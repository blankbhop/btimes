#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] Ghost",
	author = "blacky",
	description = "Shows bots that replay the top times",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <smlib/weapons>
#include <smlib/entities>
#include <cstrike>
#include <setname>
#include <bTimes-timer>

#pragma newdecls required

char g_sMapName[64];

ArrayList g_hFrame[MAXPLAYERS + 1];
bool      g_bUsedFrame[MAXPLAYERS + 1];

ArrayList g_hGhost[MAX_TYPES][MAX_STYLES];
int    g_Ghost[MAX_TYPES][MAX_STYLES];
int    g_GhostFrame[MAX_TYPES][MAX_STYLES];
bool   g_GhostPaused[MAX_TYPES][MAX_STYLES];
char   g_sGhost[MAX_TYPES][MAX_STYLES][48];
char   g_sGhostClanTag[MAX_TYPES][MAX_STYLES][MAX_NAME_LENGTH];
int    g_GhostPlayerID[MAX_TYPES][MAX_STYLES];
float  g_fGhostTime[MAX_TYPES][MAX_STYLES];
float  g_fPauseTime[MAX_TYPES][MAX_STYLES];
int    g_iBotQuota;
bool   g_bGhostLoadedOnce[MAX_TYPES][MAX_STYLES];
bool   g_bGhostLoaded[MAX_TYPES][MAX_STYLES];
bool   g_bHasMapStarted;
	
float  g_fStartTime[MAX_TYPES][MAX_STYLES];

// Cvars
ConVar g_hGhostWeapon[MAX_TYPES][MAX_STYLES];
ConVar g_hGhostDontShoot[MAX_TYPES][MAX_STYLES];
ConVar g_hGhostStartPauseTime;
ConVar g_hGhostEndPauseTime;
ConVar g_hGhostJoinCommand;
	
// Weapon control
bool g_bNewWeapon;

bool g_bLateLoaded;
	
public void OnPluginStart()
{
	g_hGhostStartPauseTime = CreateConVar("timer_ghoststartpause", "5.0", "How long the ghost will pause before starting its run.");
	g_hGhostEndPauseTime   = CreateConVar("timer_ghostendpause", "2.0", "How long the ghost will pause after it finishes its run.");
	g_hGhostJoinCommand    = CreateConVar("timer_ghostjoincommand", "bot_add", "The command that will add replay bots to the game.");
	
	AutoExecConfig(true, "ghost", "timer");
	
	// Events
	HookEvent("player_changename", Event_PlayerChangeName);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	// Create admin command that deletes the ghost
	RegAdminCmd("sm_deleteghost", SM_DeleteGhost, ADMFLAG_CHEATS, "Deletes the ghost.");
	
	ConVar hBotDontShoot = FindConVar("bot_dont_shoot");
	hBotDontShoot.Flags &= ~FCVAR_CHEAT;
	
	if(g_bLateLoaded)
	{
		ServerCommand("bot_kick all");
		
		char sTypeAbbr[8], sType[16], sStyleAbbr[8], sStyle[16], sTypeStyleAbbr[24], sCvar[32], sDesc[128];
		Style s;
		for(int Type; Type < MAX_TYPES; Type++)
		{
			for(int style; style < MAX_STYLES; style++)
			{
				GetStyleConfig(style, s);
				// Don't create cvars for styles on bonus except normal style
				if(s.GetUseGhost(Type))
				{
					s.GetName(sStyle, sizeof(sStyle));
					s.GetNameShort(sStyleAbbr, sizeof(sStyleAbbr));
					
					Format(g_sGhost[Type][style], sizeof(g_sGhost[][]), "%s %s", sType, sStyle);
					
					Format(sTypeStyleAbbr, sizeof(sTypeStyleAbbr), "%s%s", sTypeAbbr, sStyleAbbr);
					StringToUpper(sTypeStyleAbbr);
					
					Format(sCvar, sizeof(sCvar), "timer_ghostweapon_%s%s", sTypeAbbr, sStyleAbbr);
					Format(sDesc, sizeof(sDesc), "The weapon the replay bot will always use (%s style on %s timer)", sStyle, sType);
					g_hGhostWeapon[Type][style] = CreateConVar(sCvar, "weapon_glock", sDesc);
					
					Format(sCvar, sizeof(sCvar), "timer_dontshoot_%s%s", sTypeAbbr, sStyleAbbr);
					Format(sDesc, sizeof(sDesc), "Forces the replay bot to never shoot during runs (%s style on %s timer)", sStyle, sType);
					g_hGhostDontShoot[Type][style] = CreateConVar(sCvar, "1", sDesc, 0, true, 0.0, true, 1.0);
					
					HookConVarChange(g_hGhostWeapon[Type][style], OnGhostWeaponChanged);
					
					g_hGhost[Type][style] = new ArrayList(6);
				}
			}
		}
	}
}

public void OnPluginEnd()
{
	ServerCommand("bot_kick all");
	ServerCommand("bot_quota 0");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	if(!late)
	{
		CreateNative("GetBotInfo", Native_GetBotInfo);
	
		RegPluginLibrary("ghost");
	}
	
	g_bLateLoaded = late;
	
	return APLRes_Success;
}

public void OnStylesLoaded()
{
	char sTypeAbbr[8], sType[16], sStyleAbbr[8], sStyle[16], sTypeStyleAbbr[24], sCvar[32], sDesc[128];
	Style s;
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		GetTypeName(Type, sType, sizeof(sType));
		GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr));
		
		for(int style; style < MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			// Don't create cvars for styles on bonus except normal style
			if(s.GetUseGhost(Type))
			{
				s.GetName(sStyle, sizeof(sStyle));
				s.GetNameShort(sStyleAbbr, sizeof(sStyleAbbr));
				
				Format(g_sGhost[Type][style], sizeof(g_sGhost[][]), "%s %s", sType, sStyle);
				
				Format(sTypeStyleAbbr, sizeof(sTypeStyleAbbr), "%s%s", sTypeAbbr, sStyleAbbr);
				StringToUpper(sTypeStyleAbbr);
				
				Format(sCvar, sizeof(sCvar), "timer_ghostweapon_%s%s", sTypeAbbr, sStyleAbbr);
				Format(sDesc, sizeof(sDesc), "The weapon the replay bot will always use (%s style on %s timer)", sStyle, sType);
				g_hGhostWeapon[Type][style] = CreateConVar(sCvar, "weapon_glock", sDesc);
				
				Format(sCvar, sizeof(sCvar), "timer_dontshoot_%s%s", sTypeAbbr, sStyleAbbr);
				Format(sDesc, sizeof(sDesc), "Forces the replay bot to never shoot during runs (%s style on %s timer)", sStyle, sType);
				g_hGhostDontShoot[Type][style] = CreateConVar(sCvar, "1", sDesc, 0, true, 0.0, true, 1.0);
				
				HookConVarChange(g_hGhostWeapon[Type][style], OnGhostWeaponChanged);
				
				g_hGhost[Type][style] = new ArrayList(6);
			}
		}
	}
}

public int Native_GetBotInfo(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(!IsFakeClient(client))
		return false;
	
	Style s;
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			if(s.GetUseGhost(Type))
			{
				if(g_Ghost[Type][style] == client)
				{
					SetNativeCellRef(2, Type);
					SetNativeCellRef(3, style);
					
					return true;
				}
			}
		}
	}
	
	return false;
}

public void OnMapStart()
{
	char sType[32], sStyle[32];
	Style s;
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			if(s.GetUseGhost(Type))
			{
				ClearArray(g_hGhost[Type][style]);
				g_Ghost[Type][style]         = 0;
				g_fGhostTime[Type][style]    = 0.0;
				g_GhostFrame[Type][style]    = 0;
				g_GhostPlayerID[Type][style] = 0;
				g_bGhostLoaded[Type][style]  = false;
				GetTypeName(Type, sType, sizeof(sType));
				s.GetName(sStyle, sizeof(sStyle));
				FormatEx(g_sGhost[Type][style], sizeof(g_sGhost[][]), "%s %s", sType, sStyle);
				FormatEx(g_sGhostClanTag[Type][style], sizeof(g_sGhostClanTag[][]), "");
			}
		}
	}
	
	// Get map name to use the database
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	// Check path to folder that holds all the ghost data
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes");
	if(!DirExists(sPath))
	{
		// Create ghost data directory if it doesn't exist
		CreateDirectory(sPath, 511);
	}
	
	// Timer to check ghost things such as clan tag
	CreateTimer(0.1, GhostCheck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	if(IsPlayerIDListLoaded())
	{
		LoadGhost();
	}
	
	g_bHasMapStarted = true;
}

public void OnMapEnd()
{
	// Remove ghost to get a clean start next map
	ServerCommand("bot_kick all");
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			g_Ghost[Type][style] = 0;
		}
	}
	
	g_bHasMapStarted = false;
}

public void OnPlayerIDListLoaded()
{
	if(g_bHasMapStarted == true)
	{
		LoadGhost();
	}
}

public void OnConfigsExecuted()
{
	CalculateBotQuota();
}

public void OnUseGhostChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	CalculateBotQuota();
}

public void OnGhostWeaponChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	Style s;
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			if(0 < g_Ghost[Type][style] <= MaxClients && s.GetUseGhost(Type))
			{
				if(g_hGhostWeapon[Type][style] == convar)
				{
					CheckWeapons(Type, style);
				}
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	{
		SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
	}
	else
	{
		// Reset player recorded movement
		if(g_bUsedFrame[client] == false)
		{
			g_hFrame[client]     = new ArrayList(6);
			g_bUsedFrame[client] = true;
		}
		else
		{
			g_hFrame[client].Clear();
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "trigger_", false) != -1)
	{
		SDKHook(entity, SDKHook_StartTouch, OnTrigger);
		SDKHook(entity, SDKHook_EndTouch, OnTrigger);
		SDKHook(entity, SDKHook_Touch, OnTrigger);
	}
}
 
public Action OnTrigger(int entity, int other)
{
	if(0 < other <= MaxClients)
	{
		if(IsClientConnected(other))
		{
			if(IsFakeClient(other))
			{
				return Plugin_Handled;
			}
		}
	}
   
	return Plugin_Continue;
}

public void OnPlayerIDLoaded(int client)
{
	int PlayerID = GetPlayerID(client);
	
	Style s;
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			if(s.GetUseGhost(Type))
			{
				if(PlayerID == g_GhostPlayerID[Type][style])
				{
					if(0 < g_Ghost[Type][style] <= MaxClients)
					{
						char sName[20];
						GetClientName(client, sName, sizeof(sName));
						CS_SetClientClanTag(g_Ghost[Type][style], sName);
					}
				}
			}
		}
	}
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	// Find out if it's the bot added from another time
	if(IsFakeClient(client) && !IsClientSourceTV(client))
	{
		Style s;
		for(int Type; Type < MAX_TYPES; Type++)
		{
			for(int style; style < MAX_STYLES; style++)
			{
				if(g_Ghost[Type][style] == 0)
				{
					GetStyleConfig(style, s);
					if(s.GetUseGhost(Type))
					{
						g_Ghost[Type][style] = client;
						
						return true;
					}
				}
			}
		}
	}
	return true;
}

public void OnClientDisconnect(int client)
{
	// Prevent players from becoming the ghost.
	if(IsFakeClient(client))
	{
		Style s;
		for(int Type; Type < MAX_TYPES; Type++)
		{
			for(int style; style < MAX_STYLES; style++)
			{
				GetStyleConfig(style, s);
				if(s.GetUseGhost(Type))
				{
					if(client == g_Ghost[Type][style])
					{
						g_Ghost[Type][style] = 0;
						break;
					}
				}
			}
		}
	}
}

public void OnTimesDeleted(int Type, int style, int RecordOne, int RecordTwo, ArrayList Times)
{
	int iSize = GetArraySize(Times);
	if(RecordTwo <= iSize)
	{
		for(int idx = RecordOne - 1; idx < RecordTwo; idx++)
		{
			if(GetArrayCell(Times, idx) == g_GhostPlayerID[Type][style])
			{
				DeleteGhost(Type, style);
				break;
			}
		}
	}
}

public Action Event_PlayerChangeName(Event event, char[] name, bool dontBroadcast)
{
	int PlayerId = GetPlayerID(GetClientOfUserId(event.GetInt("userid")));
	
	if(PlayerId != 0)
	{
		for(int Type; Type < MAX_TYPES; Type++)
		{
			for(int style; style < MAX_STYLES; style++)
			{
				if(g_GhostPlayerID[Type][style] == PlayerId)
				{
					event.GetString("newname", g_sGhostClanTag[Type][style], sizeof(g_sGhostClanTag[][]));
				}
			}
		}
	}
}

public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsFakeClient(client))
	{
		Style s;
		for(int Type; Type < MAX_TYPES; Type++)
		{
			for(int style; style < MAX_STYLES; style++)
			{
				GetStyleConfig(style, s);
				if(s.GetUseGhost(Type))
				{
					if(g_Ghost[Type][style] == client)
					{
						CreateTimer(0.1, Timer_CheckWeapons, client);
					}
				}
			}
		}
	}
}

public Action Timer_CheckWeapons(Handle timer, any client)
{
	Style s;
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			if(s.GetUseGhost(Type))
			{
				if(g_Ghost[Type][style] == client)
				{
					CheckWeapons(Type, style);
				}
			}
		}
	}
}

void CheckWeapons(int Type, int style)
{
	for(int i; i < 8; i++)
	{
		FakeClientCommand(g_Ghost[Type][style], "drop");
	}
	
	char sWeapon[32];
	GetConVarString(g_hGhostWeapon[Type][style], sWeapon, sizeof(sWeapon));
	
	g_bNewWeapon = true;
	GivePlayerItem(g_Ghost[Type][style], sWeapon);
}

public Action SM_DeleteGhost(int client, int args)
{
	OpenDeleteGhostMenu(client);
	
	return Plugin_Handled;
}

void OpenDeleteGhostMenu(int client)
{
	Menu menu = CreateMenu(Menu_DeleteGhost);
	
	menu.SetTitle("Select ghost to delete");
	
	char sDisplay[64], sType[32], sStyle[32], sInfo[8];
	Style s;
	
	for(int Type; Type < MAX_TYPES; Type++)
	{
		GetTypeName(Type, sType, sizeof(sType));
		
		for(int style; style < MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			if(s.GetUseGhost(Type))
			{
				s.GetName(sStyle, sizeof(sStyle));
				FormatEx(sDisplay, sizeof(sDisplay), "%s (%s)", sType, sStyle);
				Format(sInfo, sizeof(sInfo), "%d;%d", Type, style);
				menu.AddItem(sInfo, sDisplay);
			}
		}
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_DeleteGhost(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16], sTypeStyle[2][8];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrContains(info, ";") != -1)
		{
			ExplodeString(info, ";", sTypeStyle, 2, 8);
			
			DeleteGhost(StringToInt(sTypeStyle[0]), StringToInt(sTypeStyle[1]));
			
			LogMessage("%L deleted the ghost", param1);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}

public Action GhostCheck(Handle timer, any data)
{
	ConVar hBotQuota = FindConVar("bot_quota");
	int iBotQuota = hBotQuota.IntValue;
	
	if(iBotQuota != g_iBotQuota)
		ServerCommand("bot_quota %d", g_iBotQuota);
	
	delete hBotQuota;
	
	Style s;
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			if(s.GetUseGhost(Type))
			{
				if(g_Ghost[Type][style] != 0)
				{
					if(IsClientInGame(g_Ghost[Type][style]))
					{
						// Check clan tag
						char sClanTag[MAX_NAME_LENGTH];
						CS_GetClientClanTag(g_Ghost[Type][style], sClanTag, sizeof(sClanTag));
						
						if(!StrEqual(g_sGhostClanTag[Type][style], sClanTag))
						{
							CS_SetClientClanTag(g_Ghost[Type][style], g_sGhostClanTag[Type][style]);
						}
						
						// Check name
						if(strlen(g_sGhost[Type][style]) > 0)
						{
							
							char sGhostname[48];
							GetClientName(g_Ghost[Type][style], sGhostname, sizeof(sGhostname));
							if(!StrEqual(sGhostname, g_sGhost[Type][style]))
							{
								//SetClientInfo(g_Ghost[Type][style], "name", g_sGhost[Type][style]);
								CS_SetClientName(g_Ghost[Type][style], g_sGhost[Type][style]);
							}
						}
						
						// Check if ghost is dead
						if(!IsPlayerAlive(g_Ghost[Type][style]))
						{
							CS_RespawnPlayer(g_Ghost[Type][style]);
						}
						
						// Display ghost's current time to spectators
						int iSize = GetArraySize(g_hGhost[Type][style]);
						for(int client = 1; client <= MaxClients; client++)
						{
							if(IsClientInGame(client))
							{
								if(!IsPlayerAlive(client))
								{
									int target 	 = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
									int observerMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
									
									if(target == g_Ghost[Type][style] && (observerMode == 4 || observerMode == 5))
									{
										if(!g_GhostPaused[Type][style] && (0 < g_GhostFrame[Type][style] < iSize))
										{
											float time = GetEngineTime() - g_fStartTime[Type][style];
											char sTime[32];
											FormatPlayerTime(time, sTime, sizeof(sTime), false, 0);
											PrintHintText(client, "Replay\n%s", sTime);
										}
									}
								}
							}
						}
						
						int weaponIndex = GetEntPropEnt(g_Ghost[Type][style], Prop_Send, "m_hActiveWeapon");
						
						if(weaponIndex != -1)
						{
							int ammo = Weapon_GetPrimaryClip(weaponIndex);
							
							if(ammo < 1)
								Weapon_SetPrimaryClip(weaponIndex, 9999);
						}
					}
				}
			}
		}
	}
}

public Action Hook_WeaponCanUse(int client, int weapon)
{
	if(g_bNewWeapon == false)
		return Plugin_Handled;
	
	g_bNewWeapon = false;
	
	return Plugin_Continue;
}

void CalculateBotQuota()
{
	g_iBotQuota = 0;
	
	char sJoinCommand[32];
	GetConVarString(g_hGhostJoinCommand, sJoinCommand, sizeof(sJoinCommand));
	
	Style s;
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style<MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			if(s.GetUseGhost(Type))
			{
				g_iBotQuota++;
				
				if(!g_Ghost[Type][style])
				{
					ServerCommand(sJoinCommand);
				}
				//g_Ghost[Type][style] = CreateFakeClient(g_sGhost[Type][style]);
			}
			else if(g_Ghost[Type][style])
				KickClient(g_Ghost[Type][style]);
		}
	}
	
	ConVar hBotQuota = FindConVar("bot_quota");
	int iBotQuota = hBotQuota.IntValue;
	
	if(iBotQuota != g_iBotQuota)
		ServerCommand("bot_quota %d", g_iBotQuota);
	
	delete hBotQuota;
}

void LoadGhost()
{
	// Rename old version files
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s.rec", g_sMapName);
	if(FileExists(sPath))
	{
		char sPathTwo[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPathTwo, sizeof(sPathTwo), "data/btimes/%s_0_0.rec", g_sMapName);
		RenameFile(sPathTwo, sPath);
	}
	
	Style s;
	for(int Type; Type < MAX_TYPES; Type++)
	{
		for(int style; style < MAX_STYLES; style++)
		{
			GetStyleConfig(style, s);
			if(s.GetUseGhost(Type))
			{
				g_fGhostTime[Type][style]    = 0.0;
				g_GhostPlayerID[Type][style] = 0;
				
				BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, style);
				
				if(FileExists(sPath))
				{
					// Open file for reading
					File file = OpenFile(sPath, "r");
					
					// Load all data into the ghost handle
					char line[512], expLine[6][64], expLine2[2][10];
					int iSize;
					
					// Read first line for player and time information
					file.ReadLine(line, sizeof(line));
					
					// Decode line into needed information
					ExplodeString(line, "|", expLine2, 2, 10);
					g_GhostPlayerID[Type][style] = StringToInt(expLine2[0]);
					GetNameFromPlayerID(g_GhostPlayerID[Type][style], g_sGhostClanTag[Type][style], sizeof(g_sGhostClanTag[][]));
					
					g_fGhostTime[Type][style] = StringToFloat(expLine2[1]);
					
					// Read rest of file
					while(!file.EndOfFile())
					{
						file.ReadLine(line, sizeof(line));
						ExplodeString(line, "|", expLine, 6, 64);
						
						iSize = g_hGhost[Type][style].Length + 1;
						
						ResizeArray(g_hGhost[Type][style], iSize);
						SetArrayCell(g_hGhost[Type][style], iSize - 1, StringToFloat(expLine[0]), 0);
						SetArrayCell(g_hGhost[Type][style], iSize - 1, StringToFloat(expLine[1]), 1);
						SetArrayCell(g_hGhost[Type][style], iSize - 1, StringToFloat(expLine[2]), 2);
						SetArrayCell(g_hGhost[Type][style], iSize - 1, StringToFloat(expLine[3]), 3);
						SetArrayCell(g_hGhost[Type][style], iSize - 1, StringToFloat(expLine[4]), 4);
						SetArrayCell(g_hGhost[Type][style], iSize - 1, StringToInt(expLine[5]), 5);
					}
					delete file;
					
					g_bGhostLoadedOnce[Type][style] = true;
				}
				
				g_bGhostLoaded[Type][style] = true;
			}
		}
	}
}

public void OnTimerStart_Post(int client, int Type, int style)
{
	// Reset saved ghost data
	g_hFrame[client].Clear();
}

public void OnTimerFinished_Post(int client, float Time, int Type, int style, bool NewTime, int OldPosition, int NewPosition)
{
	if(g_bGhostLoaded[Type][style] == true)
	{
		Style s;
		GetStyleConfig(style, s);
		if(s.GetSaveGhost(Type))
		{
			if(Time < g_fGhostTime[Type][style] || g_fGhostTime[Type][style] == 0.0)
			{
				SaveGhost(client, Time, Type, style);
			}
		}
	}
}

void SaveGhost(int client, float Time, int Type, int style)
{
	g_fGhostTime[Type][style] = Time;
	
	g_GhostPlayerID[Type][style] = GetPlayerID(client);
	CS_GetClientName(client, g_sGhostClanTag[Type][style], sizeof(g_sGhostClanTag[][]));
	
	// Delete existing ghost for the map
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, style);
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}
	
	// Open a file for writing
	File file = OpenFile(sPath, "w");
	
	// save playerid to file to grab name and time for later times map is played
	char playerid[16];
	IntToString(GetPlayerID(client), playerid, sizeof(playerid));
	WriteFileLine(file, "%d|%f", GetPlayerID(client), Time);
	
	int iSize = GetArraySize(g_hFrame[client]), buttons;
	char buffer[512];
	float data[5];
	
	g_hGhost[Type][style].Clear();
	for(int i; i < iSize; i++)
	{
		GetArrayArray(g_hFrame[client], i, data, 5);
		PushArrayArray(g_hGhost[Type][style], data, 5);
		
		buttons = GetArrayCell(g_hFrame[client], i, 5);
		SetArrayCell(g_hGhost[Type][style], i, buttons, 5);
		
		FormatEx(buffer, sizeof(buffer), "%f|%f|%f|%f|%f|%d", data[0], data[1], data[2], data[3], data[4], buttons);
		WriteFileLine(file, buffer);
	}
	delete file;
	
	g_GhostFrame[Type][style] = 0;
}

void DeleteGhost(int Type, int style)
{
	// delete map ghost file
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, style);
	if(FileExists(sPath))
		DeleteFile(sPath);
	
	// reset ghost
	if(g_Ghost[Type][style] != 0)
	{
		g_fGhostTime[Type][style] = 0.0;
		ClearArray(g_hGhost[Type][style]);
		if(Type == TIMER_MAIN)
			Timer_TeleportToZone(g_ReplayBot, MAIN_START, 0, true);
		else
			Timer_TeleportToZone(g_ReplayBot, BONUS_START, 0, true);
		
		FormatEx(g_ReplayBotTag[Type][style], sizeof(g_ReplayBotTag[][]), "");
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(IsPlayerAlive(client))
	{
		if(!IsFakeClient(client))
		{
			Style s;
			int Type  = GetClientTimerType(client);
			int style = GetClientStyle(client);
			GetStyleConfig(style, s);
			if(IsBeingTimed(client, TIMER_ANY) && !IsTimerPaused(client) && s.GetSaveGhost(Type))
			{
				// Record player movement data
				int iSize = GetArraySize(g_hFrame[client]);
				ResizeArray(g_hFrame[client], iSize + 1);
				
				float vPos[3], vAng[3];
				Entity_GetAbsOrigin(client, vPos);
				GetClientEyeAngles(client, vAng);
				
				SetArrayCell(g_hFrame[client], iSize, vPos[0], 0);
				SetArrayCell(g_hFrame[client], iSize, vPos[1], 1);
				SetArrayCell(g_hFrame[client], iSize, vPos[2], 2);
				SetArrayCell(g_hFrame[client], iSize, vAng[0], 3);
				SetArrayCell(g_hFrame[client], iSize, vAng[1], 4);
				SetArrayCell(g_hFrame[client], iSize, buttons, 5);
			}
		}
		else
		{
			Style s;
			for(int Type; Type < MAX_TYPES; Type++)
			{
				for(int style; style < MAX_STYLES; style++)
				{
					GetStyleConfig(style, s);
					
					if(s.GetUseGhost(Type))
					{
						if(client == g_Ghost[Type][style] && g_hGhost[Type][style] != INVALID_HANDLE)
						{
							int iSize = GetArraySize(g_hGhost[Type][style]);
							
							float vPos[3], vAng[3];
							if(g_GhostFrame[Type][style] == 0)
							{
								g_fStartTime[Type][style] = GetEngineTime();
								
								if(iSize > 0)
								{
									vPos[0] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 0);
									vPos[1] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 1);
									vPos[2] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 2);
									vAng[0] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 3);
									vAng[1] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 4);
									TeleportEntity(g_Ghost[Type][style], vPos, vAng, view_as<float>{0.0, 0.0, 0.0});
								}
								
								if(g_GhostPaused[Type][style] == false)
								{
									g_GhostPaused[Type][style] = true;
									g_fPauseTime[Type][style]  = GetEngineTime();
								}
								
								if(GetEngineTime() > g_fPauseTime[Type][style] + GetConVarFloat(g_hGhostStartPauseTime))
								{
									g_GhostPaused[Type][style] = false;
									g_GhostFrame[Type][style]++;
								}
							}
							else if(g_GhostFrame[Type][style] == (iSize - 1))
							{
								if(iSize > 0)
								{
									vPos[0] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 0);
									vPos[1] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 1);
									vPos[2] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 2);
									vAng[0] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 3);
									vAng[1] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 4);
									
									TeleportEntity(g_Ghost[Type][style], vPos, vAng, view_as<float>{0.0, 0.0, 0.0});
								}
								
								if(g_GhostPaused[Type][style] == false)
								{					
									g_GhostPaused[Type][style] = true;
									g_fPauseTime[Type][style]  = GetEngineTime();
								}
								
								if(GetEngineTime() > g_fPauseTime[Type][style] + GetConVarFloat(g_hGhostEndPauseTime))
								{
									g_GhostPaused[Type][style] = false;
									g_GhostFrame[Type][style]  = (g_GhostFrame[Type][style] + 1) % iSize;
								}
							}
							else if(g_GhostFrame[Type][style] < iSize)
							{
								float vPos2[3];
								Entity_GetAbsOrigin(client, vPos2);
								
								vPos[0] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 0);
								vPos[1] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 1);
								vPos[2] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 2);
								vAng[0] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 3);
								vAng[1] = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 4);
								buttons = GetArrayCell(g_hGhost[Type][style], g_GhostFrame[Type][style], 5);
								
								if(GetConVarBool(g_hGhostDontShoot[Type][style]))
								{
									buttons &= ~IN_ATTACK;
								}
								
								if(GetVectorDistance(vPos, vPos2) > 50.0)
								{
									TeleportEntity(g_Ghost[Type][style], vPos, vAng, NULL_VECTOR);
								}
								else
								{
									// Get the new velocity from the the 2 points
									float vVel[3];
									MakeVectorFromPoints(vPos2, vPos, vVel);
									ScaleVector(vVel, 128.0);
									
									//TeleportEntity(g_Ghost[Type][style], NULL_VECTOR, vAng, vVel);
									if(Type == 0 && style == 0)
									{
										TeleportEntity(g_Ghost[Type][style], NULL_VECTOR, view_as<float>{30.0, -70.0, 0.0}, view_as<float>{0.0, 0.0, 0.0});
									}
								}
								
								if(GetEntityFlags(g_Ghost[Type][style]) & FL_ONGROUND)
									SetEntityMoveType(g_Ghost[Type][style], MOVETYPE_WALK);
								else
									SetEntityMoveType(g_Ghost[Type][style], MOVETYPE_NOCLIP);
								
								g_GhostFrame[Type][style] = (g_GhostFrame[Type][style] + 1) % iSize;
							}
							
							if(g_GhostPaused[Type][style] == true)
							{
								if(GetEntityMoveType(g_Ghost[Type][style]) != MOVETYPE_NONE)
								{
									SetEntityMoveType(g_Ghost[Type][style], MOVETYPE_NONE);
								}
							}
						}
					}
				}
			}
		}
	}
	
	return Plugin_Changed;
}