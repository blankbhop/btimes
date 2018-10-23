#include <sourcemod>
#include <smlib/entities>
#include <smlib/arrays>
#include <bTimes-core>
#include <bTimes-timer>
#include <bTimes-zones>
#include <setname>
#include <cstrike>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#include <bTimes-tas>
#include <buttonhook>
//#include <painter>

public Plugin:myinfo = 
{
	name = "[Timer] - Replay",
	author = "blacky",
	description = "Replay bots",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#pragma newdecls required
#pragma semicolon 1

int       g_ReplayBot;
int       g_ReplayOwner;
ArrayList g_hReplayQueue;
ArrayList g_hReplayFrame[MAX_TYPES][MAX_STYLES][2];
int       g_ReplayCurrentFrame;
int       g_ReplayMaxFrame;
float     g_ReplayBotTime[MAX_TYPES][MAX_STYLES][2];
int       g_ReplayPlayerId[MAX_TYPES][MAX_STYLES][2];
char      g_ReplayBotTag[MAX_TYPES][MAX_STYLES][2][MAX_NAME_LENGTH];
bool      g_ReplayBotIsReplaying;
bool      g_bReplayLoaded[MAX_TYPES][MAX_STYLES][2];
int       g_ReplayBotTimerType  = -1;
int       g_ReplayBotTimerStyle = -1;
bool      g_ReplayBotIsTas;
char      g_sMapName[64];
bool      g_bLateLoad;
bool      g_bUsedFrame[MAXPLAYERS + 1];
bool      g_bTasLoaded;
bool      g_bPainterLoaded;
int       g_iGameRulesEnt;
int       g_CurrentValue[3];
int       g_ExpectedValue[3];
int       g_FadeSpeed = 1;
int       g_iDecal;

ArrayList g_hPlayerFrame[MAXPLAYERS + 1];
int g_ReplayMenuType[MAXPLAYERS + 1];
int g_ReplayMenuStyle[MAXPLAYERS + 1];
int g_ReplayMenuTAS[MAXPLAYERS + 1];
bool g_bIsReplayAdmin[MAXPLAYERS + 1];

EngineVersion g_Engine;

// ConVars
ConVar g_cSmoothing;
ConVar g_cSpawnCount;
ConVar g_hForceBotQuota;

#define REPLAY_FRAME_SIZE 6

public void OnPluginStart()
{
	g_Engine = GetEngineVersion();
	
	// ConVars
	g_cSmoothing     = CreateConVar("timer_smoothing", "1", "Uses a smoothing algorithm when saving TAS runs to make them look nicer. (Experimental)", 0, true, 0.0, true, 1.0);
	g_cSpawnCount    = CreateConVar("timer_spawncount", "24", "Ensures 24 spawn points on each team.", 0, true, 0.0);
	g_hForceBotQuota = CreateConVar("timer_forcebotquota", "1", "Forces the bot quota to 1", 0, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "replay", "timer");
	
	// Commands
	RegConsoleCmd("sm_replay", SM_Replay);
	RegConsoleCmd("sm_bot", SM_Replay);
	RegConsoleCmd("sm_specbot", SM_SpecBot);
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			for(int tas; tas < 2; tas++)
			{
				g_hReplayFrame[Type][style][tas] = new ArrayList(6);
			}
		}
	}
	
	if(g_bLateLoad)
	{
		UpdateMessages();
		
		g_iGameRulesEnt = FindEntityByClassname(-1, "cs_gamerules");
	}
	
	g_hReplayQueue = new ArrayList(4);
	
	UserMsg msgSayText2 = GetUserMessageId("SayText2");
	
	if(msgSayText2 != INVALID_MESSAGE_ID)
	{
		HookUserMessage(msgSayText2, OnSayText2, true);
	}
	
	//HookEvent("round_start", Event_RoundStart);
	HookEvent("player_changename", Event_ChangeName);
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes");
	
	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
	
	ConVar c = FindConVar("sv_tags");
	c.Flags &= ~FCVAR_NOTIFY;
	delete c;
	
	c = FindConVar("bot_quota");
	c.Flags &= ~FCVAR_NOTIFY;
	
}

bool g_bFastForward[MAXPLAYERS + 1];
bool g_bRewind[MAXPLAYERS + 1];
public Action OnClientCommand(int client, int args)
{
	char sArg[64];
	GetCmdArg(0, sArg, sizeof(sArg));
	if(StrEqual(sArg, "+fastforward"))
	{
		g_bFastForward[client] = true;
	}
	else if(StrEqual(sArg, "-fastforward"))
	{
		g_bFastForward[client] = false;
	}
	else if(StrEqual(sArg, "+rewind"))
	{
		g_bRewind[client] = true;
	}
	else if(StrEqual(sArg, "-rewind"))
	{
		g_bRewind[client] = false;
	}
}

public Action Event_ChangeName(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}
	
	int playerId = GetPlayerID(client);
	if(playerId == 0)
	{
		return;
	}
	
	for(int Type = 0; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			for(int tas; tas < 2; tas++)
			{
				if(g_ReplayPlayerId[Type][style][tas] == playerId)
				{
					char sNewName[MAX_NAME_LENGTH];
					GetEventString(event, "newname", sNewName, MAX_NAME_LENGTH);
					FormatEx(g_ReplayBotTag[Type][style][tas], MAX_NAME_LENGTH, sNewName);
				}
			}
		}
	}
}

// Block the name replay bot's name changes
public Action OnSayText2(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	char sMsgType[64];
	int client;
	
	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
	{
		client = PbReadInt(msg, "ent_idx");
		PbReadString(msg, "msg_name", sMsgType, sizeof(sMsgType));
	}
	else
	{
		client = BfReadByte(msg);
		BfReadByte(msg);
		BfReadString(msg, sMsgType, sizeof(sMsgType));
	}
	
	if((0 < client <= MaxClients) && IsFakeClient(client) && StrEqual(sMsgType, "#Cstrike_Name_Change"))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Replay_IsReplaying",           Native_IsReplaying);
	CreateNative("Replay_IsClientReplayBot",     Native_IsClientReplayBot);
	CreateNative("Replay_GetCurrentReplayType",  Native_GetCurrentReplayType);
	CreateNative("Replay_GetCurrentReplayStyle", Native_GetCurrentReplayStyle);
	CreateNative("Replay_GetCurrentReplayTAS",   Native_GetCurrentReplayTAS);
	CreateNative("Replay_GetPlayerName",         Native_GetPlayerName);
	CreateNative("Replay_GetPlayerId",           Native_GetPlayerId);
	CreateNative("Replay_GetTime",               Native_GetTime);
	CreateNative("Replay_GetCurrentTimeInRun",   Native_GetCurrentTimeInRun);
	
	RegPluginLibrary("replay");

	g_bLateLoad = late;
	
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bTasLoaded = LibraryExists("tas");
	g_bPainterLoaded = LibraryExists("painter");
}

public void OnLibraryAdded(const char[] library)
{
	if(StrEqual(library, "tas"))
	{
		g_bTasLoaded = true;
	}
	
	if(StrEqual(library, "painter"))
	{
		g_bPainterLoaded = true;
	}
}

public void OnLibraryRemoved(const char[] library)
{
	if(StrEqual(library, "tas"))
	{
		g_bTasLoaded = false;
	}
	
	if(StrEqual(library, "painter"))
	{
		g_bPainterLoaded = false;
	}
}

public void OnPluginEnd()
{
	ServerCommand("bot_kick all");
}

public void OnMapStart()
{
	if(g_bLateLoad == true)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && !IsFakeClient(client))
			{
				InitializePlayerSettings(client);
			}
		}
	}
	
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	ServerCommand("bot_add");
	
	g_ReplayBotIsReplaying = false;
	g_ReplayBotTimerType   = -1;
	g_ReplayBotTimerStyle  = -1;
	g_ReplayBotIsTas       = false;
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			for(int tas; tas < 2; tas++)
			{		
				g_hReplayFrame[Type][style][tas].Clear();
				g_bReplayLoaded[Type][style][tas]  = false;
				g_ReplayBotTime[Type][style][tas]  = 0.0;
				g_ReplayPlayerId[Type][style][tas] = 0;
				FormatEx(g_ReplayBotTag[Type][style][tas], MAX_NAME_LENGTH, "");
			}
		}
	}
	
	if(IsPlayerIDListLoaded() == true)
	{
		LoadReplays();
	}
	
	if(g_bLateLoad == true)
	{
		int maxEnts = GetMaxEntities();
		char sClassname[64];
		for(int entity = MAXPLAYERS + 1; entity < maxEnts; entity++)
		{
			if(IsValidEntity(entity))
			{
				GetEntityClassname(entity, sClassname, 64);
				
				if(StrContains(sClassname, "trigger_") != -1)
				{
					SDKHook(entity, SDKHook_StartTouch, Hook_Touch);
					SDKHook(entity, SDKHook_EndTouch, Hook_Touch);
					SDKHook(entity, SDKHook_Touch, Hook_Touch);
				}
			}
		}
	}
		
	
	CreateTimer(2.0, Timer_ReplayChecker, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	CreateSpawns();
	
	char sFile[PLATFORM_MAX_PATH];
	FormatEx(sFile, sizeof(sFile), "decals/paintk/laser_red_large.vmt");
	g_iDecal = PrecacheDecal(sFile, true);
	FormatEx(sFile, sizeof(sFile), "materials/decals/paintk/laser_red_large.vmt");
	AddFileToDownloadsTable(sFile);
}

void CreateSpawns()
{
	int spawn = FindEntityByClassname(-1, "info_player_terrorist");
	
	if(spawn == -1)
	{
		spawn = FindEntityByClassname(-1, "info_player_counterterrorist");
	}
	
	if(spawn != -1)
	{
		float vPos[3];
		Entity_GetAbsOrigin(spawn, vPos);
		vPos[2] += 5.0;
		
		int newSpawn;
		int spawnCount = GetEntityCountByClassname("info_player_terrorist");
		for(int idx = spawnCount; idx <= GetConVarInt(g_cSpawnCount); idx++)
		{
			newSpawn = CreateEntityByName("info_player_terrorist");
			
			if(newSpawn != -1)
			{
				DispatchSpawn(newSpawn);
				TeleportEntity(newSpawn, vPos, NULL_VECTOR, NULL_VECTOR);
			}
			else
			{
				Timer_Log(false, "Failed to create new spawn for replay bot.");
			}
		}
		
		spawnCount = GetEntityCountByClassname("info_player_counterterrorist");
		for(int idx = spawnCount; idx <= GetConVarInt(g_cSpawnCount); idx++)
		{
			newSpawn = CreateEntityByName("info_player_counterterrorist");
			
			if(newSpawn != -1)
			{
				DispatchSpawn(newSpawn);
				TeleportEntity(newSpawn, vPos, NULL_VECTOR, NULL_VECTOR);
			}
			else
			{
				Timer_Log(false, "Failed to create new spawn for replay bot.");
			}
		}
	}
}

int GetEntityCountByClassname(char[] sClassname)
{
	int entity = -1;
	int entityCount;
	while((entity = FindEntityByClassname(entity, sClassname)) != -1)
	{
		entityCount++;
	}
	
	return entityCount;
}

public Action Timer_ReplayChecker(Handle timer, any data)
{
	if(g_hForceBotQuota.BoolValue == true && FindConVar("bot_quota").IntValue != 1)
	{
		SetBotQuota(1);
	}
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsFakeClient(client))
		{
			if(!IsPlayerAlive(client))
			{
				CS_RespawnPlayer(client);
			}
			
			if(client != g_ReplayBot)
			{
				KickClient(client, "You're not supposed to be here!");
			}
		}
	}

	if(g_ReplayBot == 0 || !IsClientInGame(g_ReplayBot))
	{
		bool bBotAlreadyExists;
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && IsFakeClient(client) && !IsClientSourceTV(client))
			{
				if(bBotAlreadyExists == false)
				{
					g_ReplayBot = client;
					SetClientName(g_ReplayBot, "!replay");
					SDKHook(client, SDKHook_WeaponEquip, OnReplayEquip);
					bBotAlreadyExists = true;
				}
				else
				{
					KickClient(client, "You're not supposed to be here!");
				}
			}
		}
		
		if(bBotAlreadyExists == false)
		{
			ServerCommand("bot_kick all");
			ServerCommand("bot_add");
		}
		
	}
	else
	{
		if(GetClientTeam(g_ReplayBot) <= 1)
		{
			ChangeClientTeam(g_ReplayBot, GetRandomInt(2, 3));
		}
	
		if(!IsPlayerAlive(g_ReplayBot))
		{
			CS_RespawnPlayer(g_ReplayBot);
		}
		
		char sName[MAX_NAME_LENGTH];
		GetClientName(g_ReplayBot, sName, MAX_NAME_LENGTH);
		
		if(g_ReplayBotIsReplaying)
		{
			char sType[32], sStyle[32], sTime[32], sResult[MAX_NAME_LENGTH];
			GetTypeName(g_ReplayBotTimerType, sType, sizeof(sType));
			Style(g_ReplayBotTimerStyle).GetName(sStyle, sizeof(sStyle));
			FormatPlayerTime(g_ReplayBotTime[g_ReplayBotTimerType][g_ReplayBotTimerStyle][g_ReplayBotIsTas], sTime, sizeof(sTime), 1);
			FormatEx(sResult, sizeof(sResult), "%s - %s%s - %s", sType, sStyle, g_ReplayBotIsTas?" (TAS)":"", sTime);
			
			if(!StrEqual(sName, sResult))
			{
				SetClientName(g_ReplayBot, sResult);
			}	
		}
		else
		{
			if(!StrEqual(sName, "!replay"))
			{
				SetClientName(g_ReplayBot, "!replay");
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	InitializePlayerSettings(client);
}

public void OnClientPostAdminCheck(int client)
{
	AdminFlag flag = Admin_Generic;
	Timer_GetAdminFlag("replay", flag);
			
	g_bIsReplayAdmin[client] = GetAdminFlag(GetUserAdmin(client), flag, Access_Effective);
}

void InitializePlayerSettings(int client)
{
	if(g_bUsedFrame[client] == false)
	{
		g_hPlayerFrame[client] = CreateArray(6);
		g_bUsedFrame[client] = true;
	}
	else
	{
		g_hPlayerFrame[client].Clear();
	}
	
	g_ReplayMenuType[client] = 0;
	g_ReplayMenuStyle[client] = 0;
	g_ReplayMenuTAS[client] = 0;
}

public void OnConfigsExecuted()
{
	// Required settings
	ServerCommand("bot_chatter off");
	ServerCommand("bot_join_after_player 0");
	ServerCommand("bot_quota_mode normal");
	ServerCommand("bot_stop 1");
}

void SetBotQuota(int value)
{
	ServerCommand("bot_quota %d", value);
}

public void OnPlayerIDListLoaded()
{
	LoadReplays();
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlength)
{
	if(IsFakeClient(client) && !IsClientSourceTV(client))
	{
		if(0 < g_ReplayBot <= MaxClients && IsClientInGame(g_ReplayBot))
		{
			return false;
		}
		
		g_ReplayBot = client;
		SetClientName(g_ReplayBot, "!replay");
		SDKHook(client, SDKHook_WeaponEquip, OnReplayEquip);
	}

	return true;
}

public Action OnReplayEquip(int client, int weapon)
{
	char sClassname[64];
	GetEntityClassname(weapon, sClassname, sizeof(sClassname));
	if(!StrEqual(sClassname, "weapon_knife"))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
	
}

public void OnClientDisconnect(int client)
{
	if(g_ReplayBot == client)
	{
		g_ReplayBot = 0;
	}
	
	g_bIsReplayAdmin[client] = false;
}

public void OnTimerStart_Post(int client, int Type, int style)
{
	// Reset saved ghost data
	g_hPlayerFrame[client].Clear();
}

public Action SM_SpecBot(int client, int args)
{
	if(0 < g_ReplayBot <= MaxClients && IsClientInGame(g_ReplayBot))
	{
		ForcePlayerSuicide(client);
		ChangeClientTeam(client, 1);
		StopTimer(client);
		
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", g_ReplayBot);
	}
	
	return Plugin_Handled;
}

public Action SM_Replay(int client, int args)
{
	AdminFlag flag = Admin_Generic;
	Timer_GetAdminFlag("replay", flag);
	
	if(GetAdminFlag(GetUserAdmin(client), flag, Access_Effective))
	{
		OpenAdminReplayMenu(client);
	}
	else
	{
		OpenPlayReplayMenu(client);
	}
	
	return Plugin_Handled;
}

void OpenAdminReplayMenu(int client)
{
	Menu menu = new Menu(Menu_AdminReplay);
	menu.SetTitle("Replay bot admin menu");
	
	menu.AddItem("play",  "Play replay");
	menu.AddItem("del",   "Delete replay");
	menu.AddItem("stop",  "Stop replay");
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_AdminReplay(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "del"))
		{
			OpenDeleteReplayMenu(param1);
		}
		else if(StrEqual(sInfo, "stop"))
		{
			StopCurrentReplay();
			OpenAdminReplayMenu(param1);
		}
		else if(StrEqual(sInfo, "play"))
		{
			OpenPlayReplayMenu(param1);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}

void OpenDeleteReplayMenu(int client)
{
	Menu menu = new Menu(Menu_DeleteReplay);
	menu.SetTitle("Select replay to delete");
	
	char sType[32], sStyle[32], sTime[32], sResult[64], sInfo[32];
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			for(int tas; tas < 2; tas++)
			{		
				if(g_bReplayLoaded[Type][style][tas] == true)
				{
					GetTypeName(Type, sType, sizeof(sType));
					Style(style).GetName(sStyle, sizeof(sStyle));
					FormatPlayerTime(g_ReplayBotTime[Type][style][tas], sTime, sizeof(sTime), 1);
					FormatEx(sResult, sizeof(sResult), "%s%s - %s : %s\nby %s", 
						tas?"TAS: ":"",
						sType, 
						sStyle, 
						sTime, 
						g_ReplayBotTag[Type][style][tas]);
					FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", Type, style, tas);
					menu.AddItem(sInfo, sResult);
				}
			}
		}
	}
	
	if(menu.ItemCount == 0)
	{
		PrintColorText(client, "%s%sThere are no replays yet for this map.", g_msg_start, g_msg_textcol);
		delete menu;
	}
	else
	{
		AdminFlag flag = Admin_Generic;
		Timer_GetAdminFlag("replay", flag);
		
		if(GetAdminFlag(GetUserAdmin(client), flag, Access_Effective))
		{
			menu.ExitBackButton = true;
		}
	
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int Menu_DeleteReplay(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sInfoExploded[3][16];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		
		int Type  = StringToInt(sInfoExploded[0]);
		int style = StringToInt(sInfoExploded[1]);
		int tas   = StringToInt(sInfoExploded[2]);
		
		char sType[32], sStyle[32], sTime[32];
		GetTypeName(Type, sType, sizeof(sType));
		Style(style).GetName(sStyle, sizeof(sStyle));
		FormatPlayerTime(g_ReplayBotTime[Type][style][tas], sTime, sizeof(sTime), 1);
		
		Timer_Log(false, "%L deleted replay (Map: %s, Type: %s, Style: %s, TAS: %s, Replay owner: %s, Replay time: %s)",
			param1,
			g_sMapName,
			sType,
			sStyle,
			tas?"Yes":"No",
			g_ReplayBotTag[Type][style][tas],
			sTime);
		DeleteReplay(Type, style, tas);
		
		OpenAdminReplayMenu(param1);
	}
	
	if (action & MenuAction_End)
	{
		delete menu;
	}
		
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			OpenAdminReplayMenu(param1);
		}
	}
}

void OpenPlayReplayMenu(int client)
{
	Menu menu = new Menu(Menu_PlayReplay);
	
	char sTitle[128], sTime[32];
	int replayCount = GetAvailableReplayCount();
	
	if(g_bReplayLoaded[g_ReplayMenuType[client]][g_ReplayMenuStyle[client]][g_ReplayMenuTAS[client]])
	{
		char sPlayerID[32];
		FormatEx(sPlayerID, sizeof(sPlayerID), " (%d)", g_ReplayPlayerId[g_ReplayMenuType[client]][g_ReplayMenuStyle[client]][g_ReplayMenuTAS[client]]);
		FormatPlayerTime(g_ReplayBotTime[g_ReplayMenuType[client]][g_ReplayMenuStyle[client]][g_ReplayMenuTAS[client]], sTime, sizeof(sTime), 1);
		FormatEx(sTitle, sizeof(sTitle), "Select replay (%d available)\n \nPlayer: %s%s\nTime: %s\n \n",
			replayCount,
			g_ReplayBotTag[g_ReplayMenuType[client]][g_ReplayMenuStyle[client]][g_ReplayMenuTAS[client]],
			Timer_ClientHasTimerFlag(client, "replay", Admin_Generic)?sPlayerID:"",
			sTime);
	}
	else
	{
		FormatEx(sTitle, sizeof(sTitle), "Select replay (%d available)\n \nSpecified replay unavailable\n \n ",
			replayCount);
	}
	
	menu.SetTitle(sTitle);
	
	char sType[32], sStyle[32], sDisplay[256];
	GetTypeName(g_ReplayMenuType[client], sType, sizeof(sType));
	FormatEx(sDisplay, sizeof(sDisplay), "Type: %s", sType);
	menu.AddItem("type", sDisplay);
	
	Style(g_ReplayMenuStyle[client]).GetName(sStyle, sizeof(sStyle));
	FormatEx(sDisplay, sizeof(sDisplay), "Style: %s", sStyle);
	menu.AddItem("style", sDisplay);
	
	FormatEx(sDisplay, sizeof(sDisplay), "TAS: %s", g_ReplayMenuTAS[client]?"Yes\n \n":"No\n \n");
	menu.AddItem("tas", sDisplay);
	
	menu.AddItem("confirm", "Play", g_bReplayLoaded[g_ReplayMenuType[client]][g_ReplayMenuStyle[client]][g_ReplayMenuTAS[client]]?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	
	if(menu.ItemCount == 0)
	{
		PrintColorText(client, "%s%sThere are no replays yet for this map.", g_msg_start, g_msg_textcol);
		delete menu;
	}
	else
	{
		if(Timer_ClientHasTimerFlag(client, "replay", Admin_Generic))
		{
			menu.ExitBackButton = true;
		}
		
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

int GetAvailableReplayCount()
{
	int replayCount;
	for(int type; type < MAX_TYPES; type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			for(int tas; tas < 2; tas++)
			{
				if(Style(style).Enabled && Style(style).GetUseGhost(type) && g_bReplayLoaded[type][style][tas])
				{
					replayCount++;
				}
			}
		}
	}
	
	return replayCount;
}

public int Menu_PlayReplay(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "type"))
		{
			g_ReplayMenuType[client] = (g_ReplayMenuType[client] + 1) % MAX_TYPES;
			OpenPlayReplayMenu(client);
		}
		else if(StrEqual(sInfo, "style"))
		{
			int totalStyles = GetTotalStyles();
			
			do
			{
				g_ReplayMenuStyle[client] = (g_ReplayMenuStyle[client] + 1) % totalStyles;
			}
			while(Style(g_ReplayMenuStyle[client]).Enabled == false ||
			Style(g_ReplayMenuStyle[client]).GetAllowType(g_ReplayMenuType[client]) == false ||
			Style(g_ReplayMenuStyle[client]).GetUseGhost(g_ReplayMenuType[client]) == false);
			OpenPlayReplayMenu(client);
		}
		else if(StrEqual(sInfo, "tas"))
		{
			g_ReplayMenuTAS[client] = !g_ReplayMenuTAS[client];
			OpenPlayReplayMenu(client);
		}
		else if(StrEqual(sInfo, "confirm"))
		{
			if(!g_ReplayBotIsReplaying || Timer_ClientHasTimerFlag(client, "replay", Admin_Generic) && g_bReplayLoaded[g_ReplayMenuType[client]][g_ReplayMenuStyle[client]][g_ReplayMenuTAS[client]])
			{
				StartReplay(client, g_ReplayMenuType[client], g_ReplayMenuStyle[client], g_ReplayMenuTAS[client]);
			}
			
		}
		/*else
		{
			if(!IsInQueue(param1))
			{
				AddToQueue(param1, Type, style, tas);
			}
			else
			{
				PrintColorText(param1, "%s%sYou already have a replay bot set to replay in the queue. (%s%d%s)",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					GetQueueIndex(param1) + 1,
					g_msg_textcol);
			}
		}*/
	}
	if(action & MenuAction_End)
	{
		delete menu;
	}
		
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			OpenAdminReplayMenu(client);
		}
	}
}

stock int GetQueueIndex(int client)
{
	int iSize  = GetArraySize(g_hReplayQueue);
	int userId = GetClientUserId(client);
	
	for(int idx; idx < iSize; idx++)
	{
		if(GetArrayCell(g_hReplayQueue, idx, 0) == userId)
			return idx;
	}
	
	return -1;
}

stock bool IsInQueue(int client)
{
	int iSize  = GetArraySize(g_hReplayQueue);
	int userId = GetClientUserId(client);
	
	for(int idx; idx < iSize; idx++)
	{
		if(GetArrayCell(g_hReplayQueue, idx, 0) == userId)
			return true;
	}
	
	return false;
}

stock void AddToQueue(int client, int type, int style, int tas)
{
	int data[4];
	data[0] = GetClientUserId(client);
	data[1] = type;
	data[2] = style;
	data[3] = tas;
	
	int idx = PushArrayArray(g_hReplayQueue, data, sizeof(data));
	
	PrintColorText(client, "%s%sAdded replay to queue. (%s%d%s)",
		g_msg_start,
		g_msg_textcol,
		g_msg_varcol,
		idx + 1,
		g_msg_textcol);
}

void StartReplay(int client, int Type, int style, int tas)
{
	g_ReplayCurrentFrame   = 0;
	g_ReplayMaxFrame       = GetArraySize(g_hReplayFrame[Type][style][tas]);
	g_ReplayBotTimerType   = Type;
	g_ReplayBotTimerStyle  = style;
	g_ReplayBotIsTas       = view_as<bool>(tas);
	g_ReplayBotIsReplaying = true;
	CS_SetClientClanTag(g_ReplayBot, g_ReplayBotTag[Type][style][tas]);
	
	char sType[32], sStyle[32], sTime[32], sResult[MAX_NAME_LENGTH];
	GetTypeName(Type, sType, sizeof(sType));
	Style(style).GetName(sStyle, sizeof(sStyle));
	FormatPlayerTime(g_ReplayBotTime[Type][style][tas], sTime, sizeof(sTime), 1);
	FormatEx(sResult, sizeof(sResult), "%s - %s%s - %s", sType, sStyle, tas?" (TAS)":"", sTime);
	SetClientName(g_ReplayBot, sResult);
	g_ReplayOwner = GetClientUserId(client);
	SetEntityMoveType(g_ReplayBot, MOVETYPE_NOCLIP);
}

void StopCurrentReplay()
{
	g_ReplayBotIsReplaying = false;
	
	if(g_ReplayBotTimerType == TIMER_MAIN)
		Timer_TeleportToZone(g_ReplayBot, MAIN_START, 0, true);
	else
		Timer_TeleportToZone(g_ReplayBot, BONUS_START, 0, true);
	
	g_ReplayBotTimerType   = -1;
	g_ReplayBotTimerStyle  = -1;
	g_ReplayMaxFrame       = 0;
	g_ReplayCurrentFrame   = 0;
	g_ReplayBotIsTas       = false;
	CS_SetClientClanTag(g_ReplayBot, "");
	SetClientName(g_ReplayBot, "!replay");
	SetEntityMoveType(g_ReplayBot, MOVETYPE_WALK);
}

/* Load the replay bot files */
void LoadReplays()
{
	char sPath[PLATFORM_MAX_PATH], sPathRec[PLATFORM_MAX_PATH];
	any data[6];
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			for(int tas; tas < 2; tas++)
			{
				if(Style(style).GetUseGhost(Type))
				{
					g_ReplayBotTime[Type][style][tas]  = 0.0;
					g_ReplayPlayerId[Type][style][tas] = 0;
					BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, style);
					BuildPath(Path_SM, sPathRec, sizeof(sPathRec), "data/btimes/%s_%d_%d_%d.rec", g_sMapName, Type, style, tas);
					if(FileExists(sPath))
					{
						RenameFile(sPathRec, sPath);
					}
					
					BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d_%d.txt", g_sMapName, Type, style, tas);
					if(FileExists(sPathRec) && !FileExists(sPath))
					{
						ConvertFile(sPathRec, sPath);
					}
					
					if(FileExists(sPath))
					{
						// Open file for reading
						File file = OpenFile(sPath, "rb");
						
						// Read first line for player and time information
						any header[2];
						file.Read(header, 2, 4);
						
						// Decode line into needed information
						g_ReplayPlayerId[Type][style][tas] = header[0];
						GetNameFromPlayerID(g_ReplayPlayerId[Type][style][tas], g_ReplayBotTag[Type][style][tas], sizeof(g_ReplayBotTag[][][]));
						
						g_ReplayBotTime[Type][style][tas] = header[1];
						
						// Read rest of file
						while(!file.EndOfFile())
						{
							file.Read(data, REPLAY_FRAME_SIZE, 4);
							g_hReplayFrame[Type][style][tas].PushArray(data, REPLAY_FRAME_SIZE);
						}
						delete file;
						
						g_bReplayLoaded[Type][style][tas] = true;
					}
				}
			}
		}
	}
}

void ConvertFile(const char[] sPath, const char[] newName)
{
	Timer_Log(false, "Converting replay file '%s' to '%s' using new format.", sPath, newName);
	// Open file for reading
	File file = OpenFile(sPath, "r");
	
	// Load all data into the ghost handle
	char sLine[512], sData[6][64], sMetaData[2][10];
	
	// Read first line for player and time information
	file.ReadLine(sLine, sizeof(sLine));
	
	ArrayList list = CreateArray(6);
	int playerId;
	float fTime;
	
	// Decode line into needed information
	ExplodeString(sLine, "|", sMetaData, sizeof(sMetaData), sizeof(sMetaData[]));
	playerId = StringToInt(sMetaData[0]);
	fTime = StringToFloat(sMetaData[1]);
	
	// Read rest of file
	any data[6];
	while(!file.EndOfFile())
	{
		file.ReadLine(sLine, sizeof(sLine));
		ExplodeString(sLine, "|", sData, sizeof(sData), sizeof(sData[]));
		
		data[0] = StringToFloat(sData[0]);
		data[1] = StringToFloat(sData[1]);
		data[2] = StringToFloat(sData[2]);
		data[3] = StringToFloat(sData[3]);
		data[4] = StringToFloat(sData[4]);
		data[5] = StringToInt(sData[5]);
		
		PushArrayArray(list, data);
	}
	delete file;
	
	file = OpenFile(newName, "wb");
	
	any header[2];
	header[0] = playerId;
	header[1] = fTime;
	file.Write(header, 2, 4);
	
	int writeDataSize = 128 * REPLAY_FRAME_SIZE;
	any[] writeData = new any[writeDataSize];
	int ticksWritten;
	any singleFrame[REPLAY_FRAME_SIZE];
	int iSize = list.Length;
	
	for(int idx; idx < iSize; idx++)
	{
		GetArrayArray(list, idx, singleFrame, REPLAY_FRAME_SIZE);
		for(int i; i < REPLAY_FRAME_SIZE; i++)
		{
			writeData[(ticksWritten * REPLAY_FRAME_SIZE) + i] = singleFrame[i];
		}
		ticksWritten++;
		
		if(ticksWritten == 128 || idx == iSize - 1)
		{
			WriteFile(file, writeData, ticksWritten * REPLAY_FRAME_SIZE, 4);
			ticksWritten = 0;
		}
	}
	delete file;
	delete list;
}

public void OnTimerFinished_Post(int client, float Time, int Type, int style, bool tas, bool NewTime, int OldPosition, int NewPosition)
{
	if(Style(style).GetSaveGhost(Type))
	{
		if(Time < g_ReplayBotTime[Type][style][tas] || g_ReplayBotTime[Type][style][tas] == 0.0 || NewPosition == 1)
		{
			SaveReplay(client, Time, Type, style, tas);
		}
	}
}

/* Save the replay of the specified player since they got the record */
void SaveReplay(int client, float time, int Type, int style, int tas)
{
	if(IsBotReplaying(Type, style, tas))
		StopCurrentReplay();
		
	g_ReplayBotTime[Type][style][tas] = time;
	
	g_ReplayPlayerId[Type][style][tas] = GetPlayerID(client);
	GetClientName(client, g_ReplayBotTag[Type][style][tas], sizeof(g_ReplayBotTag[][][]));
	
	// Delete existing ghost for the map
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d_%d.txt", g_sMapName, Type, style, tas);
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}
	
	// Open a file for writing
	File file = OpenFile(sPath, "wb");
	
	// save playerid to file to grab name and time for later times map is played
	any header[2];
	header[0] = GetPlayerID(client);
	header[1] = time;
	file.Write(header, 2, 4);
	
	ArrayList list;
	if(tas)
	{
		list = view_as<ArrayList>(CloneHandle(TAS_GetRunHandle(client)));
		
		if(GetConVarBool(g_cSmoothing) == true)
		{
			SmoothOutReplay(list);
		}
	}
	else
	{
		list = view_as<ArrayList>(CloneHandle(g_hPlayerFrame[client]));
	}
	
	int writeDataSize = 128 * REPLAY_FRAME_SIZE;
	any[] writeData = new any[writeDataSize];
	any singleFrame[REPLAY_FRAME_SIZE];
	int ticksWritten;
	int iSize = GetArraySize(list);
	ClearArray(g_hReplayFrame[Type][style][tas]);
	ResizeArray(g_hReplayFrame[Type][style][tas], iSize);
	
	for(int idx; idx < iSize; idx++)
	{
		for(int block; block < REPLAY_FRAME_SIZE; block++)
		{
			singleFrame[block] = GetArrayCell(list, idx, block);
			SetArrayCell(g_hReplayFrame[Type][style][tas], idx, singleFrame[block], block);
		}
		
		for(int i; i < REPLAY_FRAME_SIZE; i++)
		{
			writeData[(ticksWritten * REPLAY_FRAME_SIZE) + i] = singleFrame[i];
		}
		ticksWritten++;
		
		if(ticksWritten == 128 || idx == iSize - 1)
		{
			WriteFile(file, writeData, ticksWritten * REPLAY_FRAME_SIZE, 4);
			ticksWritten = 0;
		}
	}
	delete file;
	
	g_bReplayLoaded[Type][style][tas] = true;
}

#define TURN_LEFT 0
#define TURN_RIGHT 1

void SmoothOutReplay(ArrayList list)
{
	int iSize = list.Length;
	float fOldAngle[2], fTotalAngleDiff[2];
	int   lastTurnDir[2], lastUpdateIdx[2];
	
	fOldAngle[0] = view_as<float>(list.Get(0, 4));
	fOldAngle[1] = view_as<float>(list.Get(0, 5));
	for(int idx; idx < iSize; idx++)
	{
		float fAngle = view_as<float>(list.Get(idx, 5));
		float fAngleDiff = fAngle - fOldAngle[1];
		if (fAngleDiff > 180)
		{
			fAngleDiff -= 360;
		}
		else if(fAngleDiff < -180)
		{
			fAngleDiff += 360;
		}
		
		float fTempTotalAngleDiff = fTotalAngleDiff[1];
		bool bUpdateAngles;
		if(fAngleDiff > 0) // Turning left
		{
			if(lastTurnDir[1] == TURN_RIGHT)
			{
				fTotalAngleDiff[1] = 0.0;
				bUpdateAngles           = true; //Update if replay turns left
			}
			
			fTotalAngleDiff[1] += fAngleDiff;
			lastTurnDir[1]      = TURN_LEFT;
		}
		else if(fAngleDiff < 0) // Turning right
		{
			if(lastTurnDir[1] == TURN_LEFT)
			{
				fTotalAngleDiff[1] = 0.0;
				bUpdateAngles      = true; // Update if replay turns right
			}
			
			fTotalAngleDiff[1] += fAngleDiff;
			lastTurnDir[1]      = TURN_RIGHT;
		}
		
		// Update if the replay has turned too much
		if((FloatAbs(fTotalAngleDiff[1]) > 45.0)) 
		{
			bUpdateAngles = true;
		}
		
		// Update if person shoots
		if(idx > 0)
		{
			int curButtons = list.Get(idx, 5);
			int oldButtons = list.Get(idx - 1, 5);
			
			if(!(oldButtons & IN_ATTACK) && (curButtons & IN_ATTACK))
			{
				bUpdateAngles = true;
			}
			
		}
		
		// Smooth out angles
		if(bUpdateAngles == true)
		{
			int tickCount = idx - lastUpdateIdx[1];
			float fStartAngle = view_as<float>(list.Get(lastUpdateIdx[1], 4));
			for(int idx2 = lastUpdateIdx[1], idx3; idx2 < idx; idx2++, idx3++)
			{
				float fPercent = float(idx3) / float(tickCount);
				float fAngleToSet = fStartAngle + (fTempTotalAngleDiff * fPercent);
				if(fAngleToSet > 180)
					fAngleToSet -= 360;
				else if(fAngleToSet < -180)
					fAngleToSet += 360;
				
				list.Set(idx2, fAngleToSet, 5);
			}
		
			lastUpdateIdx[1] = idx;
		}
			
		fOldAngle[1] = fAngle;
	}
}

/* Delete replay of specified type/style */
void DeleteReplay(int Type, int style, int tas)
{
	if(IsBotReplaying(Type, style, tas))
	{
		StopCurrentReplay();
	}
		
	// Delete map ghost file
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d_%d.txt", g_sMapName, Type, style, tas);
	if(FileExists(sPath))
		DeleteFile(sPath);
	
	// Reset ghost settings
	g_hReplayFrame[Type][style][tas].Clear();
	g_ReplayBotTime[Type][style][tas] = 0.0;
	FormatEx(g_ReplayBotTag[Type][style][tas], sizeof(g_ReplayBotTag[][][]), "");
	g_ReplayPlayerId[Type][style][tas] = 0;
	g_bReplayLoaded[Type][style][tas] = false;
}

bool IsBotReplaying(int Type, int style, int tas)
{
	return (g_ReplayBotIsReplaying && g_ReplayBotTimerType == Type && g_ReplayBotTimerStyle == style && g_ReplayBotIsTas == view_as<bool>(tas));
}

public int Native_IsReplaying(Handle plugin, int numParams)
{
	return view_as<int>(g_ReplayBotIsReplaying);
}

public int Native_IsClientReplayBot(Handle plugin, int numParams)
{
	return view_as<int>(GetNativeCell(1) == g_ReplayBot);
}

public int Native_GetCurrentReplayType(Handle plugin, int numParams)
{
	return g_ReplayBotTimerType;
}

public int Native_GetCurrentReplayStyle(Handle plugin, int numParams)
{
	return g_ReplayBotTimerStyle;
}

public int Native_GetCurrentReplayTAS(Handle plugin, int numParams)
{
	return g_ReplayBotIsTas;
}

public int Native_GetPlayerName(Handle plugin, int numParams)
{
	SetNativeString(4, g_ReplayBotTag[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)], GetNativeCell(5));
}

public int Native_GetPlayerId(Handle plugin, int numParams)
{
	return g_ReplayPlayerId[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)];
}

public int Native_GetTime(Handle plugin, int numParams)
{
	return view_as<int>(g_ReplayBotTime[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)]);
}

public int Native_GetCurrentTimeInRun(Handle plugin, int numParams)
{
	if(g_ReplayBotIsReplaying == false)
	{
		return 0;
	}
	
	float fTime = g_ReplayBotTime[g_ReplayBotTimerType][g_ReplayBotTimerStyle][g_ReplayBotIsTas];
	int iSize = GetArraySize(g_hReplayFrame[g_ReplayBotTimerType][g_ReplayBotTimerStyle][g_ReplayBotIsTas]);
	
	return view_as<int>(fTime * (float(g_ReplayCurrentFrame) / float(iSize)));
}

public void OnButtonPressed(int client, int buttons)
{
	if(!IsPlayerAlive(client) && buttons & IN_USE)
	{
		int Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		int ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5) && Target == g_ReplayBot && !g_ReplayBotIsReplaying)
		{
			OpenPlayReplayMenu(client);
		}
	}
}


float g_fLastZVel;
int g_iReplayLastButtons;
int g_Bot_LastUsedFrame;
bool g_Bot_IsFrozen;
float g_Bot_FreezeTime;

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(client == g_ReplayBot)
	{
		for(int idx; idx < 3; idx++)
		{
			if (g_ExpectedValue[idx] > g_CurrentValue[idx])
			{
				if(g_CurrentValue[idx] + g_FadeSpeed > g_ExpectedValue[idx])
					g_CurrentValue[idx] = g_ExpectedValue[idx];
				else
					g_CurrentValue[idx] += g_FadeSpeed;
			}
			 
			if (g_ExpectedValue[idx] < g_CurrentValue[idx])
			{
				if(g_CurrentValue[idx] - g_FadeSpeed < g_ExpectedValue[idx])
					g_CurrentValue[idx] = g_ExpectedValue[idx];
				else
					g_CurrentValue[idx] -= g_FadeSpeed;
			}

			if (g_ExpectedValue[idx] == g_CurrentValue[idx])
			{
				g_ExpectedValue[idx] = GetRandomInt(0, 255);
			}
		}
		
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, g_CurrentValue[0], g_CurrentValue[1], g_CurrentValue[2], 255);
		
		if(g_ReplayBotIsReplaying == false)
		{
			buttons &= ~IN_ATTACK;
			buttons &= ~IN_ATTACK2;
			buttons &= ~IN_JUMP;
			
			vel[0] = 0.0;
			vel[1] = 0.0;
			
			TeleportEntity(client, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}), NULL_VECTOR);
		}
		else
		{
			int Type = g_ReplayBotTimerType, style = g_ReplayBotTimerStyle, tas = g_ReplayBotIsTas;
			
			if(g_ReplayCurrentFrame >= g_hReplayFrame[Type][style][tas].Length)
				StopCurrentReplay();
				
			any data[REPLAY_FRAME_SIZE];
			GetArrayArray(g_hReplayFrame[Type][style][tas], g_ReplayCurrentFrame, data, sizeof(data));
			
			float vPos[3];
			vPos[0] = view_as<float>(data[0]);
			vPos[1] = view_as<float>(data[1]);
			vPos[2] = view_as<float>(data[2]);
			
			float vAng[3];
			vAng[0] = view_as<float>(data[3]);
			vAng[1] = view_as<float>(data[4]);
			vAng[2] = 0.0;
			
			buttons = view_as<int>(data[5]);
			//buttons &= ~IN_DUCK;
			
			float vCurrentPos[3];
			Entity_GetAbsOrigin(client, vCurrentPos);
			
			// Get the new velocity from the the 2 points
			float vVel[3];
			MakeVectorFromPoints(vCurrentPos, vPos, vVel);
			ScaleVector(vVel, 1.0/GetTickInterval());
			
			if(g_ReplayCurrentFrame != g_Bot_LastUsedFrame)
			{
				if(GetVectorDistance(vCurrentPos, vPos) > 50)
				{
					TeleportEntity(client, vPos, vAng, NULL_VECTOR);
				}
				else
				{
					TeleportEntity(client, NULL_VECTOR, vAng, vVel);
				}
				
				g_Bot_LastUsedFrame = g_ReplayCurrentFrame;
			}
			else
			{
				TeleportEntity(client, NULL_VECTOR, vAng, NULL_VECTOR);
			}
			
			if(GetEntityFlags(client) & FL_ONGROUND && GetEntityMoveType(client) == MOVETYPE_NOCLIP)
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
			}
			else if(!(GetEntityFlags(client) & FL_ONGROUND) && GetEntityMoveType(client) == MOVETYPE_WALK)
			{
				SetEntityMoveType(client, MOVETYPE_NOCLIP);
			}
			
			// Handle bot freezing at start/end of run
			if(g_ReplayCurrentFrame == 0 || g_ReplayCurrentFrame == g_hReplayFrame[Type][style][tas].Length - 1)
			{
				if(g_Bot_IsFrozen == false) // Initialize bot freezing
				{
					SetEntityMoveType(client, MOVETYPE_NONE);
					SetEntityFlags(client, GetEntityFlags(client) | FL_FROZEN);
					g_Bot_FreezeTime = GetEngineTime();
					g_Bot_IsFrozen = true;
				}
				else if((GetEngineTime() - g_Bot_FreezeTime) > 0.5) // End bot freezing
				{
					SetEntityMoveType(client, MOVETYPE_WALK);
					SetEntityFlags(client, GetEntityFlags(client) & ~FL_FROZEN);
					g_ReplayCurrentFrame++;
					g_Bot_IsFrozen = false;
				}
			}
			else
			{
				g_ReplayCurrentFrame++;
			}
			
			/*
			int[] clients = new int[MaxClients + 1];
			int numClients;
			if(g_bPainterLoaded && vVel[2] > 0.0 && g_fLastZVel <= 0)
			{
				bool doPaint;
				for(int target = 1; target <= MaxClients; target++)
				{
					if(!IsClientInGame(target))
						continue;
						
					if(IsFakeClient(target))
						continue;
						
					if(IsPlayerAlive(target))
						continue;
						
					if(!Paint_Replay(target))
						continue;
						
					int ObserverTarget = GetEntPropEnt(target, Prop_Send, "m_hObserverTarget");
					int ObserverMode   = GetEntProp(target, Prop_Send, "m_iObserverMode");
					
					if((ObserverTarget == g_ReplayBot) && (ObserverMode == 4 || ObserverMode == 5 || ObserverMode == 6))
					{
						doPaint = true;
						clients[numClients++] = target;
						
						if(IsBlacky(target))
						{
							if(buttons & IN_DUCK != g_iReplayLastButtons & IN_DUCK)
							{
								PrintToChat(target, "Duck change");
							}
						}
					}
					else
					{
						continue;
					}
				}
				
				g_iReplayLastButtons = buttons;
				
				if(doPaint)
				{
					float fPos[3];
					Entity_GetAbsOrigin(g_ReplayBot, fPos);
					
					TR_TraceRayFilter(fPos, view_as<float>({90.0, 0.0, 0.0}), MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, g_ReplayBot);
					
					if(TR_DidHit())
					{
						float vEnd[3];
						TR_GetEndPosition(vEnd);
						TE_SetupBSPDecal(vEnd, 0, g_iDecal);
						TE_Send(clients, numClients);
					}
				}
			}
				
			g_fLastZVel = vVel[2];
			*/
			
			if(g_ReplayCurrentFrame >= g_ReplayMaxFrame)
				StopCurrentReplay();
		}
	}
	else
	{
		if(!IsPlayerAlive(client) && g_bIsReplayAdmin[client])
		{
			int ObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			int ObserverMode   = GetEntProp(client, Prop_Send, "m_iObserverMode");
			
			if((0 < ObserverTarget <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5) && ObserverTarget == g_ReplayBot && g_ReplayBotIsReplaying == true)
			{
				int frameSkips;
				if(g_bFastForward[client])
				{
					frameSkips += 100;
				}
				if(g_bRewind[client])
				{
					frameSkips -= 100;
				}
					
				int iSize = GetArraySize(g_hReplayFrame[g_ReplayBotTimerType][g_ReplayBotTimerStyle][g_ReplayBotIsTas]);
				
				if(iSize != 0 && frameSkips != 0)
				{
					g_ReplayCurrentFrame += frameSkips;
					
					if(g_ReplayCurrentFrame < 0)
					{
						g_ReplayCurrentFrame = iSize - 1;
					}
					else if(g_ReplayCurrentFrame >= iSize)
					{
						g_ReplayCurrentFrame = 0;
					}
				}
			}
		}
		else if(IsBeingTimed(client, TIMER_ANY) == true && TimerInfo(client).Paused == false)
		{
			bool bTas = g_bTasLoaded?TAS_InEditMode(client):false;
			
			if(bTas == false)
			{
				float vPos[3];
				Entity_GetAbsOrigin(client, vPos);
				
				float vAng[3];
				GetClientEyeAngles(client, vAng);
				
				any data[6];
				data[0] = vPos[0];
				data[1] = vPos[1];
				data[2] = vPos[2];
				data[3] = vAng[0];
				data[4] = vAng[1];
				data[5] = GetClientButtons(client);
				
				int iSize = GetArraySize(g_hPlayerFrame[client]);
				ResizeArray(g_hPlayerFrame[client], iSize + 1);
				for(int block; block < REPLAY_FRAME_SIZE; block++)
				{
					SetArrayCell(g_hPlayerFrame[client], iSize, data[block], block);
				}
			}
		}
		
		/*if(client == GetClientOfUserId(g_ReplayOwner))
		{
			if(GetClientObservee(client) == g_ReplayBot)
			{
				g_fReplayOwnerLastObserve = GetEngineTime();
			}
		}*/
	}
	
	return Plugin_Changed;
}

void TE_SetupBSPDecal(float vecOrigin[3], int entity, int index) 
{
	TE_Start("BSP Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nEntity", entity);
	TE_WriteNum("m_nIndex", index);
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

/*
public void OnGameFrame()
{
	if(g_ReplayBotIsReplaying)
	{
		if(GetEngineTime() - g_fReplayOwnerLastObserve > 5.0)
		{
			StopCurrentReplay();
		}
	}
	
}
*/

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "cs_gamerules"))
	{
		g_iGameRulesEnt = entity;
	}
	
	if(StrContains(classname, "trigger_") != -1)
	{
		SDKHook(entity, SDKHook_StartTouch, Hook_Touch);
		SDKHook(entity, SDKHook_EndTouch, Hook_Touch);
		SDKHook(entity, SDKHook_Touch, Hook_Touch);
	}
}

public Action Hook_Touch(int entity, int other)
{
	if(0 < other <= MaxClients && IsFakeClient(other))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	if (g_Engine == Engine_CSGO && GetEntProp(g_iGameRulesEnt, Prop_Send, "m_bWarmupPeriod"))
	{
		return Plugin_Continue;
	}
		
	if (reason == CSRoundEnd_GameStart)
	{
		return Plugin_Handled;
	}
		
	if(reason == CSRoundEnd_TerroristsSurrender)
	{
		return Plugin_Handled;
	}
	
	if(reason == CSRoundEnd_CTSurrender)
	{
		return Plugin_Handled;
	}
		
	return Plugin_Continue;
}