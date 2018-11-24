#pragma semicolon 1

#include <sourcemod>
#include <smlib/entities>
#include <smlib/weapons>
#include <sdktools>
#include <sdkhooks>
#include <bTimes-gunjump>
#include <bTimes-core>
#include <bTimes-zones>
#include <bTimes-timer>
#include <mapcommands>

// Gun jumping
new	bool:g_bInGunJump;
new	g_GunJumpConfig[32][GunJumpConfig];
new	g_TotalGuns;

// Dodging
new Float:g_LastSideMove[MAXPLAYERS + 1][2];
new g_LastDodgeTick[MAXPLAYERS + 1];
new g_LandingTick[MAXPLAYERS + 1];
new g_LastTapTick[MAXPLAYERS + 1];
new g_LastTapKey[MAXPLAYERS + 1];
new bool:g_bCanDodge[MAXPLAYERS + 1];
new bool:g_bWaitingForGround[MAXPLAYERS + 1];

// Double jumping
new bool:g_Jumped[MAXPLAYERS + 1];
new g_LastButtons[MAXPLAYERS + 1];

public Plugin:myinfo = 
{
	name = "[bTimes] Unreal Physics",
	author = "blacky",
	description = "The gun jumping mod for the timer.",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

public OnPluginStart()
{
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	RegAdminCmd("sm_reloadgj", SM_ReloadGJ, ADMFLAG_RCON, "Reloads the gun jumping config.");
	
	LoadGunJumpConfig();
}

public TriggerCommand_OnCommand(const String:command[], const String:arg[], client, trigger)
{
	if(StrEqual(command, "stoptimer"))
	{
		StopTimer(client);
		PrintToChat(client, "Your timer was stopped");
	}
}

public OnMapStart()
{
	CreateTimer(1.0, Timer_Regen, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
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

public OnStyleChanged(client, OldStyle, NewStyle, Type)
{
	if(IsPlayerAlive(client))
	{
		new Config[StyleConfig];
		Style_GetConfig(NewStyle, Config);
		
		if(Config[GunJump] && Config[AllowType][Type])
		{
			for(new i; i<8; i++)
			{
				FakeClientCommand(client, "drop");
			}
			
			GivePlayerItem(client, Config[GunJump_Weapon]);
		}
	}
}

public Action:Timer_Regen(Handle:timer, any:data)
{
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			new Style = GetClientStyle(client);
			new Type  = GetClientTimerType(client);
			
			new Config[StyleConfig];
			Style_GetConfig(Style, Config);
			
			if(Config[GunJump] && Config[AllowType][Type])
			{
				new weaponIndex = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
				if(weaponIndex == -1)
					continue;
				
				decl String:sWeapon[64];
				GetEntityClassname(weaponIndex, sWeapon, sizeof(sWeapon));
				if(StrEqual(sWeapon, Config[GunJump_Weapon]))
				{
					new GunConfig = FindWeaponConfigByWeaponName(sWeapon);
					if(GunConfig == -1)
						continue;
					
					// Health regen
					new health = GetEntProp(client, Prop_Data, "m_iHealth");
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
					new ammo1 = Weapon_GetPrimaryClip(weaponIndex);
					if(ammo1 + g_GunJumpConfig[GunConfig][Primary_Clip_Regen_Rate] > g_GunJumpConfig[GunConfig][Primary_Clip_Max_Size])
					{
						ammo1 = g_GunJumpConfig[GunConfig][Primary_Clip_Max_Size];
					}
					else
					{
						ammo1 += g_GunJumpConfig[GunConfig][Primary_Clip_Regen_Rate];
					}
					Weapon_SetPrimaryClip(weaponIndex, ammo1);
				}
			}
		}
	}
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	new Style = GetClientStyle(client);
	new Type  = GetClientTimerType(client);
	
	new Config[StyleConfig];
	Style_GetConfig(Style, Config);
	
	if(Config[GunJump] && Config[AllowType][Type])
	{
		new Handle:hData;
		CreateDataTimer(0.0, Timer_SetGunJumpWeapon, hData, TIMER_DATA_HNDL_CLOSE);
		WritePackCell(hData, client);
		WritePackString(hData, Config[GunJump_Weapon]);
	}
}

public Action:Timer_SetGunJumpWeapon(Handle:timer, Handle:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	
	decl String:sWeapon[64];
	ReadPackString(data, sWeapon, sizeof(sWeapon));
	
	for(new i; i<8; i++)
	{
		FakeClientCommand(client, "drop");
	}
	
	GivePlayerItem(client, sWeapon);
}

public Action:SM_ReloadGJ(client, args)
{	
	LoadGunJumpConfig();
	
	return Plugin_Handled;
}

FindWeaponConfigByWeaponName(const String:sWeapon[])
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

LoadGunJumpConfig()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/gunjump.cfg");
	
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
				g_GunJumpConfig[Key][Secondary_Clip_Size]       = KvGetNum(kv, "clip2_size", 0);
				g_GunJumpConfig[Key][Secondary_Clip_Max_Size]   = KvGetNum(kv, "clip2_max", 0);
				g_GunJumpConfig[Key][Secondary_Clip_Regen_Rate] = KvGetNum(kv, "clip2_regen", 0);
				g_GunJumpConfig[Key][Secondary_Clip_Auto_Regen] = bool:KvGetNum(kv, "clip2_auto_regen", 0);
				
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

public Action:Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Stop boost if invalid weapon
	decl String:sWeapon[64];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
	Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);
	new GunConfig = FindWeaponConfigByWeaponName(sWeapon);
	if(GunConfig == -1)
		return Plugin_Continue;
	
	// Stop boost if style doesn't allow it
	new Config[StyleConfig];
	Style_GetConfig(GetClientStyle(client), Config);
	if(Config[GunJump] == false || StrEqual(sWeapon, Config[GunJump_Weapon]) == false)
		return Plugin_Continue;
	
	new Float:vPos[3];
	GetClientEyePosition(client, vPos);
	
	new Float:vAng[3];
	GetClientEyeAngles(client, vAng);
	
	TR_TraceRayFilter(vPos, vAng, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);
	
	if(TR_DidHit())
	{
		new Float:vHitPos[3];
		TR_GetEndPosition(vHitPos);
		
		if(GetVectorDistance(vPos, vHitPos) <= g_GunJumpConfig[GunConfig][Range])
		{
			g_bInGunJump = true;
			
			new Float:vPush[3];
			MakeVectorFromPoints(vHitPos, vPos, vPush);
			vPush[0] *= g_GunJumpConfig[GunConfig][Boost_Horizontal];
			vPush[1] *= g_GunJumpConfig[GunConfig][Boost_Horizontal];
			vPush[2] *= g_GunJumpConfig[GunConfig][Boost_Vertical];
			
			new Float:vVel[3];
			Entity_GetAbsVelocity(client, vVel);
			
			new Float:vResult[3];
			AddVectors(vPush, vVel, vResult);
			
			Entity_SetAbsVelocity(client, vResult);
			
			new weaponIndex = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			SDKHooks_TakeDamage(client, weaponIndex, client, g_GunJumpConfig[GunConfig][Damage], DMG_BLAST, _, vPush, vHitPos);
			
			g_bInGunJump = false;
		}
	}
	
	return Plugin_Continue;
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

public Native_IsGunJump(Handle:plugin, numParams)
{
	return g_bInGunJump;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsPlayerAlive(client) && !IsFakeClient(client))
	{
		new Config[StyleConfig];
		Style_GetConfig(GetClientStyle(client), Config);
		
		if(Config[UnrealPhys])
		{
			CheckForKeyTap(client, vel);
			
			CheckForJumpTap(client);
		}
	}
	
	g_LastSideMove[client][0] = vel[0];
	g_LastSideMove[client][1] = vel[1];
	g_LastButtons[client]     = Timer_GetButtons(client);
}

CheckForKeyTap(client, Float:vel[3])
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
	
	if((GetGameTickCount() - g_LandingTick[client]) < 30)
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

OnClientTappedKey(client, Key)
{
	if(g_LastTapKey[client] == Key && (GetGameTickCount() - g_LastTapTick[client] < 20))
	{
		OnClientDoubleTappedKey(client, Key);
	}
	
	g_LastTapKey[client]  = Key;
	g_LastTapTick[client] = GetGameTickCount();
}

OnClientDoubleTappedKey(client, Key)
{
	new Float:vAng[3];
	GetClientEyeAngles(client, vAng);
	vAng[0] = 0.0; // Ensures consistent dodges if player is considered to be facing straight outwards
	
	new Float:vDodgeDir[3];
	
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
	
	new bool:bCanDodge;
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		bCanDodge = true;
	}
	else
	{
		new Float:vPos[3];
		Entity_GetAbsOrigin(client, vPos);
		
		new Float:vTraceAngle[3];
		vTraceAngle[0] = vDodgeDir[0];
		vTraceAngle[1] = vDodgeDir[1];
		vTraceAngle[2] = vDodgeDir[2];
		NegateVector(vTraceAngle);
		GetVectorAngles(vTraceAngle, vTraceAngle);
		
		TR_TraceRayFilter(vPos, vTraceAngle, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);
		
		if(TR_DidHit())
		{
			new Float:vHitPos[3];
			TR_GetEndPosition(vHitPos);
			
			if(GetVectorDistance(vPos, vHitPos) < 30)
			{
				bCanDodge = true;
			}
		}
	}
	
	if(bCanDodge == true)
	{
		vDodgeDir[0] *= 400.0;
		vDodgeDir[1] *= 400.0;
		
		new Float:vVel[3];
		Entity_GetAbsVelocity(client, vVel);
		
		new Float:vResult[3];
		AddVectors(vVel, vDodgeDir, vResult);
		vResult[2] = 251.0;
		
		Entity_SetAbsVelocity(client, vResult);
		
		new Handle:hData;
		CreateDataTimer(0.0, Timer_Dodge, hData, TIMER_DATA_HNDL_CLOSE);
		WritePackCell(hData, client);
		WritePackFloat(hData, vResult[0]);
		WritePackFloat(hData, vResult[1]);
		WritePackFloat(hData, vResult[2]);
		
		g_LastDodgeTick[client] = GetGameTickCount();
		
		new Float:vPos[3];
		GetClientEyePosition(client, vPos);
	}
}

public Action:Timer_Dodge(Handle:timer, Handle:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	
	new Float:vVel[3];
	vVel[0] = ReadPackFloat(data);
	vVel[1] = ReadPackFloat(data);
	vVel[2] = 150.0;
	
	Entity_SetAbsVelocity(client, vVel);
	
	g_bWaitingForGround[client] = true;
	g_bCanDodge[client]         = false;
}

CheckForJumpTap(client)
{
	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		new buttons = Timer_GetButtons(client);
		new Float:vVel[3];
		Entity_GetAbsVelocity(client, vVel);
		
		if(!(g_LastButtons[client] & IN_JUMP) && (buttons & IN_JUMP) && g_Jumped[client] == false && (-60 <= vVel[2] <= 90.0))
		{
			vVel[2] = 290.0;
			Entity_SetAbsVelocity(client, vVel);
			
			new Handle:hEventJump = CreateEvent("player_jump");
			SetEventInt(hEventJump, "userid", GetClientUserId(client));
			FireEvent(hEventJump);
			
			g_Jumped[client] = true;
		}
	}
	else
	{
		g_Jumped[client] = false;
	}
}