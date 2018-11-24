// Clear savelocs if the replay plugin is unloaded
// Don't let timer start until saveloc is checked



#include <sourcemod>
#include <bTimes-core>
#include <bTimes-timer>
#include <smlib/entities>

#undef REQUIRE_PLUGIN
#include <bTimes-climbcp>
#include <bTimes-tas>
#include <bTimes-replay3>

enum SaveLocationProp
{
	SaveLoc_SteamId[32],
	SaveLoc_Pos[3],
	SaveLoc_Ang[3],
	SaveLoc_Time,
	SaveLoc_Type,
	SaveLoc_Style,
	SaveLoc_Jumps,
	SaveLoc_Strafes,
	SaveLoc_CheckpointsUsed,
	SaveLoc_GoodSync,
	SaveLoc_TotalSync,
	SaveLoc_Paused,
	SaveLoc_ReplayStartFrame,
	SaveLoc_ReplayTimerStartFrame
};

bool g_bClimbCpLoaded;
bool g_bTasLoaded;
bool g_bReplay3Loaded;

ConVar g_hSaveLocCvar;
ArrayList g_hSaveLocList;

Handle g_hFwdSaveLocCreated_Pre;
Handle g_hFwdSaveLocCreated_Post;

public Plugin:myinfo = 
{
	name = "[Timer] Save Location",
	author = "blacky",
	description = "Saves player locations when they leave the server or stop bhopping",
	version = "1.0",
	url = "http://steamcommunity.com/id/blaackyy/"
};

public void OnPluginStart()
{
	// Cvars
	g_hSaveLocCvar = CreateConVar("timer_saveloc_enable", "1", "Enable the save location plugin.", _, true, 0.0, true, 1.0);
	AutoExecConfig(true, "saveloc", "timer");
	
	// Event hooks
	HookEvent("player_spawn", Event_SendToLocation, EventHookMode_Post);
	HookEvent("player_death", Event_SaveLocation, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_SaveLocation, EventHookMode_Pre);
	//HookEvent("player_team", Event_SaveLocation, EventHookMode_Pre);
	
	// Saved location list
	g_hSaveLocList = CreateArray(view_as<int>(SaveLocationProp));
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hFwdSaveLocCreated_Pre  = CreateGlobalForward("OnSaveLocCreated_Pre", ET_Hook, Param_Cell);
	g_hFwdSaveLocCreated_Post = CreateGlobalForward("OnSaveLocCreated_Post", ET_Event, Param_Cell);
	
	CreateNative("SaveLoc_PlayerHasSaveLoc", Native_PlayerHasSaveLoc);
	
	RegPluginLibrary("timer-saveloc");
}

public int Native_PlayerHasSaveLoc(Handle plugin, int numParams)
{
	return FindIndexOfSaveLocation(GetNativeCell(1)) != -1;
}

public void OnAllPluginsLoaded()
{
	g_bClimbCpLoaded = LibraryExists("timer-climbcp");
	g_bTasLoaded     = LibraryExists("tas");
	g_bReplay3Loaded = LibraryExists("replay3");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "timer-climbcp"))
	{
		g_bClimbCpLoaded = true;
	}
	else if(StrEqual(name, "tas"))
	{
		g_bTasLoaded = true;
	}
	else if(StrEqual(name, "replay3"))
	{
		g_bReplay3Loaded = true;
		ClearArray(g_hSaveLocList);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "timer-climbcp"))
	{
		g_bClimbCpLoaded = false;
	}
	else if(StrEqual(name, "tas"))
	{
		g_bTasLoaded = false;
	}
	else if(StrEqual(name, "replay3"))
	{
		g_bReplay3Loaded = false;
		ClearArray(g_hSaveLocList);
	}
}

public void OnMapStart()
{
	// Clear list of saved locations
	ClearSaveLocationList();
}

public void Event_SendToLocation(Event event, const char[] name, bool dontBroadcast)
{
	if(GetConVarBool(g_hSaveLocCvar))
	{
		int userid = GetEventInt(event, "userid");
		CreateTimer(0.2, Timer_SendToLocation, userid);
	}
}

public Action Timer_SendToLocation(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
		
	if(client != 0 && !IsFakeClient(client) && IsClientAuthorized(client) && IsPlayerAlive(client))
	{
		int idx;
		if((idx = FindIndexOfSaveLocation(client)) != -1)
		{
			LoadSaveLocation(client, idx);
		}
	}
}

public void Event_SaveLocation(Event event, const char[] name, bool dontBroadcast)
{
	if(GetConVarBool(g_hSaveLocCvar))
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client != 0)
		{
			if(!IsFakeClient(client) && IsClientAuthorized(client) && IsBeingTimed(client, TIMER_ANY) && TimerInfo(client).CurrentTime > 1.0)
			{				
				if(g_bTasLoaded && TAS_InEditMode(client))
				{
					return;
				}
				
				SaveLocation(client, name);
			}
		}
	}
}

void ClearSaveLocationList()
{
	ClearArray(g_hSaveLocList);
}

float g_fLastSaveLocTime[MAXPLAYERS + 1];

public bool OnSaveLocCreated_Pre(int client)
{
	if(GetEngineTime() - g_fLastSaveLocTime[client] < 30)
	{
		return false;
	}
	
	return true;
}

public bool OnSaveLocCreated_Post(int client)
{
	g_fLastSaveLocTime[client] = GetEngineTime();
}

public Action OnTimerStart_Pre(int client, int Type, int style, int Method) 
{
	if(Method != StartMethod_SaveLocation && FindIndexOfSaveLocation(client) != -1)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

void SaveLocation(int client, const char[] event)
{
	Call_StartForward(g_hFwdSaveLocCreated_Pre);
	Call_PushCell(client);
	
	bool result;
	Call_Finish(result);
	
	if(result == false)
	{
		return;
	}
	
	// Save SteamId
	any[] data = new any[SaveLocationProp];
	GetClientAuthId(client, AuthId_Steam2, view_as<char>(data[SaveLoc_SteamId]), 32);
	
	// Save Position and Angle
	new Float:fPos[3], Float:fAng[3];
	Entity_GetAbsOrigin(client, fPos);
	Entity_GetAbsAngles(client, fAng);
	
	if(StrEqual(event, "player_death"))
	{
		float vMaxs[3];
		GetEntPropVector(client, Prop_Send, "m_vecMaxs", vMaxs);
		fPos[2] -= vMaxs[2];
		if(GetEngineVersion() == Engine_CSGO)
		{
			fPos[2] += 8.0;
		}
	}
	
	for(new idx; idx < 3; idx++)
	{
		data[view_as<int>(SaveLoc_Pos) + idx] = fPos[idx];
		data[view_as<int>(SaveLoc_Ang) + idx] = fAng[idx];
	}
	
	// Save time
	TimerInfo Info;
	Timer_GetClientTimerInfo(client, Info);
	data[SaveLoc_Time] = view_as<any>(Info.CurrentTime);
	
	data[SaveLoc_Type]            = Info.Type;
	data[SaveLoc_Style]           = Info.GetStyle(Info.Type);
	data[SaveLoc_Jumps]           = Info.Jumps;
	data[SaveLoc_Strafes]         = Info.Strafes;
	data[SaveLoc_CheckpointsUsed] = Info.CheckpointsUsed;
	data[SaveLoc_GoodSync]        = Info.GoodSync;
	data[SaveLoc_TotalSync]       = Info.TotalSync;
	
	if(g_bReplay3Loaded == true)
	{
		int startFrame, timerStartFrame;
		Replay_GetPlayerStartTicks(client, startFrame, timerStartFrame);
		data[SaveLoc_ReplayStartFrame] = startFrame;
		data[SaveLoc_ReplayTimerStartFrame] = timerStartFrame;
	}

	
	PushArrayArray(g_hSaveLocList, data);
	
	Call_StartForward(g_hFwdSaveLocCreated_Post);
	Call_PushCell(client);
	Call_Finish();
}

LoadSaveLocation(client, index)
{
	any[] data = new any[SaveLocationProp];
	GetArrayArray(g_hSaveLocList, index, data, view_as<int>(SaveLocationProp));
	
	TimerInfo Info;
	Timer_GetClientTimerInfo(client, Info);
	Info.Type                           = view_as<any>(data[SaveLoc_Type]);
	
	if(StartTimer(client, Info.Type, Info.CurrentTime, StartMethod_SaveLocation))
	{
		if(g_bClimbCpLoaded == true)
		{
			Timer_SetUsedCpCount(client, data[SaveLoc_CheckpointsUsed]);
		}
		
		Info.SetStyle(Info.Type, data[SaveLoc_Style])
		Info.Jumps           = data[SaveLoc_Jumps];
		Info.Strafes         = data[SaveLoc_Strafes];
		Info.GoodSync        = data[SaveLoc_GoodSync];
		Info.TotalSync       = data[SaveLoc_TotalSync];
		Info.CheckpointsUsed = data[SaveLoc_CheckpointsUsed];
		Info.CurrentTime     = view_as<float>(data[SaveLoc_Time]);
	}
	
	float fPos[3], fAng[3];
	
	for(new idx; idx < 3; idx++)
	{
		fPos[idx] = data[view_as<int>(SaveLoc_Pos) + idx];
		fAng[idx] = data[view_as<int>(SaveLoc_Ang) + idx];
	}
	
	TeleportEntity(client, fPos, fAng, view_as<float>({0.0, 0.0, 0.0}));
	//TeleportEntity(client, fPos, fAng, view_as<float>({0.0, 0.0, 0.0}));
	
	if(g_bReplay3Loaded == true)
	{
		Replay_SetPlayerStartTicks(client, data[SaveLoc_ReplayStartFrame], data[SaveLoc_ReplayTimerStartFrame]);
	}
	
	RemoveFromArray(g_hSaveLocList, index);
}

int FindIndexOfSaveLocation(client)
{
	decl String:sClientSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sClientSteamID, sizeof(sClientSteamID));
	
	any[] SaveLoc = new any[SaveLocationProp];
	
	new iSize = GetArraySize(g_hSaveLocList);
	for(new idx; idx < iSize; idx++)
	{
		GetArrayArray(g_hSaveLocList, idx, SaveLoc);
		
		if(StrEqual(view_as<char>(SaveLoc[SaveLoc_SteamId]), sClientSteamID))
		{
			return idx;
		}
	}
	
	return -1;
}