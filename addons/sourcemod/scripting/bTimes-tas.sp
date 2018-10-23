#pragma semicolon 1

#include <bTimes-core>
#include <bTimes-timer>
#include <bTimes-zones>
#include <smlib/entities>
#include <smlib/arrays>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#include <bTimes-climbcp>
#include <bTimes-saveloc>

#pragma newdecls required

#define FRAMESIZE 16

ArrayList g_hFrameList[MAXPLAYERS + 1];
float     g_CurrentFrame[MAXPLAYERS + 1];
bool      g_bTASMode[MAXPLAYERS + 1];
bool      g_bUsedFrame[MAXPLAYERS + 1];
bool      g_bFastForward[MAXPLAYERS + 1];
bool      g_bRewind[MAXPLAYERS + 1];
bool      g_bPaused[MAXPLAYERS + 1];
float     g_fEditSpeed[MAXPLAYERS + 1];
bool      g_bSpeedUpFromUnpause[MAXPLAYERS + 1];
float     g_fSpeedTicksPassed[MAXPLAYERS + 1];
bool      g_bDontCutVelocity[MAXPLAYERS + 1];
int       g_LastButtons[MAXPLAYERS + 1];
float     g_fTimescale[MAXPLAYERS + 1];

bool g_bLateLoad;

Handle g_fwdOnTASPauseChange;
Handle g_fwdOnTASFrameRecorded;

public Plugin myinfo =
{
	name = "[bTimes] TAS",
	author = "blacky",
	description = "Adds the Tool-Assisted Speedrun style.",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_tas", SM_TAS, "Opens the TAS menu.");
	RegConsoleCmd("+rewind", Command_Rewind);
	RegConsoleCmd("-rewind", Command_Rewind);
	RegConsoleCmd("+fastforward", Command_FastForward);
	RegConsoleCmd("-fastforward", Command_FastForward);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && g_bPaused[client])
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
}

public void OnMapStart()
{
	if(g_bLateLoad == true)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				InitializePlayerSettings(client);
			}
		}
	}	
}

public APLRes AskPluginLoad(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tas");
	
	CreateNative("TAS_InEditMode",       Native_IsInEditMode);
	CreateNative("TAS_IsPaused",         Native_IsPaused);
	CreateNative("TAS_GetRunHandle",     Native_GetRunHandle);
	CreateNative("TAS_GetCurrentFrame",  Native_GetCurrentFrame);
	
	g_fwdOnTASPauseChange = CreateGlobalForward("OnTASPauseChange", ET_Event, Param_Cell, Param_Cell);
	g_fwdOnTASFrameRecorded = CreateGlobalForward("OnTASFrameRecorded", ET_Event, Param_Cell, Param_Cell);
	
	g_bLateLoad = late;
	
	if(late)
	{
		UpdateMessages();
	}
	
	return APLRes_Success;
}

public void OnStyleChanged(int client, int oldStyle, int newStyle, int type)
{
	if(g_bTASMode[client])
	{
		if(Style(newStyle).AllowTAS == false)
		{
			ExitTASMode(client);
		}

		g_hFrameList[client].Clear();
		g_CurrentFrame[client]       = 0.0;
        g_bFastForward[client]       = false;
        g_bRewind[client]            = false;
        g_bPaused[client]            = false;
        g_bDontCutVelocity[client]   = false;
		SetEntityMoveType(client, MOVETYPE_WALK);
		OpenTASMenu(client);
	}
}

public bool OnCheckpointUsed_Pre(int client)
{
	if(g_bTASMode[client])
	{
		PrintColorText(client, "%s%sYou cannot use checkpoints on TAS mode.",
			g_msg_start,
			g_msg_color);
			
		return false;
	}
	
	return true;
}

public bool OnCheckpointSaved_Pre(int client)
{
	if(g_bTASMode[client])
	{
		PrintColorText(client, "%s%sYou cannot save checkpoints on TAS mode.",
			g_msg_start,
			g_msg_color);
			
		return false;
	}
	
	return true;
}

public bool OnSaveLocCreated_Pre(int client)
{
	if(g_bTASMode[client])
	{
		return false;
	}
	
	return true;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(g_bTASMode[client] == true)
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fTimescale[client]);
	}
}

public Action Command_Rewind(int client, int args)
{
	if(g_bTASMode[client])
	{
		char sArg[32];
		GetCmdArg(0, sArg, sizeof(sArg));
		if(StrEqual(sArg, "+rewind"))
		{
			g_bRewind[client] = true;
		}
		else if(StrEqual(sArg, "-rewind"))
		{
			g_bRewind[client] = false;
		}
		
		g_bPaused[client] = true;
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
		OpenTASMenu(client);
	}
	
	return Plugin_Handled;
}

public Action Command_FastForward(int client, int args)
{
	if(g_bTASMode[client])
	{
		char sArg[32];
		GetCmdArg(0, sArg, sizeof(sArg));
		if(StrEqual(sArg, "+fastforward"))
		{
			g_bFastForward[client] = true;
		}
		else if(StrEqual(sArg, "-fastforward"))
		{
			g_bFastForward[client] = false;
		}
		
		g_bPaused[client] = true;
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
		OpenTASMenu(client);
	}
	
	return Plugin_Handled;
}

public int Native_IsInEditMode(Handle plugin, int numParams)
{
	return g_bTASMode[GetNativeCell(1)];
}

public int Native_IsPaused(Handle plugin, int numParams)
{
	return g_bPaused[GetNativeCell(1)];
}

public int Native_GetRunHandle(Handle plugin, int numParams)
{
	return view_as<int>(g_hFrameList[GetNativeCell(1)]);
}

public void OnClientPutInServer(int client)
{
	InitializePlayerSettings(client);
}

void InitializePlayerSettings(int client)
{
	if(g_bUsedFrame[client] == false)
	{
		g_hFrameList[client] = CreateArray(FRAMESIZE);
		g_bUsedFrame = true;
	}
	else
	{
		g_hFrameList[client].Clear();
	}
	
	g_bFastForward[client]       = false;
	g_bRewind[client]            = false;
	g_bPaused[client]            = false;
	g_fEditSpeed[client]         = 0.5;
	g_bDontCutVelocity[client]   = false;
	g_fTimescale[client]         = 0.6;
	g_fTimescale[client]        += 0.1;
	g_bTASMode[client]           = false;
}

public Action SM_TAS(int client, int args)
{
	OpenTASMenu(client);
	
	return Plugin_Handled;
}

/*
public void Hook_PostThink(int client)
{
	float fSpeed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
	if(fSpeed != 1.0 && g_bDontCutVelocity[client] == false)
	{
		float vVel[3];
		Entity_GetAbsVelocity(client, vVel);
		
		float vNewVel[3];
		vNewVel[0] = g_vLastVel[client][0] + (vVel[0] - g_vLastVel[client][0] / (1.0 / fSpeed);
		vNewVel[1] = g_vLastVel[client][1] + (vVel[1] - g_vLastVel[client][1] / (1.0 / fSpeed);
		vNewVel[2] vVel[2];
		
		Entity_SetAbsVelocity(client, vNewVel);
	}
	
	g_bDontCutVelocity[client]   = false;
	
	float vAbsVel[3];
	Entity_GetAbsVelocity(client, vAbsVel);
	Array_Copy(vAbsVel, g_vLastVel[client], 3);
}
*/

public void OnTimerStart_Post(int client, int Type, int style)
{
	g_hFrameList[client].Clear();
}

public Action OnTimerStart_Pre(int client, int Type, int style)
{
	if(g_bTASMode[client] && g_bPaused[client] && TimerInfo(client).IsTiming)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

void OpenTASMenu(int client)
{
	Menu menu = new Menu(Menu_TAS);
	menu.SetTitle("Speedrun Assistant");
	
	if(g_bTASMode[client])
	{
		char sDisplay[32];
		menu.AddItem("pr", g_bPaused[client]?"Resume":"Pause");
		menu.AddItem("rw", g_bRewind[client]?"-rewind":"+rewind");
		menu.AddItem("ff", g_bFastForward[client]?"-fastforward":"+fastforward");
		FormatEx(sDisplay, sizeof(sDisplay), "Edit Speed: %.2f", g_fEditSpeed[client]);
		menu.AddItem("editspeed", sDisplay);
		FormatEx(sDisplay, sizeof(sDisplay), "Timescale: %.1f", g_fTimescale[client]);
		menu.AddItem("ts", sDisplay);
		menu.AddItem("exit", "Exit TAS Mode");		
		
		if(g_bSpeedUpFromUnpause[client] == false)
		{
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fTimescale[client]);
		}
	}
	else
	{
		menu.AddItem("enter", "Enter TAS Mode");
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_TAS(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "pr"))
		{
			if(Timer_InsideZone(client, MAIN_START) == -1 && Timer_InsideZone(client, BONUS_START) == -1)
			{
				g_bPaused[client] = !g_bPaused[client];
				if(g_bPaused[client] == false)
				{
					SetEntityMoveType(client, MOVETYPE_WALK);
					g_bSpeedUpFromUnpause[client] = true;
					TeleportToFrame(client, true);
					SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.01);
					ResizeArray(g_hFrameList[client], RoundToFloor(g_CurrentFrame[client]) + 1);
				}
				else
				{
					SetEntityMoveType(client, MOVETYPE_NONE);
					TeleportToFrame(client, true);
				}
				
				Call_StartForward(g_fwdOnTASPauseChange);
				Call_PushCell(client);
				Call_PushCell(g_bPaused[client]);
				Call_Finish();
			}
			else
			{
				PrintColorText(client, "%s%sYou cannot pause inside the start zone.",
					g_msg_start,
					g_msg_textcol);
			}
		
			OpenTASMenu(client);
		}
		else if(StrEqual(sInfo, "rw"))
		{
			g_bPaused[client] = true;
			SetEntityMoveType(client, MOVETYPE_NONE);
			
			g_bRewind[client] = !g_bRewind[client];
			
			if(g_bRewind[client])
			{
				g_bFastForward[client] = false;
			}
			
			OpenTASMenu(client);
		}
		else if(StrEqual(sInfo, "ff"))
		{
			g_bPaused[client] = true;
			SetEntityMoveType(client, MOVETYPE_NONE);
			
			g_bFastForward[client] = !g_bFastForward[client];
			
			if(g_bFastForward[client])
			{
				g_bRewind[client] = false;
			}
			
			OpenTASMenu(client);
		}
		else if(StrEqual(sInfo, "editspeed"))
		{
			g_fEditSpeed[client] *= 2;
			
			if(g_fEditSpeed[client] > 128)
			{
				g_fEditSpeed[client] = 0.25;
			}
			
			OpenTASMenu(client);
		}
		else if(StrEqual(sInfo, "ts"))
		{
			g_fTimescale[client] += 0.1;
			
			if(g_fTimescale[client] > 1.05)
			{
				g_fTimescale[client] = 0.2;
			}
			
			OpenTASMenu(client);
		}
		else if(StrEqual(sInfo, "enter"))
		{
			if(Style(TimerInfo(client).ActiveStyle).AllowTAS == true)
			{
				g_bTASMode[client] = true;
				OpenTASMenu(client);
			
				if(TimerInfo(client).Type == TIMER_BONUS)
					Timer_TeleportToZone(client, BONUS_START, 0, true);
				else
					Timer_TeleportToZone(client, MAIN_START, 0, true);
			}
			else
			{
				PrintColorText(client, "%s%sYou cannot use TAS on your current style.",
					g_msg_start,
					g_msg_textcol);
			}
			
		}
		else if(StrEqual(sInfo, "exit"))
		{
			OpenExitTASPrompt(client);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
}

void OpenExitTASPrompt(int client)
{
	Menu menu = new Menu(Menu_ExitTAS);
	menu.SetTitle("Exit TAS Mode?");
	menu.AddItem("y", "Yes");
	menu.AddItem("n", "No");
	menu.ExitBackButton = true;
	menu.ExitButton     = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_ExitTAS(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "y"))
		{
			ExitTASMode(client);
		}
		else if(StrEqual(sInfo, "n"))
		{
			OpenTASMenu(client);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit || param2 == MenuCancel_ExitBack)
		{
			OpenTASMenu(client);
		}
	}
}

void ExitTASMode(int client)
{
	g_bTASMode[client] = false;
	
	if(g_bPaused[client] == true)
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
	
	g_bPaused[client] = false;
	StopTimer(client);
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
}
/*
void RecordFrame(int client)
{
	float vPos[3];
	Entity_GetAbsOrigin(client, vPos);
	
	float
}*/

public int Native_GetCurrentFrame(Handle plugin, int numParams)
{
	return RoundToFloor(g_CurrentFrame[GetNativeCell(1)]);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angels[3], int &weapon, int &subtype
{
	if(g_bTASMode[client] == true && IsPlayerAlive(client))
	{
		if(g_bPaused[client] == true) //Player can rewind/fastforward when paused
		{
			float frameSkips;
			if(g_bFastForward[client])
			{
				frameSkips += g_fEditSpeed[client];
			}
			if(g_bRewind[client])
			{
				frameSkips -= g_fEditSpeed[client];
			}
			
			int size = GetArraySize(g_hFrameList[client]);
			if(size !=0 && frameSkips != 0)
			{
				g_CurrentFrame[client] += frameSkips;
				
				if(g_CurrentFrame[client] < 0)
				{
					g_CurrentFrame = float(GetArraySize(g_hFrameList[client]) - 1);
				}
				else if(g_CurrentFrame[client] >= GetArraySize(g_hFrameList[client]));
				{
					g_CurrentFrame[client] = 0.0;
				}
			}
			
			TeleportToFrame(client);
			
			if(!(g_LastButtons[client] & IN_JUMP) && (Timer_GetButtons(client) & IN_JUMP))
			{
				g_bPaused[client] = false;
				
				SetEntityMoveType(client, MOVETYPE_WALK);
				g_bSpeedUpFromUnpause[client] = true;
				TeleportToFrame(client, true, buttons)
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.01);
				ResizeArray(g_hFrameList[client], RoundToFloor(g_CurrentFrame[client]) + 1);
				g_bDontCutVelocity[client] = true;
				
				OpenTASMenu(client);
				
				Call_StartForward(g_fwdOnTASPauseChange);
				Call_PushCell(client);
				Call_PushCell(false);
				Call_Finish();
			}
		}
		else // Record run
		{
			float fSpeed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
			g_fSpeedTicksPassed[client] += fSpeed;
			if(g_fSpeedTicksPassed[client] >= 1.0)
			{
				RecordFrame(client);
				g_fSpeedTicksPassed[client] -= 1.0;
			}
			else
			{
				if(GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") != 0)
				{
					
				}
			}
		}
	}
}





















