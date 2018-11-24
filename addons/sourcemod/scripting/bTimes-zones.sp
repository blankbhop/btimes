#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[Timer] - Zones",
	author = "blacky",
	description = "Used to create map zones",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <smlib/entities>
#include <bTimes-timer>
#include <bTimes-zones>
#include <csgocolors>
#include <smlib>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required

Database g_DB;
Handle g_MapList;
char g_sMapName[PLATFORM_MAX_PATH];
float g_fSpawnPos[3];

int	g_Properties[ZONE_COUNT][ZoneProperties]; // Properties for each type of zone
	
bool   g_InZonesMenu[MAXPLAYERS + 1];
bool   g_InSetFlagsMenu[MAXPLAYERS + 1];
int    g_CurrentZone[MAXPLAYERS + 1];
Handle g_SetupTimer[MAXPLAYERS + 1];
bool   g_bSnapping[MAXPLAYERS + 1];
int    g_GridSnap[MAXPLAYERS + 1];
bool   g_ViewAnticheats[MAXPLAYERS + 1];
bool   g_bViewSlideZones[MAXPLAYERS + 1];
bool   g_DisableTriggers[MAXPLAYERS + 1];
float  g_fWarningTime[MAXPLAYERS + 1];

EngineVersion g_Engine;

int	  g_Entities_ZoneType[2048] = {-1, ...}; // For faster lookup of zone type by entity number
int	  g_Entities_ZoneNumber[2048] = {-1, ...}; // For faster lookup of zone number by entity number
float g_Zones[ZONE_COUNT][64][8][3]; // Zones that have been created
int	  g_TotalZoneCount;
bool  g_bZonesLoaded;
	
bool g_bInside[MAXPLAYERS + 1][ZONE_COUNT][64];

int	g_SnapModelIndex;
int	g_SnapHaloIndex;

// Cvars
ConVar g_hZoneEnabled[ZONE_COUNT];
ConVar g_hZoneColor[ZONE_COUNT];
ConVar g_hZoneOffset[ZONE_COUNT];
ConVar g_hZoneTexture[ZONE_COUNT];
ConVar g_hZoneTrigger[ZONE_COUNT];
ConVar g_hZoneSpeed[ZONE_COUNT];
ConVar g_hRestartTime;
	
// Forwards
Handle g_fwdOnZonesLoaded;
Handle g_fwdOnZoneStartTouch;
Handle g_fwdOnZoneEndTouch;
Handle g_fwdOnTeleportToZone;

ArrayList g_hZoneDrawList;
int       g_LastDrawnZone;

public void OnPluginStart()
{
	// Connect to database
	DB_Connect();
	
	// Cvars
	g_hZoneEnabled[MAIN_START]  = CreateConVar("timer_mainstart_enable", "1", "Enables use of the main start zone.", 0, true, 0.0, true, 1.0);
	g_hZoneEnabled[MAIN_END]    = CreateConVar("timer_mainend_enable", "1", "Enables use of the main end zone.", 0, true, 0.0, true, 1.0);
	g_hZoneEnabled[BONUS_START] = CreateConVar("timer_bonusstart_enable", "1", "Enables use of the bonus start zone.", 0, true, 0.0, true, 1.0);
	g_hZoneEnabled[BONUS_END]   = CreateConVar("timer_bonusend_enable", "1", "Enables use of the bonus end zone.", 0, true, 0.0, true, 1.0);
	g_hZoneEnabled[ANTICHEAT]   = CreateConVar("timer_ac_enable", "1", "Enables use of the anti-cheat zone.", 0, true, 0.0, true, 1.0);
	g_hZoneEnabled[FREESTYLE]   = CreateConVar("timer_fs_enable", "1", "Enables use of the freestyle zone.", 0, true, 0.0, true, 1.0);
	g_hZoneEnabled[SLIDE]       = CreateConVar("timer_slide_enable", "1", "Enables use of the sliding zone.", 0, true, 0.0, true, 1.0);
	
	g_hZoneColor[MAIN_START]    = CreateConVar("timer_mainstart_color", "0 255 0 255", "Set the main start zone's RGBA color.");
	g_hZoneColor[MAIN_END]      = CreateConVar("timer_mainend_color", "255 0 0 255", "Set the main end zone's RGBA color.");
	g_hZoneColor[BONUS_START]   = CreateConVar("timer_bonusstart_color", "0 255 0 255", "Set the bonus start zone's RGBA color.");
	g_hZoneColor[BONUS_END]     = CreateConVar("timer_bonusend_color", "255 0 0 255", "Set the bonus end zone's RGBA color.");
	g_hZoneColor[ANTICHEAT]     = CreateConVar("timer_ac_color", "255 255 0 255", "Set the anti-cheat zone's RGBA color.");
	g_hZoneColor[FREESTYLE]     = CreateConVar("timer_fs_color", "0 0 255 255", "Set the freestyle zone's RGBA color.");
	g_hZoneColor[SLIDE]         = CreateConVar("timer_slide_color", "153 204 255 255", "Set the sliding zone's RGBA color.");
	
	g_hZoneOffset[MAIN_START]   = CreateConVar("timer_mainstart_offset", "128", "Set the the default height for the main start zone.");
	g_hZoneOffset[MAIN_END]     = CreateConVar("timer_mainend_offset", "128", "Set the the default height for the main end zone.");
	g_hZoneOffset[BONUS_START]  = CreateConVar("timer_bonusstart_offset", "128", "Set the the default height for the bonus start zone.");
	g_hZoneOffset[BONUS_END]    = CreateConVar("timer_bonusend_offset", "128", "Set the the default height for the bonus end zone.");
	g_hZoneOffset[ANTICHEAT]    = CreateConVar("timer_ac_offset", "0", "Set the the default height for the anti-cheat zone.");
	g_hZoneOffset[FREESTYLE]    = CreateConVar("timer_fs_offset", "0", "Set the the default height for the freestyle zone.");
	g_hZoneOffset[SLIDE]        = CreateConVar("timer_slide_offset", "32", "Set the default height for the sliding zone");
	
	g_hZoneTexture[MAIN_START]  = CreateConVar("timer_mainstart_tex", "materials/sprites/bluelaser1", "Texture for main start zone. (Exclude the file types like .vmt/.vtf)");
	g_hZoneTexture[MAIN_END]    = CreateConVar("timer_mainend_tex", "materials/sprites/bluelaser1", "Texture for main end zone.");
	g_hZoneTexture[BONUS_START] = CreateConVar("timer_bonusstart_tex", "materials/sprites/bluelaser1", "Texture for bonus start zone.");
	g_hZoneTexture[BONUS_END]   = CreateConVar("timer_bonusend_tex", "materials/sprites/bluelaser1", "Texture for main end zone.");
	g_hZoneTexture[ANTICHEAT]   = CreateConVar("timer_ac_tex", "materials/sprites/bluelaser1", "Texture for anti-cheat zone.");
	g_hZoneTexture[FREESTYLE]   = CreateConVar("timer_fs_tex", "materials/sprites/bluelaser1", "Texture for freestyle zone.");
	g_hZoneTexture[SLIDE]       = CreateConVar("timer_slide_tex", "materials/sprites/bluelaser1", "Texture for the slide zone.");
	
	g_hZoneTrigger[MAIN_START]  = CreateConVar("timer_mainstart_trigger", "0", "Main start zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[MAIN_END]    = CreateConVar("timer_mainend_trigger", "0", "Main end zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[BONUS_START] = CreateConVar("timer_bonusstart_trigger", "0", "Bonus start zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[BONUS_END]   = CreateConVar("timer_bonusend_trigger", "0", "Bonus end zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[ANTICHEAT]   = CreateConVar("timer_ac_trigger", "1", "Anti-cheat zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[FREESTYLE]   = CreateConVar("timer_fs_trigger", "1", "Freestyle zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[SLIDE]       = CreateConVar("timer_slide_trigger", "1", "Slide zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	
	g_hZoneSpeed[MAIN_START]    = CreateConVar("timer_mainstart_speed", "0", "Main start zone texture scrolling speed.", 0, true, 0.0, true, 100.0);
	g_hZoneSpeed[MAIN_END]      = CreateConVar("timer_mainend_speed", "0", "Main end zone texture scrolling speed.", 0, true, 0.0, true, 100.0);
	g_hZoneSpeed[BONUS_START]   = CreateConVar("timer_bonusstart_speed", "0", "Bonus start zone texture scrolling speed.", 0, true, 0.0, true, 100.0);
	g_hZoneSpeed[BONUS_END]     = CreateConVar("timer_bonusend_speed", "0", "Bonus end zone texture scrolling speed.", 0, true, 0.0, true, 100.0);
	g_hZoneSpeed[ANTICHEAT]     = CreateConVar("timer_ac_speed", "0", "Anti-cheat zone texture scrolling speed.", 0, true, 0.0, true, 100.0);
	g_hZoneSpeed[FREESTYLE]     = CreateConVar("timer_fs_speed", "0", "Freestyle zone texture scrolling speed.", 0, true, 0.0, true, 100.0);
	g_hZoneSpeed[SLIDE]         = CreateConVar("timer_slide_speed", "0", "Slide zone texture scrolling speed.", 0, true, 0.0, true, 100.0);
	
	g_hRestartTime    = CreateConVar("timer_restartmenutime", "5", "Minimum time on a player's timer when they are given the 'Are you sure you want to noclip?' menu prompt if they try to noclip, to prevent players from accidentally ruining their time", 0, true, 0.0);
	
	AutoExecConfig(true, "zones", "timer");
	
	// Hook changes
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		HookConVarChange(g_hZoneColor[Zone], OnZoneColorChanged);
		HookConVarChange(g_hZoneOffset[Zone], OnZoneOffsetChanged);	
		HookConVarChange(g_hZoneTrigger[Zone], OnZoneTriggerChanged);
		HookConVarChange(g_hZoneSpeed[Zone], OnZoneSpeedChanged);
		HookConVarChange(g_hZoneEnabled[Zone], OnZoneEnabledChanged);
	}
	
	// Admin Commands
	RegConsoleCmd("sm_zones", SM_Zones, "Opens the zones menu.");
	RegConsoleCmd("sm_nozone", SM_NoZone, "Shows a list of maps that don't have zones yet.");
	
	// Player Commands
	RegConsoleCmdEx("sm_b", SM_B, "Teleports you to the bonus zone");
	RegConsoleCmdEx("sm_bonus", SM_B, "Teleports you to the bonus zone");
	RegConsoleCmdEx("sm_br", SM_B, "Teleports you to the bonus zone");
	RegConsoleCmdEx("sm_r", SM_R, "Teleports you to your last starting zone");
	RegConsoleCmdEx("sm_restart", SM_R, "Teleports you to your last starting zone");
	RegConsoleCmdEx("sm_start", SM_R, "Teleports you to the main start zone.");
	RegConsoleCmdEx("sm_end", SM_End, "Teleports your to the end zone");
	RegConsoleCmdEx("sm_endb", SM_EndB, "Teleports you to the bonus end zone");
	
	// Command listeners for easier team joining
	AddCommandListener(Command_JoinTeam, "spectate");
	AddCommandListener(Command_JoinTeam, "jointeam");
	
	// Events
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart);
	
	// Translations
	LoadTranslations("core.phrases");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Natives
	CreateNative("Timer_InsideZone", Native_InsideZone);
	CreateNative("Timer_IsPointInsideZone", Native_IsPointInsideZone);
	CreateNative("Timer_TeleportToZone", Native_TeleportToZone);
	CreateNative("Timer_GetZoneCount", Native_GetZoneCount);
	CreateNative("Timer_AreZonesLoaded", Native_AreZonesLoaded);
	
	// Forwards
	g_fwdOnZonesLoaded    = CreateGlobalForward("OnZonesLoaded", ET_Event);
	g_fwdOnZoneStartTouch = CreateGlobalForward("OnZoneStartTouch", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnZoneEndTouch   = CreateGlobalForward("OnZoneEndTouch", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTeleportToZone = CreateGlobalForward("OnTeleportToZone", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	
	RegPluginLibrary("timer-zones");
	
	if(late)
	{
		UpdateMessages();
	}
	
	return APLRes_Success;
}

bool g_bAnticheatLoaded;

public void OnAllPluginsLoaded()
{
	g_bAnticheatLoaded = LibraryExists("ac");
}

public void OnLibraryRemoved(const char[] library)
{
	if(StrEqual(library, "ac"))
	{
		g_bAnticheatLoaded = false;
	}
}

public void OnLibraryAdded(const char[] library)
{
	if(StrEqual(library, "ac"))
	{
		g_bAnticheatLoaded = true;
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(0 < client <= MaxClients)
	{
		if(sArgs[0] == '!' || sArgs[0] == '/')
		{
			if(sArgs[1] == 'R')
			{
				FakeClientCommand(client, "sm_r");
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

void TeleportToZone(int client, int Zone, int ZoneNumber, bool bottom = false)
{
	StopTimer(client);
	
	if(g_Properties[Zone][zReady][ZoneNumber] == true)
	{
		float vMiddle[3];
		GetZonePosition(Zone, ZoneNumber, vMiddle);
		
		float vBottom[3];
		Array_Copy(vMiddle, vBottom, sizeof vBottom);
		
		if(g_Zones[Zone][ZoneNumber][0][2] <= g_Zones[Zone][ZoneNumber][7][2])
			vBottom[2] = g_Zones[Zone][ZoneNumber][0][2];
		else
			vBottom[2] = g_Zones[Zone][ZoneNumber][7][2];
			
		if(bottom)
		{
			float vTop[3];
			Array_Copy(vBottom, vTop, sizeof vTop);
			vTop[2] += 72.0;
			
			float vMins[3], vMaxs[3];
			GetEntPropVector(client, Prop_Send, "m_vecMins", vMins);
			GetEntPropVector(client, Prop_Send, "m_vecMaxs", vMaxs);
				
			TR_TraceHullFilter(vTop, vBottom, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceRayDontHitSelf, client);
			
			if(TR_DidHit())
			{
				TR_GetEndPosition(vBottom);
			}
		}
		else
		{
			vBottom[2] += (FloatAbs(g_Zones[Zone][ZoneNumber][0][2] - g_Zones[Zone][ZoneNumber][7][2]) / 2.0);
			float vPos[3], vEyePos[3];
			Entity_GetAbsOrigin(client, vPos);
			GetClientEyePosition(client, vEyePos);
			vBottom[2] -= (vEyePos[2] - vPos[2]);
		}
		
		if(g_bAnticheatLoaded && Style(TimerInfo(client).GetStyle(TimerInfo(client).Type)).HasSpecialKey("ac"))
		{
			float vAng[3];
			GetClientEyeAngles(client, vAng);
			vAng[1] = GetRandomFloat(-180.0, 180.0);
			TeleportEntity(client, vBottom, vAng, view_as<float>({0.0, 0.0, 0.0}));
		}
		else
		{
			TeleportEntity(client, vBottom, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		}
		
	}
	else
	{
		TeleportEntity(client, g_fSpawnPos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
	}
	
	Call_StartForward(g_fwdOnTeleportToZone);
	Call_PushCell(client);
	Call_PushCell(Zone);
	Call_PushCell(ZoneNumber);
	Call_Finish();
}

public void OnMapStart()
{
	if(g_MapList != INVALID_HANDLE)
		CloseHandle(g_MapList);
	
	g_MapList = ReadMapList();
	
	if(g_hZoneDrawList == INVALID_HANDLE)
	{
		g_hZoneDrawList = CreateArray(2);
	}
	
	ClearArray(g_hZoneDrawList);
	
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	g_SnapHaloIndex = PrecacheModel("materials/sprites/light_glow02.vmt");
	g_SnapModelIndex = PrecacheModel("materials/sprites/bluelaser1.vmt");
	PrecacheModel("materials/sprites/bluelaser1.vmt");
	AddFileToDownloadsTable("materials/sprites/bluelaser1.vmt");
	AddFileToDownloadsTable("materials/sprites/bluelaser1.vtf");
	
	PrecacheModel("models/props/cs_office/vending_machine.mdl");
	
	CreateTimer(0.1, Timer_SnapPoint, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0, Timer_DrawBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Check for t/ct spawns
	int t  = FindEntityByClassname(-1, "info_player_terrorist");
	int ct = FindEntityByClassname(-1, "info_player_counterterrorist");
	
	// Set map team and get spawn position
	if(t != -1)
		Entity_GetAbsOrigin(t, g_fSpawnPos);
	else
		Entity_GetAbsOrigin(ct, g_fSpawnPos);
		
	g_bZonesLoaded = false;
	
	ServerCommand("exec timer/zones.cfg");
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		UpdateZoneBeamTexture(Zone);
		UpdateZoneSpriteTexture(Zone);
	}
}

public void OnMapIDPostCheck()
{
	DB_LoadZones();
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	InitializePlayerProperties(client);
	
	return true;
}

public void OnConfigsExecuted()
{
	InitializeZoneProperties();
	//CreateTimer(1.0, Timer_InitializeZoneProps);
	ResetEntities();
}

/*
public Action Timer_InitializeZoneProps(Handle timer, any data)
{
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		UpdateZoneBeamTexture(Zone);
		UpdateZoneSpriteTexture(Zone);
	}
}
*/

public void OnClientDisconnect(int client)
{
	g_CurrentZone[client]    = -1;
	g_InZonesMenu[client]    = false;
	g_InSetFlagsMenu[client] = false;
}

public void OnZoneColorChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		if(g_hZoneColor[Zone] == convar)
		{
			UpdateZoneColor(Zone);
			break;
		}
	}
}

public void OnZoneOffsetChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		if(g_hZoneOffset[Zone] == convar)
		{
			g_Properties[Zone][zOffset] = StringToInt(newValue);
			break;
		}
	}
}

public void OnZoneTriggerChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		if(g_hZoneTrigger[Zone] == convar)
		{
			g_Properties[Zone][zTriggerBased] = view_as<bool>(StringToInt(newValue));
			break;
		}
	}
}

public void OnZoneSpeedChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		if(g_hZoneSpeed[Zone] == convar)
		{
			g_Properties[Zone][zSpeed] = view_as<bool>(StringToInt(newValue));
			break;
		}
	}
}

public void OnZoneEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		if(g_hZoneEnabled[Zone] == convar)
		{
			g_Properties[Zone][zEnabled] = view_as<bool>(StringToInt(newValue));
			break;
		}
	}
}

void InitializeZoneProperties()
{
	g_TotalZoneCount     = 0;
	
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		GetZoneName(Zone, g_Properties[Zone][zName], 64);
		UpdateZoneColor(Zone);
		g_Properties[Zone][zEnabled]      = GetConVarBool(g_hZoneEnabled[Zone]);
		g_Properties[Zone][zOffset]       = GetConVarInt(g_hZoneOffset[Zone]);
		g_Properties[Zone][zTriggerBased] = GetConVarBool(g_hZoneTrigger[Zone]);
		g_Properties[Zone][zSpeed]        = GetConVarInt(g_hZoneSpeed[Zone]);
		g_Properties[Zone][zCount]        = 0;
		
		switch(Zone)
		{
			case MAIN_START, MAIN_END, BONUS_START, BONUS_END:
			{
				g_Properties[Zone][zMax]         = 1;
				g_Properties[Zone][zReplaceable] = true;
			}
			case ANTICHEAT, FREESTYLE, SLIDE:
			{
				g_Properties[Zone][zMax]         = 64;
				g_Properties[Zone][zReplaceable] = false;
			}
		}
		
		for(int i; i < g_Properties[Zone][zMax]; i++)
		{
			g_Properties[Zone][zReady][i]         = false;
			g_Properties[Zone][zRowID][i]         = 0;
			g_Properties[Zone][zEntity][i]        = -1;
			g_Properties[Zone][zFs_Unrestrict][i] = 0;
			g_Properties[Zone][zFs_EzHop][i]      = 0;
			g_Properties[Zone][zFs_Auto][i]       = 0;
			g_Properties[Zone][zFs_NoLimit][i]    = 0;
			g_Properties[Zone][zAc_Type][i]       = 0;
		}
	}
}

void InitializePlayerProperties(int client)
{
	g_CurrentZone[client]     = -1;
	g_ViewAnticheats[client]  = false;
	g_bSnapping[client]       = true;
	g_GridSnap[client]        = 64;
	g_InZonesMenu[client]     = false;
	g_InSetFlagsMenu[client]  = false;
	g_DisableTriggers[client] = false;
	g_bViewSlideZones[client] = false;
}

void GetZoneName(int Zone, char[] buffer, int maxlength)
{
	switch(Zone)
	{
		case MAIN_START:
		{
			FormatEx(buffer, maxlength, "Main Start");
		}
		case MAIN_END:
		{
			FormatEx(buffer, maxlength, "Main End");
		}
		case BONUS_START:
		{
			FormatEx(buffer, maxlength, "Bonus Start");
		}
		case BONUS_END:
		{
			FormatEx(buffer, maxlength, "Bonus End");
		}
		case ANTICHEAT:
		{
			FormatEx(buffer, maxlength, "Anti-cheat");
		}
		case FREESTYLE:
		{
			FormatEx(buffer, maxlength, "Freestyle");
		}
		case SLIDE:
		{
			FormatEx(buffer, maxlength, "Slide");
		}
		default:
		{
			FormatEx(buffer, maxlength, "Unknown");
		}
	}
}

void UpdateZoneColor(int Zone)
{
	char sColor[32], sColorExp[4][8];
	
	GetConVarString(g_hZoneColor[Zone], sColor, sizeof(sColor));
	ExplodeString(sColor, " ", sColorExp, 4, 8);
	
	for(int idx; idx < 4; idx++)
		g_Properties[Zone][zColor][idx] = StringToInt(sColorExp[idx]);
}

void UpdateZoneBeamTexture(int Zone)
{
	char sTexture[PLATFORM_MAX_PATH];
	GetConVarString(g_hZoneTexture[Zone], sTexture, sizeof(sTexture));
	
	char sPrecache[PLATFORM_MAX_PATH];
	FormatEx(sPrecache, sizeof(sPrecache), "%s.vmt", sTexture);
	g_Properties[Zone][zModelIndex] = PrecacheModel(sPrecache);
	
	char sDownload[PLATFORM_MAX_PATH];
	FormatEx(sDownload, sizeof(sDownload), "%s.vmt", sTexture);
	AddFileToDownloadsTable(sDownload);
	
	FormatEx(sDownload, sizeof(sDownload), "%s.vtf", sTexture);
	AddFileToDownloadsTable(sDownload);
}

void UpdateZoneSpriteTexture(int Zone)
{
	char sSprite[PLATFORM_MAX_PATH];
	
	FormatEx(sSprite, sizeof(sSprite), "materials/sprites/light_glow02.vmt");
	
	g_Properties[Zone][zHaloIndex] = PrecacheModel(sSprite);
}

void ResetEntities()
{
	for(int entity; entity < 2048; entity++)
	{
		g_Entities_ZoneType[entity]   = -1;
		g_Entities_ZoneNumber[entity] = -1;
	}
}

// Might remove this or place into a separate plugin
public Action Command_JoinTeam(int client, char[] command, int argc)
{
	if(StrEqual(command, "jointeam"))
	{
		char sArg[192];
		GetCmdArgString(sArg, sizeof(sArg));
		
		int team = StringToInt(sArg);
		
		if(team == 2 || team == 3)
		{
			CS_SwitchTeam(client, team);
			CS_RespawnPlayer(client);
		}
		else if(team == 0)
		{
			CS_SwitchTeam(client, GetRandomInt(2, 3));
			CS_RespawnPlayer(client);
		}
		else if(team == 1)
		{
			ForcePlayerSuicide(client);
			ChangeClientTeam(client, 1);
		}
	}
	else // spectate command
	{
		ForcePlayerSuicide(client);
		ChangeClientTeam(client, 1);
	}
	
	return Plugin_Handled;
}

public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsClientInGame(client))
	{
		if(g_Properties[MAIN_START][zReady][0] == true)
		{
			TeleportToZone(client, MAIN_START, 0, true);
		}
		else
		{
			TeleportEntity(client, g_fSpawnPos, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	return Plugin_Continue;
}

public Action SM_R(int client, int args)
{
	if(g_Properties[MAIN_START][zReady][0] == true)
	{
		if(IsBeingTimed(client, TIMER_ANY) && (TimerInfo(client).CurrentTime / 60) > g_hRestartTime.IntValue)
		{
			RestartRequestMenu(client, MAIN_START);
		}
		else
		{
			StopTimer(client);
		
			if(!IsPlayerAlive(client))
			{
				SetEntProp(client, Prop_Data, "m_iObserverMode", 6);
			}
			TeleportToZone(client, MAIN_START, 0, IsPlayerAlive(client));
			
			if(Style(TimerInfo(client).GetStyle(TimerInfo(client).Type)).HasSpecialKey("parkour"))
			{
				SetEntProp(client, Prop_Data, "m_ArmorValue", 100);
			}
		}
	}
	else
	{
		char sZone[64];
		GetZoneName(MAIN_START, sZone, sizeof(sZone));
		PrintColorText(client, "%s%sThe %s%s%s is not ready yet.",
			g_msg_start,
			g_msg_varcol,
			sZone,
			g_msg_textcol,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action SM_End(int client, int args)
{
	if(g_Properties[MAIN_END][zReady][0] == true)
	{
		StopTimer(client);
		
		if(!IsPlayerAlive(client))
		{
			SetEntProp(client, Prop_Data, "m_iObserverMode", 6);
		}
		TeleportToZone(client, MAIN_END, 0, IsPlayerAlive(client));
	}
	else
	{
		PrintColorText(client, "%s%sThe main end zone is not ready yet.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action SM_B(int client, int args)
{
	if(g_Properties[BONUS_START][zReady][0] == true)
	{
		if(IsBeingTimed(client, TIMER_ANY) && (TimerInfo(client).CurrentTime / 60) > g_hRestartTime.IntValue)
		{
			RestartRequestMenu(client, BONUS_START);
		}
		else
		{
			StopTimer(client);
		
			if(!IsPlayerAlive(client))
			{
				SetEntProp(client, Prop_Data, "m_iObserverMode", 6);
			}
			TeleportToZone(client, BONUS_START, 0, IsPlayerAlive(client));
			
			if(Style(TimerInfo(client).GetStyle(TimerInfo(client).Type)).HasSpecialKey("parkour"))
			{
				SetEntProp(client, Prop_Data, "m_ArmorValue", 100);
			}
			
			if(g_Properties[BONUS_END][zReady][0] == true)
			{
				StartTimer(client, TIMER_BONUS);
			}
		}
	}
	else
	{
		PrintColorText(client, "%s%sThe bonus zone has not been created.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action SM_EndB(int client, int args)
{
	if(g_Properties[BONUS_END][zReady][0] == true)
	{
		StopTimer(client);
		
		if(!IsPlayerAlive(client))
		{
			SetEntProp(client, Prop_Data, "m_iObserverMode", 6);
		}
		TeleportToZone(client, BONUS_END, 0, IsPlayerAlive(client));
	}
	else
	{
		PrintColorText(client, "%s%sThe bonus end zone has not been created.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

int g_iRestartRequestZone[MAXPLAYERS + 1];
void RestartRequestMenu(int client, int zone)
{
	g_iRestartRequestZone[client] = zone;
	
	Menu menu = new Menu(Menu_RestartRequest);
	menu.SetTitle("Are you sure you want to restart?\n ");
	menu.AddItem("yes", "Yes");
	menu.AddItem("no",  "No");
	menu.Display(client, 3);
}

public int Menu_RestartRequest(Menu menu, MenuAction action, int client, int param2)
{
	if(action & MenuAction_Select)
	{
		char sInfo[4];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "yes"))
		{
			if(g_Properties[g_iRestartRequestZone[client]][zReady][0])
			{
				StopTimer(client);
		
				if(!IsPlayerAlive(client))
				{
					SetEntProp(client, Prop_Data, "m_iObserverMode", 7);
				}
				TeleportToZone(client, g_iRestartRequestZone[client], 0, IsPlayerAlive(client));
				
				if(Style(TimerInfo(client).GetStyle(TimerInfo(client).Type)).HasSpecialKey("parkour"))
				{
					SetEntProp(client, Prop_Data, "m_ArmorValue", 100);
				}
			}
			
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

g_NZ_Selection[MAXPLAYERS + 1];
public Action SM_NoZone(int client, int args)
{
	g_NZ_Selection[client] = 0;
	ShowNoZoneMenu(client);
	
	return Plugin_Handled;
}

void ShowNoZoneMenu(int client)
{
	Menu menu = new Menu(Menu_NoZone);
	menu.SetTitle("Choose Zones");
	
	char sInfo[8], sDisplay[32];
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		IntToString(Zone, sInfo, sizeof(sInfo));
		
		FormatEx(sDisplay, sizeof(sDisplay), "%s%s%s",
			(g_NZ_Selection[client] & (1 << Zone))?"> ":"",
			g_Properties[Zone][zName],
			(Zone == ZONE_COUNT - 1)?"\n":"");
		
		menu.AddItem(sInfo, sDisplay);
	}
	
	menu.AddItem("confirm", "Confirm");
	
	menu.Pagination = false;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_NoZone(Menu menu, MenuAction action, int client, int param2)
{
	if(action & MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "confirm"))
		{
			ShowNoZoneList(client);
		}
		else
		{
			int Zone = StringToInt(sInfo);
			g_NZ_Selection[client] ^= (1 << Zone);
			ShowNoZoneMenu(client);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void ShowNoZoneList(int client)
{
	if(g_NZ_Selection[client] == 0)
	{
		PrintColorText(client, "%s%sYou did not choose any zones.",
			g_msg_start,
			g_msg_textcol);
		ShowNoZoneMenu(client);
		return;
	}
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT MapName FROM maps WHERE InMapCycle = 1 AND HasZones & %d != %d ORDER BY MapName",
		g_NZ_Selection[client],
		g_NZ_Selection[client]);
		
	SQL_TQuery(g_DB, ShowNoZoneList_Callback, sQuery, GetClientUserId(client));
}

public void ShowNoZoneList_Callback(Handle owner, Handle hndl, const char[] error, int userid)
{
	if(hndl != INVALID_HANDLE)
	{
		int client = GetClientOfUserId(userid);
		
		if(client != 0)
		{
			if(SQL_GetRowCount(hndl) > 0)
			{
				Menu menu = new Menu(Menu_NoZoneList);
				menu.SetTitle("List of maps without all specified zones\n ");
				
				char sMap[PLATFORM_MAX_PATH];
				while(SQL_FetchRow(hndl))
				{
					SQL_FetchString(hndl, 0, sMap, PLATFORM_MAX_PATH);
					menu.AddItem(sMap, sMap);
				}
				
				menu.Display(client, MENU_TIME_FOREVER);
			}
			else
			{
				PrintColorText(client, "%s%sNo maps found to not have selected zones.", 
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
	else
	{
		Timer_Log(false, error);
	}
}

public int Menu_NoZoneList(Menu menu, MenuAction action, int client, int param2)
{
	if(action & MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		FakeClientCommand(client, "sm_nominate %s", sInfo);
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

public Action SM_Zones(int client, int args)
{
	if(!(Timer_ClientHasTimerFlag(client, "zones", Admin_Config)))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if(g_bZonesLoaded == false)
	{
		PrintColorText(client, "%s%sCurrently loading zones. Please wait.",
			g_msg_start,
			g_msg_textcol);
		return Plugin_Handled;
	}
	
	OpenZonesMenu(client);
	
	return Plugin_Handled;
}

void OpenZonesMenu(int client)
{
	Menu menu = new Menu(Menu_Zones);
	
	menu.SetTitle("Zone Control");
	
	menu.AddItem("add", "Add a zone");
	menu.AddItem("goto", "Go to zone");
	menu.AddItem("del", "Delete a zone");
	menu.AddItem("set", "Set zone flags");
	menu.AddItem("misc", "Miscellaneous");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	g_InZonesMenu[client] = true;
}

public int Menu_Zones(Menu menu, MenuAction action, int client, int param2)
{
	if(action & MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "add"))
		{
			OpenAddZoneMenu(client);
		}
		else if(StrEqual(sInfo, "goto"))
		{
			OpenGoToMenu(client);
		}
		else if(StrEqual(sInfo, "del"))
		{
			OpenDeleteMenu(client);
		}
		else if(StrEqual(sInfo, "set"))
		{
			OpenSetFlagsMenu(client);
		}
		else if(StrEqual(sInfo, "misc"))
		{
			OpenMiscMenu(client);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
	
	if(action & MenuAction_Cancel)
	{
		g_InZonesMenu[client] = false;
		
		if(LibraryExists("adminmenu") && param2 == MenuCancel_ExitBack)
		{
			if(Timer_ClientHasTimerFlag(client, "adminmenu", Admin_Custom5))
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

void OpenAddZoneMenu(int client)
{
	Menu menu = new Menu(Menu_AddZone);
	menu.SetTitle("Add a zone");
	
	char sInfo[8];
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		IntToString(Zone, sInfo, sizeof(sInfo));
		menu.AddItem(sInfo, g_Properties[Zone][zName]);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	g_InZonesMenu[client] = true;
}

public int Menu_AddZone(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		CreateZone(client, StringToInt(sInfo));
		
		OpenAddZoneMenu(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			OpenZonesMenu(client);
		}
	}
	else if(action == MenuAction_End)
	{
		if(param2 == MenuEnd_Selected)
		{
			//g_InZonesMenu[client] = false;
		}
		
		delete menu;
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_InZonesMenu[client] = false;
		}
	}
}

void CreateZone(int client, int Zone)
{
	if(ClientCanCreateZone(client, Zone))
	{
		if((g_Properties[Zone][zCount] < g_Properties[Zone][zMax]) || g_Properties[Zone][zReplaceable] == true)
		{
			int ZoneNumber;
			
			if(g_Properties[Zone][zCount] >= g_Properties[Zone][zMax])
				ZoneNumber = 0;
			else
				ZoneNumber = g_Properties[Zone][zCount];
			
			if(g_CurrentZone[client] == -1)
			{
				if(g_Properties[Zone][zReady][ZoneNumber] == true)
					DB_DeleteZone(client, Zone, ZoneNumber);
				
				if(Zone == ANTICHEAT)
					g_ViewAnticheats[client] = true;
				else if(Zone == SLIDE)
					g_bViewSlideZones[client] = true;
				
				g_CurrentZone[client] = Zone;
				
				GetZoneSetupPosition(client, g_Zones[Zone][ZoneNumber][0]);
				
				DataPack data;
				g_SetupTimer[client] = CreateDataTimer(0.1, Timer_ZoneSetup, data, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				data.WriteCell(GetClientUserId(client));
				data.WriteCell(ZoneNumber);
			}
			else if(g_CurrentZone[client] == Zone)
			{	
				if(g_Properties[Zone][zCount] < g_Properties[Zone][zMax])
				{
					g_Properties[Zone][zCount]++;
					g_TotalZoneCount++;
				}
				
				KillTimer(g_SetupTimer[client], true);
				
				GetZoneSetupPosition(client, g_Zones[Zone][ZoneNumber][7]);
				
				g_Zones[Zone][ZoneNumber][7][2] += g_Properties[Zone][zOffset];
				
				switch(Zone)
				{
					case ANTICHEAT:
					{
						g_Properties[Zone][zAc_Type][ZoneNumber] = FLAG_ANTICHEAT_MAIN;
					}
					case FREESTYLE:
					{
						Style s;
						
						for(int style; style < MAX_STYLES; style++)
						{
							GetStyleConfig(style, s);
							
							g_Properties[Zone][zFs_Auto][ZoneNumber]       |= view_as<int>(s.FreestyleAuto);
							g_Properties[Zone][zFs_Unrestrict][ZoneNumber] |= view_as<int>(s.FreestyleUnrestrict);
							g_Properties[Zone][zFs_EzHop][ZoneNumber]      |= view_as<int>(s.FreestyleEzHop);
							g_Properties[Zone][zFs_NoLimit][ZoneNumber]    |= view_as<int>(s.FreestyleNoLimit);
						}
					}
				}
				
				g_CurrentZone[client] = -1;
				g_Properties[Zone][zReady][ZoneNumber] = true;
				
				char sZone[64];
				GetZoneName(Zone, sZone, sizeof(sZone));
				Timer_Log(false, "%L created %s zone on map %s", client, sZone, g_sMapName);
				DB_SaveZone(Zone, ZoneNumber);
				
				if(g_Properties[Zone][zTriggerBased] == true)
					CreateZoneTrigger(Zone, ZoneNumber);
					
				LoadZoneArrayList();
			}
			else
			{
				PrintColorText(client, "%s%sYou are already setting up a different zone (%s%s%s).",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					g_Properties[g_CurrentZone[client]][zName],
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sThere are too many of this zone (Max %s%d%s).",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_Properties[Zone][zMax],
				g_msg_textcol);
		}
	}
	else
	{
		PrintColorText(client, "%s%sSomeone else is already creating this zone (%s%s%s).",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_Properties[Zone][zName],
			g_msg_textcol);
	}
}

bool ClientCanCreateZone(int client, int Zone)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && g_CurrentZone[i] == Zone && client != i)
		{
			return false;
		}
	}
	
	return true;
}

public Action Timer_ZoneSetup(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(ReadPackCell(pack));
	
	if(client != 0)
	{
		int ZoneNumber = ReadPackCell(pack);
		int Zone       = g_CurrentZone[client];
		
		// Get setup position
		GetZoneSetupPosition(client, g_Zones[Zone][ZoneNumber][7]);
		g_Zones[Zone][ZoneNumber][7][2] += g_Properties[Zone][zOffset];
		
		// Draw zone
		CreateZonePoints(g_Zones[Zone][ZoneNumber]);
		DrawZone(Zone, ZoneNumber, 0.1);
	}
	else
	{
		KillTimer(timer, true);
	}
}


void CreateZonePoints(float Zone[8][3])
{
	for(int i=1; i<7; i++)
	{
		for(int j=0; j<3; j++)
		{
			Zone[i][j] = Zone[((i >> (2 - j)) & 1) * 7][j];
		}
	}
}

void DrawZone(int Zone, int ZoneNumber, float life)
{
	int color[4];
	
	for(int i = 0; i < 4; i++)
		color[i] = g_Properties[Zone][zColor][i];
	
	for(int i=0, i2=3; i2>=0; i+=i2--)
	{
		for(int j=1; j<=7; j+=(j/2)+1)
		{
			if(j != 7-i)
			{
				TE_SetupBeamPoints(g_Zones[Zone][ZoneNumber][i], g_Zones[Zone][ZoneNumber][j], g_Properties[Zone][zModelIndex], g_Properties[Zone][zHaloIndex], 0, 0, (life < 0.1)?0.1:life, 5.0, 5.0, 10, 0.0, color, g_Properties[Zone][zSpeed]);
				
				int[] clients = new int[MaxClients];
				int numClients;
				
				switch(Zone)
				{
					case MAIN_START, MAIN_END, BONUS_START, FREESTYLE:
					{
						TE_SendToAll();
					}
					case BONUS_END:
					{
						numClients = 0;
						for(int client = 1; client <= MaxClients; client++)
						{
							if(IsClientInGame(client) && IsBeingTimed(client, TIMER_MAIN) == false)
							{
								clients[numClients++] = client;
							}
						}
						
						if(numClients > 0)
							TE_Send(clients, numClients);
					}
					case ANTICHEAT:
					{
						numClients = 0;
						for(int client = 1; client <= MaxClients; client++)
						{
							if(IsClientInGame(client) && g_ViewAnticheats[client] == true)
							{
								clients[numClients++] = client;
							}
						}
						
						if(numClients > 0)
							TE_Send(clients, numClients);
					}
					case SLIDE:
					{
						numClients = 0;
						for(int client = 1; client <= MaxClients; client++)
						{
							if(IsClientInGame(client) && g_bViewSlideZones[client] == true)
							{
								clients[numClients++] = client;
							}
						}
						
						if(numClients > 0)
							TE_Send(clients, numClients);
					}
				}
			}
		}
	}
}

public Action Timer_DrawBeams(Handle timer, any data)
{
	int iSize = GetArraySize(g_hZoneDrawList);
	
	if(iSize > 0)
	{
		if(g_LastDrawnZone >= iSize)
		{
			g_LastDrawnZone = 0;
		}
		
		int startZone = g_LastDrawnZone;
		
		for(int i; i < 4 && !(startZone == g_LastDrawnZone && i > 0); i++)
		{
			int Zone       = GetArrayCell(g_hZoneDrawList, g_LastDrawnZone, 0);
			int ZoneNumber = GetArrayCell(g_hZoneDrawList, g_LastDrawnZone, 1);
			
			int life;
			
			if(i < (4 - (iSize % 4)))
			{
				life = RoundToFloor(float(iSize) / 4.0);
			}
			else
			{
				life = RoundToCeil(float(iSize) / 4.0);
			}
			
			if(life < 1)
			{
				life = 1;
			}
			
			DrawZone(Zone, ZoneNumber, float(life));
			
			g_LastDrawnZone = (g_LastDrawnZone + 1) % iSize;
		}
	}
	
	/*
	// Draw 4 zones (32 temp ents limit) per timer frame so all zones will draw
	if(g_TotalZoneCount > 0)
	{
		
		
		for(; cycle < ZONE_COUNT; g_Drawing_Zone = (g_Drawing_Zone + 1) % ZONE_COUNT, cycle++)
		{
			for(; g_Drawing_ZoneNumber < g_Properties[g_Drawing_Zone][zCount]; g_Drawing_ZoneNumber++)
			{	
				if(g_Properties[g_Drawing_Zone][zReady][g_Drawing_ZoneNumber] == true)
				{
					if(g_Properties[g_Drawing_Zone][zEnabled] == true)
					{
						float fLife = (float(g_TotalZoneCount * 8)/32.0);
						if(fLife < 1.0)
						{
							fLife = 1.0;
						}
						
						DrawZone(g_Drawing_Zone, g_Drawing_ZoneNumber++, fLife);
						
						if(++ZonesDrawnThisFrame == 4)
						{
							g_Drawing_ZoneNumber++;
							
							return Plugin_Continue;
						}
					}
				}
			}
			
			g_Drawing_ZoneNumber = 0;
		}
		
	}
	*/
	
	return Plugin_Continue;
}

void CreateZoneTrigger(int Zone, int ZoneNumber)
{	
	int entity = CreateEntityByName("trigger_multiple");
	
	if(entity != -1)
	{
		DispatchKeyValue(entity, "spawnflags", "4097");
		
		DispatchSpawn(entity);
		ActivateEntity(entity);
		
		float fPos[3];
		GetZonePosition(Zone, ZoneNumber, fPos);
		TeleportEntity(entity, fPos, NULL_VECTOR, NULL_VECTOR);
		
		SetEntityModel(entity, "models/props/cs_office/vending_machine.mdl");
		
		float fBounds[2][3];
		GetMinMaxBounds(Zone, ZoneNumber, fBounds);
		SetEntPropVector(entity, Prop_Send, "m_vecMins", fBounds[0]);
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", fBounds[1]);
		
		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		SetEntProp(entity, Prop_Send, "m_fEffects", GetEntProp(entity, Prop_Send, "m_fEffects") | 32);
		
		g_Entities_ZoneType[entity]             = Zone;
		g_Entities_ZoneNumber[entity]           = ZoneNumber;
		g_Properties[Zone][zEntity][ZoneNumber] = entity;
		
		SDKHook(entity, SDKHook_StartTouch, Hook_StartTouch);
		SDKHook(entity, SDKHook_EndTouch, Hook_EndTouch);
		SDKHook(entity, SDKHook_Touch, Hook_Touch);
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		for(int ZoneNumber; ZoneNumber < g_Properties[Zone][zCount]; ZoneNumber++)
		{
			CreateZoneTrigger(Zone, ZoneNumber);
		}
	}
}

public Action Hook_StartTouch(int entity, int other)
{
	// Anti-cheats, freestyles, and end zones
	int Zone       = g_Entities_ZoneType[entity];
	int ZoneNumber = g_Entities_ZoneNumber[entity];
	
	if(Zone == -1)
	{
		return Plugin_Continue;
	}
	
	if(0 < other <= MaxClients)
	{
		if(IsClientInGame(other))
		{
			if(IsPlayerAlive(other))
			{
				if(g_Properties[Zone][zTriggerBased] == true)
				{
					g_bInside[other][Zone][ZoneNumber] = true;
					
					if(g_Properties[Zone][zEnabled] == true)
					{
						switch(Zone)
						{
							case MAIN_END:
							{
								if(IsBeingTimed(other, TIMER_MAIN))
								{
									FinishTimer(other);
								}
									
							}
							case BONUS_END:
							{
								if(IsBeingTimed(other, TIMER_BONUS))
								{
									FinishTimer(other);
								}
							}
							case ANTICHEAT:
							{
								if(IsBeingTimed(other, TIMER_MAIN) && (g_Properties[Zone][zAc_Type][ZoneNumber] & FLAG_ANTICHEAT_MAIN))
								{
									StopTimer(other);
									
									PrintColorText(other, "%s%sYour timer was stopped for using a shortcut.",
										g_msg_start,
										g_msg_textcol);
								}
								
								if(IsBeingTimed(other, TIMER_BONUS) && (g_Properties[Zone][zAc_Type][ZoneNumber] & FLAG_ANTICHEAT_BONUS))
								{
									StopTimer(other);
									
									PrintColorText(other, "%s%sYour timer was stopped for using a shortcut.",
										g_msg_start,
										g_msg_textcol);
								}
							}
						}
					}
				}
			}
			
			if(g_InSetFlagsMenu[other] == true)
				if(Zone == ANTICHEAT || Zone == FREESTYLE)
					OpenSetFlagsMenu(other, Zone, ZoneNumber);
				
			Call_StartForward(g_fwdOnZoneStartTouch);
			Call_PushCell(other);
			Call_PushCell(Zone);
			Call_PushCell(ZoneNumber);
			Call_Finish();
		}
	}
	
	return Plugin_Continue;
}

public Action Hook_EndTouch(int entity, int other)
{
	int Zone       = g_Entities_ZoneType[entity];
	int ZoneNumber = g_Entities_ZoneNumber[entity];
	
	if(Zone == -1)
	{
		return Plugin_Continue;
	}
	
	if(0 < other <= MaxClients)
	{
		if(g_Properties[Zone][zTriggerBased] == true)
		{
			g_bInside[other][Zone][ZoneNumber] = false;
		}
		
		Call_StartForward(g_fwdOnZoneEndTouch);
		Call_PushCell(other);
		Call_PushCell(Zone);
		Call_PushCell(ZoneNumber);
		Call_Finish();
	}
	
	return Plugin_Continue;
}

public Action Hook_Touch(int entity, int other)
{
	// Anti-prespeed (Start zones)
	int Zone = g_Entities_ZoneType[entity];
	
	if(Zone == -1)
	{
		return Plugin_Continue;
	}
	
	if(g_Properties[Zone][zTriggerBased] == true && (0 < other <= MaxClients))
	{
		if(IsClientInGame(other))
		{	
			if(IsPlayerAlive(other))
			{
				switch(Zone)
				{
					case MAIN_START:
					{						
						if(g_Properties[MAIN_END][zReady][0] == true)
							StartTimer(other, TIMER_MAIN);
					}
					case BONUS_START:
					{
						if(g_Properties[BONUS_END][zReady][0] == true)
							StartTimer(other, TIMER_BONUS);
					}
					case SLIDE:
					{
						SetEntProp(other, Prop_Send, "m_hGroundEntity", -1);
						SetEntityFlags(other, GetEntityFlags(other) & ~FL_ONGROUND);
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

void GetZoneSetupPosition(int client, float fPos[3])
{
	bool bSnapped;
	
	if(g_bSnapping[client] == true)
		bSnapped = GetWallSnapPosition(client, fPos);
		
	if(bSnapped == false)
		GetGridSnapPosition(client, fPos);
}

void GetGridSnapPosition(int client, float fPos[3])
{
	Entity_GetAbsOrigin(client, fPos);
	
	for(int i = 0; i < 2; i++)
		fPos[i] = float(RoundFloat(fPos[i] / float(g_GridSnap[client])) * g_GridSnap[client]);
	
	// Snap to z axis only if the client is off the ground
	if(!(GetEntityFlags(client) & FL_ONGROUND))
		fPos[2] = float(RoundFloat(fPos[2] / float(g_GridSnap[client])) * g_GridSnap[client]);
}

public Action Timer_SnapPoint(Handle timer, any data)
{
	float fSnapPos[3], fClientPos[3];
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && g_InZonesMenu[client])
		{
			Entity_GetAbsOrigin(client, fClientPos);
			GetZoneSetupPosition(client, fSnapPos);
			
			if(GetVectorDistance(fClientPos, fSnapPos) > 0)
			{
				TE_SetupBeamPoints(fClientPos, fSnapPos, g_SnapModelIndex, g_SnapHaloIndex, 0, 0, 0.1, 5.0, 5.0, 0, 0.0, {0, 255, 255, 255}, 0);
				TE_SendToAll();
			}
		}
	}
}

bool GetWallSnapPosition(int client, float fPos[3])
{
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
	
	float fHitPos[3], vAng[3];
	bool bSnapped;
	
	for(; vAng[1] < 360; vAng[1] += 90)
	{
		TR_TraceRayFilter(fPos, vAng, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);
		
		if(TR_DidHit())
		{
			TR_GetEndPosition(fHitPos);
			
			if(GetVectorDistance(fPos, fHitPos) < 17)
			{
				if(vAng[1] == 0 || vAng[1] == 180)
				{
					// Change x
					fPos[0] = fHitPos[0];
				}
				else
				{
					// Change y
					fPos[1] = fHitPos[1];
				}
				
				bSnapped = true;
			}
		}
	}
	
	return bSnapped;
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

void GetZonePosition(int Zone, int ZoneNumber, float fPos[3])
{
	for(int i = 0; i < 3; i++)
		fPos[i] = (g_Zones[Zone][ZoneNumber][0][i] + g_Zones[Zone][ZoneNumber][7][i]) / 2;
}

void GetMinMaxBounds(int Zone, int ZoneNumber, float fBounds[2][3])
{
	float length;
	
	for(int i = 0; i < 3; i++)
	{
		length = FloatAbs(g_Zones[Zone][ZoneNumber][0][i] - g_Zones[Zone][ZoneNumber][7][i]);
		fBounds[0][i] = -(length / 2);
		fBounds[1][i] = length / 2;
	}
}

void DB_Connect()
{
	char error[255];
	
	// Connect to mysql server
	if(g_DB != INVALID_HANDLE)
		delete g_DB;
	
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	
	if(g_DB == INVALID_HANDLE)
	{
		Timer_Log(false, error);
		delete g_DB;
	}
}

public void DB_Connect_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		Timer_Log(false, "DB_Connect_Callback (%s)", error);
	}
}

void DB_LoadZones()
{
	Timer_Log(true, "SQL Query Start: (Function = DB_LoadZones, Time = %d)", GetTime());
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "SELECT Type, RowID, unrestrict, ezhop, autohop, nolimit, actype, point00, point01, point02, point10, point11, point12 FROM zones WHERE MapID = (SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1)",
		g_sMapName);
	SQL_TQuery(g_DB, LoadZones_Callback, sQuery);
}

public void LoadZones_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	Timer_Log(true, "SQL Query Finish: (Function = DB_LoadZones, Time = %d)", GetTime());
	if(hndl != INVALID_HANDLE)
	{
		int Zone, ZoneNumber;
		
		while(SQL_FetchRow(hndl))
		{
			Zone       = SQL_FetchInt(hndl, 0);
			ZoneNumber = g_Properties[Zone][zCount];
			
			g_Properties[Zone][zRowID][ZoneNumber]         = SQL_FetchInt(hndl, 1);
			g_Properties[Zone][zFs_Unrestrict][ZoneNumber] = SQL_FetchInt(hndl, 2);
			g_Properties[Zone][zFs_EzHop][ZoneNumber]      = SQL_FetchInt(hndl, 3);
			g_Properties[Zone][zFs_Auto][ZoneNumber]       = SQL_FetchInt(hndl, 4);
			g_Properties[Zone][zFs_NoLimit][ZoneNumber]    = SQL_FetchInt(hndl, 5);
			g_Properties[Zone][zAc_Type][ZoneNumber]       = SQL_FetchInt(hndl, 6);
			
			for(int i = 0; i < 6; i++)
			{
				g_Zones[Zone][ZoneNumber][(i / 3) * 7][i % 3] = SQL_FetchFloat(hndl, i + 7);
			}
			
			CreateZonePoints(g_Zones[Zone][ZoneNumber]);
			CreateZoneTrigger(Zone, ZoneNumber);
			
			g_Properties[Zone][zReady][ZoneNumber] = true;
			g_Properties[Zone][zCount]++;
			g_TotalZoneCount++;
		}
		
		LoadZoneArrayList();
		
		g_bZonesLoaded = true;
		Call_StartForward(g_fwdOnZonesLoaded);
		Call_Finish();
	}
	else
	{
		Timer_Log(false, error);
	}
}

void LoadZoneArrayList()
{
	ClearArray(g_hZoneDrawList);
	
	int data[2];
	
	for(int Zone; Zone < ZONE_COUNT; Zone++)
	{
		for(int ZoneNumber; ZoneNumber < g_Properties[Zone][zCount]; ZoneNumber++)
		{
			data[0] = Zone;
			data[1] = ZoneNumber;
			
			PushArrayArray(g_hZoneDrawList, data, 2);
		}
	}
}

void DB_SaveZone(int Zone, int ZoneNumber)
{
	DataPack data = new DataPack();
	data.WriteCell(Zone);
	data.WriteCell(ZoneNumber);
	
	Transaction t = new Transaction();
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO zones (MapID, Type, point00, point01, point02, point10, point11, point12, unrestrict, ezhop, autohop, nolimit, actype) VALUES ((SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1), %d, %f, %f, %f, %f, %f, %f, %d, %d, %d, %d, %d)", 
		g_sMapName,
		Zone,
		g_Zones[Zone][ZoneNumber][0][0], g_Zones[Zone][ZoneNumber][0][1], g_Zones[Zone][ZoneNumber][0][2], 
		g_Zones[Zone][ZoneNumber][7][0], g_Zones[Zone][ZoneNumber][7][1], g_Zones[Zone][ZoneNumber][7][2],
		g_Properties[Zone][zFs_Unrestrict][ZoneNumber],
		g_Properties[Zone][zFs_Auto][ZoneNumber],
		g_Properties[Zone][zFs_EzHop][ZoneNumber],
		g_Properties[Zone][zFs_Auto][ZoneNumber],
		g_Properties[Zone][zAc_Type][ZoneNumber]);
	t.AddQuery(sQuery);
	
	FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET HasZones = HasZones | (1 << %d) WHERE MapID = (SELECT MapID FROM (SELECT * FROM maps) m WHERE MapName = '%s')",
		Zone,
		g_sMapName);
	t.AddQuery(sQuery);
	
	SQL_ExecuteTransaction(g_DB, t, OnZoneSavedSuccess, OnZoneSavedFailure, data);
}

public void OnZoneSavedSuccess(Database db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	data.Reset();
	int Zone       = data.ReadCell();
	int ZoneNumber = data.ReadCell();
	
	g_Properties[Zone][zRowID][ZoneNumber] = SQL_GetInsertId(results[0]);
	
	delete data;
}

public void OnZoneSavedFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	Timer_Log(false, error);
}

void DB_DeleteZone(int client, int Zone, int ZoneNumber, bool ManualDelete = false)
{
	if(g_Properties[Zone][zReady][ZoneNumber] == true)
	{
		// Delete from database
		DataPack data = new DataPack();
		data.WriteCell(GetClientUserId(client));
		data.WriteCell(Zone);
		
		Transaction t = new Transaction();
		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), "DELETE FROM zones WHERE RowID = %d",
			g_Properties[Zone][zRowID][ZoneNumber]);
		t.AddQuery(sQuery);
		
		if(g_Properties[Zone][zCount] - 1 == 0)
		{
			FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET HasZones = HasZones & ~(1 << %d) WHERE MapID = (SELECT MapID FROM (SELECT * FROM maps) m WHERE MapName = '%s')",
				Zone,
				g_sMapName);
			t.AddQuery(sQuery);
		}
		
		SQL_ExecuteTransaction(g_DB, t, OnZoneDeletedSuccess, OnZoneDeletedFailure, data);
		
		// Delete in memory
		for(int client2 = 1; client2 <= MaxClients; client2++)
		{
			g_bInside[client2][Zone][ZoneNumber] = false;
			
			if(ManualDelete == true)
			{
				if(Zone == MAIN_START || Zone == MAIN_END)
				{
					if(IsBeingTimed(client2, TIMER_MAIN))
					{
						StopTimer(client2);
						
						PrintColorText(client2, "%s%sYour timer was stopped because the %s%s%s zone was deleted.",
							g_msg_start,
							g_msg_textcol,
							g_msg_varcol,
							g_Properties[Zone][zName],
							g_msg_textcol);
					}
				}
				
				if(Zone == BONUS_START || Zone == BONUS_END)
				{
					if(IsBeingTimed(client2, TIMER_BONUS))
					{
						StopTimer(client2);
						
						PrintColorText(client2, "%s%sYour timer was stopped because the %s%s%s zone was deleted.",
							g_msg_start,
							g_msg_textcol,
							g_msg_varcol,
							g_Properties[Zone][zName],
							g_msg_textcol);
					}
				}
			}
		}
		
		if(IsValidEntity(g_Properties[Zone][zEntity][ZoneNumber]))
		{
			AcceptEntityInput(g_Properties[Zone][zEntity][ZoneNumber], "Kill");
		}
		
		if(-1 < g_Properties[Zone][zEntity][ZoneNumber] < 2048)
		{
			g_Entities_ZoneNumber[g_Properties[Zone][zEntity][ZoneNumber]] = -1;
			g_Entities_ZoneType[g_Properties[Zone][zEntity][ZoneNumber]]   = -1;
		}
		
		for(int i = ZoneNumber; i < g_Properties[Zone][zCount] - 1; i++)
		{
			for(int point = 0; point < 8; point++)
				for(int axis = 0; axis < 3; axis++)
					g_Zones[Zone][i][point][axis] = g_Zones[Zone][i + 1][point][axis];
			
			g_Properties[Zone][zEntity][i] = g_Properties[Zone][zEntity][i + 1];
			
			if(-1 < g_Properties[Zone][zEntity][i] < 2048)
			{
				g_Entities_ZoneNumber[g_Properties[Zone][zEntity][i]]--;
			}
			
			g_Properties[Zone][zRowID][i]         = g_Properties[Zone][zRowID][i + 1];
			g_Properties[Zone][zFs_Unrestrict][i] = g_Properties[Zone][zFs_Unrestrict][i + 1];
			g_Properties[Zone][zFs_EzHop][i]      = g_Properties[Zone][zFs_EzHop][i + 1];
			g_Properties[Zone][zFs_Auto][i]       = g_Properties[Zone][zFs_Auto][i + 1];
			g_Properties[Zone][zFs_NoLimit][i]    = g_Properties[Zone][zFs_NoLimit][i + 1];
			g_Properties[Zone][zAc_Type][i]       = g_Properties[Zone][zAc_Type][i + 1];
		}
		
		g_Properties[Zone][zReady][g_Properties[Zone][zCount] - 1] = false;
		
		g_Properties[Zone][zCount]--;
		g_TotalZoneCount--;
		LoadZoneArrayList();
	}
	else
	{
		PrintColorText(client, "%s%sAttempted to delete a zone that doesn't exist.",
			g_msg_start,
			g_msg_textcol);
	}
}

public void OnZoneDeletedSuccess(Database db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	data.Reset();
	int userid = data.ReadCell();
	int client = GetClientOfUserId(userid);
	
	if(client != 0)
	{
		int Zone = data.ReadCell();
		Timer_Log(false, "%L deleted zone %s ", client, g_Properties[Zone][zName]);
	}
	else
	{
		Timer_Log(false, "Player with UserID %d deleted a zone.", userid);
	}
	
	delete data;
}

public void OnZoneDeletedFailure(Database db, DataPack data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	Timer_Log(false, error[failIndex]);
}

public void DeleteZone_Callback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if(hndl != INVALID_HANDLE)
	{
		data.Reset();
		int userid = data.ReadCell();
		int client = GetClientOfUserId(userid);
		
		if(client != 0)
		{
			int Zone = data.ReadCell();
			Timer_Log(false, "%L deleted zone %s on map %s", client, g_Properties[Zone][zName], g_sMapName);
		}
		else
		{
			Timer_Log(false, "Player with UserID %d deleted a zone.", userid);
		}
	}
	else
	{
		Timer_Log(false, error);
	}
	
	delete data;
}

void OpenGoToMenu(int client)
{
	if(g_TotalZoneCount > 0)
	{
		Menu menu = new Menu(Menu_GoToZone);
		
		menu.SetTitle("Go to a Zone");
		
		char sInfo[8];
		for(int Zone; Zone < ZONE_COUNT; Zone++)
		{
			if(g_Properties[Zone][zCount] > 0)
			{
				IntToString(Zone, sInfo, sizeof(sInfo));
				menu.AddItem(sInfo, g_Properties[Zone][zName]);
			}
		}
		
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		OpenZonesMenu(client);
	}
}

public int Menu_GoToZone(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		int Zone = StringToInt(sInfo);
		
		switch(Zone)
		{
			case MAIN_START, MAIN_END, BONUS_START, BONUS_END:
			{
				TeleportToZone(client, Zone, 0);
				OpenGoToMenu(client);
			}
			case ANTICHEAT, FREESTYLE:
			{
				ListGoToZones(client, Zone);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenZonesMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_InZonesMenu[client] = false;
		}
	}
}

void ListGoToZones(int client, int Zone)
{
	Menu menu = new Menu(Menu_GoToList);
	menu.SetTitle("Go to %s zones", g_Properties[Zone][zName]);
	
	char sInfo[16], sDisplay[16];
	for(int ZoneNumber; ZoneNumber < g_Properties[Zone][zCount]; ZoneNumber++)
	{
		FormatEx(sInfo, sizeof(sInfo), "%d;%d", Zone, ZoneNumber);
		IntToString(ZoneNumber + 1, sDisplay, sizeof(sDisplay));
		
		menu.AddItem(sInfo, sDisplay);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_GoToList(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sZoneAndNumber[2][16];
		ExplodeString(sInfo, ";", sZoneAndNumber, 2, 16);
		
		int Zone       = StringToInt(sZoneAndNumber[0]);
		int ZoneNumber = StringToInt(sZoneAndNumber[1]);
		
		TeleportToZone(client, Zone, ZoneNumber);
		
		ListGoToZones(client, Zone);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenGoToMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_InZonesMenu[client] = false;
		}
	}
}

void OpenDeleteMenu(int client)
{
	if(g_TotalZoneCount > 0)
	{
		Menu menu = new Menu(Menu_DeleteZone);
		
		menu.SetTitle("Delete a zone");
		
		menu.AddItem("sel", "Selected Zone");
		
		char sInfo[8];
		for(int Zone; Zone < ZONE_COUNT; Zone++)
		{
			if(g_Properties[Zone][zCount] > 0)
			{
				IntToString(Zone, sInfo, sizeof(sInfo));
				
				menu.AddItem(sInfo, g_Properties[Zone][zName]);
			}
		}
		
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		OpenZonesMenu(client);
	}
}

public int Menu_DeleteZone(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "sel"))
		{
			for(int Zone; Zone < ZONE_COUNT; Zone++)
			{
				for(int ZoneNumber; ZoneNumber < g_Properties[Zone][zCount]; ZoneNumber++)
				{
					if(g_bInside[client][Zone][ZoneNumber] == true)
					{
						DB_DeleteZone(client, Zone, ZoneNumber, true);
					}
				}
			}
			
			OpenDeleteMenu(client);
		}
		else
		{
			int Zone = StringToInt(sInfo);
			
			switch(Zone)
			{
				case MAIN_START, MAIN_END, BONUS_START, BONUS_END:
				{
					DB_DeleteZone(client, Zone, 0, true);
					
					OpenDeleteMenu(client);
				}
				case ANTICHEAT, FREESTYLE, SLIDE:
				{
					ListDeleteZones(client, Zone);
				}
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenZonesMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_InZonesMenu[client] = false;
		}
	}
}

void ListDeleteZones(int client, int Zone)
{
	Menu menu = CreateMenu(Menu_DeleteList);
	menu.SetTitle("Delete %s zones", g_Properties[Zone][zName]);
	
	char sInfo[16], sDisplay[16];
	for(int ZoneNumber; ZoneNumber < g_Properties[Zone][zCount]; ZoneNumber++)
	{
		FormatEx(sInfo, sizeof(sInfo), "%d;%d", Zone, ZoneNumber);
		IntToString(ZoneNumber + 1, sDisplay, sizeof(sDisplay));
		
		menu.AddItem(sInfo, sDisplay);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_DeleteList(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sZoneAndNumber[2][16];
		ExplodeString(sInfo, ";", sZoneAndNumber, 2, 16);
		
		int Zone       = StringToInt(sZoneAndNumber[0]);
		int ZoneNumber = StringToInt(sZoneAndNumber[1]);
		
		DB_DeleteZone(client, Zone, ZoneNumber);
		
		ListDeleteZones(client, Zone);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenGoToMenu(client);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_InZonesMenu[client] = false;
		}
	}
}

void OpenSetFlagsMenu(int client, int Zone = -1, int ZoneNumber = -1)
{
	g_InSetFlagsMenu[client] = true;
	g_ViewAnticheats[client] = true;
	
	Menu menu = new Menu(Menu_SetFlags);
	menu.ExitBackButton = true;
	
	if(Zone == -1 && ZoneNumber == -1)
	{
		for(Zone = ANTICHEAT; Zone <= FREESTYLE; Zone++)
		{
			if((ZoneNumber = Timer_InsideZone(client, Zone)) != -1)
			{
				break;
			}
		}
	}
	
	if(ZoneNumber != -1)
	{
		menu.SetTitle("Set %s flags", g_Properties[Zone][zName]);
		
		char sInfo[16];
		
		switch(Zone)
		{
			case ANTICHEAT:
			{
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", ANTICHEAT, ZoneNumber, FLAG_ANTICHEAT_MAIN);
				menu.AddItem(sInfo, (g_Properties[Zone][zAc_Type][ZoneNumber] & FLAG_ANTICHEAT_MAIN)?"Main: Yes":"Main: No");
				
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", ANTICHEAT, ZoneNumber, FLAG_ANTICHEAT_BONUS);
				menu.AddItem(sInfo, (g_Properties[Zone][zAc_Type][ZoneNumber] & FLAG_ANTICHEAT_BONUS)?"Bonus: Yes":"Bonus: No");
				
				menu.Display(client, MENU_TIME_FOREVER);
				
				return;
			}
			case FREESTYLE:
			{
				char sStyle[32];
				Style s;
				for(int style; style < GetTotalStyles(); style++)
				{
					GetStyleConfig(style, s);
					
					if(s.Enabled && s.Freestyle)
					{
						s.GetName(sStyle, sizeof(sStyle));
						
						FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", FREESTYLE, ZoneNumber, style);
						
						menu.AddItem(sInfo, sStyle);
					}
				}
				
				menu.Display(client, MENU_TIME_FOREVER);
				
				return;
			}
		}
	}
	else
	{
		menu.SetTitle("Not in Anti-cheat nor Freestyle zone");
		menu.AddItem("choose", "Go to a zone", ITEMDRAW_DISABLED);
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	g_InSetFlagsMenu[client] = true;
}

public int Menu_SetFlags(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sExplode[3][16];
		ExplodeString(sInfo, ";", sExplode, 3, 16);
		
		int Zone       = StringToInt(sExplode[0]);
		int ZoneNumber = StringToInt(sExplode[1]);
		
		switch(Zone)
		{
			case ANTICHEAT:
			{
				int flags = StringToInt(sExplode[2]);
				SetZoneFlags(Zone, ZoneNumber, view_as<int>(zAc_Type), g_Properties[Zone][zAc_Type][ZoneNumber] ^ flags);
				OpenSetFlagsMenu(client, Zone, ZoneNumber);
			}
			case FREESTYLE:
			{
				int style = StringToInt(sExplode[2]);
				OpenFreestyleFlagsMenu(client, ZoneNumber, style);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenGoToMenu(client);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	if(action & MenuAction_Cancel)
	{		
		if(param2 == MenuCancel_Exit)
		{
			g_InZonesMenu[client]    = false;
			g_InSetFlagsMenu[client] = false;
		}
		else if(param2 == MenuCancel_ExitBack)
		{
			g_InSetFlagsMenu[client] = false;
			
			OpenZonesMenu(client);
		}
	}
}

void SetZoneFlags(int Zone, int ZoneNumber, int flagtype, int flags)
{
	g_Properties[Zone][flagtype + ZoneNumber] = flags;
	
	char sFieldname[32];
	DB_GetZoneFlagFieldName(flagtype, sFieldname, sizeof(sFieldname));
	
	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), "UPDATE zones SET %s = %d WHERE RowID = %d",
		sFieldname,
		g_Properties[Zone][flagtype + ZoneNumber],
		g_Properties[Zone][zRowID][ZoneNumber]);
	SQL_TQuery(g_DB, SetZoneFlags_Callback, sQuery);
}

void DB_GetZoneFlagFieldName(int flagtype, char[] fieldname, int maxlength)
{
	switch(flagtype)
	{
		case zFs_Auto:
		{
			FormatEx(fieldname, maxlength, "autohop");
		}
		case zFs_EzHop:
		{
			FormatEx(fieldname, maxlength, "ezhop");
		}
		case zFs_NoLimit:
		{
			FormatEx(fieldname, maxlength, "nolimit");
		}
		case zFs_Unrestrict:
		{
			FormatEx(fieldname, maxlength, "unrestrict");
		}
		case zAc_Type:
		{
			FormatEx(fieldname, maxlength, "actype");
		}
	}
}

public void SetZoneFlags_Callback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if(hndl == INVALID_HANDLE)
	{
		Timer_Log(false, error);
	}
}

void OpenFreestyleFlagsMenu(int client, int ZoneNumber, int style)
{
	g_InSetFlagsMenu[client] = false;
	
	Menu menu = new Menu(Menu_FreestyleFlags);
	menu.SetTitle("Set selected freestyle zone settings");
	
	char sInfo[64];
	FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", ZoneNumber, style, zFs_Unrestrict);
	menu.AddItem(sInfo, (g_Properties[FREESTYLE][zFs_Unrestrict][ZoneNumber] & (1 << style))?"Unrestrict: Yes":"Unrestrict: No");
	
	FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", ZoneNumber, style, zFs_EzHop);
	menu.AddItem(sInfo, (g_Properties[FREESTYLE][zFs_EzHop][ZoneNumber] & (1 << style))?"Easyhop: Yes":"Easyhop: No");
	
	FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", ZoneNumber, style, zFs_Auto);
	menu.AddItem(sInfo, (g_Properties[FREESTYLE][zFs_Auto][ZoneNumber] & (1 << style))?"Autohop: Yes":"Autohop: No");
	
	FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", ZoneNumber, style, zFs_NoLimit);
	menu.AddItem(sInfo, (g_Properties[FREESTYLE][zFs_NoLimit][ZoneNumber] & (1 << style))?"No velocity limit: Yes":"No velocity limit: No");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_FreestyleFlags(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sExplode[3][16];
		ExplodeString(sInfo, ";", sExplode, sizeof(sExplode), sizeof(sExplode[]));
		
		int ZoneNumber = StringToInt(sExplode[0]);
		int style      = StringToInt(sExplode[1]);
		int flagtype   = StringToInt(sExplode[2]);
		
		SetZoneFlags(FREESTYLE, ZoneNumber, flagtype, g_Properties[FREESTYLE][flagtype + ZoneNumber] ^ (1 << style));
		OpenFreestyleFlagsMenu(client, ZoneNumber, style);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	if(action & MenuAction_Cancel)
	{		
		if(param2 == MenuCancel_Exit)
		{
			g_InZonesMenu[client] = false;
		}
		else if(param2 == MenuCancel_ExitBack)
		{
			OpenSetFlagsMenu(client);
		}
	}
}

void OpenMiscMenu(int client)
{
	Menu menu = new Menu(Menu_Misc);
	menu.SetTitle("Miscellaneous zone settings");
	menu.AddItem("snap", g_bSnapping[client]?"Wall Snapping: On":"Wall Snapping: Off");
	
	char sDisplay[64];
	IntToString(g_GridSnap[client], sDisplay, sizeof(sDisplay));
	Format(sDisplay, sizeof(sDisplay), "Grid Snapping: %s", sDisplay);
	menu.AddItem("grid", sDisplay);
	menu.AddItem("ac", g_ViewAnticheats[client]?"Anti-cheats: Visible":"Anti-cheats: Invisible");
	menu.AddItem("slide", g_bViewSlideZones[client]?"Slide zones: Visible":"Slide zones: Invisible");
	menu.AddItem("triggers", g_DisableTriggers[client]?"Triggers: Disabled":"Triggers: Enabled");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Misc(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "snap"))
		{
			g_bSnapping[client] = !g_bSnapping[client];
			OpenMiscMenu(client);
		}
		else if(StrEqual(sInfo, "grid"))
		{
			g_GridSnap[client] *= 2;
				
			if(g_GridSnap[client] > 64)
				g_GridSnap[client] = 1;
			
			OpenMiscMenu(client);
		}
		else if(StrEqual(sInfo, "ac"))
		{
			g_ViewAnticheats[client] = !g_ViewAnticheats[client];
			OpenMiscMenu(client);
		}
		else if(StrEqual(sInfo, "slide"))
		{
			g_bViewSlideZones[client] = !g_bViewSlideZones[client];
			OpenMiscMenu(client);
		}
		else if(StrEqual(sInfo, "triggers"))
		{
			g_DisableTriggers[client] = !g_DisableTriggers[client];
			
			if(g_DisableTriggers[client] && IsBeingTimed(client, TIMER_ANY))
			{
				StopTimer(client);
			}
			OpenMiscMenu(client);
		}
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_InZonesMenu[client] = false;
		}
		else if(param2 == MenuCancel_ExitBack)
		{
			OpenZonesMenu(client);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "trigger_") != -1)
	{
		SDKHook(entity, SDKHook_StartTouch, ZoningTriggers);
		SDKHook(entity, SDKHook_Touch, ZoningTriggers);
		SDKHook(entity, SDKHook_EndTouch, ZoningTriggers);
	}
}

public Action ZoningTriggers(int entity, int other)
{
	if(!(0 < other <= MaxClients))
		return Plugin_Continue;
		
	if(g_DisableTriggers[other])
	{
		return Plugin_Handled;
	}
		
	return Plugin_Continue;
}

public Action OnTimerStart_Pre(int client, int Type, int style, int Method)
{
	if(g_DisableTriggers[client] == true)
	{
		WarnClient(client, "%s%sYour timer won't start unless you enable triggers again in the Zones>Miscellaneous menu.", 30.0,
			g_msg_start,
			g_msg_textcol);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

void WarnClient(int client, const char[] message, float WarnTime, any ...)
{
	if(GetEngineTime() > g_fWarningTime[client])
	{
		char buffer[300];
		VFormat(buffer, sizeof(buffer), message, 4);
		PrintColorText(client, buffer);
		
		g_fWarningTime[client] = GetEngineTime() + WarnTime;	
	}
}

bool IsClientInsideZone(int client, float point[8][3])
{
	float fPos[3];
	Entity_GetAbsOrigin(client, fPos);
	
	// Add 5 units to a player's height or it won't work
	fPos[2] += 5.0;
	
	return IsPointInsideZone(fPos, point);
}

bool IsPointInsideZone(float pos[3], float point[8][3])
{
	for(int i = 0; i < 3; i++)
	{
		if(point[0][i] >= pos[i] == point[7][i] >= pos[i])
		{
			return false;
		}
	}
	
	return true;
}

public int Native_InsideZone(Handle plugin, int numParams)
{
	int client   = GetNativeCell(1);
	int Zone     = GetNativeCell(2);
	int flags    = GetNativeCell(3);
	int flagtype = GetNativeCell(4);
	
	for(int ZoneNumber; ZoneNumber < g_Properties[Zone][zCount]; ZoneNumber++)
	{
		if(g_bInside[client][Zone][ZoneNumber] == true)
		{
			if(flags != -1 && flagtype != -1)
			{
				if((g_Properties[Zone][flagtype] + ZoneNumber) & flags)
					return ZoneNumber;
			}
			else
			{
				return ZoneNumber;
			}
		}
	}
		
	return -1;
}

public int Native_IsPointInsideZone(Handle plugin, int numParams)
{
	float fPos[3];
	GetNativeArray(1, fPos, 3);
	
	int Zone       = GetNativeCell(2);
	int ZoneNumber = GetNativeCell(3);
	
	if(g_Properties[Zone][zReady][ZoneNumber] == true)
	{
		return IsPointInsideZone(fPos, g_Zones[Zone][ZoneNumber]);
	}
	else
	{
		return false;
	}
}

public int Native_TeleportToZone(Handle plugin, int numParams)
{
	int client      = GetNativeCell(1);
	int Zone        = GetNativeCell(2);
	int ZoneNumber  = GetNativeCell(3);
	bool bottom     = GetNativeCell(4);
	
	TeleportToZone(client, Zone, ZoneNumber, bottom);
}

public int Native_GetZoneCount(Handle plugin, int numParams)
{
	return g_Properties[GetNativeCell(1)][zCount];
}

public int Native_AreZonesLoaded(Handle plugin, int numParams)
{
	return g_bZonesLoaded;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{	
	if(IsPlayerAlive(client) && !IsFakeClient(client))
	{
		for(int Zone = 0; Zone < ZONE_COUNT; Zone++)
		{
			if(g_Properties[Zone][zTriggerBased] == false && g_Properties[Zone][zEnabled] == true)
			{
				for(int ZoneNumber = 0; ZoneNumber < g_Properties[Zone][zCount]; ZoneNumber++)
				{
					g_bInside[client][Zone][ZoneNumber] = IsClientInsideZone(client, g_Zones[Zone][ZoneNumber]);
					
					if(g_bInside[client][Zone][ZoneNumber] == true)
					{
						switch(Zone)
						{
							case MAIN_START:
							{
								if(g_Properties[MAIN_END][zReady][ZoneNumber] == true)
								{
									StartTimer(client, TIMER_MAIN);
								}
							}
							case MAIN_END:
							{
								if(IsBeingTimed(client, TIMER_MAIN))
								{
									FinishTimer(client);
								}
							}
							case BONUS_START:
							{
								if(g_Properties[BONUS_END][zReady][ZoneNumber] == true)
									StartTimer(client, TIMER_BONUS);
							}
							case BONUS_END:
							{
								if(IsBeingTimed(client, TIMER_BONUS))
								{
									FinishTimer(client);
								}
							}
							case ANTICHEAT:
							{
								if(IsBeingTimed(client, TIMER_MAIN) && g_Properties[Zone][zAc_Type][ZoneNumber] & FLAG_ANTICHEAT_MAIN)
								{
									StopTimer(client);
									
									PrintColorText(client, "%s%sYour timer was stopped for using a shortcut.",
										g_msg_start,
										g_msg_textcol);
								}
								
								if(IsBeingTimed(client, TIMER_BONUS) && g_Properties[Zone][zAc_Type][ZoneNumber] & FLAG_ANTICHEAT_BONUS)
								{
									StopTimer(client);
									
									PrintColorText(client, "%s%sYour timer was stopped for using a shortcut.",
										g_msg_start,
										g_msg_textcol);
								}
							}
							case SLIDE:
							{
								SetEntProp(client, Prop_Send, "m_hGroundEntity", -1);
								SetEntityFlags(client, GetEntityFlags(client) & ~FL_ONGROUND);
							}
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}