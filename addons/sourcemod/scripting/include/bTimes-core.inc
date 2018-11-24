#if defined _timercore_included
  #endinput
#endif
#define _timercore_included

#define VERSION "2.0"

#define MAX_TYPES 2

#define TIMER_MAIN 0
#define TIMER_BONUS 1
#define TIMER_ANY 2

#define ALL -1

stock int g_CRCTable[256] = {
    0x00000000, 0x09073096, 0x120e612c, 0x1b0951ba,
    0xff6dc419, 0xf66af48f, 0xed63a535, 0xe46495a3,
    0xfedb8832, 0xf7dcb8a4, 0xecd5e91e, 0xe5d2d988,
    0x01b64c2b, 0x08b17cbd, 0x13b82d07, 0x1abf1d91,
    0xfdb71064, 0xf4b020f2, 0xefb97148, 0xe6be41de,
    0x02dad47d, 0x0bdde4eb, 0x10d4b551, 0x19d385c7,
    0x036c9856, 0x0a6ba8c0, 0x1162f97a, 0x1865c9ec,
    0xfc015c4f, 0xf5066cd9, 0xee0f3d63, 0xe7080df5,
    0xfb6e20c8, 0xf269105e, 0xe96041e4, 0xe0677172,
    0x0403e4d1, 0x0d04d447, 0x160d85fd, 0x1f0ab56b,
    0x05b5a8fa, 0x0cb2986c, 0x17bbc9d6, 0x1ebcf940,
    0xfad86ce3, 0xf3df5c75, 0xe8d60dcf, 0xe1d13d59,
    0x06d930ac, 0x0fde003a, 0x14d75180, 0x1dd06116,
    0xf9b4f4b5, 0xf0b3c423, 0xebba9599, 0xe2bda50f,
    0xf802b89e, 0xf1058808, 0xea0cd9b2, 0xe30be924,
    0x076f7c87, 0x0e684c11, 0x15611dab, 0x1c662d3d,
    0xf6dc4190, 0xffdb7106, 0xe4d220bc, 0xedd5102a,
    0x09b18589, 0x00b6b51f, 0x1bbfe4a5, 0x12b8d433,
    0x0807c9a2, 0x0100f934, 0x1a09a88e, 0x130e9818,
    0xf76a0dbb, 0xfe6d3d2d, 0xe5646c97, 0xec635c01,
    0x0b6b51f4, 0x026c6162, 0x196530d8, 0x1062004e,
    0xf40695ed, 0xfd01a57b, 0xe608f4c1, 0xef0fc457,
    0xf5b0d9c6, 0xfcb7e950, 0xe7beb8ea, 0xeeb9887c,
    0x0add1ddf, 0x03da2d49, 0x18d37cf3, 0x11d44c65,
    0x0db26158, 0x04b551ce, 0x1fbc0074, 0x16bb30e2,
    0xf2dfa541, 0xfbd895d7, 0xe0d1c46d, 0xe9d6f4fb,
    0xf369e96a, 0xfa6ed9fc, 0xe1678846, 0xe860b8d0,
    0x0c042d73, 0x05031de5, 0x1e0a4c5f, 0x170d7cc9,
    0xf005713c, 0xf90241aa, 0xe20b1010, 0xeb0c2086,
    0x0f68b525, 0x066f85b3, 0x1d66d409, 0x1461e49f,
    0x0edef90e, 0x07d9c998, 0x1cd09822, 0x15d7a8b4,
    0xf1b33d17, 0xf8b40d81, 0xe3bd5c3b, 0xeaba6cad,
    0xedb88320, 0xe4bfb3b6, 0xffb6e20c, 0xf6b1d29a,
    0x12d54739, 0x1bd277af, 0x00db2615, 0x09dc1683,
    0x13630b12, 0x1a643b84, 0x016d6a3e, 0x086a5aa8,
    0xec0ecf0b, 0xe509ff9d, 0xfe00ae27, 0xf7079eb1,
    0x100f9344, 0x1908a3d2, 0x0201f268, 0x0b06c2fe,
    0xef62575d, 0xe66567cb, 0xfd6c3671, 0xf46b06e7,
    0xeed41b76, 0xe7d32be0, 0xfcda7a5a, 0xf5dd4acc,
    0x11b9df6f, 0x18beeff9, 0x03b7be43, 0x0ab08ed5,
    0x16d6a3e8, 0x1fd1937e, 0x04d8c2c4, 0x0ddff252,
    0xe9bb67f1, 0xe0bc5767, 0xfbb506dd, 0xf2b2364b,
    0xe80d2bda, 0xe10a1b4c, 0xfa034af6, 0xf3047a60,
    0x1760efc3, 0x1e67df55, 0x056e8eef, 0x0c69be79,
    0xeb61b38c, 0xe266831a, 0xf96fd2a0, 0xf068e236,
    0x140c7795, 0x1d0b4703, 0x060216b9, 0x0f05262f,
    0x15ba3bbe, 0x1cbd0b28, 0x07b45a92, 0x0eb36a04,
    0xead7ffa7, 0xe3d0cf31, 0xf8d99e8b, 0xf1deae1d,
    0x1b64c2b0, 0x1263f226, 0x096aa39c, 0x006d930a,
    0xe40906a9, 0xed0e363f, 0xf6076785, 0xff005713,
    0xe5bf4a82, 0xecb87a14, 0xf7b12bae, 0xfeb61b38,
    0x1ad28e9b, 0x13d5be0d, 0x08dcefb7, 0x01dbdf21,
    0xe6d3d2d4, 0xefd4e242, 0xf4ddb3f8, 0xfdda836e,
    0x19be16cd, 0x10b9265b, 0x0bb077e1, 0x02b74777,
    0x18085ae6, 0x110f6a70, 0x0a063bca, 0x03010b5c,
    0xe7659eff, 0xee62ae69, 0xf56bffd3, 0xfc6ccf45,
    0xe00ae278, 0xe90dd2ee, 0xf2048354, 0xfb03b3c2,
    0x1f672661, 0x166016f7, 0x0d69474d, 0x046e77db,
    0x1ed16a4a, 0x17d65adc, 0x0cdf0b66, 0x05d83bf0,
    0xe1bcae53, 0xe8bb9ec5, 0xf3b2cf7f, 0xfab5ffe9,
    0x1dbdf21c, 0x14bac28a, 0x0fb39330, 0x06b4a3a6,
    0xe2d03605, 0xebd70693, 0xf0de5729, 0xf9d967bf,
    0xe3667a2e, 0xea614ab8, 0xf1681b02, 0xf86f2b94,
    0x1c0bbe37, 0x150c8ea1, 0x0e05df1b, 0x0702ef8d,
 };

typedef PlayerSelectedCallback = function void (int client, int playerId);

DataPack g_FxnPack[MAXPLAYERS + 1];
bool g_PlayerListAllOption[MAXPLAYERS + 1];

stock void DB_CreatePlayerListFromName(int client, const char[] title, Database db, bool all, const char[] name, PlayerSelectedCallback cb)
{
	g_PlayerListAllOption[client] = all;
	
	if(strlen(name) == 0)
	{
		Menu menu = new Menu(Menu_PlayerList);
		menu.SetTitle(title);
		
		if(g_PlayerListAllOption[client])
		{
			menu.AddItem("all", "All Players");
		}
		
		char sInfo[8], sDisplay[48];
		IntToString(GetPlayerID(client), sInfo, sizeof(sInfo));
		FormatEx(sDisplay, sizeof(sDisplay), "%N (You)\n ", client);
		menu.AddItem(sInfo, sDisplay);
		
		int playerId;
		for(int target = 1; target <= MaxClients; target++)
		{
			if(IsClientInGame(target) && (playerId = GetPlayerID(target)) != 0 && target != client)
			{
				IntToString(playerId, sInfo, sizeof(sInfo));
				GetClientName(target, sDisplay, sizeof(sDisplay));
				menu.AddItem(sInfo, sDisplay);
			}
		}
		
		if(g_FxnPack[client] != INVALID_HANDLE)
		{
			delete g_FxnPack[client];
		}

		g_FxnPack[client] = new DataPack();
		
		g_FxnPack[client].WriteFunction(cb);
		
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		//PrintToBlacky("DB_CreatePlayerListFromName 1: %f", GetEngineTime());
		char sName[(2 * MAX_NAME_LENGTH) + 1];
		SQL_LockDatabase(db);
		SQL_EscapeString(db, name, sName, sizeof(sName));
		SQL_UnlockDatabase(db);
		//PrintToBlacky("DB_CreatePlayerListFromName 2: %f", GetEngineTime());
		
		DataPack pack = new DataPack();
		WritePackCell(pack, GetClientUserId(client));
		WritePackString(pack, title);
		WritePackFunction(pack, cb);
		
		char sQuery[256];
		FormatEx(sQuery, sizeof(sQuery), "SELECT PlayerID, User FROM players WHERE User LIKE '%%%s%%' ORDER BY User ASC LIMIT 0, 100", sName);
		SQL_TQuery(db, OnPlayerListCreated, sQuery, pack);
	}
	
}

public void OnPlayerListCreated(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if(hndl != INVALID_HANDLE)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		
		if(client != 0)
		{
			Menu menu = new Menu(Menu_PlayerList);
			
			char sTitle[256];
			pack.ReadString(sTitle, sizeof(sTitle));
			menu.SetTitle(sTitle);
			
			int inserted;
			if(g_PlayerListAllOption[client])
			{
				menu.AddItem("all", "All Players");
				inserted++;
			}
			
			char sName[MAX_NAME_LENGTH];
			int  playerId, added;
			
			char sInfo[32], sDisplay[256];
			while(SQL_FetchRow(hndl))
			{
				playerId = SQL_FetchInt(hndl, 0);
				SQL_FetchString(hndl, 1, sName, sizeof(sName));
				
				if(GetClientFromPlayerID(playerId) != 0)
				{
					IntToString(playerId, sInfo, sizeof(sInfo));
					FormatEx(sDisplay, sizeof(sDisplay), "[+] %s (%d)", sName, playerId);
					
					if(added > inserted)
					{
						menu.InsertItem(inserted++, sInfo, sDisplay);
					}
					else
					{
						menu.AddItem(sInfo, sDisplay);
						added++;
					}
				}
				else
				{
					IntToString(playerId, sInfo, sizeof(sInfo));
					FormatEx(sDisplay, sizeof(sDisplay), "[-] %s (%d)", sName, playerId);
					menu.AddItem(sInfo, sDisplay);
					added++;
				}
			}
			
			menu.Display(client, MENU_TIME_FOREVER);
			
			if(g_FxnPack[client] != INVALID_HANDLE)
			{
				delete g_FxnPack[client];
			}

			g_FxnPack[client] = new DataPack();
			
			g_FxnPack[client].WriteFunction(pack.ReadFunction());
		}
	}
	else
	{
		LogError(error);
	}
	
	delete pack;
}

public int Menu_PlayerList(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		ResetPack(g_FxnPack[client]);
		Call_StartFunction(GetMyHandle(), g_FxnPack[client].ReadFunction());
		Call_PushCell(client);
		
		if(StrEqual(sInfo, "all"))
		{
			Call_PushCell(0);
		}
		else
		{
			Call_PushCell(StringToInt(sInfo));
		}
		
		Call_Finish();
		
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

stock Timer_Log(bool timerDebug = false, const char[] log, any ...)
{
	if(timerDebug == true)
	{
		ConVar c = FindConVar("timer_debug");
		
		if(c != null && c.BoolValue == false)
		{
			delete c;
			return;
		}
	}
	
	char buffer[1024];
	VFormat(buffer, sizeof(buffer), log, 3);
	
	Handle myHandle = GetMyHandle();
	char sPlugin[PLATFORM_MAX_PATH];
	GetPluginFilename(myHandle, sPlugin, PLATFORM_MAX_PATH);
	Format(buffer, 1024, "[%s] %s", sPlugin, buffer);
	
	char sDate[64];
	FormatTime(sDate, sizeof(sDate), "%y%m%d", GetTime());
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/timer_%s.txt", sDate);
	File hFile = OpenFile(sPath, "a");
	if(hFile != INVALID_HANDLE)
	{
		WriteFileLine(hFile, buffer);
		delete hFile;
	}
	else
	{
		LogError("Couldn't open timer log file.");
	}
}

// Core natives

/**
* Gets a client's player id in the database.
* 
* @param client		Client index.
* 
* @return			Client's player id.
*/
native GetClientID(client);

/**
* A better name for GetClientID()
* 
* @param client        Client index.
* 
* @return              Client's player id.
*/
stock GetPlayerID(client)
{
	return GetClientID(client);
}

stock int GetClientFromPlayerID(int playerId)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(GetPlayerID(client) == playerId)
		{
			return client;
		}
	}
	
	return 0;
}

/**
* Gets the name of a player in the database by their Player ID
* 
* @param PlayerID      Player ID in the database.
* @param sName         Buffer to store the given name.
* @param maxlength     Maxlength of the sName string.
*/
native GetNameFromPlayerID(PlayerID, String:sName[], maxlength);

/**
* Gets a SteamID given a PlayerID in the timer database
* 
* @param PlayerID      Player ID in the database.
* @param sAuth         Buffer to store the SteamID.
* @param maxlength     Maxlength of the sAuth string.
*/
native GetSteamIDFromPlayerID(PlayerID, String:sAuth[], maxlength);

/**
* Gets whether or not the player id list is loaded.
* 
* @return true if player id list is loaded, false otherwise.
*/
native bool:IsPlayerIDListLoaded();

/**
* Gets the map id in the timer database from a map name
* 
* @param sMapName      The name of the map to get the map id for.
* 
* @return              The map's map id, 0 if map not found.
*/
//native GetMapIdFromMapName(const String:sMapName[]);

/**
* Gets the map name from a map id
* 
* @param MapID         The map id you use to get the map name for.
* @param sMapName      The buffer to hold the map name.
* @param maxlength     The max length of the sMapName buffer.
* 
* @return              True if the map was found, false otherwise.
*/
//native bool:GetMapNameFromMapId(MapID, String:sMapName[], maxlength);


/**
* Gets if a client is spamming SQL related commands or not.
* 
* @param client		Client index.
* 
* @return 			True if client is spamming; false otherwise.
*/
native bool:IsSpamming(client);

/**
* Sets a client as spamming commands.
* 
* @param client		Client index.
* 
* @noreturn
*/
native SetIsSpamming(client, Float:BlockTime);

/**
* Adds a command to the timer's command list.
* 
* @param sCommand		The command to add to the command list.
* @param sDescription	The description of the command added to the command list.
* 
* @noreturn
*/
native RegisterCommand(const String:sCommand[], const String:sDescription[]);

/**
* Gets the admin flag required for the specific timer admin flag
* 
* @param timerflag     The name of the timer admin flag.
* @param flag          A value that returns by reference the admin flag.
* 
* @return              True if the timer flag was found, false otherwise.
*/
native bool:Timer_GetAdminFlag(const char[] timerflag, AdminFlag &flag);

/**
* Gets if a client has a specified timer admin flag.
*
* @param client        Client index.
* @param sFlag         Name of flag you want to check.
* @param defaultFlag   Default flag to use in case it isn't found in the text file.
*
* @return              True if client has flag, false otherwise.
*/
native bool Timer_ClientHasTimerFlag(client, const char[] sFlag, AdminFlag defaultFlag);

/**
* Gets if a map is in the server's mapcycle.
*
* @param sMap          The map you are checking for.
*
* @return              True if the map is in the mapcycle, false otherwise.
*/
native bool Timer_IsMapInMapCycle(const char[] sMap);

native bool Timer_GetMapCycleSize();

native Handle Timer_GetMapCycle();

#include <clientprefs>

/**
* A simpler way of getting the bool value of a client's cookie.
* 
* @param client        Client index.
* @param cookie        Handle to the cookie.
* 
* @return              Boolean value of the client's cookie, false if client's cookies are not cached.
*/
stock bool:GetCookieBool(client, Handle:cookie)
{
	if(AreClientCookiesCached(client))
	{
		decl String:sCookie[16];
		GetClientCookie(client, cookie, sCookie, sizeof(sCookie));
		
		if(strlen(sCookie) == 0)
			return false;
		else if(StrEqual(sCookie, "off"))
			return false;
		else if(StrEqual(sCookie, "on"))
			return true;
		else
			return bool:StringToInt(sCookie);
	}
	
	return true;
}

stock int GetCookieInt(int client, Handle cookie)
{
	if(AreClientCookiesCached(client))
	{
		char sCookie[16];
		GetClientCookie(client, cookie, sCookie, sizeof(sCookie));
		
		if(strlen(sCookie) == 0)
			return 0;
		else
			return StringToInt(sCookie);
	}
	
	return true;
}

/**
* A simpler of of setting a client's cookie with a boolean value
* 
* @param client        Client index.
* @param cookie        Handle to the cookie.
* @param value         Value to set the client's cookie to.
* 
* @noreturn
*/
stock SetCookieBool(client, Handle:cookie, bool:value)
{
	if(AreClientCookiesCached(client))
	{
		decl String:sCookie[32];
		IntToString(value, sCookie, sizeof(sCookie));
		SetClientCookie(client, cookie, sCookie);
	}
}

stock void SetCookieInt(int client, Handle cookie, int value)
{
	if(AreClientCookiesCached(client))
	{
		decl String:sCookie[32];
		IntToString(value, sCookie, sizeof(sCookie));
		SetClientCookie(client, cookie, sCookie);
	}
}

#include <console>

/**
* Registers a console command and adds it to the timer's command list.
* 
* @param sCommand		The command to register and add to the command list.
* @param callback		The callback for the command.
* @param sDescription	The description of the command.
* 
* @noreturn
*/
stock RegConsoleCmdEx(const String:sCommand[], ConCmd:callback, const String:sDescription[])
{
	RegConsoleCmd(sCommand, callback, sDescription);
	
	RegisterCommand(sCommand, sDescription);
}

#if defined _timer_included
stock RegConsoleCmdPerStyle(const String:sBaseCmd[], ConCmd:callback, const String:sDescription[])
{
	decl String:sLiteralDesc[256], String:sType[32], String:sStyle[32], String:sTypeAbbr[32], String:sStyleAbbr[32], String:sLiteralBaseCmd[64];
	
	new TotalStyles = GetTotalStyles();
	for(new Type; Type < MAX_TYPES; Type++)
	{
		GetTypeName(Type, sType, sizeof(sType));
		GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr), true);
		
		Style s;
		for(new style; style < TotalStyles; style++)
		{
			GetStyleConfig(style, s);
			s.GetName(sStyle, sizeof(sStyle));
			s.GetNameShort(sStyleAbbr, sizeof(sStyleAbbr));
			
			if(s.Enabled && s.GetAllowType(Type))
			{
				strcopy(sLiteralDesc, sizeof(sLiteralDesc), sDescription);
				ReplaceString(sLiteralDesc, sizeof(sLiteralDesc), "{Type}", sType, false);
				ReplaceString(sLiteralDesc, sizeof(sLiteralDesc), "{Style}", sStyle, false);
				
				FormatEx(sLiteralBaseCmd, sizeof(sLiteralBaseCmd), "sm_%s%s%s", sTypeAbbr, sBaseCmd, sStyleAbbr);
				
				RegConsoleCmdEx(sLiteralBaseCmd, callback, sLiteralDesc);
			}
		}
	}
}
#endif
/**
* Called when a map's MapID is gauranteed to be in the database
*/
forward void OnMapIDPostCheck();

/**
* Called when the list of maps from the maps table in the database has been loaded into memory
*/
forward void OnDatabaseMapListLoaded();

/**
* Called when a player's PlayerID is retrieved and gauranteed to be in the database
*/
forward void OnPlayerIDLoaded(client);

/**
* Called when the list of Player Ids is loaded
*/
forward void OnPlayerIDListLoaded();

/**
* Used to print messages to all players and allows special colors without annoying hexadecimal spam in console
*/
stock void PrintColorTextAll(const String:msg[], any:...)
{
	decl String:buffer[300];
	VFormat(buffer, sizeof(buffer), msg, 2);
	new Handle:hMessage = StartMessageAll("SayText2"); 
	if (hMessage != INVALID_HANDLE) 
	{
		if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
		{
			PbSetInt(hMessage, "ent_idx", 0);
			PbSetBool(hMessage, "chat", true);
			PbSetString(hMessage, "msg_name", buffer);
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
		}
		else
		{
			BfWriteByte(hMessage, 0);
			BfWriteByte(hMessage, true);
			BfWriteString(hMessage, buffer);
		}
		
		EndMessage();
	}
}

/**
* Used to print messages to a single player and allows special colors without annoying hexadecimal spam in console
*/
stock void PrintColorText(client, const String:msg[], any:...)
{
	if(IsClientInGame(client))
	{
		new String:buffer[300];
		VFormat(buffer, sizeof(buffer), msg, 3);
		
		new Handle:hMessage = StartMessageOne("SayText2", client); 
		if (hMessage != INVALID_HANDLE) 
		{ 
			if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
			{
				PbSetInt(hMessage, "ent_idx", client);
				PbSetBool(hMessage, "chat", true);
				PbSetString(hMessage, "msg_name", buffer);
				PbAddString(hMessage, "params", "");
				PbAddString(hMessage, "params", "");
				PbAddString(hMessage, "params", "");
				PbAddString(hMessage, "params", "");
			}
			else
			{
				BfWriteByte(hMessage, client);
				BfWriteByte(hMessage, true);
				BfWriteString(hMessage, buffer);
			}
			
			EndMessage();
		}
	}
}

/**
* Used to print messages to a player's spectators and allows special colors without annoying hexadecimal spam in console
*/
stock void PrintColorTextObservers(target, const String:msg[], any:...)
{
	new String:buffer[300];
	VFormat(buffer, sizeof(buffer), msg, 3);
	
	new clients[MaxClients], observercount;
	
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsPlayerAlive(client) && !IsFakeClient(client))
		{
			new observee 		= GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			new ObserverMode 	= GetEntProp(client, Prop_Send, "m_iObserverMode");
			
			if(observee == target && (ObserverMode == 4 || ObserverMode == 5))
			{
				clients[observercount++] = client;
			}
		}
	}
	
	if(observercount == 0)
		return;
	
	new Handle:hMessage = StartMessage("SayText2", clients, observercount); 
	if (hMessage != INVALID_HANDLE) 
	{ 
		if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
		{
			PbSetInt(hMessage, "ent_idx", 0);
			PbSetBool(hMessage, "chat", true);
			PbSetString(hMessage, "msg_name", buffer);
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
		}
		else
		{
			BfWriteByte(hMessage, 0);
			BfWriteByte(hMessage, true);
			BfWriteString(hMessage, buffer);
		}
		
		EndMessage();
	}
}

/**
* Converts a time into a formatted string
*/
stock void FormatPlayerTime(float fTime, char[] result, int maxlength, int precision)
{
	int hours 	  = RoundToFloor(fTime / 3600);
	fTime        -= hours * 3600;
	int minutes   = RoundToFloor(fTime / 60);
	fTime        -= minutes * 60;
	float seconds = fTime;
	
	char sPrecision[16];
	
	if(precision == 0)
		Format(sPrecision, sizeof(sPrecision), (hours > 0 || minutes > 0)?"%04.1f":"%.1f", seconds);
	else if(precision == 1)
		Format(sPrecision, sizeof(sPrecision), (hours > 0 || minutes > 0)?"%05.2f":"%.2f", seconds);
	else if(precision == 2)
		Format(sPrecision, sizeof(sPrecision), (hours > 0 || minutes > 0)?"%09.6f":"%.6f", seconds);
	
	if(hours > 0)
		FormatEx(result, maxlength, "%d:%02d:%s", hours, minutes, sPrecision);
	else if(minutes > 0)
		FormatEx(result, maxlength, "%d:%s", minutes, sPrecision);
	else
		FormatEx(result, maxlength, "%s", sPrecision);
}

stock void RemoveNonCharactersFromString(char[] sString)
{
	int len = strlen(sString);
	
	for(int idx; idx < len; idx++)
	{
		if(sString[idx] < 'A' || (sString[idx] > 'Z' && sString[idx] < 'a') || sString[idx] > 'z')
		{
			sString[idx] = null;
		}
	}
}

/**
* Gets a client's velocity with extra settings to disallow velocity on certain axes
*/
stock float GetClientVelocity(client, bool:UseX, bool:UseY, bool:UseZ)
{
	new Float:vVel[3];
	
	if(UseX)
	{
		vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	}
	
	if(UseY)
	{
		vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	}
	
	if(UseZ)
	{
		vVel[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
	}
	
	return GetVectorLength(vVel);
}

/**
* Gets the name of a specified type
*/
stock void GetTypeName(Type, String:sType[], maxlength, bool:bBlankIfMain = false)
{
	if((Type == TIMER_MAIN && bBlankIfMain == true) || Type == ALL)
	{
		FormatEx(sType, maxlength, "");
		return;
	}
	
	decl String:sTypeList[MAX_TYPES][] = {"Main", "Bonus"};
	
	FormatEx(sType, maxlength, sTypeList[Type]);
}

/**
* Gets the abbreviation of a specified type
*/
stock void GetTypeAbbr(Type, String:sAbbr[], maxlength, bool:bBlankIfMain = false)
{
	if((Type == TIMER_MAIN && bBlankIfMain == true) || Type == ALL)
	{
		FormatEx(sAbbr, maxlength, "");
		return;
	}
	
	decl String:sAbbrList[MAX_TYPES][] = {"", "b"};
	
	FormatEx(sAbbr, maxlength, sAbbrList[Type]);
}

/**
* Turns all lowercase letters in a string to uppercase
*/
stock void StringToUpper(String:buffer[])
{
	new len = strlen(buffer);
	
	for(new idx = 0; idx < len; idx++)
	{
		buffer[idx] = CharToUpper(buffer[idx]);
	}
}

/**
* Adds brackets to a string, might change so players can choose brackets
*/
stock void AddBracketsToString(String:buffer[], maxlength)
{
	if(strlen(buffer) > 0)
		Format(buffer, maxlength, "[%s]", buffer);
}

/**
* Adds a space to the end of a string, probably gonna remove this
*/
stock void AddSpaceToEnd(String:buffer[], maxlength)
{
	if(strlen(buffer) > 0)
		Format(buffer, maxlength, "%s ", buffer);
}

new 	String:g_msg_start[128] = {""};
new 	String:g_msg_varcol[128] = {"\x07B4D398"};
new 	String:g_msg_textcol[128] = {"\x01"};

public void OnTimerChatChanged(MessageType, String:Message[])
{
	if(MessageType == 0)
	{
		Format(g_msg_start, sizeof(g_msg_start), Message);
		ReplaceMessage(g_msg_start, sizeof(g_msg_start), MessageType);
	}
	else if(MessageType == 1)
	{
		Format(g_msg_varcol, sizeof(g_msg_varcol), Message);
		ReplaceMessage(g_msg_varcol, sizeof(g_msg_varcol), MessageType);
	}
	else if(MessageType == 2)
	{
		Format(g_msg_textcol, sizeof(g_msg_textcol), Message);
		ReplaceMessage(g_msg_textcol, sizeof(g_msg_textcol), MessageType);
	}
}

forward void OnTimerChatChanged(MessageType, String:Message[]);

#include <csgocolors>

stock void ReplaceMessage(String:message[], maxlength, MessageType)
{
	decl String:sGame[64];
	GetGameFolderName(sGame, sizeof(sGame));
	
	if(StrEqual(sGame, "cstrike"))
	{
		ReplaceString(message, maxlength, "^", "\x07", false);
	}
	else if(StrEqual(sGame, "csgo"))
	{
		CFormat(message, maxlength);
		
		if(MessageType == 0)
		{
			Format(message, maxlength, " \x01%s", message);
		}
	}
}

stock void UpdateMessages()
{
	new Handle:hCvar;
	
	hCvar = FindConVar("timer_msgstart");
	if(hCvar != INVALID_HANDLE)
	{
		GetConVarString(hCvar, g_msg_start, sizeof(g_msg_start));
		ReplaceMessage(g_msg_start, sizeof(g_msg_start), 0);
	}
	
	hCvar = FindConVar("timer_msgvar");
	if(hCvar != INVALID_HANDLE)
	{
		GetConVarString(hCvar, g_msg_varcol, sizeof(g_msg_varcol));
		ReplaceMessage(g_msg_varcol, sizeof(g_msg_varcol), 1);
	}
	
	hCvar = FindConVar("timer_msgtext");
	if(hCvar != INVALID_HANDLE)
	{
		GetConVarString(hCvar, g_msg_textcol, sizeof(g_msg_textcol));
		ReplaceMessage(g_msg_textcol, sizeof(g_msg_textcol), 1);
	}
}

/* stock bool IsBlacky(int client)
{
	char sAuth[32];
	GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
	return StrContains(sAuth, "0:1739936") != -1;
} */

stock int GetClientObservee(int client)
{
	if(IsPlayerAlive)
	{
		return client;
	}
	else
	{
		int Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		int ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5) && Target == g_ReplayBot && !g_ReplayBotIsReplaying)
		{
			return Target;
		}
	}
	
	return 0;
}

/* stock void PrintToBlacky(const String:msg[], any:...)
{
	//0:1739936
	char sAuth[32];
	static blackyUserId;
	
	int blacky = GetClientOfUserId(blackyUserId);
	if(blacky == 0)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
				
				if(StrContains(sAuth, "0:1739936") != -1)
				{
					blackyUserId = GetClientUserId(client);
					blacky = client;
					break;
				}
			}
		}
		
		if(blacky == 0)
		{
			return;
		}
	}
	
	new String:buffer[300];
	VFormat(buffer, sizeof(buffer), msg, 2);
	
	new Handle:hMessage = StartMessageOne("SayText2", blacky); 
	if (hMessage != INVALID_HANDLE) 
	{ 
		if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
		{
			PbSetInt(hMessage, "ent_idx", blacky);
			PbSetBool(hMessage, "chat", true);
			PbSetString(hMessage, "msg_name", buffer);
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
		}
		else
		{
			BfWriteByte(hMessage, blacky);
			BfWriteByte(hMessage, true);
			BfWriteString(hMessage, buffer);
		}
		
		EndMessage();
	}
} */
