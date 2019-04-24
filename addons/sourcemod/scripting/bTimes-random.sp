#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[Timer] - Random",
	author = "blacky",
	description = "Handles events and modifies them to fit bTimes' needs",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <smlib/weapons>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <bTimes-timer>
#include <bTimes-zones>
#include <clientprefs>
#include <csgocolors>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <bTimes-tas>
#include <smartmsg>

#undef REQUIRE_EXTENSIONS
#include <soundscapehook>

#pragma newdecls required

EngineVersion g_Engine;
bool g_bUncrouch[MAXPLAYERS + 1];

float g_fMapStart;

int  g_iSoundEnts[2048];
int  g_iNumSounds;
bool g_bHooked;
bool g_bSoundsHavePlayed;


// Server Settings
ConVar g_hAllowKnifeDrop;
ConVar g_WeaponDespawn;
ConVar g_hNoDamage;
ConVar g_hAllowHide;

// Client settings
Handle g_hHideCookie;
Handle g_hDoorSoundCookie;
Handle g_hGunSoundCookie;
Handle g_hMusicCookie;

bool g_bLateLoad;
bool g_bTasPluginLoaded;
bool g_bSmartMsgLoaded;

public void OnPluginStart()
{
	g_Engine = GetEngineVersion();
	
	g_hAllowKnifeDrop = CreateConVar("timer_allowknifedrop", "1", "Allows players to drop any weapons (including knives and grenades)", 0, true, 0.0, true, 1.0);
	g_WeaponDespawn   = CreateConVar("timer_weapondespawn", "1", "Kills weapons a second after spawning to prevent flooding server.", 0, true, 0.0, true, 1.0);
	g_hNoDamage       = CreateConVar("timer_nodamage", "1", "Blocks all player damage when on", 0, true, 0.0, true, 1.0);
	g_hAllowHide      = CreateConVar("timer_allowhide", "1", "Allows players to use the !hide command", 0, true, 0.0, true, 1.0);
	
	// Hook cvars
	HookConVarChange(g_hNoDamage, OnNoDamageChanged);
	HookConVarChange(g_hAllowHide, OnAllowHideChanged);
	
	// Create config file if it doesn't exist
	AutoExecConfig(true, "random", "timer");
	
	// Event hooks
	HookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	AddNormalSoundHook(NormalSHook);
	AddAmbientSoundHook(AmbientSHook);
	AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
	
	// Command hooks
	AddCommandListener(DropItem, "drop");
	AddCommandListener(Command_Kill, "kill");
	AddCommandListener(Command_Kill, "explode");
	
	if(g_Engine == Engine_CSGO)
		AddCommandListener(Spec_Mode, "spec_mode"); // Fix a spec bug in cs:go with crouching
	
	// Player commands
	RegConsoleCmdEx("sm_hide", SM_Hide, "Toggles hide");
	RegConsoleCmdEx("sm_unhide", SM_Hide, "Toggles hide");
	RegConsoleCmdEx("sm_spec", SM_Spec, "Be a spectator");
	RegConsoleCmdEx("sm_spectate", SM_Spec, "Be a spectator");
	RegConsoleCmdEx("sm_maptime", SM_Maptime, "Shows how long the current map has been on.");
	RegConsoleCmdEx("sm_specinfo", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_specs", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_speclist", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_spectators", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_normalspeed", SM_Normalspeed, "Sets your speed to normal speed.");
	RegConsoleCmdEx("sm_speed", SM_Speed, "Changes your speed to the specified value.");
	RegConsoleCmdEx("sm_setspeed", SM_Speed, "Changes your speed to the specified value.");
	RegConsoleCmdEx("sm_slow", SM_Slow, "Sets your speed to slow (0.5)");
	RegConsoleCmdEx("sm_fast", SM_Fast, "Sets your speed to fast (2.0)");
	//RegConsoleCmdEx("sm_lowgrav", SM_Lowgrav, "Lowers your gravity.");
	//RegConsoleCmdEx("sm_normalgrav", SM_Normalgrav, "Sets your gravity to normal.");
	//RegConsoleCmdEx("sm_stuck", SM_Stuck, "Unstuck yourself");
	
	// Admin commands
	RegConsoleCmd("sm_move", SM_Move, "For getting players out of places they are stuck in");
	RegConsoleCmd("sm_admins", SM_Admins, "Shows list of players that have any admin flags");
	
	// Client cookies
	g_hHideCookie      = RegClientCookie("timer_hide", "Hide players setting.", CookieAccess_Public);
	SetCookiePrefabMenu(g_hHideCookie, CookieMenu_OnOff, "Hide players");
	
	g_hDoorSoundCookie = RegClientCookie("timer_doorsounds", "Door sound setting.", CookieAccess_Public);
	SetCookiePrefabMenu(g_hDoorSoundCookie, CookieMenu_OnOff, "Door sounds");
	
	g_hGunSoundCookie  = RegClientCookie("timer_gunsounds", "Gun sounds setting.", CookieAccess_Public);
	SetCookieMenuItem(Menu_Sound, 1, "Gun sounds");
	
	g_hMusicCookie     = RegClientCookie("timer_musicsounds", "Map music sounds setting.", CookieAccess_Public);
	SetCookieMenuItem(Menu_Sound, 2, "Map music sounds");
	
	// Translations
	LoadTranslations("common.phrases");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	RegPluginLibrary("timer-random");
	
	if(late)
	{
		UpdateMessages();
	}
	
	g_bLateLoad = late;
	
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bTasPluginLoaded = LibraryExists("tas");
	
	if((g_bSmartMsgLoaded  = LibraryExists("smartmsg")) == true)
	{
		RegisterSmartMessage(SmartMsg_Sounds);
	}
}

public void OnLibraryAdded(const char[] library)
{
	if(StrEqual(library, "tas"))
	{
		g_bTasPluginLoaded = true;
	}
	else if(StrEqual(library, "smartmsg"))
	{
		g_bSmartMsgLoaded = true;
		RegisterSmartMessage(SmartMsg_Sounds);
	}
}

public void OnLibraryRemoved(const char[] library)
{
	if(StrEqual(library, "tas"))
	{
		g_bTasPluginLoaded = false;
	}
	else if(StrEqual(library, "smartmsg"))
	{
		g_bSmartMsgLoaded = false;
	}
}

public void OnMapStart()
{
	g_bSoundsHavePlayed = false;
	//set map start time
	g_fMapStart = GetEngineTime();
	
	if(g_bLateLoad)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				OnClientPutInServer(client);
			}

		}
		
		g_iNumSounds = 0;
		char sSound[PLATFORM_MAX_PATH];
		int entity = INVALID_ENT_REFERENCE;
		
		while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
		{
			GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
			
			int len = strlen(sSound);
			if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
			{
				g_iSoundEnts[g_iNumSounds++] = EntIndexToEntRef(entity);
			}
		}
	}
	
	CheckHooks();
}

public void OnClientPutInServer(int client)
{
	// for !hide
	if(GetConVarBool(g_hAllowHide))
	{
		SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	}
	
	// prevents damage
	if(GetConVarBool(g_hNoDamage))
	{
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	}
	
	SDKHook(client, SDKHook_WeaponDropPost, Hook_DropWeapon);
}

public void OnClientCookiesCached(int client)
{
	char sCookie[32];
	GetClientCookie(client, g_hDoorSoundCookie, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hDoorSoundCookie, true);
	}
	
	GetClientCookie(client, g_hGunSoundCookie, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hGunSoundCookie, true);
	}
	
	GetClientCookie(client, g_hMusicCookie, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hMusicCookie, true);
	}
	
	if(GetCookieBool(client, g_hGunSoundCookie) == false && g_bHooked == false)
	{
		g_bHooked = true;
	}
}

public void OnNoDamageChanged(ConVar convar, const char[] error, const char[] newValue)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(newValue[0] == '0')
			{
				SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
			}
			else
			{
				SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
			}
		}
	}
}

public void OnAllowHideChanged(ConVar convar, const char[] error, const char[] newValue)
{	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(newValue[0] == '0')
			{
				SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit);
			}
			else
			{
				SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
			}
		}
	}
}

public void OnClientDisconnect_Post(int client)
{
	CheckHooks();
}

public bool SmartMsg_Sounds(int client)
{
	if(g_bSoundsHavePlayed && GetCookieBool(client, g_hMusicCookie))
	{
		PrintColorText(client, "%s%sTip: You can disable map music by accessing the %s!settings%s menu",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
			
		return true;
	}
	
	return false;
}

public Action Timer_StopMusic(Handle timer, any data)
{
	int ientity;
	char sSound[128];
	for (int idx; idx < g_iNumSounds; idx++)
	{
		ientity = EntRefToEntIndex(g_iSoundEnts[idx]);
		
		if (ientity != INVALID_ENT_REFERENCE)
		{
			for(int client = 1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client))
				{
					if(!GetCookieBool(client, g_hMusicCookie))
					{
						GetEntPropString(ientity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
						EmitSoundToClient(client, sSound, ientity, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
					}
				}
			}
		}
	}
}

// Credits to GoD-Tony for everything related to stopping gun sounds
public Action CSS_Hook_ShotgunShot(const char[] te_name, const int[] Players, int numClients, float delay)
{
	if(!g_bHooked)
		return Plugin_Continue;
	
	// Check which clients need to be excluded.
	int[] newClients = new int[MaxClients];
	int newTotal, client;
	
	for (int i; i < numClients; i++)
	{
		client = Players[i];
		
		if (GetCookieBool(client, g_hGunSoundCookie))
		{
			newClients[newTotal++] = client;
		}
	}
	
	// No clients were excluded.
	if (newTotal == numClients)
		return Plugin_Continue;
	
	// All clients were excluded and there is no need to broadcast.
	else if (newTotal == 0)
		return Plugin_Stop;
	
	// Re-broadcast to clients that still need it.
	float vTemp[3];
	TE_Start("Shotgun Shot");
	
	if(g_Engine == Engine_CSS)
	{
		TE_ReadVector("m_vecOrigin", vTemp); TE_WriteVector("m_vecOrigin", vTemp);
		TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
		TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
		TE_WriteNum("m_iWeaponID", TE_ReadNum("m_iWeaponID"));
		TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
		TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
		TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
		TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
		TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	}
	else if(g_Engine == Engine_CSGO)
	{
		TE_ReadVector("m_vecOrigin", vTemp); TE_WriteVector("m_vecOrigin", vTemp);
		TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
		TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
		TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
		TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
		TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
		TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
		TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
		TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
		TE_WriteFloat("m_flRecoilIndex", TE_ReadFloat("m_flRecoilIndex"));
		TE_WriteNum("m_nItemDefIndex", TE_ReadNum("m_nItemDefIndex"));
		TE_WriteNum("m_iSoundType", TE_ReadNum("m_iSoundType"));
	}
	
	TE_Send(newClients, newTotal, delay);
	
	return Plugin_Stop;
}

void CheckHooks()
{
	bool bShouldHook = false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(!GetCookieBool(i, g_hGunSoundCookie))
			{
				bShouldHook = true;
				break;
			}
		}
	}
	
	// Fake (un)hook because toggling actual hooks will cause server instability.
	g_bHooked = bShouldHook;
}

public Action AmbientSHook(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	g_bSoundsHavePlayed = true;
	// Stop music next frame
	CreateTimer(0.0, Timer_StopMusic);
}
 
public Action NormalSHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if(IsValidEntity(entity) && IsValidEdict(entity))
	{
		char sClassName[128];
		GetEntityClassname(entity, sClassName, sizeof(sClassName));
		
		Handle hCookie;
		if(StrEqual(sClassName, "func_door"))
			hCookie = g_hDoorSoundCookie;
		else if(strncmp(sample, "weapons", 7) == 0 || strncmp(sample[1], "weapons", 7) == 0)
			hCookie = g_hGunSoundCookie;
		else
			return Plugin_Continue;
		
		for(int idx; idx < numClients; idx++)
		{
			if(!GetCookieBool(clients[idx], hCookie))
			{
				// Remove the client from the array.
				for (int j = idx; j < numClients-1; j++)
				{
					clients[j] = clients[j+1];
				}
				numClients--;
				idx--;
			}
		}
		
		return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(GetConVarBool(g_WeaponDespawn) == true)
	{
		if(StrContains(classname, "weapon_") != -1 || StrContains(classname, "item_") != -1)
		{
			CreateTimer(1.0, KillEntity, EntIndexToEntRef(entity));
		}
	}
}
 
public Action KillEntity(Handle timer, any ref)
{
	// anti-weapon spam
	int ent = EntRefToEntIndex(ref);
	if(ent != INVALID_ENT_REFERENCE)
	{
		int m_hOwnerEntity = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
		if(m_hOwnerEntity == -1)
			AcceptEntityInput(ent, "Kill");
	}
}
 
public Action Event_PlayerSpawn_Post(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// no block
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
	
	GivePlayerItem(client, "item_assaultsuit");
	
	return Plugin_Continue;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client != 0 && !IsFakeClient(client) && event.GetInt("newteam") == 1)
	{
		// Disable flashlight when player's go to spectate to prevent visual bugs
		SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") & ~(1 << 2));
	}
}

public Action Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	// Ents are recreated every round.
	g_iNumSounds = 0;
	
	// Find all ambient sounds played by the map.
	char sSound[PLATFORM_MAX_PATH];
	int entity = INVALID_ENT_REFERENCE;
	
	while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
		
		int len = strlen(sSound);
		if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
		{
			g_iSoundEnts[g_iNumSounds++] = EntIndexToEntRef(entity);
		}
	}
}

public Action Command_Kill(int client, char[] command, int args)
{
	if(IsBeingTimed(client, TIMER_ANY) && (TimerInfo(client).CurrentTime / 60) > 10)
	{
		KillRequestMenu(client);
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

void KillRequestMenu(int client)
{
	Menu menu = new Menu(Menu_KillRequest);
	menu.SetTitle("Are you sure you want to kys?\n ");
	menu.AddItem("yes", "Yes");
	menu.AddItem("no",  "No");
	menu.Display(client, 3);
}

public int Menu_KillRequest(Menu menu, MenuAction action, int client, int param2)
{
	if(action & MenuAction_Select)
	{
		char sInfo[4];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "yes"))
		{
			if(IsPlayerAlive(client))
			{
				ForcePlayerSuicide(client);
			}
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

public Action Spec_Mode(int client, char[] command, int args)
{
	if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 5)
	{
		g_bUncrouch[client] = true;
	}
}

// drop any weapon
public Action DropItem(int client, char[] command, int argc)
{
	if(0 < client <= MaxClients && IsClientInGame(client))
	{
		// Allow ghosts to drop all weapons and allow players if the cvar allows them to
		if(GetConVarBool(g_hAllowKnifeDrop) || IsFakeClient(client))
		{
			int weaponIndex = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			if(weaponIndex != -1)
			{
				CS_DropWeapon(client, weaponIndex, false, false);
			}
			
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}
 
// kill weapon and weapon attachments on drop
public void Hook_DropWeapon(int client, int weaponIndex)
{
	if(weaponIndex != -1)
	{
		RequestFrame(NextFrame_KillWeapon, EntIndexToEntRef(weaponIndex));
	}
}

public void NextFrame_KillWeapon(int weaponRef)
{
	int weaponIndex = EntRefToEntIndex(weaponRef);
	if(weaponIndex != INVALID_ENT_REFERENCE && Weapon_GetOwner(weaponIndex) == -1)
	{
		AcceptEntityInput(weaponIndex, "KillHierarchy");
		AcceptEntityInput(weaponIndex, "Kill");
	}
}

// Tells a player who is spectating them
public Action SM_Specinfo(int client, int args)
{
	if(IsPlayerAlive(client))
	{
		ShowSpecinfo(client, client);
	}
	else
	{
		int Target       = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		int ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
			
		if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
		{
			ShowSpecinfo(client, Target);
		}
		else
		{
			PrintColorText(client, "%s%sYou are not spectating anyone.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

void ShowSpecinfo(int client, int target)
{
	char[][] sNames = new char[MaxClients + 1][MAX_NAME_LENGTH];
	int index;
	AdminFlag flag = Admin_Generic;
	Timer_GetAdminFlag("basic", flag);
	bool bClientHasAdmin = GetAdminFlag(GetUserAdmin(client), flag, Access_Effective);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(!bClientHasAdmin && GetAdminFlag(GetUserAdmin(i), flag, Access_Effective))
			{
				continue;
			}
				
			if(!IsPlayerAlive(i))
			{
				int iTarget 	 = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
				int ObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				
				if((ObserverMode == 4 || ObserverMode == 5) && (iTarget == target))
				{
					GetClientName(i, sNames[index++], MAX_NAME_LENGTH);
				}
			}
		}
	}
	
	char sTarget[MAX_NAME_LENGTH];
	GetClientName(target, sTarget, sizeof(sTarget));
	
	if(index != 0 || 1 == 1)
	{
		Panel panel = new Panel();
		
		char sTitle[64];
		Format(sTitle, sizeof(sTitle), "Spectating %s", sTarget);
		panel.DrawText(sTitle);
		panel.DrawText(" ");
		
		for(int i = 0; i < index; i++)
		{
			if(StrContains(sNames[i], "#"))
			{
				ReplaceString(sNames[i], MAX_NAME_LENGTH, "#", "");
			}
			panel.DrawText(sNames[i]);
		}
		
		panel.DrawText(" ");
		panel.CurrentKey = 10;
		panel.DrawItem("Close");
		panel.Send(client, Menu_SpecInfo, MENU_TIME_FOREVER);
	}
	else
	{
		PrintColorText(client, "%s%s%s%s has no spectators.",
			g_msg_start,
			g_msg_varcol,
			sTarget,
			g_msg_textcol);
	}
}

public int Menu_SpecInfo(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_End)
		delete menu;
}

// Hide other players
public Action SM_Hide(int client, int args)
{
	SetCookieBool(client, g_hHideCookie, !GetCookieBool(client, g_hHideCookie));
	
	if(GetCookieBool(client, g_hHideCookie))
	{
		PrintColorText(client, "%s%sPlayers are now %sinvisible",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol);
	}
	else
	{
		PrintColorText(client, "%s%sPlayers are now %svisible",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol);
	}
	
	return Plugin_Handled;
}

// Spectate command
public Action SM_Spec(int client, int args)
{
	if(IsPlayerAlive(client))
	{
		ForcePlayerSuicide(client);
		StopTimer(client);
	}
	
	if(GetClientTeam(client) != 1)
	{
		ChangeClientTeam(client, 1);
	}
	
	if(args != 0)
	{
		char arg[128];
		GetCmdArgString(arg, sizeof(arg));
		int target = FindTarget(client, arg, false, false);
		if(target != -1)
		{
			if(client != target)
			{
				if(IsPlayerAlive(target))
				{
					SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
					SetEntProp(client, Prop_Send, "m_iObserverMode", 4);
				}
				else
				{
					char name[MAX_NAME_LENGTH];
					GetClientName(target, name, sizeof(name));
					PrintColorText(client, "%s%s%s %sis not alive.", 
						g_msg_start,
						g_msg_varcol,
						name,
						g_msg_textcol);
				}
			}
			else
			{
				PrintColorText(client, "%s%sYou can't spectate yourself.",
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
	else
	{
		int bot = 0;
		for(int target = 1; target <= MaxClients; target++)
		{
			if(IsClientInGame(target) && IsPlayerAlive(target) && IsFakeClient(target))
			{
				bot = target;
				break;
			}
		}
		
		if(bot != 0)
		{
			SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", bot);
			SetEntProp(client, Prop_Send, "m_iObserverMode", 4);
		}
	}
	
	return Plugin_Handled;
}

// Move stuck players
public Action SM_Move(int client, int args)
{
	AdminFlag flag = Admin_Config;
	Timer_GetAdminFlag("basic", flag);
	
	if(!GetAdminFlag(GetUserAdmin(client), flag))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if(args != 0)
	{
		char name[MAX_NAME_LENGTH];
		GetCmdArgString(name, sizeof(name));
		
		int target = FindTarget(client, name, true, false);
		
		if(target != -1)
		{
			MoveStuckTarget(client, target);
		}
	}
	else
	{
		OpenMoveMenu(client);
	}
	
	return Plugin_Handled;
}

void OpenMoveMenu(int client)
{
	Menu menu = new Menu(Menu_Move);
	menu.SetTitle("Move a stuck player:");
	menu.AddItem("sel", "Targeted player");
	
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && !IsFakeClient(target))
		{
			char sName[MAX_NAME_LENGTH], sUserId[8];
			GetClientName(target, sName, sizeof(sName));
			FormatEx(sUserId, sizeof(sUserId), "%d", GetClientUserId(target));
			
			menu.AddItem(sUserId, sName);
		}
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Move(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "sel"))
		{
			if(IsPlayerAlive(client))
			{
				MoveStuckTarget(client, client);
			}
			else
			{
				int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				
				if((0 < target <= MaxClients) && IsClientInGame(target))
				{
					MoveStuckTarget(client, target);
				}
			}
		}
		else
		{
			int target = GetClientOfUserId(StringToInt(sInfo));
			
			if(target != 0)
			{
				MoveStuckTarget(client, target);
			}
			else
			{
				PrintColorText(client, "%s%sSelected player is no longer ingame.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		
		OpenMoveMenu(client);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			if(LibraryExists("adminmenu") && param2 == MenuCancel_ExitBack)
			{
				AdminFlag Flag = Admin_Custom5;
				Timer_GetAdminFlag("adminmenu", Flag);
				if(GetAdminFlag(GetUserAdmin(client), Flag))
				{
					TopMenuObject TimerCommands = FindTopMenuCategory(GetAdminTopMenu(), "TimerCommands");
					if(TimerCommands != INVALID_TOPMENUOBJECT)
					{
						DisplayTopMenuCategory(GetAdminTopMenu(), TimerCommands, client);
					}
				}
			}
		}
	}
}

void MoveStuckTarget(int client, int target)
{
	float angles[3], pos[3];
	GetClientEyeAngles(target, angles);
	GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos);
	
	for(int i; i < 3; i++)
		pos[i] += (angles[i] * 50);
	
	TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
	
	if(IsBeingTimed(target, TIMER_ANY))
	{
		Timer_Log(false, "%L moved %L with a timer", client, target);
	}
	else
	{
		Timer_Log(false, "%L moved %L without a timer", client, target);
	}
	
	PrintColorTextAll("%s%s%N%s moved %s%N%s.",
		g_msg_start,
		g_msg_varcol,
		client, 
		g_msg_textcol,
		g_msg_varcol,
		target,
		g_msg_varcol);
	
}

public Action SM_Admins(int client, int args)
{
	if(!Timer_ClientHasTimerFlag(client, "basic", Admin_Generic))
	{
		return Plugin_Continue;
	}
	
	if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		PrintToChat(client, "[SM] Check console for admin list");
	}
	
	char sFlag[32];
	int cFlag;
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsClientInGame(target) && IsClientAuthorized(target))
		{
			sFlag[0] = '\0';
			int flags = GetAdminFlags(GetUserAdmin(target), Access_Effective);
			
			for(int adminFlag = 0; adminFlag < AdminFlags_TOTAL; adminFlag++)
			{
				FindFlagChar(view_as<AdminFlag>(adminFlag), cFlag);
				if(flags & (1 << adminFlag))
				{
					Format(sFlag, sizeof(sFlag), "%s%s", sFlag, cFlag);
				}
			}
			
			if(strlen(sFlag) > 0)
			{
				PrintToConsole(client, "%N: %s", target, sFlag);
			}
		}
	}
	
	return Plugin_Handled;
}

// Display current map session time
public Action SM_Maptime(int client, int args)
{
	float mapTime = GetEngineTime() - g_fMapStart;
	int hours, minutes, seconds;
	hours    = RoundToFloor(mapTime/3600);
	mapTime -= (hours * 3600);
	minutes  = RoundToFloor(mapTime/60);
	mapTime -= (minutes * 60);
	seconds  = RoundToFloor(mapTime);
	
	PrintColorText(client, "%s%sMaptime: %s%d%s %s, %s%d%s %s, %s%d%s %s",
		g_msg_start,
		g_msg_textcol,
		g_msg_varcol,
		hours,
		g_msg_textcol,
		(hours==1)?"hour":"hours", 
		g_msg_varcol,
		minutes,
		g_msg_textcol,
		(minutes==1)?"minute":"minutes", 
		g_msg_varcol,
		seconds, 
		g_msg_textcol,
		(seconds==1)?"second":"seconds");
}

public void Menu_Sound(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if(action == CookieMenuAction_SelectOption)
	{
		if(info == 1)
		{
			SetCookieBool(client, g_hGunSoundCookie, !GetCookieBool(client, g_hGunSoundCookie));
			
			if(GetCookieBool(client, g_hGunSoundCookie) == true)
			{
				PrintColorText(client, "%s%sGun sounds enabled.", 
					g_msg_start,
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%sGun sounds disabled.", 
					g_msg_start,
					g_msg_textcol);
			}
			
			CheckHooks();
		}
		else if(info == 2)
		{
			SetCookieBool(client, g_hMusicCookie, !GetCookieBool(client, g_hMusicCookie));
			
			if(!GetCookieBool(client, g_hMusicCookie))
			{
				char sSound[128];
				for (int i; i < g_iNumSounds; i++)
				{
					int ientity = EntRefToEntIndex(g_iSoundEnts[i]);
					
					if (ientity != INVALID_ENT_REFERENCE)
					{
						GetEntPropString(ientity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
						EmitSoundToClient(client, sSound, ientity, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
					}
				}

				PrintColorText(client, "%s%sMusic disabled.", 
					g_msg_start,
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%sMusic enabled.", 
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
}

public void Menu_StopSound(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action SoundscapeUpdateForPlayer(int soundscape, int client)
{
    if(!IsValidEntity(soundscape) || !IsValidEdict(soundscape))
        return Plugin_Continue;
       
    char sScape[64];
       
    GetEdictClassname(soundscape, sScape, sizeof(sScape));
   
    if(!StrEqual(sScape,"env_soundscape") && !StrEqual(sScape,"env_soundscape_triggerable") && !StrEqual(sScape,"env_soundscape_proxy"))
        return Plugin_Continue;
   
    if(0 < client <= MaxClients && !GetCookieBool(client, g_hMusicCookie))
    {
        return Plugin_Handled;
    }
       
    return Plugin_Continue;
}

public Action SM_Speed(int client, int args)
{
	if(args == 1)
	{
		// Get the specified speed
		char sArg[250];
		GetCmdArgString(sArg, sizeof(sArg));
		
		float fSpeed = StringToFloat(sArg);
		
		// Check if the speed value is in a valid range
		if(!(0 <= fSpeed <= 100))
		{
			PrintColorText(client, "%s%sYour speed must be between 0 and 100",
				g_msg_start,
				g_msg_textcol);
			return Plugin_Handled;
		}
		
		if(!(g_bTasPluginLoaded && TAS_InEditMode(client)))
		{
			StopTimer(client);
		}
		
		
		// Set the speed
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fSpeed);
		
		// Notify them
		PrintColorText(client, "%s%sSpeed changed to %s%f%s%s",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			fSpeed,
			g_msg_textcol,
			(fSpeed != 1.0)?" (Default is 1)":" (Default)");
	}
	else
	{
		// Show how to use the command
		PrintColorText(client, "%s%sExample: sm_speed 2.0",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action SM_Fast(int client, int args)
{
	StopTimer(client);
	
	// Set the speed
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 2.0);
	
	return Plugin_Handled;
}

public Action SM_Slow(int client, int args)
{
	StopTimer(client);
	
	// Set the speed
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.5);
	
	return Plugin_Handled;
}

public Action SM_Normalspeed(int client, int args)
{
	StopTimer(client);
	
	// Set the speed
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	
	return Plugin_Handled;
}

public Action SM_Lowgrav(int client, int args)
{
	if(g_bTasPluginLoaded == true)
	{
		if(TAS_InEditMode(client))
		{
			PrintColorText(client, "%s%sYou can't change your gravity in TAS mode.",
				g_msg_start,
				g_msg_textcol);
				
			return Plugin_Handled;
		}
	}
	StopTimer(client);
	
	SetEntityGravity(client, 0.6);
	
	PrintColorText(client, "%s%sUsing low gravity. Use !normalgrav to switch back to normal gravity.",
		g_msg_start,
		g_msg_textcol);
	return Plugin_Handled;
}

public Action SM_Normalgrav(int client, int args)
{
	if(g_bTasPluginLoaded == true)
	{
		if(TAS_InEditMode(client))
		{
			PrintColorText(client, "%s%sYou can't change your gravity in TAS mode.",
				g_msg_start,
				g_msg_textcol);
				
			return Plugin_Handled;
		}
	}
	StopTimer(client);

	SetEntityGravity(client, 0.0);
	
	PrintColorText(client, "%s%sUsing normal gravity.",
		g_msg_start,
		g_msg_textcol);
	
	return Plugin_Handled;
}

public Action SM_Stuck(int client, int args)
{
	float vPos[3], vEyePos[3];
	Entity_GetAbsOrigin(client, vPos);
	GetClientEyePosition(client, vEyePos);
	vEyePos[2] += 1.0;
	
	float vMins[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", vMins);

	float vMaxs[3];
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", vMaxs);
	vMaxs[2] = 1.0;
	
	//PrintToChat(client, "%f %f", vMins[2], vMaxs[2]);
	
	bool stuckFeet = view_as<bool>(TR_PointOutsideWorld(vPos));
	bool stuckHead = view_as<bool>(TR_PointOutsideWorld(vEyePos));
	if(stuckFeet && !stuckHead)
	{
		TR_TraceRayFilter(vEyePos, view_as<float>({90.0, 0.0, 0.0}), MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
		
		if(TR_DidHit())
		{
			float vEndPos[3];
			TR_GetEndPosition(vEndPos);
			
			TeleportEntity(client, vEndPos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
			StopTimer(client);
		}
		else
		{
			PrintColorText(client, "%s%sYour gonna need an admin to get out of this bind buddy.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else if(stuckHead && !stuckFeet)
	{
		TR_TraceRayFilter(vPos, view_as<float>({-90.0, 0.0, 0.0}), MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
		
		if(TR_DidHit())
		{
			float vEndPos[3];
			TR_GetEndPosition(vEndPos);
			vEndPos[2] -= 95.0;
			
			TeleportEntity(client, vEndPos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
			StopTimer(client);
		}
		else
		{
			PrintColorText(client, "%s%sYour gonna need an admin to get out of this bind buddy.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else if(!stuckFeet && !stuckHead)
	{		
		TR_TraceHullFilter(vEyePos, vPos, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceRayDontHitSelf, client);
		
		if(TR_DidHit())
		{
			float vEndPos[3];
			TR_GetEndPosition(vEndPos);
			
			if(vPos[2] <= vEndPos[2] <= vEyePos[2])
			{
				TeleportEntity(client, vEndPos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
				StopTimer(client);
				
				return Plugin_Handled;
			}
		}
		
		TR_TraceHullFilter(vPos, vEyePos, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceRayDontHitSelf, client);
		
		if(TR_DidHit())
		{
			float vEndPos[3];
			TR_GetEndPosition(vEndPos);
			
			if(vPos[2] <= vEndPos[2] <= vEyePos[2])
			{
				vEndPos[2] -= 74.0;
				TeleportEntity(client, vEndPos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
				StopTimer(client);
				
				return Plugin_Handled;
			}
		}
		
		PrintColorText(client, "%s%sCan't tell if you're actually stuck or not, sorry :D.",
			g_msg_start,
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%sYour gonna need an admin to get out of this bind buddy.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

public Action Hook_SetTransmit(int entity, int client)
{
	if(client != entity)
	{
		if(0 < entity <= MaxClients)
		{
			if(IsPlayerAlive(client))
			{
				if(GetCookieBool(client, g_hHideCookie))
					return Plugin_Handled;
		
				//if(GetEntityMoveType(entity) == MOVETYPE_NOCLIP && !IsFakeClient(entity))
				//	return Plugin_Handled;
			
				if(!IsPlayerAlive(entity))
					return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(GetEngineVersion() == Engine_CSS)
	{
		SetEntPropVector(victim, Prop_Send, "m_vecPunchAngle", NULL_VECTOR);
		SetEntPropVector(victim, Prop_Send, "m_vecPunchAngleVel", NULL_VECTOR);
	}
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(g_bUncrouch[client] == true)
	{
		g_bUncrouch[client] = false;
		SetEntityFlags(client, GetEntityFlags(client) & ~FL_DUCKING);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
