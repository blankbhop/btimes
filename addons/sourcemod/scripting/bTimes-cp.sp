#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] Checkpoints",
	author = "blacky",
	description = "Checkpoints plugin for the timer",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sdktools>
#include <sourcemod>
#include <bTimes-timer>
#include <bTimes-zones>
#include <smlib/entities>
#include <csgocolors>

#pragma newdecls required

ArrayList g_hCheckpointList[MAXPLAYERS + 1];

bool g_UsePos[MAXPLAYERS+1] = {true, ...};
bool g_UseVel[MAXPLAYERS+1] = {false, ...};
bool g_UseAng[MAXPLAYERS+1] = {false, ...};

int  g_LastUsed[MAXPLAYERS+1];
bool g_HasLastUsed[MAXPLAYERS+1];
	
float g_fLastTpToTime[MAXPLAYERS + 1];

bool g_AntiCpPrespeed[MAXPLAYERS + 1];

int  g_iLastCpTick[MAXPLAYERS + 1];
	
// Cvars
Handle g_hAllowCp;

bool g_bLateLoad;

public void OnPluginStart()
{
	// Cvars
	g_hAllowCp = CreateConVar("timer_allowcp", "1", "Allows players to use the checkpoint plugin's features.", 0, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "cp", "timer");
	
	// Commands
	RegConsoleCmdEx("sm_cp", SM_CP, "Opens the checkpoint menu.");
	RegConsoleCmdEx("sm_checkpoint", SM_CP, "Opens the checkpoint menu.");
	RegConsoleCmdEx("sm_tele", SM_Tele, "Teleports you to the specified checkpoint.");
	RegConsoleCmdEx("sm_lastsaved", SM_LastSaved, "Teleports you to your last saved checkpoint.");
	RegConsoleCmdEx("sm_lastused", SM_LastUsed, "Teleports you to your last saved checkpoint.");
	RegConsoleCmdEx("sm_tp", SM_Tele, "Teleports you to the specified checkpoint.");
	RegConsoleCmdEx("sm_save", SM_Save, "Saves a new checkpoint.");
	RegConsoleCmdEx("sm_tpto", SM_TpTo, "Teleports you to a player.");
	RegConsoleCmdEx("sm_teleport", SM_TpTo, "Teleports you to a player.");
	
	// Makes FindTarget() work properly
	LoadTranslations("common.phrases");
	
	if(g_bLateLoad)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				OnClientPutInServer(client);
			}
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(late)
	{
		UpdateMessages();
	}
	
	g_bLateLoad = late;
}

public void OnClientPutInServer(int client)
{
	if(g_hCheckpointList[client] == INVALID_HANDLE)
	{
		g_hCheckpointList[client] = CreateArray(9);
	}
	
	g_hCheckpointList[client].Clear();
	
	g_UseAng[client] = true;
	g_UsePos[client] = true;
	g_UseVel[client] = true;
	
	g_iLastCpTick[client] = 0;
}

public Action OnTimerStart_Pre(int client, int type, int style, int Method)
{
	if(g_AntiCpPrespeed[client] == true)
	{
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		g_AntiCpPrespeed[client] = false;
	}
	
	if(GetGameTickCount() < g_iLastCpTick[client] + 10)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action SM_TpTo(int client, int args)
{
	if(GetConVarBool(g_hAllowCp))
	{
		if(IsPlayerAlive(client))
		{
			if(args == 0)
			{
				OpenTpToMenu(client);
			}
			else
			{
				char argString[250];
				GetCmdArgString(argString, sizeof(argString));
				int target = FindTarget(client, argString, false, false);
				
				if(client != target)
				{
					if(target != -1)
					{
						if(IsPlayerAlive(target))
						{
							if(GetEngineTime() - g_fLastTpToTime[client] > 10.0)
							{
								float vPos[3];
								GetEntPropVector(target, Prop_Send, "m_vecOrigin", vPos);
								
								StopTimer(client);
								TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
								g_fLastTpToTime[client] = GetEngineTime();
							}
							else
							{
								PrintColorText(client, "%s%sWait %s%.1f%s seconds to use tpto again.",
									g_msg_start,
									g_msg_textcol,
									g_msg_varcol,
									10.0 - (GetEngineTime() - g_fLastTpToTime[client]),
									g_msg_textcol);
							}
						}
						else
						{
							PrintColorText(client, "%s%sTarget not alive.",
								g_msg_start,
								g_msg_textcol);
						}
					}
					else
					{
						OpenTpToMenu(client);
					}
				}
				else
				{
					PrintColorText(client, "%s%sYou can't target yourself.",
						g_msg_start,
						g_msg_textcol);
				}
			}
		}
		else
		{
			PrintColorText(client, "%s%sYou must be alive to use the sm_tpto command.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

void OpenTpToMenu(int client)
{
	Menu menu = new Menu(Menu_Tpto);
	menu.SetTitle("Select player to teleport to");

	char sTarget[MAX_NAME_LENGTH], sInfo[8];
	for(int target = 1; target <= MaxClients; target++)
	{
		if(target != client && IsClientInGame(target))
		{
			GetClientName(target, sTarget, sizeof(sTarget));
			IntToString(GetClientUserId(target), sInfo, sizeof(sInfo));
			menu.AddItem(sInfo, sTarget);
		}
	}

	menu.ExitBackButton = true;
	menu.ExitButton     = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Tpto(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		int target = GetClientOfUserId(StringToInt(sInfo));
		if(target != 0)
		{
			if(GetEngineTime() - g_fLastTpToTime[client] > 10.0)
			{
				float vPos[3];
				GetEntPropVector(target, Prop_Send, "m_vecOrigin", vPos);
				
				StopTimer(client);
				TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
				g_fLastTpToTime[client] = GetEngineTime();
			}
			else
			{
				PrintColorText(client, "%s%sWait %s%.1f%s seconds to use tpto again.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					10.0 - (GetEngineTime() - g_fLastTpToTime[client]),
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sTarget not in game.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}
/*
stock void SendTpToRequest(int client, int target)
{
	if(g_BlockTpTo[target][client] == false)
	{
		new Handle:menu = CreateMenu(Menu_TpRequest);
		
		decl String:sInfo[16];
		new UserId = GetClientUserId(client);
		
		SetMenuTitle(menu, "%N wants to teleport to you", client);
		
		Format(sInfo, sizeof(sInfo), "%d;a", UserId);
		AddMenuItem(menu, sInfo, "Accept");
		
		Format(sInfo, sizeof(sInfo), "%d;d", UserId);
		AddMenuItem(menu, sInfo, "Deny");
		
		Format(sInfo, sizeof(sInfo), "%d;b", UserId);
		AddMenuItem(menu, sInfo, "Deny & Block");
		
		DisplayMenu(menu, target, 20);
	}
	else
	{
		PrintColorText(client, "%s%s%N %sblocked all tpto requests from you.",
			g_msg_start,
			g_msg_varcol,
			target,
			g_msg_textcol);
	}
}

public Menu_TpRequest(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		decl String:sInfoExploded[2][16];
		ExplodeString(info, ";", sInfoExploded, 2, 16);
		
		new client = GetClientOfUserId(StringToInt(sInfoExploded[0]));
		
		if(client != 0)
		{
			if(sInfoExploded[1][0] == 'a') // accept
			{
				new Float:vPos[3];
				Entity_GetAbsOrigin(param1, vPos);
				
				StopTimer(client);
				TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
				
				PrintColorText(client, "%s%s%N %saccepted your request.",
					g_msg_start,
					g_msg_varcol,
					param1,
					g_msg_textcol);
			}
			else if(sInfoExploded[1][0] == 'd') // deny
			{
				PrintColorText(client, "%s%s%N %sdenied your request.",
					g_msg_start,
					g_msg_varcol,
					param1,
					g_msg_textcol);
			}
			else if(sInfoExploded[1][0] == 'b') // deny and block
			{				
				g_BlockTpTo[param1][client] = true;
				PrintColorText(client, "%s%s%N %sdenied denied your request and blocked future requests from you.",
					g_msg_start,
					g_msg_varcol,
					param1,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(param1, "%s%sThe tp requester is no longer in game.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
}
*/

public Action SM_CP(int client, int args)
{
	if(GetConVarBool(g_hAllowCp))
	{
		OpenCheckpointMenu(client);
	}
	
	return Plugin_Handled;
}

void OpenCheckpointMenu(int client)
{
	Menu menu = new Menu(Menu_Checkpoint);
	menu.SetTitle("Checkpoint menu");
	menu.AddItem("Save", "Save");
	menu.AddItem("Teleport", "Teleport");
	menu.AddItem("Delete", "Delete");
	menu.AddItem("usepos", g_UsePos[client]?"Use position: Yes":"Use position: No");
	menu.AddItem("usevel", g_UseVel[client]?"Use velocity: Yes":"Use velocity: No");
	menu.AddItem("useang", g_UseAng[client]?"Use angles: Yes":"Use angles: No");
	menu.AddItem("Noclip", "Noclip");
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Checkpoint(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "Save"))
		{
			SaveCheckpoint(param1);
			OpenCheckpointMenu(param1);
		}
		else if(StrEqual(sInfo, "Teleport"))
		{
			OpenTeleportMenu(param1);
		}
		else if(StrEqual(sInfo, "Delete"))
		{
			OpenDeleteMenu(param1);
		}
		else if(StrEqual(sInfo, "usepos"))
		{
			g_UsePos[param1] = !g_UsePos[param1];
			OpenCheckpointMenu(param1);
		}
		else if(StrEqual(sInfo, "usevel"))
		{
			g_UseVel[param1] = !g_UseVel[param1];
			OpenCheckpointMenu(param1);
		}
		else if(StrEqual(sInfo, "useang"))
		{
			g_UseAng[param1] = !g_UseAng[param1];
			OpenCheckpointMenu(param1);
		}
		else if(StrEqual(sInfo, "Noclip"))
		{
			FakeClientCommand(param1, "sm_practice");
			OpenCheckpointMenu(param1);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}

void OpenTeleportMenu(int client)
{
	Menu menu = new Menu(Menu_Teleport);
	
	menu.SetTitle("Teleport");
	menu.AddItem("lastused", "Last used");
	menu.AddItem("lastsaved", "Last saved");
	
	char sTp[8], sInfo[8];
	for(int idx; idx < g_hCheckpointList[client].Length; idx++)
	{
		Format(sTp, sizeof(sTp), "CP %d", idx + 1);
		Format(sInfo, sizeof(sInfo), "%d", idx);
		AddMenuItem(menu, sInfo, sTp);
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton     = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Teleport(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "lastused"))
		{
			TeleportToLastUsed(param1);
			OpenTeleportMenu(param1);
		}
		else if(StrEqual(sInfo, "lastsaved"))
		{
			TeleportToLastSaved(param1);
			OpenTeleportMenu(param1);
		}
		else
		{
			char infoGuess[8];
			for(int idx; idx < g_hCheckpointList[param1].Length; idx++)
			{
				FormatEx(infoGuess, sizeof(infoGuess), "%d", idx);
				if(StrEqual(sInfo, infoGuess))
				{
					TeleportToCheckpoint(param1, idx);
					OpenTeleportMenu(param1);
					break;
				}
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			OpenCheckpointMenu(param1);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}

void OpenDeleteMenu(int client)
{
	if(g_hCheckpointList[client].Length > 0)
	{
		Menu menu = new Menu(Menu_Delete);
		menu.SetTitle("Delete");
		
		char sDisplay[16], sInfo[8];
		for(int idx; idx < g_hCheckpointList[client].Length; idx++)
		{
			Format(sDisplay, sizeof(sDisplay), "Delete %d", idx + 1);
			IntToString(idx, sInfo, sizeof(sInfo));
			AddMenuItem(menu, sInfo, sDisplay);
		}
		
		menu.ExitBackButton = true;
		menu.ExitButton     = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		PrintColorText(client, "%s%sYou have no checkpoints saved.",
			g_msg_start,
			g_msg_textcol);
		OpenCheckpointMenu(client);
	}
}

public int Menu_Delete(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		DeleteCheckpoint(param1, StringToInt(sInfo));
		OpenDeleteMenu(param1);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			OpenCheckpointMenu(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
	
}

public Action SM_LastUsed(int client, int args)
{
	TeleportToLastUsed(client);
	
	return Plugin_Handled;
}

public Action SM_LastSaved(int client, int args)
{
	TeleportToLastSaved(client);
	
	return Plugin_Handled;
}

public Action SM_Tele(int client, int args)
{
	if(args != 0)
	{
		char sArg[256];
		GetCmdArgString(sArg, sizeof(sArg));
		
		if(StrEqual(sArg, "saved"))
		{
			TeleportToLastSaved(client);
		}
		else if(StrEqual(sArg, "used"))
		{
			TeleportToLastUsed(client);
		}
		else
		{
			int checkPoint = StringToInt(sArg) - 1;
			TeleportToCheckpoint(client, checkPoint);
		}
	}
	else 
	{
		ReplyToCommand(client, "[SM] Usage: sm_tele <Checkpoint number>.");
	}
	
	return Plugin_Handled;
}

public Action SM_Save(int client, int args)
{
	SaveCheckpoint(client);
	
	return Plugin_Handled;
}

void SaveCheckpoint(int client)
{
	if(GetConVarBool(g_hAllowCp))
	{
		float pos[3], vel[3], ang[3];
		Entity_GetAbsOrigin(client, pos);
		Entity_GetAbsVelocity(client, vel);
		GetClientEyeAngles(client, ang);
		
		float data[9];
		data[0] = pos[0];
		data[1] = pos[1];
		data[2] = pos[2];
		data[3] = vel[0];
		data[4] = vel[1];
		data[5] = vel[2];
		data[6] = ang[0];
		data[7] = ang[1];
		data[8] = ang[2];
		
		g_hCheckpointList[client].PushArray(data);
		
		PrintColorText(client, "%s%sCheckpoint %s%d%s saved.", 
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_hCheckpointList[client].Length,
			g_msg_textcol);
	}
}

void DeleteCheckpoint(int client, int cpnum)
{
	if(0 <= cpnum < g_hCheckpointList[client].Length)
	{
		RemoveFromArray(g_hCheckpointList[client], cpnum);
		
		if(cpnum < g_LastUsed[client])
		{
			g_LastUsed[client]--;
		}
		else if(cpnum == g_LastUsed[client])
		{
			g_HasLastUsed[client] = false;
		}
		
		if(g_hCheckpointList[client].Length == 0)
		{
			g_HasLastUsed[client] = false;
		}
	}
	else
	{
		PrintColorText(client, "%s%sCheckpoint %s%d%s doesn't exist.", 
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			cpnum+1,
			g_msg_textcol);
	}
}

void TeleportToCheckpoint(int client, int cpnum)
{
	if(GetConVarBool(g_hAllowCp))
	{
		if(0 <= cpnum < g_hCheckpointList[client].Length)
		{
			float fData[9], vPos[3], vVel[3], vAng[3];
			g_hCheckpointList[client].GetArray(cpnum, fData, sizeof(fData));
			
			vPos[0] = fData[0];
			vPos[1] = fData[1];
			vPos[2] = fData[2];
			vVel[0] = fData[3];
			vVel[1] = fData[4];
			vVel[2] = fData[5];
			vAng[0] = fData[6];
			vAng[1] = fData[7];
			vAng[2] = fData[8];
			
			StopTimer(client);
			
			// Prevent using velocity with checkpoints inside start zones so players can't abuse it to beat times
			if(g_UsePos[client] == false)
			{
				if(Timer_InsideZone(client, MAIN_START) != -1 || Timer_InsideZone(client, BONUS_START) != -1)
				{
					TeleportEntity(client, 
						g_UsePos[client]?vPos:NULL_VECTOR, 
						g_UseAng[client]?vAng:NULL_VECTOR, 
						view_as<float>({0.0, 0.0, 0.0}));
				}
				else
				{
					TeleportEntity(client, 
						g_UsePos[client]?vPos:NULL_VECTOR, 
						g_UseAng[client]?vAng:NULL_VECTOR, 
						g_UseVel[client]?vVel:NULL_VECTOR);
				}
			}
			else
			{
				if(!Timer_IsPointInsideZone(vPos, MAIN_START, 0) && !Timer_IsPointInsideZone(vPos, BONUS_START, 0))
				{
					TeleportEntity(client, 
						g_UsePos[client]?vPos:NULL_VECTOR, 
						g_UseAng[client]?vAng:NULL_VECTOR, 
						g_UseVel[client]?vVel:NULL_VECTOR);
				}
				else
				{
					TeleportEntity(client, 
						g_UsePos[client]?vPos:NULL_VECTOR, 
						g_UseAng[client]?vAng:NULL_VECTOR, 
						view_as<float>({0.0, 0.0, 0.0}));
				}
			}
			
			g_iLastCpTick[client] = GetGameTickCount();
			
			g_AntiCpPrespeed[client] = true;
			
			g_HasLastUsed[client] = true;
			g_LastUsed[client]    = cpnum;
		}
		else
		{
			PrintColorText(client, "%s%sCheckpoint %s%d%s doesn't exist.", 
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				cpnum+1,
				g_msg_textcol);
		}
	}
}

void TeleportToLastUsed(int client)
{
	if(GetConVarBool(g_hAllowCp))
	{
		if(g_HasLastUsed[client] == true)
		{
			TeleportToCheckpoint(client, g_LastUsed[client]);
		}
		else
		{
			PrintColorText(client, "%s%sYou have no last used checkpoint.",
				g_msg_start,
				g_msg_textcol);
		}
	}
}

void TeleportToLastSaved(int client)
{
	if(GetConVarBool(g_hAllowCp))
	{
		if(g_hCheckpointList[client].Length > 0)
		{
			TeleportToCheckpoint(client, g_hCheckpointList[client].Length - 1);
		}
		else
		{
			PrintColorText(client, "%s%sYou have no last saved checkpoint.",
				g_msg_start,
				g_msg_textcol);
		}
	}
}