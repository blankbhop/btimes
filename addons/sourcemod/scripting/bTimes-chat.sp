#include <bTimes-core>
#include <sourcemod>
#include <csgocolors>
#include <cstrike>

#undef REQUIRE_PLUGIN
#include <smartmsg>
#include <bTimes-rank2>
#include <scp>
#include <chat-processor>

public Plugin myinfo = 
{
	name = "[Timer] - Chat",
	author = "blacky",
	description = "Chat ranks",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

KeyValues g_Kv;
int g_CurrentKvChatRank;
ArrayList g_hChatRanks[MAXPLAYERS + 1];
ArrayList g_hAttainableRanksList;

bool g_bLateLoad;
bool g_bAdminLoaded[MAXPLAYERS + 1];
bool g_bChatRankLoaded[MAXPLAYERS + 1];
bool g_bClientHasCustom[MAXPLAYERS + 1];

Handle g_hChatRankCookie;
Handle g_hCCName_Init;
Handle g_hCCName;
Handle g_hCCName_Enabled;
Handle g_hCCMsg;
Handle g_hCCMsg_Enabled;
Handle g_hCCTag;
Handle g_hCCTag_Enabled;
Handle g_hHideChat;

EngineVersion g_Engine;
bool g_bNewMessage;

bool g_bSmartMsgLoaded;
bool g_bRanksLoaded;

public void OnPluginStart()
{
	g_Engine = GetEngineVersion();
	
	// Player commands
	RegConsoleCmdEx("sm_chatrank", SM_Chat,     "Change your preferred chat rank.");
	RegConsoleCmdEx("sm_ranks",    SM_Ranks,    "Show list of attainable chat ranks.");
	RegConsoleCmdEx("sm_ccname",   SM_CCName,   "Change your custom chat name.");
	RegConsoleCmdEx("sm_ccmsg",    SM_CCMsg,    "Change your message color.");
	RegConsoleCmdEx("sm_cctag",    SM_CCTag,    "Change your clan tag");
	RegConsoleCmdEx("sm_cchelp",   SM_CCHelp,   "Tutorial on how to use the custom chat features.");
	//RegConsoleCmdEx("sm_ccdel",    SM_CCDel,    "Change your message delimiter.");
	RegConsoleCmdEx("sm_hidechat", SM_HideChat, "Hides all chat");
	
	// All chat
	AddCommandListener(Command_Say, "say");
	
	// Admin commands
	RegConsoleCmd("sm_reloadcr", SM_ReloadCR, "Reload chat ranks.");

	g_hAttainableRanksList = CreateArray();
	LoadChatRanks();

	g_hChatRankCookie = RegClientCookie("timer_chatrank",       "Preferred chat rank", CookieAccess_Protected);
	g_hCCName_Init    = RegClientCookie("timer_ccname_init",    "Useful to know if your custom chat name has ever been set to anything to prevent blank names.", CookieAccess_Protected);
	g_hCCName         = RegClientCookie("timer_ccname",         "Name used for the custom chat tag", CookieAccess_Protected);
	g_hCCName_Enabled = RegClientCookie("timer_ccname_enabled", "Enable your custom chat name if you are allowed to use it.", CookieAccess_Public);
	g_hCCMsg          = RegClientCookie("timer_ccmsg",          "Message color used for the custom chat tag", CookieAccess_Protected);
	g_hCCMsg_Enabled  = RegClientCookie("timer_ccmsg_enabled",  "Enable your custom chat message color if you are allowed to use it.", CookieAccess_Public);
	g_hCCTag          = RegClientCookie("timer_cctag",          "Custom clan tag", CookieAccess_Protected);
	g_hCCTag_Enabled  = RegClientCookie("timer_cctag_enabled",  "Enable your custom clan tag", CookieAccess_Public);
	g_hHideChat       = RegClientCookie("timer_hidechat",       "Hides all chat", CookieAccess_Public);
	SetCookieMenuItem(Menu_CookieChanged, g_hHideChat, "Hide chat");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerSpawn);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	
	if(late)
	{
		UpdateMessages();
	}
}

bool g_bFirstLateLoadMap = true;
public void OnMapStart()
{
	if(g_bLateLoad == true && g_bFirstLateLoadMap == true)
	{	
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && !IsFakeClient(client))
			{
				g_hChatRanks[client] = CreateArray(2);
				g_bAdminLoaded[client] = true;
				GetClientAvailableChatRanks(client);
				g_bLateLoad = false;
			}
		}
		
		g_bFirstLateLoadMap = false;
	}
	
	CreateTimer(1.0, Timer_CheckClanTags, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void Menu_CookieChanged(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if(action == CookieMenuAction_SelectOption)
	{
		if(info == g_hHideChat)
		{
			FakeClientCommand(client, "sm_hidechat");
		}
	}
}

public void OnAllPluginsLoaded()
{
	if(LibraryExists("smartmsg") && g_bSmartMsgLoaded == false)
	{
		g_bSmartMsgLoaded = true;
		RegisterSmartMessage(SmartMessage_ChatRank);
		RegisterSmartMessage(SmartMessage_CustomChat);
	}
	
	if(LibraryExists("ranks"))
	{
		g_bRanksLoaded = true;
	}
}

public void OnLibraryRemoved(const char[] library)
{
	if(StrEqual(library, "smartmsg"))
	{
		g_bSmartMsgLoaded = false;
	}
	else if(StrEqual(library, "ranks"))
	{
		g_bRanksLoaded = false;
		
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				GetClientAvailableChatRanks(client);
			}
		}
	}
}

public void OnLibraryAdded(const char[] library)
{
	if(StrEqual(library, "smartmsg"))
	{
		g_bSmartMsgLoaded = true;
		RegisterSmartMessage(SmartMessage_ChatRank);
		RegisterSmartMessage(SmartMessage_CustomChat);
		RegisterSmartMessage(SmartMessage_HideChat);
	}
	else if(StrEqual(library, "ranks"))
	{
		g_bRanksLoaded = true;
	}
}

public bool SmartMessage_ChatRank(int client)
{
	if(g_hChatRanks[client] != INVALID_HANDLE && GetArraySize(g_hChatRanks[client]) >= 2)
	{
		PrintColorText(client, "%s%sHave another chat rank you want to use? You can change it by typing %s!chatrank%s.",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
		return true;
	}
	
	return false;
}

public bool SmartMessage_CustomChat(int client)
{
	if(g_bClientHasCustom[client] == true)
	{
		if(GetCookieBool(client, g_hCCName_Enabled) == false)
		{
			PrintColorText(client, "%s%sYou have custom chat abilities and can enable them by typing %s!ccname%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_msg_textcol);
			return true;
		}
		
	}
	
	return false;
}

public bool SmartMessage_HideChat(int client)
{
	if(GetCookieBool(client, g_hHideChat) == false)
	{
		PrintColorText(client, "%s%sChat annoying you? You can disable it with %s!hidechat%s.",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
		return true;
	}
	
	return false;
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	g_bChatRankLoaded[client] = false;
	
	if(g_hChatRanks[client] == INVALID_HANDLE)
	{
		g_hChatRanks[client] = CreateArray(2);
	}
	
	ClearArray(g_hChatRanks[client]);
	
	return true;
}

public void OnClientCookiesCached(int client)
{
	char sCookie[32];
	GetClientCookie(client, g_hHideChat, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hHideChat, false);
	}
}

public Action:Command_Say(client, const String:command[], argc)
{
	g_bNewMessage = true;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client != 0 && !IsFakeClient(client))
	{
		if(g_bChatRankLoaded[client] == true)
		{
			char sTag[128];
			if(g_bClientHasCustom[client] && GetCookieBool(client, g_hCCTag_Enabled))
			{
				GetClientCookie(client, g_hCCTag, sTag, sizeof(sTag));
			}
			else
			{
				GetChatRankTag(GetCookieInt(client, g_hChatRankCookie), sTag, sizeof(sTag));
			}
			
			CS_SetClientClanTag(client, sTag);
			
		}
		else
		{
			CS_SetClientClanTag(client, "[Loading...]");
		}
		
	}
}

public Action SM_ReloadCR(int client, int args)
{
	if(!Timer_ClientHasTimerFlag(client, "config", Admin_Config))
	{
		ReplyToCommand(client, "[SM] You do not have access to this command.");
		return Plugin_Continue;
	}
	
	
	LoadChatRanks();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			GetClientAvailableChatRanks(i);
		}
	}
	
	PrintColorTextAll("%s%sChat ranks reloaded.",
		g_msg_start,
		g_msg_textcol);
	
	return Plugin_Handled;
}

public Action Timer_CheckClanTags(Handle timer, Handle data)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && (g_bLateLoad || g_bAdminLoaded[client]) && g_bChatRankLoaded[client])
		{
			//if(IsBlacky(client)) PrintToChat(client, "Test 1");
			char sExpectedTag[128];
			if(g_bClientHasCustom[client] && GetCookieBool(client, g_hCCTag_Enabled))
			{
				GetClientCookie(client, g_hCCTag, sExpectedTag, sizeof(sExpectedTag));
			}
			else
			{
				GetChatRankTag(GetCookieInt(client, g_hChatRankCookie), sExpectedTag, sizeof(sExpectedTag));
			}
			
			char sCurrentTag[64];
			CS_GetClientClanTag(client, sCurrentTag, sizeof(sCurrentTag));
			
			if(!StrEqual(sExpectedTag, sCurrentTag))
			{
				//if(IsBlacky(client)) PrintToChat(client, "Test 2");
				CS_SetClientClanTag(client, sExpectedTag);
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	g_bAdminLoaded[client] = false;
}

public void OnClientPutInServer(int client)
{
	if(g_hChatRanks[client] == INVALID_HANDLE)
	{
		g_hChatRanks[client] = CreateArray(2);
	}
		
	ClearArray(g_hChatRanks[client]);
}

public void OnClientPostAdminCheck(int client)
{
	g_bAdminLoaded[client] = true;
	
	GetClientAvailableChatRanks(client);
}

public void OnClientRankLoaded(int client)
{
	GetClientAvailableChatRanks(client);
}

public void OnClientOverallRankChanged(int client, int oldRank, int newRank)
{
	GetClientAvailableChatRanks(client);
}

public void OnClientStyleRankChanged(int client, int oldRank, int newRank, int Type, int style)
{
	GetClientAvailableChatRanks(client);
}

public Action SM_Ranks(int client, int args)
{
	Menu menu = new Menu(Menu_AttainableRanks);
	menu.SetTitle("List of Attainable Chat Ranks\n ");
	
	int iSize = GetArraySize(g_hAttainableRanksList), id;
	char sInfo[8], sTag[128], sDesc[128], sDisplay[256];
	for(int idx; idx < iSize; idx++)
	{
		id = GetArrayCell(g_hAttainableRanksList, idx);
		
		IntToString(id, sInfo, sizeof(sInfo));
		GetChatRankTag(id, sTag, sizeof(sTag));
		GetChatRankDescription(id, sDesc, sizeof(sDesc));
		FormatEx(sDisplay, sizeof(sDisplay), "%s\n %s", sTag, sDesc);
		
		if(ClientHasChatRank(client, id))
		{
			Format(sDisplay, sizeof(sDisplay), "-> %s", sDisplay);
		}
		
		menu.AddItem(sInfo, sDisplay);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int Menu_AttainableRanks(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action SM_HideChat(int client, int args)
{
	if(!AreClientCookiesCached(client))
	{
		PrintColorText(client, "%s%sYour client settings have not been loaded yet.",
			g_msg_start,
			g_msg_textcol);
		return Plugin_Handled;
	}
	bool bHideChat = GetCookieBool(client, g_hHideChat);
	
	SetCookieBool(client, g_hHideChat, !bHideChat);
	
	
	if(bHideChat)
	{
		PrintColorText(client, "%s%sChat is now visible (Saved)",
			g_msg_start,
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%sChat is now invisible (Saved)",
			g_msg_start,
			g_msg_textcol);
	}

	return Plugin_Handled;
}

int g_iShowChatRanksTarget[MAXPLAYERS + 1];

public Action SM_Chat(int client, int args)
{
	if(args == 0)
	{
		g_iShowChatRanksTarget[client] = GetClientUserId(client);
		ShowChatRanks(client, client);
	}
	else
	{
		char sName[MAX_NAME_LENGTH];
		GetCmdArgString(sName, MAX_NAME_LENGTH);
		int target = FindTarget(client, sName, true, false);
		
		if(target != -1)
		{
			g_iShowChatRanksTarget[client] = GetClientUserId(target);
			ShowChatRanks(client, target);
		}
	}

	return Plugin_Handled;
}

void ShowChatRanks(int client, int target)
{
	Menu menu = new Menu(Menu_ChatRanks);
	menu.SetTitle("Select Chat Rank\n ");
	
	if(g_bClientHasCustom[target])
	{
		bool n = GetCookieBool(target, g_hCCName_Enabled);
		bool m = GetCookieBool(target, g_hCCMsg_Enabled);
		bool c = GetCookieBool(target, g_hCCTag_Enabled);
		menu.AddItem("customname", n?"Custom Name: On":"Custom Name: Off", client == target?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		menu.AddItem("custommsg", m?"Custom Message: On":"Custom Message: Off", client == target?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		menu.AddItem("customtag", c?"Custom Clan Tag: On\n ":"Custom Clan Tag: Off\n ", client == target?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}
	
	int iSize = GetArraySize(g_hChatRanks[target]), id;
	char sInfo[8], sTag[128], sDesc[128], sDisplay[256];
	for(int idx; idx < iSize; idx++)
	{
		id = GetArrayCell(g_hChatRanks[target], idx);
		
		IntToString(id, sInfo, sizeof(sInfo));
		GetChatRankTag(id, sTag, sizeof(sTag));
		GetChatRankDescription(id, sDesc, sizeof(sDesc));
		FormatEx(sDisplay, sizeof(sDisplay), "%s\n %s", sTag, sDesc);
		
		menu.AddItem(sInfo, sDisplay, client == target?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_ChatRanks(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "customname"))
		{
			SetCookieBool(client, g_hCCName_Enabled, !GetCookieBool(client, g_hCCName_Enabled));
	
			if(GetCookieBool(client, g_hCCName_Enabled))
			{
				PrintColorText(client, "%s%sCustom name setting enabled.",
					g_msg_start,
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%sCustom name setting disabled.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		else if(StrEqual(sInfo, "custommsg"))
		{
			SetCookieBool(client, g_hCCMsg_Enabled, !GetCookieBool(client, g_hCCMsg_Enabled));
	
			if(GetCookieBool(client, g_hCCMsg_Enabled))
			{
				PrintColorText(client, "%s%sCustom message setting enabled.",
					g_msg_start,
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%sCustom message setting disabled.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		else if(StrEqual(sInfo, "customtag"))
		{
			SetCookieBool(client, g_hCCTag_Enabled, !GetCookieBool(client, g_hCCTag_Enabled));
	
			char sTag[128];
			if(GetCookieBool(client, g_hCCTag_Enabled))
			{
				PrintColorText(client, "%s%sCustom clan tag setting enabled.",
					g_msg_start,
					g_msg_textcol);
				GetClientCookie(client, g_hCCTag, sTag, sizeof(sTag));
				
			}
			else
			{
				PrintColorText(client, "%s%sCustom clan tag setting disabled.",
					g_msg_start,
					g_msg_textcol);
				GetChatRankTag(GetCookieInt(client, g_hChatRankCookie), sTag, sizeof(sTag));
			}
			CS_SetClientClanTag(client, sTag);
		}
		else
		{
			SetCookieInt(client, g_hChatRankCookie, StringToInt(sInfo));
		
			char sTag[128];
			GetChatRankTag(GetCookieInt(client, g_hChatRankCookie), sTag, sizeof(sTag));
			CS_SetClientClanTag(client, sTag);
			
			PrintColorText(client, "%s%sYou changed your chat rank to %s%s%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sTag,
				g_msg_textcol);
		}
		
		int target = GetClientOfUserId(g_iShowChatRanksTarget[client]);
		if(target != 0)
		{
			ShowChatRanks(client, target);
		}
		
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action SM_CCName(int client, int args)
{
	if(args == 0)
	{
		SetCookieBool(client, g_hCCName_Enabled, !GetCookieBool(client, g_hCCName_Enabled));
	
		if(GetCookieBool(client, g_hCCName_Enabled))
		{
			PrintColorText(client, "%s%sCustom name setting enabled.%s",
				g_msg_start,
				g_msg_textcol,
				g_bClientHasCustom[client] == false?" However, you do not have the custom chat privileges to use it.":"");
		}
		else
		{
			PrintColorText(client, "%s%sCustom name setting disabled.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		char sArg[256];
		GetCmdArgString(sArg, sizeof(sArg));
		SetClientCookie(client, g_hCCName, sArg);
		PrintColorText(client, "%s%sCustom chat name changed to %s",
			g_msg_start,
			g_msg_textcol,
			sArg);
	}
	
	return Plugin_Handled;
}

public Action SM_CCMsg(int client, int args)
{
	if(args == 0)
	{
		SetCookieBool(client, g_hCCMsg_Enabled, !GetCookieBool(client, g_hCCMsg_Enabled));
	
		if(GetCookieBool(client, g_hCCMsg_Enabled))
		{
			PrintColorText(client, "%s%sCustom message setting enabled.%s",
				g_msg_start,
				g_msg_textcol,
				g_bClientHasCustom[client] == false?" However, you do not have the custom chat privileges to use it.":"");
		}
		else
		{
			PrintColorText(client, "%s%sCustom message setting disabled.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		char sArg[256], sMessage[256];
		GetCmdArgString(sArg, sizeof(sArg));
		if(IsValidColor(sArg, sMessage, sizeof(sMessage)))
		{
			SetClientCookie(client, g_hCCMsg, sArg);
			PrintColorText(client, "%s%sCustom message color changed to %s",
				g_msg_start,
				g_msg_textcol,
				sArg);
		}
		else
		{
			PrintColorText(client, "%s%sFailed to change message color. (%s)",
				g_msg_start,
				g_msg_textcol,
				sMessage);
		}
	}
	
	return Plugin_Handled;
}

public Action SM_CCTag(int client, int args)
{
	if(args == 0)
	{
		SetCookieBool(client, g_hCCTag_Enabled, !GetCookieBool(client, g_hCCTag_Enabled));
	
		if(GetCookieBool(client, g_hCCTag_Enabled))
		{
			PrintColorText(client, "%s%sCustom clan tag setting enabled.%s",
				g_msg_start,
				g_msg_textcol,
				g_bClientHasCustom[client] == false?" However, you do not have the custom chat privileges to use it.":"");
		}
		else
		{
			PrintColorText(client, "%s%sCustom clan tag setting disabled.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		char sArg[256];
		GetCmdArgString(sArg, sizeof(sArg));
		SetClientCookie(client, g_hCCTag, sArg);
		PrintColorText(client, "%s%sCustom clan tag changed to %s",
			g_msg_start,
			g_msg_textcol,
			sArg);
		CS_SetClientClanTag(client, sArg);
	}
	
	return Plugin_Handled;
}

bool IsValidColor(const char[] color, char[] message, int maxlength)
{
	if(g_Engine == Engine_CSS)
	{
		if(StrEqual(color, "{rand}"))
		{
			return true;
		}
		
		int len = strlen(color);
		
		if(len > 7)
		{
			FormatEx(message, maxlength, "String too long. Type !cchelp for more info.");
			return false;
		}
		
		else if(len < 7)
		{
			FormatEx(message, maxlength, "String too short. Type !cchelp for more info.");
			return false;
		}
		
		if(color[0] != '^')
		{
			FormatEx(message, maxlength, "String did not start with a '^'");
			return false;
		}
		
		int charValue;
		for(int idx; idx < 6; idx++)
		{
			charValue = CharToUpper(color[idx + 1]);
			
			if((48 <= charValue <= 57) == false && (65 <= charValue <= 70) == false)
			{
				FormatEx(message, maxlength, "String has atleast 1 non-hexadecimal character.");
				return false;
			}
		}
		
		return true;
	}
	else if(g_Engine == Engine_CSGO)
	{
		for(int idx; idx < MAX_COLORS; idx++)
		{
			if(StrEqual(color, CTag[idx]))
			{
				return true;
			}
		}
		
		if(StrEqual(color, "{rand}"))
		{
			return true;
		}
		
		FormatEx(message, maxlength, "String was not a valid color. Type !cchelp for a list of colors.");
		return false;
	}
	
	FormatEx(message, maxlength, "Invalid game.");
	return false;
}

public Action SM_CCHelp(int client, int args)
{
	if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		PrintColorText(client, "%s%sCheck your console for custom chat help.",
			g_msg_start,
			g_msg_textcol);
	}
	
	PrintToConsole(client, "-----------------------------------------------------------------------");
	if(!g_bClientHasCustom[client])
	{
		PrintToConsole(client, "* You do not have custom chat privileges.");
	}
	else
	{
		PrintToConsole(client, "* You have custom chat privileges.");
	}
	
	if(GetCookieBool(client, g_hCCName_Enabled))
	{
		PrintToConsole(client, "* Your custom chat name setting is ENABLED.");
	}
	else
	{
		PrintToConsole(client, "* Your custom chat name setting is DISABLED.");
	}
	
	if(GetCookieBool(client, g_hCCMsg_Enabled))
	{
		PrintToConsole(client, "* Your custom chat message setting is ENABLED.");
	}
	else
	{
		PrintToConsole(client, "* Your custom chat message setting is DISABLED.");
	}
	
	PrintToConsole(client, "\n*** HOW TO USE ***");
	PrintToConsole(client, "- Type !ccmsg to toggle your custom chat message setting.");
	PrintToConsole(client, "- Type !ccname to toggle your custom chat name setting.");
	PrintToConsole(client, "- Type !chatrank if you want a menu to toggle both.");
	PrintToConsole(client, "- To change your custom name, type !ccname followed by the name you want.");
	if(g_Engine == Engine_CSS)
	{
		PrintToConsole(client, "- To add color, you would place a '^' character followed by a hexadecimal code such as ff0000");
		PrintToConsole(client, "- Try typing '!ccname ^ff0000{name}' in chat and it will show your name in red when you type.");
		PrintToConsole(client, "- ^ means the timer expects a 6 digit hexadecimal code following it and {name} will automatically be replaced with your own name.");
		PrintToConsole(client, "- {norm} will be replaced with the normal chat-yellow color.");
		PrintToConsole(client, "- {team} will be replaced with your team color.");
		PrintToConsole(client, "- {rand} will be replaced with a random color.");
		PrintToConsole(client, "- {name} will be replaced with your own name.");
	}
	else if(g_Engine == Engine_CSGO)
	{
		PrintToConsole(client, "- {team} will be replaced by your team color.");
		PrintToConsole(client, "- {name} will be replaced with your own name.");
		PrintToConsole(client, "- {rand} will be replaced with a random color.");
		PrintToConsole(client, "- Here is a list of every allowed color:");
		for(int idx; idx < MAX_COLORS; idx++)
		{
			PrintToConsole(client, "-- %s", CTag[idx]);
		}
	}
	PrintToConsole(client, "-----------------------------------------------------------------------");
	
	return Plugin_Handled;
}

// Chat processor plugin
public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	EditChatMsgRecipients(author, recipients, true, "CP_OnChatMessage");
	AlterChatMessage(author, message, name);
	
	return Plugin_Changed;
}

// Simple chat processor plugin
public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message)
{
	EditChatMsgRecipients(author, recipients, false, "OnChatMessage");
	AlterChatMessage(author, message, name);
	
	return Plugin_Changed;
}

void EditChatMsgRecipients(int &author, Handle recipients, bool bUseUserIds, const char[] caller)
{
	if(g_Engine == Engine_CSS)
	{
		if(g_bNewMessage == true)
		{
			if(StrEqual(caller, "OnChatMessage"))
			{
				if(GetMessageFlags() & CHATFLAGS_ALL && !IsPlayerAlive(author))
				{
					for(new client = 1; client <= MaxClients; client++)
					{
						if(IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
						{
							PushArrayCell(recipients, bUseUserIds ? GetClientUserId(client) : client);
						}
					}
				}
			}
			
			g_bNewMessage = false;
		}
	}
	
	int iSize = GetArraySize(recipients);
	for(int idx; idx < iSize; idx++)
	{
		int client = GetArrayCell(recipients, idx);
		if(bUseUserIds && (client = GetClientOfUserId( client )) <= 0)
		{
			continue;
		}
		
		if(!AreClientCookiesCached(client))
		{
			continue;
		}
		
		if(!GetCookieBool(client, g_hHideChat))
		{
			continue;
		}
		
		RemoveFromArray(recipients, idx--);
		iSize--;
	}
}

void AlterChatMessage(int &author, char[] message, char[] name)
{
	/*
	int len = strlen(message);
	for(int idx; idx < len; idx++)
	{
		if(!('A' <= message[idx] <= 'Z') && !('a' <= message[idx] <= 'z'))
		{
			for(int idx2 = idx; idx2 < len - 1; idx2++)
			{
				message[idx2] = message[idx2 + 1];
			}
			
			message[len - 1] = '\0';
			idx--;
			len--;
		}
	}
	
	if(len == 0)
	{
		return Plugin_Stop;
	}
	
	ReplaceString(message, MAXLENGTH_MESSAGE, "feggit", "cute boy", false);
	ReplaceString(message, MAXLENGTH_MESSAGE, "fagget", "cute boy", false);
	ReplaceString(message, MAXLENGTH_MESSAGE, "fagot", "cute boy", false);
	ReplaceString(message, MAXLENGTH_MESSAGE, "faggot", "cute boy", false);
	ReplaceString(message, MAXLENGTH_MESSAGE, "fag", "cute boy", false);
	
	
	ReplaceString(message, MAXLENGTH_MESSAGE, "nigga", "im a retard", false);
	ReplaceString(message, MAXLENGTH_MESSAGE, "nigger", "im a retard", false);
	//ReplaceString(message, MAXLENGTH_MESSAGE, "s", "z", false);
	
	ReplaceString(message, MAXLENGTH_MESSAGE, "r", "w", false);
	ReplaceString(message, MAXLENGTH_MESSAGE, "l", "r", false);
	*/
	
	if(g_bChatRankLoaded[author] == false)
	{
		return;
	}
	
	int chatRank = GetCookieInt(author, g_hChatRankCookie);
	if(!ClientCanUseChatRank(author, chatRank))
	{
		SetCookieInt(author, g_hChatRankCookie, GetClientChatRankWithHighestPriority(author));
	}
	
	// Custom name
	char sColorName[MAXLENGTH_NAME];
	if(g_bClientHasCustom[author] && GetCookieBool(author, g_hCCName_Enabled) && GetCookieBool(author, g_hCCName_Init))
	{
		GetCustomName(author, name, MAXLENGTH_NAME);
		if(g_Engine == Engine_CSGO)
		{
			Format(name, MAXLENGTH_NAME, " \x01%s", name);
		}
	}
	else if(SetKvToChatRank(chatRank))
	{
		GetChatRankColoredTag(chatRank, sColorName, sizeof(sColorName));
		if(g_Engine == Engine_CSGO)
		{
			CFormat(sColorName, sizeof(sColorName), author);
		}
		else if(g_Engine == Engine_CSS)
		{
			ReplaceString(sColorName, sizeof(sColorName), "^", "\x07");
			ReplaceString(sColorName, sizeof(sColorName), "{norm}", "\x01");
			if(StrContains(sColorName, "{rand}", true) != -1)
			{
				int rand[3];
				char sRandHex[15];
				for(new i=0; i<3; i++)
					rand[i] = GetRandomInt(0, 255);
				
				FormatEx(sRandHex, sizeof(sRandHex), "\x07%02X%02X%02X", rand[0], rand[1], rand[2]);
				ReplaceStringEx(sColorName, sizeof(sColorName), "{rand}", sRandHex);
			}
		}
		
		Format(name, MAXLENGTH_NAME, "%s%s", sColorName, name);
		
		if(g_Engine == Engine_CSGO)
		{
			Format(name, MAXLENGTH_NAME, " \x01%s", name);
		}
	}
	
	// Message color
	char sColorMessage[128];
	if(g_bClientHasCustom[author] && GetCookieBool(author, g_hCCMsg_Enabled))
	{
		GetCustomMessage(author, message, MAXLENGTH_MESSAGE);
	}
	else if(SetKvToChatRank(chatRank))
	{
		GetChatRankMessageColor(chatRank, sColorMessage, sizeof(sColorMessage));
		if(g_Engine == Engine_CSGO)
		{
			CFormat(sColorMessage, sizeof(sColorMessage), author);
		}
		else if(g_Engine == Engine_CSS)
		{
			ReplaceString(sColorMessage, sizeof(sColorMessage), "^", "\x07");
			ReplaceString(sColorMessage, sizeof(sColorMessage), "{norm}", "\x01");
			
			if(StrContains(sColorMessage, "{rand}") != -1)
			{
				int rand[3];
				char sRandHex[15];
				for(new i=0; i<3; i++)
					rand[i] = GetRandomInt(0, 255);
				
				FormatEx(sRandHex, sizeof(sRandHex), "\x07%02X%02X%02X", rand[0], rand[1], rand[2]);
				ReplaceStringEx(sColorMessage, sizeof(sColorMessage), "{rand}", sRandHex);
			}
		}
		
		if(strlen(sColorMessage) > 0)
			Format(message, MAXLENGTH_MESSAGE, "%s%s", sColorMessage, message);
	}
}

void GetCustomName(int client, char[] name, int maxlength)
{
	GetClientCookie(client, g_hCCName, name, maxlength);
	
	if(g_Engine == Engine_CSS)
	{
		ReplaceString(name, maxlength, "{team}", "\x03", true);
		ReplaceString(name, maxlength, "^", "\x07", true);
		
		int rand[3];
		char sRandHex[15];
		while(StrContains(name, "{rand}", true) != -1)
		{
			for(new i=0; i<3; i++)
				rand[i] = GetRandomInt(0, 255);
			
			FormatEx(sRandHex, sizeof(sRandHex), "\x07%02X%02X%02X", rand[0], rand[1], rand[2]);
			ReplaceStringEx(name, maxlength, "{rand}", sRandHex);
		}
		
		ReplaceString(name, maxlength, "{norm}", "\x01", true);
		
		if(0 < client <= MaxClients)
		{
			char sName[MAX_NAME_LENGTH];
			GetClientName(client, sName, sizeof(sName));
			ReplaceString(name, maxlength, "{name}", sName, true);
		}
	}
	else if(g_Engine == Engine_CSGO)
	{
		CFormat(name, maxlength);
		
		if(0 < client <= MaxClients)
		{
			char sName[MAX_NAME_LENGTH];
			GetClientName(client, sName, sizeof(sName));
			ReplaceString(name, maxlength, "{name}", sName, true);
		}
	}
}

void GetCustomMessage(int client, char[] message, int maxlength)
{
	char sColorMessage[128];
	GetClientCookie(client, g_hCCMsg, sColorMessage, sizeof(sColorMessage));
	
	if(g_Engine == Engine_CSS)
	{
		ReplaceStringEx(sColorMessage, sizeof(sColorMessage), "^", "\x07");
		ReplaceString(sColorMessage, sizeof(sColorMessage), "{norm}", "\x01");
		
		if(StrContains(sColorMessage, "{rand}") != -1)
		{
			int rand[3];
			char sRandHex[15];
			for(new i=0; i<3; i++)
				rand[i] = GetRandomInt(0, 255);
			
			FormatEx(sRandHex, sizeof(sRandHex), "\x07%02X%02X%02X", rand[0], rand[1], rand[2]);
			ReplaceStringEx(sColorMessage, sizeof(sColorMessage), "{rand}", sRandHex);
		}
	}
	else if(g_Engine == Engine_CSGO)
	{
		CFormat(sColorMessage, sizeof(sColorMessage));
	}
			
	Format(message, maxlength, "%s%s", sColorMessage, message);
}

void LoadChatRanks()
{
	if(g_Kv != INVALID_HANDLE)
	{
		CloseHandle(g_Kv);
	}
	
	g_Kv = new KeyValues("Chat");
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/chatranks.txt");
	g_Kv.ImportFromFile(sPath);
	
	// Load Attainable Ranks List
	LoadAttainableRanksList();
}

void LoadAttainableRanksList()
{
	ClearArray(g_hAttainableRanksList);
	
	g_Kv.Rewind();
	g_Kv.GotoFirstSubKey();
	
	do
	{
		g_CurrentKvChatRank = g_Kv.GetNum("id");
		
		if(g_Kv.GetNum("list", 0) != 0)
		{
			PushArrayCell(g_hAttainableRanksList, g_CurrentKvChatRank);
		}
	}
	while(g_Kv.GotoNextKey());
}

void GetClientAvailableChatRanks(int client)
{
	if(!IsClientInGame(client))
	{
		return;
	}
	
	if(IsFakeClient(client))
	{
		return;
	}
	
	if(!IsClientAuthorized(client))
	{
		return;
	}
	
	if(g_bRanksLoaded && !Ranks_IsClientRankLoaded(client))
	{
		return;
	}
	
	if(!g_bAdminLoaded[client])
	{
		return;
	}
	
	g_Kv.Rewind();
	g_Kv.GotoFirstSubKey();
	
	do
	{
		g_CurrentKvChatRank = g_Kv.GetNum("id");
		if(ClientCanUseChatRank(client, g_CurrentKvChatRank))
		{
			//PrintToChat(client, "Can use %d", g_CurrentKvChatRank);
			if(!ClientHasChatRank(client, g_CurrentKvChatRank))
			{
				//PrintToChat(client, "Doesn't have %d", g_CurrentKvChatRank);
				GiveClientChatRank(client, g_CurrentKvChatRank);
				//PrintToChat(client, "Given %d", g_CurrentKvChatRank);
			}
		}
		else
		{
			if(ClientHasChatRank(client, g_CurrentKvChatRank) == true)
			{
				RemoveClientChatRank(client, g_CurrentKvChatRank);
			}
		}
	}
	while(g_Kv.GotoNextKey());
	
	if(GetCookieInt(client, g_hChatRankCookie) == 0)
	{
		SetCookieInt(client, g_hChatRankCookie, GetClientChatRankWithHighestPriority(client));
	}
	else
	{
		if(!ClientCanUseChatRank(client, GetCookieInt(client, g_hChatRankCookie)))
		{
			SetCookieInt(client, g_hChatRankCookie, GetClientChatRankWithHighestPriority(client));
		}
	}
	
	CheckForCustomChat(client);
	
	char sTag[64];
	GetChatRankTag(GetCookieInt(client, g_hChatRankCookie), sTag, sizeof(sTag));
	CS_SetClientClanTag(client, sTag);
	
	g_CurrentKvChatRank       = g_Kv.GetNum("id");
	g_bChatRankLoaded[client] = true;
}

void CheckForCustomChat(int client)
{
	int iSize = GetArraySize(g_hChatRanks[client]);
	int chatRank;
	for(int idx; idx < iSize; idx++)
	{
		chatRank = GetArrayCell(g_hChatRanks[client], idx, 0);
		SetKvToChatRank(chatRank);
		
		if(view_as<bool>(g_Kv.GetNum("custom")))
		{
			// Tell the player they now have custom chat privileges if something changed that allows them to use it
			if(g_bChatRankLoaded[client] == true && g_bClientHasCustom[client] == false)
			{
				PrintColorText(client, "%s%sYou have gained custom chat privileges! Type %s!chatrank%s to use it!",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					g_msg_textcol);
			}
			
			// Initialize the player's custom chat name so it doesn't show as blank
			if(GetCookieBool(client, g_hCCName_Init) == false)
			{
				SetClientCookie(client, g_hCCName, "{rand}{name}");
				SetCookieBool(client, g_hCCName_Init, true);
			}
			
			g_bClientHasCustom[client] = true;
			return;
		}
	}
	
	if(g_bChatRankLoaded[client] == true && g_bClientHasCustom[client] == true)
	{
		PrintColorText(client, "%s%sYou have lost your custom chat privileges!",
			g_msg_start,
			g_msg_textcol);
	}
	
	g_bClientHasCustom[client] = false;
}

int GetClientChatRankWithHighestPriority(int client)
{
	int iSize = GetArraySize(g_hChatRanks[client]);
	
	int prio, data[2], chatRank = -1;
	for(int idx; idx < iSize; idx++)
	{
		GetArrayArray(g_hChatRanks[client], idx, data, sizeof(data));
		data[1] = GetArrayCell(g_hChatRanks[client], idx, 1);
		if(data[1] > prio)
		{
			prio     = data[1];
			chatRank = data[0];
		}
	}
	
	return chatRank;
}

bool ClientHasChatRank(int client, int chatRank)
{
	int iSize = GetArraySize(g_hChatRanks[client]);
	
	for(int idx; idx < iSize; idx++)
	{
		if(GetArrayCell(g_hChatRanks[client], idx, 0) == chatRank)
		{
			return true;
		}
	}
	
	return false;
}

void RemoveClientChatRank(int client, int chatRank)
{
	int iSize = GetArraySize(g_hChatRanks[client]);
	
	for(int idx; idx < iSize; idx++)
	{
		if(GetArrayCell(g_hChatRanks[client], idx, 0) == chatRank)
		{
			RemoveFromArray(g_hChatRanks[client], idx);
			
			if(g_bChatRankLoaded[client] == true)
			{
				char sTag[64];
				GetChatRankTag(chatRank, sTag, sizeof(sTag));
				PrintColorText(client, "%s%sYou lost the chatrank %s%s%s.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sTag,
					g_msg_textcol);
			}
			
			return;
		}
	}
}

void GiveClientChatRank(client, int chatRankId)
{
	if(g_CurrentKvChatRank != chatRankId)
	{
		SetKvToChatRank(chatRankId);
	}
	
	int data[2];
	data[0] = chatRankId;
	data[1] = g_Kv.GetNum("prio");
	PushArrayArray(g_hChatRanks[client], data, sizeof(data));
	
	if(g_bChatRankLoaded[client] == true)
	{
		char sTag[64];
		GetChatRankTag(chatRankId, sTag, sizeof(sTag));
		PrintColorText(client, "%s%sYou gained the chatrank %s%s%s!",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			sTag,
			g_msg_textcol,
			data[0],
			data[1]);
	}
}

bool SetKvToChatRank(int id)
{
	g_Kv.Rewind();
	g_Kv.GotoFirstSubKey();
	
	do
	{
		if(g_Kv.GetNum("id") == id)
		{
			g_CurrentKvChatRank = id;
			return true;	
		}
	}
	while(g_Kv.GotoNextKey());
	
	g_CurrentKvChatRank = g_Kv.GetNum("id");
	return false;
}

void GetChatRankTag(int id, char[] sTag, int maxlength)
{
	if(g_CurrentKvChatRank != id)
	{
		SetKvToChatRank(id);
	}
	
	g_Kv.GetString("tag", sTag, maxlength, "N/A");
}

void GetChatRankColoredTag(int id, char[] sColTag, int maxlength)
{
	if(g_CurrentKvChatRank != id)
	{
		SetKvToChatRank(id);
	}
	
	g_Kv.GetString("col", sColTag, maxlength, "N/A");
}

stock void GetChatRankDelimiter(int id, char[] sDel, int maxlength)
{
	if(g_CurrentKvChatRank != id)
	{
		SetKvToChatRank(id);
	}
	
	g_Kv.GetString("del", sDel, maxlength, "N/A");
}

void GetChatRankMessageColor(int id, char[] sMsg, int maxlength)
{
	if(g_CurrentKvChatRank != id)
	{
		SetKvToChatRank(id);
	}
	
	g_Kv.GetString("msg", sMsg, maxlength, "N/A");
}

void GetChatRankDescription(int id, char[] sDesc, int maxlength)
{
	if(g_CurrentKvChatRank != id)
	{
		SetKvToChatRank(id);
	}
	
	g_Kv.GetString("desc", sDesc, maxlength, "N/A");
}

bool ClientCanUseChatRank(int client, int id)
{
	if(g_CurrentKvChatRank != id)
	{
		SetKvToChatRank(id);
	}
	
	char sSectionName[32];
	g_Kv.GetSectionName(sSectionName, sizeof(sSectionName))
		
	if(StrEqual(sSectionName, "Flag"))
	{
		char sFlag[2];
		g_Kv.GetString("flag", sFlag, sizeof(sFlag), "");
		
		AdminFlag flag;
		FindFlagByChar(sFlag[0], flag);
		//LogMessage("%L: %s, %c, %d", client, sFlag, sFlag[0], GetAdminFlag(GetUserAdmin(client), flag, Access_Effective));
		
		return GetAdminFlag(GetUserAdmin(client), flag, Access_Effective);
	} 
	else if(StrEqual(sSectionName, "Unranked") && g_bRanksLoaded)
	{
		return !Ranks_IsClientRankedOverall(client);
	}
	else if(StrEqual(sSectionName, "OverallRank") && g_bRanksLoaded)
	{
		if(!Ranks_IsClientRankedOverall(client))
			return false;
			
		float rank = float(Ranks_GetClientOverallRank(client));
		
		return g_Kv.GetFloat("min") <= rank <= g_Kv.GetFloat("max");
	}
	else if(StrEqual(sSectionName, "OverallRankPercent") && g_bRanksLoaded)
	{
		if(!Ranks_IsClientRankedOverall(client))
			return false;
			
		float rankPct = float(Ranks_GetClientOverallRank(client)) / float(Ranks_GetTotalOverallRanks());
		
		return g_Kv.GetFloat("min") < rankPct*100.0 <= g_Kv.GetFloat("max");
	}
	else if(StrEqual(sSectionName, "WRRank") && g_bRanksLoaded)
	{
		if(!Ranks_IsClientRankedOverall(client))
			return false;
			
		return g_Kv.GetNum("min") <= Ranks_GetClientOverallRecordRank(client) <= g_Kv.GetNum("max");
	}
	else if(StrEqual(sSectionName, "SteamID"))
	{
		char sAuth[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth), true);
		
		char sKvAuth[32];
		g_Kv.GetString("steamid", sKvAuth, sizeof(sKvAuth));
		
		return StrEqual(sAuth, sKvAuth);
	}
	else if(StrEqual(sSectionName, "All"))
	{
		return true;
	}
	else if(StrEqual(sSectionName, "StyleRank") && g_bRanksLoaded)
	{
		int type  = g_Kv.GetNum("type");
		int style = g_Kv.GetNum("style");
		if(!Ranks_IsClientRankedStyle(client, type, style))
			return false;
		
		int rank = Ranks_GetClientStyleRank(client, type, style);
		
		return g_Kv.GetNum("min") <= rank <= g_Kv.GetNum("max");
	}
	else if(StrEqual(sSectionName, "StyleRankPercent") && g_bRanksLoaded)
	{
		int type  = g_Kv.GetNum("type");
		int style =  g_Kv.GetNum("style");
		if(!Ranks_IsClientRankedStyle(client, type, style))
			return false;
			
		float rankPct = float(Ranks_GetClientStyleRank(client, type, style)) / float(Ranks_GetTotalStyleRanks(type, style));
		
		return g_Kv.GetNum("min") < rankPct*100.0 <= g_Kv.GetNum("max");
	}
	
	return false;
}