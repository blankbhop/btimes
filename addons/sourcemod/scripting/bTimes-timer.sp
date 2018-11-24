#pragma semicolon 1

#include <bTimes-core>

public Plugin myinfo = 
{
	name = "[Timer] - Timer",
	author = "blacky",
	description = "The timer portion of the bTimes plugin",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>

#include <bTimes-timer>
#include <sdktools>
#include <sdkhooks>
#include <smlib/entities>
#include <smlib/arrays>
#include <cstrike>
#include <clientprefs>
#include <csgocolors>

#undef REQUIRE_PLUGIN
#include <bTimes-zones>
#include <bTimes-climbcp>
#include <bTimes-tas>
#include <cvarenf>
#include <smartmsg>

#pragma newdecls required

EngineVersion g_Engine;

// database
Database g_DB;

// Current map info
char g_sMapName[64];

// Player timer info
TimerInfo g_TimerInfo[MAXPLAYERS + 1];

// Style info
Style g_StyleConfig[MAX_STYLES];
int   g_TotalStyles;
ArrayList g_hFavoriteStyles[MAXPLAYERS + 1][MAX_TYPES][2];
bool  g_bFavoriteStylesLoaded[MAXPLAYERS + 1];
	
bool  g_bTimeIsLoaded[MAXPLAYERS + 1];
bool  g_bPlayerHasTime[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES][2];
float g_fTime[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES][2];
int   g_iPosition[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES][2];
int   g_SWStrafes[MAXPLAYERS + 1][2];
float g_HSWCounter[MAXPLAYERS + 1];
bool  g_AorD_ChosenKey[MAXPLAYERS + 1];
bool  g_AorD_HasPickedKey[MAXPLAYERS + 1];
float g_fSpawnTime[MAXPLAYERS + 1];
float g_fNoClipSpeed[MAXPLAYERS + 1];
bool  g_bUnNoClipped[MAXPLAYERS + 1];
int   g_Buttons[MAXPLAYERS + 1];
int   g_UnaffectedButtons[MAXPLAYERS + 1];
float g_fLastMove[MAXPLAYERS + 1][2];
int   g_UnaffectedFlags[MAXPLAYERS + 1];

ArrayList g_hSound_Path_Record;
ArrayList g_hSound_Record_Data;
ArrayList g_hSound_Path_Personal;
ArrayList g_hSound_Path_Fail;

float g_fPauseTime[MAXPLAYERS + 1];
float g_fPausePos[MAXPLAYERS + 1][3];
	
float g_Fps[MAXPLAYERS + 1];
	
// Warning
float g_fWarningTime[MAXPLAYERS + 1];

// Sync measurement
float g_fOldAngle[MAXPLAYERS + 1];

// Cvars
int    g_AllowedYawspeed[MAXPLAYERS + 1];
ConVar g_hAllowPause;
ConVar g_hAllowNoClip;
ConVar g_hVelocityCap;
bool   g_bAllowVelocityCap;
ConVar g_hAllowAuto;
bool   g_bAllowAuto;
ConVar g_hJumpInStartZone;
bool   g_bJumpInStartZone;
ConVar g_hAutoStopsTimer;
bool   g_bAutoStopsTimer;
ConVar g_hAirAcceleration;
ConVar g_hGravity;
ConVar g_hStaminaJumpCost;
ConVar g_hStaminaMax;
ConVar g_hStaminaLandCost;
ConVar g_hAutoBunnyhopping;
ConVar g_hStatsUrl;
ConVar g_hPracticeTime;
	
// Client cookies
Handle g_hRecordSoundCookie;
Handle g_hPersonalBestSoundCookie;
Handle g_hFailedSoundCookie;
Handle g_hAutohopCookie;
Handle g_hPersonalizedStyleList;
	
// All map times
ArrayList g_hTimes[MAX_TYPES][MAX_STYLES][2];
ArrayList g_hTimesUsers[MAX_TYPES][MAX_STYLES][2];
bool      g_bTimesAreLoaded;
	
// Forwards
Handle g_fwdOnTimerFinished_Pre;
Handle g_fwdOnTimerFinished_Post;
Handle g_fwdOnTimerStart_Pre;
Handle g_fwdOnTimerStart_Post;
Handle g_fwdOnTimerStopped;
Handle g_fwdOnTimesDeleted;
Handle g_fwdOnTimesUpdated;
Handle g_fwdOnStylesLoaded;
Handle g_fwdOnTimesLoaded;
Handle g_fwdOnStyleChanged;

// Other plugins
bool g_bTasPluginLoaded;
bool g_bSmartMsgLoaded;
bool g_bZonePluginLoaded;

public void OnPluginStart()
{
	g_Engine = GetEngineVersion();
	// Connect to the database
	DB_Connect();
	
	// Server cvars
	g_hAllowPause      = CreateConVar("timer_allowpausing", "1", "Lets players use the !pause/!unpause commands.", 0, true, 0.0, true, 1.0);
	g_hAllowNoClip     = CreateConVar("timer_noclip", "1", "Allows players to use the !p commands to noclip themselves.", 0, true, 0.0, true, 1.0);
	g_hVelocityCap     = CreateConVar("timer_velocitycap", "1", "Allows styles with a max velocity cap to cap player velocity.", 0, true, 0.0, true, 1.0);
	g_hJumpInStartZone = CreateConVar("timer_allowjumpinstart", "1", "Allows players to jump in the start zone. (This is not exactly anti-prespeed)", 0, true, 0.0, true, 1.0);
	g_hAllowAuto       = CreateConVar("timer_allowauto", "1", "Allows players to use auto bunnyhop.", 0, true, 0.0, true, 1.0);
	g_hAutoStopsTimer  = CreateConVar("timer_autostopstimer", "0", "Players can't get times with autohop on.");
	g_hStatsUrl        = CreateConVar("timer_statsurl", "https://www.kawaiiclan.com/stats.php?", "Stats page URL");
	g_hPracticeTime    = CreateConVar("timer_noclipmenutime", "5", "Minimum time on a player's timer when they are given the 'Are you sure you want to noclip?' menu prompt if they try to noclip, to prevent players from accidentally ruining their time", 0, true, 0.0);
	
	AutoExecConfig(true, "timer", "timer");
	
	HookConVarChange(g_hAllowPause,      OnAllowPauseChanged);
	HookConVarChange(g_hVelocityCap,     OnVelocityCapChanged);
	HookConVarChange(g_hAutoStopsTimer,  OnAutoStopsTimerChanged);
	HookConVarChange(g_hAllowAuto,       OnAllowAutoChanged);
	HookConVarChange(g_hJumpInStartZone, OnAllowJumpInStartZoneChanged);
	HookConVarChange(FindConVar("sm_nextmap"), OnNextMapChanged);
	
	// Event hooks
	HookEvent("player_death",      Event_PlayerDeath,     EventHookMode_Post);
	HookEvent("player_team",       Event_PlayerTeam,      EventHookMode_Post);
	HookEvent("player_spawn",      Event_PlayerSpawn,     EventHookMode_Pre);
	HookEvent("player_jump",       Event_PlayerJump,      EventHookMode_Pre);
	HookEvent("player_jump",       Event_PlayerJump_Post, EventHookMode_Post);
	HookEvent("player_disconnect", Event_Disconnect,      EventHookMode_Pre);
	//HookEvent("player_connect",    Event_Connect,         EventHookMode_Post);
	HookEvent("player_changename", Event_ChangeName,      EventHookMode_Post);
	
	// Admin commands
	RegConsoleCmd("sm_delete",       SM_Delete,       "Deletes map times.");
	RegConsoleCmd("sm_enablestyle",  SM_EnableStyle,  "Enables a style for players to use. (Resets to default setting on map change)");
	RegConsoleCmd("sm_disablestyle", SM_DisableStyle, "Disables a style so players can no longer use it. (Resets to default setting on map change)");
	RegConsoleCmd("sm_reloadstyles", SM_ReloadStyles, "Reloads the styles.cfg file.");
	
	// Player commands
	RegConsoleCmdEx("sm_stop",     SM_StopTimer,       "Stops your timer.");
	RegConsoleCmdEx("sm_style",    SM_Style,           "Change your style.");
	RegConsoleCmdEx("sm_styles",   SM_Style,           "Change your style.");
	RegConsoleCmdEx("sm_mode",     SM_Style,           "Change your style.");
	RegConsoleCmdEx("sm_bstyle",   SM_BStyle,          "Change your bonus style.");
	RegConsoleCmdEx("sm_bmode",    SM_BStyle,          "Change your bonus style.");
	RegConsoleCmdEx("sm_practice", SM_Practice,        "Puts you in noclip. Stops your timer.");
	RegConsoleCmdEx("sm_p",        SM_Practice,        "Puts you in noclip. Stops your timer.");
	RegConsoleCmdEx("sm_noclipme", SM_Practice,        "Puts you in noclip. Stops your timer.");
	RegConsoleCmdEx("sm_nc",       SM_Practice,        "Puts you in noclip. Stops your timer.");
	RegConsoleCmdEx("sm_pause",    SM_Pause,           "Pauses your timer and freezes you.");
	RegConsoleCmdEx("sm_unpause",  SM_Unpause,         "Unpauses your timer and unfreezes you.");
	RegConsoleCmdEx("sm_resume",   SM_Unpause,         "Unpauses your timer and unfreezes you.");
	RegConsoleCmdEx("sm_fps",      SM_Fps,             "Shows a list of every player's fps_max value.");
	//RegConsoleCmdEx("sm_auto",     SM_Auto,            "Toggles auto bunnyhop");
	//RegConsoleCmdEx("sm_bhop",     SM_Auto,            "Toggles auto bunnyhop");
	RegConsoleCmdEx("sm_wr",       SM_WR,              "Show the world records.");
	RegConsoleCmdEx("sm_bwr",      SM_BWR,             "Shows the Bonus world records.");
	RegConsoleCmdEx("sm_wrtas",    SM_WRTas,           "Shows the TAS world records.");
	RegConsoleCmdEx("sm_bwrtas",   SM_BWRTas,          "Shows the Bonus TAS world records.");
	RegConsoleCmdEx("sm_rr",       SM_RecentRecords,   "Shows recent records.");
	RegConsoleCmdEx("sm_overtake", SM_Overtake,        "Shows records you have lost recently.");
	RegConsoleCmdEx("sm_time",     SM_Time,            "Shows information about the specified player's time.");
	
	// Player cookies
	g_hRecordSoundCookie = RegClientCookie("timer_wrsounds", "Play world record sound", CookieAccess_Public);
	SetCookiePrefabMenu(g_hRecordSoundCookie, CookieMenu_OnOff, "World record sound");
	
	g_hPersonalBestSoundCookie = RegClientCookie("timer_pbsound", "Play personal best sound.", CookieAccess_Public);
	SetCookiePrefabMenu(g_hPersonalBestSoundCookie, CookieMenu_OnOff, "Personal best sound");
	
	g_hFailedSoundCookie = RegClientCookie("timer_failsound", "Play failed time sound.", CookieAccess_Public);
	SetCookiePrefabMenu(g_hFailedSoundCookie, CookieMenu_OnOff, "No new time sound");
	
	g_hAutohopCookie = RegClientCookie("timer_auto", "Autohop.", CookieAccess_Public);
	SetCookiePrefabMenu(g_hAutohopCookie, CookieMenu_OnOff, "Autohop");
	
	g_hPersonalizedStyleList = RegClientCookie("timer_personalizedstylelist", "Personalized style list", CookieAccess_Public);
	SetCookiePrefabMenu(g_hPersonalizedStyleList, CookieMenu_OnOff, "Personalized style list");
	
	// Translations
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			for(int tas; tas < 2; tas++)
			{
				g_hTimes[Type][style][tas]      = CreateArray(2);
				g_hTimesUsers[Type][style][tas] = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
			}
		}
	}
	
	g_hSound_Path_Record     = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hSound_Record_Data 	 = CreateArray(2);
	g_hSound_Path_Personal   = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hSound_Path_Fail       = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	RegConsoleCmd("sm_reloadfinishsounds", SM_ReloadFinishSounds);
	
	g_hAirAcceleration = FindConVar("sv_airaccelerate");
	g_hAirAcceleration.Flags &= ~FCVAR_NOTIFY;
	g_hAirAcceleration.Flags &= ~FCVAR_REPLICATED;
	
	g_hGravity = FindConVar("sv_gravity");
	g_hGravity.Flags &= ~FCVAR_NOTIFY;
	g_hGravity.Flags &= ~FCVAR_REPLICATED;
	
	if(g_Engine == Engine_CSGO)
	{
		g_hStaminaJumpCost  = FindConVar("sv_staminajumpcost");
		g_hStaminaMax       = FindConVar("sv_staminamax");
		g_hStaminaLandCost  = FindConVar("sv_staminalandcost");
		g_hAutoBunnyhopping = FindConVar("sv_autobunnyhopping");
		
		g_hStaminaJumpCost.Flags  &= ~FCVAR_NOTIFY;
		g_hStaminaJumpCost.Flags  &= ~FCVAR_REPLICATED;
		g_hStaminaMax.Flags       &= ~FCVAR_NOTIFY;
		g_hStaminaMax.Flags       &= ~FCVAR_REPLICATED;
		g_hStaminaLandCost.Flags  &= ~FCVAR_NOTIFY;
		g_hStaminaLandCost.Flags  &= ~FCVAR_REPLICATED;
		g_hAutoBunnyhopping.Flags &= ~FCVAR_NOTIFY;
		g_hAutoBunnyhopping.Flags &= ~FCVAR_REPLICATED;
	}
}

public void OnAllPluginsLoaded()
{
	if(LibraryExists("tas"))
	{
		g_bTasPluginLoaded = true;
	}
	
	if(LibraryExists("smartmsg") && g_bSmartMsgLoaded == false)
	{
		g_bSmartMsgLoaded = true;
	}
	
	g_bZonePluginLoaded = LibraryExists("zones");
	
	ReadStyleConfig();
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
	else if(StrEqual(library, "zones"))
	{
		g_bZonePluginLoaded = false;
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
	}
	else if(StrEqual(library, "zones"))
	{
		g_bZonePluginLoaded = true;
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Natives
	CreateNative("StartTimer", Native_StartTimer);
	CreateNative("StopTimer", Native_StopTimer);
	CreateNative("IsBeingTimed", Native_IsBeingTimed);
	CreateNative("FinishTimer", Native_FinishTimer);
	CreateNative("GetClientStyle", Native_GetClientStyle);
	CreateNative("IsTimerPaused", Native_IsTimerPaused);
	CreateNative("GetTypeStyleFromCommand", Native_GetTypeStyleFromCommand);
	CreateNative("GetClientTimerType", Native_GetClientTimerType);
	CreateNative("GetStyleConfig", Native_GetStyleConfig);
	CreateNative("GetTotalStyles", Native_GetTotalStyles);
	CreateNative("Timer_GetButtons", Native_GetButtons);
	CreateNative("Timer_GetFlags", Native_GetFlags);
	CreateNative("Timer_Pause", Native_PauseTimer);
	CreateNative("Timer_GetPersonalBest", Native_GetPersonalBest);
	CreateNative("Timer_GetClientTimerInfo", Native_GetClientTimerInfo);
	CreateNative("Timer_PlayerHasTime", Native_GetPlayerHasTime);
	CreateNative("Timer_GetTimesCount", Native_GetTimesCount);
	CreateNative("Timer_GetTimeAtPosition", Native_GetTimeAtPosition);
	CreateNative("Timer_GetNameAtPosition", Native_GetNameAtPosition);
	CreateNative("Timer_ShowPlayerTime", Native_ShowPlayerTime);
	CreateNative("Timer_GetPlayerMapRank", Native_GetPlayerMapRank);
	
	// Style methodmap natives
	CreateNative("Style.Style",                   Native_StyleStyle);
	CreateNative("Style.GetName",                 Native_StyleGetName);
	CreateNative("Style.GetNameShort",            Native_StyleGetNameShort);
	CreateNative("Style.EnabledInConfig.get",     Native_StyleEnabledInConfigGet);
	CreateNative("Style.Enabled.get",             Native_StyleEnabledGet);
	CreateNative("Style.GetAllowType",            Native_StyleGetAllowType);
	CreateNative("Style.Freestyle.get",           Native_StyleFreestyleGet);
	CreateNative("Style.FreestyleUnrestrict.get", Native_StyleFreestyleUnrestrictGet);
	CreateNative("Style.FreestyleAuto.get",       Native_StyleFreestyleAutoGet);
	CreateNative("Style.FreestyleEzHop.get",      Native_StyleFreestyleEzHopGet);
	CreateNative("Style.FreestyleNoLimit.get",    Native_StyleFreestyleNoLimitGet);
	CreateNative("Style.Auto.get",                Native_StyleAutoGet);
	CreateNative("Style.EzHop.get",               Native_StyleEzHopGet);
	CreateNative("Style.Gravity.get",             Native_StyleGravityGet);
	CreateNative("Style.RunSpeed.get",            Native_StyleRunSpeedGet);
	CreateNative("Style.MaxVelocity.get",         Native_StyleMaxVelocityGet);
	CreateNative("Style.MinimumFPS.get",          Native_StyleMinimumFPSGet);
	CreateNative("Style.CalculateSync.get",       Native_StyleCalculateSyncGet);
	CreateNative("Style.PreventLeft.get",         Native_StylePreventLeftGet);
	CreateNative("Style.PreventRight.get",        Native_StylePreventRightGet);
	CreateNative("Style.PreventBack.get",         Native_StylePreventBackGet);
	CreateNative("Style.PreventForward.get",      Native_StylePreventForwardGet);
	CreateNative("Style.RequireLeft.get",         Native_StyleRequireLeftGet);
	CreateNative("Style.RequireRight.get",        Native_StyleRequireRightGet);
	CreateNative("Style.RequireBack.get",         Native_StyleRequireBackGet);
	CreateNative("Style.RequireForward.get",      Native_StyleRequireForwardGet);
	CreateNative("Style.ShowNameOnHud.get",       Native_StyleShowNameOnHudGet);
	CreateNative("Style.ShowStrafesOnHud.get",    Native_StyleShowStrafesOnHudGet);
	CreateNative("Style.ShowJumpsOnHud.get",      Native_StyleShowJumpsOnHudGet);
	CreateNative("Style.CountLeftStrafe.get",     Native_StyleCountLeftStrafeGet);
	CreateNative("Style.CountRightStrafe.get",    Native_StyleCountRightStrafeGet);
	CreateNative("Style.CountBackStrafe.get",     Native_StyleCountBackStrafeGet);
	CreateNative("Style.CountForwardStrafe.get",  Native_StyleCountForwardStrafeGet);
	CreateNative("Style.GetUseGhost",             Native_StyleGetUseGhost);
	CreateNative("Style.GetSaveGhost",            Native_StyleGetSaveGhost);
	CreateNative("Style.MaxPrespeed.get",         Native_StyleMaxPrespeedGet);
	CreateNative("Style.SlowedSpeed.get",         Native_StyleSlowedSpeedGet);
	CreateNative("Style.IsSpecial.get",           Native_StyleIsSpecialGet);
	CreateNative("Style.HasSpecialKey",           Native_StyleHasSpecialKey);
	CreateNative("Style.AllowCheckpoints.get",    Native_StyleAllowCheckpointsGet);
	CreateNative("Style.PointScale.get",          Native_StylePointScaleGet);
	CreateNative("Style.AirAcceleration.get",     Native_StyleGetAirAcceleration);
	CreateNative("Style.EnableBunnyhopping.get",  Native_StyleGetEnableBunnyhopping);
	CreateNative("Style.Break.get",               Native_StyleGetBreak);
	CreateNative("Style.Start.get",               Native_StyleGetStart);
	CreateNative("Style.Selectable.get",          Native_StyleGetSelectable);
	CreateNative("Style.AllowTAS.get",            Native_StyleGetAllowTAS);
	CreateNative("Style.AntiNoClip.get",          Native_StyleGetAntiNoClip);
	CreateNative("Style.GroundStartOnly.get",     Native_StyleGetGroundStartOnly);
	
	
	// TimerInfo methodmap natives
	CreateNative("TimerInfo.TimerInfo",           Native_TimerInfoTimerInfo);
	CreateNative("TimerInfo.IsTiming.get",        Native_TimerInfoIsTimingGet);
	CreateNative("TimerInfo.IsTiming.set",        Native_TimerInfoIsTimingSet);
	CreateNative("TimerInfo.Paused.get",          Native_TimerInfoPausedGet);
	CreateNative("TimerInfo.Paused.set",          Native_TimerInfoPausedSet);
	CreateNative("TimerInfo.CurrentTime.get",     Native_TimerInfoCurrentTimeGet);
	CreateNative("TimerInfo.CurrentTime.set",     Native_TimerInfoCurrentTimeSet);
	CreateNative("TimerInfo.Type.get",            Native_TimerInfoTypeGet);
	CreateNative("TimerInfo.Type.set",            Native_TimerInfoTypeSet);
	CreateNative("TimerInfo.GetStyle",            Native_TimerInfoGetStyle);
	CreateNative("TimerInfo.SetStyle",            Native_TimerInfoSetStyle);
	CreateNative("TimerInfo.TotalSync.get",       Native_TimerInfoTotalSyncGet);
	CreateNative("TimerInfo.TotalSync.set",       Native_TimerInfoTotalSyncSet);
	CreateNative("TimerInfo.GoodSync.get",        Native_TimerInfoGoodSyncGet);
	CreateNative("TimerInfo.GoodSync.set",        Native_TimerInfoGoodSyncSet);
	CreateNative("TimerInfo.Sync.get",            Native_TimerInfoSyncGet);
	CreateNative("TimerInfo.CheckpointsUsed.get", Native_TimerInfoCheckpointsUsedGet);
	CreateNative("TimerInfo.CheckpointsUsed.set", Native_TimerInfoCheckpointsUsedSet);
	CreateNative("TimerInfo.Jumps.get",           Native_TimerInfoJumpsGet);
	CreateNative("TimerInfo.Jumps.set",           Native_TimerInfoJumpsSet);
	CreateNative("TimerInfo.Strafes.get",         Native_TimerInfoStrafesGet);
	CreateNative("TimerInfo.Strafes.set",         Native_TimerInfoStrafesSet);
	CreateNative("TimerInfo.ActiveStyle.get",     Native_TimerActiveStyleGet);
	
	// Forwards
	g_fwdOnTimerStart_Pre     = CreateGlobalForward("OnTimerStart_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimerStart_Post    = CreateGlobalForward("OnTimerStart_Post", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimerFinished_Pre  = CreateGlobalForward("OnTimerFinished_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimerFinished_Post = CreateGlobalForward("OnTimerFinished_Post", ET_Event, Param_Cell, Param_Float, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimerStopped       = CreateGlobalForward("OnTimerStopped", ET_Event, Param_Cell);
	g_fwdOnTimesDeleted       = CreateGlobalForward("OnTimesDeleted", ET_Event, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimesUpdated       = CreateGlobalForward("OnTimesUpdated", ET_Event, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Any);
	g_fwdOnStylesLoaded       = CreateGlobalForward("OnStylesLoaded", ET_Event);
	g_fwdOnTimesLoaded        = CreateGlobalForward("OnMapTimesLoaded", ET_Event);
	g_fwdOnStyleChanged       = CreateGlobalForward("OnStyleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	
	if(late == true)
	{
		UpdateMessages();
	}
	
	return APLRes_Success;
}

public void OnMapStart()
{
	// Set the map id
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	LoadRecordSounds();
	g_bTimesAreLoaded = false;
}

public void OnConfigsExecuted()
{
	// Reset temporary enabled and disabled styles
	for(int style; style < g_TotalStyles; style++)
	{
		g_StyleConfig[style].Enabled = g_StyleConfig[style].EnabledInConfig;
	}
	
	g_bAllowVelocityCap = GetConVarBool(g_hVelocityCap);
	g_bAllowAuto        = GetConVarBool(g_hAllowAuto);
	g_bAutoStopsTimer   = GetConVarBool(g_hAutoStopsTimer);
	g_bJumpInStartZone  = GetConVarBool(g_hJumpInStartZone);
}

public bool OnClientConnect(int client)
{
	g_TimerInfo[client]        = TimerInfo(client);
	g_bTimeIsLoaded[client]    = false;
	g_TimerInfo[client].Paused = false;
	g_fNoClipSpeed[client]     = 1.0;
	g_AllowedYawspeed[client]  = 0;
	g_fNoClipSpeed[client]     = 1.0;
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			if(g_StyleConfig[style].Enabled && g_StyleConfig[style].GetAllowType(Type))
			{
				g_TimerInfo[client].SetStyle(Type, style);
				break;
			}
		}
	}
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			for(int tas; tas < 2; tas++)
			{
				g_bPlayerHasTime[client][Type][style][tas] = false;
			}
		}
	}
	
	g_bFavoriteStylesLoaded[client] = false;
	if(g_hFavoriteStyles[client][0][0] == INVALID_HANDLE)
	{
		for(int type; type < MAX_TYPES; type++)
		{
			for(int tas; tas < 2; tas++)
			{
				g_hFavoriteStyles[client][type][tas] = new ArrayList(2);
			}
		}
	}
	else
	{
		for(int type; type < MAX_TYPES; type++)
		{
			for(int tas; tas < 2; tas++)
			{
				ClearArray(g_hFavoriteStyles[client][type][tas]);
			}
		}
	}
	
	return true;
}

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
	{
		QueryClientConVar(client, "fps_max", OnFpsMaxRetrieved);
	
		SDKHook(client, SDKHook_PreThinkPost, Hook_PreThink);
		
		ConVar c = FindConVar("sv_airaccelerate");
	
		if(c != null)
		{
			char sAirAccelerate[16];
			IntToString(Style(g_TimerStyle[client][g_TimerType[client]]).AirAcceleration, sAirAccelerate, sizeof(sAirAccelerate));
			SendConVarValue(client, c, sAirAccelerate);
			
			delete c;
		}
		
		if(g_Engine == Engine_CSGO)
		{
			if(Style(g_TimerStyle[client][g_TimerType[client]]).EzHop)
			{
				SendConVarValue(client, g_hStaminaJumpCost, "0.0");
				SendConVarValue(client, g_hStaminaMax, "0");
				SendConVarValue(client, g_hStaminaLandCost, "0.0");
			}
			else
			{
				SendConVarValue(client, g_hStaminaJumpCost, "0.080");
				SendConVarValue(client, g_hStaminaMax, "80");
				SendConVarValue(client, g_hStaminaLandCost, "0.050");
			}
			
			if(Style(g_TimerStyle[client][g_TimerType[client]]).Auto)
			{
				SendConVarValue(client, g_hAutoBunnyhopping, "1");
			}
			else
			{
				SendConVarValue(client, g_hAutoBunnyhopping, "0");
			}
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sCookie[32];
	GetClientCookie(client, g_hAutohopCookie, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hAutohopCookie, true);
	}
	
	GetClientCookie(client, g_hRecordSoundCookie, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hRecordSoundCookie, true);
	}
	
	GetClientCookie(client, g_hPersonalBestSoundCookie, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hPersonalBestSoundCookie, true);
	}
	
	GetClientCookie(client, g_hFailedSoundCookie, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hFailedSoundCookie, true);
	}
	
	GetClientCookie(client, g_hPersonalizedStyleList, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hPersonalizedStyleList, true);
	}
}

public void OnStyleChanged(int client, int oldStyle, int style, int type)
{
	if(Style(oldStyle).AirAcceleration != Style(style).AirAcceleration)
	{
		PrintColorText(client, "%s%sYour airacceleration has been changed to %s%d%s.", 
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			Style(style).AirAcceleration,
			g_msg_textcol);
	}
	
	char sGravity[16];
	IntToString(Style(style).Gravity, sGravity, sizeof(sGravity));
	SendConVarValue(client, g_hGravity, sGravity);
}

public void OnFpsMaxRetrieved(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	g_Fps[client] = StringToFloat(cvarValue);
	
	if(g_Fps[client] > 1000)
		g_Fps[client] = 1000.0;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(0 < client <= MaxClients)
	{
		if(sArgs[0] == '!' || sArgs[0] == '/')
		{
			int len = strlen(sArgs) + 1;
			char[] sArgs2 = new char[len];
			strcopy(sArgs2, len, sArgs);
			char sStyle[64];
			for(int style; style < g_TotalStyles; style++)
			{
				ReplaceString(sArgs2, len, "!", "");
				ReplaceString(sArgs2, len, "/", "");
				if(Style(style).Enabled && Style(style).GetAllowType(g_TimerType[client]) && g_StyleConfig[style].Selectable)
				{
					Style(style).GetName(sStyle, sizeof sStyle);
				
					if(StrEqual(sArgs2, sStyle, false))
					{
						ReplaceString(sStyle, sizeof(sStyle), "-", "");
						SetStyle(client, g_TimerType[client], style);
						return Plugin_Handled;
					}
					
					Style(style).GetNameShort(sStyle, sizeof sStyle);
					
					if(StrEqual(sArgs2, sStyle, false))
					{
						ReplaceString(sStyle, sizeof(sStyle), "-", "");
						SetStyle(client, g_TimerType[client], style);
						return Plugin_Handled;
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

// TimerInfo methodmap declarations
public int Native_TimerInfoTimerInfo(Handle plugin, int numParams)
{
	return GetNativeCell(1);
}

public int Native_TimerInfoIsTimingGet(Handle plugin, int numParams)
{
	return g_TimerIsTiming[GetNativeCell(1)];
}

public int Native_TimerInfoIsTimingSet(Handle plugin, int numParams)
{
	g_TimerIsTiming[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_TimerInfoPausedGet(Handle plugin, int numParams)
{
	return g_TimerPaused[GetNativeCell(1)];
}

public int Native_TimerInfoPausedSet(Handle plugin, int numParams)
{
	g_TimerPaused[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_TimerInfoCurrentTimeGet(Handle plugin, int numParams)
{
	if(g_TimerInfo[GetNativeCell(1)].IsTiming == false)
		return 0;
		
	return view_as<int>(g_TimerCurrentTime[GetNativeCell(1)]);
}

public int Native_TimerInfoCurrentTimeSet(Handle plugin, int numParams)
{
	g_TimerCurrentTime[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_GetPersonalBest(Handle plugin, int numParams)
{
	return view_as<int>(g_fTime[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)][GetNativeCell(4)]);
}

public int Native_GetPlayerHasTime(Handle plugin, int numParams)
{
	return g_bPlayerHasTime[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)][GetNativeCell(4)];
}

public int Native_GetTimesCount(Handle plugin, int numParams)
{
	return GetArraySize(g_hTimes[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)]);
}

public int Native_GetTimeAtPosition(Handle plugin, int numParams)
{
	int Type     = GetNativeCell(1);
	int style    = GetNativeCell(2);
	int tas      = GetNativeCell(3);
	int position = GetNativeCell(4);
	int iSize    = GetArraySize(g_hTimes[Type][style][tas]);
	
	if(position < 0 || position >= iSize)
	{
		return 0;
	}
	
	return GetArrayCell(g_hTimes[Type][style][tas], position, 1);
}

public int Native_GetNameAtPosition(Handle plugin, int numParams)
{
	int Type     = GetNativeCell(1);
	int style    = GetNativeCell(2);
	int tas      = GetNativeCell(3);
	int position = GetNativeCell(4);
	int iSize    = GetArraySize(g_hTimesUsers[Type][style][tas]);
	
	if(position < 0 || position >= iSize)
	{
		char sError[32];
		FormatEx(sError, sizeof(sError), "INVALID Pos:%d|Size:%d", position, iSize);
		SetNativeString(6, sError, GetNativeCell(5));
		return false;
	}
	
	char sName[MAX_NAME_LENGTH];
	GetArrayString(g_hTimesUsers[Type][style][tas], position, sName, MAX_NAME_LENGTH);
	SetNativeString(5, sName, GetNativeCell(5));
	
	return true;
}

public int Native_ShowPlayerTime(Handle plugin, int numParams)
{
	//DB_ShowTime(client, type, style, tas, playerId, sInfoExploded[4]);
	int client   = GetNativeCell(1);
	int type     = GetNativeCell(2);
	int style    = GetNativeCell(3);
	int tas      = GetNativeCell(4);
	int playerId = GetNativeCell(5);
	char sMap[PLATFORM_MAX_PATH];
	GetNativeString(6, sMap, PLATFORM_MAX_PATH);
	
	DB_ShowTimeFromMapName(client, type, style, tas, playerId, sMap);
}

void DB_ShowTimeFromMapName(int client, int type, int style, int tas, int playerId, const char[] sMap)
{
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(type);
	pack.WriteCell(style);
	pack.WriteCell(tas);
	pack.WriteCell(playerId);

	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT MapID FROM maps WHERE MapName='%s' AND InMapCycle=1", sMap);
	SQL_TQuery(g_DB, ShowTimeFromMapName_Callback, sQuery, pack);
}

public void ShowTimeFromMapName_Callback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if(hndl != INVALID_HANDLE)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		
		if(client != 0)
		{
			if(SQL_FetchRow(hndl))
			{
				int type     = pack.ReadCell();
				int style    = pack.ReadCell();
				int tas      = pack.ReadCell();
				int playerId = pack.ReadCell();
				
				DB_ShowTime(client, type, style, tas, playerId, SQL_FetchInt(hndl, 0));
			}
			else
			{
				PrintColorText(client, "%s%sSorry, the selected map was not found in the database.",
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	delete pack;
}

public int Native_GetPlayerMapRank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int type   = GetNativeCell(2);
	int style  = GetNativeCell(3);
	int tas    = GetNativeCell(4);
	
	if(g_bPlayerHasTime[client][type][style][tas])
	{
		return g_iPosition[client][type][style][tas];
	}
	
	return -1;
}

public int Native_TimerInfoTypeGet(Handle plugin, int numParams)
{
	return g_TimerType[GetNativeCell(1)];
}

public int Native_TimerInfoTypeSet(Handle plugin, int numParams)
{
	g_TimerType[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_TimerInfoGetStyle(Handle plugin, int numParams)
{
	return g_TimerStyle[GetNativeCell(1)][GetNativeCell(2)];
}

public int Native_TimerInfoSetStyle(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(IsFakeClient(client))
	{
		return;
	}
	
	int oldStyle = g_TimerInfo[client].GetStyle(g_TimerInfo[client].Type);
	int type     = GetNativeCell(2);
	int style    = GetNativeCell(3);
	g_TimerStyle[client][type] = style;
	
	if(oldStyle != style)
	{
		Call_StartForward(g_fwdOnStyleChanged);
		Call_PushCell(client);
		Call_PushCell(oldStyle);
		Call_PushCell(style);
		Call_PushCell(type);
		Call_Finish();
		
		ConVar c = FindConVar("sv_airaccelerate");
	
		if(c != null)
		{
			char sAirAccelerate[16];
			IntToString(Style(style).AirAcceleration, sAirAccelerate, sizeof(sAirAccelerate));
			SendConVarValue(client, c, sAirAccelerate);
			delete c;
		}
		
		if(g_Engine == Engine_CSGO)
		{
			if(Style(style).EzHop)
			{
				SendConVarValue(client, g_hStaminaJumpCost, "0.0");
				SendConVarValue(client, g_hStaminaMax, "0");
				SendConVarValue(client, g_hStaminaLandCost, "0.0");
			}
			else
			{
				SendConVarValue(client, g_hStaminaJumpCost, "0.080");
				SendConVarValue(client, g_hStaminaMax, "80");
				SendConVarValue(client, g_hStaminaLandCost, "0.050");
			}
			
			if(Style(style).Auto)
			{
				SendConVarValue(client, g_hAutoBunnyhopping, "1");
			}
			else
			{
				SendConVarValue(client, g_hAutoBunnyhopping, "0");
			}
		}
	}
}

public int Native_TimerInfoTotalSyncGet(Handle plugin, int numParams)
{
	return g_TimerTotalSync[GetNativeCell(1)];
}

public int Native_TimerInfoTotalSyncSet(Handle plugin, int numParams)
{
	g_TimerTotalSync[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_TimerInfoGoodSyncGet(Handle plugin, int numParams)
{
	return g_TimerGoodSync[GetNativeCell(1)];
}

public int Native_TimerInfoGoodSyncSet(Handle plugin, int numParams)
{
	g_TimerGoodSync[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_TimerInfoSyncGet(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(g_TimerInfo[client].TotalSync == 0)
		return 0;
	
	return view_as<int>(float(g_TimerInfo[client].GoodSync) / float(g_TimerInfo[client].TotalSync) * 100.0);
}

public int Native_TimerInfoCheckpointsUsedGet(Handle plugin, int numParams)
{
	return g_TimerCheckpointsUsed[GetNativeCell(1)];
}

public int Native_TimerInfoCheckpointsUsedSet(Handle plugin, int numParams)
{
	g_TimerCheckpointsUsed[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_TimerInfoJumpsGet(Handle plugin, int numParams)
{
	return g_TimerJumps[GetNativeCell(1)];
}

public int Native_TimerInfoJumpsSet(Handle plugin, int numParams)
{
	g_TimerJumps[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_TimerInfoStrafesGet(Handle plugin, int numParams)
{
	return g_TimerStrafes[GetNativeCell(1)];
}

public int Native_TimerInfoStrafesSet(Handle plugin, int numParams)
{
	g_TimerStrafes[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_TimerActiveStyleGet(Handle plugin, int numParams)
{
	return g_TimerStyle[GetNativeCell(1)][g_TimerType[GetNativeCell(1)]];
}

// Style methodmap native declarations
public int Native_StyleStyle(Handle plugin, int numParams)
{
	return GetNativeCell(1);
}

public int Native_StyleEnabledInConfigGet(Handle plugin, int numParams)
{
	return g_StyleEnabledInConfig[GetNativeCell(1)];
}

public int Native_StyleEnabledGet(Handle plugin, int numParams)
{
	return g_StyleEnabled[GetNativeCell(1)];
}

public int Native_StyleGetName(Handle plugin, int numParams)
{
	SetNativeString(2, g_StyleName[GetNativeCell(1)], GetNativeCell(3));
}

public int Native_StyleGetNameShort(Handle plugin, int numParams)
{
	SetNativeString(2, g_StyleNameShort[GetNativeCell(1)], GetNativeCell(3));
}

public int Native_StyleGetAllowType(Handle plugin, int numParams)
{
	return g_AllowType[GetNativeCell(1)][GetNativeCell(2)];
}

public int Native_StyleFreestyleGet(Handle plugin, int numParams)
{
	return g_Freestyle[GetNativeCell(1)];
}

public int Native_StyleFreestyleUnrestrictGet(Handle plugin, int numParams)
{
	return g_FreestyleUnrestrict[GetNativeCell(1)];
}

public int Native_StyleFreestyleAutoGet(Handle plugin, int numParams)
{
	return g_FreestyleAuto[GetNativeCell(1)];
}

public int Native_StyleFreestyleEzHopGet(Handle plugin, int numParams)
{
	return g_FreestyleEzHop[GetNativeCell(1)];
}

public int Native_StyleFreestyleNoLimitGet(Handle plugin, int numParams)
{
	return g_FreestyleNoLimit[GetNativeCell(1)];
}

public int Native_StyleAutoGet(Handle plugin, int numParams)
{
	return g_StyleUsesAuto[GetNativeCell(1)];
}

public int Native_StyleEzHopGet(Handle plugin, int numParams)
{
	return g_StyleUsesEzHop[GetNativeCell(1)];
}

public int Native_StyleGravityGet(Handle plugin, int numParams)
{
	return view_as<int>(g_StyleGravity[GetNativeCell(1)]);
}

public int Native_StyleRunSpeedGet(Handle plugin, int numParams)
{
	return view_as<int>(g_StyleRunSpeed[GetNativeCell(1)]);
}

public int Native_StyleMaxVelocityGet(Handle plugin, int numParams)
{
	return view_as<int>(g_StyleMaxVel[GetNativeCell(1)]);
}

public int Native_StyleMinimumFPSGet(Handle plugin, int numParams)
{
	return view_as<int>(g_StyleMinFPS[GetNativeCell(1)]);
}

public int Native_StyleCalculateSyncGet(Handle plugin, int numParams)
{
	return g_StyleCalcSync[GetNativeCell(1)];
}

public int Native_StylePreventLeftGet(Handle plugin, int numParams)
{
	return g_StylePreventLeft[GetNativeCell(1)];
}

public int Native_StylePreventRightGet(Handle plugin, int numParams)
{
	return g_StylePreventRight[GetNativeCell(1)];
}

public int Native_StylePreventBackGet(Handle plugin, int numParams)
{
	return g_StylePreventBack[GetNativeCell(1)];
}

public int Native_StylePreventForwardGet(Handle plugin, int numParams)
{
	return g_StylePreventForward[GetNativeCell(1)];
}

public int Native_StyleRequireLeftGet(Handle plugin, int numParams)
{
	return g_StyleRequireLeft[GetNativeCell(1)];
}

public int Native_StyleRequireRightGet(Handle plugin, int numParams)
{
	return g_StyleRequireRight[GetNativeCell(1)];
}

public int Native_StyleRequireBackGet(Handle plugin, int numParams)
{
	return g_StyleRequireBack[GetNativeCell(1)];
}

public int Native_StyleRequireForwardGet(Handle plugin, int numParams)
{
	return g_StyleRequireForward[GetNativeCell(1)];
}

public int Native_StyleShowNameOnHudGet(Handle plugin, int numParams)
{
	return g_ShowStyleOnHud[GetNativeCell(1)];
}

public int Native_StyleShowStrafesOnHudGet(Handle plugin, int numParams)
{
	return g_ShowStrafesOnHud[GetNativeCell(1)];
}

public int Native_StyleShowJumpsOnHudGet(Handle plugin, int numParams)
{
	return g_ShowJumpsOnHud[GetNativeCell(1)];
}

public int Native_StyleCountLeftStrafeGet(Handle plugin, int numParams)
{
	return g_CountLeftStrafe[GetNativeCell(1)];
}

public int Native_StyleCountRightStrafeGet(Handle plugin, int numParams)
{
	return g_CountRightStrafe[GetNativeCell(1)];
}

public int Native_StyleCountBackStrafeGet(Handle plugin, int numParams)
{
	return g_CountBackStrafe[GetNativeCell(1)];
}

public int Native_StyleCountForwardStrafeGet(Handle plugin, int numParams)
{
	return g_CountForwardStrafe[GetNativeCell(1)];
}

public int Native_StyleGetUseGhost(Handle plugin, int numParams)
{
	return view_as<int>(g_UseGhost[GetNativeCell(1)][GetNativeCell(2)]);
}

public int Native_StyleGetSaveGhost(Handle plugin, int numParams)
{
	return g_SaveGhost[GetNativeCell(1)][GetNativeCell(2)];
}

public int Native_StyleMaxPrespeedGet(Handle plugin, int numParams)
{
	return view_as<int>(g_MaxPrespeed[GetNativeCell(1)]);
}

public int Native_StyleSlowedSpeedGet(Handle plugin, int numParams)
{
	return view_as<int>(g_SlowedSpeed[GetNativeCell(1)]);
}

public int Native_StyleIsSpecialGet(Handle plugin, int numParams)
{
	return g_StyleIsSpecial[GetNativeCell(1)];
}

public int Native_StyleHasSpecialKey(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(2, len);
	len++;
	
	char[] buffer = new char[len];
	
	GetNativeString(2, buffer, len);
	int delimiterCount, style = GetNativeCell(1);
	int specialKeyLen = strlen(g_StyleSpecialKey[style]) + 1;
	for(int idx; idx < specialKeyLen; idx++)
	{
		if(g_StyleSpecialKey[style][idx] == ';')
			delimiterCount++;
	}
	
	char[][] specialKeyList = new char[delimiterCount + 1][32];
	ExplodeString(g_StyleSpecialKey[style], ";", specialKeyList, delimiterCount + 1, 32, false);
	
	for(int idx; idx < delimiterCount + 1; idx++)
	{
		if(StrEqual(specialKeyList[idx], buffer))
			return 1;
	}
	
	return 0;
}

public int Native_StyleAllowCheckpointsGet(Handle plugin, int numParams)
{
	return g_AllowCheckpoints[GetNativeCell(1)];
}

public int Native_StylePointScaleGet(Handle plugin, int numParams)
{
	return view_as<int>(g_StylePointScale[GetNativeCell(1)]);
}

public int Native_StyleGetAirAcceleration(Handle plugin, int numParams)
{
	return view_as<int>(g_StyleAirAcceleration[GetNativeCell(1)]);
}

public int Native_StyleGetEnableBunnyhopping(Handle plugin, int numParams)
{
	return view_as<int>(g_StyleEnableBunnyhopping[GetNativeCell(1)]);
}

public int Native_StyleGetBreak(Handle plugin, int numParams)
{
	return g_StyleBreak[GetNativeCell(1)];
}

public int Native_StyleGetStart(Handle plugin, int numParams)
{
	return g_StyleStart[GetNativeCell(1)];
}

public int Native_StyleGetSelectable(Handle plugin, int numParams)
{
	return g_StyleSelectable[GetNativeCell(1)];
}

public int Native_StyleGetAllowTAS(Handle plugin, int numParams)
{
	return view_as<int>(g_StyleAllowTAS[GetNativeCell(1)]);
}

public int Native_StyleGetAntiNoClip(Handle plugin, int numParams)
{
	return view_as<int>(g_StyleAntiNoClip[GetNativeCell(1)]);
}

public int Native_StyleGetGroundStartOnly(Handle plugin, int numParams)
{
	return view_as<int>(g_StyleGroundStartOnly[GetNativeCell(1)]);
}

public int Native_GetTotalStyles(Handle plugin, int numParams)
{
	return g_TotalStyles;
}

public void Hook_PreThink(int client)
{
	if(IsFakeClient(client) || !IsPlayerAlive(client))
		return;
	
	//bool bTas = g_bTasPluginLoaded?TAS_InEditMode(client):false;
	int style = g_TimerInfo[client].ActiveStyle;
	
	SetConVarInt(g_hAirAcceleration, Style(style).AirAcceleration);
	
	SetConVarInt(g_hGravity, Style(style).Gravity);
	
	if(g_Engine == Engine_CSGO)
	{
		if(Style(style).EzHop)
		{
			SetConVarFloat(g_hStaminaJumpCost, 0.0);
			SetConVarInt(g_hStaminaMax, 0);
			SetConVarFloat(g_hStaminaLandCost, 0.0);
		}
		else
		{
			SetConVarFloat(g_hStaminaJumpCost, 0.080);
			SetConVarInt(g_hStaminaMax, 80);
			SetConVarFloat(g_hStaminaLandCost, 0.050);
		}
		
		if(Style(style).Auto)
		{
			SetConVarBool(g_hAutoBunnyhopping, true);
		}
		else
		{
			SetConVarBool(g_hAutoBunnyhopping, false);
		}
	}
	
}

public void OnPlayerIDLoaded(int client)
{
	if(g_bTimesAreLoaded == true)
	{
		LoadPlayerInfo(client);
	}
	
	DB_LoadPlayerFavoriteStyles(client);
}

public void OnZonesLoaded()
{	
	DB_LoadTimes();
}

public void OnCheckpointUsed(int client)
{
	g_TimerInfo[client].CheckpointsUsed++;
}

public void OnAllowPauseChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(GetConVarInt(convar) == 0)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsTimerPaused(client))
			{
				UnpauseTimer(client);
			}
		}
	}
}

public void OnVelocityCapChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bAllowVelocityCap = view_as<bool>(StringToInt(newValue));
}

public void OnAutoStopsTimerChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(StringToInt(newValue) == 1)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && IsBeingTimed(client, TIMER_ANY) && GetCookieBool(client, g_hAutohopCookie) && !IsFakeClient(client))
			{
				StopTimer(client);
			}
		}
	}
}

public void OnAllowJumpInStartZoneChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bJumpInStartZone = view_as<bool>(StringToInt(newValue));
}

public void OnAllowAutoChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bAllowAuto = view_as<bool>(StringToInt(newValue));
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Player timers should stop when they die
	if(client != 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		StopTimer(client);
	}
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	// Player timers should stop when they switch teams
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(client != 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		StopTimer(client);
		if(GetEventInt(event, "oldteam") == 0)
		{	
			//ShowOvertake(client, client, false);
		}
	}
}

public Action Event_Disconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(client != 0 && GetPlayerID(client) != 0)
	{
		int clients[1];
		clients[0] = client;
		UpdateConnectionTime(clients, 1, null, 0);
	}
}

public Action Event_ChangeName(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsClientInGame(client) == false || IsFakeClient(client) == true || g_bTimesAreLoaded == false)
	{
		return;
	}
	
	for(int Type = 0; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			for(int tas; tas < 2; tas++)
			{
				if(g_bPlayerHasTime[client][Type][style][tas] == true)
				{
					char sNewName[MAX_NAME_LENGTH];
					GetEventString(event, "newname", sNewName, MAX_NAME_LENGTH);
					SetArrayString(g_hTimesUsers[Type][style][tas], g_iPosition[client][Type][style][tas], sNewName);
				}
			}
		}
	}
}

public void OnNextMapChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int[] clients = new int[MaxClients + 1];
	int numClients;
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetPlayerID(client) != 0)
		{
			clients[numClients++] = client;
		}
	}
	
	if(numClients > 0)
	{
		UpdateConnectionTime(clients, numClients, null, 0);
	}
}

void UpdateConnectionTime(const int[] clients, int numClients, Transaction t, int client)
{
	if(t == null)
	{
		t = new Transaction();
	}
	
	char sQuery[256];
	
	for(int idx; idx < numClients; idx++)
	{
		FormatEx(sQuery, sizeof(sQuery), "UPDATE players SET LastConnection = UNIX_TIMESTAMP() WHERE PlayerID = %d",
			GetPlayerID(clients[idx]));
		t.AddQuery(sQuery, 0);
	}
	
	Timer_Log(true, "SQL Query Start: (Function = UpdateConnectionTime, Time = %d)", GetTime());
	if(client != 0)
	{
		SQL_ExecuteTransaction(g_DB, t, OnOvertakeSuccess, OnOvertakeFailure, GetClientUserId(client));
	}
	else
	{
		SQL_ExecuteTransaction(g_DB, t, OnOvertakeSuccess, OnOvertakeFailure, 0);
	}
	
}

void ShowOvertake(int client, int target, bool force)
{
	Transaction t = new Transaction();
	
	int playerId = GetPlayerID(target);
	
	char sForce[256];
	if(force == true)
	{
		FormatEx(sForce, sizeof(sForce), "0");
	}
	else
	{
		FormatEx(sForce, sizeof(sForce), "(SELECT LastConnection FROM players WHERE PlayerID = %d)",
			playerId);
	}
	
	char sQuery[2048];
	FormatEx(sQuery, sizeof(sQuery), 
	"SELECT MapName, Type, Style, TAS, Time, MyTime, id, Overtaker \
	FROM (SELECT m.MapName, rr.Type, rr.Style, rr.TAS, rr.Time, ot.id, ot.Overtaker \
	FROM (SELECT * FROM overtake WHERE Overtakee = %d AND Timestamp > %s) AS ot,  \
	recent_records AS rr, maps AS m WHERE ot.OvertakerTimeId = rr.Id AND rr.MapID = m.MapID ORDER BY ot.Timestamp DESC) AS a \
	JOIN \
	(SELECT MyTime, id2 \
	FROM (SELECT rr.Time AS MyTime, ot.id AS id2 \
	FROM (SELECT * FROM overtake WHERE Overtakee = %d AND Timestamp > %s) AS ot, \
	recent_records AS rr WHERE ot.OvertakeeTimeId = rr.Id ORDER BY ot.Timestamp DESC) AS a) AS c \
	ON a.id = c.id2",
		playerId,
		sForce,
		playerId,
		sForce);
	
	t.AddQuery(sQuery, true);
		
	if(force == false)
	{
		int clients[1];
		clients[0] = client;
		UpdateConnectionTime(clients, 1, t, client);
	}
	else
	{
		Timer_Log(true, "SQL Query Start: (Function = ShowOvertake, Time = %d)", GetTime());
		SQL_ExecuteTransaction(g_DB, t, OnOvertakeSuccess, OnOvertakeFailure, GetClientUserId(client));
	}
}

ArrayList g_OvertakeData[MAXPLAYERS + 1], g_OvertakeMap[MAXPLAYERS + 1];
//int g_OvertakeParam[MAXPLAYERS + 1] = {-1, ...};

public void OnOvertakeSuccess(Database db, any data, int numQueries, Handle[] results, bool[] isOvertake)
{
	Timer_Log(true, "SQL Query Finish: (Function = ShowOvertake/UpdateConnectionTime, Time = %d)", GetTime());
	int client = GetClientOfUserId(data);
	
	if(client != 0)
	{
		if(isOvertake[0] == true)
		{
			int recordsStolen = SQL_GetRowCount(results[0]);
			PrintColorText(client, "%s%sYou have lost %s%d%s records since your last connection.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				recordsStolen,
				g_msg_textcol);
			if(recordsStolen == 0)
			{
				return;
			}
			
			if(g_OvertakeData[client] == INVALID_HANDLE)
			{
				g_OvertakeData[client] = CreateArray(5);
				g_OvertakeMap[client]  = CreateArray(PLATFORM_MAX_PATH);
			}
			
			ClearArray(g_OvertakeData[client]);
			ClearArray(g_OvertakeMap[client]);
			
			Menu menu = new Menu(Menu_Overtake);
			menu.Pagination = 4;
			menu.SetTitle("Records Recently Stolen From You\n \n");
			
			char sMap[PLATFORM_MAX_PATH], sTheirTime[64], sYourTime[64], sDisplay[256], sType[32], sStyle[32], sOvertaker[MAX_NAME_LENGTH];
			int Type, style, tas, overtaker;
			float fTheirTime, fYourTime;
			while(SQL_FetchRow(results[0]))
			{
				SQL_FetchString(results[0], 0, sMap, PLATFORM_MAX_PATH);
				Type       = SQL_FetchInt(results[0], 1);
				style      = SQL_FetchInt(results[0], 2);
				tas        = SQL_FetchInt(results[0], 3);
				fTheirTime = SQL_FetchFloat(results[0], 4);
				fYourTime  = SQL_FetchFloat(results[0], 5);
				overtaker  = SQL_FetchInt(results[0], 7);
				
				GetTypeName(Type, sType, sizeof(sType));
				Style(style).GetName(sStyle, sizeof(sStyle));
				FormatPlayerTime(fTheirTime, sTheirTime, sizeof(sTheirTime), 1);
				FormatPlayerTime(fYourTime, sYourTime, sizeof(sYourTime), 1);
				GetNameFromPlayerID(overtaker, sOvertaker, sizeof(sOvertaker));
				
				FormatEx(sDisplay, sizeof(sDisplay), "%s by %s (%s - %s%s)\n Their time: %s\n Your time: %s",
					sMap, sOvertaker, sType, sStyle, tas?"- TAS":"", sTheirTime, sYourTime);
				menu.AddItem("", sDisplay);
			}
			
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

public int Menu_Overtake(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public void OnOvertakeFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	Timer_Log(false, "OnOvertakeFailure: %s", error);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Anti-time-cheat
	g_fSpawnTime[client] = GetEngineTime();
	
	// Player timers should stop when they spawn
	StopTimer(client);
}

public Action Event_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Increase jump count for the hud hint text, it resets to 0 when StartTimer for the client is called
	if(g_TimerInfo[client].IsTiming == true)
	{
		g_TimerInfo[client].Jumps++;
		g_AllowedYawspeed[client] = 0;
	}
	
	int style = g_TimerInfo[client].GetStyle(g_TimerInfo[client].Type);
	
	if(g_StyleConfig[style].EzHop == true)
	{
		if(g_Engine == Engine_CSS)
		{
			SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
		}
		else if(g_Engine == Engine_CSGO)
		{
			SetConVarFloat(g_hStaminaJumpCost, 0.0);
			SetConVarInt(g_hStaminaMax, 0);
			SetConVarFloat(g_hStaminaLandCost, 0.0);
		}
	}
	else if(g_bZonePluginLoaded && g_StyleConfig[style].Freestyle)
	{
		if(Timer_InsideZone(client, FREESTYLE, 1 << style, view_as<int>(zFs_EzHop)) != -1)
		{
			if(g_Engine == Engine_CSS)
			{
				SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
			}
			else if(g_Engine == Engine_CSGO)
			{
				SetConVarFloat(g_hStaminaJumpCost, 0.0);
				SetConVarInt(g_hStaminaMax, 0);
				SetConVarFloat(g_hStaminaLandCost, 0.0);
			}
		}
	}
	else if(g_Engine == Engine_CSGO)
	{
		SetConVarFloat(g_hStaminaJumpCost, 0.080);
		SetConVarInt(g_hStaminaMax, 80);
		SetConVarFloat(g_hStaminaLandCost, 0.050);
	}
}

public Action Event_PlayerJump_Post(Event event, const char[] name, bool dontBroadcast)
{
	// Check max velocity on player jump event rather than OnPlayerRunCmd, rewards better strafing
	if(g_bAllowVelocityCap == true)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		int style = g_TimerInfo[client].GetStyle(g_TimerInfo[client].Type);
		
		if(g_StyleConfig[style].MaxVelocity != 0.0)
		{
			// Has to be on next game frame, TeleportEntity doesn't seem to work in event player_jump
			RequestFrame(Timer_CheckVel, client);
		}
	}
}

public void Timer_CheckVel(int client)
{
	int style = g_TimerInfo[client].GetStyle(g_TimerInfo[client].Type);
	float fVel = GetClientVelocity(client, true, true, false);
		
	if(fVel > g_StyleConfig[style].MaxVelocity)
	{
		float vVel[3];
		Entity_GetAbsVelocity(client, vVel);
		
		float fTemp = vVel[2];
		ScaleVector(vVel, g_StyleConfig[style].MaxVelocity/fVel);
		vVel[2] = fTemp;
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}

public Action SM_ReloadFinishSounds(int client, int args)
{
	if(!Timer_ClientHasTimerFlag(client, "config", Admin_Generic))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}

	LoadRecordSounds();
	
	return Plugin_Handled;
}

// Auto bhop
public Action SM_Auto(int client, int args)
{
	if(g_bAllowAuto == true)
	{
		if (args < 1)
		{
			SetCookieBool(client, g_hAutohopCookie, !GetCookieBool(client, g_hAutohopCookie));
			
			if(g_bAutoStopsTimer && GetCookieBool(client, g_hAutohopCookie))
			{
				StopTimer(client);
			}
			
			if(GetCookieBool(client, g_hAutohopCookie))
			{
				PrintColorText(client, "%s%sAuto bhop %senabled",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol);
			}
			else
			{
				PrintColorText(client, "%s%sAuto bhop %sdisabled",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol);
			}
		}
		else if (args == 1)
		{
			char sArg[128];
			GetCmdArgString(sArg, sizeof(sArg));
			int target = FindTarget(client, sArg, true, false);
			if(target != -1)
			{
				if(GetCookieBool(client, g_hAutohopCookie))
				{
					PrintColorText(client, "%s%sPlayer %s%N%s has auto bhop %senabled",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						target,
						g_msg_textcol,
						g_msg_varcol);
				}
				else
				{
					PrintColorText(client, "%s%sPlayer %s%N%s has auto bhop %sdisabled",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						target,
						g_msg_textcol,
						g_msg_varcol);
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action SM_StopTimer(int client, int args)
{
	StopTimer(client);
	
	return Plugin_Handled;
}

public Action SM_WR(int client, int args)
{
	if(args == 0)
	{
		ShowWorldRecordMenu(client, TIMER_MAIN, 0, g_sMapName);
	}
	else
	{
		char sArg[64];
		GetCmdArg(1, sArg, sizeof(sArg));
		if(Timer_IsMapInMapCycle(sArg))
		{
			ShowWorldRecordMenu(client, TIMER_MAIN, 0, sArg);
		}
		else
		{
			PrintColorText(client, "%s%s%s%s is not a map found in the server's mapcycle.",
				g_msg_start,
				g_msg_varcol,
				sArg,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

public Action SM_BWR(int client, int args)
{
	if(args == 0)
	{
		ShowWorldRecordMenu(client, TIMER_BONUS, 0, g_sMapName);
	}
	else
	{
		char sArg[64];
		GetCmdArg(1, sArg, sizeof(sArg));
		if(Timer_IsMapInMapCycle(sArg))
		{
			ShowWorldRecordMenu(client, TIMER_BONUS, 0, sArg);
		}
		else
		{
			PrintColorText(client, "%s%s%s%s is not a map found in the server's mapcycle.",
				g_msg_start,
				g_msg_varcol,
				sArg,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

public Action SM_WRTas(int client, int args)
{
	if(args == 0)
	{
		ShowWorldRecordMenu(client, TIMER_MAIN, 1, g_sMapName);
	}
	else
	{
		char sArg[64];
		GetCmdArg(1, sArg, sizeof(sArg));
		if(Timer_IsMapInMapCycle(sArg))
		{
			ShowWorldRecordMenu(client, TIMER_MAIN, 1, sArg);
		}
		else
		{
			PrintColorText(client, "%s%s%s%s is not a map found in the server's mapcycle.",
				g_msg_start,
				g_msg_varcol,
				sArg,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

public Action SM_BWRTas(int client, int args)
{
	if(args == 0)
	{
		ShowWorldRecordMenu(client, TIMER_BONUS, 1, g_sMapName);
	}
	else
	{
		char sArg[64];
		GetCmdArg(1, sArg, sizeof(sArg));
		if(Timer_IsMapInMapCycle(sArg))
		{
			ShowWorldRecordMenu(client, TIMER_BONUS, 1, sArg);
		}
		else
		{
			PrintColorText(client, "%s%s%s%s is not a map found in the server's mapcycle.",
				g_msg_start,
				g_msg_varcol,
				sArg,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

char g_sWRMenu_Map[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

void ShowWorldRecordMenu(int client, int type, int tas, const char[] sMap)
{
	strcopy(g_sWRMenu_Map[client], PLATFORM_MAX_PATH, sMap);
	char sType[32], sStyle[32], sInfo[128];
	
	GetTypeName(type, sType, sizeof(sType));
	Menu menu = new Menu(Menu_WRStyleSelection);
	menu.SetTitle("%s world records for %s timer %s", sMap, sType, tas?"(TAS)":"");
	
	if(AreClientCookiesCached(client) && GetCookieBool(client, g_hPersonalizedStyleList) && g_bFavoriteStylesLoaded[client] == true && g_hFavoriteStyles[client][type][tas].Length > 0)
	{
		bool[] styleUsed = new bool[g_TotalStyles];
		
		for(int idx; idx < g_hFavoriteStyles[client][type][tas].Length; idx++)
		{
			int style = g_hFavoriteStyles[client][type][tas].Get(idx, 1);
			
			if(g_StyleConfig[style].Enabled && g_StyleConfig[style].GetAllowType(type) && g_StyleConfig[style].Selectable && g_StyleConfig[style].AllowTAS)
			{
				g_StyleConfig[style].GetName(sStyle, sizeof(sStyle));
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", type, style, tas);
				menu.AddItem(sInfo, sStyle);
				styleUsed[style] = true;
			}
		}
		
		for(int style; style < g_TotalStyles; style++)
		{
			if(g_StyleConfig[style].Enabled && g_StyleConfig[style].GetAllowType(type) && g_StyleConfig[style].Selectable && (!tas || g_StyleConfig[style].AllowTAS) && styleUsed[style] == false)
			{
				g_StyleConfig[style].GetName(sStyle, sizeof(sStyle));
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", type, style, tas);
				menu.AddItem(sInfo, sStyle);
			}
		}
	}
	else
	{
		for(int style; style < g_TotalStyles; style++)
		{
			if(g_StyleConfig[style].Enabled && g_StyleConfig[style].GetAllowType(type) && g_StyleConfig[style].Selectable && (!tas || g_StyleConfig[style].AllowTAS))
			{
				g_StyleConfig[style].GetName(sStyle, sizeof(sStyle));
				
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", type, style, tas);
				
				menu.AddItem(sInfo, sStyle);
			}
		}
	}
	
	if(menu.ItemCount == 0)
	{
		delete menu;
		return;
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_WRStyleSelection(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		char sInfoExploded[3][64];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		
		int type  = StringToInt(sInfoExploded[0]);
		int style = StringToInt(sInfoExploded[1]);
		int tas   = StringToInt(sInfoExploded[2]);
		
		ShowRecordList(client, type, style, tas, g_sWRMenu_Map[client]);
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void ShowRecordList(int client, int Type, int style, int tas, const char[] sMap)
{
	char sQuery[1024];
	Transaction t = new Transaction();
	
	FormatEx(sQuery, sizeof(sQuery), "SELECT MapID FROM maps WHERE MapName='%s'", sMap);
	t.AddQuery(sQuery);
	
	
	FormatEx(sQuery, sizeof(sQuery), "SELECT Time, jumps, strafes, Sync, timestamp, p.PlayerID AS PlayerID, p.user AS Name, r.Points AS Points, r.Rank AS Rank \
		FROM (SELECT * FROM times WHERE Type=%d AND Style=%d AND tas=%d AND MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1)) AS t \
		LEFT JOIN players AS p \
		ON p.PlayerID=t.PlayerID \
		LEFT JOIN (SELECT * FROM ranks_maps WHERE Type=%d AND Style=%d AND tas=0 AND MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1)) AS r \
		ON t.PlayerID=r.PlayerID \
		ORDER BY Time ASC, Timestamp ASC",
			Type,
			style,
			tas,
			sMap,
			Type,
			style,
			sMap);
	t.AddQuery(sQuery);
		
	DataPack pack = CreateDataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(Type);
	pack.WriteCell(style);
	pack.WriteCell(tas);
	pack.WriteString(sMap);
	
	SQL_ExecuteTransaction(g_DB, t, ShowRecordList_Success, ShowRecordList_Failure, pack);
}

public void ShowRecordList_Success(Database db, DataPack pack, int numQueries, Handle[] hndl, any[] queryData)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	
	if(client == 0 || SQL_FetchRow(hndl[0]) == false)
	{
		delete pack;
		return;
	}
	
	int mapId = SQL_FetchInt(hndl[0], 0);
	int type  = pack.ReadCell();
	int style = pack.ReadCell();
	int tas   = pack.ReadCell();
	char sMap[PLATFORM_MAX_PATH];
	pack.ReadString(sMap, sizeof(sMap));
	
	if(SQL_MoreRows(hndl[1]))
	{
		Menu menu = new Menu(Menu_ShowRecordList);
	
		char sType[32], sStyle[32], sMode[32];
		GetTypeName(type, sType, sizeof(sType));
		Style(style).GetName(sStyle, sizeof(sStyle));
		if(tas == 0)
		{
			FormatEx(sMode, sizeof(sMode), "Default");
		}
		else
		{
			FormatEx(sMode, sizeof(sMode), "TAS");
		}
		
		menu.SetTitle("%s World Record List\nTimer: %s\nStyle: %s\nMode: %s\n----------------------", sMap, sType, sStyle, sMode);
		
		int position = 1;
		while(SQL_FetchRow(hndl[1]))
		{
			char  sName[MAX_NAME_LENGTH], sDisplay[64], sTime[32], sInfo[PLATFORM_MAX_PATH];
			int fieldnum;
			
			SQL_FieldNameToNum(hndl[1], "Time", fieldnum);
			float fTime = SQL_FetchFloat(hndl[1], fieldnum);
			
			SQL_FieldNameToNum(hndl[1], "PlayerID", fieldnum);
			int playerId = SQL_FetchInt(hndl[1], fieldnum);
			
			SQL_FieldNameToNum(hndl[1], "Name", fieldnum);
			SQL_FetchString(hndl[1], fieldnum, sName, sizeof(sName));
			
			FormatPlayerTime(fTime, sTime, sizeof(sTime), 1);
			FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d;%d;%d", playerId, type, style, tas, mapId);
			FormatEx(sDisplay, sizeof(sDisplay), "#%d - %s by %s", position++, sTime, sName);
			menu.AddItem(sInfo, sDisplay);
		}
		
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		PrintColorText(client, "%s%sThere aren't any times in that category.",
			g_msg_start,
			g_msg_textcol);
		ShowWorldRecordMenu(client, type, tas, sMap);
	}		
	
	delete pack;
}

public void ShowRecordList_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError(error);
}

public int Menu_ShowRecordList(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sInfoExploded[5][PLATFORM_MAX_PATH];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		
		int playerId = StringToInt(sInfoExploded[0]);
		int type     = StringToInt(sInfoExploded[1]);
		int style    = StringToInt(sInfoExploded[2]);
		int tas      = StringToInt(sInfoExploded[3]);
		int mapId    = StringToInt(sInfoExploded[4]);
		
		DB_ShowTime(client, type, style, tas, playerId, mapId);
	}
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

char g_sTimeMenuMap[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

public Action SM_Time(int client, int args)
{
	if(args == 0)
	{
		int playerId = GetPlayerID(client);
		
		if(playerId != 0)
		{
			OpenShowTimeMenu(client, playerId, g_sMapName);
		}
		else
		{
			PrintColorText(client, "%s%sYour PlayerID hasn't loaded yet, so your time can't be obtained.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else if(args == 1)
	{
		char sArg[256];
		GetCmdArgString(sArg, sizeof(sArg));
		int target = FindTarget(0, sArg, true, false);
		if(Timer_IsMapInMapCycle(sArg))
		{
			int playerId = GetPlayerID(client);
			if(playerId != 0)
			{
				OpenShowTimeMenu(client, playerId, sArg);
			}
			else
			{
				PrintColorText(client, "%s%sYour PlayerID hasn't loaded yet, so your time can't be obtained.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		else if(target != -1)
		{
			int playerId = GetPlayerID(target);
			if(playerId != 0)
			{
				OpenShowTimeMenu(client, playerId, g_sMapName);
			}
			else
			{
				PrintColorText(client, "%s%sYour target's PlayerID hasn't loaded yet, so your time can't be obtained.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sNo map or player found named %s%s",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sArg);
		}
	}
	
	return Plugin_Handled;
}

void OpenShowTimeMenu(int client, int playerId, const char[] sMap)
{
	strcopy(g_sTimeMenuMap[client], sizeof(g_sTimeMenuMap[]), sMap);
	Menu menu = new Menu(Menu_ShowTimeChooseTypeStyle);
	menu.SetTitle("Choose Time Category");
	
	char sInfo[512], sDisplay[64];
	for(int style; style < MAX_STYLES; style++)
	{
		if(Style(style).EnabledInConfig)
		{
			for(int Type; Type < MAX_TYPES; Type++)
			{	
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", Type, style, playerId);
				bool bAllowed = Style(style).GetAllowType(Type);
				switch(Type)
				{
					case TIMER_MAIN:
					{
						Style(style).GetName(sDisplay, sizeof(sDisplay));
					}
					case TIMER_BONUS:
					{
						FormatEx(sDisplay, sizeof(sDisplay), "  Bonus\n ");
					}
				}
				
				menu.AddItem(sInfo, sDisplay, bAllowed?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
			}
		}
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_ShowTimeChooseTypeStyle(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sInfoExploded[3][64];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		
		int Type     = StringToInt(sInfoExploded[0]);
		int style    = StringToInt(sInfoExploded[1]);
		int playerId = StringToInt(sInfoExploded[2]);
		
		DB_ShowTimeFromMapName(client, Type, style, 0, playerId, g_sTimeMenuMap[client]);
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

stock void DB_ShowTimeAtRank(int client, char[] mapName, int rank, int type, int style, int tas)
{		
	
}

void DB_ShowTime(int client, int type, int style, int tas, int playerId, int mapId)
{
	char sQuery[1024];
	Transaction t = new Transaction();
	FormatEx(sQuery, sizeof(sQuery), "SELECT Time, Jumps, Strafes, Timestamp, Sync FROM times WHERE \
		MapID=%d AND Type=%d AND Style=%d AND tas=%d AND PlayerID=%d",
			mapId,
			type,
			style,
			tas,
			playerId);
	t.AddQuery(sQuery);

	FormatEx(sQuery, sizeof(sQuery), "SELECT Rank, Points FROM ranks_maps WHERE \
		MapID=%d AND Type=%d AND Style=%d AND tas=%d AND PlayerID=%d",
			mapId,
			type,
			style,
			tas,
			playerId);
	t.AddQuery(sQuery);

	FormatEx(sQuery, sizeof(sQuery), "SELECT User FROM players WHERE PlayerID=%d",
		playerId);
	t.AddQuery(sQuery);
	
	FormatEx(sQuery, sizeof(sQuery), "SELECT MapName FROM maps WHERE MapID=%d", mapId);
	t.AddQuery(sQuery);
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(type);
	pack.WriteCell(style);
	pack.WriteCell(tas);
	pack.WriteCell(playerId);

	SQL_ExecuteTransaction(g_DB, t, ShowTime_Success, ShowTime_Failure, pack);
}

int  g_ShowTime_PlayerId[MAXPLAYERS + 1];
int  g_ShowTime_Type[MAXPLAYERS + 1];
int  g_ShowTime_Style[MAXPLAYERS + 1];
int  g_ShowTime_TAS[MAXPLAYERS + 1];
int  g_ShowTime_MapRank[MAXPLAYERS + 1];
char g_ShowTime_Map[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

public void ShowTime_Success(Database db, DataPack data, int numQueries, Handle[] hndl, any[] queryData)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	if(client != 0)
	{
		//0 - Time, Jumps, Strafes, Timestamp, Sync
		//1 - Rank, Points
		//2 - User
		int type     = data.ReadCell();
		int style    = data.ReadCell();
		int tas      = data.ReadCell();
		int playerId = data.ReadCell();

		char sTime[32], sTimestamp[64], sName[MAX_NAME_LENGTH], sType[32], sStyle[32], sTAS[32], sMap[PLATFORM_MAX_PATH];
		if(SQL_FetchRow(hndl[0]) && SQL_FetchRow(hndl[1]) && SQL_FetchRow(hndl[2]) && SQL_FetchRow(hndl[3]))
		{
			FormatPlayerTime(SQL_FetchFloat(hndl[0], 0), sTime, sizeof(sTime), 1);
			FormatTime(sTimestamp, sizeof(sTimestamp), "%x %X", SQL_FetchInt(hndl[0], 3));
			SQL_FetchString(hndl[2], 0, sName, MAX_NAME_LENGTH);
			Style(style).GetName(sStyle, sizeof(sStyle));
			GetTypeName(type, sType, sizeof(sType));
			if(tas) sTAS = "Yes"; else sTAS = "No";
			int   jumps   = SQL_FetchInt(hndl[0], 1);
			int   strafes = SQL_FetchInt(hndl[0], 2);
			float fSync   = SQL_FetchFloat(hndl[0], 4);
			float fPoints = SQL_FetchFloat(hndl[1], 1);
			int   mapRank = SQL_FetchInt(hndl[1], 0);
			SQL_FetchString(hndl[3], 0, sMap, PLATFORM_MAX_PATH);
			
			Panel panel = new Panel(INVALID_HANDLE);
			DrawPanelTextEx(panel, "Player: %s", sName);
			DrawPanelTextEx(panel, "Map: %s", sMap);
			DrawPanelTextEx(panel, "Type: %s", sType);
			DrawPanelTextEx(panel, "Style: %s", sStyle);
			DrawPanelTextEx(panel, "TAS: %s\n \n", sTAS);
			DrawPanelTextEx(panel, "Time: %s (%.0f pts) #%d", sTime, fPoints, mapRank);
			DrawPanelTextEx(panel, "Date: %s", sTimestamp);
			DrawPanelTextEx(panel, "Jumps: %d", jumps);
			if(Style(style).ShowStrafesOnHud)
			{
				DrawPanelTextEx(panel, "Strafes: %d", strafes);
			}
			if(Style(style).CalculateSync)
			{
				DrawPanelTextEx(panel, "Sync: %.2f%%", fSync);
			}
			DrawPanelText(panel, "\n \n");
			DrawPanelItem(panel, "Show player stats", ITEMDRAW_DEFAULT);
			
			if(Timer_ClientHasTimerFlag(client, "delete", Admin_Config))
			{
				DrawPanelItem(panel, "Delete Time", ITEMDRAW_DEFAULT);
			}
			
			panel.CurrentKey = 10;
			panel.DrawItem("Close");
			
			SendPanelToClient(panel, client, Panel_TimeInfo, 10);
			
			g_ShowTime_PlayerId[client] = playerId;
			g_ShowTime_Type[client]     = type;
			g_ShowTime_Style[client]    = style;
			g_ShowTime_TAS[client]      = tas;
			g_ShowTime_MapRank[client]  = mapRank;
			strcopy(g_ShowTime_Map[client], sizeof(g_ShowTime_Map[]), sMap);
		}
		else
		{
			PrintColorText(client, "%s%sYour selected player doesn't have a time on the map.", g_msg_start, g_msg_textcol);
		}
	}
}

public void ShowTime_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	Timer_Log(false, "ShowTime_Failure: %s", error);
}

public int Panel_TimeInfo(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(param2 == 1)
		{
			ShowPlayerStats(param1, g_ShowTime_PlayerId[param1], g_ShowTime_Type[param1], g_ShowTime_Style[param1], g_ShowTime_TAS[param1]);
		}
		else if(param2 == 2)
		{
			//void DB_DeleteTimes(int client, const char[] sMap, int type, int style, bool tas, int minPos, int maxPos)
			if(g_ShowTime_MapRank[param1] != 0)
			{
				DB_DeleteTimes(
					param1, 
					g_ShowTime_Map[param1], 
					g_ShowTime_Type[param1], 
					g_ShowTime_Style[param1], 
					view_as<bool>(g_ShowTime_TAS[param1]), 
					g_ShowTime_MapRank[param1] - 1, 
					g_ShowTime_MapRank[param1] - 1);
			}
		}
		
		
	}
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void DrawPanelTextEx(Panel panel, char[] text, any ...)
{
	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), text, 3);
	panel.DrawText(sBuffer);
}

void OpenStyleMenu(int client, int type, const char[] title)
{
	int tas = g_bTasPluginLoaded?view_as<int>(TAS_InEditMode(client)):0;
	
	Menu menu = new Menu(Menu_Style);
	
	char sStyle[32], sInfo[32];
	if(AreClientCookiesCached(client) && GetCookieBool(client, g_hPersonalizedStyleList) && g_bFavoriteStylesLoaded[client] == true && g_hFavoriteStyles[client][type][tas].Length > 0)
	{
		char sDisplay[64];
		menu.SetTitle("%s (Personalized)", title);
		
		bool[] styleUsed = new bool[g_TotalStyles];
		
		for(int idx; idx < g_hFavoriteStyles[client][type][tas].Length; idx++)
		{
			int data[2];
			g_hFavoriteStyles[client][type][tas].GetArray(idx, data, sizeof(data));
			
			int count = data[0];
			int style = data[1];
			
			if(g_StyleConfig[style].Enabled && g_StyleConfig[style].GetAllowType(type) && g_StyleConfig[style].Selectable)
			{
				g_StyleConfig[style].GetName(sStyle, sizeof(sStyle));
				FormatEx(sDisplay, sizeof(sDisplay), "%s (%d %s)", sStyle, count, (count == 1)?"time":"times");
				FormatEx(sInfo, sizeof(sInfo), "%d;%d", type, style);
				menu.AddItem(sInfo, sDisplay);
				styleUsed[style] = true;
			}
		}
		
		for(int style; style < g_TotalStyles; style++)
		{
			if(g_StyleConfig[style].Enabled && g_StyleConfig[style].GetAllowType(type) && g_StyleConfig[style].Selectable && styleUsed[style] == false)
			{
				g_StyleConfig[style].GetName(sStyle, sizeof(sStyle));
				FormatEx(sDisplay, sizeof(sDisplay), "%s (0 times)", sStyle);
				FormatEx(sInfo, sizeof(sInfo), "%d;%d", type, style);
				menu.AddItem(sInfo, sStyle);
			}
		}
	}
	else
	{
		menu.SetTitle(title);
		for(int style; style < g_TotalStyles; style++)
		{
			if(g_StyleConfig[style].Enabled && g_StyleConfig[style].GetAllowType(type) && g_StyleConfig[style].Selectable)
			{
				g_StyleConfig[style].GetName(sStyle, sizeof(sStyle));
				
				FormatEx(sInfo, sizeof(sInfo), "%d;%d", type, style);
				
				menu.AddItem(sInfo, sStyle);
			}
		}
	}
	
	if(menu.ItemCount == 0)
	{
		delete menu;
		return;
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public Action SM_Style(int client, int args)
{
	OpenStyleMenu(client, TIMER_MAIN, "Change Style");
	
	return Plugin_Handled;
}

public Action SM_BStyle(int client, int args)
{
	OpenStyleMenu(client, TIMER_BONUS, "Change Bonus Style");
	
	return Plugin_Handled;
}

public int Menu_Style(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrContains(info, ";") != -1)
		{
			char sInfoExplode[2][16];
			ExplodeString(info, ";", sInfoExplode, sizeof(sInfoExplode), sizeof(sInfoExplode[]));
			
			SetStyle(client, StringToInt(sInfoExplode[0]), StringToInt(sInfoExplode[1]));
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void SetStyle(int client, int type, int style)
{	
	StopTimer(client);
	
	if(g_bZonePluginLoaded)
	{
		if(type == TIMER_MAIN)
		{
			Timer_TeleportToZone(client, MAIN_START, 0, true);
		}
		else if(type == TIMER_BONUS)
		{
			Timer_TeleportToZone(client, BONUS_START, 0, true);
		}
	}
	
	g_TimerInfo[client].SetStyle(type, style);
}

public Action SM_Practice(int client, int args)
{
	if(GetConVarBool(g_hAllowNoClip))
	{
		if(args == 0)
		{
			if(IsBeingTimed(client, TIMER_ANY) && (TimerInfo(client).CurrentTime / 60.0) > g_hPracticeTime.IntValue)
			{
				NoclipRequestMenu(client);
				return Plugin_Handled;
			}
			else
			{
				StopTimer(client);
			
				if(GetEntityMoveType(client) != MOVETYPE_NOCLIP)
				{
					SetEntityMoveType(client, MOVETYPE_NOCLIP);
					SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fNoClipSpeed[client]);
				}
				else
				{
					SetEntityMoveType(client, MOVETYPE_WALK);
					SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
					if(Style(TimerInfo(client).ActiveStyle).AntiNoClip == true)
					{
						g_bUnNoClipped[client] = true;
					}
				}
			}
		}
		else
		{
			char sArg[256];
			GetCmdArgString(sArg, sizeof(sArg));
			
			float fSpeed = StringToFloat(sArg);
			
			if(!(0 <= fSpeed <= 10))
			{
				PrintColorText(client, "%s%sYour noclip speed must be between 0 and 10",
					g_msg_start,
					g_msg_textcol);
					
				return Plugin_Handled;
			}
			
			g_fNoClipSpeed[client] = fSpeed;
		
			PrintColorText(client, "%s%sNoclip speed changed to %s%f%s%s",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				fSpeed,
				g_msg_textcol,
				(fSpeed != 1.0)?" (Default is 1)":" (Default)");
				
			if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
			{
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fSpeed);
			}
		}
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

void NoclipRequestMenu(int client)
{
	Menu menu = new Menu(Menu_NoclipRequest);
	menu.SetTitle("Are you sure you want to noclip?\n ");
	menu.AddItem("yes", "Yes");
	menu.AddItem("no",  "No");
	menu.Display(client, 3);
}

public int Menu_NoclipRequest(Menu menu, MenuAction action, int client, int param2)
{
	if(action & MenuAction_Select)
	{
		char sInfo[4];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "yes"))
		{
			StopTimer(client);
			
			if(GetEntityMoveType(client) != MOVETYPE_NOCLIP)
			{
				SetEntityMoveType(client, MOVETYPE_NOCLIP);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fNoClipSpeed[client]);
			}
			else
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
				if(Style(TimerInfo(client).ActiveStyle).AntiNoClip == true)
				{
					g_bUnNoClipped[client] = true;
				}
			}
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

public Action SM_Pause(int client, int args)
{
	if(g_TimerInfo[client].Paused)
	{
		UnpauseTimer(client);
	}
	else
	{
		PauseTimer(client);
	}
	
	return Plugin_Handled;
}

public Action SM_Unpause(int client, int args)
{
	UnpauseTimer(client);
	
	return Plugin_Handled;
}

void PauseTimer(int client)
{
	if(GetConVarBool(g_hAllowPause))
	{
		if(!g_bZonePluginLoaded || (Timer_InsideZone(client, MAIN_START) == -1 && Timer_InsideZone(client, BONUS_START) == -1))
		{
			if(g_TimerInfo[client].IsTiming == true)
			{
				if(g_TimerInfo[client].Paused == false)
				{
					if(GetEntityFlags(client) & FL_ONGROUND)
					{
						GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_fPausePos[client]);
						g_fPauseTime[client]	= GetEngineTime();
						g_TimerInfo[client].Paused = true;
						SetEntityMoveType(client, MOVETYPE_NONE);
						SetEntityFlags(client, GetEntityFlags(client) | FL_FROZEN);
					}
					else
					{
						PrintColorText(client, "%s%sYou can't pause while in the air.",
							g_msg_start,
							g_msg_textcol);
					}
				}
				else
				{
					PrintColorText(client, "%s%sYou are already paused.",
						g_msg_start,
						g_msg_textcol);
				}
			}
			else
			{
				PrintColorText(client, "%s%sYou have no timer running.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sYou can't pause while inside a starting zone.",
				g_msg_start,
				g_msg_textcol);
		}
	}
}

void UnpauseTimer(int client)
{
	if(g_TimerInfo[client].IsTiming == true)
	{
		if(g_TimerInfo[client].Paused == true)
		{
			// Teleport player to the position they paused at
			TeleportEntity(client, g_fPausePos[client], NULL_VECTOR, view_as<float>({0, 0, 0}));
			
			// Unpause
			g_TimerInfo[client].Paused = false;
			
			SetEntityMoveType(client, MOVETYPE_WALK);
			SetEntityFlags(client, GetEntityFlags(client) & ~FL_FROZEN);
		}
		else
		{
			PrintColorText(client, "%s%sYou are not currently paused.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		PrintColorText(client, "%s%sYou have no timer running.",
			g_msg_start,
			g_msg_textcol);
	}
}

public Action SM_Fps(int client, int args)
{
	Menu menu = new Menu(Menu_Fps);
	menu.SetTitle("List of player fps_max values");
	
	char sFps[64];
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsClientInGame(target) && !IsFakeClient(target))
		{
			FormatEx(sFps, sizeof(sFps), "%N - %.3f", target, g_Fps[target]);
			menu.AddItem("", sFps);
		}
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int Menu_Fps(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action SM_EnableStyle(int client, int args)
{
	AdminFlag flag = Admin_Config;
	Timer_GetAdminFlag("styles", flag);
	
	if(!GetAdminFlag(GetUserAdmin(client), flag))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		char sArg[32];
		GetCmdArg(1, sArg, sizeof(sArg));
		
		int  style = StringToInt(sArg);
		if(0 <= style < g_TotalStyles)
		{
			g_StyleConfig[style].Enabled = true;
			ReplyToCommand(client, "[Timer] - Style '%d' has been enabled.", style);
		}
		else
		{
			ReplyToCommand(client, "[Timer] - Style '%d' is not a valid style number. It will not be enabled.", style);
		}
	}
	else
	{
		ReplyToCommand(client, "[Timer] - Example: \"sm_enablestyle 1\" will enable the style with number value of 1 in the styles.cfg");
	}
	
	return Plugin_Handled;
}

public Action SM_DisableStyle(int client, int args)
{
	AdminFlag flag = Admin_Config;
	Timer_GetAdminFlag("styles", flag);
	
	if(!GetAdminFlag(GetUserAdmin(client), flag))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		char sArg[32];
		GetCmdArg(1, sArg, sizeof(sArg));
		
		int style = StringToInt(sArg);
		if(0 <= style < g_TotalStyles)
		{
			g_StyleConfig[style].Enabled = false;
			ReplyToCommand(client, "[Timer] - Style '%d' has been disabled.", style);
		}
		else
		{
			ReplyToCommand(client, "[Timer] - Style '%d' is not a valid style number. It will not be disabled.", style);
		}
	}
	else
	{
		ReplyToCommand(client, "[Timer] - Example: 'sm_disablestyle 1' will disable the style with number value of 1 in the styles.cfg");
	}
	
	return Plugin_Handled;
}

public Action SM_ReloadStyles(int client, int args)
{
	AdminFlag flag = Admin_Config;
	Timer_GetAdminFlag("styles", flag);
	
	if(!GetAdminFlag(GetUserAdmin(client), flag))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if(ReadStyleConfig())
	{
		ReplyToCommand(client, "[Timer] - Style config reloaded.");
	}
	else
	{
		ReplyToCommand(client, "[Timer] - Failed to reload style config.");
	}
	
	return Plugin_Handled;
}

int  g_RR_Type[MAXPLAYERS + 1];
int  g_RR_Style[MAXPLAYERS +1 ];
int  g_RR_TAS[MAXPLAYERS + 1];
bool g_RR_AllConfigs[MAXPLAYERS + 1];
char g_RR_NameSearch[MAXPLAYERS + 1][MAX_NAME_LENGTH];
int  g_RR_PlayerID[MAXPLAYERS + 1];
bool g_RR_AllPlayers[MAXPLAYERS + 1];
bool g_RR_AllMaps[MAXPLAYERS + 1];
char g_RR_Map[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
bool g_RR_Active[MAXPLAYERS + 1];

public Action SM_RecentRecords(int client, int args)
{
	g_RR_Type[client]       = 0;
	g_RR_Style[client]      = 0;
	g_RR_TAS[client]        = 0;
	g_RR_AllConfigs[client] = false;
	g_RR_PlayerID[client]   = 0;
	g_RR_AllPlayers[client] = false;
	g_RR_AllMaps[client]    = false;
	GetCmdArgString(g_RR_NameSearch[client], sizeof(g_RR_NameSearch[]));
	
	CreateTimerSelection(client, "Select Recent Records Timer Configuration", 0, 0, 0, true, RecentRecords_SelectTimerCallback, 0);
	
	return Plugin_Handled;
}

public void RecentRecords_SelectTimerCallback(int client, int type, int style, bool tas, bool all, any data)
{
	g_RR_Type[client]       = type;
	g_RR_Style[client]      = style;
	g_RR_TAS[client]        = tas;
	g_RR_AllConfigs[client] = all;
	
	DB_CreatePlayerListFromName(client, "Select Player", g_DB, true, g_RR_NameSearch[client], RecentRecords_SelectPlayerCallback);
}

public void RecentRecords_SelectPlayerCallback(int client, int playerId)
{
	if(playerId == 0)
	{
		g_RR_AllPlayers[client] = true;
	}
	else
	{
		g_RR_PlayerID[client] = playerId;
	}
	
	RR_StartMapSelection(client);
}

void RR_StartMapSelection(int client)
{
	Menu menu = new Menu(Menu_MapSelection);
	menu.SetTitle("Select Map");
	menu.AddItem("all;", "All Maps");
	
	char sCurrent[PLATFORM_MAX_PATH];
	FormatEx(sCurrent, sizeof(sCurrent), "%s (Current map)", g_sMapName);
	menu.AddItem(g_sMapName, sCurrent);
	
	Handle hMapList = Timer_GetMapCycle();
	int iSize = GetArraySize(hMapList);
	char sMap[PLATFORM_MAX_PATH];
	for(int idx; idx < iSize; idx++)
	{
		GetArrayString(hMapList, idx, sMap, sizeof(sMap));
		menu.AddItem(sMap, sMap);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_MapSelection(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[PLATFORM_MAX_PATH];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "all;"))
		{
			g_RR_AllMaps[param1] = true;
		}
		else
		{
			FormatEx(g_RR_Map[param1], sizeof(g_RR_Map[]), sInfo);
		}
		
		RR_StartActiveRecordSelection(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void RR_StartActiveRecordSelection(int client)
{
	Menu menu = new Menu(Menu_ActiveSelection);
	menu.SetTitle("Show Only Active Records?");
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_ActiveSelection(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[PLATFORM_MAX_PATH];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "yes"))
		{
			g_RR_Active[param1] = true;
		}
		else
		{
			g_RR_Active[param1] = false;
		}
		
		ShowRecentRecords(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void ShowRecentRecords(int client)
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT m.MapName, p.User, rr.Time, rr.StillExists, rr.IsRecord, rr.Type, rr.Style, rr.TAS, rr.PlayerID, m.MapID FROM recent_records AS rr, maps AS m, players AS p WHERE rr.MapID = m.MapID AND rr.PlayerID = p.PlayerID ");
	if(!g_RR_AllConfigs[client])
	{
		Format(sQuery, sizeof(sQuery), "%sAND rr.Type = %d AND rr.Style = %d AND rr.TAS = %d ", sQuery, g_RR_Type[client], g_RR_Style[client], g_RR_TAS[client]);
	}
	
	if(!g_RR_AllPlayers[client])
	{
		Format(sQuery, sizeof(sQuery), "%sAND rr.PlayerID = %d ", sQuery, g_RR_PlayerID[client]);
	}
	
	if(!g_RR_AllMaps[client])
	{
		Format(sQuery, sizeof(sQuery), "%sAND rr.MapID = (SELECT MapID FROM maps WHERE MapName = '%s') ", sQuery, g_RR_Map[client]);
	}
	
	if(g_RR_Active[client])
	{
		Format(sQuery, sizeof(sQuery), "%sAND rr.IsRecord = 1 ", sQuery);
	}
	
	Format(sQuery, sizeof(sQuery), "%sORDER BY rr.Timestamp DESC", sQuery);
	
	SQL_TQuery(g_DB, RecentRecords_QueryCallback, sQuery, GetClientUserId(client));
}


// 0 = MapName
// 1 = User
// 2 = Time
// 3 = StillExists
// 4 = IsRecord
// 5 = PlayerID
// 6 = Type
// 7 = Style
// 8 = TAS
// 9 = MapID
		
public void RecentRecords_QueryCallback(Handle owner, Handle hndl, const char[] error, int userid)
{
	if(hndl != INVALID_HANDLE)
	{		
		int client = GetClientOfUserId(userid);
		if(client != 0)
		{
			Menu menu = new Menu(Menu_RecentRecords);
			menu.SetTitle("Recent Records");
			
			char sMap[PLATFORM_MAX_PATH], sUser[MAX_NAME_LENGTH], sTime[32], sDisplay[512], sInfo[PLATFORM_MAX_PATH];
			float fTime;
			bool IsRecord;
			int playerId, type, style, tas, mapId;
			
			while(SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, sMap, PLATFORM_MAX_PATH);
				SQL_FetchString(hndl, 1, sUser, MAX_NAME_LENGTH);
				fTime = SQL_FetchFloat(hndl, 2);
				IsRecord = view_as<bool>(SQL_FetchInt(hndl, 4));
				type     = SQL_FetchInt(hndl, 5);
				style    = SQL_FetchInt(hndl, 6);
				tas      = SQL_FetchInt(hndl, 7);
				playerId = SQL_FetchInt(hndl, 8);
				mapId    = SQL_FetchInt(hndl, 9);
				
				FormatPlayerTime(fTime, sTime, sizeof(sTime), 1);
				FormatEx(sDisplay, sizeof(sDisplay), "%s - (%s on %s) %s", sUser, sTime, sMap, IsRecord?"★":"");
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d;%d;%d", mapId, playerId, type, style, tas);
				menu.AddItem(sInfo, sDisplay);
			}
			
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
	else
	{
		Timer_Log(false, "RecentRecords_QueryCallback %s", error);
	}
}

public Action SM_Overtake(int client, int args)
{
	if(args == 0)
	{
		ShowOvertake(client, client, true);
	}
	else
	{
		char sArgString[MAX_NAME_LENGTH];
		GetCmdArgString(sArgString, sizeof(sArgString));
		
		int target = FindTarget(client, sArgString, false, false);
		if(target != -1)
		{
			ShowOvertake(client, target, true);
		}
	}
	
	return Plugin_Handled;
}

public int Menu_RecentRecords(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sInfoExploded[5][PLATFORM_MAX_PATH];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		
		int mapId    = StringToInt(sInfoExploded[0]);
		int playerId = StringToInt(sInfoExploded[1]);
		int type     = StringToInt(sInfoExploded[2]);
		int style    = StringToInt(sInfoExploded[3]);
		int tas      = StringToInt(sInfoExploded[4]);
		DB_ShowTime(param1, type, style, tas, playerId, mapId);
		
	}
	if(action == MenuAction_End)
	{
		delete menu;
	}
}

stock void GetPlayerPosition(float fTime, int Type, int style)
{	
	if(g_bTimesAreLoaded == true)
	{
		int iSize = GetArraySize(g_hTimes[Type][style]);
		
		for(int idx; idx < iSize; idx++)
		{
			if(fTime <= GetArrayCell(g_hTimes[Type][style], idx, 1))
			{
				return idx + 1;
			}
		}
		
		return iSize + 1;
	}
	
	return 0;
}

int GetPlayerPositionByID(int PlayerID, int Type, int style, int tas)
{
	if(g_bTimesAreLoaded == true)
	{
		int iSize = GetArraySize(g_hTimes[Type][style][tas]);
		
		for(int idx; idx < iSize; idx++)
		{
			if(PlayerID == GetArrayCell(g_hTimes[Type][style][tas], idx, 0))
			{
				return idx + 1;
			}
		}
		
		return iSize + 1;
	}
	
	return 0;
}

public Action OnTimerStart_Pre(int client, int Type, int style, int Method)
{
	g_AllowedYawspeed[client] = 0;
	
	if(!IsClientInGame(client))
	{
		return Plugin_Handled;
	}
		
	if(!IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}
	
	// Don't start if they are a fake client
	if(IsFakeClient(client))
	{
		return Plugin_Handled;
	}
	
	// Fixes a bug for players to completely cheat times by spawning in weird parts of the map
	if((g_Engine == Engine_CSS) && (GetEngineTime() < (g_fSpawnTime[client] + 0.1)) && Method != StartMethod_SaveLocation)
	{
		return Plugin_Handled;
	}
	
	// Don't start if their speed isn't default
	if(GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != 1.0)
	{
		if(g_bTasPluginLoaded)
		{
			if(!TAS_InEditMode(client))
			{
				WarnClient(client, "%s%sYour movement speed is off. Type %s!normalspeed%s to set it to default.", 30.0,
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					g_msg_textcol);
				return Plugin_Handled;
			}
		}
		else
		{
			WarnClient(client, "%s%sYour movement speed is off. Type %s!normalspeed%s to set it to default.", 30.0,
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
			return Plugin_Handled;
		}
	}
	
	// Don't start if they are in noclip
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		return Plugin_Handled;
	}
	
	if(!g_StyleConfig[style].GetAllowType(Type) || !g_StyleConfig[style].Enabled)
	{
		return Plugin_Handled;
	}
	
	if(g_StyleConfig[style].MinimumFPS != 0 && g_Fps[client] < g_StyleConfig[style].MinimumFPS && g_Fps[client] != 0.0)
	{
		WarnClient(client, "%s%sPlease set your fps_max to a higher value (Minimum %s%.1f%s).", 30.0, 
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_StyleConfig[style].MinimumFPS,
			g_msg_textcol);
			
		return Plugin_Handled;
	}
	
	if(GetCookieBool(client, g_hAutohopCookie) && g_bAutoStopsTimer)
	{
		return Plugin_Handled;
	}
	
	if(Method == StartMethod_Zones || Method == StartMethod_Buttons)
	{
		CheckPrespeed(client, style);
		
		if(Style(style).GroundStartOnly)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				return Plugin_Handled;
			}
		}
	}
	
	if(Style(TimerInfo(client).ActiveStyle).AntiNoClip == true)
	{
		if(g_bUnNoClipped[client] == true)
		{
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
			g_bUnNoClipped[client] = false;
		}
	}
	
	return Plugin_Continue;
}

public void OnTimerStart_Post(int client, int Type, int style, int Method)
{
	// For an always convenient starting jump
	SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	
	if(g_StyleConfig[style].RunSpeed != 0.0)
	{
		SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", g_StyleConfig[style].RunSpeed);
	}
	
	// Set to correct gravity
	if(GetEntityGravity(client) != 0.0)
	{
		SetEntityGravity(client, 0.0);
	}
	
	if(Style(style).Start != -1)
	{
		g_TimerInfo[client].SetStyle(g_TimerInfo[client].Type, Style(style).Start);
	}
	
	if(g_StyleConfig[style].HasSpecialKey("aord"))
	{
		g_AorD_HasPickedKey[client] = false;
	}
}

public int Native_StartTimer(Handle plugin, int numParams)
{
	int client       = GetNativeCell(1);
	int type         = GetNativeCell(2);
	int style        = g_TimerInfo[client].GetStyle(type);
	float fStartTime = view_as<float>(GetNativeCell(3));
	int method       = GetNativeCell(4);
	
	Call_StartForward(g_fwdOnTimerStart_Pre);
	Call_PushCell(client);
	Call_PushCell(type);
	Call_PushCell(style);
	Call_PushCell(method);
	
	Action fResult;
	Call_Finish(fResult);
	
	if(fResult != Plugin_Handled)
	{
		if(g_TimerInfo[client].Paused)
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
			g_TimerInfo[client].Paused = false;
		}
		
		g_TimerInfo[client].IsTiming        = true;
		g_TimerInfo[client].CurrentTime     = fStartTime;
		g_TimerInfo[client].SetStyle(type, style);
		g_TimerInfo[client].Type            = type;
		g_TimerInfo[client].Jumps           = 0;
		g_TimerInfo[client].Strafes         = 0;
		g_TimerInfo[client].TotalSync       = 0;
		g_TimerInfo[client].GoodSync        = 0;
		g_TimerInfo[client].CheckpointsUsed = 0;
		
		Call_StartForward(g_fwdOnTimerStart_Post);
		Call_PushCell(client);
		Call_PushCell(type);
		Call_PushCell(style);
		Call_PushCell(method);
		Call_Finish();
		
		return true;
	}
	
	return false;
}

bool CheckPrespeed(int client, int style)
{	
	if(g_StyleConfig[style].MaxPrespeed != 0.0)
	{
		float fVel = GetClientVelocity(client, true, true, true);
		
		if(fVel > g_StyleConfig[style].MaxPrespeed)
		{
			float vVel[3];
			Entity_GetAbsVelocity(client, vVel);
			ScaleVector(vVel, g_StyleConfig[style].SlowedSpeed/fVel);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			
			return true;
		}
	}
	
	return false;
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

public int Native_StopTimer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	// stop timer
	if(0 < client <= MaxClients)
	{
		if(g_TimerInfo[client].Paused == true)
		{
			UnpauseTimer(client);
		}
		
		g_TimerInfo[client].IsTiming = false;
		
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			if(GetEntityMoveType(client) == MOVETYPE_NONE)
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
			}
		}
		
		Call_StartForward(g_fwdOnTimerStopped);
		Call_PushCell(client);
		Call_Finish();
	}
}

public int Native_IsBeingTimed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int Type   = GetNativeCell(2);
	
	if(g_TimerInfo[client].IsTiming == true)
	{
		if(Type == TIMER_ANY)
		{
			return true;
		}
		else
		{
			return g_TimerInfo[client].Type == Type;
		}
	}
	
	return false;
}

public Action OnTimerFinished_Pre(int client, int Type, int style)
{
	if(!IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(IsFakeClient(client))
	{
		return Plugin_Handled;
	}
	
	if(g_bTimeIsLoaded[client] == false)
	{
		return Plugin_Handled;
	}
	
	if(GetPlayerID(client) == 0)
	{
		return Plugin_Handled;
	}
	
	if(g_TimerInfo[client].Paused == true)
	{
		return Plugin_Handled;
	}
	
	// Anti-cheat sideways
	if(g_StyleConfig[style].IsSpecial == true)
	{
		if(g_StyleConfig[style].HasSpecialKey("sw"))
		{
			float WSRatio = view_as<float>(g_SWStrafes[client][0])/float(g_SWStrafes[client][1]);
			if((WSRatio > 2.0) || (g_TimerInfo[client].Strafes < 10))
			{
				PrintColorText(client, "%s%sThat time did not count because you used W-Only too much",
					g_msg_start,
					g_msg_textcol);
				StopTimer(client);
				return Plugin_Handled;
			}
		}
	}
	
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void OnTimerFinished_Post(int client, float Time, int Type, int style, bool tas, bool NewTime, int OldPosition, int NewPosition)
{
	char sType[128];
	GetTypeName(Type, sType, sizeof(sType));
	
	char sStyle[128];
	Style(style).GetName(sStyle, sizeof(sStyle));
	
	char sTas[128] = "";
	if(tas == true)
	{
		FormatEx(sTas, sizeof(sTas), " %s(%sTAS%s)", g_msg_textcol, g_msg_varcol, g_msg_textcol);
	}
	
	char sTime[128];
	FormatPlayerTime(Time, sTime, sizeof(sTime), 1);
	if(NewTime == true)
	{
		//NEW Bonus Record by Blacky on Normal (TAS) in 13.37
		if(NewPosition == 1)
		{
			PrintColorTextAll("%s%sNEW %s%s%s Record by %s%N%s on %s%s%s%s in %s%s%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sType,
				g_msg_textcol,
				g_msg_varcol,
				client,
				g_msg_textcol,
				g_msg_varcol,
				sStyle,
				sTas,
				g_msg_textcol,
				g_msg_varcol,
				sTime,
				g_msg_textcol);
		}
		else
		{
			PrintColorTextAll("%s%s%N%s finished in %s%s%s (%s%d%s/%s%d%s) on the %s%s%s timer using %s%s%s style%s.",
				g_msg_start,
				g_msg_varcol,
				client,
				g_msg_textcol,
				g_msg_varcol,
				sTime,
				g_msg_textcol,
				g_msg_varcol,
				NewPosition,
				g_msg_textcol,
				g_msg_varcol,
				GetArraySize(g_hTimes[Type][style][tas]),
				g_msg_textcol,
				g_msg_varcol,
				sType,
				g_msg_textcol,
				g_msg_varcol,
				sStyle,
				g_msg_textcol,
				sTas);
		}

		UpdatePlayerPositions(Type, style, tas);
	}
	else
	{
		PrintColorText(client, "%s%sYou finished in %s%s%s (No improvement)",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			sTime,
			g_msg_textcol);
	}
	
	PlayFinishSound(client, NewTime, NewPosition, Type, style, tas);
}

void UpdatePlayerPositions(int Type, int style, int tas)
{
	int playerId;
	for(int client = 1; client <= MaxClients; client++)
	{
		playerId = GetPlayerID(client);
		if(playerId != 0 && g_bPlayerHasTime[client][Type][style][tas] == true)
		{
			g_iPosition[client][Type][style][tas] = GetPlayerPositionByID(playerId, Type, style, tas) - 1;
		}
		else
		{
			g_iPosition[client][Type][style][tas] = 0;
		}
	}
	
}

public int Native_FinishTimer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int Type   = g_TimerInfo[client].Type;
	int style  = g_TimerInfo[client].GetStyle(g_TimerInfo[client].Type);
	int tas    = g_bTasPluginLoaded?view_as<int>(TAS_InEditMode(client)):0;
	
	Call_StartForward(g_fwdOnTimerFinished_Pre);
	Call_PushCell(client);
	Call_PushCell(Type);
	Call_PushCell(style);
	
	Action fResult;
	Call_Finish(fResult);
	
	if(fResult != Plugin_Handled)
	{
		float fTime = g_TimerInfo[client].CurrentTime;
		
		int oldPosition, newPosition;
		bool newTime = false;
		
		if(fTime < g_fTime[client][Type][style][tas] || !g_bPlayerHasTime[client][Type][style][tas])
		{
			newTime = true;
			
			if(!g_bPlayerHasTime[client][Type][style][tas])
			{
				oldPosition = 0;
			}
			else
			{
				oldPosition = GetPlayerPositionByID(GetPlayerID(client), Type, style, tas);
			}
			
			newPosition = DB_UpdateTime(client, Type, style, fTime, g_TimerInfo[client].Jumps, g_TimerInfo[client].Strafes, g_TimerInfo[client].Sync, tas);
			
			g_fTime[client][Type][style][tas]          = fTime;
			g_bPlayerHasTime[client][Type][style][tas] = true;
		}
		
		Call_StartForward(g_fwdOnTimerFinished_Post);
		Call_PushCell(client);
		Call_PushFloat(fTime);
		Call_PushCell(Type);
		Call_PushCell(style);
		Call_PushCell(tas);
		Call_PushCell(newTime);
		Call_PushCell(oldPosition);
		Call_PushCell(newPosition);
		Call_Finish();
		
		// This NEEDS to be called AFTER finish timer for the replaybot v3 plugin
		StopTimer(client);
	}
}

// Adds or updates a player's record on the map
int DB_UpdateTime(int client, int Type, int style, float Time, int Jumps, int Strafes, float Sync, int tas)
{
	int PlayerID = GetPlayerID(client);
	
	/* Get player position */
	int iSize = GetArraySize(g_hTimes[Type][style][tas]), Position = -1;
	
	for(int idx; idx < iSize; idx++)
	{
		if(GetArrayCell(g_hTimes[Type][style][tas], idx) == PlayerID)
		{
			Position = idx;
			break;
		}
	}
	
	if(Position != -1)
	{
		RemoveFromArray(g_hTimes[Type][style][tas], Position);
		RemoveFromArray(g_hTimesUsers[Type][style][tas], Position);
	}
	
	iSize = GetArraySize(g_hTimes[Type][style][tas]);
	Position = -1;
	
	for(int idx; idx < iSize; idx++)
	{
		if(Time < GetArrayCell(g_hTimes[Type][style][tas], idx, 1))
		{
			Position = idx;
			break;
		}
	}
	
	if(Position == -1)
	{
		Position = iSize;
	}
	
	if(Position >= iSize)
	{
		ResizeArray(g_hTimes[Type][style][tas], Position + 1);
		ResizeArray(g_hTimesUsers[Type][style][tas], Position + 1);
	}
	else
	{
		ShiftArrayUp(g_hTimes[Type][style][tas], Position);
		ShiftArrayUp(g_hTimesUsers[Type][style][tas], Position);
	}
	
	SetArrayCell(g_hTimes[Type][style][tas], Position, PlayerID, 0);
	SetArrayCell(g_hTimes[Type][style][tas], Position, Time, 1);
	
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	SetArrayString(g_hTimesUsers[Type][style][tas], Position, sName);
	
	Transaction hTransaction = SQL_CreateTransaction();
	
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "CALL AddPlayerTime('%s', %d, %d, %d, %f, %d, %d, %d, %f, %d, %d)",
		g_sMapName,
		Type,
		style,
		PlayerID,
		Time,
		Jumps,
		Strafes,
		GetTime(),
		Sync,
		tas,
		Position == 0);
	hTransaction.AddQuery(sQuery);
	
	DataPack pack = CreateDataPack();
	pack.WriteString(g_sMapName);
	pack.WriteCell(Type);
	pack.WriteCell(style);
	pack.WriteCell(tas);
	
	SQL_ExecuteTransaction(g_DB, hTransaction, UpdateTimes_Success, UpdateTimes_Failure, pack);
	
	return Position + 1;
}

public void UpdateTimes_Success(Database db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	// Read and delete datapack
	data.Reset();
	char sMapName[64];
	ReadPackString(data, sMapName, sizeof(sMapName));
	int Type  = data.ReadCell();
	int style = data.ReadCell();
	int tas   = data.ReadCell();
	delete data;
	
	// Start forward to let other plugins know that times were updated
	Call_StartForward(g_fwdOnTimesUpdated);
	Call_PushString(sMapName);
	Call_PushCell(Type);
	Call_PushCell(style);
	Call_PushCell(tas);
	Call_PushCell(g_hTimes[Type][style][tas]);
	Call_Finish();
}

public void UpdateTimes_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] querydata)
{
	Timer_Log(false, "UpdateTimes_Failure: %s", error);
}

bool ReadStyleConfig()
{
	KeyValues kv = new KeyValues("Styles");
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/styles.cfg");
	kv.ImportFromFile(sPath);
	
	for(int style; style < MAX_STYLES; style++)
	{
		g_StyleConfig[style] = Style(style);
	}
	
	if(kv != INVALID_HANDLE)
	{
		int key;
		bool keyExists = true;
		char sKey[32], sBuffer[64];
		
		do
		{
			IntToString(key, sKey, sizeof(sKey));
			keyExists = kv.JumpToKey(sKey);
			
			if(keyExists == true)
			{
				kv.GetString("name", sBuffer, sizeof(sBuffer));
				g_StyleConfig[key].SetName(sBuffer);
				
				kv.GetString("abbr", sBuffer, sizeof(sBuffer));
				g_StyleConfig[key].SetNameShort(sBuffer);
				g_StyleConfig[key].EnabledInConfig         = view_as<bool>(kv.GetNum("enable", 0));
				g_StyleConfig[key].SetAllowType(TIMER_MAIN,  view_as<bool>(kv.GetNum("main", 0)));
				g_StyleConfig[key].SetAllowType(TIMER_BONUS, view_as<bool>(kv.GetNum("bonus", 0)));
				g_StyleConfig[key].Freestyle               = view_as<bool>(kv.GetNum("freestyle", 0));
				g_StyleConfig[key].FreestyleUnrestrict     = view_as<bool>(kv.GetNum("freestyle_unrestrict", 0));
				g_StyleConfig[key].FreestyleEzHop          = view_as<bool>(kv.GetNum("freestyle_ezhop", 0));
				g_StyleConfig[key].FreestyleAuto           = view_as<bool>(kv.GetNum("freestyle_auto", 0));
				g_StyleConfig[key].FreestyleNoLimit        = view_as<bool>(kv.GetNum("freestyle_nolimit", 0));
				g_StyleConfig[key].Auto                    = view_as<bool>(kv.GetNum("auto", 0));
				g_StyleConfig[key].EzHop                   = view_as<bool>(kv.GetNum("ezhop", 0));
				g_StyleConfig[key].Gravity                 = kv.GetNum("gravity", 800);
				g_StyleConfig[key].RunSpeed                = kv.GetFloat("runspeed", 0.0);
				g_StyleConfig[key].MaxVelocity             = kv.GetFloat("maxvel", 0.0);
				g_StyleConfig[key].MinimumFPS              = kv.GetFloat("minfps", 0.0);
				g_StyleConfig[key].CalculateSync           = view_as<bool>(kv.GetNum("sync", 0));
				g_StyleConfig[key].PreventLeft             = view_as<bool>(kv.GetNum("prevent_left", 0));
				g_StyleConfig[key].PreventRight            = view_as<bool>(kv.GetNum("prevent_right", 0));
				g_StyleConfig[key].PreventBack             = view_as<bool>(kv.GetNum("prevent_back", 0));
				g_StyleConfig[key].PreventForward          = view_as<bool>(kv.GetNum("prevent_forward", 0));
				g_StyleConfig[key].RequireLeft             = view_as<bool>(kv.GetNum("require_left", 0));
				g_StyleConfig[key].RequireRight            = view_as<bool>(kv.GetNum("require_right", 0));
				g_StyleConfig[key].RequireBack             = view_as<bool>(kv.GetNum("require_back", 0));
				g_StyleConfig[key].RequireForward          = view_as<bool>(kv.GetNum("require_forward", 0));
				g_StyleConfig[key].ShowNameOnHud           = view_as<bool>(kv.GetNum("hud_style", 0));
				g_StyleConfig[key].ShowStrafesOnHud        = view_as<bool>(kv.GetNum("hud_strafes", 0));
				g_StyleConfig[key].ShowJumpsOnHud          = view_as<bool>(kv.GetNum("hud_jumps", 0));
				g_StyleConfig[key].CountLeftStrafe         = view_as<bool>(kv.GetNum("count_left_strafe", 0));
				g_StyleConfig[key].CountRightStrafe        = view_as<bool>(kv.GetNum("count_right_strafe", 0));
				g_StyleConfig[key].CountBackStrafe         = view_as<bool>(kv.GetNum("count_back_strafe", 0));
				g_StyleConfig[key].CountForwardStrafe      = view_as<bool>(kv.GetNum("count_forward_strafe", 0));
				g_StyleConfig[key].SetUseGhost(TIMER_MAIN,   view_as<bool>(kv.GetNum("ghost_use", 0)));
				g_StyleConfig[key].SetSaveGhost(TIMER_MAIN,  view_as<bool>(kv.GetNum("ghost_save", 0)));
				g_StyleConfig[key].SetUseGhost(TIMER_BONUS,  view_as<bool>(kv.GetNum("ghost_use_b", 0)));
				g_StyleConfig[key].SetSaveGhost(TIMER_BONUS, view_as<bool>(kv.GetNum("ghost_save_b", 0)));
				g_StyleConfig[key].MaxPrespeed             = kv.GetFloat("prespeed", 0.0);
				g_StyleConfig[key].SlowedSpeed             = kv.GetFloat("slowedspeed", 0.0);
				g_StyleConfig[key].IsSpecial               = view_as<bool>(kv.GetNum("special", 0));
				kv.GetString("specialid", sBuffer, sizeof(sBuffer));
				g_StyleConfig[key].SetSpecialKey(sBuffer, sizeof(sBuffer));
				g_StyleConfig[key].AllowCheckpoints        = view_as<bool>(KvGetNum(kv, "allowcheckpoints", 0));
				g_StyleConfig[key].PointScale              = kv.GetFloat("pointscale", 1.0);
				g_StyleConfig[key].AirAcceleration        = kv.GetNum("aa", 1000);
				g_StyleConfig[key].EnableBunnyhopping     = view_as<bool>(kv.GetNum("enablebhop", 1));
				g_StyleConfig[key].Break                  = kv.GetNum("break", -1);
				g_StyleConfig[key].Start                  = kv.GetNum("start", -1);
				g_StyleConfig[key].AllowTAS               = view_as<bool>(kv.GetNum("allowtas", 1));
				g_StyleConfig[key].AntiNoClip             = view_as<bool>(kv.GetNum("antinoclipprespeed", 0));
				g_StyleConfig[key].GroundStartOnly        = view_as<bool>(kv.GetNum("groundstartonly", 1));
				g_StyleConfig[key].Selectable             = view_as<bool>(kv.GetNum("selectable", 1));
				
				kv.GoBack();
				key++;
			}
		}
		while(keyExists == true && key < MAX_STYLES);
		
		delete kv;
	
		g_TotalStyles = key;
		
		// Reset temporary enabled and disabled styles
		for(int style; style < g_TotalStyles; style++)
		{
			g_StyleConfig[style].Enabled = g_StyleConfig[style].EnabledInConfig;
		}
		
		Call_StartForward(g_fwdOnStylesLoaded);
		Call_Finish();
		
		return true;
	}
	else
	{
		SetFailState("Something went wrong reading from the styles.cfg file.");
	}
	
	return false;
}

void LoadRecordSounds()
{	
	ClearArray(g_hSound_Path_Record);
	ClearArray(g_hSound_Record_Data);
	ClearArray(g_hSound_Path_Personal);
	ClearArray(g_hSound_Path_Fail);
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/sounds.txt");
	
	KeyValues kv = new KeyValues("Sounds");
	kv.ImportFromFile(sPath);
	
	int  key;
	bool keyExists = true;
	char sKey[64], sPrecache[PLATFORM_MAX_PATH], sDownload[PLATFORM_MAX_PATH];
	
	if(kv.JumpToKey("World Record"))
	{
		int data[2];
		do
		{
			IntToString(++key, sKey, sizeof(sKey));
			keyExists = KvJumpToKey(kv, sKey);
			
			if(keyExists == true)
			{
				data[0] = KvGetNum(kv, "Position");
				data[1] = KvGetNum(kv, "mintimes");
				kv.GetString("Sound", sKey, sizeof(sKey));
				
				// precache the sound
				Format(sPrecache, sizeof(sPrecache), "timer/%s", sKey);
				PrecacheSound(sPrecache);
				
				// make clients download it
				Format(sDownload, sizeof(sDownload), "sound/timer/%s", sKey);
				AddFileToDownloadsTable(sDownload);
				
				// add it to array
				PushArrayString(g_hSound_Path_Record, sKey);
				PushArrayArray(g_hSound_Record_Data, data);
				
				kv.GoBack();
			}
		}
		while(keyExists == true);
	}
	kv.Rewind();
	
	if(kv.JumpToKey("Personal Record"))
	{
		key = 0;
		keyExists = true;
		
		do
		{
			IntToString(++key, sKey, sizeof(sKey));
			keyExists = KvJumpToKey(kv, sKey);
			
			if(keyExists == true)
			{
				kv.GetString("Sound", sKey, sizeof(sKey));
				
				// precache the sound
				Format(sPrecache, sizeof(sPrecache), "timer/%s", sKey);
				PrecacheSound(sPrecache);
				
				// make clients download it
				Format(sDownload, sizeof(sDownload), "sound/timer/%s", sKey);
				AddFileToDownloadsTable(sDownload);
				
				// add it to array for later downloading
				PushArrayString(g_hSound_Path_Personal, sKey);
				
				kv.GoBack();
			}
		}
		while(keyExists == true);
	}
	kv.Rewind();
	
	if(kv.JumpToKey("No New Time"))
	{
		key = 0;
		keyExists = true;
		
		do
		{
			IntToString(++key, sKey, sizeof(sKey));
			keyExists = KvJumpToKey(kv, sKey);
			
			if(keyExists == true)
			{
				kv.GetString("Sound", sKey, sizeof(sKey));
				
				// precache the sound
				Format(sPrecache, sizeof(sPrecache), "timer/%s", sKey);
				PrecacheSound(sPrecache);
				
				// make clients download it
				Format(sDownload, sizeof(sDownload), "sound/timer/%s", sKey);
				AddFileToDownloadsTable(sDownload);
				
				// add it to array for later downloading
				PushArrayString(g_hSound_Path_Fail, sKey);
				
				kv.GoBack();
			}
		}
		while(keyExists == true);
	}
	
	delete kv;
}

void PlayFinishSound(int client, bool NewTime, int Position, int type, int style, int tas)
{
	char sSound[64];
	
	if(NewTime == true)
	{
		int iSize = GetArraySize(g_hSound_Record_Data);
		
		ArrayList IndexList = CreateArray();
		
		for(int idx; idx < iSize; idx++)
		{
			if(GetArrayCell(g_hSound_Record_Data, idx, 0) == Position && GetArraySize(g_hTimes[type][style][tas]) >= GetArrayCell(g_hSound_Record_Data, idx, 1))
			{
				PushArrayCell(IndexList, idx);
			}
		}
		
		iSize = GetArraySize(IndexList);
		
		if(iSize > 0)
		{
			int rand = GetRandomInt(0, iSize - 1);
			GetArrayString(g_hSound_Path_Record, GetArrayCell(IndexList, rand), sSound, sizeof(sSound));
			
			int numClients;
			int[] clients = new int[MaxClients + 1];
			for(int target = 1; target <= MaxClients; target++)
			{
				if(IsClientInGame(target) && GetCookieBool(target, g_hRecordSoundCookie))
				{
					clients[numClients++] = target;
					if(g_Engine == Engine_CSGO)
					{
						ClientCommand(target, "play */timer/%s", sSound);
					}
				}
			}
			
			if(g_Engine == Engine_CSS)
			{
				Format(sSound, sizeof(sSound), "timer/%s", sSound);
				EmitSound(clients, numClients, sSound);
			}
			
		}
		else
		{
			iSize = GetArraySize(g_hSound_Path_Personal);
			
			if(iSize > 0)
			{
				int rand = GetRandomInt(0, iSize - 1);
				GetArrayString(g_hSound_Path_Personal, rand, sSound, sizeof(sSound));
				
				if(GetCookieBool(client, g_hPersonalBestSoundCookie))
				{
					if(g_Engine == Engine_CSGO)
					{
						ClientCommand(client, "play */timer/%s", sSound);
					}
					else if(g_Engine == Engine_CSS)
					{
						Format(sSound, sizeof(sSound), "timer/%s", sSound);
						EmitSoundToClient(client, sSound);
					}
				}
			}
		}
		
		delete IndexList;
	}
	else
	{
		int iSize = GetArraySize(g_hSound_Path_Fail);
		
		if(iSize > 0)
		{
			int rand = GetRandomInt(0, iSize - 1);
			GetArrayString(g_hSound_Path_Fail, rand, sSound, sizeof(sSound));
			
			if(GetCookieBool(client, g_hFailedSoundCookie))
			{
				if(g_Engine == Engine_CSGO)
				{
					ClientCommand(client, "play */timer/%s", sSound);
				}
				else if(g_Engine == Engine_CSS)
				{
					Format(sSound, sizeof(sSound), "timer/%s", sSound);
					EmitSoundToClient(client, sSound);
				}
			}
		}
	}
}

void DB_Connect()
{
	if(g_DB != INVALID_HANDLE)
	{
		delete g_DB;
	}
	
	char error[256];
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	
	if(g_DB == INVALID_HANDLE)
	{
		Timer_Log(false, "DB_Connect: %s", error);
		delete g_DB;
	}
}

void LoadPlayerInfo(int client)
{
	int PlayerID = GetPlayerID(client);
	if(IsClientConnected(client) && PlayerID != 0 && !IsFakeClient(client))
	{
		int iSize;
		for(int Type; Type < MAX_TYPES; Type++)
		{
			for(int style; style < MAX_STYLES; style++)
			{
				if(g_StyleConfig[style].GetAllowType(Type))
				{
					for(int tas; tas < 2; tas++)
					{
						g_bPlayerHasTime[client][Type][style][tas] = false;
						
						iSize = GetArraySize(g_hTimes[Type][style][tas]);
						
						for(int idx; idx < iSize; idx++)
						{
							if(GetArrayCell(g_hTimes[Type][style][tas], idx) == PlayerID)
							{
								g_fTime[client][Type][style][tas] = GetArrayCell(g_hTimes[Type][style][tas], idx, 1);
								g_bPlayerHasTime[client][Type][style][tas] = true;
								g_iPosition[client][Type][style][tas] = idx;
							}
						}
					}
				}
			}
		}
		
		g_bTimeIsLoaded[client] = true;
	}
}

void DB_LoadPlayerFavoriteStyles(int client)
{
	Transaction t = new Transaction();
	
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT count(*), Type, Style, tas FROM times WHERE PlayerID=%d GROUP BY Type, Style, tas ORDER BY Type ASC, tas ASC, count(*) DESC",
		GetPlayerID(client));
	t.AddQuery(sQuery);
	
	SQL_ExecuteTransaction(g_DB, t, DB_LoadPlayerFavoriteStyles_Success, DB_LoadPlayerFavoriteStyles_Failure, GetClientUserId(client));
}

public void DB_LoadPlayerFavoriteStyles_Success(Database db, any userid, int numQueries, Handle[] results, any[] queryData)
{
	int client = GetClientOfUserId(userid);
	
	if(client != 0)
	{
		while(SQL_FetchRow(results[0]))
		{
			int count = SQL_FetchInt(results[0], 0);
			int type  = SQL_FetchInt(results[0], 1);
			int style = SQL_FetchInt(results[0], 2);
			int tas   = SQL_FetchInt(results[0], 3);
			
			int data[2];
			data[0] = count;
			data[1] = style;
			
			g_hFavoriteStyles[client][type][tas].PushArray(data);
		}
		
		g_bFavoriteStylesLoaded[client] = true;
	}
}

public void DB_LoadPlayerFavoriteStyles_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError(error);
}

public int Native_GetClientStyle(Handle plugin, int numParams)
{
	return g_TimerInfo[GetNativeCell(1)].GetStyle(g_TimerInfo[GetNativeCell(1)].Type);
}

public int Native_IsTimerPaused(Handle plugin, int numParams)
{
	return g_TimerInfo[GetNativeCell(1)].Paused;
}

public int Native_GetStyleConfig(Handle plugin, int numParams)
{
	SetNativeCellRef(2, g_StyleConfig[GetNativeCell(1)]);
}

public int Native_GetClientTimerType(Handle plugin, int numParams)
{
	return g_TimerInfo[GetNativeCell(1)].Type;
}

public int Native_GetTypeStyleFromCommand(Handle plugin, int numParams)
{
	char sCommand[64];
	GetCmdArg(0, sCommand, sizeof(sCommand));
	ReplaceStringEx(sCommand, sizeof(sCommand), "sm_", "");
	
	int DelimiterLen;
	GetNativeStringLength(1, DelimiterLen);
	
	char[] sDelimiter = new char[DelimiterLen + 1];
	GetNativeString(1, sDelimiter, DelimiterLen + 1);
	
	char sTypeStyle[2][64];
	ExplodeString(sCommand, sDelimiter, sTypeStyle, 2, 64);
	
	if(StrEqual(sTypeStyle[0], ""))
	{
		SetNativeCellRef(2, TIMER_MAIN);
	}
	else if(StrEqual(sTypeStyle[0], "b"))
	{
		SetNativeCellRef(2, TIMER_BONUS);
	}
	else
	{
		return false;
	}
	
	for(int style; style < g_TotalStyles; style++)
	{
		if(g_StyleConfig[style].Enabled)
		{
			char sStyleAbbr[64];
			g_StyleConfig[style].GetNameShort(sStyleAbbr, sizeof(sStyleAbbr));
			if(StrEqual(sTypeStyle[1], sStyleAbbr) || (style == 0 && StrEqual(sTypeStyle[1], "")))
			{
				SetNativeCellRef(3, style);
				return true;
			}
		}
	}
	
	return false;
}

public int Native_GetButtons(Handle plugin, int numParams)
{
	return g_UnaffectedButtons[GetNativeCell(1)];
}

public int Native_GetFlags(Handle plugin, int numParams)
{
	return g_UnaffectedFlags[GetNativeCell(1)];
}

public int Native_PauseTimer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool pause = view_as<bool>(GetNativeCell(2));
	
	if(!IsBeingTimed(client, TIMER_ANY) || !GetConVarBool(g_hAllowPause))
	{
		return false;
	}
	
	if(pause == true)
	{
		PauseTimer(client);
	}
	else
	{
		UnpauseTimer(client);
	}
	
	return true;
}

public int Native_GetClientTimerInfo(Handle plugin, int numParams)
{
	SetNativeCellRef(2, g_TimerInfo[GetNativeCell(1)]);
}

int       g_TimesDeletion_Type[MAXPLAYERS + 1];
int       g_TimesDeletion_Style[MAXPLAYERS + 1];
bool      g_TimesDeletion_TAS[MAXPLAYERS + 1];
char      g_TimesDeletion_Map[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
int       g_TimesDeletion_MinPos[MAXPLAYERS + 1];
int       g_TimesDeletion_MaxPos[MAXPLAYERS + 1];
ArrayList g_TimesDeletion_TimesList[MAXPLAYERS + 1];

public Action SM_Delete(int client, int args)
{
	if(!Timer_ClientHasTimerFlag(client, "delete", Admin_Config))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if(args == 0)
	{
		GetCurrentMap(g_TimesDeletion_Map[client], sizeof(g_TimesDeletion_Map[]));
	}
	else if(args == 1)
	{
		GetCmdArg(1, g_TimesDeletion_Map[client], sizeof(g_TimesDeletion_Map[]));
	}
	else
	{
		PrintColorText(client, "%s%sToo many arguments. Use %s!delete%s or %s!delete <map>%s.",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
		return Plugin_Handled;
	}
	
	g_TimesDeletion_Type[client]   = 0;
	g_TimesDeletion_Style[client]  = 0;
	g_TimesDeletion_TAS[client]    = false;
	g_TimesDeletion_MinPos[client] = 0;
	g_TimesDeletion_MaxPos[client] = 0;
	
	OpenDeleteRecordsMenu(client);
	
	return Plugin_Handled;
}

void OpenDeleteRecordsMenu(int client)
{
	Menu menu = new Menu(DeleteRecords_SelectSettingsMenu);
	menu.SetTitle("Select categories");
	
	char sDisplay[128], sInfo[16];
	GetTypeName(g_TimesDeletion_Type[client], sDisplay, sizeof(sDisplay));
	Format(sDisplay, sizeof(sDisplay), "Timer type: %s", sDisplay);
	IntToString(g_TimesDeletion_Type[client], sInfo, sizeof(sInfo));
	menu.AddItem(sInfo, sDisplay);
	
	Style(g_TimesDeletion_Style[client]).GetName(sDisplay, sizeof(sDisplay));
	Format(sDisplay, sizeof(sDisplay), "Style: %s", sDisplay);
	IntToString(g_TimesDeletion_Style[client], sInfo, sizeof(sInfo));
	menu.AddItem(sInfo, sDisplay);
	
	if(g_TimesDeletion_TAS[client] == false)
	{
		menu.AddItem("0", "TAS: No\n ");
	}
	else
	{
		menu.AddItem("1", "TAS: Yes\n ");
	}
	
	menu.AddItem("confirm", "Confirm");
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int DeleteRecords_SelectSettingsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(param2 == 0) // Timer type
		{
			g_TimesDeletion_Type[param1] = (g_TimesDeletion_Type[param1] + 1) % MAX_TYPES;
			OpenDeleteRecordsMenu(param1);
		}
		else if(param2 == 1) // Style
		{
			g_TimesDeletion_Style[param1] = (g_TimesDeletion_Style[param1] + 1) % g_TotalStyles;
			OpenDeleteRecordsMenu(param1);
		}
		else if(param2 == 2) // TAS
		{
			g_TimesDeletion_TAS[param1] = !g_TimesDeletion_TAS[param1];
			OpenDeleteRecordsMenu(param1);
		}
		else // Confirm
		{
			LoadDeleteRecordsTimeList(param1);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void LoadDeleteRecordsTimeList(int client)
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT PlayerID, Time FROM times WHERE MapID = (SELECT MapID FROM maps WHERE MapName='%s') AND Type = %d AND Style = %d AND tas = %d ORDER BY Time ASC",
		g_TimesDeletion_Map[client],
		g_TimesDeletion_Type[client],
		g_TimesDeletion_Style[client],
		g_TimesDeletion_TAS[client]);
	SQL_TQuery(g_DB, OpenTimesList_Callback, sQuery, GetClientUserId(client));
}

public void OpenTimesList_Callback(Handle owner, Handle hndl, const char[] error, int userid)
{
	if(hndl != INVALID_HANDLE)
	{
		int client = GetClientOfUserId(userid);
		
		if(client != 0)
		{
			if(g_TimesDeletion_TimesList[client] == INVALID_HANDLE)
			{
				g_TimesDeletion_TimesList[client] = CreateArray(2);
			}
			
			ClearArray(g_TimesDeletion_TimesList[client]);
			
			if(SQL_GetRowCount(hndl) == 0)
			{
				PrintColorText(client, "%s%sNo times found under specified category.",
					g_msg_start,
					g_msg_textcol);
				OpenDeleteRecordsMenu(client);
				return;
			}
			any data[2];
			while(SQL_FetchRow(hndl))
			{
				data[0] = SQL_FetchInt(hndl, 0);
				data[1] = SQL_FetchFloat(hndl, 1);
				PushArrayArray(g_TimesDeletion_TimesList[client], data, sizeof(data));
			}
			
			OpenDeleteRecordsTimeListSelectMin(client);
		}
	}
	else
	{
		Timer_Log(false, "OpenTimesList_Callback %s", error);
	}
}

void OpenDeleteRecordsTimeListSelectMin(int client)
{
	Menu menu = CreateMenu(DeleteRecords_TimeListMin);
	
	char sName[MAX_NAME_LENGTH], sTime[32];
	GetNameFromPlayerID(GetArrayCell(g_TimesDeletion_TimesList[client], g_TimesDeletion_MinPos[client], 0), sName, sizeof(sName));
	float fTime = view_as<float>(GetArrayCell(g_TimesDeletion_TimesList[client], g_TimesDeletion_MinPos[client], 1));
	FormatPlayerTime(fTime, sTime, sizeof(sTime), 1);
	menu.SetTitle("Select minimum record to delete\n#%d: %s - %s\n ", g_TimesDeletion_MinPos[client] + 1, sName, sTime);
	
	int iSize = GetArraySize(g_TimesDeletion_TimesList[client]);
	menu.AddItem("+1", "+1", g_TimesDeletion_MinPos[client] + 1 >= iSize?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("+10", "+10", g_TimesDeletion_MinPos[client] + 10 >= iSize?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("+100", "+100", g_TimesDeletion_MinPos[client] + 100 >= iSize?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("-1", "-1", g_TimesDeletion_MinPos[client] - 1 < 0?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("-10", "-10", g_TimesDeletion_MinPos[client] - 10 < 0?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("-100", "-100\n ", g_TimesDeletion_MinPos[client] - 100 < 0?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("Confirm", "Confirm");
	//menu.AddItem("Exit", "Exit");
	
	menu.Pagination = MENU_NO_PAGINATION;
	menu.Display(client, MENU_TIME_FOREVER);
	menu.ExitButton = true;
}

public int DeleteRecords_TimeListMin(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "+1"))
		{
			g_TimesDeletion_MinPos[param1] += 1;
			OpenDeleteRecordsTimeListSelectMin(param1);
		}
		else if(StrEqual(sInfo, "+10"))
		{
			g_TimesDeletion_MinPos[param1] += 10;
			OpenDeleteRecordsTimeListSelectMin(param1);
		}
		else if(StrEqual(sInfo, "+100"))
		{
			g_TimesDeletion_MinPos[param1] += 100;
			OpenDeleteRecordsTimeListSelectMin(param1);
		}
		else if(StrEqual(sInfo, "-1"))
		{
			g_TimesDeletion_MinPos[param1] -= 1;
			OpenDeleteRecordsTimeListSelectMin(param1);
		}
		else if(StrEqual(sInfo, "-10"))
		{
			g_TimesDeletion_MinPos[param1] -= 10;
			OpenDeleteRecordsTimeListSelectMin(param1);
		}
		else if(StrEqual(sInfo, "-100"))
		{
			g_TimesDeletion_MinPos[param1] -= 100;
			OpenDeleteRecordsTimeListSelectMin(param1);
		}
		else if(StrEqual(sInfo, "Confirm"))
		{
			g_TimesDeletion_MaxPos[param1] = g_TimesDeletion_MinPos[param1];
			OpenDeleteRecordsTimeListSelectMax(param1);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void OpenDeleteRecordsTimeListSelectMax(int client)
{
	Menu menu = CreateMenu(DeleteRecords_TimeListMax);
	
	char sName_Min[MAX_NAME_LENGTH], sTime_Min[32], sName_Max[MAX_NAME_LENGTH], sTime_Max[32];
	
	GetNameFromPlayerID(GetArrayCell(g_TimesDeletion_TimesList[client], g_TimesDeletion_MinPos[client], 0), sName_Min, sizeof(sName_Min));
	float fTime_Min = view_as<float>(GetArrayCell(g_TimesDeletion_TimesList[client], g_TimesDeletion_MinPos[client], 1));
	FormatPlayerTime(fTime_Min, sTime_Min, sizeof(sTime_Min), 1);
	
	GetNameFromPlayerID(GetArrayCell(g_TimesDeletion_TimesList[client], g_TimesDeletion_MaxPos[client], 0), sName_Max, sizeof(sName_Max));
	float fTime_Max = view_as<float>(GetArrayCell(g_TimesDeletion_TimesList[client], g_TimesDeletion_MaxPos[client], 1));
	FormatPlayerTime(fTime_Max, sTime_Max, sizeof(sTime_Max), 1);
	
	
	menu.SetTitle("Delete from\n \n#%d: %s - %s\nto\n#%d: %s - %s\n ", 
		g_TimesDeletion_MinPos[client] + 1, sName_Min, sTime_Min,
		g_TimesDeletion_MaxPos[client] + 1, sName_Max, sTime_Max);
	
	int iSize = GetArraySize(g_TimesDeletion_TimesList[client]);
	menu.AddItem("+1", "+1", g_TimesDeletion_MaxPos[client] + 1 >= iSize?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("+10", "+10", g_TimesDeletion_MaxPos[client] + 10 >= iSize?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("+100", "+100", g_TimesDeletion_MaxPos[client] + 100 >= iSize?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("-1", "-1", g_TimesDeletion_MaxPos[client] - 1 < g_TimesDeletion_MinPos[client]?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("-10", "-10", g_TimesDeletion_MaxPos[client] - 10 < g_TimesDeletion_MinPos[client]?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("-100", "-100\n ", g_TimesDeletion_MaxPos[client] - 100 < g_TimesDeletion_MinPos[client]?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("Back", "Back");
	menu.AddItem("Confirm", "Confirm");
	menu.AddItem("Exit", "Exit");
	
	menu.Pagination = MENU_NO_PAGINATION;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int DeleteRecords_TimeListMax(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "+1"))
		{
			g_TimesDeletion_MaxPos[param1] += 1;
			OpenDeleteRecordsTimeListSelectMax(param1);
		}
		else if(StrEqual(sInfo, "+10"))
		{
			g_TimesDeletion_MaxPos[param1] += 10;
			OpenDeleteRecordsTimeListSelectMax(param1);
		}
		else if(StrEqual(sInfo, "+100"))
		{
			g_TimesDeletion_MaxPos[param1] += 100;
			OpenDeleteRecordsTimeListSelectMax(param1);
		}
		else if(StrEqual(sInfo, "-1"))
		{
			g_TimesDeletion_MaxPos[param1] -= 1;
			OpenDeleteRecordsTimeListSelectMax(param1);
		}
		else if(StrEqual(sInfo, "-10"))
		{
			g_TimesDeletion_MaxPos[param1] -= 10;
			OpenDeleteRecordsTimeListSelectMax(param1);
		}
		else if(StrEqual(sInfo, "-100"))
		{
			g_TimesDeletion_MaxPos[param1] -= 100;
			OpenDeleteRecordsTimeListSelectMax(param1);
		}
		else if(StrEqual(sInfo, "Back"))
		{
			OpenDeleteRecordsTimeListSelectMin(param1);
		}
		else if(StrEqual(sInfo, "Confirm"))
		{
			DB_DeleteTimes(param1, g_TimesDeletion_Map[param1], g_TimesDeletion_Type[param1], g_TimesDeletion_Style[param1], g_TimesDeletion_TAS[param1], g_TimesDeletion_MinPos[param1], g_TimesDeletion_MaxPos[param1]);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void DB_DeleteTimes(int client, const char[] sMap, int type, int style, bool tas, int minPos, int maxPos)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "CALL DeleteTimes('%s', %d, %d, %d, %d, %d)", sMap, type, style, tas, minPos, maxPos);
	
	DataPack hPack = CreateDataPack();
	hPack.WriteCell(GetClientUserId(client));
	hPack.WriteString(sMap);
	hPack.WriteCell(type);
	hPack.WriteCell(style);
	hPack.WriteCell(tas);
	hPack.WriteCell(minPos);
	hPack.WriteCell(maxPos);
	SQL_TQuery(g_DB, DeleteTimes_Callback, sQuery, hPack);
}

public void DeleteTimes_Callback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if(hndl != INVALID_HANDLE)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		char sMap[PLATFORM_MAX_PATH]; pack.ReadString(sMap, sizeof(sMap));
		int type   = pack.ReadCell();
		int style  = pack.ReadCell();
		bool tas   = pack.ReadCell();
		int minPos = pack.ReadCell();
		int maxPos = pack.ReadCell();
		
		if(client != 0)
		{
			char sType[32], sStyle[32];
			GetTypeName(type, sType, sizeof(sType));
			Style(style).GetName(sStyle, sizeof(sStyle));
			PrintColorTextAll("%s%sTimes deleted. Map: %s, Timer type: %s, Timer style: %s, TAS: %s, Range: %d to %d",
				g_msg_start,
				g_msg_textcol,
				sMap,
				sType,
				sStyle,
				tas?"Yes":"No",
				minPos + 1,
				maxPos + 1);
			Timer_Log(false, "Times deleted by %L. Map: %s, Timer type: %s, Timer style: %s, TAS: %s, Range: %d to %d",
				client,
				sMap,
				sType,
				sStyle,
				tas?"Yes":"No",
				minPos + 1,
				maxPos + 1);

			OpenDeleteRecordsMenu(client);
		}
		
		Call_StartForward(g_fwdOnTimesDeleted);
		Call_PushString(sMap);
		Call_PushCell(type);
		Call_PushCell(style);
		Call_PushCell(tas);
		Call_PushCell(minPos);
		Call_PushCell(maxPos);
		Call_Finish();
	}
	else
	{
		Timer_Log(false, "DeleteTimes_Callback %s", error);
	}
	
	delete pack;
}

public void OnTimesDeleted(const char[] sMap, int type, int style, bool tas, int minPos, int maxPos)
{
	if(StrEqual(g_sMapName, sMap))
	{
		// Remove times from current map array
		for(int idx = minPos; idx <= maxPos; idx++)
		{
			RemoveFromArray(g_hTimes[type][style][tas], minPos);
			RemoveFromArray(g_hTimesUsers[type][style][tas], minPos);
		}
		
		// Refresh connected player times
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && GetPlayerID(client) != 0)
			{
				LoadPlayerInfo(client);
			}
		}
	}
}

void DB_LoadTimes()
{	
	Timer_Log(true, "SQL Query Start: (Function = DB_LoadTimes, Time = %d)", GetTime());
	
	char query[512];
	Format(query, sizeof(query), "SELECT t1.Type, t1.Style, t1.tas, t1.PlayerID, t1.Time, t2.User FROM times AS t1, players AS \
	t2 WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.PlayerID=t2.PlayerID ORDER BY t1.Type, t1.Style, t1.tas, t1.Time, t1.Timestamp",
		g_sMapName);
		
	DataPack pack = CreateDataPack();
	pack.WriteString(g_sMapName);
	
	SQL_TQuery(g_DB, LoadTimes_Callback, query, pack);
}

public void LoadTimes_Callback(Handle owner, Handle hndl, char[] error, DataPack pack)
{
	if(hndl != INVALID_HANDLE)
	{
		Timer_Log(true, "SQL Query Finish: (Function = DB_LoadTimes, Time = %d)", GetTime());
		
		pack.Reset();
		
		char sMapName[64];
		pack.ReadString(sMapName, sizeof(sMapName));
		
		if(StrEqual(g_sMapName, sMapName))
		{
			for(int type; type < MAX_TYPES; type++)
			{
				for(int style; style < MAX_STYLES; style++)
				{
					for(int tas; tas < 2; tas++)
					{
						ClearArray(g_hTimes[type][style][tas]);
						ClearArray(g_hTimesUsers[type][style][tas]);
					}
				}
			}
			
			int type, style, tas, field;
			char sUser[MAX_NAME_LENGTH];
			any data[2];
			
			while(SQL_FetchRow(hndl))
			{ 
				SQL_FieldNameToNum(hndl, "Type", field);
				type  = SQL_FetchInt(hndl, field);
				SQL_FieldNameToNum(hndl, "Style", field);
				style = SQL_FetchInt(hndl, field);
				SQL_FieldNameToNum(hndl, "tas", field);
				tas   = SQL_FetchInt(hndl, field);
				
				SQL_FieldNameToNum(hndl, "PlayerID", field);
				data[0] = SQL_FetchInt(hndl, field);
				SQL_FieldNameToNum(hndl, "Time", field);
				data[1] = SQL_FetchFloat(hndl, field);
				
				PushArrayArray(g_hTimes[type][style][tas], data, sizeof(data));
				
				SQL_FieldNameToNum(hndl, "User", field);
				SQL_FetchString(hndl, field, sUser, sizeof(sUser));
				PushArrayString(g_hTimesUsers[type][style][tas], sUser);
			}
			
			g_bTimesAreLoaded  = true;
			
			Call_StartForward(g_fwdOnTimesLoaded);
			Call_Finish();
			
			for(int client = 1; client <= MaxClients; client++)
			{
				if(GetPlayerID(client) != 0)
				{
					LoadPlayerInfo(client);
				}
			}
		}
	}
	else
	{
		Timer_Log(false, "LoadTimes_Callback %s", error);
	}
}

stock void VectorAngles(float vel[3], float angles[3])
{
	float tmp, yaw, pitch;
	
	if (vel[1] == 0 && vel[0] == 0)
	{
		yaw = 0.0;
		if (vel[2] > 0)
		{
			pitch = 270.0;
		}
		else
		{
			pitch = 90.0;
		}
	}
	else
	{
		yaw = (ArcTangent2(vel[1], vel[0]) * (180 / 3.141593));
		if (yaw < 0)
		{
			yaw += 360;
		}

		tmp = SquareRoot(vel[0] * vel[0] + vel[1] * vel[1]);
		pitch = (ArcTangent2(-vel[2], tmp) * (180 / 3.141593));
		if (pitch < 0)
		{
			pitch += 360;
		}
	}
	
	angles[0] = pitch;
	angles[1] = yaw;
	angles[2] = 0.0;
}

/*
int GetDirection(int client)
{
	float vVel[3];
	Entity_GetAbsVelocity(client, vVel);
	
	float vAngles[3];
	GetClientEyeAngles(client, vAngles);
	
	float fTempAngle = vAngles[1];

	VectorAngles(vVel, vAngles);

	if(fTempAngle < 0)
	{
		fTempAngle += 360;
	}

	float fTempAngle2 = fTempAngle - vAngles[1];

	if(fTempAngle2 < 0)
	{
		fTempAngle2 = -fTempAngle2;
	}
	
	if(fTempAngle2 < 22.5 || fTempAngle2 > 337.5)
	{	
		return 1; // Forwards
	}
	if(fTempAngle2 > 22.5 && fTempAngle2 < 67.5 || fTempAngle2 > 292.5 && fTempAngle2 < 337.5 )
	{
		return 2; // Half-sideways
	}
	if(fTempAngle2 > 67.5 && fTempAngle2 < 112.5 || fTempAngle2 > 247.5 && fTempAngle2 < 292.5)
	{
		return 3; // Sideways
	}
	if(fTempAngle2 > 112.5 && fTempAngle2 < 157.5 || fTempAngle2 > 202.5 && fTempAngle2 < 247.5)
	{
		return 4; // Backwards Half-sideways
	}
	if(fTempAngle2 > 157.5 && fTempAngle2 < 202.5)
	{
		return 5; // Backwards
	}
	
	return 0; // Unknown
}
*/

#define Button_Forward 0
#define Button_Back    1
#define Button_Left    2
#define Button_Right   3

#define Moving_Forward 0
#define Moving_Back    1
#define Moving_Left    2
#define Moving_Right   3

#define Turn_Left 0
#define Turn_Right 1

int GetDirection(int client)
{
	float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	
	float vAng[3];
	GetClientEyeAngles(client, vAng);
   
	float movementDiff = ArcTangent(vVel[1] / vVel[0]) * 180.0 / FLOAT_PI;
   
	if (vVel[0] < 0.0)
	{
		if (vVel[1] > 0.0)
			movementDiff += 180.0;
		else
			movementDiff -= 180.0;
	}

	if(movementDiff < 0.0)
		movementDiff += 360.0;

	if(vAng[1] < 0.0)
		vAng[1] += 360.0;

	movementDiff = movementDiff - vAng[1];

	bool flipped = false;

	if(movementDiff < 0.0)
	{
		flipped = true;
		movementDiff = -movementDiff;
	}

	if(movementDiff > 180.0)
	{
		if(flipped)
			flipped = false;
		else
			flipped = true;
	   
		movementDiff = FloatAbs(movementDiff - 360.0);
	}

	if(-0.1 < movementDiff < 67.5)
	{
		return Moving_Forward; // Forwards
	}
	if(67.5 < movementDiff < 112.5)
	{
		if(flipped)
		{
			return Moving_Right; // Sideways
		}
		else
		{
			return Moving_Left; // Sideways other way
		}
	}
	if(112.5 < movementDiff <= 180.0)
	{
		return Moving_Back; // Backwards
	}
	return 0; // Unknown should never happend
}

/*
void CheckSync(int client, float vel[3], float angles[3])
{
	if(GetClientVelocity(client, true, true, false) > 5.0)
	{	
		int flags = GetEntityFlags(client);
		MoveType movetype = GetEntityMoveType(client);
		if(!(flags & (FL_INWATER|FL_ONGROUND)) && (movetype == MOVETYPE_WALK))
		{
			// Normalize difference
			float fAngleDiff = angles[1] - g_fOldAngle[client];
			if (fAngleDiff > 180)
			{
				fAngleDiff -= 360;
			}
			else if(fAngleDiff < -180)
			{
				fAngleDiff += 360;
			}
			
			// Add to good sync if client buttons match up
			if(fAngleDiff > 0) // Turning left
			{
				int dButton = GetDesiredButton(client, Turn_Left);
				g_TimerInfo[client].TotalSync++;
				if((dButton == Button_Left && g_fLastMove[client][1] < 0) ||
					(dButton == Button_Right && g_fLastMove[client][1] > 0) ||
					(dButton == Button_Back && g_fLastMove[client][0] < 0) ||
					(dButton == Button_Forward && g_fLastMove[client][0] > 0))
				{
					g_TimerInfo[client].GoodSync++;
				}
			}
			else if(fAngleDiff < 0) // Turning right
			{
				int dButton = GetDesiredButton(client, Turn_Right);
				g_TimerInfo[client].TotalSync++;
				if((dButton == Button_Left && g_fLastMove[client][1] < 0) ||
					(dButton == Button_Right && g_fLastMove[client][1] > 0) ||
					(dButton == Button_Back && g_fLastMove[client][0] < 0) ||
					(dButton == Button_Forward && g_fLastMove[client][0] > 0))
				{
					g_TimerInfo[client].GoodSync++;
				}
			}
		}
	}
}
*/

void CheckSync(int client, float angles[3])
{
	if(!(GetEntityFlags(client) & (FL_INWATER|FL_ONGROUND)) && (GetEntityMoveType(client) == MOVETYPE_WALK))
	{
		//Normalize difference
		float fAngleDiff = angles[1] - g_fOldAngle[client];
		if (fAngleDiff > 180)
		{
			fAngleDiff -= 360;
		}
		else if(fAngleDiff < -180)
		{
			fAngleDiff += 360;
		}
		
		//Calculate sync if there's any camera movement
		if(fAngleDiff)
		{
			g_TimerInfo[client].TotalSync++;
			
			//Get movement direction
			float fore[3], side[3], wishvel[3], wishdir[3];

			GetAngleVectors(angles, fore, side, NULL_VECTOR);

			fore[2] = 0.0;
			side[2] = 0.0;
			NormalizeVector(fore, fore);
			NormalizeVector(side, side);

			for(int i = 0; i < 2; i++)
				wishvel[i] = fore[i] * g_fLastMove[client][0] + side[i] * g_fLastMove[client][1];
				
			float velocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
			
			//Add to good sync if any acceleration happens
			if(NormalizeVector(wishvel, wishdir) && GetVectorDotProduct(velocity, wishdir) < 30.0)
				g_TimerInfo[client].GoodSync++;
		}
	}
}

stock int GetDesiredButton(int client, int dir)
{
	int moveDir = GetDirection(client);
	int button;
	if(dir == Turn_Left)
	{
		if(moveDir == Moving_Forward)
		{
			button = Button_Left;
		}
		else if(moveDir == Moving_Back)
		{
			button = Button_Right;
		}
		else if(moveDir == Moving_Left)
		{
			button = Button_Back;
		}
		else if(moveDir == Moving_Right)
		{
			button = Button_Forward;
		}
	}
	else if(dir == Turn_Right)
	{
		if(moveDir == Moving_Forward)
		{
			button = Button_Right;
		}
		else if(moveDir == Moving_Back)
		{
			button = Button_Left;
		}
		else if(moveDir == Moving_Left)
		{
			button = Button_Forward;
		}
		else if(moveDir == Moving_Right)
		{
			button = Button_Back;
		}
	}
	
	return button;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	g_UnaffectedButtons[client] = buttons;
	g_UnaffectedFlags[client]   = GetEntityFlags(client);
	bool bIsTiming = g_TimerInfo[client].IsTiming;
	bool bPaused   = g_TimerInfo[client].Paused;
	if(IsPlayerAlive(client) && !IsFakeClient(client))
	{
		if(bIsTiming == true)
		{
			if(bPaused == false)
			{
				g_TimerInfo[client].CurrentTime += GetTickInterval() * GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
			}
			else
			{
				vel[0] = 0.0;
				vel[1] = 0.0;
			}
		}
	
		int style = g_TimerInfo[client].GetStyle(g_TimerInfo[client].Type);
		
		// Calculate sync
		CheckSync(client, angles);
		
		// Key restriction
		bool bRestrict;
		
		if(g_StyleConfig[style].PreventLeft && vel[1] < 0)
			bRestrict = true;
		if(g_StyleConfig[style].PreventRight && vel[1] > 0)
			bRestrict = true;
		if(g_StyleConfig[style].PreventBack && vel[0] < 0)
			bRestrict = true;
		if(g_StyleConfig[style].PreventForward && vel[0] > 0)
			bRestrict = true;
		
		if(g_StyleConfig[style].RequireLeft && vel[1] >= 0)
			bRestrict = true;
		if(g_StyleConfig[style].RequireRight && vel[1] <= 0)
			bRestrict = true;
		if(g_StyleConfig[style].RequireBack && vel[0] >= 0)
			bRestrict = true;
		if(g_StyleConfig[style].RequireForward && vel[0] <= 0)
			bRestrict = true;
		
		if(g_StyleConfig[style].IsSpecial == true)
		{
			if(g_StyleConfig[style].HasSpecialKey("hsw"))
			{
				if(vel[0] > 0 && vel[1] != 0)
				{
					g_HSWCounter[client] = GetEngineTime();
				}
				
				if(((GetEngineTime() - g_HSWCounter[client] > 0.4) || vel[0] <= 0) && !(GetEntityFlags(client) & FL_ONGROUND))
				{
					bRestrict = true;
				}
			}
			
			if(g_StyleConfig[style].HasSpecialKey("antiscript"))
			{
				SetEntityFlags(client, GetEntityFlags(client) | FL_ONGROUND);
			}
			
			if(g_StyleConfig[style].HasSpecialKey("bw"))
			{
				int direction = GetDirection(client);
				if(direction != Moving_Back)
				{
					bRestrict = true;
				}
				
				if(GetEntityFlags(client) & (FL_ONGROUND|FL_INWATER))
				{
					bRestrict = false;
				}
				
				if(GetClientVelocity(client, true, true, false) < 30.0)
				{
					bRestrict = false;
				}
			}
			
			if(g_StyleConfig[style].HasSpecialKey("surfhsw-aw-sd"))
			{
				if((vel[0] > 0.0 && vel[1] < 0.0) || (vel[0] < 0.0 && vel[1] > 0.0)) // If pressing w and a or s and d, keep unrestricted
				{
					g_HSWCounter[client] = GetEngineTime();
				}
				else if(GetEngineTime() - g_HSWCounter[client] > 0.3) // Restrict if player hasn't held the right buttons for too long
				{
					bRestrict = true;
				}
			}
			
			if(g_StyleConfig[style].HasSpecialKey("surfhsw-as-wd"))
			{
				if ((vel[0] < 0.0 && vel[1] < 0.0) || (vel[0] > 0.0 && vel[1] > 0.0))
				{
					g_HSWCounter[client] = GetEngineTime();
				}
				else if(GetEngineTime() - g_HSWCounter[client] > 0.3)
				{
					bRestrict = true;
				}
			}
			
			if(g_StyleConfig[style].HasSpecialKey("aord"))
			{
				if(vel[0] != 0.0)
				{
					bRestrict = true;
				}
				
				if(!g_AorD_HasPickedKey[client])
				{
					if(vel[1] < 0.0)
					{
						g_AorD_HasPickedKey[client] = true;
						g_AorD_ChosenKey[client]    = false;
					}
					else if(vel[1] > 0.0)
					{
						g_AorD_HasPickedKey[client] = true;
						g_AorD_ChosenKey[client]    = true;
					}
				}
				else
				{
					if(g_AorD_ChosenKey[client] == false && vel[1] > 0.0)
					{
						bRestrict = true;
					}
					else if(g_AorD_ChosenKey[client] == true && vel[1] < 0.0)
					{
						bRestrict = true;
					}
				}
			}
		}
		
		// Unrestrict movement inside freestyle zones
		if(g_bZonePluginLoaded && g_StyleConfig[style].Freestyle && g_StyleConfig[style].FreestyleUnrestrict)
			if(Timer_InsideZone(client, FREESTYLE, 1 << style, view_as<int>(zFs_Unrestrict)) != -1)
				bRestrict = false;
			
		// Unrestrict movement in noclip
		if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
			bRestrict = false;
			
		
		
		if(bRestrict == true)
		{
			if(!(GetEntityFlags(client) & FL_ATCONTROLS))
				SetEntityFlags(client, GetEntityFlags(client) | FL_ATCONTROLS);
		}
		else
		{
			if(GetEntityFlags(client) & FL_ATCONTROLS)
				SetEntityFlags(client, GetEntityFlags(client) &  ~FL_ATCONTROLS);
		}
		
		// Count strafes
		if(g_StyleConfig[style].CountLeftStrafe && !(g_Buttons[client] & IN_MOVELEFT) && (buttons & IN_MOVELEFT))
			g_TimerInfo[client].Strafes++;
		if(g_StyleConfig[style].CountRightStrafe && !(g_Buttons[client] & IN_MOVERIGHT) && (buttons & IN_MOVERIGHT))
			g_TimerInfo[client].Strafes++;
		if(g_StyleConfig[style].CountBackStrafe && !(g_Buttons[client] & IN_BACK) && (buttons & IN_BACK))
			g_TimerInfo[client].Strafes++;
		if(g_StyleConfig[style].CountForwardStrafe && !(g_Buttons[client] & IN_FORWARD) && (buttons & IN_FORWARD))
			g_TimerInfo[client].Strafes++;
		
		bool bTas = g_bTasPluginLoaded?TAS_InEditMode(client):false;
		
		if(g_TimerInfo[client].IsTiming == true && bTas == false)
		{		
			bool bStop;
			// Anti - +left/+right
			if(buttons & (IN_LEFT|IN_RIGHT) == IN_LEFT|IN_RIGHT)
			{
				bStop = true;
			}
			else if(buttons & (IN_LEFT|IN_RIGHT))
			{
				if(g_AllowedYawspeed[client] != 0 && (g_AllowedYawspeed[client] != (buttons & (IN_RIGHT|IN_LEFT))))
				{
					bStop = true;
				}
				else
				{
					g_AllowedYawspeed[client] = buttons & (IN_LEFT|IN_RIGHT);
				}
			}
			if(bStop == true)
			{
				StopTimer(client);
				if(!g_bZonePluginLoaded || (Timer_InsideZone(client, MAIN_START) == -1 && Timer_InsideZone(client, BONUS_START) == -1))
				{
					PrintColorText(client, "%s%sYour timer was stopped for using both +left and +right in one jump.",
						g_msg_start,
						g_msg_textcol);
				}
			}
		}
		
		// auto bhop check
		if(g_Engine == Engine_CSS && g_bAllowAuto)
		{
			if(g_StyleConfig[style].Auto || (g_StyleConfig[style].Freestyle && (!g_bZonePluginLoaded || Timer_InsideZone(client, FREESTYLE, 1 << style, view_as<int>(zFs_Auto)) != -1)))
			{
				if(GetCookieBool(client, g_hAutohopCookie) && IsPlayerAlive(client))
				{
					if(buttons & IN_JUMP)
					{
						if(!(GetEntityFlags(client) & FL_ONGROUND))
						{
							if(GetEntityMoveType(client) == MOVETYPE_WALK)
							{
								if(GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1)
								{
									buttons &= ~IN_JUMP;
								}
							}
						}
					}
				}
			}
		}
		
		if(g_bZonePluginLoaded == true && g_bJumpInStartZone == false)
		{
			if(Timer_InsideZone(client, MAIN_START) != -1 || Timer_InsideZone(client, BONUS_START) != -1)
			{
				buttons &= ~IN_JUMP;
			}
		}
	}
	
	g_Buttons[client]   = buttons;
	g_fLastMove[client][0] = vel[0];
	g_fLastMove[client][1] = vel[1];
	g_fOldAngle[client] = angles[1];
}