#pragma dynamic 131072
#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] Ranks",
	author = "blacky",
	description = "Controls server rankings",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <sdkhooks>
#include <bTimes-ranks>
#include <bTimes-timer>
#include <csgocolors>

#undef REQUIRE_PLUGIN
#include <scp>

#define CC_HASCC  1<<0
#define CC_MSGCOL 1<<1
#define CC_NAME   1<<2

enum
{
	GameType_CSS,
	GameType_CSGO
};

new g_GameType;

new 	Handle:g_DB;
new	Handle:g_MapList = INVALID_HANDLE;

new 	Handle:g_hMapsDone[MAX_TYPES][MAX_STYLES],
	Handle:g_hMapsDoneHndlRef[MAX_TYPES][MAX_STYLES],
	Handle:g_hRecordListID[MAX_TYPES][MAX_STYLES],
	Handle:g_hRecordListCount[MAX_TYPES][MAX_STYLES],
	g_RecordCount[MAXPLAYERS + 1],
	g_iMVPs_offset,
	bool:g_bStatsLoaded;

new	Handle:g_hRanksPlayerID[MAX_TYPES][MAX_STYLES],
	Handle:g_hRanksPoints[MAX_TYPES][MAX_STYLES],
	Handle:g_hRanksNames[MAX_TYPES][MAX_STYLES],
	g_Rank[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES],
	g_Points[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES];

// Chat ranks
new 	Handle:g_hChatRanksRanges,
	Handle:g_hChatRanksNames;
	
// Custom chat
new	Handle:g_hCustomSteams,
	Handle:g_hCustomNames,
	Handle:g_hCustomMessages,
	Handle:g_hCustomUse,
	g_ClientUseCustom[MAXPLAYERS + 1];
	
new	bool:g_bNewMessage;
	
// Settings
new	Handle:g_hUseCustomChat,
	Handle:g_hUseChatRanks,
	Handle:g_hAllChat;
	
// Points recalculation
new	g_RecalcTotal,
	g_RecalcProgress;

public OnPluginStart()
{
	decl String:sGame[64];
	GetGameFolderName(sGame, sizeof(sGame));
	
	if(StrEqual(sGame, "cstrike"))
		g_GameType = GameType_CSS;
	else if(StrEqual(sGame, "csgo"))
		g_GameType = GameType_CSGO;
	else
		SetFailState("This timer does not support this game (%s)", sGame);
	
	// Connect to the database
	DB_Connect();
	
	// Cvars
	g_hUseCustomChat  = CreateConVar("timer_enablecc", "1", "Allows specific players to use custom chat. Enabled by !enablecc <steamid> command.", 0, true, 0.0, true, 1.0);
	g_hUseChatRanks   = CreateConVar("timer_chatranks", "1", "Allows players to use chat ranks specified in sourcemod/configs/timer/ranks.cfg", 0, true, 0.0, true, 1.0);
	g_hAllChat        = CreateConVar("timer_allchat", "1", "Enable's allchat", 0, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "ranks", "timer");
	
	// Commands
	RegConsoleCmdEx("sm_ccname", SM_ColoredName, "Change colored name.");
	RegConsoleCmdEx("sm_ccmsg", SM_ColoredMsg, "Change the color of your messages.");
	RegConsoleCmdEx("sm_cchelp", SM_Colorhelp, "For help on creating a custom name tag with colors and a color message.");
	
	RegConsoleCmdEx("sm_rankings", SM_Rankings, "Shows the chat ranking tags and the ranks required to get them.");
	RegConsoleCmdEx("sm_ranks", SM_Rankings, "Shows the chat ranking tags and the ranks required to get them.");
	RegConsoleCmdEx("sm_chatranks", SM_Rankings, "Shows the chat ranking tags and the ranks required to get them.");
	
	// Admin commands
	RegAdminCmd("sm_enablecc", SM_EnableCC, ADMFLAG_ROOT, "Enable custom chat for a specified SteamID.");
	RegAdminCmd("sm_disablecc", SM_DisableCC, ADMFLAG_ROOT, "Disable custom chat for a specified SteamID.");
	RegAdminCmd("sm_cclist", SM_CCList, ADMFLAG_CHEATS, "Shows a list of players with custom chat privileges.");
	RegAdminCmd("sm_recalcpts", SM_RecalcPts, ADMFLAG_CHEATS, "Recalculates all the points in the database.");
	RegAdminCmd("sm_reloadranks", SM_ReloadRanks, ADMFLAG_CHEATS, "Reloads chat ranks.");
	
	// Chat ranks
	g_hChatRanksRanges = CreateArray(2);
	g_hChatRanksNames  = CreateArray(ByteCountToCells(256));
	LoadChatRanks();
	
	// Custom chat ranks
	g_hCustomSteams  	= CreateArray(ByteCountToCells(32));
	g_hCustomNames   	= CreateArray(ByteCountToCells(128));
	g_hCustomMessages	= CreateArray(ByteCountToCells(256));
	g_hCustomUse 	   	= CreateArray();
	
	// Makes FindTarget() work properly
	LoadTranslations("common.phrases");
	
	// Command listeners
	AddCommandListener(Command_Say, "say");
	
	g_iMVPs_offset = FindSendPropInfo("CCSPlayerResource", "m_iMVPs");
	
	g_MapList = ReadMapList();
	
	RegAdminCmd("sm_showcycle", SM_ShowCycle, ADMFLAG_GENERIC);
}

public Action:SM_ShowCycle(client, args)
{
	new iSize = GetArraySize(g_MapList);
	
	if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
		ReplyToCommand(client, "[SM] See your console for the map cycle");
	
	decl String:sMapName[64];
	for(new idx; idx < iSize; idx++)
	{
		GetArrayString(g_MapList, idx, sMapName, sizeof(sMapName));
		PrintToConsole(client, sMapName);
	}
	
	return Plugin_Handled;
}

public OnEntityCreated(entity, const String:classname[])
{
	if(StrContains(classname, "_player_manager") != -1)
	{
		SDKHook(entity, SDKHook_ThinkPost, PlayerManager_OnThinkPost);
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("DB_UpdateRanks", Native_UpdateRanks);
	CreateNative("Timer_EnableCustomChat", Native_EnableCustomChat);
	CreateNative("Timer_DisableCustomChat", Native_DisableCustomChat);
	CreateNative("Timer_SteamIDHasCustomChat", Native_SteamIDHasCustomChat);
	CreateNative("Timer_OpenStatsMenu", Native_OpenStatsMenu);
	
	if(late)
	{
		UpdateMessages();
	}
	
	return APLRes_Success;
}

public OnMapStart()
{	
	if(g_MapList != INVALID_HANDLE)
		CloseHandle(g_MapList);
	
	g_MapList = ReadMapList();
	
	CreateTimer(1.0, UpdateDeaths, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientAuthorized(client, const String:auth[])
{
	new idx = FindStringInArray(g_hCustomSteams, auth);
	if(idx != -1)
	{
		g_ClientUseCustom[client]  = GetArrayCell(g_hCustomUse, idx);
	}
}

public bool:OnClientConnect(client)
{
	g_ClientUseCustom[client] = 0;
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			g_Rank[client][Type][Style]   = 0;
			g_Points[client][Type][Style] = 0;
			g_RecordCount[client]         = 0;
		}
	}
	
	return true;
}

public OnPlayerIDLoaded(client)
{
	SetClientRank(client);
	SetRecordCount(client);
}

public OnMapTimesLoaded()
{
	DB_LoadStats();
}

public OnStylesLoaded()
{
	RegConsoleCmdPerStyle("rank", SM_Rank, "Show your rank for {Type} timer on {Style} style.");
	RegConsoleCmdPerStyle("mapsleft", SM_Mapsleft, "Show maps left for {Type} timer on {Style} style.");
	RegConsoleCmdPerStyle("mapsnotdone", SM_Mapsnotdone, "Show maps left for {Type} timer on {Style} style.");
	RegConsoleCmdPerStyle("mapsdone", SM_Mapsdone, "Show maps done for {Type} timer on {Style} style.");
	RegConsoleCmdPerStyle("top", SM_Top, "Show list of top players for {Type} timer on {Style} style.");
	RegConsoleCmdPerStyle("topwr", SM_TopWorldRecord, "Show who has the most records for {Type} timer on {Style} style.");
	RegConsoleCmdPerStyle("stats", SM_Stats, "Shows a player's stats for {Type} timer on {Style} style.");
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			g_hRanksPlayerID[Type][Style] = CreateArray();
			g_hRanksPoints[Type][Style]   = CreateArray();
			g_hRanksNames[Type][Style]    = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
			
			g_hRecordListID[Type][Style]    = CreateArray();
			g_hRecordListCount[Type][Style] = CreateArray();
			
			g_hMapsDone[Type][Style]        = CreateArray();
			g_hMapsDoneHndlRef[Type][Style] = CreateArray();
		}
	}
}

public Action:Command_Say(client, const String:command[], argc)
{
	if(GetConVarBool(g_hAllChat))
	{
		g_bNewMessage = true;
	}
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	GetChatName(author, name, MAXLENGTH_NAME);
	GetChatMessage(author, message, MAXLENGTH_MESSAGE);
	
	if(g_bNewMessage == true)
	{
		if(GetMessageFlags() & CHATFLAGS_ALL && !IsPlayerAlive(author))
		{
			for(new client = 1; client <= MaxClients; client++)
			{
				if(IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
				{
					PushArrayCell(recipients, client);
				}
			}
		}
		g_bNewMessage = false;
	}
	
	return Plugin_Changed;
}

FormatTag(client, String:buffer[], maxlength)
{	
	// Replace custom name colors
	if(g_GameType == GameType_CSS)
	{
		ReplaceString(buffer, maxlength, "{team}", "\x03", true);
		ReplaceString(buffer, maxlength, "{norm}", "\x01", true);
		ReplaceString(buffer, maxlength, "^", "\x07", true);
		
		new rand[3], String:sRandHex[15];
		while(StrContains(buffer, "{rand}", true) != -1)
		{
			for(new i=0; i<3; i++)
				rand[i] = GetRandomInt(0, 255);
			
			FormatEx(sRandHex, sizeof(sRandHex), "\x07%02X%02X%02X", rand[0], rand[1], rand[2]);
			ReplaceStringEx(buffer, maxlength, "{rand}", sRandHex);
		}
	}
	else if(g_GameType == GameType_CSGO)
	{
		CFormat(buffer, maxlength, client, true);
	}
	
	if(0 < client <= MaxClients)
	{
		decl String:sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		ReplaceString(buffer, maxlength, "{name}", sName, true);
	}
}

GetChatName(client, String:buffer[], maxlength)
{	
	if((g_ClientUseCustom[client] & CC_HASCC) && (g_ClientUseCustom[client] & CC_NAME) && GetConVarBool(g_hUseCustomChat))
	{
		decl String:sAuth[32];
		GetClientAuthString(client, sAuth, sizeof(sAuth));
		
		new idx = FindStringInArray(g_hCustomSteams, sAuth);
		if(idx != -1)
		{
			GetArrayString(g_hCustomNames, idx, buffer, maxlength);
			FormatTag(client, buffer, maxlength);
		}
	}
	else if(GetConVarBool(g_hUseChatRanks))
	{
		new iSize = GetArraySize(g_hChatRanksRanges);
		for(new i=0; i<iSize; i++)
		{
			if(GetArrayCell(g_hChatRanksRanges, i, 0) <= g_Rank[client][TIMER_MAIN][0] <= GetArrayCell(g_hChatRanksRanges, i, 1))
			{
				GetArrayString(g_hChatRanksNames, i, buffer, maxlength);
				FormatTag(client, buffer, maxlength);
				return;
			}
		}
	}
}

GetChatMessage(client, String:message[], maxlength)
{
	if((g_ClientUseCustom[client] & CC_HASCC) && (g_ClientUseCustom[client] & CC_MSGCOL) && GetConVarBool(g_hUseCustomChat))
	{
		decl String:sAuth[32];
		GetClientAuthString(client, sAuth, sizeof(sAuth));
		
		new idx = FindStringInArray(g_hCustomSteams, sAuth);
		if(idx != -1)
		{
			decl String:buffer[MAXLENGTH_MESSAGE];
			GetArrayString(g_hCustomMessages, idx, buffer, MAXLENGTH_MESSAGE);
			FormatTag(client, buffer, maxlength);
			Format(message, maxlength, "%s%s", buffer, message);
		}
	}
}

public Action:SM_RecalcPts(client, args)
{
	new	Handle:menu = CreateMenu(Menu_RecalcPts);
	
	SetMenuTitle(menu, "Recalculating the points takes a while.\nAre you sure you want to do this?");
	
	AddMenuItem(menu, "y", "Yes");
	AddMenuItem(menu, "n", "No");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Menu_RecalcPts(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[16];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(info[0] == 'y')
		{
			RecalcPoints(param1);
		}
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

RecalcPoints(client)
{
	PrintColorTextAll("%s%sRecalculating the ranks, see console for progress.",
		g_msg_start,
		g_msg_textcol);
	
	decl	String:query[128];
	FormatEx(query, sizeof(query), "SELECT MapName, MapID FROM maps");
	
	SQL_TQuery(g_DB, RecalcPoints_Callback, query, client);
}

public RecalcPoints_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new rows = SQL_GetRowCount(hndl);
		decl String:sMapName[64], String:query[128];
		
		g_RecalcTotal    = rows * 4;
		g_RecalcProgress = 0;
		
		for(new i = 0; i < rows; i++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sMapName, sizeof(sMapName));
			
			if(FindStringInArray(g_MapList, sMapName) != -1)
			{
				new TotalStyles = Style_GetTotal();
				
				for(new Type = 0; Type < MAX_TYPES; Type++)
				{
					for(new Style = 0; Style < TotalStyles; Style++)
					{
						if(Style_IsEnabled(Style) && Style_IsTypeAllowed(Style, Type))
						{
							UpdateRanks(sMapName, Type, Style, true);
						}
					}
				}
			}
			else
			{
				FormatEx(query, sizeof(query), "UPDATE times SET Points = 0 WHERE MapID = %d",
					SQL_FetchInt(hndl, 1));
					
				new	Handle:pack = CreateDataPack();
				WritePackString(pack, sMapName);
					
				SQL_TQuery(g_DB, RecalcPoints_Callback2, query, pack);
			}
		}
	}
	else
	{
		LogError(error);
	}
}

public RecalcPoints_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		
		decl String:sMapName[64];
		ReadPackString(data, sMapName, sizeof(sMapName));
		
		g_RecalcProgress += 4;
		
		for(new client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				if(!IsFakeClient(client))
				{
					PrintToConsole(client, "[%.1f%%] %s's points deleted.",
						float(g_RecalcProgress)/float(g_RecalcTotal) * 100.0,
						sMapName);
				}
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

public Action:SM_Rank(client, args)
{
	new Type, Style;
	if(GetTypeStyleFromCommand("rank", Type, Style))
	{
		if(!IsSpamming(client))
		{
			SetIsSpamming(client, 1.0);
			if(args == 0)
			{
				DB_ShowRank(client, client, Type, Style);
			}
			else
			{
				decl String:targetName[128];
				GetCmdArgString(targetName, sizeof(targetName));
				new target = FindTarget(client, targetName, true, false);
				if(target != -1)
					DB_ShowRank(client, target, Type, Style);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Top(client, args)
{
	new Type, Style;
	if(GetTypeStyleFromCommand("top", Type, Style))
	{
		if(!IsSpamming(client))
		{
			SetIsSpamming(client, 1.0);
			
			DB_ShowTopAllSpec(client, Type, Style);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Mapsleft(client, args)
{
	new Type, Style;
	if(GetTypeStyleFromCommand("mapsleft", Type, Style))
	{
		if(!IsSpamming(client))
		{
			SetIsSpamming(client, 1.0);
			
			if(args == 0)
			{
				DB_ShowMapsleft(client, client, Type, Style);
			}
			else
			{
				decl String:targetName[128];
				GetCmdArgString(targetName, sizeof(targetName));
				new target = FindTarget(client, targetName, true, false);
				if(target != -1)
					DB_ShowMapsleft(client, target, Type, Style);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Mapsnotdone(client, args)
{
	new Type, Style;
	if(GetTypeStyleFromCommand("mapsleft", Type, Style))
	{
		if(!IsSpamming(client))
		{
			SetIsSpamming(client, 1.0);
			
			if(args == 0)
			{
				DB_ShowMapsleft(client, client, Type, Style);
			}
			else
			{
				decl String:targetName[128];
				GetCmdArgString(targetName, sizeof(targetName));
				new target = FindTarget(client, targetName, true, false);
				if(target != -1)
					DB_ShowMapsleft(client, target, Type, Style);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Mapsdone(client, args)
{
	new Type, Style;
	if(GetTypeStyleFromCommand("mapsdone", Type, Style))
	{
		if(!IsSpamming(client))
		{
			SetIsSpamming(client, 1.0);
			
			new PlayerID;
			if(args == 0)
			{
				PlayerID = GetPlayerID(client);
				
				if(PlayerID != 0)
				{
					DB_ShowMapsdone(client, PlayerID, Type, Style);
				}
				else
				{
					PrintColorText(client, "%s%sYou have not been authorized by the timer yet.",
						g_msg_start,
						g_msg_textcol);
				}
			}
			else
			{
				decl String:targetName[128];
				GetCmdArgString(targetName, sizeof(targetName));
				new target = FindTarget(client, targetName, true, false);
				if(target != -1)
				{
					PlayerID = GetPlayerID(target);
					
					if(PlayerID != 0)
					{
						DB_ShowMapsdone(client, PlayerID, Type, Style);
					}
					else
					{
						PrintColorText(client, "%s%s%N%s has not been authorized by the timer yet.",
							g_msg_start,
							g_msg_varcol,
							target,
							g_msg_textcol);
					}
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Stats(client, args)
{
	new Type, Style;
	if(GetTypeStyleFromCommand("stats", Type, Style))
	{
		if(!IsSpamming(client))
		{
			SetIsSpamming(client, 1.0);
			
			new PlayerID;
			
			if(args == 0)
			{
				PlayerID = GetPlayerID(client);
				
				if(PlayerID != 0)
				{
					OpenStatsMenu(client, PlayerID, Type, Style);
				}
				else
				{
					PrintColorText(client, "%s%sYou have not been authorized by the timer yet.",
						g_msg_start,
						g_msg_textcol);
				}
			}
			else
			{
				decl String:targetName[128];
				GetCmdArgString(targetName, sizeof(targetName));
				new target = FindTarget(client, targetName, true, false);
				if(target != -1)
				{
					PlayerID = GetPlayerID(target);
					
					if(PlayerID != 0)
					{
						OpenStatsMenu(client, PlayerID, Type, Style);
					}
					else
					{
						PrintColorText(client, "%s%s%N%s has not been authorized by the timer yet.",
							g_msg_start,
							g_msg_varcol,
							target,
							g_msg_textcol);
					}
				}
			}
		}
	}
	
	return Plugin_Handled;
}

OpenStatsMenu(client, PlayerID, Type, Style)
{
	new Rank = FindValueInArray(g_hRanksPlayerID[Type][Style], PlayerID);
	if(Rank != -1)
	{
		Rank++;
		new Handle:menu = CreateMenu(Menu_Stats);
		
		decl String:sName[MAX_NAME_LENGTH], String:sAuth[32], String:sType[32], String:sStyle[32];
		GetNameFromPlayerID(PlayerID, sName, sizeof(sName));
		GetSteamIDFromPlayerID(PlayerID, sAuth, sizeof(sAuth));
		GetTypeName(Type, sType, sizeof(sType));
		GetStyleName(Style, sStyle, sizeof(sStyle));
		
		SetMenuTitle(menu, "Stats for %s (%s)\n--------------------------------\n", sName, sAuth);
		
		// Get Record count
		new RecordCount;
		new idx = FindValueInArray(g_hRecordListID[Type][Style], PlayerID);
		if(idx != -1)
		{
			RecordCount = GetArrayCell(g_hRecordListCount[Type][Style], idx);
		}
		
		// Get maps done
		new Handle:hCell = GetArrayCell(g_hMapsDone[Type][Style], PlayerID);
		
		new MapsDone;
		if(hCell != INVALID_HANDLE)
			MapsDone = GetArraySize(hCell);
		
		new TotalMaps;
		//if(Type == TIMER_MAIN)
		//	TotalMaps = GetArraySize(g_MapList);
		//else
		TotalMaps = GetArraySize(g_MapList);
		
		new Float:fCompletion = float(MapsDone) / float(TotalMaps) * 100.0;
		
		// Get rank info
		new TotalRanks = GetArraySize(g_hRanksPlayerID[Type][Style]);
		new Float:fPoints = GetArrayCell(g_hRanksPoints[Type][Style], Rank - 1);
		
		decl String:sDisplay[256];
		FormatEx(sDisplay, sizeof(sDisplay), "%s [%s]\nWorld Records: %d\n \nMaps done: %d / %d (%.1f%%)\n \nRank: %d / %d (%d Pts.)\n--------------------------------",
			sType,
			sStyle,
			RecordCount,
			MapsDone,
			TotalMaps,
			fCompletion,
			Rank,
			TotalRanks,
			RoundToFloor(fPoints));
		
		decl String:sInfo[32];
		FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", PlayerID, Type, Style);
		AddMenuItem(menu, sInfo, sDisplay);
		
		for(new lType; lType < MAX_TYPES; lType++)
		{
			GetTypeName(lType, sType, sizeof(sType));
			for(new lStyle; lStyle < MAX_STYLES; lStyle++)
			{
				if(lType == Type && lStyle == Style)
					continue;
				
				if(Style_IsEnabled(lStyle) && Style_IsTypeAllowed(lStyle, lType))
				{
					GetStyleName(lStyle, sStyle, sizeof(sStyle));
					
					FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", PlayerID, lType, lStyle);
					FormatEx(sDisplay, sizeof(sDisplay), "%s [%s]", sType, sStyle);
					
					AddMenuItem(menu, sInfo, sDisplay);
				}
			}
		}
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		if(g_bStatsLoaded == false)
		{
			PrintColorText(client, "%s%sThe stats have not been loaded yet.",
				g_msg_start,
				g_msg_textcol);
		}
		else
		{
			decl String:sType[32], String:sStyle[32];
			GetTypeName(Type, sType, sizeof(sType));
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			decl String:slType[32], String:slStyle[32];
			for(new lType; lType < MAX_TYPES; lType++)
			{
				GetTypeName(lType, slType, sizeof(slType));
				
				for(new lStyle; lStyle < MAX_STYLES; lStyle++)
				{
					if(Style_IsEnabled(lStyle) && Style_IsTypeAllowed(lStyle, lType))
					{
						GetStyleName(lStyle, slStyle, sizeof(slStyle));
						
						if((Rank = FindValueInArray(g_hRanksPlayerID[lType][lStyle], PlayerID)) != -1)
						{
							PrintColorText(client, "%s%sCouldn't find stats for [%s%s%s] - [%s%s%s], showing stats for [%s%s%s] - [%s%s%s] instead.",
								g_msg_start,
								g_msg_textcol,
								g_msg_varcol,
								sType,
								g_msg_textcol,
								g_msg_varcol,
								sStyle,
								g_msg_textcol,
								g_msg_varcol,
								slType,
								g_msg_textcol,
								g_msg_varcol,
								slStyle,
								g_msg_textcol);
							
							OpenStatsMenu(client, PlayerID, lType, lStyle);
							return;
						}
					}
				}
			}
			
			PrintColorText(client, "%s%sThe player you specified is unranked.",
				g_msg_start,
				g_msg_textcol);
		}
	}
}

public Menu_Stats(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		decl String:sInfoExploded[3][16];
		ExplodeString(info, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		
		OpenStatsMenu(param1, StringToInt(sInfoExploded[0]), StringToInt(sInfoExploded[1]), StringToInt(sInfoExploded[2]));
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Native_OpenStatsMenu(Handle:plugin, numParams)
{
	OpenStatsMenu(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), GetNativeCell(4));
}

public Action:SM_TopWorldRecord(client, args)
{
	new Type, Style;
	
	if(GetTypeStyleFromCommand("topwr", Type, Style))
	{
		decl String:sType[32];
		GetTypeName(Type, sType, sizeof(sType));
		
		decl String:sStyle[32];
		GetStyleName(Style, sStyle, sizeof(sStyle));
		
		new iSize = GetArraySize(g_hRecordListID[Type][Style]);
		if(iSize > 0)
		{
			new Handle:menu = CreateMenu(Menu_RecordCount);
			SetMenuTitle(menu, "World Record Count [%s] - [%s]", sType, sStyle);
			
			new PlayerID, RecordCount, String:sInfo[32], String:sDisplay[64], String:sName[MAX_NAME_LENGTH];
			for(new idx; idx < iSize; idx++)
			{
				PlayerID    = GetArrayCell(g_hRecordListID[Type][Style], idx);
				RecordCount = GetArrayCell(g_hRecordListCount[Type][Style], idx);
				
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", PlayerID, Type, Style);
				
				GetNameFromPlayerID(PlayerID, sName, sizeof(sName));
				FormatEx(sDisplay, sizeof(sDisplay), "#%d: %s (%d)", idx + 1, sName, RecordCount);
				
				AddMenuItem(menu, sInfo, sDisplay);
			}
			
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			PrintColorText(client, "%s%s[%s%s%s] - [%s%s%s] There are no world records on any map.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sType,
				g_msg_textcol,
				g_msg_varcol,
				sStyle,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

public Menu_RecordCount(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:sInfo[32];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		decl String:sInfoExploded[3][16];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		
		OpenStatsMenu(param1, StringToInt(sInfoExploded[0]), StringToInt(sInfoExploded[1]), StringToInt(sInfoExploded[2]));
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_ColoredName(client, args)
{	
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(g_ClientUseCustom[client] & CC_HASCC)
		{
			decl String:query[512], String:sAuth[32];
			GetClientAuthString(client, sAuth, sizeof(sAuth));
			
			if(args == 0)
			{
				// Get new ccname setting
				g_ClientUseCustom[client] ^= CC_NAME;
				
				// Acknowledge change to client
				if(g_ClientUseCustom[client] & CC_NAME)
				{
					PrintColorText(client, "%s%sColored name enabled.",
						g_msg_start,
						g_msg_textcol);
				}
				else
				{
					PrintColorText(client, "%s%sColored name disabled.",
						g_msg_start,
						g_msg_textcol);
				}
				
				// Set the new ccname setting
				new idx = FindStringInArray(g_hCustomSteams, sAuth);
				
				if(idx != -1)
					SetArrayCell(g_hCustomUse, idx, g_ClientUseCustom[client]);
				
				// Format the query
				FormatEx(query, sizeof(query), "UPDATE players SET ccuse=%d WHERE SteamID='%s'",
					g_ClientUseCustom[client],
					sAuth);
			}
			else
			{
				// Get new ccname
				decl String:sArg[250];
				GetCmdArgString(sArg, sizeof(sArg));
				decl String:sEscapeArg[(strlen(sArg)*2)+1];
				
				// Escape the ccname for SQL insertion
				SQL_LockDatabase(g_DB);
				SQL_EscapeString(g_DB, sArg, sEscapeArg, (strlen(sArg)*2)+1);
				SQL_UnlockDatabase(g_DB);
				
				// Modify player's ccname
				new idx = FindStringInArray(g_hCustomSteams, sAuth);
				
				if(idx != -1)
					SetArrayString(g_hCustomNames, idx, sEscapeArg);
				
				// Prepare query
				FormatEx(query, sizeof(query), "UPDATE players SET ccname='%s' WHERE SteamID='%s'",
					sEscapeArg,
					sAuth);
					
				PrintColorText(client, "%s%sColored name set to %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sArg);
			}
			
			// Execute query
			SQL_TQuery(g_DB, ColoredName_Callback, query);
		}
	}
	return Plugin_Handled;
}

public ColoredName_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

public Action:SM_ColoredMsg(client, args)
{	
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		if(g_ClientUseCustom[client] & CC_HASCC)
		{
			decl String:query[512], String:sAuth[32];
			GetClientAuthString(client, sAuth, sizeof(sAuth));
			
			if(args == 0)
			{
				g_ClientUseCustom[client] ^= CC_MSGCOL;
				
				new idx = FindStringInArray(g_hCustomSteams, sAuth);
				
				if(idx != -1)
					SetArrayCell(g_hCustomUse, idx, g_ClientUseCustom[client]);
				
				FormatEx(query, sizeof(query), "UPDATE players SET ccuse=%d WHERE SteamID='%s'",
					g_ClientUseCustom[client],
					sAuth);
					
				if(g_ClientUseCustom[client] & CC_MSGCOL)
					PrintColorText(client, "%s%sColored message enabled.",
						g_msg_start,
						g_msg_textcol);
				else
					PrintColorText(client, "%s%sColored message disabled.",
						g_msg_start,
						g_msg_textcol);
			}
			else
			{
				decl String:sArg[128];
				GetCmdArgString(sArg, sizeof(sArg));
				decl String:sEscapeArg[(strlen(sArg)*2)+1];
				
				SQL_LockDatabase(g_DB);
				SQL_EscapeString(g_DB, sArg, sEscapeArg, (strlen(sArg)*2)+1);
				SQL_UnlockDatabase(g_DB);
					
				new idx = FindStringInArray(g_hCustomSteams, sAuth);
				
				if(idx != -1)
					SetArrayString(g_hCustomMessages, idx, sEscapeArg);
				
				FormatEx(query, sizeof(query), "UPDATE players SET ccmsgcol='%s' WHERE SteamID='%s'",
					sEscapeArg,
					sAuth);
					
				PrintColorText(client, "%s%sColored message set to %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sArg);
			}
			
			// Execute query
			SQL_TQuery(g_DB, ColoredName_Callback, query);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Colorhelp(client, args)
{
	if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		PrintColorText(client, "%s%sLook in console for help with custom color chat.",
			g_msg_start,
			g_msg_textcol);
	}
	
	PrintToConsole(client, "\nsm_ccname <arg> to set your name.");
	PrintToConsole(client, "sm_ccname without an argument to toggle colored name.\n");
	
	PrintToConsole(client, "sm_ccmsg <arg> to set your message.");
	PrintToConsole(client, "sm_ccmsg without an argument to toggle colored message.\n");
	
	PrintToConsole(client, "{name} will be replaced with your steam name.");
	PrintToConsole(client, "{rand} will be replaced with a random color.");
	PrintToConsole(client, "{team} will be replaced with your team color.");
	PrintToConsole(client, "{norm} will be replaced with normal chat color.\n");
	
	if(g_GameType == GameType_CSS)
	{
		PrintToConsole(client, "'^' followed by a hexadecimal code to use any custom color.");
	}
	else if(g_GameType == GameType_CSGO)
	{
		for(new color = 1; color < MAX_COLORS; color++)
		{
			PrintToConsole(client, CTag[color]);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_ReloadRanks(client, args)
{
	LoadChatRanks();
	
	PrintColorText(client, "%s%sChat ranks reloaded.",
		g_msg_start,
		g_msg_textcol);
	
	return Plugin_Handled;
}

public Action:SM_EnableCC(client, args)
{
	decl String:sArg[256];
	GetCmdArgString(sArg, sizeof(sArg));
	
	if(StrContains(sArg, "STEAM_") != -1)
	{
		decl String:query[256];
		FormatEx(query, sizeof(query), "SELECT User, ccuse FROM players WHERE SteamID='%s'",
			sArg);
			
		new	Handle:pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackString(pack, sArg);
			
		SQL_TQuery(g_DB, EnableCC_Callback1, query, pack);
	}
	else
	{
		ReplyToCommand(client, "sm_enablecc example: \"sm_enablecc STEAM_%d:1:12345\"",
			g_GameType == GameType_CSS?0:1);
	}
	
	return Plugin_Handled;
}

public EnableCC_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(pack);
		new client = ReadPackCell(pack);
		
		decl String:sAuth[32];
		ReadPackString(pack, sAuth, sizeof(sAuth));
		
		if(SQL_GetRowCount(hndl) > 0)
		{
			SQL_FetchRow(hndl);
			
			decl String:sName[MAX_NAME_LENGTH];
			SQL_FetchString(hndl, 0, sName, sizeof(sName));
			
			new ccuse = SQL_FetchInt(hndl, 1);
			
			if(!(ccuse & CC_HASCC))
			{
				PrintColorText(client, "%s%sA player with the name '%s%s%s' <%s%s%s> will be given custom chat privileges.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sName,
					g_msg_textcol,
					g_msg_varcol,
					sAuth,
					g_msg_textcol);
				
				EnableCustomChat(sAuth);
			}
			else
			{
				PrintColorText(client, "%s%sA player with the given SteamID '%s%s%s' (name '%s%s%s') already has custom chat privileges.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sAuth,
					g_msg_textcol,
					g_msg_varcol,
					sName,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sNo player in the database found with '%s%s%s' as their SteamID.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sAuth,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(pack);
}

EnableCustomChat(const String:sAuth[])
{
	if(FindStringInArray(g_hCustomSteams, sAuth) != -1)
	{
		ThrowError("SteamID <%s> already has custom chat privileges.", sAuth);
	}
	
	// Check and enable cc for any clients in the game
	decl String:sAuth2[32];
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			GetClientAuthString(client, sAuth2, sizeof(sAuth2));
			if(StrEqual(sAuth, sAuth2))
			{
				g_ClientUseCustom[client]  = CC_HASCC|CC_MSGCOL|CC_NAME;
				
				PrintColorText(client, "%s%sYou have been given custom chat privileges. Type sm_cchelp or ask for help to learn how to use it.",
					g_msg_start,
					g_msg_textcol);
					
				break;
			}
		}
	}
	
	decl String:query[512];
	FormatEx(query, sizeof(query), "UPDATE players SET ccuse=%d, ccname='{rand}{name}', ccmsgcol='{rand}' WHERE SteamID='%s'",
		CC_HASCC|CC_MSGCOL|CC_NAME,
		sAuth);
	SQL_TQuery(g_DB, EnableCC_Callback, query);
	
	PushArrayString(g_hCustomSteams, sAuth);
	PushArrayString(g_hCustomNames, "{rand}{name}");
	PushArrayString(g_hCustomMessages, "{rand}");
	PushArrayCell(g_hCustomUse, CC_HASCC|CC_MSGCOL|CC_NAME);
}

public EnableCC_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

public Action:SM_DisableCC(client, args)
{
	decl String:sArg[256];
	GetCmdArgString(sArg, sizeof(sArg));
	
	if(StrContains(sArg, "STEAM_0:") != -1)
	{
		decl String:query[256];
		FormatEx(query, sizeof(query), "SELECT User, ccuse FROM players WHERE SteamID='%s'",
			sArg);
			
		new	Handle:pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackString(pack, sArg);
			
		SQL_TQuery(g_DB, DisableCC_Callback1, query, pack);
	}
	else
	{
		PrintColorText(client, "%s%ssm_disablecc example: \"sm_disablecc STEAM_0:1:12345\"",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public DisableCC_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(pack);
		new client = ReadPackCell(pack);
		
		decl String:sAuth[32];
		ReadPackString(pack, sAuth, sizeof(sAuth));
		
		if(SQL_GetRowCount(hndl) > 0)
		{
			SQL_FetchRow(hndl);
			
			decl String:sName[MAX_NAME_LENGTH];
			SQL_FetchString(hndl, 0, sName, sizeof(sName));
			
			new ccuse = SQL_FetchInt(hndl, 1);
			
			if(ccuse & CC_HASCC)
			{
				PrintColorText(client, "%s%sA player with the name '%s%s%s' <%s%s%s> will have their custom chat privileges removed.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sName,
					g_msg_textcol,
					g_msg_varcol,
					sAuth,
					g_msg_textcol);
				
				DisableCustomChat(sAuth);
			}
			else
			{
				PrintColorText(client, "%s%sA player with the given SteamID '%s%s%s' (name '%s%s%s') doesn't have custom chat privileges to remove.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sAuth,
					g_msg_textcol,
					g_msg_varcol,
					sName,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sNo player in the database found with '%s%s%s' as their SteamID.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sAuth,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
}

DisableCustomChat(const String:sAuth[])
{
	new idx = FindStringInArray(g_hCustomSteams, sAuth);	
	if(idx != -1)
	{
		RemoveFromArray(g_hCustomSteams, idx);
		RemoveFromArray(g_hCustomNames, idx);
		RemoveFromArray(g_hCustomMessages, idx);
		RemoveFromArray(g_hCustomUse, idx);
		
		decl String:query[512];
		FormatEx(query, sizeof(query), "UPDATE players SET ccuse=0 WHERE SteamID='%s'",
			sAuth);
		SQL_TQuery(g_DB, DisableCC_Callback, query);
	}
	
	// Check and disable cc for any clients in the game
	decl String:sAuth2[32];
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			GetClientAuthString(client, sAuth2, sizeof(sAuth2));
			if(StrEqual(sAuth, sAuth2))
			{
				g_ClientUseCustom[client]  = 0;
				
				PrintColorText(client, "%s%sYou have lost your custom chat privileges.",
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
}

public DisableCC_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

public Action:SM_CCList(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		decl String:query[512];
		FormatEx(query, sizeof(query), "SELECT SteamID, User, ccname, ccmsgcol, ccuse FROM players WHERE ccuse != 0");
		SQL_TQuery(g_DB, CCList_Callback, query, client);
	}
	
	return Plugin_Handled;
}

public CCList_Callback(Handle:owner, Handle:hndl, String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		new Handle:menu = CreateMenu(Menu_CCList);
		SetMenuTitle(menu, "Players with custom chat privileges");
		
		decl String:sAuth[32], String:sName[MAX_NAME_LENGTH], String:sCCName[128], String:sCCMsg[256], String:info[512], String:display[70], ccuse;
		new rows = SQL_GetRowCount(hndl);
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sAuth, sizeof(sAuth));
			SQL_FetchString(hndl, 1, sName, sizeof(sName));
			SQL_FetchString(hndl, 2, sCCName, sizeof(sCCName));
			SQL_FetchString(hndl, 3, sCCMsg, sizeof(sCCMsg));
			ccuse = SQL_FetchInt(hndl, 4);
			
			FormatEx(info, sizeof(info), "%s%%%s%%%s%%%s%%%d",
				sAuth, 
				sName,
				sCCName,
				sCCMsg,
				ccuse);
				
			FormatEx(display, sizeof(display), "<%s> - %s",
				sAuth,
				sName);
				
			AddMenuItem(menu, info, display);
		}
		
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
		
	}
	else
	{
		LogError(error);
	}
}

public Menu_CCList(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[512];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		decl String:expInfo[5][256];
		ExplodeString(info, "\%", expInfo, 5, 256);
		ReplaceString(expInfo[2], 256, "{name}", expInfo[1]);
		ReplaceString(expInfo[2], 256, "{team}", "\x03");
		ReplaceString(expInfo[2], 256, "^", "\x07");

		ReplaceString(expInfo[3], 256, "^", "\x07");
		
		PrintColorText(param1, "%sSteamID          : %s%s", g_msg_textcol, g_msg_varcol, expInfo[0]);
		PrintColorText(param1, "%sName               : %s%s", g_msg_textcol, g_msg_varcol, expInfo[1]);
		PrintColorText(param1, "%sCCName          : %s%s", g_msg_textcol, g_msg_varcol, expInfo[2]);
		PrintColorText(param1, "%sCCMessage      : %s%sExample text", g_msg_textcol, g_msg_varcol, expInfo[3]);
		
		new ccuse = StringToInt(expInfo[4]);
		PrintColorText(param1, "%sUses CC Name: %s%s", g_msg_textcol, g_msg_varcol, (ccuse & CC_NAME)?"Yes":"No");
		PrintColorText(param1, "%sUses CC Msg   : %s%s", g_msg_textcol, g_msg_varcol, (ccuse & CC_MSGCOL)?"Yes":"No");
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_Rankings(client, args)
{
	new iSize = GetArraySize(g_hChatRanksNames);
	
	decl String:sChatRank[MAXLENGTH_NAME];
	
	for(new i=0; i<iSize-1; i++)
	{
		GetArrayString(g_hChatRanksNames, i, sChatRank, MAXLENGTH_NAME);
		FormatTag(client, sChatRank, MAXLENGTH_NAME);
		
		PrintColorText(client, "%s%5d %s-%s %5d%s: %s",
			g_msg_varcol,
			GetArrayCell(g_hChatRanksRanges, i, 0),
			g_msg_textcol,
			g_msg_varcol,
			GetArrayCell(g_hChatRanksRanges, i, 1),
			g_msg_textcol,
			sChatRank);
	}
	
	return Plugin_Handled;
}

public Action:UpdateDeaths(Handle:timer, any:data)
{
	for(new client=1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(IsPlayerAlive(client))
			{
				if(IsFakeClient(client))
				{
					SetEntProp(client, Prop_Data, "m_iDeaths", 0);
				}
				else
				{
					SetEntProp(client, Prop_Data, "m_iDeaths", g_Rank[client][TIMER_MAIN][0]);
				}
			}
		}
	}
}

LoadChatRanks()
{
	// Check if timer config path exists
	decl String:sPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer");
	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
	
	// If it doesn't exist, create a default ranks config
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/ranks.cfg");
	if(!FileExists(sPath))
	{
		new Handle:hFile = OpenFile(sPath, "w");
		WriteFileLine(hFile, "//\"Range\"     \"Tag/Name\"");
		WriteFileLine(hFile, "\"0-0\"     \"[Unranked] {name}\"");
		WriteFileLine(hFile, "\"1-1\"     \"[Master] {name}\"");
		WriteFileLine(hFile, "\"2-2\"     \"[Champion] {name}\"");
		CloseHandle(hFile);
	}
	
	// init chat ranks
	ClearArray(g_hChatRanksRanges);
	ClearArray(g_hChatRanksNames);
	
	// Read file lines and get chat ranks and ranges out of them
	new String:line[PLATFORM_MAX_PATH], String:oldLine[PLATFORM_MAX_PATH], String:sRange[PLATFORM_MAX_PATH], String:sName[PLATFORM_MAX_PATH], String:expRange[2][128];
	new idx, Range[2];
	
	new Handle:hFile = OpenFile(sPath, "r");
	while(!IsEndOfFile(hFile))
	{
		ReadFileLine(hFile, line, sizeof(line));
		ReplaceString(line, sizeof(line), "\n", "");
		if(line[0] != '/' && line[1] != '/' && strlen(line) > 2)
		{
			if(!StrEqual(line, oldLine))
			{
				idx = BreakString(line, sRange, sizeof(sRange));
				BreakString(line[idx], sName, sizeof(sName));
				ExplodeString(sRange, "-", expRange, 2, 128);
				
				Range[0] = StringToInt(expRange[0]);
				Range[1] = StringToInt(expRange[1]);
				PushArrayArray(g_hChatRanksRanges, Range);
				
				PushArrayString(g_hChatRanksNames, sName);
			}
		}
		Format(oldLine, sizeof(oldLine), line);
	}
	
	CloseHandle(hFile);
}

LoadCustomChat()
{	
	decl String:query[512];
	FormatEx(query, sizeof(query), "SELECT SteamID, ccname, ccmsgcol, ccuse FROM players WHERE ccuse != 0");
	SQL_TQuery(g_DB, LoadCustomChat_Callback, query);
}

public LoadCustomChat_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{		
		decl String:sAuth[32], String:sName[128], String:sMsg[256];
		new rows = SQL_GetRowCount(hndl);
		
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sAuth, sizeof(sAuth));
			SQL_FetchString(hndl, 1, sName, sizeof(sName));
			SQL_FetchString(hndl, 2, sMsg, sizeof(sMsg));
			
			PushArrayString(g_hCustomSteams, sAuth);
			PushArrayString(g_hCustomNames, sName);
			PushArrayString(g_hCustomMessages, sMsg);
			PushArrayCell(g_hCustomUse, SQL_FetchInt(hndl, 3));
		}
	}
	else
	{
		LogError(error);
	}
}

public Native_EnableCustomChat(Handle:plugin, numParams)
{
	decl String:sAuth[32];
	GetNativeString(1, sAuth, sizeof(sAuth));
	
	EnableCustomChat(sAuth);
}

public Native_DisableCustomChat(Handle:plugin, numParams)
{
	decl String:sAuth[32];
	GetNativeString(1, sAuth, sizeof(sAuth));
	
	DisableCustomChat(sAuth);
}

public Native_SteamIDHasCustomChat(Handle:plugin, numParams)
{
	decl String:sAuth[32];
	GetNativeString(1, sAuth, sizeof(sAuth));
	
	return FindStringInArray(g_hCustomSteams, sAuth) != -1;
}

DB_ShowRank(client, target, Type, Style)
{
	if(g_Rank[target][Type][Style] != 0)
	{
		PrintColorText(client, "%s%s%N%s is ranked %s%d%s of %s%d%s players with %s%.1f%s points.",
			g_msg_start,
			g_msg_varcol,
			target,
			g_msg_textcol,
			g_msg_varcol,
			g_Rank[target][Type][Style],
			g_msg_textcol,
			g_msg_varcol,
			GetArraySize(g_hRanksPlayerID[Type][Style]),
			g_msg_textcol,
			g_msg_varcol,
			GetArrayCell(g_hRanksPoints[Type][Style], g_Rank[target][Type][Style] - 1),
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%s%N%s is not ranked yet.",
			g_msg_start,
			g_msg_varcol,
			target,
			g_msg_textcol);
	}
}

public DB_ShowRank_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client = ReadPackCell(data);
		new target = ReadPackCell(data);
		
		decl String:sTarget[MAX_NAME_LENGTH];
		GetClientName(target, sTarget, sizeof(sTarget));
		
		SQL_FetchRow(hndl);
		
		if(SQL_FetchInt(hndl, 0) != 0)
		{
			new Rank         = SQL_FetchInt(hndl, 0);
			new Total        = SQL_FetchInt(hndl, 1);
			new Float:Points = SQL_FetchFloat(hndl, 2);
			
			PrintColorText(client, "%s%s%s%s is ranked %s%d%s of %s%d%s players with %s%.1f%s points.",
				g_msg_start,
				g_msg_varcol,
				sTarget,
				g_msg_textcol,
				g_msg_varcol,
				Rank,
				g_msg_textcol,
				g_msg_varcol,
				Total,
				g_msg_textcol,
				g_msg_varcol,
				Points,
				g_msg_textcol);
		}
		else
		{
			PrintColorText(client, "%s%s%s%s is not ranked yet.",
				g_msg_start,
				g_msg_varcol,
				sTarget,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

/*
DB_ShowTopAll(client)
{
	decl String:query[256];
	Format(query, sizeof(query), "SELECT t1.User, SUM(t2.Points) FROM players AS t1, times AS t2 WHERE t1.PlayerID=t2.PlayerID GROUP BY t2.PlayerID ORDER BY SUM(t2.Points) DESC LIMIT 0, 100");
	SQL_TQuery(g_DB, DB_ShowTopAll_Callback, query, client);
}

public DB_ShowTopAll_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new String:name[MAX_NAME_LENGTH], String:item[128], Float:points;
		new rows = SQL_GetRowCount(hndl);
		new Handle:menu = CreateMenu(Menu_ShowTopAll);
		SetMenuTitle(menu, "TOP 100 Players\n------------------------------------");
		for(new itemnum=1; itemnum<=rows; itemnum++)
		{
			SQL_FetchRow(hndl);
			SQL_FetchString(hndl, 0, name, sizeof(name));
			points = SQL_FetchFloat(hndl, 1);
			Format(item, sizeof(item), "#%d: %s - %6.3f", itemnum, name, points);
			
			if((itemnum % 7 == 0) || (itemnum == rows))
				Format(item, sizeof(item), "%s\n------------------------------------", item);
			
			AddMenuItem(menu, item, item);
		}
		
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, data, MENU_TIME_FOREVER);
	}
	else
	{
		LogError(error);
	}
}
*/

public Menu_ShowTopAll(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_End)
		CloseHandle(menu);
}

DB_ShowTopAllSpec(client, Type, Style)
{	
	decl String:sType[32];
	GetTypeName(Type, sType, sizeof(sType));
	AddBracketsToString(sType, sizeof(sType));
	
	decl String:sStyle[32];
	GetStyleName(Style, sStyle, sizeof(sStyle));
	AddBracketsToString(sStyle, sizeof(sStyle));
	
	new iSize = GetArraySize(g_hRanksPlayerID[Type][Style]);
	if(iSize > 0)
	{
		new Handle:menu = CreateMenu(Menu_ShowTop);
		SetMenuTitle(menu, "Top 100 Players %s - %s\n--------------------------------------", sType, sStyle);
		
		decl String:sDisplay[64], String:sInfo[16];
		
		for(new idx; idx < iSize && idx < 100; idx++)
		{
			GetArrayString(g_hRanksNames[Type][Style], idx, sDisplay, sizeof(sDisplay));
			Format(sDisplay, sizeof(sDisplay), "#%d: %s (%d Pts.)", idx + 1, sDisplay, RoundToNearest(GetArrayCell(g_hRanksPoints[Type][Style], idx)));
			
			FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", GetArrayCell(g_hRanksPlayerID[Type][Style], idx), Type, Style);
			
			if(((idx + 1) % 7) == 0 || (idx + 1) == iSize)
				Format(sDisplay, sizeof(sDisplay), "%s\n--------------------------------------", sDisplay);
			
			AddMenuItem(menu, sInfo, sDisplay);
		}
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		PrintColorText(client, "%s%s%s %s-%s %s %sThere are no ranked players yet.",
			g_msg_start,
			g_msg_varcol,
			sType,
			g_msg_textcol,
			g_msg_varcol,
			sStyle,
			g_msg_textcol);
	}
}

public Menu_ShowTop(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:sInfo[32];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		decl String:sInfoExploded[3][16];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		OpenStatsMenu(param1, StringToInt(sInfoExploded[0]), StringToInt(sInfoExploded[1]), StringToInt(sInfoExploded[2]));
	}
	if(action == MenuAction_End)
		CloseHandle(menu);
}

DB_ShowMapsleft(client, target, Type, Style)
{
	if(GetPlayerID(target) != 0)
	{
		new Handle:pack = CreateDataPack();
		WritePackCell(pack, GetClientUserId(client));
		WritePackCell(pack, GetClientUserId(target));
		
		decl String:sTarget[MAX_NAME_LENGTH];
		GetClientName(target, sTarget, sizeof(sTarget));
		WritePackString(pack, sTarget);
		WritePackCell(pack, Type);
		WritePackCell(pack, Style);
		
		decl String:query[512];
		if(Type == ALL && Style == ALL)
			Format(query, sizeof(query), "SELECT t2.MapName FROM (SELECT maps.MapID AS MapID1, t1.MapID AS MapID2 FROM maps LEFT JOIN (SELECT MapID FROM times WHERE PlayerID=%d) t1 ON maps.MapID=t1.MapID) AS t1, maps AS t2 WHERE t1.MapID1=t2.MapID AND t1.MapID2 IS NULL ORDER BY t2.MapName",
				GetPlayerID(target));
		else
			Format(query, sizeof(query), "SELECT t2.MapName FROM (SELECT maps.MapID AS MapID1, t1.MapID AS MapID2 FROM maps LEFT JOIN (SELECT MapID FROM times WHERE Type=%d AND Style=%d AND PlayerID=%d) t1 ON maps.MapID=t1.MapID) AS t1, maps AS t2 WHERE t1.MapID1=t2.MapID AND t1.MapID2 IS NULL ORDER BY t2.MapName",
				Type,
				Style,
				GetPlayerID(target));
		SQL_TQuery(g_DB, DB_ShowMapsLeft_Callback, query, pack);
	}
	else
	{
		if(client == target)
		{
			PrintColorText(client, "%s%sYour SteamID is not authorized. Steam servers may be down. If not, try reconnecting.",
				g_msg_start,
				g_msg_textcol);
		}
		else
		{
			decl String:name[MAX_NAME_LENGTH];
			GetClientName(target, name, sizeof(name));
			
			PrintColorText(client, "%s%s%s's %sSteamID is not authorized. Steam servers may be down.", 
				g_msg_start,
				g_msg_varcol,
				name,
				g_msg_textcol);
		}
	}
}

public DB_ShowMapsLeft_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new clientUserId = ReadPackCell(data);
		new client       = GetClientOfUserId(clientUserId);
		new targetUserId = ReadPackCell(data);
		
		decl String:sTarget[MAX_NAME_LENGTH];
		ReadPackString(data, sTarget, sizeof(sTarget));
		new Type		= ReadPackCell(data);
		new Style 	= ReadPackCell(data);
		
		if(client != 0)
		{
			new rows = SQL_GetRowCount(hndl), count;
			new String:mapname[128];
			new Handle:menu = CreateMenu(Menu_ShowMapsleft);
			
			new String:sType[32];
			if(Type != ALL)
			{
				GetTypeName(Type, sType, sizeof(sType));
				StringToUpper(sType);
				AddBracketsToString(sType, sizeof(sType));
				AddSpaceToEnd(sType, sizeof(sType));
			}
			
			new String:sStyle[32];
			if(Style != ALL)
			{
				GetStyleName(Style, sStyle, sizeof(sStyle));
				
				Format(sStyle, sizeof(sStyle)," on %s", sStyle);
			}
			
			decl String:title[128];
			if (rows > 0)
			{
				for(new itemnum=1; itemnum<=rows; itemnum++)
				{
					SQL_FetchRow(hndl);
					SQL_FetchString(hndl, 0, mapname, sizeof(mapname));
					if(FindStringInArray(g_MapList, mapname) != -1)
					{
						count++;
						AddMenuItem(menu, mapname, mapname);
					}
				}
				
				if(clientUserId == targetUserId)
				{
					Format(title, sizeof(title), "%d %sMaps left to complete%s",
						count,
						sType,
						sStyle);
				}
				else
				{
					Format(title, sizeof(title), "%d %sMaps left to complete%s for player %s",
						count,
						sType,
						sStyle,
						sTarget);
				}
				SetMenuTitle(menu, title);
			}
			else
			{
				if(clientUserId == targetUserId)
				{
					PrintColorText(client, "%s%s%s%sYou have no maps left to beat%s%s.", 
						g_msg_start,
						g_msg_varcol,
						sType,
						g_msg_textcol,
						g_msg_varcol,
						sStyle);
				}
				else
				{
					PrintColorText(client, "%s%s has no maps left to beat%s.", 
						g_msg_start,
						g_msg_varcol,
						sType,
						sTarget,
						g_msg_textcol,
						g_msg_varcol,
						sStyle);
				}
			}
			
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
	}
	else
	{
		LogError(error);
	}
	CloseHandle(data);
}

public Menu_ShowMapsleft(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		FakeClientCommand(param1, "sm_nominate %s", info);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

DB_ShowMapsdone(client, PlayerID, Type, Style)
{
	new Handle:menu = CreateMenu(Menu_ShowMapsdone);
	
	decl String:sType[32];
	GetTypeName(Type, sType, sizeof(sType));
	
	decl String:sStyle[32];
	GetStyleName(Style, sStyle, sizeof(sStyle));
	
	decl String:sName[MAX_NAME_LENGTH];
	GetNameFromPlayerID(PlayerID, sName, sizeof(sName));
	
	new Handle:hCell = GetArrayCell(g_hMapsDone[Type][Style], PlayerID);
	
	if(hCell != INVALID_HANDLE)
	{
		new iSize = GetArraySize(hCell);
		decl String:sMapName[64], String:sTime[32], String:sDisplay[128];
		for(new idx; idx < iSize; idx++)
		{
			GetMapNameFromMapId(GetArrayCell(hCell, idx, 0), sMapName, sizeof(sMapName));
			new Position   = GetArrayCell(hCell, idx, 1);
			new Float:Time = GetArrayCell(hCell, idx, 2);
			FormatPlayerTime(Time, sTime, sizeof(sTime), false, 1);
			
			FormatEx(sDisplay, sizeof(sDisplay), "%s: %s (#%d)", sMapName, sTime, Position);
			
			if(((idx + 1) % 7) == 0 || (idx + 1) == iSize)
				Format(sDisplay, sizeof(sDisplay), "%s\n--------------------------------------", sDisplay);
			
			AddMenuItem(menu, sMapName, sDisplay);
		}
		
		SetMenuTitle(menu, "Maps done for %s [%s] - [%s]\n \nCompleted %d / %d\n-----------------------------------", sName, sType, sStyle, iSize, GetArraySize(g_MapList));
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		PrintColorText(client, "%s%s%s %shas no maps done.",
			g_msg_start,
			g_msg_varcol,
			sName,
			g_msg_textcol);
	}
}
 
public Menu_ShowMapsdone_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client      = ReadPackCell(data);
		new target      = ReadPackCell(data);
		new Type        = ReadPackCell(data);
		new Style       = ReadPackCell(data);
	   
		new rows = SQL_GetRowCount(hndl);
		
		new String:sType[32];
		if(Type != ALL)
		{
			GetTypeName(Type, sType, sizeof(sType));
			StringToUpper(sType);
			AddBracketsToString(sType, sizeof(sType));
			AddSpaceToEnd(sType, sizeof(sType));
		}
		
		new String:sStyle[32];
		if(Style != ALL)
		{
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			Format(sStyle, sizeof(sStyle)," on %s", sStyle);
		}
		
		if(rows != 0)
		{
			new Handle:menu = CreateMenu(Menu_ShowMapsdone);
			decl String:sMapName[64];
			new mapsdone;
			
			for(new i=0; i<rows; i++)
			{
				SQL_FetchRow(hndl);
				
				SQL_FetchString(hndl, 0, sMapName, sizeof(sMapName));
				
				if(FindStringInArray(g_MapList, sMapName) != -1)
				{
					AddMenuItem(menu, sMapName, sMapName);
					mapsdone++;
				}
			}
			
			if(client == target)
			{
				SetMenuTitle(menu, "%s%d maps done%s",
					sType,
					mapsdone,
					sStyle);
			}
			else
			{
				decl String:sTargetName[MAX_NAME_LENGTH];
				GetClientName(target, sTargetName, sizeof(sTargetName));
				
				SetMenuTitle(menu, "%s%d maps done by %s%s",
					sType,
					mapsdone,
					sTargetName,
					sStyle);
			}
			
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			if(client == target)
			{
				PrintColorText(client, "%s%s%s%sYou haven't finished any maps%s%s.",
					g_msg_start,
					g_msg_varcol,
					sType,
					g_msg_textcol,
					g_msg_varcol,
					sStyle);
			}
			else
			{
				decl String:targetname[MAX_NAME_LENGTH];
				GetClientName(target, targetname, sizeof(targetname));
					
				PrintColorText(client, "%s%s doesn't have any maps finished%s.",
					g_msg_start,
					g_msg_varcol,
					sType,
					targetname,
					g_msg_textcol,
					g_msg_varcol,
					sStyle);
			}
		}
	}
	else
	{
		LogError(error);
	}
	CloseHandle(data);
}
 
public Menu_ShowMapsdone(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		FakeClientCommand(param1, "sm_nominate %s", info);
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

public OnTimesUpdated(const String:sMapName[], Type, Style, Handle:Times)
{
	// Formula: (#Times - MapRank) * AverageTime / 10
	
	new Size = GetArraySize(Times);
	
	new Float:fTimeSum;
	for(new idx; idx < Size; idx++)
		fTimeSum += Float:GetArrayCell(Times, idx, 1);
	
	new Float:fAverage = fTimeSum / float(Size);
	
	new QuerySize = 200 + (50 * Size);
	decl String:query[QuerySize];
	FormatEx(query, QuerySize, "UPDATE times SET Points = CASE PlayerID ");
	
	for(new idx; idx < Size; idx++)
		Format(query, QuerySize, "%sWHEN %d THEN %f ", query, GetArrayCell(Times, idx), (float(Size) - float(idx)) * fAverage / 10.0);
	
	Format(query, QuerySize, "%sEND WHERE MapID = (SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d", query, sMapName, Type, Style);
	
	SQL_TQuery(g_DB, TimesUpdated_Callback, query);
}

public TimesUpdated_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError(error);
}

UpdateRanks(const String:sMapName[], Type, Style, bool:recalc = false)
{
	decl String:query[700];
	Format(query, sizeof(query), "UPDATE times SET Points = (SELECT t1.Rank FROM (SELECT count(*)*(SELECT AVG(Time) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d)/10 AS Rank, t1.rownum FROM times AS t1, times AS t2 WHERE t1.MapID=t2.MapID AND t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.Type=t2.Type AND t1.Type=%d AND t1.Style=t2.Style AND t1.Style=%d AND t1.Time <= t2.Time GROUP BY t1.PlayerID ORDER BY t1.Time) AS t1 WHERE t1.rownum=times.rownum) WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d",
		sMapName,
		Type,
		Style,
		sMapName,
		Type,
		Style,
		sMapName,
		Type,
		Style);
	
	new	Handle:pack = CreateDataPack();
	WritePackCell(pack, recalc);
	WritePackString(pack, sMapName);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	
	SQL_TQuery(g_DB, DB_UpdateRanks_Callback, query, pack);
	
	//if(recalc == false)
	//{
	//	for(new client=1; client <= MaxClients; client++)
	//		DB_SetClientRank(client);
	//}
}

public Native_UpdateRanks(Handle:plugin, numParams)
{
	decl String:sMapName[128];
	GetNativeString(1, sMapName, sizeof(sMapName));
	
	UpdateRanks(sMapName, GetNativeCell(2), GetNativeCell(3));
}

public DB_UpdateRanks_Callback(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(pack);
		new bool:recalc = bool:ReadPackCell(pack);
		
		if(recalc == true)
		{
			decl String:sMapName[64];
			ReadPackString(pack, sMapName, sizeof(sMapName));
			new Type  = ReadPackCell(pack);
			new Style = ReadPackCell(pack);
			
			decl String:sType[16];
			GetTypeName(Type, sType, sizeof(sType));
			StringToUpper(sType);
			AddBracketsToString(sType, sizeof(sType));
			AddSpaceToEnd(sType, sizeof(sType));
			
			decl String:sStyle[16];
			GetStyleName(Style, sStyle, sizeof(sStyle));
			StringToUpper(sStyle);
			AddBracketsToString(sStyle, sizeof(sStyle));
			
			g_RecalcProgress += 1;
			
			for(new client = 1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client))
				{
					if(!IsFakeClient(client))
					{
						PrintToConsole(client, "[%.1f%%] %s %s%s finished recalculation.",
							float(g_RecalcProgress)/float(g_RecalcTotal) * 100.0,
							sMapName,
							sType[Type],
							sStyle[Style]);
					}
				}
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(pack);
}

SetClientRank(client)
{
	new PlayerID = GetPlayerID(client);
	if(PlayerID != 0 && IsClientConnected(client) && !IsFakeClient(client))
	{		
		for(new Type; Type < MAX_TYPES; Type++)
		{
			for(new Style; Style < MAX_STYLES; Style++)
			{
				if(Style_IsEnabled(Style) && Style_IsTypeAllowed(Style, Type))
				{
					g_Rank[client][Type][Style] = FindValueInArray(g_hRanksPlayerID[Type][Style], PlayerID) + 1;
				}
			}
		}
	}
}

public PlayerManager_OnThinkPost(entity)
{
	new m_iMVPs[MaxClients + 1];
	//GetEntDataArray(entity, g_iMVPs_offset, m_iMVPs, MaxClients);

	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && GetPlayerID(client) != 0)
		{
			m_iMVPs[client] = g_RecordCount[client];
		}
	}
	
	SetEntDataArray(entity, g_iMVPs_offset, m_iMVPs, MaxClients + 1);
}

SetRecordCount(client)
{
	new idx = FindValueInArray(g_hRecordListID[TIMER_MAIN][0], GetPlayerID(client));
	
	if(idx != -1)
	{
		g_RecordCount[client] = GetArrayCell(g_hRecordListCount[TIMER_MAIN][0], idx);
	}
}

DB_LoadStats()
{
	#if defined DEBUG
		LogMessage("Loading stats (Getting max PlayerID)");
	#endif
	
	decl String:query[128];
	FormatEx(query, sizeof(query), "SELECT MAX(PlayerID) FROM times");
	SQL_TQuery(g_DB, LoadStats_Callback, query);
}

public LoadStats_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		#if defined DEBUG
			LogMessage("Loading stats (Selecting all times)");
		#endif
		
		if(SQL_GetRowCount(hndl) != 0)
		{
			SQL_FetchRow(hndl);
			
			new Handle:pack = CreateDataPack();
			WritePackCell(pack, SQL_FetchInt(hndl, 0));
			
			decl String:query[256];
			FormatEx(query, sizeof(query), "SELECT t1.MapID, t1.Type, t1.Style, t1.PlayerID, t1.Time, t1.Points FROM times AS t1, maps AS t2 WHERE t1.MapID=t2.MapID ORDER BY t2.MapName, t1.Type, t1.Style, t1.Time");
			SQL_TQuery(g_DB, LoadStats_Callback2, query, pack);
		}
	}
	else
	{
		LogError(error);
	}
}

public LoadStats_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		#if defined DEBUG
			LogMessage("Stats retrieved, importing to adt_array");
		#endif
		
		ResetPack(data);
		new MaxPlayerID = ReadPackCell(data);
		
		new iSize, idx;
		for(new Type; Type < MAX_TYPES; Type++)
		{
			for(new Style; Style < MAX_STYLES; Style++)
			{
				// Close old handles
				iSize = GetArraySize(g_hMapsDoneHndlRef[Type][Style]);
				for(new i; i < iSize; i++)
				{
					idx = GetArrayCell(g_hMapsDoneHndlRef[Type][Style], 0);
					RemoveFromArray(g_hMapsDoneHndlRef[Type][Style], 0);
					CloseHandle(GetArrayCell(g_hMapsDone[Type][Style], idx));
				}
				
				ClearArray(g_hMapsDone[Type][Style]);
				ResizeArray(g_hMapsDone[Type][Style], MaxPlayerID + 1);
				
				for(new i; i < MaxPlayerID + 1; i++)
				{
					SetArrayCell(g_hMapsDone[Type][Style], i, 0);
				}
				
				ClearArray(g_hRecordListID[Type][Style]);
				ClearArray(g_hRecordListCount[Type][Style]);
			}
		}
		
		new Position;
		new lMapID, lType, lStyle;
		new MapID, Type, Style, PlayerID, Float:Time;
		decl String:sMapName[64];
		
		while(SQL_FetchRow(hndl))
		{
			MapID    = SQL_FetchInt(hndl, 0);
			Type     = SQL_FetchInt(hndl, 1);
			Style    = SQL_FetchInt(hndl, 2);
			PlayerID = SQL_FetchInt(hndl, 3);
			Time     = SQL_FetchFloat(hndl, 4);
			
			if(lMapID != MapID || lType != Type || lStyle != Style)
				Position = 0;
			Position++;
			
			//if(!(Style_IsEnabled(Style) && Style_IsTypeAllowed(Style, Type)))
			//	continue;
			
			GetMapNameFromMapId(MapID, sMapName, sizeof(sMapName));
			
			if(FindStringInArray(g_MapList, sMapName) == -1)
				continue;
			
			if(Position == 1)
			{
				AddToRecordList(PlayerID, Type, Style);
			}
			
			if(GetArrayCell(g_hMapsDone[Type][Style], PlayerID) == INVALID_HANDLE)
			{
				new Handle:hCell = CreateArray(3);
				SetArrayCell(g_hMapsDone[Type][Style], PlayerID, hCell);
				
				PushArrayCell(g_hMapsDoneHndlRef[Type][Style], PlayerID);
			}
			
			new Handle:hCell = GetArrayCell(g_hMapsDone[Type][Style], PlayerID);
			
			iSize = GetArraySize(hCell);
			ResizeArray(hCell, iSize + 1);
			
			SetArrayCell(hCell, iSize, MapID, 0);
			SetArrayCell(hCell, iSize, Position, 1);
			SetArrayCell(hCell, iSize, Time, 2);
			
			lMapID = MapID;
			lType  = Type;
			lStyle = Style;
		}
		
		for(new client = 1; client <= MaxClients; client++)
		{
			if(GetPlayerID(client) != 0)
			{
				SetRecordCount(client);
			}
		}
		
		DB_LoadRankList();
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

AddToRecordList(PlayerID, Type, Style)
{
	new idx = FindValueInArray(g_hRecordListID[Type][Style], PlayerID);
	
	new RecordCount;
	
	if(idx == -1)
	{
		RecordCount = 1;
		
		new iSize = GetArraySize(g_hRecordListID[Type][Style]);
		
		ResizeArray(g_hRecordListID[Type][Style], iSize + 1);
		ResizeArray(g_hRecordListCount[Type][Style], iSize + 1);
		
		SetArrayCell(g_hRecordListID[Type][Style], iSize, PlayerID);
		SetArrayCell(g_hRecordListCount[Type][Style], iSize, RecordCount);
	}
	else
	{
		RecordCount = GetArrayCell(g_hRecordListCount[Type][Style], idx) + 1;
		RemoveFromArray(g_hRecordListID[Type][Style], idx);
		RemoveFromArray(g_hRecordListCount[Type][Style], idx);
		
		new iSize = GetArraySize(g_hRecordListID[Type][Style]);
		
		for(new i; i < iSize; i++)
		{
			if(RecordCount > GetArrayCell(g_hRecordListCount[Type][Style], i))
			{
				ShiftArrayUp(g_hRecordListID[Type][Style], i);
				ShiftArrayUp(g_hRecordListCount[Type][Style], i);
				
				SetArrayCell(g_hRecordListID[Type][Style], i, PlayerID);
				SetArrayCell(g_hRecordListCount[Type][Style], i, RecordCount);
				
				break;
			}
		}
	}
}

DB_LoadRankList()
{	
	#if defined DEBUG
		LogMessage("Selecting rank list");
	#endif
	
	// Load ranks only for maps on the server
	new iSize = GetArraySize(g_MapList);
	new QuerySize = 220 + (iSize * 128);
	decl String:query[QuerySize];
	FormatEx(query, QuerySize, "SELECT t2.User, t1.PlayerID, SUM(t1.Points), t1.Type, t1.Style FROM times AS t1, players AS t2 WHERE t1.PlayerID=t2.PlayerID AND (");
	
	decl String:sMapName[64];
	for(new idx; idx < iSize; idx++)
	{
		GetArrayString(g_MapList, idx, sMapName, sizeof(sMapName));
		
		Format(query, QuerySize, "%st1.MapID = (SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1)", query, sMapName);
		
		if(idx < iSize - 1)
		{
			Format(query, QuerySize, "%s OR ", query);
		}
	}
	
	Format(query, QuerySize, "%s) GROUP BY t1.PlayerID, t1.Type, t1.Style ORDER BY t1.Type, t1.Style, SUM(t1.Points) DESC", query);
	
	SQL_TQuery(g_DB, LoadRankList_Callback, query);
}

public LoadRankList_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		#if defined DEBUG
			PrintToServer("Rank list selected, loading into adt_array");
		#endif
		
		for(new Type; Type < MAX_TYPES; Type++)
		{
			for(new Style; Style < MAX_STYLES; Style++)
			{
				if(Style_IsEnabled(Style) && Style_IsTypeAllowed(Style, Type))
				{
					ClearArray(g_hRanksPlayerID[Type][Style]);
					ClearArray(g_hRanksPoints[Type][Style]);
					ClearArray(g_hRanksNames[Type][Style]);
				}
			}
		}
		
		new String:sName[MAX_NAME_LENGTH], PlayerID, Float:Points, Type, Style, iSize;
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sName, sizeof(sName));
			PlayerID = SQL_FetchInt(hndl, 1);
			Points   = SQL_FetchFloat(hndl, 2);
			Type     = SQL_FetchInt(hndl, 3);
			Style    = SQL_FetchInt(hndl, 4);
			
			if(!(Style_IsEnabled(Style) && Style_IsTypeAllowed(Style, Type)))
				continue;
			
			iSize = GetArraySize(g_hRanksPlayerID[Type][Style]);
			
			ResizeArray(g_hRanksNames[Type][Style], iSize + 1);
			SetArrayString(g_hRanksNames[Type][Style], iSize, sName);
			
			ResizeArray(g_hRanksPlayerID[Type][Style], iSize + 1);
			SetArrayCell(g_hRanksPlayerID[Type][Style], iSize, PlayerID);
			
			ResizeArray(g_hRanksPoints[Type][Style], iSize + 1);
			SetArrayCell(g_hRanksPoints[Type][Style], iSize, Points);
		}
		
		for(new client = 1; client <= MaxClients; client++)
		{
			if(GetPlayerID(client) != 0)
			{
				SetClientRank(client);
			}
		}
		
		g_bStatsLoaded = true;
	}
	else
	{
		LogError(error);
	}
}

DB_Connect()
{
	if(g_DB != INVALID_HANDLE)
	{
		CloseHandle(g_DB);
	}
	
	decl String:error[255];
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	
	if(g_DB == INVALID_HANDLE)
	{
		LogError(error);
		CloseHandle(g_DB);
	}
	else
	{
		// Custom chat tags
		LoadCustomChat();
	}
}