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

ArrayList g_hReplayFrame[MAX_TYPES][MAX_STYLES][2];
int       g_ReplayCurrentFrame[MAXPLAYERS + 1];
int       g_ReplayMaxFrame[MAX_TYPES][MAX_STYLES][2];
float     g_ReplayBotTime[MAX_TYPES][MAX_STYLES][2];
int       g_ReplayPlayerId[MAX_TYPES][MAX_STYLES][2];
char      g_ReplayBotTag[MAX_TYPES][MAX_STYLES][2][MAX_NAME_LENGTH];
bool      g_bIsReplaying[MAXPLAYERS + 1];
int       g_CameraEntRef[MAXPLAYERS + 1];
bool      g_bReplayLoaded[MAX_TYPES][MAX_STYLES][2];
int       g_ReplayTimerType[MAXPLAYERS + 1]  = {-1, ...};
int       g_ReplayTimerStyle[MAXPLAYERS + 1]  = {-1, ...};
bool      g_ReplayIsTas[MAXPLAYERS + 1];
char      g_sMapName[PLATFORM_MAX_PATH];
bool      g_bLateLoad;
bool      g_bUsedFrame[MAXPLAYERS + 1];
bool      g_bTasLoaded;

ArrayList g_hPlayerFrame[MAXPLAYERS + 1];

// ConVars
ConVar g_cSmoothing;

#define REPLAY_FRAME_SIZE 6

public void OnPluginStart()
{
	// ConVars
	g_cSmoothing = CreateConVar("timer_smoothing", "1", "Uses a smoothing algorithm when saving TAS runs to make them look nicer. (Experimental)", 0, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "replay", "timer");
	// Commands
	RegConsoleCmd("sm_replay", SM_Replay);
	RegConsoleCmd("sm_bot", SM_Replay);
	
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
	}
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes");
	
	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("replay");

	g_bLateLoad = late;
	
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bTasLoaded = LibraryExists("tas");
}

public void OnLibraryAdded(const char[] library)
{
	if(StrEqual(library, "tas"))
	{
		g_bTasLoaded = true;
	}
}

public void OnLibraryRemoved(const char[] library)
{
	if(StrEqual(library, "tas"))
	{
		g_bTasLoaded = false;
	}
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
			}
		}
	}
	
	if(g_bLateLoad == true || IsPlayerIDListLoaded() == true)
		LoadReplays();
}

public void OnClientPutInServer(int client)
{
	InitializePlayerSettings(client);
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
	
	SDKHook(client, SDKHook_PreThink, Hook_PostThink);
}

public void OnPlayerIDListLoaded()
{
	LoadReplays();
}

public void OnTimerStart_Post(int client, int Type, int style)
{
	// Reset saved ghost data
	g_hPlayerFrame[client].Clear();
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

int g_ReplayMenuType[MAXPLAYERS + 1];
int g_ReplayMenuStyle[MAXPLAYERS + 1];
int g_ReplayMenuTAS[MAXPLAYERS + 1];

void OpenPlayReplayMenu(int client)
{
	Menu menu = new Menu(Menu_PlayReplay);
	
	char sTitle[128], sTime[32];
	int replayCount = GetAvailableReplayCount();
	
	if(g_bReplayLoaded[g_ReplayMenuType[client]][g_ReplayMenuStyle[client]][g_ReplayMenuTAS[client]])
	{
		FormatPlayerTime(g_ReplayBotTime[g_ReplayMenuType[client]][g_ReplayMenuStyle[client]][g_ReplayMenuTAS[client]], sTime, sizeof(sTime), 1);
		FormatEx(sTitle, sizeof(sTitle), "Select replay (%d available)\n \nPlayer: %s\nTime: %s\n \n",
			replayCount,
			g_ReplayBotTag[g_ReplayMenuType[client]][g_ReplayMenuStyle[client]][g_ReplayMenuTAS[client]],
			sTime);
	}
	else
	{
		FormatEx(sTitle, sizeof(sTitle), "Select replay (%d available)\n \nSpecified replay unavailable",
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
			StartReplay(client, g_ReplayMenuType[client], g_ReplayMenuStyle[client], g_ReplayMenuTAS[client]);
		}
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

int SpawnBaseProp()
{
	//Spawn entity
	char sModel[64];
	Format(sModel, sizeof(sModel), "models/player/ct_gign.mdl");
	PrecacheModel(sModel, true);
	
	int iEntity = CreateEntityByName("prop_dynamic");

	if(iEntity == -1)
	{
		return -1;
	}
	
	DispatchKeyValue(iEntity, "model",	  sModel);
	DispatchKeyValue(iEntity, "solid",	  "0");
	DispatchKeyValue(iEntity, "rendermode", "10"); // dont render
	DispatchKeyValue(iEntity, "disableshadows", "1"); // no shadows
	
	SetEntityModel(iEntity, sModel);
	SetEntityMoveType(iBaseProp, MOVETYPE_WALK);
	DispatchSpawn(iEntity);
	SetEntityMoveType(iBaseProp, MOVETYPE_WALK);
	
	return iEntity;
}

/*
void StartReplay(int client, int type, int style, int tas)
{
	g_bIsReplaying[client] = true;
	g_ReplayCurrentFrame[client] = 0;
	g_ReplayTimerType[client] = type;
	g_ReplayTimerStyle[client] = style;
	g_ReplayIsTas[client] = view_as<bool>(tas);
	
	int iBaseProp = SpawnBaseProp();
	if(iBaseProp == -1)
	{
		return;
	}
	
	//Spawn entity
	char sModel[64];
	//Format(sModel, sizeof(sModel), "models/player/ct_gign.mdl");
	Format(sModel, sizeof(sModel), "models/props/cs_office/vending_machine.mdl");
	PrecacheModel(sModel, true);
	
	char sTargetName[64]; 
	Format(sTargetName, sizeof(sTargetName), "replay%d", client);
	DispatchKeyValue(iBaseProp, "targetname", sTargetName);

	int iEntity = CreateEntityByName("prop_dynamic");
	if (iEntity == -1)
		return;

	char sCamName[64]; 
	Format(sCamName, sizeof(sCamName), "replayCam%d", iEntity);

	DispatchKeyValue(iEntity, "targetname", sCamName);
	DispatchKeyValue(iEntity, "parentname", sTargetName);
	DispatchKeyValue(iEntity, "model",	  sModel);
	DispatchKeyValue(iEntity, "solid",	  "0");
	DispatchKeyValue(iEntity, "rendermode", "10"); // dont render
	DispatchKeyValue(iEntity, "disableshadows", "1"); // no shadows

	float fPos[3];
	fPos[0] = view_as<float>(GetArrayCell(g_hReplayFrame[type][style][tas], 0, 0));
	fPos[1] = view_as<float>(GetArrayCell(g_hReplayFrame[type][style][tas], 0, 1));
	fPos[2] = view_as<float>(GetArrayCell(g_hReplayFrame[type][style][tas], 0, 2));
	TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);
	
	float fAngles[3];
	fAngles[0] = GetArrayCell(g_hReplayFrame[type][style][tas], 0, 3);
	fAngles[1] = GetArrayCell(g_hReplayFrame[type][style][tas], 0, 4);
	
	char sCamAngles[64];
	Format(sCamAngles, sizeof(sCamAngles), "%f %f %f", fAngles[0], fAngles[1], fAngles[2]);
	DispatchKeyValue(iEntity, "angles", sCamAngles);
	
	SetEntityModel(iEntity, sModel);
	DispatchSpawn(iEntity);

	SetVariantString(sTargetName);
	AcceptEntityInput(iEntity, "SetParent", iEntity, iEntity, 0);

	SetVariantString("forward");
	AcceptEntityInput(iEntity, "SetParentAttachment", iEntity, iEntity, 0);

	AcceptEntityInput(iEntity, "TurnOn");
	SetEntityMoveType(client, MOVETYPE_OBSERVER);
	
	SetClientViewEntity(client, iEntity);
	g_CameraEntRef[client] = EntIndexToEntRef(iBaseProp);
}*/

void StartReplay(int client, int type, int style, int tas)
{
	g_bIsReplaying[client] = true;
	g_ReplayCurrentFrame[client] = 0;
	g_ReplayTimerType[client] = type;
	g_ReplayTimerStyle[client] = style;
	g_ReplayIsTas[client] = view_as<bool>(tas);

	int iEntity = CreateEntityByName("point_viewcontrol");
	if (iEntity == -1)
		return;

	char sCamName[64]; 
	Format(sCamName, sizeof(sCamName), "replayCam%d", client);
	DispatchKeyValue(iEntity, "targetname", sCamName);
	
	char sWatcher[64]; 
	Format(sWatcher, sizeof(sWatcher), "replay%d", client); 
	DispatchKeyValue(client, "targetname", sWatcher); 
	
	//DispatchKeyValue(iEntity, "targetname", "playercam"); 
	//DispatchKeyValue(iEntity, "wait", "3600");
	
	float fAngles[3];
	fAngles[0] = GetArrayCell(g_hReplayFrame[type][style][tas], 0, 3);
	fAngles[1] = GetArrayCell(g_hReplayFrame[type][style][tas], 0, 4);
	char sCamAngles[64];
	Format(sCamAngles, sizeof(sCamAngles), "%f %f %f", fAngles[0], fAngles[1], fAngles[2]);
	DispatchKeyValue(iEntity, "angles", sCamAngles);
	
	DispatchKeyValue(iEntity, "LagCompensate", "1");
	DispatchKeyValue(iEntity, "MoveType", "8");
	DispatchKeyValue(iEntity, "fov", "100");
	DispatchKeyValue(iEntity, "spawnflags", "64");
	DispatchSpawn(iEntity);
	
	//SetEntityMoveType(client, MOVETYPE_OBSERVER);
	SetVariantString(sWatcher); 
	AcceptEntityInput(iEntity, "Enable", client, iEntity, 0); 

	float fPos[3];
	fPos[0] = view_as<float>(GetArrayCell(g_hReplayFrame[type][style][tas], 0, 0));
	fPos[1] = view_as<float>(GetArrayCell(g_hReplayFrame[type][style][tas], 0, 1));
	fPos[2] = view_as<float>(GetArrayCell(g_hReplayFrame[type][style][tas], 0, 2));
	TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);
	
	g_CameraEntRef[client] = EntIndexToEntRef(iEntity);
}

void StopReplays(int type, int style, int tas)
{
	
}

void StopReplay(int client)
{
	g_bIsReplaying[client] = false;
	int entity = EntRefToEntIndex(g_CameraEntRef[client]);
	if(entity != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(entity, "Kill");
	}
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
						RenameFile(sPath, sPathRec);
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
						
						g_bReplayLoaded[Type][style][tas]  = true;
						g_ReplayMaxFrame[Type][style][tas] = GetArraySize(g_hReplayFrame[Type][style][tas]);
					}
				}
			}
		}
	}
}

void ConvertFile(const char[] sPath, const char[] newName)
{
	LogMessage("Converting replay file '%s' to '%s' using new format.", sPath, newName);
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
	StopReplays(Type, style, tas);
		
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
	g_ReplayMaxFrame[Type][style][tas] = iSize;
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
		for(int angIdx; angIdx < 2; angIdx++)
		{
			float fAngle = view_as<float>(list.Get(idx, angIdx + 4));
			float fAngleDiff = fAngle - fOldAngle[angIdx];
			if (fAngleDiff > 180)
			{
				fAngleDiff -= 360;
			}
			else if(fAngleDiff < -180)
			{
				fAngleDiff += 360;
			}
			
			float fTempTotalAngleDiff = fTotalAngleDiff[angIdx];
			bool bUpdateAngles;
			if(fAngleDiff > 0) // Turning left
			{
				if(lastTurnDir[angIdx] == TURN_RIGHT)
				{
					fTotalAngleDiff[angIdx] = 0.0;
					bUpdateAngles           = true; //Update if replay turns left
				}
				
				fTotalAngleDiff[angIdx] += fAngleDiff;
				lastTurnDir[angIdx]      = TURN_LEFT;
			}
			else if(fAngleDiff < 0) // Turning right
			{
				if(lastTurnDir[angIdx] == TURN_LEFT)
				{
					fTotalAngleDiff[angIdx] = 0.0;
					bUpdateAngles           = true; // Update if replay turns right
				}
				
				fTotalAngleDiff[angIdx] += fAngleDiff;
				lastTurnDir[angIdx]      = TURN_RIGHT;
			}
			
			// Update if the replay has turned too much
			if(angIdx == 0)
			{
				if((FloatAbs(fTotalAngleDiff[0]) > 45.0)) 
				{
					bUpdateAngles = true;
				}
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
				int tickCount = idx - lastUpdateIdx[angIdx];
				float fStartAngle = view_as<float>(list.Get(lastUpdateIdx[angIdx], 4));
				for(int idx2 = lastUpdateIdx[angIdx], idx3; idx2 < idx; idx2++, idx3++)
				{
					float fPercent = float(idx3) / float(tickCount);
					float fAngleToSet = fStartAngle + (fTempTotalAngleDiff * fPercent);
					if(fAngleToSet > 180)
						fAngleToSet -= 360;
					else if(fAngleToSet < -180)
						fAngleToSet += 360;
					
					list.Set(idx2, fAngleToSet, angIdx + 4);
				}
			
				lastUpdateIdx[angIdx] = idx;
			}
				
			fOldAngle[angIdx] = fAngle;
		}
	}
}

/* Delete replay of specified type/style */
void DeleteReplay(int Type, int style, int tas)
{	
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

bool IsReplay(int client)
{
	return g_bIsReplaying[client];
}

public void OnButtonPressed(int client, int buttons)
{
	if(!IsPlayerAlive(client) && buttons & IN_USE)
	{
		OpenPlayReplayMenu(client);
	}
}

public void Hook_PostThink(int client)
{
	if(!IsPlayerAlive(client))
		return;
		
	if(IsBeingTimed(client, TIMER_ANY) == true && TimerInfo(client).Paused == false)
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
}

float g_fLastVel;
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsReplay(client))
	{
		int type = g_ReplayTimerType[client];
		int style = g_ReplayTimerStyle[client];
		int tas = g_ReplayIsTas[client];
		any data[REPLAY_FRAME_SIZE];
		GetArrayArray(g_hReplayFrame[type][style][tas], g_ReplayCurrentFrame[client], data, sizeof(data));
		
		float vPos[3];
		vPos[0] = view_as<float>(data[0]);
		vPos[1] = view_as<float>(data[1]);
		vPos[2] = view_as<float>(data[2]) + 64.0;
		
		float vAng[3];
		vAng[0] = view_as<float>(data[3]);
		vAng[1] = view_as<float>(data[4]);
		vAng[2] = 0.0;
		
		buttons = view_as<int>(data[5]);
		
		float vCurrentPos[3];
		Entity_GetAbsOrigin(client, vCurrentPos);
		
		int entity = EntRefToEntIndex(g_CameraEntRef[client]);
		if(entity != INVALID_ENT_REFERENCE)
		{
			if(GetVectorDistance(vCurrentPos, vPos) > 50.0)
			{
				TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
			}
			else
			{
				// Get the new velocity from the the 2 points
				float vVel[3];
				MakeVectorFromPoints(vCurrentPos, vPos, vVel);
				ScaleVector(vVel, 1.0/GetTickInterval());
				
				g_fLastVel = GetVectorLength(vVel);
				
				TeleportEntity(entity, NULL_VECTOR, vAng, vVel);
			}
		}
		
		
		g_ReplayCurrentFrame[client]++;
		if(g_ReplayCurrentFrame[client] >= g_ReplayMaxFrame[type][style][tas] - 1)
			StopReplay(client);
	}
	/*
	else
	{
		if(!IsPlayerAlive(client))
		{
			AdminFlag flag = Admin_Generic;
			Timer_GetAdminFlag("replay", flag);
			
			if(GetAdminFlag(GetUserAdmin(client), flag, Access_Effective))
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
		}
	}
	*/
	
	return Plugin_Changed;
}
