#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <bTimes-core>
#include <bTimes-timer>
#include <bTimes-zones>
#include <bTimes-rank2>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <bTimes-tas>
#include <smartmsg>

#pragma newdecls required

Database g_DB;
EngineVersion g_Engine;

ArrayList g_hOverallRanks;
ArrayList g_hStyleRanks[MAX_TYPES][MAX_STYLES];
ArrayList g_hOverallWRRank;
ArrayList g_hStyleWRRank;
ArrayList g_hMaps;
ArrayList g_hTiers;

char   g_sMapName[PLATFORM_MAX_PATH];

bool g_bClientIsRankedOverall[MAXPLAYERS + 1];
bool g_bClientIsRankedStyle[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES];
bool g_bClientRanksAreLoaded[MAXPLAYERS + 1];
bool g_bShouldRecalculate[MAX_TYPES][MAX_STYLES];
int g_OverallRank[MAXPLAYERS + 1];
int g_StyleRank[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES];
int g_StyleBits[MAX_TYPES];
int g_WRCount[MAXPLAYERS + 1];
int g_WRRank[MAXPLAYERS + 1];
int g_iMVPs_offset;

//Forwards
Handle g_hOnPointsRecalculated;
Handle g_hOnPlayerRankLoaded;
Handle g_hOnClientOverallRankChanged;
Handle g_hOnClientStyleRankChanged;
Handle g_hOnTiersLoaded;

// Late load
bool g_bLateLoad;
bool g_bFirstTimeLoad = true;
bool g_bZonesLoaded;

//Other plugins
bool g_bSmartMsgPluginLoaded;
bool g_bTasPluginLoaded;

public Plugin myinfo = 
{
	name = "[Timer] - Ranks",
	author = "blacky",
	description = "A ranking system for the timer",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

public void OnPluginStart()
{
	g_Engine = GetEngineVersion();
	
	// Connect to the database
	DB_Connect();
	
	// Commands
	RegConsoleCmdEx("sm_rank",      SM_Rank,            "Shows your rank.");
	RegConsoleCmdEx("sm_top",       SM_Top,             "Shows the list of top players.");
	RegConsoleCmdEx("sm_tier",      SM_Tier,            "Shows you the tier of the specified map.");
	RegConsoleCmdEx("sm_mapsdone",  SM_Mapsdone,        "Shows the maps done of a specified player.");
	RegConsoleCmdEx("sm_mapsleft",  SM_Mapsleft,        "Shows a player's maps left.");
	RegConsoleCmdEx("sm_stats",     SM_Stats,           "Shows the stats of a specified player.");
	RegConsoleCmdEx("sm_topwr",     SM_TopWR,           "Shows the rankings of players ordered by how many records they have.");
	RegConsoleCmdEx("sm_wrtop",     SM_TopWR,           "Shows the rankings of players ordered by how many records they have.");
	RegConsoleCmdEx("sm_mc",        SM_MostCompetitive, "Shows the most competitive maps.");
	
	// Admin commands
	RegConsoleCmdEx("sm_settier",   SM_SetTier,         "Set the map tier");
	RegConsoleCmdEx("sm_recalcmap", SM_RecalcMap,       "Recalculate a map's points manually.");
	RegConsoleCmdEx("sm_recalcall", SM_RecalcAll,       "Recalculates all map points.");
	RegConsoleCmdEx("sm_recalcoverall", SM_RecalcOverall, "Recalculates overall points.");
	
	g_hOverallRanks = new ArrayList(2);
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			g_hStyleRanks[Type][style] = new ArrayList(2);
		}
	}
	
	g_hOverallWRRank = new ArrayList(2);
	
	if(g_bLateLoad)
	{
		UpdateStyleBits();
		DB_LoadAllRanks();
	}
	
	if(g_Engine == Engine_CSS)
	{
		g_iMVPs_offset = FindSendPropInfo("CCSPlayerResource", "m_iMVPs");
	}
	else if(g_Engine == Engine_CSGO)
	{
		HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	}
	
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
}

public void OnAllPluginsLoaded()
{
	if(LibraryExists("tas"))
	{
		g_bTasPluginLoaded = true;
	}
	
	if(LibraryExists("smartmsg") && g_bSmartMsgPluginLoaded == false)
	{
		g_bSmartMsgPluginLoaded = true;
		RegisterSmartMessage(SmartMessage_OverallRank);
		RegisterSmartMessage(SmartMessage_StyleRank);
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
		g_bSmartMsgPluginLoaded = false;
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
		g_bSmartMsgPluginLoaded = true;
		//RegisterSmartMessage(SmartMessage_OverallRank);
		//RegisterSmartMessage(SmartMessage_StyleRank);
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Ranks_GetClientOverallRank",       Native_GetOverallRank);
	CreateNative("Ranks_IsClientRankedOverall",      Native_IsClientRankedOverall);
	CreateNative("Ranks_GetClientStyleRank",         Native_GetStyleRank);
	CreateNative("Ranks_IsClientRankedStyle",        Native_IsClientRankedStyle);
	CreateNative("Ranks_GetTotalOverallRanks",       Native_GetTotalOverallRanks);
	CreateNative("Ranks_GetTotalStyleRanks",         Native_GetTotalStyleRanks);
	CreateNative("Ranks_IsClientRankLoaded",         Native_IsClientRankLoaded);
	CreateNative("Ranks_GetClientOverallRecordRank", Native_GetClientOverallRecordRank);
	CreateNative("Ranks_GetMapTier",                 Native_GetMapTier);
	CreateNative("Ranks_AreTiersLoaded",             Native_AreTiersLoaded);
	CreateNative("Ranks_GetMapList",                 Native_GetMapList);
	CreateNative("Ranks_GetTierList",                Native_GetTierList);
	
	g_hOnPointsRecalculated       = CreateGlobalForward("OnPointsRecalculated", ET_Event, Param_Cell, Param_Cell);
	g_hOnClientOverallRankChanged = CreateGlobalForward("OnClientOverallRankChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	g_hOnClientStyleRankChanged   = CreateGlobalForward("OnClientStyleRankChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_hOnPlayerRankLoaded         = CreateGlobalForward("OnClientRankLoaded", ET_Event, Param_Cell);
	g_hOnTiersLoaded              = CreateGlobalForward("OnTierListLoaded", ET_Event);
	
	g_bLateLoad = late;
	if(late)
	{
		UpdateMessages();
	}
	
	RegPluginLibrary("ranks");
}

public void OnMapStart()
{
	g_bZonesLoaded = false;
	g_bFirstTimeLoad = true;
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	if(g_bLateLoad == true)
	{
		if(g_Engine == Engine_CSS)
		{
			int entity = FindEntityByClassname(-1, "cs_player_manager");
			if(entity != -1)
			{
				SDKHook(entity, SDKHook_ThinkPost, PlayerManager_OnThinkPost);
			}
		}
		
		g_bZonesLoaded = true;
	}
	//DB_LoadTierList();
}

public void OnPlayerIDLoaded(int client)
{
	if(g_bZonesLoaded == true)
	{
		int clients[1];
		clients[0] = client;
		DB_LoadPlayerRanks(clients, 1);
	}
}

public void OnClientDisconnect(int client)
{
	g_bClientRanksAreLoaded[client]  = false;
	g_OverallRank[client]            = 0;
	g_bClientIsRankedOverall[client] = false;
	g_WRCount[client]                = 0;
	g_WRRank[client]                 = 0;
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			g_bClientIsRankedStyle[client][Type][style] = false;
			g_StyleRank[client][Type][style] = 0;
		}
	}
}

public void OnZonesLoaded()
{
	g_bZonesLoaded = true;
	
	//if(g_bFirstTimeLoad == true)
	//{
	DB_LoadAllRanks();
	//}
	/*else
	{
		int[] clients = new int[MaxClients];
		int numClients;
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && GetPlayerID(client) != 0)
			{
				clients[numClients++] = client;
			}
		}
		
		Timer_Log(true, "SQL Query Start: (Function = DB_LoadPlayerRanks, Time = %d)", GetTime());
		DB_LoadPlayerRanks(clients, numClients);
	}*/
	
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(g_Engine == Engine_CSS)
	{
		if(StrContains(classname, "_player_manager") != -1)
		{
			SDKHook(entity, SDKHook_ThinkPost, PlayerManager_OnThinkPost);
		}
	}
}

public int PlayerManager_OnThinkPost(int entity)
{
	int[] m_iMVPs = new int[MaxClients + 1];
	//GetEntDataArray(entity, g_iMVPs_offset, m_iMVPs, MaxClients);

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && GetPlayerID(client) != 0)
		{
			m_iMVPs[client] = g_WRCount[client];
		}
	}
	
	SetEntDataArray(entity, g_iMVPs_offset, m_iMVPs, MaxClients + 1);
}

public void OnTimesUpdated(const char[] sMapName, int Type, int style, int tas, Handle Times)
{
	DB_RecalculateMapPoints(sMapName, Type, style, tas);
}

public void OnTimesDeleted(const char[] sMap, int type, int style, bool tas, int minPos, int maxPos)
{
	DB_RecalculateMapPoints(sMap, type, style, tas);
}

public void OnStylesLoaded()
{
	UpdateStyleBits();
}

public bool SmartMessage_OverallRank(int client)
{
	if(g_bClientRanksAreLoaded[client])
	{
		if(g_bClientIsRankedOverall[client])
		{
			PrintColorText(client, "%s%sYou are ranked %s%d%s overall.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_OverallRank[client],
				g_msg_textcol);
		}
		else
		{
			PrintColorText(client, "%s%sYou are not yet ranked. If you want to get ranked you just need to finish a map!",
				g_msg_start,
				g_msg_textcol);
		}
		return true;
	}
	
	return false;
}

public bool SmartMessage_StyleRank(int client)
{
	if(!Ranks_IsClientRankLoaded(client))
	{
		return false;
	}
	
	if(IsPlayerAlive(client) && IsBeingTimed(client, TIMER_ANY))
	{
		int tas = g_bTasPluginLoaded?view_as<int>(TAS_InEditMode(client)):0;
		if(!tas)
		{
			int type  = TimerInfo(client).Type;
			int style = TimerInfo(client).ActiveStyle;
			if(Ranks_IsClientRankedStyle(client, type, style))
			{
				PrintColorText(client, "%s%sYou are ranked %s%d%s on your current style.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					g_StyleRank[client][type][style],
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%sYou are not ranked on your current style yet.",
					g_msg_start,
					g_msg_textcol);
			}
			
			return true;
		}
	}
	
	return false;
}

void UpdateStyleBits()
{
	g_StyleBits[0] = 0;
	g_StyleBits[1] = 0;
	for(int style; style < MAX_STYLES; style++)
	{
		if(Style(style).EnabledInConfig == false)
		{
			continue;
		}
		
		if(Style(style).GetAllowType(TIMER_MAIN))
		{
			g_StyleBits[TIMER_MAIN] |= (1 << style);
		}
		
		if(Style(style).GetAllowType(TIMER_BONUS))
		{
			g_StyleBits[TIMER_BONUS] |= (1 << style);
		}
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_Engine != Engine_CSGO)
	{
		return Plugin_Continue;
	}
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client != 0 && !IsFakeClient(client))
	{
		if(g_bClientRanksAreLoaded[client])
		{
			CS_SetMVPCount(client, g_WRCount[client]);
		}
	}
	
	return Plugin_Continue;
}

public Action SM_Rank(int client, int args)
{
	if(args == 0)
	{
		int playerId = GetPlayerID(client);
		if(playerId != 0)
		{
			OpenRankMenu(client, playerId);
		}
		else
		{
			PrintColorText(client, "%s%sYour PlayerID hasn't loaded yet, so your rank can't be obtained.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		char sName[MAX_NAME_LENGTH];
		GetCmdArgString(sName, MAX_NAME_LENGTH);
		int target = FindTarget(client, sName, true, false);
		
		if(target != -1)
		{
			int playerId = GetPlayerID(target);
			
			if(playerId != 0)
			{
				OpenRankMenu(client, playerId);
			}
			else
			{
				PrintColorText(client, "%s%sThe PlayerID for %s%N%s has not been found yet.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					target,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sNo player found named %s%s%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sName,
				g_msg_textcol);
		}
	}
}

void OpenRankMenu(int client, int playerId)
{
	Menu menu = new Menu(Menu_RankMenu);
	menu.SetTitle("Choose Rank Type");
	
	char sInfo[32], sDisplay[64];
	
	FormatEx(sInfo, sizeof(sInfo), "overall;%d", playerId);
	menu.AddItem(sInfo, "Overall\n ");
	
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

public int Menu_RankMenu(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrContains(sInfo, "overall") != -1)
		{
			char sInfoExploded[2][64];
			ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
			
			int playerId = StringToInt(sInfoExploded[1]);
			
			DB_ShowOverallRank(client, playerId);
		}
		else
		{
			char sInfoExploded[3][32];
			ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
			
			int Type     = StringToInt(sInfoExploded[0]);
			int style    = StringToInt(sInfoExploded[1]);
			int playerId = StringToInt(sInfoExploded[2]);
			
			DB_ShowRank(client, playerId, Type, style);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void DB_ShowRank(int client, int playerId, int Type, int style)
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT (SELECT User FROM players WHERE PlayerID=%d) AS Name, Rank, Points, \
	(SELECT Count(*) FROM ranks_styles WHERE Type=%d AND Style=%d) AS Total FROM ranks_styles WHERE Type=%d AND Style=%d AND PlayerID=%d",
		playerId,
		Type,
		style,
		Type,
		style,
		playerId);
		
	DataPack pack = CreateDataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(playerId);
	
	SQL_TQuery(g_DB, ShowRank_Callback, sQuery, pack);
}

public void ShowRank_Callback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if(hndl != INVALID_HANDLE)
	{	
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		if(client != 0)
		{
			int playerId = pack.ReadCell();
			
			if(SQL_GetRowCount(hndl))
			{
				SQL_FetchRow(hndl);
				
				int field;
				
				char sName[MAX_NAME_LENGTH];
				SQL_FieldNameToNum(hndl, "Name", field);
				SQL_FetchString(hndl, field, sName, sizeof(sName));
				
				SQL_FieldNameToNum(hndl, "Rank", field);
				int rank = SQL_FetchInt(hndl, field);
				
				SQL_FieldNameToNum(hndl, "Points", field);
				float fPoints = SQL_FetchFloat(hndl, field);
				
				SQL_FieldNameToNum(hndl, "Total", field);
				int total = SQL_FetchInt(hndl, field);
				
				PrintColorText(client, "%s%s%s%s is ranked %s%d%s out of %s%d%s with %s%.0f%s pts.",
					g_msg_start,
					g_msg_varcol,
					sName,
					g_msg_textcol,
					g_msg_varcol,
					rank,
					g_msg_textcol,
					g_msg_varcol,
					total,
					g_msg_textcol,
					g_msg_varcol,
					fPoints,
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%sThe specified player is not ranked yet under the category you chose.",
					g_msg_start,
					g_msg_textcol);
			}
			
			OpenRankMenu(client, playerId);
		}
	}
	else
	{
		LogError("ShowRank_Callback: %s", error);
	}
	
	delete pack;
}

public void LoadTierList_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(g_hMaps == INVALID_HANDLE)
		{
			g_hMaps  = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
			g_hTiers = CreateArray();
		}
		
		ClearArray(g_hMaps);
		ClearArray(g_hTiers);
		
		char sMap[PLATFORM_MAX_PATH];
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sMap, PLATFORM_MAX_PATH);
			int tier = SQL_FetchInt(hndl, 1);
			
			PushArrayString(g_hMaps, sMap);
			PushArrayCell(g_hTiers, tier);
		}
	}
}

public int Native_GetMapTier(Handle plugin, int numParams)
{
	if(g_hMaps == INVALID_HANDLE)
	{
		return -1;
	}
	
	char sMap[PLATFORM_MAX_PATH];
	GetNativeString(1, sMap, PLATFORM_MAX_PATH);
	int iSize = GetArraySize(g_hMaps);
	
	for(int idx; idx < iSize; idx++)
	{
		char sIdxMap[PLATFORM_MAX_PATH];
		GetArrayString(g_hMaps, idx, sIdxMap, sizeof(sIdxMap));
		if(StrEqual(sMap, sIdxMap, false))
		{
			return GetArrayCell(g_hTiers, idx, 0);
		}
	}
	
	return -1;
}

public int Native_AreTiersLoaded(Handle plugin, int numParams)
{
	return g_hMaps != INVALID_HANDLE;
}

public int Native_GetMapList(Handle plugin, int numParams)
{
	return view_as<int>(g_hMaps);
}

public int Native_GetTierList(Handle plugin, int numParams)
{
	return view_as<int>(g_hTiers);
}

void DB_ShowOverallRank(int client, int playerId)
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT (SELECT User FROM players WHERE PlayerID=%d) AS Name, Rank, Points, \
	(SELECT Count(*) FROM ranks_overall) AS Total FROM ranks_overall WHERE PlayerID=%d",
		playerId,
		playerId);
		
	DataPack pack = CreateDataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(playerId);
	
	SQL_TQuery(g_DB, ShowRank_Callback, sQuery, pack);
}

void DB_ShowStyleRankAtPosition(int client, int position, int Type, int style)
{
	
}

void DB_ShowOverallRankAtPosition(int client, int position, int Type, int style)
{

}

public Action SM_Top(int client, int args)
{
	OpenTopMenu(client);
	
	return Plugin_Handled;
}

void OpenTopMenu(int client)
{
	Menu menu = new Menu(Menu_TopMenu);
	menu.SetTitle("Choose Rank List Type");
	
	char sInfo[32], sDisplay[64];
	
	FormatEx(sInfo, sizeof(sInfo), "overall");
	menu.AddItem(sInfo, "Overall\n ");
	
	for(int style; style < MAX_STYLES; style++)
	{
		if(Style(style).EnabledInConfig)
		{
			for(int Type; Type < MAX_TYPES; Type++)
			{	
				FormatEx(sInfo, sizeof(sInfo), "%d;%d", Type, style);
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

public int Menu_TopMenu(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "overall") == true)
		{
			DB_ShowOverallTop(client);
		}
		else
		{
			char sInfoExploded[2][8];
			ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
			
			int Type     = StringToInt(sInfoExploded[0]);
			int style    = StringToInt(sInfoExploded[1]);
			
			DB_ShowTop(client, Type, style);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void DB_ShowOverallTop(int client)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "SELECT t2.User AS Name, t2.PlayerID, t1.Rank, t1.Points FROM ranks_overall AS t1, players AS t2 WHERE t1.PlayerID = t2.PlayerID ORDER BY t1.Rank ASC");
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(0);
	pack.WriteCell(0);
	SQL_TQuery(g_DB, ShowTop_Callback, sQuery, pack);
}

public void ShowTop_Callback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if(hndl != INVALID_HANDLE)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		
		if(client != 0)
		{
			if(SQL_GetRowCount(hndl))
			{
				int type  = pack.ReadCell();
				int style = pack.ReadCell();
				char sName[MAX_NAME_LENGTH], sInfo[32], sDisplay[64];
				int playerId, rank, points, field, rowsAdded;
				
				Menu menu = new Menu(Menu_TopList);
				menu.SetTitle("Top Players");
				while(SQL_FetchRow(hndl) && rowsAdded < 100)
				{
					rowsAdded++;
					// Get data
					SQL_FieldNameToNum(hndl, "Name", field);
					SQL_FetchString(hndl, field, sName, sizeof(sName));
					
					SQL_FieldNameToNum(hndl, "PlayerID", field);
					playerId = SQL_FetchInt(hndl, field);
					
					SQL_FieldNameToNum(hndl, "Rank", field);
					rank = SQL_FetchInt(hndl, field);
					
					SQL_FieldNameToNum(hndl, "Points", field);
					points = SQL_FetchInt(hndl, field);
					
					// Add data to menu
					FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", playerId, type, style);
					FormatEx(sDisplay, sizeof(sDisplay), "#%d: %s (%d pts.)", 
						rank,
						sName,
						points);
					
					menu.AddItem(sInfo, sDisplay);
				}
				
				menu.Display(client, MENU_TIME_FOREVER);
			}
			else
			{
				PrintColorText(client, "%s%sLooks like there aren't any ranks yet on the server for the specified category.",
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
	else
	{
		LogError("ShowTop_Callback: %s", error);
	}
}

public int Menu_TopList(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sInfoExploded[3][16];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		
		int playerId = StringToInt(sInfoExploded[0]);
		int type     = StringToInt(sInfoExploded[1]);
		int style    = StringToInt(sInfoExploded[2]);
		
		ShowPlayerStats(client, playerId, type, style, 0);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void DB_ShowTop(int client, int Type, int style)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "SELECT t2.User AS Name, t2.PlayerID, t1.Rank, t1.Points FROM ranks_styles AS t1, players AS t2 WHERE t1.PlayerID = t2.PlayerID AND t1.Type = %d AND t1.Style = %d ORDER BY t1.Rank ASC",
		Type,
		style);
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(Type);
	pack.WriteCell(style);
	SQL_TQuery(g_DB, ShowTop_Callback, sQuery, pack);
}

public Action SM_Tier(int client, int args)
{
	if(args == 0)
	{
		DB_ShowMapTier(client, g_sMapName);
	}
	else
	{
		char sArg[PLATFORM_MAX_PATH];
		GetCmdArg(1, sArg, sizeof(sArg));
		if(Timer_IsMapInMapCycle(sArg))
		{
			DB_ShowMapTier(client, sArg);
		}
		else
		{
			PrintColorText(client, "%s%s%s%s is not a valid map.",
				g_msg_start,
				g_msg_varcol,
				sArg,
				g_msg_textcol);
		}
	}

	return Plugin_Handled;
}

void DB_ShowMapTier(int client, const char[] sMap)
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT Tier FROM maps WHERE MapName='%s'", sMap);
	
	DataPack pack = CreateDataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(sMap);
	SQL_TQuery(g_DB, ShowMapTier_Callback, sQuery, pack);
}

public void ShowMapTier_Callback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if(hndl != INVALID_HANDLE)
	{	
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		if(client != 0)
		{
			char sMap[PLATFORM_MAX_PATH];
			pack.ReadString(sMap, sizeof(sMap));
			if(SQL_FetchRow(hndl))
			{
				int tier = SQL_FetchInt(hndl, 0);
				
				PrintColorText(client, "%s%s%s%s is a tier %s%d%s map.",
					g_msg_start,
					g_msg_varcol,
					sMap,
					g_msg_textcol,
					g_msg_varcol,
					tier,
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%s%s%s has no tier set yet.",
					g_msg_start,
					g_msg_varcol,
					sMap,
					g_msg_textcol);
			}
		}
		
	}
	else
	{
		LogError("ShowMapTier_Callback: %s", error);
	}
}

public Action SM_SetTier(int client, int args)
{
	if(!Timer_ClientHasTimerFlag(client, "tier", Admin_Generic))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if(args == 0)
	{
		CreateSetTierMenu(client, g_sMapName);
	}
	else if(args == 1)
	{
		char sArg[PLATFORM_MAX_PATH];
		GetCmdArg(1, sArg, sizeof(sArg));
		
		if(Timer_IsMapInMapCycle(sArg))
		{
			CreateSetTierMenu(client, sArg);
		}
		else if(1 <= StringToInt(sArg) <= 5)
		{
			SetMapTier(client, g_sMapName, StringToInt(sArg));
		}
		else
		{
			PrintColorText(client, "%s%s'%s'%s is not a map nor a valid tier number (1-5)",
				g_msg_start,
				g_msg_varcol,
				sArg,
				g_msg_textcol);
		}
	}
	else if(args == 2)
	{
		char sMap[PLATFORM_MAX_PATH], sTier[64];
		GetCmdArg(1, sMap, sizeof(sMap));
		GetCmdArg(2, sTier, sizeof(sTier));
		
		if(Timer_IsMapInMapCycle(sMap) == false)
		{
			PrintColorText(client, "%s%s%s%s is not a map.",
				g_msg_start,
				g_msg_varcol,
				sMap,
				g_msg_textcol);
				
			return Plugin_Handled;
		}
		
		int tier = StringToInt(sTier);
		if(tier < 1 || tier > 5)
		{
			PrintColorText(client, "%s%s%s%s is not a tier number. Tier values must be between between 1 and 5",
				g_msg_start,
				g_msg_varcol,
				sTier,
				g_msg_textcol);
				
			return Plugin_Handled;
		}
		
		SetMapTier(client, sMap, tier);
		
	}

	return Plugin_Handled;
}

void CreateSetTierMenu(int client, const char[] sMapName)
{
	Menu menu = new Menu(Menu_SetTier);
	menu.SetTitle("Set Map Tier: %s", sMapName);
	
	char sInfo[70], sDisplay[32];
	for(int tier = 1; tier <= 5; tier++)
	{
		FormatEx(sInfo, sizeof(sInfo), "%s;%d", sMapName, tier);
		FormatEx(sDisplay, sizeof(sDisplay), "Tier %d", tier);
		menu.AddItem(sInfo, sDisplay);
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_SetTier(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		char sInfoExploded[2][64];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		int tier = StringToInt(sInfoExploded[1]);
		
		SetMapTier(client, sInfoExploded[0], tier);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void SetMapTier(int client, const char[] sMapName, int tier)
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET Tier=%d WHERE MapName='%s'", tier, sMapName);
	
	DataPack pack = CreateDataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(sMapName);
	pack.WriteCell(tier);
	SQL_TQuery(g_DB, SetMapTier_Callback, sQuery, pack);
}

public void SetMapTier_Callback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if(hndl != INVALID_HANDLE)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		char sMap[PLATFORM_MAX_PATH]; pack.ReadString(sMap, sizeof(sMap));
		int tier = pack.ReadCell();
		
		if(SQL_GetAffectedRows(hndl) == 0)
		{
			if(client != 0)
			{
				PrintColorText(client, "%s%s%s%s either is not a map in the database or its tier is already at %s%d%s.",
					g_msg_start,
					g_msg_varcol,
					sMap,
					g_msg_textcol,
					g_msg_varcol,
					tier,
					g_msg_textcol);
			}
		}
		else
		{
			if(client != 0)
			{
				PrintColorText(client, "%s%sMap tier for %s%s%s has been changed to %s%d%s.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sMap,
					g_msg_textcol,
					g_msg_varcol,
					tier,
					g_msg_textcol);
					
				PrintColorText(client, "%s%sPoints will be recalculated now due to the tier change.",
					g_msg_start,
					g_msg_textcol);
			}
			
			Transaction t = new Transaction();
			char sQuery[256];
			for(int Type; Type < MAX_TYPES; Type++)
			{
				for(int style; style < MAX_STYLES; style++)
				{
					for(int tas; tas < 2; tas++)
					{
						if(Style(style).Enabled && Style(style).GetAllowType(Type))
						{
							FormatEx(sQuery, sizeof(sQuery), "CALL recalcmappts('%s', %d, %d, %d)", sMap, Type, style, tas);
							t.AddQuery(sQuery);
							
							FormatEx(sQuery, sizeof(sQuery), "CALL recalcstylepts(%d, %d)", Type, style);
							t.AddQuery(sQuery);
						}
					}
				}
			}
			
			FormatEx(sQuery, sizeof(sQuery), "CALL recalcpts(%d, %d)",
				g_StyleBits[TIMER_MAIN],
				g_StyleBits[TIMER_BONUS]);
			t.AddQuery(sQuery);
			
			SQL_ExecuteTransaction(g_DB, t, Recalc_Success, Recalc_Failure);
		}
	}
	else
	{
		LogError("SetMapTier_Callback: %s", error);
	}
}

public Action SM_RecalcMap(int client, int args)
{
	if(!Timer_ClientHasTimerFlag(client, "tier", Admin_Generic))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if(args != 4)
	{
		ReplyToCommand(client, "[SM] Usage: sm_recalcmap <MapName> <Type|0(main) or 1(bonus)> <Style #> <Tas|0 or 1>");
	}
	
	char sMap[PLATFORM_MAX_PATH];
	GetCmdArg(1, sMap, sizeof(sMap));
	
	char sArg[8];
	GetCmdArg(2, sArg, sizeof(sArg));
	int type = StringToInt(sArg);
	
	GetCmdArg(3, sArg, sizeof(sArg));
	int style = StringToInt(sArg);
	
	GetCmdArg(4, sArg, sizeof(sArg));
	int tas = StringToInt(sArg);
	
	DB_RecalculateMapPoints(sMap, type, style, tas);
	
	return Plugin_Handled;
}

public Action SM_RecalcAll(int client, int args)
{
	if(!Timer_ClientHasTimerFlag(client, "tier", Admin_Generic))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	DB_RecalcAllMaps();
	
	return Plugin_Handled;
}

public Action SM_RecalcOverall(int client, int args)
{
	if(!Timer_ClientHasTimerFlag(client, "tier", Admin_Generic))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "CALL recalcpts(2^32-1, 2^32-1);");
	SQL_TQuery(g_DB, RecalcOverall_Callback, sQuery);
	
	return Plugin_Handled;
}

public void RecalcOverall_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl != INVALID_HANDLE)
	{
		g_bFirstTimeLoad = true;
		DB_LoadAllRanks();
	}
	else
	{
		Timer_Log(false, error);
	}
}

public Action SM_Mapsleft(int client, int args)
{
	
}

public Action SM_Mapsdone(int client, int args)
{
	char sArg[MAX_NAME_LENGTH];
	GetCmdArgString(sArg, sizeof(sArg));
	
	DB_CreatePlayerListFromName(client, "Select Player To Show Maps Done", g_DB, false, sArg, MapsDone_PlayerSelectedCallback);
	
	return Plugin_Handled;
}

public void MapsDone_PlayerSelectedCallback(int client, int playerId)
{
	OpenMapsDoneMainMenu(client, playerId);
}

void OpenMapsDoneMainMenu(int client, int playerId)
{
	CreateTimerSelection(client, "Select Maps Done Settings", 0, 0, 0, false, MapsDone_TimerSelectCallback, playerId);
}

public void MapsDone_TimerSelectCallback(int client, int type, int style, bool tas, bool all, int playerId)
{
	DB_ShowMapsDone(client, type, style, tas, playerId);
}

void DB_ShowMapsDone(int client, int type, int style, int tas, int playerId)
{
	char sQuery[512];
	Transaction t = new Transaction();
	
	FormatEx(sQuery, sizeof(sQuery), "SELECT User FROM players WHERE PlayerID=%d", playerId);
	t.AddQuery(sQuery);
	
	FormatEx(sQuery, sizeof(sQuery), "SELECT m.MapName, rm.Rank, t.Time FROM \
		(SELECT * FROM times WHERE PlayerID=%d AND Type=%d AND Style=%d AND tas=%d) AS t \
		JOIN (SELECT * FROM maps WHERE InMapCycle=1) AS m ON m.MapID=t.MapID \
		JOIN (SELECT * FROM ranks_maps WHERE PlayerID=%d AND Type=%d AND Style=%d AND tas=%d) AS rm ON rm.MapID=t.MapID \
		ORDER BY m.MapName",
			playerId,
			type,
			style,
			tas,
			playerId,
			type,
			style,
			tas);
	t.AddQuery(sQuery, type);
	
	DataPack pack = CreateDataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(type);
	pack.WriteCell(style);
	pack.WriteCell(tas);
	pack.WriteCell(playerId);
	
	SQL_ExecuteTransaction(g_DB, t, MapsDone_Success, MapsDone_Failure, pack);
}

int g_MapsDone_Type[MAXPLAYERS + 1];
int g_MapsDone_Style[MAXPLAYERS + 1];
int g_MapsDone_TAS[MAXPLAYERS + 1];
int g_MapsDone_PlayerId[MAXPLAYERS + 1];

public void MapsDone_Success(Database db, DataPack pack, int numQueries, Handle[] results, any[] queryData)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	if(client == 0)
		return;
		
	g_MapsDone_Type[client]     = pack.ReadCell();
	g_MapsDone_Style[client]    = pack.ReadCell();
	g_MapsDone_TAS[client]      = pack.ReadCell();
	g_MapsDone_PlayerId[client] = pack.ReadCell();
	
	char sName[MAX_NAME_LENGTH];
	SQL_FetchRow(results[0]);
	SQL_FetchString(results[0], 0, sName, sizeof(sName));
	
	if(SQL_GetRowCount(results[1]) > 0)
	{
		Menu menu = new Menu(Menu_MapsDone);
		if(queryData[1] == TIMER_MAIN)
		{
			menu.SetTitle("Maps done for %s\n%d completed of %d total\n ", sName, SQL_GetRowCount(results[1]), Timer_GetMapCycleSize());
		}
		else if(queryData[1] == TIMER_BONUS)
		{
			menu.SetTitle("Maps done for %s\n%d completed\n ", sName, SQL_GetRowCount(results[1]));
		}
		
		char  sMap[PLATFORM_MAX_PATH], sDisplay[PLATFORM_MAX_PATH], sTime[64];
		int   mapRank;
		float fTime;
		
		while(SQL_FetchRow(results[1]))
		{
			SQL_FetchString(results[1], 0, sMap, sizeof(sMap));
			mapRank = SQL_FetchInt(results[1], 1);
			fTime   = SQL_FetchFloat(results[1], 2);
			FormatPlayerTime(fTime, sTime, sizeof(sTime), 1);
			
			FormatEx(sDisplay, sizeof(sDisplay), "%s [%s - #%d]", sMap, sTime, mapRank);
			menu.AddItem(sMap, sDisplay);
		}
		
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		PrintColorText(client, "%s%s%s%s has not completed any maps.",
			g_msg_start,
			g_msg_varcol,
			sName,
			g_msg_textcol);
	}
	
}

public void MapsDone_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] querydata)
{
	LogError("MapsDone_Failure: %s", error);
}

public int Menu_MapsDone(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sMap[PLATFORM_MAX_PATH];
		GetMenuItem(menu, param2, sMap, sizeof(sMap));
		
		//Timer_ShowPlayerTime(int client, int type, int style, int tas, int playerId, char[] sMap);
		Timer_ShowPlayerTime(
			client, 
			g_MapsDone_Type[client], 
			g_MapsDone_Style[client], 
			g_MapsDone_TAS[client], 
			g_MapsDone_PlayerId[client], 
			sMap);
	}
	if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action SM_Stats(int client, int args)
{
	
}

public Action SM_TopWR(int client, int args)
{
	OpenTopWrMenu(client);
	
	return Plugin_Handled;
}

void OpenTopWrMenu(int client)
{
	Menu menu = new Menu(Menu_TopWrMenu);
	menu.SetTitle("Choose Rank List Type");
	
	char sInfo[32], sDisplay[64];
	
	FormatEx(sInfo, sizeof(sInfo), "overall");
	menu.AddItem(sInfo, "Overall\n ");
	
	for(int style; style < MAX_STYLES; style++)
	{
		if(Style(style).EnabledInConfig)
		{
			for(int Type; Type < MAX_TYPES; Type++)
			{	
				FormatEx(sInfo, sizeof(sInfo), "%d;%d", Type, style);
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

public int Menu_TopWrMenu(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "overall") == true)
		{
			DB_ShowOverallRecordTop(client);
		}
		else
		{
			char sInfoExploded[2][8];
			ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
			
			int Type     = StringToInt(sInfoExploded[0]);
			int style    = StringToInt(sInfoExploded[1]);
			
			DB_ShowRecordTop(client, Type, style);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void DB_ShowOverallRecordTop(int client)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "SELECT t1.PlayerID, t2.User, t1.RecordCount FROM \
				(SELECT PlayerID, count(*) AS RecordCount FROM ranks_maps WHERE Rank=1 AND tas=0 GROUP BY PlayerID ORDER BY count(*) DESC) \
				AS t1, players AS t2 \
				WHERE t1.PlayerID=t2.PlayerID");
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(0);
	pack.WriteCell(0);
	SQL_TQuery(g_DB, ShowRecordTop_Callback, sQuery, pack);
}

public void ShowRecordTop_Callback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if(hndl != INVALID_HANDLE)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		
		if(client != 0)
		{
			if(SQL_GetRowCount(hndl))
			{
				int type  = pack.ReadCell();
				int style = pack.ReadCell();
				char sName[MAX_NAME_LENGTH], sInfo[32], sDisplay[64];
				int playerId, recordCount, field, rowsAdded;
				
				Menu menu = new Menu(Menu_TopList);
				menu.SetTitle("Top Players by Record Count");
				while(SQL_FetchRow(hndl))
				{
					rowsAdded++;
					
					// Get data
					SQL_FieldNameToNum(hndl, "User", field);
					SQL_FetchString(hndl, field, sName, sizeof(sName));
					
					SQL_FieldNameToNum(hndl, "PlayerID", field);
					playerId = SQL_FetchInt(hndl, field);
					
					SQL_FieldNameToNum(hndl, "RecordCount", field);
					recordCount = SQL_FetchInt(hndl, field);
					
					// Add data to menu
					FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", playerId, type, style);
					FormatEx(sDisplay, sizeof(sDisplay), "#%d: %s (%d records)", 
						rowsAdded,
						sName,
						recordCount);
					
					menu.AddItem(sInfo, sDisplay);
				}
				
				menu.Display(client, MENU_TIME_FOREVER);
			}
			else
			{
				PrintColorText(client, "%s%sLooks like there aren't any ranks yet on the server for the specified category.",
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
	else
	{
		LogError("ShowRecordTop_Callback: %s", error);
	}
}

void DB_ShowRecordTop(int client, int type, int style)
{
		char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "SELECT t1.PlayerID, t2.User, t1.RecordCount FROM \
	(SELECT PlayerID, count(*) AS RecordCount FROM ranks_maps WHERE Rank=1 AND Type=%d AND Style=%d AND tas=0 GROUP BY PlayerID ORDER BY count(*) DESC) \
	AS t1, players AS t2 \
	WHERE t1.PlayerID=t2.PlayerID",
	type,
	style);
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(type);
	pack.WriteCell(style);
	SQL_TQuery(g_DB, ShowRecordTop_Callback, sQuery, pack);
}

public Action SM_MostCompetitive(int client, int args)
{
	
}

void DB_Connect()
{
	if(g_DB != INVALID_HANDLE)
	{
		delete g_DB;
	}
	
	char sError[256];
	g_DB = SQL_Connect("timer", true, sError, sizeof(sError));
	
	if(g_DB == INVALID_HANDLE)
	{
		LogError(sError);
	}
}

void DB_RecalculateMapPoints(const char[] sMapName, int type, int style, int tas)
{
	Transaction t = new Transaction();
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "CALL recalcmappts('%s', %d, %d, %d)", sMapName, type, style, tas);
	t.AddQuery(sQuery);
	
	if(tas == 0)
	{
		FormatEx(sQuery, sizeof(sQuery), "CALL recalcstylepts(%d, %d)", type, style);
		t.AddQuery(sQuery);
		
		FormatEx(sQuery, sizeof(sQuery), "CALL recalcpts(%d, %d)",
				g_StyleBits[TIMER_MAIN],
				g_StyleBits[TIMER_BONUS]);
		t.AddQuery(sQuery);
		
		g_bShouldRecalculate[type][style] = true;
	}
	
	Timer_Log(true, "SQL Query Start: (Function = DB_RecalculateMapPoints, Time = %d)", GetTime());
	SQL_ExecuteTransaction(g_DB, t, Recalc_Success, Recalc_Failure);
}

public void Recalc_Success(Database db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	Timer_Log(true, "SQL Query Finish: (Function = DB_RecalculateMapPoints, Time = %d)", GetTime());
	
	Call_StartForward(g_hOnPointsRecalculated);
	Call_PushCell(0);
	Call_PushCell(0);
	Call_Finish();
}

public void OnPointsRecalculated(RecalculateReason reason, any data)
{
	DB_LoadAllRanks();
}

public void Recalc_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] querydata)
{
	LogError("Recalc_Failure (%d): %s", failIndex, error);
}

void DB_LoadPlayerRanks(int[] clients, int numClients)
{
	Transaction t = new Transaction();
	char sQuery[512];
	int playerId;
	for(int idx; idx < numClients; idx++)
	{
		playerId = GetPlayerID(clients[idx]);
		if(playerId == 0)
			continue;
		
		/*if(numClients <= 1)
		{
			// Get overall rank
			FormatEx(sQuery, sizeof(sQuery), "SELECT Rank AS OverallRank, Points FROM ranks_overall WHERE PlayerID=%d", playerId);
			t.AddQuery(sQuery, GetClientUserId(clients[idx]));
			
			// Get style ranks
			for(int Type; Type < MAX_TYPES; Type++)
			{
				for(int style; style < MAX_STYLES; style++)
				{
					if(Style(style).EnabledInConfig)
					{
						FormatEx(sQuery, sizeof(sQuery), "SELECT Rank AS StyleRank, Points, Type, Style FROM ranks_styles WHERE PlayerID=%d AND Type=%d AND Style=%d",
							playerId,
							Type,
							style);
						t.AddQuery(sQuery, GetClientUserId(clients[idx]));
					}
				}
			}
		}
		else
	{*/
		int iSize = GetArraySize(g_hOverallRanks);
		
		for(int idx2; idx2 < iSize; idx2++)
		{
			if(GetArrayCell(g_hOverallRanks, idx2, 0) == playerId)
			{
				g_bClientIsRankedOverall[clients[idx]] = true;
				g_OverallRank[clients[idx]] = idx2 + 1;
			}
		}
		
		for(int Type; Type < MAX_TYPES; Type++)
		{
			for(int style; style < MAX_STYLES; style++)
			{
				if(Style(style).EnabledInConfig)
				{
					iSize = GetArraySize(g_hStyleRanks[Type][style]);
					
					for(int idx2; idx2 < iSize; idx2++)
					{
						if(GetArrayCell(g_hStyleRanks[Type][style], idx2, 0) == playerId)
						{
							g_bClientIsRankedStyle[clients[idx]][Type][style] = true;
							g_StyleRank[clients[idx]][Type][style] = idx2 + 1;
						}
					}
				}
			}
		}
		
		g_bClientRanksAreLoaded[clients[idx]] = true;
		
		Call_StartForward(g_hOnPlayerRankLoaded);
		Call_PushCell(clients[idx]);
		Call_Finish();
		
		iSize = GetArraySize(g_hOverallWRRank);
		
		for(int idx2; idx2 < iSize; idx2++)
		{
			if(GetArrayCell(g_hOverallWRRank, idx2, 0) == playerId)
			{
				g_WRRank[clients[idx]]  = idx2 + 1;
				g_WRCount[clients[idx]] = GetArrayCell(g_hOverallWRRank, idx2, 1);
				
				if(IsClientInGame(clients[idx]) && IsPlayerAlive(clients[idx]) && g_Engine == Engine_CSGO)
				{
					CS_SetMVPCount(clients[idx], g_WRCount[clients[idx]]);
				}
				break;
			}
		}
	}
	
	SQL_ExecuteTransaction(g_DB, t, OnLoadPlayerRanks_Success, OnLoadPlayerRanks_Fail);
}

public void OnLoadPlayerRanks_Success(Database db, any data, int numQueries, Handle[] results, any[] queryData)
{
	Timer_Log(true, "SQL Query Finish: (Function = DB_LoadPlayerRanks, Time = %d)", GetTime());
	char sFieldName[64];
	int[] clients = new int[MaxClients];
	int Type, style;
	int numClients, lastClient = 0;
	for(int idx; idx < numQueries; idx++)
	{
		int client = GetClientOfUserId(queryData[idx]);
		if(client == 0)
			continue;
			
		if(lastClient != client)
		{
			clients[numClients++] = client;
			lastClient = client;
		}
			
		g_bClientRanksAreLoaded[client] = true;
			
		if(SQL_FetchRow(results[idx]) == false)
			continue;
		
		SQL_FieldNumToName(results[idx], 0, sFieldName, sizeof(sFieldName));
		
		if(StrEqual(sFieldName, "OverallRank"))
		{
			g_OverallRank[client]            = SQL_FetchInt(results[idx], 0);
			g_bClientIsRankedOverall[client] = true;
		}
		else if(StrEqual(sFieldName, "StyleRank"))
		{
			Type  = SQL_FetchInt(results[idx], 2);
			style = SQL_FetchInt(results[idx], 3);
			
			g_StyleRank[client][Type][style]            = SQL_FetchInt(results[idx], 0);
			g_bClientIsRankedStyle[client][Type][style] = true;
		}
	}
	
	for(int idx; idx < numClients; idx++)
	{
		Call_StartForward(g_hOnPlayerRankLoaded);
		Call_PushCell(clients[idx]);
		Call_Finish();
	}
}

public void OnLoadPlayerRanks_Fail(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("OnLoadPlayerRanks_Fail: %s", error);
}

void DB_LoadAllRanks()
{
	Transaction t = new Transaction();
	t.AddQuery("SELECT PlayerID, Points FROM ranks_overall ORDER BY Rank ASC");
	t.AddQuery("SELECT PlayerID, Points, Type, Style FROM ranks_styles ORDER BY Type, Style, Rank ASC");
	t.AddQuery("SELECT t1.PlayerID, t2.User, t1.RecordCount FROM \
				(SELECT PlayerID, count(*) AS RecordCount FROM ranks_maps WHERE Rank=1 AND tas=0 GROUP BY PlayerID ORDER BY count(*) DESC) \
				AS t1, players AS t2 \
				WHERE t1.PlayerID=t2.PlayerID");
	t.AddQuery("SELECT MapName, Tier FROM maps ORDER BY MapName ASC");
	
	Timer_Log(true, "SQL Query Start: (Function = DB_LoadAllRanks, Time = %d)", GetTime());
	SQL_ExecuteTransaction(g_DB, t, OnLoadAllRanks_Success, OnLoadAllRanks_Fail);
}

public void OnLoadAllRanks_Success(Database db, any data, int numQueries, Handle[] results, any[] queryData)
{
	Timer_Log(true, "SQL Query Finish: (Function = DB_LoadAllRanks, Time = %d)", GetTime());
	
	// Overall ranks
	ClearArray(g_hOverallRanks);
	
	any buffer[2];
	while(SQL_FetchRow(results[0]))
	{
		buffer[0] = SQL_FetchInt(results[0], 0);
		buffer[1] = SQL_FetchInt(results[0], 1);
		g_hOverallRanks.PushArray(buffer, 2);
	}

	// Style ranks
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			ClearArray(g_hStyleRanks[Type][style]);
		}
	}
	
	while(SQL_FetchRow(results[1]))
	{
		buffer[0] = SQL_FetchInt(results[1], 0);
		buffer[1] = SQL_FetchInt(results[1], 1);
		g_hStyleRanks[SQL_FetchInt(results[1], 2)][SQL_FetchInt(results[1], 3)].PushArray(buffer, 2);
	}
	
	// WR Ranks g_hOverallWRRank
	ClearArray(g_hOverallWRRank);
	while(SQL_FetchRow(results[2]))
	{
		buffer[0] = SQL_FetchInt(results[2], 0);
		buffer[1] = SQL_FetchInt(results[2], 2);
		g_hOverallWRRank.PushArray(buffer, sizeof(buffer));
	}
	
	if(g_bFirstTimeLoad == true)
	{
		Timer_Log(true, "DB_LoadAllRanks: Loading all connected player's ranks");
		int[] clients = new int[MaxClients];
		int numClients;
		for(int client = 1; client <= MaxClients; client++)
		{
			if(GetPlayerID(client) != 0)
			{
				Timer_Log(true, "DB_LoadAllRanks: Loading rank for %N", client);
				clients[numClients++] = client;
			}
		}
		
		//Timer_Log(true, "SQL Query Start: (Function = DB_LoadPlayerRanks, Time = %d)", GetTime());
		DB_LoadPlayerRanks(clients, numClients);
		
		g_bFirstTimeLoad = false;
		
		if(g_hMaps == INVALID_HANDLE)
		{
			g_hMaps  = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
			g_hTiers = CreateArray();
		}
		
		ClearArray(g_hMaps);
		ClearArray(g_hTiers);
		
		char sMap[PLATFORM_MAX_PATH];
		while(SQL_FetchRow(results[3]))
		{
			SQL_FetchString(results[3], 0, sMap, PLATFORM_MAX_PATH);
			int tier = SQL_FetchInt(results[3], 1);
			
			PushArrayString(g_hMaps, sMap);
			PushArrayCell(g_hTiers, tier);
		}
		
		Call_StartForward(g_hOnTiersLoaded);
		Call_Finish();
	}
	else
	{
		UpdateClientOverallRanks();
		UpdateClientStyleRanks();
		
		for(int client = 1; client <= MaxClients; client++)
		{
			if(GetPlayerID(client) != 0)
			{
				if(g_bClientRanksAreLoaded[client] == false)
				{
					g_bClientRanksAreLoaded[client] = true;
					
					Call_StartForward(g_hOnPlayerRankLoaded);
					Call_PushCell(client);
					Call_Finish();
				}
			}
		}
	}
}

public void OnLoadAllRanks_Fail(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("OnLoadAllRanks_Fail: %s", error);
}

ArrayList g_hRecalcAllMaps;
ArrayList g_hRecalcAllData;
int g_iRecalcAllSize;
int g_iRecalcAllProgress;
bool g_bRecalculating;

void DB_RecalcAllMaps()
{
	if(g_bRecalculating == true)
	{
		return;
	}
	g_bRecalculating = true;
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "SELECT m.MapName, t.Type, t.Style, t.tas FROM times AS t, maps AS m WHERE t.MapID = m.MapID GROUP BY t.MapID, t.Type, t.Style, t.tas");
	SQL_TQuery(g_DB, OnRecalcAllMaps, sQuery);
}

public void OnRecalcAllMaps(Handle owner, Handle hndl, const char[] error, any data)
{
	if(g_hRecalcAllMaps == INVALID_HANDLE)
	{
		g_hRecalcAllMaps = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
		g_hRecalcAllData = CreateArray(3);
	}
	else
	{
		ClearArray(g_hRecalcAllMaps);
		ClearArray(g_hRecalcAllData);
	}
	
	char sMap[PLATFORM_MAX_PATH];
	int tdata[3];
	int Type, style, tas;
	while(SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, sMap, PLATFORM_MAX_PATH);
		tdata[0] = SQL_FetchInt(hndl, 1);
		tdata[1] = SQL_FetchInt(hndl, 2);
		tdata[2] = SQL_FetchInt(hndl, 3);
		
		PushArrayString(g_hRecalcAllMaps, sMap);
		PushArrayArray(g_hRecalcAllData, tdata, 3);
	}
	
	g_iRecalcAllProgress = 0;
	g_iRecalcAllSize = GetArraySize(g_hRecalcAllMaps);
	
	DB_StartRecalcAll();
	PrintToChatAll("*** Starting point recalculations across all maps ****");
}

void DB_StartRecalcAll()
{
	char sMap[PLATFORM_MAX_PATH], sQuery[1024];
	int data[3];
	
	Transaction t = new Transaction();
	
	int initial = g_iRecalcAllProgress;
	for(int idx = g_iRecalcAllProgress; idx < (initial + 20) && idx < g_iRecalcAllSize; idx++, g_iRecalcAllProgress++)
	{
		GetArrayString(g_hRecalcAllMaps, idx, sMap, PLATFORM_MAX_PATH);
		GetArrayArray(g_hRecalcAllData, idx, data, 3);
		FormatEx(sQuery, sizeof(sQuery), "CALL recalcmappts('%s', %d, %d, %d)",
			sMap, data[0], data[1], data[2]);
		t.AddQuery(sQuery);
	}
	
	SQL_ExecuteTransaction(g_DB, t, OnRecalcAllMapsSuccess, OnRecalcAllMapsFailure);
}

public void OnRecalcAllMapsSuccess(Database db, any data, int numQueries, Handle[] results, any[] queryData)
{
	if(g_iRecalcAllProgress < g_iRecalcAllSize)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				PrintToConsole(client, "*** Recalculation at %.1f%% ***", float(g_iRecalcAllProgress) / float(g_iRecalcAllSize) * 100.0);
			}
		}
		
		DB_StartRecalcAll();
	}
	else
	{
		PrintToChatAll(" **** Finished recalculating ****");
		g_bRecalculating = false;
	}
	
}

public void OnRecalcAllMapsFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("OnRecalcAllMapsFailure: %s", error);
}

void UpdateClientOverallRanks()
{
	// If there are no ranks for some reason, reset everything
	if(GetArraySize(g_hOverallRanks) == 0)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			g_bClientIsRankedOverall[client] = false;
			g_OverallRank[client] = 0;
			
			for(int style = 0; style < MAX_STYLES; style++)
			{
				g_bClientIsRankedStyle[client][0][style] = false;
				g_bClientIsRankedStyle[client][1][style] = false;
				g_StyleRank[client][0][style] = 0;
				g_StyleRank[client][1][style] = 0;
			}
		}
		return;
	}
	
	for(int client = 1; client <= MaxClients; client++)
	{
		int playerId = GetPlayerID(client), added = 0, subtracted = 0, iSize = GetArraySize(g_hOverallRanks);
		bool canAdd = true, canSubtract = true;
		if(playerId != 0 && g_bClientRanksAreLoaded[client] == true)
		{
			int oldRank;
			if(g_bClientIsRankedOverall[client])
			{
				oldRank = g_OverallRank[client] - 1;
			}
			else
			{
				oldRank = iSize - 1;
			}
			
			do
			{
				if(oldRank - subtracted < 0)
				{
					canSubtract = false;
				}
				else if(oldRank + added >= iSize)
				{
					canAdd = false;
				}
				
				if(canAdd)
				{
					if(GetArrayCell(g_hOverallRanks, oldRank + added, 0) == playerId)
					{
						g_OverallRank[client] = oldRank + added + 1;
						g_bClientIsRankedOverall[client] = true;
						canAdd      = false;
						canSubtract = false;
						break;
					}
					
					added++;
				}
				else if(canSubtract)
				{
					if(GetArrayCell(g_hOverallRanks, oldRank - subtracted, 0) == playerId)
					{
						g_OverallRank[client] = oldRank - subtracted + 1;
						g_bClientIsRankedOverall[client] = true;
						canAdd      = false;
						canSubtract = false;
						break;
					}
					
					subtracted++;
				}
			}
			while(canAdd == true || canSubtract == true);
			
			//LogMessage("%N: old: %d, new: %d", client, oldRank + 1, g_OverallRank[client]);
			if(g_bClientIsRankedOverall[client] && oldRank + 1 != g_OverallRank[client])
			{
				Call_StartForward(g_hOnClientOverallRankChanged);
				Call_PushCell(client);
				Call_PushCell(oldRank + 1);
				Call_PushCell(g_OverallRank[client]);
				Call_Finish();
			}
		}
	}
}

public void OnClientOverallRankChanged(int client, int oldRank, int newRank)
{
	if(newRank < oldRank)
	{
		PrintColorText(client, "%s%sYou are now rank %s%d%s.",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			newRank,
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%sYou deranked from rank %s%d%s to %s%d%s.",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			oldRank,
			g_msg_textcol,
			g_msg_varcol,
			newRank,
			g_msg_textcol);
	}
	
}

void UpdateClientStyleRanks()
{
	int playerId, added, subtracted;
	bool canAdd = true, canSubtract = true;
	for(int client = 1; client <= MaxClients; client++)
	{
		playerId = GetPlayerID(client);
		if(playerId != 0 && g_bClientRanksAreLoaded[client] == true)
		{
			for(int type; type < MAX_TYPES; type++)
			{
				for(int style; style < MAX_STYLES; style++)
				{
					if(!g_bShouldRecalculate[type][style])
						continue;
						
					int oldRank;
					if(g_bClientIsRankedStyle[client][type][style])
					{
						oldRank = g_StyleRank[client][type][style] - 1;
					}
					else
					{
						oldRank = GetArraySize(g_hStyleRanks[type][style]) - 1;
					}
			
					do
					{
						if(oldRank - subtracted < 0)
						{
							canSubtract = false;
						}
						else if(oldRank + added >= GetArraySize(g_hStyleRanks[type][style]))
						{
							canAdd = false;
						}
						if(GetArraySize(g_hStyleRanks[type][style]) == 0)
						{
							canAdd = false;
							canSubtract = false;
						}
						
						if(canAdd)
						{
							if(GetArrayCell(g_hStyleRanks[type][style], oldRank + added, 0) == playerId)
							{
								g_StyleRank[client][type][style] = oldRank + added + 1;
								g_bClientIsRankedStyle[client][type][style] = true;
								canAdd      = false;
								canSubtract = false;
							}
							
							added++;
						}
						else if(canSubtract)
						{
							if(GetArrayCell(g_hStyleRanks[type][style], oldRank - subtracted, 0) == playerId)
							{
								g_StyleRank[client][type][style] = oldRank - subtracted + 1;
								g_bClientIsRankedStyle[client][type][style] = true;
								canAdd      = false;
								canSubtract = false;
							}
							
							subtracted++;
						}
					}
					while(canAdd == true || canSubtract == true);
					
					if(g_bClientIsRankedStyle[client][type][style] && oldRank + 1 != g_StyleRank[client][type][style])
					{
						Call_StartForward(g_hOnClientStyleRankChanged);
						Call_PushCell(client);
						Call_PushCell(oldRank + 1);
						Call_PushCell(g_StyleRank[client][type][style]);
						Call_PushCell(type);
						Call_PushCell(style);
						Call_Finish();
					}
				}
			}
		}
	}
	
	for(int type; type < MAX_TYPES; type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			g_bShouldRecalculate[type][style] = false;
		}
	}
}

public int Native_GetClientOverallRecordRank(Handle plugin, int numParams)
{
	return g_WRRank[GetNativeCell(1)];
}

public int Native_GetOverallRank(Handle plugin, int numParams)
{
	return g_OverallRank[GetNativeCell(1)];
}

public int Native_GetStyleRank(Handle plugin, int numParams)
{
	return g_StyleRank[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)];
}

public int Native_GetTotalOverallRanks(Handle plugin, int numParams)
{
	return GetArraySize(g_hOverallRanks);
}

public int Native_GetTotalStyleRanks(Handle plugin, int numParams)
{
	return GetArraySize(g_hStyleRanks[GetNativeCell(1)][GetNativeCell(2)]);
}

public int Native_IsClientRankedOverall(Handle plugin, int numParams)
{
	return g_bClientIsRankedOverall[GetNativeCell(1)];
}

public int Native_IsClientRankedStyle(Handle plugin, int numParams)
{
	return g_bClientIsRankedStyle[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)];
}

public int Native_IsClientRankLoaded(Handle plugin, int numParams)
{
	return g_bClientRanksAreLoaded[GetNativeCell(1)];
}