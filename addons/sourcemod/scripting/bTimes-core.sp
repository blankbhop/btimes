#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[Timer] - Core",
	author = "blacky",
	description = "The root of bTimes",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <sdktools>
#include <smlib/clients>
#include <csgocolors>

#undef REQUIRE_PLUGIN
#include <scp>
#include <chat-processor>
#include <adminmenu>

#pragma newdecls required

EngineVersion g_Engine;

ArrayList g_hCommandList;
bool g_bCommandListLoaded;

Database g_DB;

char      g_sMapName[PLATFORM_MAX_PATH];
int       g_PlayerID[MAXPLAYERS+1];
ArrayList    g_MapList;
int       g_LastMapListSize;
//ArrayList g_hDbMapNameList;
//ArrayList g_hDbMapIdList;
//bool      g_bDbMapsLoaded;
	
float g_fSpamTime[MAXPLAYERS + 1];

// Forwards
Handle g_fwdMapIDPostCheck;
//Handle g_fwdMapListLoaded;
Handle g_fwdPlayerIDLoaded;
Handle g_fwdOnPlayerIDListLoaded;
Handle g_fwdChatChanged;

// PlayerID retrieval data
ArrayList g_hPlayerID;
ArrayList g_hUser;
bool      g_bPlayerListLoaded;

// Cvars
ConVar g_hChangeLogURL;
ConVar g_CSGOMOTDUrl;

// Timer admin config
Handle g_hAdminKv;
Handle g_hAdminMenu;
TopMenuObject g_TimerAdminCategory;

// Message color stuff
ConVar g_MessageStart;
ConVar g_MessageVar;
ConVar g_MessageText;

public void OnPluginStart()
{
	CreateConVar("timer_debug", "1", "Logs debug messages");
	g_hChangeLogURL = CreateConVar("timer_changelogurl", "http://www.kawaiiclan.com/changelog.html", "Changelog URL");
	
	// Database
	DB_Connect();
	
	if(g_Engine == Engine_CSS)
    {
        g_MessageStart     = CreateConVar("timer_msgstart", "^556b2f[Timer] ^daa520- ", "Sets the start of all timer messages.");
        g_MessageVar       = CreateConVar("timer_msgvar", "^B4D398", "Sets the color of variables in timer messages such as player names.");
        g_MessageText      = CreateConVar("timer_msgtext", "^DAA520", "Sets the color of general text in timer messages.");
    }
	else if(g_Engine == Engine_CSGO)
	{
		g_MessageStart     = CreateConVar("timer_msgstart", "{lightblue}[{blue}Timer{lightblue}] {purple}- ", "Sets the start of all timer messages.");
		g_MessageVar       = CreateConVar("timer_msgvar", "{blue}", "Sets the color of variables in timer messages such as player names.");
		g_MessageText      = CreateConVar("timer_msgtext", "{lightblue}", "Sets the color of general text in timer messages.");
		g_CSGOMOTDUrl      = CreateConVar("timer_csgomotdurl", "http://kawaiiclan.com/motdurl.php?url=", "URL for opening other URLs to players.");
	}
	
	// Hook specific convars
	HookConVarChange(g_MessageStart, OnMessageStartChanged);
	HookConVarChange(g_MessageVar,   OnMessageVarChanged);
	HookConVarChange(g_MessageText,  OnMessageTextChanged);
	
	AutoExecConfig(true, "core", "timer");
	
	// Events
	HookEvent("player_changename", Event_PlayerChangeName, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	// Commands
	RegConsoleCmdEx("sm_thelp", SM_THelp, "Shows the timer commands.");
	RegConsoleCmdEx("sm_commands", SM_THelp, "Shows the timer commands.");
	RegConsoleCmdEx("sm_search", SM_Search, "Search the command list for the given string of text.");
	RegConsoleCmdEx("sm_changes", SM_Changes, "Show the timer changelog.");
	
	// Translations
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	
	// Timer admin
	if(!LoadTimerAdminConfig())
	{
		SetFailState("Missing or failed to load configs/timer/timeradmin.txt file.");
	}
	
	RegConsoleCmd("sm_reloadtimeradmin", SM_ReloadTimerAdmin, "Reloads the timer admin configuration.");
	
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	
	CheckForMapCycleCRC();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_Engine = GetEngineVersion();
	if(g_Engine != Engine_CSS && g_Engine != Engine_CSGO)
	{
		FormatEx(error, err_max, "Game not supported");
		return APLRes_Failure;
	}
	
	// Natives
	CreateNative("GetClientID", Native_GetClientID);
	CreateNative("IsSpamming", Native_IsSpamming);
	CreateNative("SetIsSpamming", Native_SetIsSpamming);
	CreateNative("RegisterCommand", Native_RegisterCommand);
	CreateNative("GetNameFromPlayerID", Native_GetNameFromPlayerID);
	CreateNative("GetSteamIDFromPlayerID", Native_GetSteamIDFromPlayerID);
	CreateNative("IsPlayerIDListLoaded", Native_IsPlayerIDListLoaded);
	CreateNative("Timer_GetAdminFlag", Native_GetAdminFlag);
	CreateNative("Timer_ClientHasTimerFlag", Native_ClientHasTimerFlag);
	CreateNative("Timer_IsMapInMapCycle", Native_IsMapInMapCycle);
	CreateNative("Timer_GetMapCycleSize", Native_GetMapCycleSize);
	CreateNative("Timer_GetMapCycle", Native_GetMapCycle);
	
	// Forwards
	g_fwdMapIDPostCheck       = CreateGlobalForward("OnMapIDPostCheck", ET_Event);
	g_fwdPlayerIDLoaded       = CreateGlobalForward("OnPlayerIDLoaded", ET_Event, Param_Cell);
	g_fwdOnPlayerIDListLoaded = CreateGlobalForward("OnPlayerIDListLoaded", ET_Event);
	g_fwdChatChanged          = CreateGlobalForward("OnTimerChatChanged", ET_Event, Param_Cell, Param_String);
	
	return APLRes_Success;
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "adminmenu"))
	{
		g_hAdminMenu = INVALID_HANDLE;
	}
}

public void OnAdminMenuReady(Handle topmenu)
{
	if(g_TimerAdminCategory == INVALID_TOPMENUOBJECT)
	{
		OnAdminMenuCreated(topmenu);
	}
 
	if (topmenu == g_hAdminMenu)
	{
		return;
	}
 
	g_hAdminMenu = topmenu;
	
	// Add items
	AttachAdminMenu();
}

public void OnAdminMenuCreated(Handle topmenu)
{
	if (topmenu == g_hAdminMenu && g_TimerAdminCategory != INVALID_TOPMENUOBJECT)
	{
		return;
	}
 
	AdminFlag MenuFlag;
	Timer_GetAdminFlag("adminmenu", MenuFlag);
	g_TimerAdminCategory = AddToTopMenu(topmenu, "TimerCommands", TopMenuObject_Category, TimerAdminCategoryHandler, INVALID_TOPMENUOBJECT, _, FlagToBit(MenuFlag));
}

public void TimerAdminCategoryHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayTitle || action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Timer Commands");
	}
}

void AttachAdminMenu()
{
	TopMenuObject TimerCommands = FindTopMenuCategory(g_hAdminMenu, "TimerCommands");
 
	if (TimerCommands == INVALID_TOPMENUOBJECT)
	{
		return;
	}
 
	AdminFlag SpecificFlag = Admin_Custom5;
	Timer_GetAdminFlag("zones", SpecificFlag);
	
	// Add zones item
	if(LibraryExists("timer-zones"))
	{
		AddToTopMenu(g_hAdminMenu, "sm_zones", TopMenuObject_Item, AdminMenu_Zones, TimerCommands, _, FlagToBit(SpecificFlag));
	}
	
	// Add buttons item
	if(LibraryExists("timer-buttons"))
	{
		AddToTopMenu(g_hAdminMenu, "sm_buttons", TopMenuObject_Item, AdminMenu_Buttons, TimerCommands, _, FlagToBit(SpecificFlag));
	}
	
	Timer_GetAdminFlag("basic", SpecificFlag);
	
	// Add move item
	if(LibraryExists("timer-random"))
	{
		AddToTopMenu(g_hAdminMenu, "sm_move", TopMenuObject_Item, AdminMenu_Move, TimerCommands, _, FlagToBit(SpecificFlag));
	}
	
	
	SpecificFlag = Admin_Config;
	Timer_GetAdminFlag("delete", SpecificFlag);
	AddToTopMenu(g_hAdminMenu, "sm_delete", TopMenuObject_Item, AdminMenu_Delete, TimerCommands, _, FlagToBit(SpecificFlag));
}
 
public int AdminMenu_Zones(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Zones menu");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		FakeClientCommand(param, "sm_zones");
	}
}

public void AdminMenu_Buttons(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Buttons menu");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		FakeClientCommand(param, "sm_buttons");
	}
}

public void AdminMenu_Move(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Move menu");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		FakeClientCommand(param, "sm_move");
	}
}

public int AdminMenu_Delete(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Delete times menu");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		FakeClientCommand(param, "sm_delete");
	}
}

public void OnMapStart()
{
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	Timer_Log(true, "Map start: %s", g_sMapName);
	
	if(g_MapList != INVALID_HANDLE)
	{
		CloseHandle(g_MapList);
	}
	
	g_MapList = view_as<ArrayList>(ReadMapList());
	
	// Creates map if it doesn't exist, sets map as recently played, and loads map playtime
	CreateCurrentMapID();
}

public void OnMapEnd()
{
	Timer_Log(true, "Map end: %s", g_sMapName);
}

public void OnMessageStartChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetConVarString(g_MessageStart, g_msg_start, sizeof(g_msg_start));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(0);
	Call_PushString(g_msg_start);
	Call_Finish();
	ReplaceString(g_msg_start, sizeof(g_msg_start), "^", "\x07", false);
}

public void OnMessageVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetConVarString(g_MessageVar, g_msg_varcol, sizeof(g_msg_varcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(1);
	Call_PushString(g_msg_varcol);
	Call_Finish();
	ReplaceString(g_msg_varcol, sizeof(g_msg_varcol), "^", "\x07", false);
}

public void OnMessageTextChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetConVarString(g_MessageText, g_msg_textcol, sizeof(g_msg_textcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(2);
	Call_PushString(g_msg_textcol);
	Call_Finish();
	ReplaceString(g_msg_textcol, sizeof(g_msg_textcol), "^", "\x07", false);
}

public void OnConfigsExecuted()
{
	// load timer message colors
	GetConVarString(g_MessageStart, g_msg_start, sizeof(g_msg_start));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(0);
	Call_PushString(g_msg_start);
	Call_Finish();
	
	GetConVarString(g_MessageVar, g_msg_varcol, sizeof(g_msg_varcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(1);
	Call_PushString(g_msg_varcol);
	Call_Finish();
	
	GetConVarString(g_MessageText, g_msg_textcol, sizeof(g_msg_textcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(2);
	Call_PushString(g_msg_textcol);
	Call_Finish();
}

public void OnClientDisconnect(int client)
{
	// Reset the playerid for the client index
	g_PlayerID[client] = 0;
}

public void OnClientAuthorized(int client)
{
	if(!IsFakeClient(client) && g_bPlayerListLoaded == true)
	{
		CreatePlayerID(client);
	}
}

public Action Event_PlayerTeam_Post(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(0 < client <= MaxClients)
	{
		if(IsClientInGame(client))
		{
			if(GetEventInt(event, "oldteam") == 0)
			{	
				PrintColorText(client, "%s%sTimer created by %sblacky%s. Type %s!thelp%s for a command list and %s!changes%s to see the latest changes!",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					g_msg_textcol,
					g_msg_varcol,
					g_msg_textcol,
					g_msg_varcol,
					g_msg_textcol);
			}
		}
	}
}

public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message)
{
	if(IsChatTrigger())
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	if(IsChatTrigger())
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action SM_ReloadTimerAdmin(int client, int args)
{
	AdminFlag flag = Admin_Config;
	Timer_GetAdminFlag("reload", flag);
	
	if(client != 0 && !GetAdminFlag(GetUserAdmin(client), flag))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if(LoadTimerAdminConfig())
	{
		PrintColorText(client, "%s%sReloaded the timer admin configuration.",
			g_msg_start,
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%sFailed to reload the timer admin configuration.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action Event_PlayerChangeName(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsFakeClient(client) && g_PlayerID[client] != 0)
	{
		char sNewName[MAX_NAME_LENGTH];
		GetEventString(event, "newname", sNewName, sizeof(sNewName));
		UpdateName(client, sNewName);
	}
}

public Action SM_Changes(int client, int args)
{
	char sChangeLog[PLATFORM_MAX_PATH];
	GetConVarString(g_hChangeLogURL, sChangeLog, PLATFORM_MAX_PATH);
	
	OpenMOTD(client, sChangeLog);
	
	return Plugin_Handled;
}

char g_sURL[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

stock void OpenMOTD(int client, char[] url) 
{
	ShowMOTDPanel(client, "Open HTML MOTD", url, MOTDPANEL_TYPE_URL);
	
	if(GetEngineVersion() == Engine_CSGO)
	{
		char sMOTDUrl[PLATFORM_MAX_PATH];
		g_CSGOMOTDUrl.GetString(sMOTDUrl, PLATFORM_MAX_PATH);
		FormatEx(g_sURL[client], PLATFORM_MAX_PATH, "%s%s", sMOTDUrl, url);
		CreateTimer(0.5, Timer_OpenURL, GetClientUserId(client));
	}
}

public Action Timer_OpenURL(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client != 0)
	{
		ShowMOTDPanel(client, "", g_sURL[client], MOTDPANEL_TYPE_URL ); 
	}
}

bool LoadTimerAdminConfig()
{
	if(g_hAdminKv != INVALID_HANDLE)
	{
		delete g_hAdminKv;
		g_hAdminKv = INVALID_HANDLE;
	}
	
	g_hAdminKv = CreateKeyValues("Timer Admin");
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/timer/timeradmin.txt");
	
	return FileToKeyValues(g_hAdminKv, sPath);
}

void DB_Connect()
{	
	if(g_DB != INVALID_HANDLE)
	{
		CloseHandle(g_DB);
	}
	
	char error[255];
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	
	if(g_DB == INVALID_HANDLE)
	{
		LogError(error);
		CloseHandle(g_DB);
	}
	else
	{
		LoadPlayers();
		//LoadDatabaseMapList();
	}
}

public void DB_Connect_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

/*
void LoadDatabaseMapList()
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT MapID, MapName FROM maps WHERE InMapCycle = 1");
	SQL_TQuery(g_DB, LoadDatabaseMapList_Callback, sQuery);
}

public void LoadDatabaseMapList_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(g_bDbMapsLoaded == false)
		{
			g_hDbMapNameList = CreateArray(ByteCountToCells(64));
			g_hDbMapIdList   = CreateArray();
			g_bDbMapsLoaded  = true;
		}
		
		char sMapName[64];
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 1, sMapName, sizeof(sMapName));
			
			PushArrayString(g_hDbMapNameList, sMapName);
			PushArrayCell(g_hDbMapIdList, SQL_FetchInt(hndl, 0));
		}
		
		Call_StartForward(g_fwdMapListLoaded);
		Call_Finish();
	}
	else
	{
		LogError(error);
	}
}
*/

void LoadPlayers()
{
	g_hPlayerID = CreateArray(ByteCountToCells(32));
	g_hUser     = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
	
	Timer_Log(true, "SQL Query Start: (Function = LoadPlayers, Time = %d)", GetTime());
	char query[128];
	FormatEx(query, sizeof(query), "SELECT SteamID, PlayerID, User FROM players");
	SQL_TQuery(g_DB, LoadPlayers_Callback, query);
}

public void LoadPlayers_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl != INVALID_HANDLE)
	{
		Timer_Log(true, "SQL Query Finish: (Function = LoadPlayers, Time = %d)", GetTime());
		char sName[32], sAuth[32];
		
		int rowCount = SQL_GetRowCount(hndl), playerId, iSize;
		for(int row; row < rowCount; row++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sAuth, sizeof(sAuth));
			playerId = SQL_FetchInt(hndl, 1);
			SQL_FetchString(hndl, 2, sName, sizeof(sName));
			
			iSize = GetArraySize(g_hPlayerID);
			
			if(playerId >= iSize)
			{
				ResizeArray(g_hPlayerID, playerId + 1);
				ResizeArray(g_hUser, playerId + 1);
			}
			
			SetArrayString(g_hPlayerID, playerId, sAuth);
			SetArrayString(g_hUser, playerId, sName);
		}
		
		g_bPlayerListLoaded = true;
		
		Call_StartForward(g_fwdOnPlayerIDListLoaded);
		Call_Finish();
		
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientConnected(client) && !IsFakeClient(client) && IsClientAuthorized(client))
			{
				CreatePlayerID(client);
			}
		}
	}
	else
	{
		LogError(error);
	}
}

void CreateCurrentMapID()
{
	DataPack pack = new DataPack();
	pack.WriteString(g_sMapName);
		
	Timer_Log(true, "SQL Query Start: (Function = CreateCurrentMapID, Time = %d)", GetTime());
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO maps (MapName) SELECT * FROM (SELECT '%s') AS tmp WHERE NOT EXISTS (SELECT MapName FROM maps WHERE MapName = '%s') LIMIT 1",
		g_sMapName,
		g_sMapName);
	SQL_TQuery(g_DB, DB_CreateCurrentMapID_Callback, sQuery, pack);
}

public void DB_CreateCurrentMapID_Callback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if(hndl != INVALID_HANDLE)
	{
		Timer_Log(true, "SQL Query Finish: (Function = CreateCurrentMapID, Time = %d)", GetTime());
		bool bUpdateDbMapCycle;
		if(SQL_GetAffectedRows(hndl) > 0)
		{
			data.Reset();
			
			char sMapName[PLATFORM_MAX_PATH];
			data.ReadString(sMapName, sizeof(sMapName));
			
			int mapId = SQL_GetInsertId(hndl);
			LogMessage("MapID for %s created (%d)", sMapName, mapId);
			
			bUpdateDbMapCycle = true;
		}
		
		int currentChecksum = CRC32(g_MapList);
		int oldChecksum;
		
		if(GetLastCRC(oldChecksum) && currentChecksum != oldChecksum)
		{
			UpdateMapCycleCRCFile(currentChecksum);
			bUpdateDbMapCycle = true;
		}
		
		if(bUpdateDbMapCycle == true)
		{
			UpdateDatabaseMapCycle();
		}
		
		Call_StartForward(g_fwdMapIDPostCheck);
		Call_Finish();
	}
	else
	{
		LogError(error);
	}
	
	delete data;
}

int CRC32(ArrayList data)
{
	int iSize = data.Length;
	int iLookup;
	int iChecksum = 0xFFFFFFFF;
	char sData[PLATFORM_MAX_PATH];
	
	for(int idx; idx < iSize; idx++)
	{
		data.GetString(idx, sData, PLATFORM_MAX_PATH);
		int length = strlen(sData);
		for(int x; x < length; x++)
		{
			iLookup   = (iChecksum ^ sData[x]) & 0xFF;
			iChecksum = (iChecksum << 8) ^ g_CRCTable[iLookup];
		}
	}
	
	iChecksum ^= 0xFFFFFFFF;
	
	return iChecksum;
}

bool GetLastCRC(int &crc)
{
	char sDir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sDir, PLATFORM_MAX_PATH, "data/btimes/crc.txt");
	File hFile = OpenFile(sDir, "rb");
	
	if(hFile == null)
	{
		LogError("GetLastCRC: Failed to open '%s', needed to check the if the mapcycle changed.", sDir);
		return false;
	}
	
	int previousChecksum[1];
	ReadFile(hFile, previousChecksum, 1, 4);
	delete hFile;
	
	return true;
}

bool UpdateMapCycleCRCFile(int checksum)
{
	char sDir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sDir, PLATFORM_MAX_PATH, "data/btimes/crc.txt");
	File hFile = OpenFile(sDir, "wb");
	
	if(hFile == null)
	{
		LogError("UpdateMapCycleCRCFile: Failed to open '%s', needed to check the if the mapcycle changed.", sDir);
		return false;
	}
	
	int data[1];
	data[0] = checksum;
	WriteFile(hFile, data, 1, 4);
	delete hFile;
	
	return true;
}

// Check if the CRC32 checksum of the mapcycle exists
void CheckForMapCycleCRC()
{
	char sDir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sDir, PLATFORM_MAX_PATH, "data/btimes/crc.txt");
	
	if(FileExists(sDir) == false)
	{
		UpdateMapCycleCRCFile(0);
	}
}

void UpdateDatabaseMapCycle()
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "SELECT MapName, InMapCycle FROM maps ORDER BY MapName");
	SQL_TQuery(g_DB, DB_GetMapList, sQuery);
}

public void DB_GetMapList(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl != INVALID_HANDLE)
	{
		bool bIsInMapCycleDb;
		bool bIsInMapCycleFile;
		char sMapInDb[PLATFORM_MAX_PATH];
		
		Transaction t = new Transaction();
		char sQuery[1024];
		int txCount;
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sMapInDb, PLATFORM_MAX_PATH);
			bIsInMapCycleDb = view_as<bool>(SQL_FetchInt(hndl, 1));
			bIsInMapCycleFile = g_MapList.FindString(sMapInDb) != -1;
			
			if(bIsInMapCycleDb != bIsInMapCycleFile)
			{
				FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET InMapCycle=%d WHERE MapName='%s'", bIsInMapCycleFile, sMapInDb);
				t.AddQuery(sQuery);
				txCount++;
			}
		}
		
		if(txCount > 0)
		{
			SQL_ExecuteTransaction(g_DB, t, DB_UpdateMapCycle_Success, DB_UpdateMapCycle_Failure, txCount);
		}
	}
	else
	{
		LogError(error);
	}
}

public void DB_UpdateMapCycle_Success(Database db, any data, int numQueries, Handle[] results, any[] queryData)
{
	LogMessage("Database map cycle updated (%d change%s found).", data, (data == 1)?"":"s");
}

public void DB_UpdateMapCycle_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError(error);
}

void CreatePlayerID(int client)
{	
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	
	char sAuth[32];
	GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth), true);
	
	int idx = FindStringInArray(g_hPlayerID, sAuth);
	if(idx != -1)
	{
		g_PlayerID[client] = idx;
		
		char sOldName[MAX_NAME_LENGTH];
		GetArrayString(g_hUser, idx, sOldName, sizeof(sOldName));
		
		if(!StrEqual(sName, sOldName))
		{
			UpdateName(client, sName);
		}
		
		Call_StartForward(g_fwdPlayerIDLoaded);
		Call_PushCell(client);
		Call_Finish();
	}
	else
	{
		char sEscapeName[(2 * MAX_NAME_LENGTH) + 1];
		SQL_LockDatabase(g_DB);
		SQL_EscapeString(g_DB, sName, sEscapeName, sizeof(sEscapeName));
		SQL_UnlockDatabase(g_DB);
		
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(sAuth);
		pack.WriteString(sName);
		
		Timer_Log(true, "SQL Query Start: (Function = CreatePlayerID, Time = %d)", GetTime());
		char sQuery[128];
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO players (SteamID, User) VALUES ('%s', '%s')",
			sAuth,
			sEscapeName);
		SQL_TQuery(g_DB, CreatePlayerID_Callback, sQuery, pack);
	}
}

public void CreatePlayerID_Callback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if(hndl != INVALID_HANDLE)
	{
		Timer_Log(true, "SQL Query Finish: (Function = CreatePlayerID, Time = %d)", GetTime());
		data.Reset();
		int client = GetClientOfUserId(data.ReadCell());
		
		char sAuth[32];
		data.ReadString(sAuth, sizeof(sAuth));
		
		char sName[MAX_NAME_LENGTH];
		data.ReadString(sName, sizeof(sName));
		
		int PlayerID = SQL_GetInsertId(hndl);
		
		int iSize = GetArraySize(g_hPlayerID);
		
		if(PlayerID >= iSize)
		{
			ResizeArray(g_hPlayerID, PlayerID + 1);
			ResizeArray(g_hUser, PlayerID + 1);
		}
		
		SetArrayString(g_hPlayerID, PlayerID, sAuth);
		SetArrayString(g_hUser, PlayerID, sName);
		
		if(client != 0)
		{
			g_PlayerID[client] = PlayerID;
			
			Call_StartForward(g_fwdPlayerIDLoaded);
			Call_PushCell(client);
			Call_Finish();
		}
	}
	else
	{
		LogError(error);
	}
}

void UpdateName(int client, const char[] sName)
{
	SetArrayString(g_hUser, g_PlayerID[client], sName);
	
	char[] sEscapeName = new char[(2 * MAX_NAME_LENGTH) + 1];
	SQL_LockDatabase(g_DB);
	SQL_EscapeString(g_DB, sName, sEscapeName, (2 * MAX_NAME_LENGTH) + 1);
	SQL_UnlockDatabase(g_DB);
	
	char sQuery[128];
	Timer_Log(true, "SQL Query Start: (Function = UpdateName, Time = %d)", GetTime());
	FormatEx(sQuery, sizeof(sQuery), "UPDATE players SET User='%s' WHERE PlayerID=%d",
		sEscapeName,
		g_PlayerID[client]);
	SQL_TQuery(g_DB, UpdateName_Callback, sQuery);
}

public void UpdateName_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		Timer_Log(true, "SQL Query Finish: (Function = UpdateName, Time = %d)", GetTime());
		LogError(error);
	}
}

public int Native_GetClientID(Handle plugin, int numParams)
{
	return g_PlayerID[GetNativeCell(1)];
}

public Action SM_THelp(int client, int args)
{	
	int iSize = GetArraySize(g_hCommandList);
	char sResult[256];
	
	if(0 < client <= MaxClients)
	{
		if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
		{
			ReplyToCommand(client, "[SM] Look in your console for timer command list.");
		}
		
		char sCommand[32];
		GetCmdArg(0, sCommand, sizeof(sCommand));
		
		if(args == 0)
		{
			ReplyToCommand(client, "[SM] %s 10 for the next page.", sCommand);
			for(int idx; idx < 10 && idx < iSize; idx++)
			{
				GetArrayString(g_hCommandList, idx, sResult, sizeof(sResult));
				PrintToConsole(client, sResult);
			}
		}
		else
		{
			char sArg[256];
			GetCmdArgString(sArg, sizeof(sArg));
			int iStart = StringToInt(sArg);
			
			if(iStart < (iSize-10))
			{
				ReplyToCommand(client, "[SM] %s %d for the next page.", sCommand, iStart + 10);
			}
			
			for(int idx = iStart; idx < (iStart + 10) && (idx < iSize); idx++)
			{
				GetArrayString(g_hCommandList, idx, sResult, sizeof(sResult));
				PrintToConsole(client, sResult);
			}
		}
	}
	else if(client == 0)
	{
		for(int idx; idx < iSize; idx++)
		{
			GetArrayString(g_hCommandList, idx, sResult, sizeof(sResult));
			PrintToServer(sResult);
		}
	}
	
	return Plugin_Handled;
}

public Action SM_Search(int client, int args)
{
	if(args > 0)
	{
		char sArgString[255], sResult[256];
		GetCmdArgString(sArgString, sizeof(sArgString));
		
		int iSize = GetArraySize(g_hCommandList);
		for(int idx; idx < iSize; idx++)
		{
			GetArrayString(g_hCommandList, idx, sResult, sizeof(sResult));
			if(StrContains(sResult, sArgString, false) != -1)
			{
				PrintToConsole(client, sResult);
			}
		}
	}
	else
	{
		PrintColorText(client, "%s%ssm_search must have a string to search with after it.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public int Native_IsSpamming(Handle plugin, int numParams)
{
	return GetEngineTime() < g_fSpamTime[GetNativeCell(1)];
}

public int Native_SetIsSpamming(Handle plugin, int numParams)
{
	g_fSpamTime[GetNativeCell(1)] = view_as<float>(GetNativeCell(2) + GetEngineTime());
}

public int Native_RegisterCommand(Handle plugin, int numParams)
{
	if(g_bCommandListLoaded == false)
	{
		g_hCommandList = CreateArray(ByteCountToCells(256));
		g_bCommandListLoaded = true;
	}
	
	char sListing[256], sCommand[32], sDesc[224];
	
	GetNativeString(1, sCommand, sizeof(sCommand));
	GetNativeString(2, sDesc, sizeof(sDesc));
	
	FormatEx(sListing, sizeof(sListing), "%s - %s", sCommand, sDesc);
	
	char sIndex[256];
	int idx, idxlen, listlen = strlen(sListing), iSize = GetArraySize(g_hCommandList);
	bool idxFound;
	for(; idx < iSize; idx++)
	{
		GetArrayString(g_hCommandList, idx, sIndex, sizeof(sIndex));
		idxlen = strlen(sIndex);
		
		for(int cmpIdx = 0; cmpIdx < listlen && cmpIdx < idxlen; cmpIdx++)
		{
			if(sListing[cmpIdx] < sIndex[cmpIdx])
			{
				idxFound = true;
				break;
			}
			else if(sListing[cmpIdx] > sIndex[cmpIdx])
			{
				break;
			}
		}
		
		if(idxFound == true)
			break;
	}
	
	if(idx >= iSize)
	{
		ResizeArray(g_hCommandList, idx + 1);
	}
	else
	{
		ShiftArrayUp(g_hCommandList, idx);
	}
	
	SetArrayString(g_hCommandList, idx, sListing);
}

/*
public int Native_GetMapNameFromMapId(Handle plugin, int numParams)
{
	int Index = FindValueInArray(g_hDbMapIdList, GetNativeCell(1));
	
	if(Index != -1)
	{
		char sMapName[64];
		GetArrayString(g_hDbMapNameList, Index, sMapName, sizeof(sMapName));
		SetNativeString(2, sMapName, GetNativeCell(3));
		
		return true;
	}
	else
	{
		return false;
	}
}
*/

public int Native_GetNameFromPlayerID(Handle plugin, int numParams)
{
	char sName[MAX_NAME_LENGTH];
	int idx = GetNativeCell(1);
	int iSize = GetArraySize(g_hUser);
	
	if(idx < 0 || idx >= iSize)
	{
		FormatEx(sName, sizeof(sName), "INVALID %d/%d", idx, iSize);
	}
	else
	{
		GetArrayString(g_hUser, idx, sName, sizeof(sName));
	
	}
	
	SetNativeString(2, sName, GetNativeCell(3));
}

public int Native_GetSteamIDFromPlayerID(Handle plugin, int numParams)
{
	char sAuth[32];
	
	GetArrayString(g_hPlayerID, GetNativeCell(1), sAuth, sizeof(sAuth));
	
	SetNativeString(2, sAuth, GetNativeCell(3));
}

public int Native_IsPlayerIDListLoaded(Handle plugin, int numParams)
{
	return g_bPlayerListLoaded;
}

public int Native_GetAdminFlag(Handle plugin, int numParams)
{
	// Retreive input from the first parameter
	char sTimerFlag[32];
	GetNativeString(1, sTimerFlag, sizeof(sTimerFlag));
	
	// Get the key value from the timeradmin.txt file
	char sFlag[16];
	if(!KvGetString(g_hAdminKv, sTimerFlag, sFlag, sizeof(sFlag)))
		return false;
	
	// Find the first char in the input
	int idx;
	for(; idx < sizeof(sFlag); idx++)
		if(IsCharAlpha(sFlag[idx]))
			break;
	
	// See if the char represents an admin flag
	AdminFlag flag;
	bool success = FindFlagByChar(sFlag[idx], flag);
	
	// Set param 2 to that flag
	SetNativeCellRef(2, flag);
	
	return success;
}

public int Native_ClientHasTimerFlag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char sTimerFlag[32];
	GetNativeString(2, sTimerFlag, sizeof(sTimerFlag));
	AdminFlag defaultFlag = GetNativeCell(3);
	
	Timer_GetAdminFlag(sTimerFlag, defaultFlag);
	
	return GetAdminFlag(GetUserAdmin(client), defaultFlag);
}

public int Native_IsMapInMapCycle(Handle plugin, int numParams)
{
	char sMap[PLATFORM_MAX_PATH];
	GetNativeString(1, sMap, sizeof(sMap));
	
	return FindStringInArray(g_MapList, sMap) != -1;
}

public int Native_GetMapCycleSize(Handle plugin, int numParams)
{
	return GetArraySize(g_MapList);
}

public int Native_GetMapCycle(Handle plugin, int numParams)
{
	return view_as<int>(CloneHandle(g_MapList));
}