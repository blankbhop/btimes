#pragma semicolon 1

#define UNREALPHYS_VERSION "1.2"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <bTimes-timer>
#include <cstrike>
#include <smlib/clients>

enum GunJumpConfig
{
	String:Weapon[64],
	Float:Range,
	Float:Damage,
	bool:Auto_Health_Regen,
	Health_Regen_Rate,
	Max_Health,
	Float:Boost_Horizontal,
	Float:Boost_Vertical,
	Primary_Clip_Size,
	Primary_Clip_Max_Size,
	Primary_Clip_Regen_Rate,
	Primary_Clip_Auto_Regen
};

// Gun jumping
any	g_GunJumpConfig[32][GunJumpConfig];
int	g_TotalGuns;

// Dodging
float g_LastSideMove[MAXPLAYERS + 1][2];
int g_LastDodgeTick[MAXPLAYERS + 1];
int g_LandingTick[MAXPLAYERS + 1];
int g_LastTapTick[MAXPLAYERS + 1];
int g_LastTapKey[MAXPLAYERS + 1];
bool g_bCanDodge[MAXPLAYERS + 1];
bool g_bWaitingForGround[MAXPLAYERS + 1];

// Double jumping
bool g_Jumped[MAXPLAYERS + 1];
int g_LastButtons[MAXPLAYERS + 1];

ConVar g_hEnableUnrealPhys;
bool g_bEnableUnrealPhys;
ConVar g_hEnableGunBoosting;
Handle g_hRegenTimer;
ConVar g_hBlockFallDamage;
bool g_bBlockFallDamage;

public Plugin myinfo = 
{
	name = "Unreal Physics",
	author = "blacky",
	description = "Simulates physics from the Unreal Tournament games",
	version = UNREALPHYS_VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

public void OnPluginStart()
{	
	// Command that reloads the gun boosting config
	RegAdminCmd("sm_reloadgj", SM_ReloadGJ, ADMFLAG_RCON, "Reloads the gun jumping config.");
	
	// Initialize gun boosting config
	LoadGunJumpConfig();
	
	// Create/hook convars
	g_hEnableUnrealPhys = CreateConVar("unrealphys_enable", "1", "Enables unreal physics.", 0, true, 0.0, true, 1.0);
	HookConVarChange(g_hEnableUnrealPhys, OnEnableUnrealPhysicsChanged);
	
	g_hEnableGunBoosting = CreateConVar("unrealphys_gunboosting", "1", "Enables gun boosting. Reads settings from sourcemod/configs/gunjump.cfg", 0, true, 0.0, true, 1.0);
	
	g_hBlockFallDamage = CreateConVar("unrealphys_blockfalldamage", "1", "Blocks all fall damage. Useful for gun boosting since players will get high up using it.", 0, true, 0.0, true, 1.0);
	HookConVarChange(g_hBlockFallDamage, OnBlockFallDamageChanged);
	
	AutoExecConfig(true, "unrealphys");
	
	CreateConVar("unrealphys_version", VERSION, "Unreal physics version", FCVAR_NOTIFY|FCVAR_REPLICATED);
	HookEvent("weapon_fire", Event_WeaponFire);
}

public void OnConfigsExecuted()
{
	// Create weapon boosting timer
	g_hRegenTimer = CreateTimer(1.0, Timer_Regen, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	
	g_bEnableUnrealPhys = GetConVarBool(g_hEnableUnrealPhys);
	
	g_bBlockFallDamage  = GetConVarBool(g_hBlockFallDamage);
}

public void OnEnableUnrealPhysicsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bEnableUnrealPhys = view_as<bool>(StringToInt(newValue));
}

public void OnBlockFallDamageChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if((g_bBlockFallDamage = view_as<bool>(StringToInt(newValue))))
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
			}
		}
	}
	else
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
			}
		}
	}
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	// Reset player settings
	g_LastSideMove[client][0]   = 0.0;
	g_LastSideMove[client][0]   = 0.0;
	g_LastDodgeTick[client]     = 0;
	g_LandingTick[client]       = 0;
	g_LastTapTick[client]       = 0;
	g_LastTapKey[client]        = 0;
	g_bCanDodge[client]         = false;
	g_bWaitingForGround[client] = false;
	g_Jumped[client]            = false;
	g_LastButtons[client]       = 0;
	
	return true;
}

public void OnClientPutInServer(int client)
{
	if(g_bBlockFallDamage)
	{
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	}
	
	SDKHook(client, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
	SDKHook(client, SDKHook_WeaponDrop, Hook_WeaponDrop);
}

public Action Hook_WeaponSwitch(int client, int weapon)
{
	char sName[64];
	GetEntityClassname(weapon, sName, 64);
	if(Style(TimerInfo(client).ActiveStyle).HasSpecialKey("gunboost") && !StrEqual(sName, "weapon_usp"))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Hook_WeaponDrop(int client, int weapon)
{
	if(weapon == -1)
	{
		return Plugin_Continue;
	}
	
	char sName[64];
	GetEntityClassname(weapon, sName, 64);
	if(Style(TimerInfo(client).ActiveStyle).HasSpecialKey("gunboost"))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void OnStyleChanged(int client, int oldStyle, int newStyle, int type)
{
	if(Style(newStyle).HasSpecialKey("gunboost"))
	{
		Client_RemoveAllWeapons(client);
		int weaponIndex = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
		if(weaponIndex != -1)
		{
			CS_DropWeapon(client, weaponIndex, false, false);
		}
		/*weaponIndex = */
		GivePlayerItem(client, "weapon_usp");
		
		/*
		if(weaponIndex != -1)
		{
			Handle hPack = CreateDataPack();
			WritePackCell(hPack, GetClientUserId(client));
			WritePackCell(hPack, EntIndexToEntRef(weaponIndex));
			RequestFrame(NextFrame_EquipWeapon, hPack);
		}
		*/
		
	}
}

public void NextFrame_EquipWeapon(Handle pack)
{
	ResetPack(pack);
	int client = GetClientOfUserId(ReadPackCell(pack));
	if(client != 0)
	{
		int weaponIndex = EntRefToEntIndex(ReadPackCell(pack));
		if(weaponIndex != INVALID_ENT_REFERENCE)
		{
			EquipPlayerWeapon(client, weaponIndex);
		}
	}
	delete pack;
}

public Action:Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(damagetype & DMG_FALL)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Timer_Regen(Handle timer, any data)
{
	if(GetConVarBool(g_hEnableGunBoosting) == false)
	{
		return Plugin_Continue;
	}
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			if(weapon == -1)
				continue;
			
			decl String:sWeapon[64];
			GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
			int GunConfig = FindWeaponConfigByWeaponName(sWeapon);
			if(GunConfig == -1)
				continue;
			
			// Health regen
			int health = GetEntProp(client, Prop_Data, "m_iHealth");
			if(health + g_GunJumpConfig[GunConfig][Health_Regen_Rate] > g_GunJumpConfig[GunConfig][Max_Health])
			{
				health = g_GunJumpConfig[GunConfig][Max_Health];
			}
			else
			{
				health += g_GunJumpConfig[GunConfig][Health_Regen_Rate];
			}
			SetEntProp(client, Prop_Data, "m_iHealth", health);
			
			// Primary clip regen
			int ammo1 = GetEntProp(weapon, Prop_Data, "m_iClip1");
			if(ammo1 + g_GunJumpConfig[GunConfig][Primary_Clip_Regen_Rate] > g_GunJumpConfig[GunConfig][Primary_Clip_Max_Size])
			{
				ammo1 = g_GunJumpConfig[GunConfig][Primary_Clip_Max_Size];
			}
			else
			{
				ammo1 += g_GunJumpConfig[GunConfig][Primary_Clip_Regen_Rate];
			}
			SetEntProp(weapon, Prop_Data, "m_iClip1", ammo1);
		}
	}
	
	return Plugin_Continue;
}

public Action SM_ReloadGJ(int client, int args)
{	
	LoadGunJumpConfig();
	
	ReplyToCommand(client, "[Unreal Physics] - Gunjump config reloaded.");
	
	return Plugin_Handled;
}

FindWeaponConfigByWeaponName(const char[] sWeapon)
{
	for(new i; i < g_TotalGuns; i++)
	{
		if(StrEqual(sWeapon, g_GunJumpConfig[i][Weapon]))
		{
			return i;
		}
	}
	
	return -1;
}

void LoadGunJumpConfig()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/gunjump.cfg");
	
	new Handle:kv = CreateKeyValues("Gun Jump Settings");
	FileToKeyValues(kv, sPath);
	
	if(kv != INVALID_HANDLE)
	{
		new Key, bool:KeyExists = true, String:sKey[32];
		
		do
		{
			IntToString(Key, sKey, sizeof(sKey));
			KeyExists = KvJumpToKey(kv, sKey);
			
			if(KeyExists == true)
			{
				KvGetString(kv, "weapon", g_GunJumpConfig[Key][Weapon], 32);
				g_GunJumpConfig[Key][Range]                     = KvGetFloat(kv, "range", 100.0);
				g_GunJumpConfig[Key][Damage]                    = KvGetFloat(kv, "damage", 5.0);
				g_GunJumpConfig[Key][Auto_Health_Regen]         = bool:KvGetNum(kv, "auto_health_regen", 1);
				g_GunJumpConfig[Key][Health_Regen_Rate]         = KvGetNum(kv, "health_regen_rate", 5);
				g_GunJumpConfig[Key][Max_Health]                = KvGetNum(kv, "max_health", 100);
				g_GunJumpConfig[Key][Boost_Horizontal]          = KvGetFloat(kv, "boost_hor", 1.0);
				g_GunJumpConfig[Key][Boost_Vertical]            = KvGetFloat(kv, "boost_vert", 1.0);
				g_GunJumpConfig[Key][Primary_Clip_Size]         = KvGetNum(kv, "clip_size", 100);
				g_GunJumpConfig[Key][Primary_Clip_Max_Size]     = KvGetNum(kv, "clip_max", 100);
				g_GunJumpConfig[Key][Primary_Clip_Regen_Rate]   = KvGetNum(kv, "clip_regen", 5);
				g_GunJumpConfig[Key][Primary_Clip_Auto_Regen]   = bool:KvGetNum(kv, "clip_auto_regen", 0);
				
				KvGoBack(kv);
				Key++;
			}
		}
		while(KeyExists == true && Key < 32);
			
		CloseHandle(kv);
		
		g_TotalGuns = Key;
	}
	else
	{
		LogError("Something went wrong reading from the gunjump.cfg file.");
	}
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{	
	if(GetConVarBool(g_hEnableGunBoosting) == false)
	{
		return;
	}
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!(0 < client <= MaxClients))
	{
		return;
	}
	
	if(IsFakeClient(client))
	{
		return;
	}
	
	if(!Style(TimerInfo(client).GetStyle(TimerInfo(client).Type)).HasSpecialKey("gunboost"))
	{
		return;
	}
	
	// Stop boost if invalid weapon
	decl String:sWeapon[64];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
	Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);
	int GunConfig = FindWeaponConfigByWeaponName(sWeapon);
	if(GunConfig == -1)
		return;
	
	float vPos[3];
	GetClientEyePosition(client, vPos);
	
	float vAng[3];
	GetClientEyeAngles(client, vAng);
	
	TR_TraceRayFilter(vPos, vAng, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);
	
	if(TR_DidHit())
	{
		float vHitPos[3];
		TR_GetEndPosition(vHitPos);
		/*
		if(IsBlacky(client))
		{
			int entity = TR_GetEntityIndex();
			if(entity != -1)
			{
				char sClass[64];
				GetEntityClassname(entity, sClass, 64);
				PrintToChat(client, sClass);
			}
		}
		*/
		if(GetVectorDistance(vPos, vHitPos) <= g_GunJumpConfig[GunConfig][Range])
		{
			float vPush[3];
			MakeVectorFromPoints(vHitPos, vPos, vPush);
			PrintToChatAll("%f %f %f", vPush[0], vPush[1], vPush[2]);
			NormalizeVector(vPush, vPush);
			PrintToChatAll("%f %f %f", vPush[0], vPush[1], vPush[2]);
			vPush[0] *= g_GunJumpConfig[GunConfig][Boost_Horizontal];
			vPush[1] *= g_GunJumpConfig[GunConfig][Boost_Horizontal];
			vPush[2] *= g_GunJumpConfig[GunConfig][Boost_Vertical];
			PrintToChatAll("%f %f %f", vPush[0], vPush[1], vPush[2]);
			
			float vVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
			
			float vResult[3];
			AddVectors(vPush, vVel, vResult);
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vResult);
			
			if(g_GunJumpConfig[GunConfig][Damage] != 0)
			{
				int weaponIndex = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
				SDKHooks_TakeDamage(client, weaponIndex, client, g_GunJumpConfig[GunConfig][Damage], DMG_BLAST, _, NULL_VECTOR, vHitPos);
			}
			
		}
	}
	
	return;
}

public bool TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	
	if(0 < entity <= MaxClients)
	{
		return false;
	}
	
	char sClass[64];
	GetEntityClassname(entity, sClass, 64);
	if(StrContains(sClass, "weapon_") != -1)
	{
		return false;
	}
	
	return true;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(g_bEnableUnrealPhys)
	{
		if(IsPlayerAlive(client) && !IsFakeClient(client) && Style(TimerInfo(client).GetStyle(TimerInfo(client).Type)).HasSpecialKey("unreal"))
		{
			// Dodge detection
			CheckForKeyTap(client, vel);
				
			// Double jump detection
			CheckForJumpTap(client, Timer_GetButtons(client));
		}
	}
	
	g_LastSideMove[client][0] = vel[0];
	g_LastSideMove[client][1] = vel[1];
	g_LastButtons[client]     = Timer_GetButtons(client);
}

CheckForKeyTap(int client, float vel[3])
{
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		g_bCanDodge[client] = true;
		
		if(g_bWaitingForGround[client] == true)
		{
			g_bWaitingForGround[client] = false;
			g_LandingTick[client]       = GetGameTickCount();
		}
	}
	
	if(g_bCanDodge[client] == false)
		return;
	
	if((float(GetGameTickCount())*GetTickInterval() - float(g_LandingTick[client])*GetTickInterval()) < 0.3)
		return;
	
	if(g_LastSideMove[client][1] <= 0 && vel[1] > 0)
		OnClientTappedKey(client, IN_MOVERIGHT);
	else if(g_LastSideMove[client][1] >= 0 && vel[1] < 0)
		OnClientTappedKey(client, IN_MOVELEFT);
	else if(g_LastSideMove[client][0] <= 0 && vel[0] > 0)
		OnClientTappedKey(client, IN_FORWARD);
	else if(g_LastSideMove[client][0] >= 0 && vel[0] < 0)
		OnClientTappedKey(client, IN_BACK);
}

OnClientTappedKey(int client, int Key)
{
	if(g_LastTapKey[client] == Key && (float(GetGameTickCount())*GetTickInterval() - float(g_LastTapTick[client])*GetTickInterval() < 0.2))
	{
		OnClientDoubleTappedKey(client, Key);
	}
	
	g_LastTapKey[client]  = Key;
	g_LastTapTick[client] = GetGameTickCount();
}

OnClientDoubleTappedKey(int client, int Key)
{
	float vAng[3];
	GetClientEyeAngles(client, vAng);
	vAng[0] = 0.0; // Ensures consistent dodges if player is considered to be facing straight outwards
	
	// Get direction player wants to dodge to
	float vDodgeDir[3];
	if(Key == IN_MOVERIGHT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vDodgeDir, NULL_VECTOR);
	}
	else if(Key == IN_MOVELEFT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vDodgeDir, NULL_VECTOR);
		NegateVector(vDodgeDir);
	}
	else if(Key == IN_FORWARD)
	{
		GetAngleVectors(vAng, vDodgeDir, NULL_VECTOR, NULL_VECTOR);
	}
	else if(Key == IN_BACK)
	{
		GetAngleVectors(vAng, vDodgeDir, NULL_VECTOR, NULL_VECTOR);
		NegateVector(vDodgeDir);
	}
	
	// Checks if a client is allowed to dodge (from ground or from wall)
	bool bCanDodge;
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		bCanDodge = true;
	}
	else
	{
		float vPos[3];
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", vPos);
		
		float vTraceAngle[3];
		vTraceAngle[0] = vDodgeDir[0];
		vTraceAngle[1] = vDodgeDir[1];
		vTraceAngle[2] = vDodgeDir[2];
		NegateVector(vTraceAngle);
		GetVectorAngles(vTraceAngle, vTraceAngle);
		
		TR_TraceRayFilter(vPos, vTraceAngle, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);
		
		if(TR_DidHit())
		{
			float vHitPos[3];
			TR_GetEndPosition(vHitPos);
			
			if(GetVectorDistance(vPos, vHitPos) < 30)
			{
				bCanDodge = true;
			}
		}
	}
	
	// Dodges client if they are allowed to dodge
	if(bCanDodge == true)
	{
		vDodgeDir[0] *= 400.0;
		vDodgeDir[1] *= 400.0;
		
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		
		float vResult[3];
		AddVectors(vVel, vDodgeDir, vResult);
		vResult[2] = 251.0;
		
		// This line and following timer allows setting a player's vertical velocity when they are on the ground to something lower than 250.0
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vResult);
		
		DataPack hData;
		CreateDataTimer(0.0, Timer_Dodge, hData, TIMER_DATA_HNDL_CLOSE);
		WritePackCell(hData, client);
		WritePackFloat(hData, vResult[0]);
		WritePackFloat(hData, vResult[1]);
		WritePackFloat(hData, vResult[2]);
		
		g_LastDodgeTick[client] = GetGameTickCount();
		
		float vPos[3];
		GetClientEyePosition(client, vPos);
	}
}

public Action Timer_Dodge(Handle timer, DataPack data)
{
	ResetPack(data);
	int client = ReadPackCell(data);
	
	float vVel[3];
	vVel[0] = ReadPackFloat(data);
	vVel[1] = ReadPackFloat(data);
	vVel[2] = 150.0;
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	
	g_bWaitingForGround[client] = true;
	g_bCanDodge[client]         = false;
}

CheckForJumpTap(int client, int buttons)
{
	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		
		if(!(g_LastButtons[client] & IN_JUMP) && (buttons & IN_JUMP) && g_Jumped[client] == false && (-60.0 <= vVel[2] <= 90.0))
		{
			vVel[2] = 290.0;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			
			g_Jumped[client] = true;
			
			Event hEventJump = CreateEvent("player_jump", true);
			
			if(hEventJump != INVALID_HANDLE)
			{
				SetEventInt(hEventJump, "userid", GetClientUserId(client));
				FireEvent(hEventJump);
			}
		}
	}
	else
	{
		g_Jumped[client] = false;
	}
}