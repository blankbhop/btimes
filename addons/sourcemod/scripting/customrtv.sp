#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <bTimes-core>

#undef REQUIRE_PLUGIN
#include <cvarenf>
#include <bTimes-rank2>

public Plugin myinfo = 
{
    name = "Blacky RTV",
    author = "blacky",
	description = "Custom RTV plugin",
	version = "1.0",
	url = "http://steamcommunity.com/id/blaackyy/"
}

#define VOTETYPE_RTV 0
#define VOTETYPE_NEXTMAP 1

#define TIERORDER_RANDOM 0
#define TIERORDER_ASCENDING 1
#define TIERORDER_DESCENDING 2

#define EBM_MAIN 0
#define EBM_TIER 1

bool g_ClientRTVd[MAXPLAYERS + 1];
int g_iNominateBackMenu[MAXPLAYERS + 1];

ConVar g_hRequiredPercentage;
ConVar g_hSpecsCanRTV;
ConVar g_hUnrankedCanRTV;
ConVar g_hAllowRTVTime;
ConVar g_hNextMapVoteTime;
ConVar g_hMaxRecentlyPlayed;
ConVar g_hMaxExtensions;
ConVar g_hShowDontChange;
ConVar g_hShowExtend;
ConVar g_hExtendTime;
ConVar g_hNumberOfMaps;
ConVar g_hNoVote;
ConVar g_hTierCount[5];
ConVar g_hUseTierCount;
ConVar g_hTierOrder;

Database g_DB;
int g_iMaxExtensions;
bool g_bShowExtend;
int g_iExtendTime;
bool g_bShowDontChange;
int g_iNumberOfMaps;
bool g_bNoVote;
int g_iExtends;
int g_iTierCount[5];
bool g_bUseTierCount;
int g_iTierOrder;
bool  g_bAllowRTV;
bool  g_bRTVInProgress;
bool  g_bMapChanging;
bool  g_bMapDecided;
bool  g_bConfigsExecuted;
float g_fMapStart;
float g_fLastVoteTime;
int   g_iVoteType;
int   g_iCountDown;
bool  g_bHasUnplayedMaps;
/*
- # of each tier to include (ideally variables that i can change)

for these, cvar would be nice, but can be hard coded if easier:
- # of consecutive extensions allowed (2)
- enable/disable 'dont change' for RTV vote (1)
- enable/disable 'extend map' for End-of-map vote (1)
*/

bool g_bCvarEnfIsLoaded;
bool g_bRanksLoaded;
EngineVersion g_Engine;

ArrayList g_hNominationsMaps;
ArrayList g_hNominationsClients;
ArrayList g_hMapList;
ArrayList g_hTierList;
ArrayList g_hRecentlyPlayed;
ArrayList g_hSeparatedTierList[5];
char g_sMap[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	DB_Connect();
	
	g_Engine = GetEngineVersion();
	
	g_hRequiredPercentage = CreateConVar("rtv_percent", "0.51", "Required percentage of rtvs for a vote to start.", 0, true, 0.0, true, 1.0);
	g_hSpecsCanRTV        = CreateConVar("rtv_specscanrtv", "0", "Allows spectators to rtv.", 0, true, 0.0, true, 1.0);
	g_hUnrankedCanRTV     = CreateConVar("rtv_allowunranked", "0", "Allow unranked players to RTV.");
	g_hAllowRTVTime       = CreateConVar("rtv_allowrtvtime", "5", "Time until players are allowed to RTV in minutes.", 0, true, 0.0);
	g_hNextMapVoteTime    = CreateConVar("rtv_nextmapvotetime", "5", "How much time left in minutes should be left when the nextmap vote starts.");
	g_hMaxRecentlyPlayed  = CreateConVar("rtv_maxrecentlyplayed", "10", "How many maps must be played to nominate a map again.", 0, true, 0.0);
	g_hMaxExtensions      = CreateConVar("rtv_maxextends", "2", "How many extends to allow (0 = unlimited).", 0, true, 0.0);
	g_hShowExtend         = CreateConVar("rtv_showextend", "1", "Show the 'Extend' option end-of-map votes.", 0, true, 0.0);
	g_hExtendTime         = CreateConVar("rtv_extendtime", "20", "Time in minutes to extend map when the Extend option wins a map vote.", 0, true, 0.0, true, 999.0);
	g_hShowDontChange     = CreateConVar("rtv_showdontchage", "1", "Show the 'Don't Change' option in RTVs.", 0, true, 0.0);
	g_hNumberOfMaps       = CreateConVar("rtv_numberofmaps", "7", "Number of maps to display in the vote menu.", 0, true, 0.0);
	g_hNoVote             = CreateConVar("rtv_novoteoption", "1", "Show the 'No Vote' option in map votes.", 0, true, 0.0);
	g_hTierCount[0]       = CreateConVar("rtv_tier1count", "3", "Number of Tier 1 maps to display in the map votes.", 0, true, 0.0);
	g_hTierCount[1]       = CreateConVar("rtv_tier2count", "2", "Number of Tier 2 maps to display in the map votes.", 0, true, 0.0);
	g_hTierCount[2]       = CreateConVar("rtv_tier3count", "1", "Number of Tier 3 maps to display in the map votes.", 0, true, 0.0);
	g_hTierCount[3]       = CreateConVar("rtv_tier4count", "1", "Number of Tier 4 maps to display in the map votes.", 0, true, 0.0);
	g_hTierCount[4]       = CreateConVar("rtv_tier5count", "1", "Number of Tier 5 maps to display in the map votes.", 0, true, 0.0);
	g_hUseTierCount       = CreateConVar("rtv_usetiercounts", "1", "Use the tier counts when displaying the map votes, if 0 it will just be random maps.");
	g_hTierOrder          = CreateConVar("rtv_tierorder", "random", "Order to display maps if rtv_usetiercounts is set to 1. Options are: <random>, <ascending>, or <descending> - (By map tier value)");
	
	HookConVarChange(g_hMaxRecentlyPlayed, OnConvarChanged);
	HookConVarChange(g_hSpecsCanRTV, OnConvarChanged);
	HookConVarChange(g_hMaxExtensions, OnConvarChanged);
	HookConVarChange(g_hShowExtend, OnConvarChanged);
	HookConVarChange(g_hShowDontChange, OnConvarChanged);
	HookConVarChange(g_hNumberOfMaps, OnConvarChanged);
	HookConVarChange(g_hNoVote, OnConvarChanged);
	HookConVarChange(g_hUseTierCount, OnConvarChanged);
	HookConVarChange(g_hTierOrder, OnConvarChanged);
	HookConVarChange(g_hExtendTime, OnConvarChanged);
	for(int idx; idx < 5; idx++)
	{
		HookConVarChange(g_hTierCount[idx], OnConvarChanged);
	}
	
	AutoExecConfig(true, "customrtv", "sourcemod");

	HookEvent("player_team", Event_PlayerTeam);
	
	RegConsoleCmd("sm_rtv", SM_Rtv, "Rock the vote!");
	RegConsoleCmd("sm_unrtv", SM_UnRtv, "Cancel your RTV.");
	RegConsoleCmd("sm_nominate", SM_Nominate, "Nominate a map.");
	RegConsoleCmd("sm_denominate", SM_DeNominate, "Remove your map nomination.");
	RegConsoleCmd("sm_withdraw", SM_DeNominate, "Remove your map nominations.");
	
	RegAdminCmd("sm_reloadmaps", SM_ReloadMaps, ADMFLAG_CONFIG, "Reload the map list.");
	RegAdminCmd("sm_startvote",  SM_StartVote, ADMFLAG_VOTE, "Start a map vote");
	RegAdminCmd("sm_extend", SM_Extend, ADMFLAG_GENERIC, "Admin command to extend the map.");
	RegAdminCmd("sm_rrvote", SM_RerollVote, ADMFLAG_GENERIC, "Rerolls the maps on the current vote.");
	RegAdminCmd("sm_rerollvote", SM_RerollVote, ADMFLAG_GENERIC, "Rerolls the maps on the current vote.");
	
	g_hNominationsMaps    = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hNominationsClients = CreateArray();
	g_hTierList           = CreateArray();
	g_hRecentlyPlayed     = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	for(int idx; idx < 5; idx++)
		g_hSeparatedTierList[idx] = CreateArray();
}

public Action SM_RerollVote(int client, int args)
{
	if(g_bRTVInProgress == false || IsVoteInProgress() == false)
	{
		PrintColorText(client, "%s%sThere is currently no map vote in progress.", g_msg_start, g_msg_textcol);
	}
	
	CancelVote();
	
	StartVote(g_iVoteType);
	
	PrintColorTextAll("%s%sThe map list in the map vote have been rerolled by an admin.", g_msg_start, g_msg_textcol);
	
	return Plugin_Handled;
}

public void OnConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_hMaxRecentlyPlayed)
	{
		while(g_hRecentlyPlayed.Length > convar.IntValue)
		{
			g_hRecentlyPlayed.Erase(0);
		}
	}
	else if(convar == g_hSpecsCanRTV)
	{
		if(convar.BoolValue == false)
		{
			for(int client = 1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client) && GetClientTeam(client) == 1 && g_ClientRTVd[client] == true)
				{
					g_ClientRTVd[client] = false;
				}
			}
			
			CheckVotes();
		}		
	}
	else if(convar == g_hMaxExtensions)
	{
		g_iMaxExtensions = convar.IntValue;
	}
	else if(convar == g_hShowExtend)
	{
		g_bShowExtend = convar.BoolValue;
	}
	else if(convar == g_hShowDontChange)
	{
		g_bShowDontChange = convar.BoolValue;
	}
	else if(convar == g_hNumberOfMaps)
	{
		g_iNumberOfMaps = convar.IntValue;
	}
	else if(convar == g_hNoVote)
	{
		g_bNoVote = convar.BoolValue;
	}
	else if(convar == g_hUseTierCount)
	{
		g_bUseTierCount = convar.BoolValue;
	}
	else if(convar == g_hTierOrder)
	{
		char sValue[32];
		convar.GetString(sValue, 32);
		if(StrEqual(sValue, "random", false))
		{
			g_iTierOrder = TIERORDER_RANDOM;
		}
		else if(StrEqual(sValue, "descending", false))
		{
			g_iTierOrder = TIERORDER_DESCENDING;
		}
		else if(StrEqual(sValue, "ascending", false))
		{
			g_iTierOrder = TIERORDER_ASCENDING;
		}
		else
		{
			g_iTierOrder = TIERORDER_RANDOM;
		}
	}
	else if(convar == g_hExtendTime)
	{
		g_iExtendTime = convar.IntValue;
	}
	else
	{
		for(int idx; idx < 5; idx++)
		{
			if(convar == g_hTierCount[idx])
			{
				g_iTierCount[idx] = convar.IntValue;
			}
		}
	}
}

public Action SM_ReloadMaps(int client, int args)
{
	ReadMapList(g_hMapList, _, "default", MAPLIST_FLAG_CLEARARRAY);
	RemoveStringFromArray(g_hMapList, g_sMap);
	
	if(g_bRanksLoaded && Ranks_AreTiersLoaded())
	{
		SyncMapTiers();
	}
	else
	{
		PrintColorText(client, "%s%sReloaded map list but couldn't sync the tiers because the ranks plugin is not loaded.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action SM_StartVote(int client, int args)
{
	StartVote(VOTETYPE_RTV);
	
	return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(late)
	{
		UpdateMessages();
	}
}

public void OnAllPluginsLoaded()
{
	g_bCvarEnfIsLoaded = LibraryExists("cvarenf");
	g_bRanksLoaded     = LibraryExists("ranks");
}

public void OnLibraryAdded(const char[] library)
{
	if(StrEqual(library, "cvarenf"))
	{
		g_bCvarEnfIsLoaded = true;
	}
	if(StrEqual(library, "ranks"))
	{
		g_bRanksLoaded = true;
	}
}

public void OnLibraryRemoved(const char[] library)
{
	if(StrEqual(library, "cvarenf"))
	{
		g_bCvarEnfIsLoaded = false;
	}
	if(StrEqual(library, "ranks"))
	{
		g_bRanksLoaded = false;
	}
}

public void OnMapEnd()
{
	g_bMapChanging     = false;
	g_bConfigsExecuted = false;
	ClearArray(g_hNominationsClients);
	ClearArray(g_hNominationsMaps);
}

public void OnMapStart()
{
	g_fMapStart      = GetEngineTime();
	g_bRTVInProgress = false;
	g_bAllowRTV      = false;
	g_bMapDecided    = false;
	g_iExtends       = 0;
	GetCurrentMap(g_sMap, PLATFORM_MAX_PATH);
	
	if(g_hMapList == INVALID_HANDLE)
	{
		g_hMapList = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	}
	ReadMapList(g_hMapList, _, "default", MAPLIST_FLAG_CLEARARRAY);
	RemoveStringFromArray(g_hMapList, g_sMap);
	
	if(g_bRanksLoaded && Ranks_AreTiersLoaded())
	{
		SyncMapTiers();
	}
	
	g_iCountDown = 10;
	
	PushArrayString(g_hRecentlyPlayed, g_sMap);
	
	if(g_hRecentlyPlayed.Length >= g_hMaxRecentlyPlayed.IntValue)
	{
		RemoveFromArray(g_hRecentlyPlayed, 0);
	}
}

public void OnConfigsExecuted()
{
	g_iMaxExtensions   = g_hMaxExtensions.IntValue;
	g_bShowExtend      = g_hShowExtend.BoolValue;
	g_bShowDontChange  = g_hShowDontChange.BoolValue;
	g_iNumberOfMaps    = g_hNumberOfMaps.IntValue;
	g_bNoVote          = g_hNoVote.BoolValue;
	g_bUseTierCount    = g_hUseTierCount.BoolValue;
	g_iExtendTime      = g_hExtendTime.IntValue;
	
	char sValue[32];
	g_hTierOrder.GetString(sValue, 32);
	if(StrEqual(sValue, "random", false))
	{
		g_iTierOrder = TIERORDER_RANDOM;
	}
	else if(StrEqual(sValue, "descending", false))
	{
		g_iTierOrder = TIERORDER_DESCENDING;
	}
	else if(StrEqual(sValue, "ascending", false))
	{
		g_iTierOrder = TIERORDER_ASCENDING;
	}
	else
	{
		g_iTierOrder = TIERORDER_RANDOM;
	}
	
	for(int i; i < 5; i++)
	{
		g_iTierCount[i] = g_hTierCount[i].IntValue;
	}
	g_bConfigsExecuted = true;
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

public void OnTierListLoaded()
{
	SyncMapTiers();
}

void SyncMapTiers()
{
	if(g_bRanksLoaded == false)
	{
		return;
	}
	
	if(Ranks_AreTiersLoaded() == false)
	{
		return;
	}
	
	g_bHasUnplayedMaps = false;

	ClearArray(g_hTierList);
	
	for(int i; i < 5; i++)
		ClearArray(g_hSeparatedTierList[i]);
	
	int iSize = GetArraySize(g_hMapList);
	char sMap[PLATFORM_MAX_PATH];
	for(int idx; idx < iSize; idx++)
	{
		GetArrayString(g_hMapList, idx, sMap, PLATFORM_MAX_PATH);
		
		int tier = Ranks_GetMapTier(sMap);
		
		PushArrayCell(g_hTierList, tier);
		
		if(tier != -1)
		{
			PushArrayCell(g_hSeparatedTierList[tier - 1], idx);
		}
		else
		{
			g_bHasUnplayedMaps = true;
		}
	}
}

public void OnClientDisconnect(int client)
{
	if(g_ClientRTVd[client] == true)
	{
		g_ClientRTVd[client] = false;
	}
	
	if(ClientHasNominatedAMap(client))
	{
		CRemoveNominationByClient(client);
	}
}

public void OnClientDisconnect_Post(int client)
{
	CheckVotes();
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if(GetConVarBool(g_hSpecsCanRTV) == true)
	{
		return;
	}
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(client != 0)
	{
		int newTeam = GetEventInt(event, "team");
		
		if(newTeam == 1)
		{
			if(g_ClientRTVd[client] == true)
			{
				g_ClientRTVd[client] = false;
			}
		}
		
		if(!IsFakeClient(client))
		{
			CheckVotes();
		}
	}
}

public void OnClientOverallRankChanged(int client, int oldRank, int newRank)
{
	CheckVotes();
}

public Action SM_DeNominate(int client, int args)
{
	if(ClientHasNominatedAMap(client))
	{
		CRemoveNominationByClient(client);
		
		PrintColorTextAll("%s%s%N%s removed their nomination.", 
			g_msg_start,
			g_msg_varcol,
			client,
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%sYou don't have any maps nominated.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action SM_Nominate(int client, int args)
{
	if(args == 0)
	{
		OpenNominateMenu_Category(client);
		//OpenNominateMenu_Category(client, g_hMapList, g_hTierList);
	}
	else
	{
		char sArg[PLATFORM_MAX_PATH];
		GetCmdArg(1, sArg, sizeof(sArg));
		CNominateMap(client, sArg);
	}
	
	return Plugin_Handled;
}

void OpenNominateMenu_Category(int client)
{
	Menu menu = new Menu(Menu_NominateCategory);
	menu.SetTitle("Nomination categories");
	menu.AddItem("cycle", "All maps");
	menu.AddItem("tiers", "Tiers");
	menu.AddItem("mapsleft", "Maps not completed");
	menu.AddItem("unplayed", "Maps not played on server", g_bHasUnplayedMaps?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_NominateCategory(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sCat[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sCat, sizeof(sCat));

		if(StrEqual(sCat, "cycle"))
		{
			g_iNominateBackMenu[client] = EBM_MAIN;
			OpenNominateMenu(client, g_hMapList, g_hTierList);
		}
		else if(StrEqual(sCat, "tiers"))
		{
			g_iNominateBackMenu[client] = EBM_TIER;
			OpenNominateByTiersMenu(client);
		}
		else if(StrEqual(sCat, "mapsleft"))
		{
			g_iNominateBackMenu[client] = EBM_MAIN;
			OpenNominateByMapsLeftMenu(client);
		}
		else if(StrEqual(sCat, "unplayed"))
		{
			g_iNominateBackMenu[client] = EBM_MAIN;
			OpenNominateByUnplayed(client);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void OpenNominateMenu(int client, ArrayList maps, ArrayList tiers)
{
	Menu menu = new Menu(Menu_Nominate);
	menu.SetTitle("Nominate a map");
	
	char sCurrentMap[PLATFORM_MAX_PATH];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	RemoveStringFromArray(maps, sCurrentMap);
	
	int iSize = GetArraySize(maps);
	char sMap[PLATFORM_MAX_PATH], sDisplay[PLATFORM_MAX_PATH];
	for(int idx; idx < iSize; idx++)
	{
		bool bRecentlyPlayed = false;
		GetArrayString(maps, idx, sMap, sizeof(sMap));
		FormatEx(sDisplay, sizeof(sDisplay), sMap);
		int tier = GetArrayCell(tiers, idx);
		
		if(tier != -1)
		{
			FormatEx(sDisplay, sizeof(sDisplay), "%s - [Tier %d]", sMap, tier);
		}
		
		if(FindStringInArray(g_hRecentlyPlayed, sMap) != -1)
		{
			bRecentlyPlayed = true;
			Format(sDisplay, sizeof(sDisplay), "%s (Recently played)", sDisplay);
		}
		
		menu.AddItem(sMap, sDisplay, bRecentlyPlayed?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}
	
	menu.ExitButton     = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Nominate(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sMap[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sMap, sizeof(sMap));
		
		if(ClientHasNominatedAMap(client) == false)
		{
			PrintColorTextAll("%s%s%N%s nominated %s%s%s.",
				g_msg_start,
				g_msg_varcol,
				client,
				g_msg_textcol,
				g_msg_varcol,
				sMap,
				g_msg_textcol);
		}
		else
		{
			PrintColorTextAll("%s%s%N%s changed their nomination to %s%s%s.",
				g_msg_start,
				g_msg_varcol,
				client,
				g_msg_textcol,
				g_msg_varcol,
				sMap,
				g_msg_textcol);
			CRemoveNominationByClient(client);
		}
		
		PushArrayString(g_hNominationsMaps, sMap);
		PushArrayCell(g_hNominationsClients, client);
	}
	
	if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		if(g_iNominateBackMenu[client] == EBM_MAIN)
		{
			OpenNominateMenu_Category(client);
		}
		else if(g_iNominateBackMenu[client] == EBM_TIER)
		{
			OpenNominateByTiersMenu(client);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void OpenNominateByTiersMenu(int client)
{
	Menu menu = new Menu(Menu_NominateTiers);
	menu.SetTitle("Select Tier");
	menu.AddItem("0", "Tier 1");
	menu.AddItem("1", "Tier 2");
	menu.AddItem("2", "Tier 3");
	menu.AddItem("3", "Tier 4");
	menu.AddItem("4", "Tier 5");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_NominateTiers(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sCat[8];
		menu.GetItem(param2, sCat, sizeof(sCat));
		int tier = StringToInt(sCat);
		
		ArrayList mapList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
		ArrayList tierList = new ArrayList();
		
		int iSize = g_hSeparatedTierList[tier].Length;
		if(iSize == 0)
		{
			PrintColorText(client, "%s%sNo %sTier %d%s maps found.", g_msg_start, g_msg_textcol, g_msg_varcol, tier, g_msg_textcol);
			OpenNominateByTiersMenu(client);
		}
		else
		{
			char sMap[PLATFORM_MAX_PATH];
			
			for(int idx; idx < iSize; idx++)
			{
				g_hMapList.GetString(g_hSeparatedTierList[tier].Get(idx), sMap, PLATFORM_MAX_PATH);
				mapList.PushString(sMap);
				tierList.Push(tier + 1);
			}

			OpenNominateMenu(client, mapList, tierList);
		}
		
		delete mapList;
		delete tierList;
	}
	
	if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenNominateMenu_Category(client);
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void OpenNominateByMapsLeftMenu(int client)
{
	int playerId = GetPlayerID(client);
	if(playerId == 0)
	{
		PrintColorText(client, "%s%sYour timer PlayerID has not loaded yet.", g_msg_start, g_msg_textcol);
		return;
	}
	else
	{
		char sQuery[512];
		FormatEx(sQuery, 512, "SELECT t2.MapName, t2.Tier FROM \
			(SELECT maps.MapID AS MapID1, t1.MapID AS MapID2 FROM maps LEFT JOIN \
			(SELECT MapID FROM times WHERE Type=0 AND tas=0 AND PlayerID=%d) \
			t1 ON maps.MapID=t1.MapID) \
			AS t1, maps AS t2 WHERE InMapCycle=1 AND t1.MapID1=t2.MapID AND t1.MapID2 IS NULL ORDER BY t2.MapName",
			playerId);
		SQL_TQuery(g_DB, DB_NominateMapsLeft_Callback, sQuery, GetClientUserId(client));
	}
}

public void DB_NominateMapsLeft_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl != INVALID_HANDLE)
	{
		int client = GetClientOfUserId(data);
		if(client != 0)
		{
			ArrayList mapList  = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
			ArrayList tierList = new ArrayList();
			char sMap[PLATFORM_MAX_PATH];
			while(SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, sMap, PLATFORM_MAX_PATH);
				mapList.PushString(sMap);
				tierList.Push(SQL_FetchInt(hndl, 1));
			}
			
			if(mapList.Length == 0)
			{
				PrintColorText(client, "%s%sLooks like you have no maps left. Good job!", g_msg_start, g_msg_textcol);
			}
			else
			{
				OpenNominateMenu(client, mapList, tierList);
			}
			
			delete mapList;
			delete tierList;
		}
	}
	else
	{
		LogError(error);
	}
}

void OpenNominateByUnplayed(int client)
{
	ArrayList mapList  = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	ArrayList tierList = new ArrayList();
	
	int iSize = g_hMapList.Length;
	char sMap[PLATFORM_MAX_PATH];
	for(int idx; idx < iSize; idx++)
	{
		if(g_hTierList.Get(idx) == -1)
		{
			g_hMapList.GetString(idx, sMap, PLATFORM_MAX_PATH);
			mapList.PushString(sMap);
			tierList.Push(-1);
		}
	}
	
	OpenNominateMenu(client, mapList, tierList);
	
	delete mapList;
	delete tierList;
}

bool IsInMapCycle(const char[] map)
{
	return FindStringInArray(g_hMapList, map) != -1;
}

bool CNominateMap(int client, const char[] sMap)
{
	int mapIndex;
	if(StrEqual(sMap, g_sMap))
	{
		PrintColorText(client, "%s%sYou cannot nominate the current map.",
			g_msg_start,
			g_msg_textcol);
		
		return false;
	}
	
	ArrayList hMaps = new ArrayList(PLATFORM_MAX_PATH);
	ArrayList hTiers = new ArrayList();
	int iSize = g_hMapList.Length;
	char sMapCmp[PLATFORM_MAX_PATH];
	
	for(int idx; idx < iSize; idx++)
	{
		g_hMapList.GetString(idx, sMapCmp, PLATFORM_MAX_PATH);
		
		if(StrContains(sMapCmp, sMap, false) != -1)
		{
			PushArrayString(hMaps, sMapCmp);
			PushArrayCell(hTiers, GetArrayCell(g_hTierList, idx));
		}
	}
	
	if(hMaps.Length == 0)
	{
		PrintColorText(client, "%s%sNomination failed because no map in the mapcycle contains the string you entered.",
			g_msg_start,
			g_msg_textcol);
		
		return false;
	}
	else if(hMaps.Length == 1)
	{
		hMaps.GetString(0, sMapCmp, PLATFORM_MAX_PATH);
			
		if((mapIndex = FindStringInArray(g_hRecentlyPlayed, sMapCmp)) != -1)
		{
			int mapsLeft = g_hMaxRecentlyPlayed.IntValue - mapIndex;
			PrintColorText(client, "%s%sCouldn't nominate %s%s%s because it was recently played. Try again in %s%d%s map(s).",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sMapCmp,
				g_msg_textcol,
				g_msg_varcol,
				mapsLeft,
				g_msg_textcol);
				
			return false;
		}
		
		if(CIsMapNominated(sMapCmp))
		{
			PrintColorText(client, "%s%s%s%s is already nominated.",
				g_msg_start,
				g_msg_varcol,
				sMapCmp,
				g_msg_textcol);
				
			return false;
		}
		
		if(ClientHasNominatedAMap(client) == false)
		{
			PrintColorTextAll("%s%s%N%s nominated %s%s%s.",
				g_msg_start,
				g_msg_varcol,
				client,
				g_msg_textcol,
				g_msg_varcol,
				sMapCmp,
				g_msg_textcol);
		}
		else
		{
			PrintColorTextAll("%s%s%N%s changed their nomination to %s%s%s.",
				g_msg_start,
				g_msg_varcol,
				client,
				g_msg_textcol,
				g_msg_varcol,
				sMapCmp,
				g_msg_textcol);
			CRemoveNominationByClient(client);
		}
		
		PushArrayString(g_hNominationsMaps, sMapCmp);
		PushArrayCell(g_hNominationsClients, client);
	}
	else
	{
		OpenNominateMenu(client, hMaps, hTiers);
	}
	
	delete hMaps;
	delete hTiers;

	
	return true;
}

bool ClientHasNominatedAMap(int client)
{
	int iSize = GetArraySize(g_hNominationsClients);
	
	for(int idx; idx < iSize; idx++)
	{
		if(GetArrayCell(g_hNominationsClients, idx) == client)
		{
			return true;
		}
	}
	
	return false;
}

void CRemoveNominationByClient(int client)
{
	int iSize = GetArraySize(g_hNominationsClients);
	
	for(int idx; idx < iSize; idx++)
	{
		if(GetArrayCell(g_hNominationsClients, idx) == client)
		{
			RemoveFromArray(g_hNominationsClients, idx);
			RemoveFromArray(g_hNominationsMaps, idx);
			return;
		}
	}
}

stock void CRemoveNominationByMap(const char[] sMap)
{
	int iSize = GetArraySize(g_hNominationsClients);
	char sIdxMap[PLATFORM_MAX_PATH];
	
	for(int idx; idx < iSize; idx++)
	{
		GetArrayString(g_hNominationsMaps, idx, sIdxMap, sizeof(sIdxMap));
		if(StrEqual(sIdxMap, sMap))
		{
			RemoveFromArray(g_hNominationsClients, idx);
			RemoveFromArray(g_hNominationsMaps, idx);
		}
	}
}

bool CIsMapNominated(const char[] sMap)
{
	int iSize = GetArraySize(g_hNominationsClients);
	char sIdxMap[PLATFORM_MAX_PATH];
	
	for(int idx; idx < iSize; idx++)
	{
		GetArrayString(g_hNominationsMaps, idx, sIdxMap, sizeof(sIdxMap));
		if(StrEqual(sIdxMap, sMap))
		{
			return true;
		}
	}
	
	return false;
}

public Action SM_Extend(int client, int args)
{
	if(args == 0)
	{
		PrintColorText(client, "%s%sUsage: %ssm_extend <minutes>%s.", g_msg_start, g_msg_textcol, g_msg_varcol, g_msg_textcol);
	}
	else
	{
		char sArg[32];
		GetCmdArg(1, sArg, 32);
		int min = StringToInt(sArg);
		
		if(min <= 0 || min > 120)
		{
			PrintColorText(client, "%s%sCan not extend with negative values nor for more than 2 hours at a time.", g_msg_start, g_msg_textcol);
			return Plugin_Handled;
		}
		
		ExtendMap(min);
	}
	
	return Plugin_Handled;
}

public Action SM_Rtv(int client, int args)
{
	if(AttemptRTV(client))
	{
		CheckVotes();
	}
	
	return Plugin_Handled;
}

public Action SM_UnRtv(int client, int args)
{
	if(g_ClientRTVd[client] == true)
	{
		g_ClientRTVd[client] = false;
		
		int voteCount = GetVoteCount();
		
		PrintColorText(client, "%s%sYou canceled your vote. (%s%d%s %s, %s%d%s required.)",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			voteCount,
			g_msg_textcol,
			voteCount == 1?"vote":"votes",
			g_msg_varcol,
			GetVotesRequired(),
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(StrEqual(sArgs, "rtv") || StrEqual(sArgs, "rockthevote") || StrEqual(sArgs, "rockthetits"))
	{
		if(AttemptRTV(client))
		{
			CheckVotes();
		}
	}
	else if(StrEqual(sArgs, "unrtv"))
	{
		SetCmdReplySource(SM_REPLY_TO_CHAT);
		if(g_ClientRTVd[client] == true)
		{
			g_ClientRTVd[client] = false;
			
			int voteCount = GetVoteCount();
			
			PrintColorText(client, "%s%sYou canceled your vote. (%s%d%s %s, %s%d%s required.)",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				voteCount,
				g_msg_textcol,
				voteCount == 1?"vote":"votes",
				g_msg_varcol,
				GetVotesRequired(),
				g_msg_textcol);
		}
	}
	else if(StrEqual(sArgs, "nominate"))
	{
		OpenNominateMenu(client, g_hMapList, g_hTierList);
	}
	else if(StrEqual(sArgs, "denominate") || StrEqual(sArgs, "withdraw"))
	{
		if(ClientHasNominatedAMap(client))
		{
			CRemoveNominationByClient(client);
			
			PrintColorTextAll("%s%s%N%s removed their nomination.", 
				g_msg_start,
				g_msg_varcol,
				client,
				g_msg_textcol);
		}
		else
		{
			PrintColorText(client, "%s%sYou don't have any maps nominated.",
				g_msg_start,
				g_msg_textcol);
		}
	}
}

bool AttemptRTV(int client)
{
	if(!IsClientInGame(client))
	{
		g_ClientRTVd[client] = false;
		
		return false;
	}
	
	if(!g_bAllowRTV)
	{
		PrintColorText(client, "%s%sRTV is not allowed yet.",
			g_msg_start,
			g_msg_textcol);
		
		return false;
	}

	if(g_bRTVInProgress)
	{
		PrintColorText(client, "%s%sA vote is already in progress.",
			g_msg_start,
			g_msg_textcol);
		
		return false;
	}
	
	if(g_bMapChanging)
	{
		PrintColorText(client, "%s%sThe map is already changing.",
			g_msg_start,
			g_msg_textcol);
		
		return false;
	}
	
	if(g_ClientRTVd[client] == true)
	{
		int voteCount = GetVoteCount();
			
		PrintColorText(client, "%s%sYou already voted. (%s%d%s %s, %s%d%s required.)",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				voteCount,
				g_msg_textcol,
				voteCount == 1?"vote":"votes",
				g_msg_varcol,
				GetVotesRequired(),
				g_msg_textcol);
			
		return false;
	}
	
	if(!(GetConVarBool(g_hSpecsCanRTV) || GetClientTeam(client) > 1))
	{
		int voteCount = GetVoteCount();
			
		PrintColorText(client, "%s%sSpectators are not allowed to RTV. (%s%d%s %s, %s%d%s required.)",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			voteCount,
			g_msg_textcol,
			voteCount == 1?"vote":"votes",
			g_msg_varcol,
			GetVotesRequired(),
			g_msg_textcol);
		
		return false;
	}
	
	if(g_bRanksLoaded)
	{
		if(!(GetConVarBool(g_hUnrankedCanRTV) || Ranks_IsClientRankedOverall(client)))
		{
			int voteCount = GetVoteCount();
				
			PrintColorText(client, "%s%sUnranked players are not allowed to RTV. (%s%d%s %s, %s%d%s required.)",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				voteCount,
				g_msg_textcol,
				voteCount == 1?"vote":"votes",
				g_msg_varcol,
				GetVotesRequired(),
				g_msg_textcol);
			
			return false;
		}
	}
	
	
	g_ClientRTVd[client] = true;
		
	int voteCount = GetVoteCount();
		
	PrintColorTextAll("%s%s%N%s voted to rock the vote. (%s%d%s %s, %s%d%s required.)",
		g_msg_start,
		g_msg_varcol,
		client,
		g_msg_textcol,
		g_msg_varcol,
		voteCount,
		g_msg_textcol,
		voteCount == 1?"vote":"votes",
		g_msg_varcol,
		GetVotesRequired(),
		g_msg_textcol);
	
	return true;
}

void CheckVotes()
{
	if(g_bAllowRTV && GetVoteCount() >= GetVotesRequired())
	{
		if(!g_bMapDecided)
		{
			StartVote(VOTETYPE_RTV);
		}
		else
		{
			char sNextMap[PLATFORM_MAX_PATH];
			if(GetNextMap(sNextMap, PLATFORM_MAX_PATH))
			{
				g_bMapChanging = true;
			
				ConVar cNextMap = FindConVar("sm_nextmap");
				if(cNextMap != null)
				{
					cNextMap.Flags &= ~FCVAR_NOTIFY;
				}
				delete cNextMap;
				
				PrintColorTextAll("%s%sThe vote has been rocked. Map changing to %s%s%s.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sNextMap,
					g_msg_textcol);
					
				ServerCommand("sm_map %s", sNextMap);
			}
			
		}
		
	}
}

void AttemptStartVoteLater(int voteType)
{
	CreateTimer(5.0, Timer_StartVote, voteType, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_StartVote(Handle timer, any data)
{
	StartVote(data);
}

void StartVote(int voteType)
{
	if(IsVoteInProgress() == true)
	{
		AttemptStartVoteLater(voteType);
		return;
	}
	
	if(g_bMapChanging == true)
	{
		return;
	}
	
	g_bRTVInProgress = true;
	g_iVoteType      = voteType;
	g_fLastVoteTime  = GetEngineTime();

	Menu menu = new Menu(Menu_Vote);
	
	if(g_bNoVote)
	{
		menu.OptionFlags |= MENUFLAG_BUTTON_NOVOTE;
	}

	menu.SetTitle("Vote for the next map\n ");
	menu.VoteResultCallback = Menu_VoteFinished;
	
	ArrayList hAdded = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	
	int iNominationSize = GetArraySize(g_hNominationsMaps);
	char sMap[PLATFORM_MAX_PATH], sDisplay[PLATFORM_MAX_PATH];

	int itemsAdded;
	for(int idx; idx < iNominationSize && itemsAdded < g_iNumberOfMaps; idx++)
	{
		GetArrayString(g_hNominationsMaps, idx, sMap, sizeof(sMap));
		
		if(FindStringInArray(hAdded, sMap) == -1)
		{
			if(g_bRanksLoaded)
			{
				int hMapsIdx = FindStringInArray(g_hMapList, sMap);
				
				if(hMapsIdx != -1)
				{
					int tier = GetArrayCell(g_hTierList, hMapsIdx);
					
					if(tier != -1)
					{
						FormatEx(sDisplay, sizeof(sDisplay), "%s - [Tier %d]", sMap, tier);
						menu.AddItem(sMap, sDisplay);
					}
					else
					{
						menu.AddItem(sMap, sMap);
					}
				}
			}
			else
			{
				menu.AddItem(sMap, sMap);
			}
			
			PushArrayString(hAdded, sMap);
			itemsAdded++;
		}
	}
	
	int rand, iSize = GetArraySize(g_hMapList);
	
	if(g_bUseTierCount == false || g_bRanksLoaded == false)
	{
		for(int idx; idx < iSize && itemsAdded < g_iNumberOfMaps; idx++)
		{
			rand = GetRandomInt(0, iSize - 1);
			GetArrayString(g_hMapList, rand, sMap, sizeof(sMap));
			
			if(FindStringInArray(g_hRecentlyPlayed, sMap) != -1)
				continue;
			
			if(FindStringInArray(hAdded, sMap) == -1)
			{
				if(g_bRanksLoaded)
				{
					int hMapsIdx = FindStringInArray(g_hMapList, sMap);
					
					if(hMapsIdx != -1)
					{
						int tier = GetArrayCell(g_hTierList, hMapsIdx);
						
						if(tier != -1)
						{
							FormatEx(sDisplay, sizeof(sDisplay), "%s - [Tier %d]", sMap, tier);
							menu.AddItem(sMap, sDisplay);
						}
						else
						{
							menu.AddItem(sMap, sMap);
						}
					}
				}
				else
				{
					menu.AddItem(sMap, sMap);
				}
				
				PushArrayString(hAdded, sMap);
				itemsAdded++;
			}
		}
	}
	else
	{
		ArrayList t = new ArrayList();
		
		for(int i; i < 5; i++)
		{
			for(int x; x < g_iTierCount[i]; x++)
			{
				t.Push(i + 1);
			}
		}
		
		if(g_iTierOrder == TIERORDER_RANDOM)
		{
			int randTier, mapIndex, tierIndex;

			for(; t.Length > 0 && itemsAdded < g_iNumberOfMaps;)
			{
				tierIndex = GetRandomInt(0, t.Length - 1);
				randTier  = t.Get(tierIndex);
				mapIndex  = GetRandomInt(0, g_hSeparatedTierList[randTier - 1].Length - 1);
				mapIndex  = g_hSeparatedTierList[randTier - 1].Get(mapIndex);
				g_hMapList.GetString(mapIndex, sMap, PLATFORM_MAX_PATH);
				
				if(FindStringInArray(g_hRecentlyPlayed, sMap) != -1)
					continue;
					
				if(FindStringInArray(hAdded, sMap) != -1)
					continue;
				
				FormatEx(sDisplay, sizeof(sDisplay), "%s - [Tier %d]", sMap, randTier);
				menu.AddItem(sMap, sDisplay);
				
				itemsAdded++;
				hAdded.PushString(sMap);
				t.Erase(tierIndex);
			}
		}
		else if(g_iTierOrder == TIERORDER_ASCENDING)
		{
			int tier, mapIndex, tierIndex;

			for(; t.Length > 0 && itemsAdded < g_iNumberOfMaps;)
			{
				tierIndex = 0
				tier  = t.Get(tierIndex);
				mapIndex  = GetRandomInt(0, g_hSeparatedTierList[tier - 1].Length - 1);
				mapIndex  = g_hSeparatedTierList[tier - 1].Get(mapIndex);
				g_hMapList.GetString(mapIndex, sMap, PLATFORM_MAX_PATH);
				
				if(FindStringInArray(g_hRecentlyPlayed, sMap) != -1)
					continue;
					
				if(FindStringInArray(hAdded, sMap) != -1)
					continue;
				
				FormatEx(sDisplay, sizeof(sDisplay), "%s - [Tier %d]", sMap, tier);
				menu.AddItem(sMap, sDisplay);
				
				itemsAdded++;
				hAdded.PushString(sMap);
				t.Erase(tierIndex);
			}
		}
		else if(g_iTierOrder == TIERORDER_DESCENDING)
		{
			int tier, mapIndex, tierIndex;

			for(; t.Length > 0 && itemsAdded < g_iNumberOfMaps;)
			{
				tierIndex = t.Length - 1;
				tier  = t.Get(tierIndex);
				mapIndex  = GetRandomInt(0, g_hSeparatedTierList[tier - 1].Length - 1);
				mapIndex  = g_hSeparatedTierList[tier - 1].Get(mapIndex);
				g_hMapList.GetString(mapIndex, sMap, PLATFORM_MAX_PATH);
				
				if(FindStringInArray(g_hRecentlyPlayed, sMap) != -1)
					continue;
					
				if(FindStringInArray(hAdded, sMap) != -1)
					continue;
				
				FormatEx(sDisplay, sizeof(sDisplay), "%s - [Tier %d]", sMap, tier);
				menu.AddItem(sMap, sDisplay);
				
				itemsAdded++;
				hAdded.PushString(sMap);
				t.Erase(tierIndex);
			}
		}
		
		delete t;
	}
	
	if(voteType == VOTETYPE_NEXTMAP && g_bShowExtend && (g_iMaxExtensions == 0 || g_iExtends < g_iMaxExtensions))
	{
		menu.AddItem("extend", "Extend Map");
	}
	else if(voteType == VOTETYPE_RTV && g_bShowDontChange)
	{
		menu.AddItem("dontchange", "Don't Change");
	}
	
	menu.Pagination = MENU_NO_PAGINATION;
	menu.ExitButton = false;
	
	menu.DisplayVoteToAll(25);
	
	if(voteType == VOTETYPE_RTV)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			g_ClientRTVd[client] = false;
		}
	}
	
	delete hAdded;
}

bool RemoveStringFromArray(ArrayList array, const char[] str)
{
	int index = FindStringInArray(array, str);
	if (index != -1)
	{
		RemoveFromArray(array, index);
		return true;
	}
	
	return false;
}

public int Menu_Vote(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				PrintColorTextAll("%s%sVoting has ended. No one voted, map extended 10 minutes.",
					g_msg_start,
					g_msg_textcol);
				ExtendMap(10);
				g_bRTVInProgress = false;
			}
			else if(param1 == VoteCancel_Generic)
			{
				g_bRTVInProgress = false;
			}
		}
		case MenuAction_VoteEnd:
		{
			
		}
	}
}

public void Menu_VoteFinished(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char sInfo[PLATFORM_MAX_PATH];
	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], sInfo, sizeof(sInfo));
	if(StrEqual(sInfo, "extend"))
	{
		PrintColorTextAll("%s%sThe map has been extended by 20 minutes!",
			g_msg_start,
			g_msg_textcol);
		ExtendMap(g_iExtendTime);
		g_iExtends++;
	}
	else if(StrEqual(sInfo, "dontchange"))
	{
		PrintColorTextAll("%s%sMap voting finished! %s'Don't change'%s option won, map will not change.",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
	}
	else
	{
		PrintColorTextAll("%s%sMap voting has finished! The next map will be %s%s%s.",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			sInfo,
			g_msg_textcol);
		if(g_iVoteType == VOTETYPE_RTV)
		{
			g_bMapChanging   = true;
			
			ConVar cNextMap = FindConVar("sm_nextmap");
			if(cNextMap != null)
			{
				cNextMap.Flags &= ~FCVAR_NOTIFY;
			}
			delete cNextMap;
			
			LogMessage("Vote finished, map changing to %s", sInfo);
			SetNextMap(sInfo);
			ServerCommand("sm_map %s", sInfo);
			
			/*
			if(g_Engine == Engine_CSGO)
			{
				new iGameEnd  = FindEntityByClassname(-1, "game_end");
				if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1) 
				{     
					LogError("Unable to create entity 'game_end'!");
				} 
				else 
				{     
					AcceptEntityInput(iGameEnd, "EndGame");
				}
				
				if(g_bCvarEnfIsLoaded && Cvar_IsEnforced("mp_ignore_round_win_conditions"))
				{
					Cvar_Unenforce("mp_ignore_round_win_conditions");
				}
				
				ConVar c = FindConVar("mp_ignore_round_win_conditions");
				c.IntValue = 0;
				
				for(int client = 1; client <= MaxClients; client++)
				{
					if(IsClientInGame(client) && IsPlayerAlive(client))
					{
						FakeClientCommand(client, "kill");
					}
				}
				
				CS_TerminateRound(0.0, CSRoundEnd_CTWin, false);
				
				c.IntValue = 1;
			}
			else if(g_Engine == Engine_CSS)
			{
				ServerCommand("sm_map %s", sInfo);
			}
			*/
		}
		else if(g_iVoteType == VOTETYPE_NEXTMAP)
		{
			SetNextMap(sInfo);
			g_bMapDecided = true;
		}
		
		
		//DataPack data;
		//CreateDataTimer(15.0, Timer_ChangeMap, data);
		//data.WriteString(sInfo);
	}
	
	g_bRTVInProgress = false;
}

/*
public Action Timer_ChangeMap(Handle timer, DataPack data)
{
	char sMap[PLATFORM_MAX_PATH];
	data.Reset();
	data.ReadString(sMap, sizeof(sMap));
	ForceChangeLevel(sMap, "RTV");
}
*/

void ExtendMap(int minutes)
{
	if(g_bCvarEnfIsLoaded == true && Cvar_IsEnforced("mp_timelimit"))
	{
		Cvar_Unenforce("mp_timelimit");
		
		ConVar c = FindConVar("mp_timelimit");
		ServerCommand("mp_timelimit %d", c.IntValue + minutes);
		
		char sValue[128];
		IntToString(c.IntValue + minutes, sValue, sizeof(sValue));
		
		Cvar_Enforce("mp_timelimit", sValue);
		
		delete c;
	}
	else
	{
		ConVar c = FindConVar("mp_timelimit");
		ServerCommand("mp_timelimit %d", c.IntValue + minutes);
		delete c;
	}
}

int GetVoteCount()
{
	int votes;
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(g_ClientRTVd[client] == true)
		{
			votes++;
		}
	}
	
	return votes;
}

int GetVotesRequired()
{
	int clientsAllowedToVote;
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) == false)
		{
			continue;
		}
		
		if(IsFakeClient(client) == true)
		{
			continue;
		}
		
		if((GetConVarBool(g_hSpecsCanRTV) || GetClientTeam(client) > 1) == false)
		{
			continue;
		}
		
		if(g_bRanksLoaded == true)
		{
			if((GetConVarBool(g_hUnrankedCanRTV) || Ranks_IsClientRankedOverall(client)) == false)
			{
				continue;
			}
		}

		clientsAllowedToVote++;
	}
	
	int required = RoundToCeil(float(clientsAllowedToVote) * GetConVarFloat(g_hRequiredPercentage));
	
	if(required == 0)
	{
		required = 1;
	}
	
	return required;
}

public void OnGameFrame()
{
	// Start vote when a certain amount of time is left
	int timeleft;
	GetMapTimeLeft(timeleft);
	if(g_bConfigsExecuted && !g_bRTVInProgress && (GetEngineTime() - g_fLastVoteTime) > (GetConVarFloat(g_hNextMapVoteTime) * 60.0) && g_bMapChanging == false && g_bMapDecided == false)
	{
		if(timeleft <= (GetConVarFloat(g_hNextMapVoteTime) * 60.0))
		{
			StartVote(VOTETYPE_NEXTMAP);
		}
	}
	
	if(timeleft > 0 && timeleft <= g_iCountDown)
	{
		PrintColorTextAll("%s%sMAP CHANGING IN %s%d%s SECONDS",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_iCountDown,
			g_msg_textcol);
			
		if(g_iCountDown == 10)
			g_iCountDown = 5;
		else
			g_iCountDown--;
	}
	
	// Change map when there is no time left
	if(g_bConfigsExecuted && timeleft <= 0 && timeleft != -1 && g_bMapChanging == false)
	{
		char sMap[PLATFORM_MAX_PATH];
		if(GetNextMap(sMap, PLATFORM_MAX_PATH))
		{
			g_bMapChanging = true;
			ServerCommand("sm_map %s", sMap);
		}
	}
	
	// Allow rtv after a certain amount of time has passed
	if(!g_bAllowRTV)
	{
		if(GetEngineTime() - g_fMapStart > (GetConVarFloat(g_hAllowRTVTime) * 60.0))
		{
			g_bAllowRTV = true;
		}
	}
}