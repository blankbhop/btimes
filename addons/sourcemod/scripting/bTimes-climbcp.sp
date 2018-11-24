#include <sourcemod>
#include <bTimes-core>
#include <bTimes-timer>
#include <bTimes-zones>
#include <clientprefs>
#include <smlib/entities>
#include <csgocolors>

new Handle:g_hCheckpoints[MAXPLAYERS + 1]        = {INVALID_HANDLE, ...};
new	bool:g_bClientIndexJoinedYet[MAXPLAYERS + 1] = {false,          ...};
new g_SelectedCheckpoint[MAXPLAYERS + 1]         = {-1,             ...};
new	bool:g_bHasUsedACheckpoint[MAXPLAYERS + 1]   = {false,          ...};
new	bool:g_bHasTimerStartedOnce[MAXPLAYERS + 1]  = {false,          ...};
new	g_UsedTeleportCount[MAXPLAYERS + 1]          = {0,              ...};
new	Handle:g_Menu[MAXPLAYERS + 1]                = {INVALID_HANDLE, ...};
new	bool:g_bLateLoaded                           = false;
	
enum Checkpoint
{
	Float:CPPos[3],
	Float:CPAng[3]
};

new	g_UndoCheckpoint[MAXPLAYERS + 1][Checkpoint];
new	g_RestartCheckpoint[MAXPLAYERS + 1][Checkpoint];

// Forwards
new	Handle:g_hFwdCheckpointSaved_Pre;
new	Handle:g_hFwdCheckpointUsed_Pre;
new Handle:g_hFwdCheckpointSaved_Post;
new Handle:g_hFwdCheckpointUsed_Post;

// Cookies
new	Handle:g_hCheckpointCookie;
bool g_bCheckpointMenu[MAXPLAYERS + 1] = {true, ...};

bool g_bButtonsPluginLoaded;

public Plugin:myinfo = 
{
	name = "[Timer] Climb Checkpoints",
	author = "blacky",
	description = "Checkpoint portion of the timer for climb servers",
	version = "1.0",
	url = "http://steamcommunity.com/id/blaackyy/"
}

public OnPluginStart()
{
	// Commands
	RegConsoleCmdEx("sm_cpmenu", SM_CPMenu, "Opens the checkpoint menu.");
	RegConsoleCmdEx("sm_cp", SM_CPMenu, "Opens the checkpoint menu.");
	RegConsoleCmdEx("sm_menu", SM_CPMenu, "Opens the checkpoint menu.");
	
	// Cookies
	g_hCheckpointCookie = RegClientCookie("timer_cpmenu", "Keep checkpoint menu open.", CookieAccess_Public);
	SetCookiePrefabMenu(g_hCheckpointCookie, CookieMenu_OnOff, "Checkpoint menu");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Forwards
	g_hFwdCheckpointSaved_Pre  = CreateGlobalForward("OnCheckpointSaved_Pre", ET_Hook, Param_Cell);
	g_hFwdCheckpointUsed_Pre   = CreateGlobalForward("OnCheckpointUsed_Pre", ET_Hook, Param_Cell);
	g_hFwdCheckpointSaved_Post = CreateGlobalForward("OnCheckpointSaved_Post", ET_Event, Param_Cell);
	g_hFwdCheckpointUsed_Post  = CreateGlobalForward("OnCheckpointUsed_Post", ET_Event, Param_Cell);
	
	// Natives
	CreateNative("Timer_GetUsedCpCount", Native_GetUsedCpCount);
	CreateNative("Timer_SetUsedCpCount", Native_SetUsedCpCount);
	
	g_bLateLoaded = late;
	
	if(late)
	{
		UpdateMessages();
	}
	
	RegPluginLibrary("timer-climpcp");
	
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if(LibraryExists("timer-buttons"))
	{
		g_bButtonsPluginLoaded = true;
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "timer-buttons"))
	{
		g_bButtonsPluginLoaded = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "timer-buttons"))
	{
		g_bButtonsPluginLoaded = false;
	}
}

public OnMapStart()
{
	if(g_bLateLoaded)
	{
		for(new client = 1; client <= MaxClients; client++)
		{
			g_hCheckpoints[client]          = CreateArray(view_as<int>(Checkpoint));
			g_bClientIndexJoinedYet[client] = true;
		}
	}
	
	CreateTimer(0.1, Timer_ShowCheckpointMenu, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public OnClientPutInServer(client)
{
	// Initialize player settings
	if(g_bClientIndexJoinedYet[client] == false)
	{
		g_hCheckpoints[client]          = CreateArray(view_as<int>(Checkpoint));
		g_bClientIndexJoinedYet[client] = true;
	}
	else
	{
		ClearArray(g_hCheckpoints[client]);
	}
	
	g_SelectedCheckpoint[client]   = -1;
	g_bHasUsedACheckpoint[client]  = false;
	g_bHasTimerStartedOnce[client] = false;
	g_UsedTeleportCount[client]    = 0;
	g_bCheckpointMenu[client]      = true;
}

public void OnClientCookiesCached(int client)
{
	char sCookie[32];
	GetClientCookie(client, g_hCheckpointCookie, sCookie, 32);
	
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hCheckpointCookie, true);
	}
}

public Action:Timer_ShowCheckpointMenu(Handle:timer, any:data)
{
	// Re-display the checkpoint menu to all clients
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client) && g_bCheckpointMenu[client])
		{
			if(g_Menu[client] != INVALID_HANDLE)
			{
				CloseHandle(g_Menu[client]);
				g_Menu[client] = INVALID_HANDLE;
			}
			
			if(GetClientMenu(client, INVALID_HANDLE) == MenuSource_None)
			{
				OpenCheckpointMenu(client);
			}
		}
	}
}

public OnTimerStart_Post(client, Type, style, Method)
{
	if(Method != StartMethod_SaveLocation)
	{
		ClearArray(g_hCheckpoints[client]);
		g_bHasUsedACheckpoint[client]  = false;
		g_UsedTeleportCount[client]    = 0;
		
		if(Method == StartMethod_Buttons)
		{
			SaveRestartCheckpoint(client);
			g_bHasTimerStartedOnce[client] = true;
		}
		
		if(Style(style).Start != -1)
		{
			TimerInfo(client).SetStyle(TimerInfo(client).Type, Style(style).Start);
		}
	}
	
}



public Action:SM_CPMenu(client, args)
{
	SetCookieBool(client, g_hCheckpointCookie, true);
	g_bCheckpointMenu[client] = true;
	
	return Plugin_Handled;
}

OpenCheckpointMenu(client)
{
	new iSize = GetArraySize(g_hCheckpoints[client]);
	
	if(g_Menu[client] != INVALID_HANDLE)
	{
		CloseHandle(g_Menu[client]);
		g_Menu[client] = INVALID_HANDLE;
	}
	
	g_Menu[client] = CreateMenu(Menu_Checkpoint);
	
	// Menu title
	decl String:sTitle[64];
	if(Timer_InsideZone(client, MAIN_START) != -1 || Timer_InsideZone(client, BONUS_START) != -1)
	{
		FormatEx(sTitle, sizeof(sTitle), "Inside Start Zone\n ");
	}
	else
	{
		if(IsBeingTimed(client, TIMER_ANY))
		{
			new Float:fTime = TimerInfo(client).CurrentTime;
			
			decl String:sTime[32];
			FormatPlayerTime(fTime, sTime, sizeof(sTime), 0);
			
			FormatEx(sTitle, sizeof(sTitle), "Time: %s\n ",
				sTime);
		}
		else
		{
			FormatEx(sTitle, sizeof(sTitle), "Checkpoint menu\n ");
		}
	}
	
	SetMenuTitle(g_Menu[client], sTitle);
	
	// "Checkpoint" item
	if(iSize > 0)
	{
		decl String:sCheckpointItem[32];
		FormatEx(sCheckpointItem, sizeof(sCheckpointItem), "Checkpoint (%d)", iSize);
		AddMenuItem(g_Menu[client], "save", sCheckpointItem);
	}
	else
	{
		AddMenuItem(g_Menu[client], "save", "Checkpoint");
	}
	
	// "Teleport" item
	decl String:sTeleportItem[32];
	if(g_UsedTeleportCount[client] != 0)
	{
		FormatEx(sTeleportItem, sizeof(sTeleportItem), "Teleport (%d)", g_UsedTeleportCount[client]);
	}
	else
	{
		FormatEx(sTeleportItem, sizeof(sTeleportItem), "Teleport");
	}
	AddMenuItem(g_Menu[client], "tp", sTeleportItem, (iSize > 0)?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	
	// Other simpler items
	AddMenuItem(g_Menu[client], "prev", "Previous", (iSize <= 1)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	AddMenuItem(g_Menu[client], "next", "Next",     (iSize <= 1)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	AddMenuItem(g_Menu[client], "undo", "Undo",     (g_bHasUsedACheckpoint[client])?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	
	new Handle:hPauseVar = FindConVar("timer_allowpausing");
	if(hPauseVar != INVALID_HANDLE)
	{
		if(GetConVarBool(hPauseVar))
		{
			AddMenuItem(g_Menu[client], "pause", IsTimerPaused(client)?"Unpause":"Pause", (IsBeingTimed(client, TIMER_ANY))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		}
	}
	
	AddMenuItem(g_Menu[client], "restart", "Restart",   (g_bHasTimerStartedOnce[client])?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	
	SetMenuPagination(g_Menu[client], MENU_NO_PAGINATION);
	SetMenuExitButton(g_Menu[client], true);
	DisplayMenu(g_Menu[client], client, MENU_TIME_FOREVER);
}

public Menu_Checkpoint(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		new String:sInfo[32];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "save"))
		{
			SaveCheckpoint(client);
		}
		else if(StrEqual(sInfo, "tp"))
		{
			TeleportToCheckpoint(client, g_SelectedCheckpoint[client]);
		}
		else if(StrEqual(sInfo, "prev"))
		{
			new iSize = GetArraySize(g_hCheckpoints[client]);
			g_SelectedCheckpoint[client] = (g_SelectedCheckpoint[client] % iSize - 1 % iSize + iSize) % iSize;
			TeleportToCheckpoint(client, g_SelectedCheckpoint[client]);
		}
		else if(StrEqual(sInfo, "next"))
		{
			new iSize = GetArraySize(g_hCheckpoints[client]);
			g_SelectedCheckpoint[client] = (g_SelectedCheckpoint[client] % iSize + 1 % iSize + iSize) % iSize;
			TeleportToCheckpoint(client, g_SelectedCheckpoint[client]);
		}
		else if(StrEqual(sInfo, "undo"))
		{
			TeleportToUndoCheckpoint(client);
		}
		else if(StrEqual(sInfo, "pause"))
		{
			Timer_Pause(client, !IsTimerPaused(client));
		}
		else if(StrEqual(sInfo, "restart"))
		{
			TeleportToRestartCheckpoint(client);
		}
	}
	
	if (action & MenuAction_End)
	{
		if(0 < client <= MaxClients)
		{
			g_Menu[client] = INVALID_HANDLE;
		}
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			SetCookieBool(client, g_hCheckpointCookie, false);
			g_bCheckpointMenu[client] = false;
		}
	}
}

public Action OnCheckpointSaved_Pre(int client)
{
	if(IsBeingTimed(client, TIMER_ANY))
	{
		if(!(GetEntityFlags(client) & FL_ONGROUND))
		{
			PrintColorText(client, "%s%sYou need to be on the ground to save a checkpoint.",
				g_msg_start,
				g_msg_textcol);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

void SaveCheckpoint(int client)
{
	Call_StartForward(g_hFwdCheckpointSaved_Pre);
	Call_PushCell(client);
	
	Action result;
	Call_Finish(result);
	
	if(result == Plugin_Handled)
	{
		return;
	}
	
	// Save checkpoint
	any data[6];
	new Float:fPos[3], Float:fAng[3];
	Entity_GetAbsOrigin(client, fPos);
	GetClientEyeAngles(client, fAng);
	
	for(new idx; idx < 3; idx++)
	{
		data[idx]     = fPos[idx];
		data[idx + 3] = fAng[idx];
	}
	
	g_SelectedCheckpoint[client] = PushArrayArray(g_hCheckpoints[client], data);
	
	Call_StartForward(g_hFwdCheckpointSaved_Post);
	Call_PushCell(client);
	Call_Finish();
	
}

void TeleportToCheckpoint(client, cp)
{
	Call_StartForward(g_hFwdCheckpointUsed_Pre);
	Call_PushCell(client);
	
	Action result;
	Call_Finish(result);
	
	if(result == Plugin_Handled)
	{
		return;
	}
	
	int style = TimerInfo(client).ActiveStyle;
	
	if(Style(style).HasSpecialKey("nocp"))
	{
		if(Style(style).Break != -1)
		{
			TimerInfo(client).SetStyle(TimerInfo(client).Type, Style(style).Break);
		}
		else
		{
			PrintColorText(client, "%s%sYou can't use checkpoints on this style.",
				g_msg_start,
				g_msg_textcol);
			return;
		}
	}
	if(IsTimerPaused(client))
	{
		PrintColorText(client, "%s%sYou can't teleport while paused.",
			g_msg_start,
			g_msg_textcol);
			
		return;
	}
	
	// Save location so players can undo their teleport
	SaveUndoCheckpoint(client);
	
	// Teleport to checkpoint
	any data[6];
	new Float:fPos[3], Float:fAng[3];
	GetArrayArray(g_hCheckpoints[client], cp, data);
	
	for(new idx; idx < 3; idx++)
	{
		fPos[idx] = data[idx];
		fAng[idx] = data[idx + 3];
	}
	
	TeleportEntity(client, fPos, fAng, Float:{0.0, 0.0, 0.0});
	
	g_SelectedCheckpoint[client]  = cp;
	g_bHasUsedACheckpoint[client] = true;
	g_UsedTeleportCount[client]++;
	
	Call_StartForward(g_hFwdCheckpointUsed_Post);
	Call_PushCell(client);
	Call_Finish();
}

public void OnCheckpointUsed_Post(int client)
{
	int style = TimerInfo(client).ActiveStyle;
	if(Style(style).Break != -1)
	{
		TimerInfo(client).SetStyle(TimerInfo(client).Type, Style(style).Break);
	}
}

SaveUndoCheckpoint(client)
{
	// Save undo checkpoint
	new Float:fPos[3], Float:fAng[3];
	Entity_GetAbsOrigin(client, fPos);
	GetClientEyeAngles(client, fAng);
	
	for(new idx; idx < 3; idx++)
	{
		g_UndoCheckpoint[client][CPPos][idx] = fPos[idx];
		g_UndoCheckpoint[client][CPAng][idx] = fAng[idx];
	}
}

TeleportToUndoCheckpoint(client)
{
	if(IsTimerPaused(client))
	{
		PrintColorText(client, "%s%sYou can't teleport while paused.",
			g_msg_start,
			g_msg_textcol);
			
		return;
	}
	
	// Teleport to undo checkpoint
	new Float:fPos[3], Float:fAng[3];
	for(new idx; idx < 3; idx++)
	{
		fPos[idx] = g_UndoCheckpoint[client][CPPos][idx];
		fAng[idx] = g_UndoCheckpoint[client][CPAng][idx];
	}
	
	TeleportEntity(client, fPos, fAng, Float:{0.0, 0.0, 0.0});
	g_UsedTeleportCount[client]++;
}

SaveRestartCheckpoint(client)
{
	// Save undo checkpoint
	new Float:fPos[3], Float:fAng[3];
	Entity_GetAbsOrigin(client, fPos);
	GetClientEyeAngles(client, fAng);
	
	for(new idx; idx < 3; idx++)
	{
		g_RestartCheckpoint[client][CPPos][idx] = fPos[idx];
		g_RestartCheckpoint[client][CPAng][idx] = fAng[idx];
	}
}

TeleportToRestartCheckpoint(client)
{
	if(IsTimerPaused(client))
	{
		PrintColorText(client, "%s%sYou can't teleport while paused.",
			g_msg_start,
			g_msg_textcol);
			
		return;
	}
	
	// Teleport to undo checkpoint
	new Float:fPos[3], Float:fAng[3];
	for(new idx; idx < 3; idx++)
	{
		fPos[idx] = g_RestartCheckpoint[client][CPPos][idx];
		fAng[idx] = g_RestartCheckpoint[client][CPAng][idx];
	}
	
	TeleportEntity(client, fPos, fAng, Float:{0.0, 0.0, 0.0});
}

/* Natives */
public Native_GetUsedCpCount(Handle:plugin, numParams)
{
	return g_UsedTeleportCount[GetNativeCell(1)];
}

public Native_SetUsedCpCount(Handle:plugin, numParams)
{
	g_UsedTeleportCount[GetNativeCell(1)] = GetNativeCell(2);
}