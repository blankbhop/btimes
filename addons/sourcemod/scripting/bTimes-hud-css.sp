#include <sourcemod>
#include <sdktools>

#include <bTimes-timer>
#include <bTimes-zones>

#undef REQUIRE_PLUGIN
#include <bTimes-replay>
#include <bTimes-replay3>
#include <bTimes-rank2>
#include <bTimes-tas>

ConVar g_cHudRefreshSpeed;
ConVar g_cSendKeysAlive;

Handle g_hHintTextTimer;

bool g_bReplayLoaded;
bool g_bReplay3Loaded;
bool g_bTasLoaded;
bool g_bRank2Loaded;

bool g_bIsAdmin[MAXPLAYERS + 1];

// Cookies
Handle g_hVelCookie;
Handle g_hKeysCookie;

bool g_bLateLoad;

public void OnPluginStart()
{
	// Cvars
	g_cHudRefreshSpeed = CreateConVar("hud_refreshspeed", "0.1", "Changes how fast the HUD info refreshes.", 0, true, 0.1);
	g_cSendKeysAlive   = CreateConVar("hud_sendkeysalive", "1", "Send keys message to players that are alive");
	HookConVarChange(g_cHudRefreshSpeed, OnRefreshSpeedChanged);
	
	// Commands
	RegConsoleCmdEx("sm_truevel",  SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters.");
	RegConsoleCmdEx("sm_velocity", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters.");
	RegConsoleCmdEx("sm_keys",     SM_Keys,         "Shows the targeted player's movement keys on screen.");
	RegConsoleCmdEx("sm_showkeys", SM_Keys,         "Shows the targeted player's movement keys on screen.");
	RegConsoleCmdEx("sm_pad",      SM_Keys,         "Shows the targeted player's movement keys on screen.");
	
	// Cookies
	g_hVelCookie  = RegClientCookie("timer_truevel", "True velocity meter.", CookieAccess_Public);
	g_hKeysCookie = RegClientCookie("timer_keys",  "Show movement keys on screen.", CookieAccess_Public);
	SetCookiePrefabMenu(g_hVelCookie, CookieMenu_OnOff, "True velocity meter");
}

public void OnAllPluginsLoaded()
{
	g_bReplayLoaded = LibraryExists("replay");
	g_bReplay3Loaded = LibraryExists("replay3");
	g_bTasLoaded    = LibraryExists("tas");
	g_bRank2Loaded  = LibraryExists("ranks");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_CSS)
	{
		FormatEx(error, err_max, "The plugin only works on CS:S");
		return APLRes_Failure;
	}
	
	if(late)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && IsClientAuthorized(client))
			{
				OnClientPostAdminCheck(client);
			}
		}
	}
	
	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "replay"))
	{
		g_bReplayLoaded = true;
	}
	if(StrEqual(name, "replay3"))
	{
		g_bReplay3Loaded = true;
	}
	else if(StrEqual(name, "tas"))
	{
		g_bTasLoaded = true;
	}
	else if(StrEqual(name, "ranks"))
	{
		g_bRank2Loaded = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "replay"))
	{
		g_bReplayLoaded = false;
	}
	if(StrEqual(name, "replay3"))
	{
		g_bReplay3Loaded = false;
	}
	else if(StrEqual(name, "tas"))
	{
		g_bTasLoaded = false;
	}
	else if(StrEqual(name, "ranks"))
	{
		g_bRank2Loaded = false;
	}
}

public void OnConfigsExecuted()
{
	g_hHintTextTimer = CreateTimer(g_cHudRefreshSpeed.FloatValue, Timer_DrawHintText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientCookiesCached(int client)
{
	char sCookie[32];
	GetClientCookie(client, g_hVelCookie, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetCookieBool(client, g_hVelCookie, true);
	}
}

public void OnClientPostAdminCheck(int client)
{
	AdminFlag flag = Admin_Generic;
	Timer_GetAdminFlag("basic", flag);
	g_bIsAdmin[client] = GetAdminFlag(GetUserAdmin(client), flag, Access_Effective);
}

public void OnRefreshSpeedChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(g_hHintTextTimer != INVALID_HANDLE)
	{
		CloseHandle(g_hHintTextTimer);
		g_hHintTextTimer = INVALID_HANDLE;
	}
	
	g_hHintTextTimer = CreateTimer(StringToFloat(newValue), Timer_DrawHintText, _, TIMER_REPEAT);
}

public Action Timer_DrawHintText(Handle timer, any data)
{
	int[] normalSpecCount = new int[MaxClients + 1];
	int[] adminSpecCount  = new int[MaxClients + 1];
	SpecCountToArrays(normalSpecCount, adminSpecCount);
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;
			
		if(IsFakeClient(client))
			continue;
		
		int target;
		if(IsPlayerAlive(client))
		{
			target = client;
		}
		else
		{
			int ObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			int ObserverMode   = GetEntProp(client, Prop_Send, "m_iObserverMode");
			
			if((0 < ObserverTarget <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5 || ObserverMode == 6))
				target = ObserverTarget;
			else
				continue;
		}
		
		ShowHintTextMessage(client, target);
		ShowKeyHintTextMessage(client, target, normalSpecCount, adminSpecCount);
		ShowHudSyncMessage(client, target);
	}
}

/* HINT */
void ShowHintTextMessage(int client, int target)
{
	int iVel = RoundToFloor(GetClientVelocity(target, true, true, !GetCookieBool(client, g_hVelCookie)));
	int bot;
	
	if((g_bReplayLoaded == true && Replay_IsClientReplayBot(target)) || (g_bReplay3Loaded == true && (bot = Replay_GetReplayBot(target)) != -1))
	{
		int type, style, tas;
		bool isReplaying;
		float fTime;
		char sName[MAX_NAME_LENGTH];
		
		if(g_bReplayLoaded == true)
		{
			if(Replay_IsReplaying() == true)
			{
				type  = Replay_GetCurrentReplayType(); 
				style = Replay_GetCurrentReplayStyle();
				tas   = view_as<int>(Replay_GetCurrentReplayTAS());
				fTime = Replay_GetCurrentTimeInRun();
				Replay_GetPlayerName(type, style, tas, sName, sizeof(sName));
				isReplaying = true;
			}
		}
		else if(g_bReplay3Loaded == true)
		{
			if(Replay_IsBotReplaying(bot) == true)
			{
				type  = Replay_GetBotRunType(bot);
				style = Replay_GetBotRunStyle(bot);
				tas   = Replay_GetBotRunTAS(bot);
				fTime = Replay_GetBotRunTime(bot);
				Replay_GetBotPlayerName(bot, sName, sizeof(sName));
				isReplaying = true;
			}
		}
		
		if(isReplaying)
		{
			char sTime[32];
			FormatPlayerTime(fTime, sTime, sizeof(sTime), 0);
			
			char sDisplay[128];
			FormatEx(sDisplay, sizeof(sDisplay), "[Replay]\n%s\n%s\nSpeed: %d",
				sName, sTime, iVel);
				
			PrintHintText(client, sDisplay);
		}
		else
		{
			// Tell the spectating player that they can use the !replay command
			PrintHintText(client, "Type !replay");
		}
	}
	else if(Timer_InsideZone(target, MAIN_START) != -1 || Timer_InsideZone(target, BONUS_START) != -1)
	{ 
		// Tell the player they are in the start zone
		char sRank[32];
		if(g_bRank2Loaded == true && Ranks_IsClientRankLoaded(target) && Ranks_IsClientRankedOverall(target))
		{
			FormatEx(sRank, sizeof(sRank), "\nRank: %d/%d", Ranks_GetClientOverallRank(target), Ranks_GetTotalOverallRanks());
		}
		else
		{
			sRank[0] = '\0';
		}
		PrintHintText(client, "Start Zone\nSpeed: %d%s", iVel, sRank);
	}
	else if(IsBeingTimed(target, TIMER_ANY)) // Show the player the run data
	{
		char sTime[64];
		float fTime = TimerInfo(target).CurrentTime;
		FormatPlayerTime(fTime, sTime, sizeof(sTime), 0);
		if(!IsTimerPaused(target))
		{
			int style = TimerInfo(target).ActiveStyle;
			char sStrafes[32];
			if(Style(style).ShowStrafesOnHud)
			{
				FormatEx(sStrafes, sizeof(sStrafes), "\nStrafes: %d", TimerInfo(target).Strafes);
			}
			else
			{
				sStrafes[0] = '\0';
			}
			
			char sSync[32];
			if(Style(style).CalculateSync)
			{
				FormatEx(sSync, sizeof(sSync), "\nSync: %.1f％", TimerInfo(target).Sync);
			}
			else
			{
				sSync[0] = '\0';
			}
			
			PrintHintText(client, "Time: %s\nJumps: %d%s%s\nSpeed: %d",
				sTime,
				TimerInfo(target).Jumps,
				sStrafes,
				sSync,
				iVel);
		}
		else
		{
			PrintHintText(client, "Paused\n\n%s", sTime);
		}
	}
	else
	{
		// Show no timer data
		PrintHintText(client, "Speed: %d", iVel);
	}
}

/* KEY HINT */
void ShowKeyHintTextMessage(int client, int target, int[] normalSpecCount, int[] adminSpecCount)
{
	char sKeyHintMessage[256];
	int timeLimit;
	GetMapTimeLimit(timeLimit);
	if(timeLimit != 0)
	{
		int timeLeft;
		GetMapTimeLeft(timeLeft);
		
		if(timeLeft <= 0)
		{
			FormatEx(sKeyHintMessage, sizeof(sKeyHintMessage), "Time left: Map finished\n");
		}
		else if(timeLeft < 60)
		{
			FormatEx(sKeyHintMessage, sizeof(sKeyHintMessage), "Time left: %ds\n", timeLeft);
		}
		else if(timeLeft > 3600)
		{
			int tempTimeLeft = timeLeft;
			int hours = RoundToFloor(float(tempTimeLeft)/3600);
			tempTimeLeft -= hours * 3600;
			int minutes = RoundToFloor(float(tempTimeLeft)/60);
			FormatEx(sKeyHintMessage, sizeof(sKeyHintMessage), "Time left: %dh %dm\n", hours, minutes);
		}
		else
		{
			// Format the time left
			int minutes = RoundToFloor(float(timeLeft)/60);
			FormatEx(sKeyHintMessage, sizeof(sKeyHintMessage), "Time left: %dm\n", minutes);
		}
	}
	
	Format(sKeyHintMessage, sizeof(sKeyHintMessage), "%sSpecs: %d", sKeyHintMessage, g_bIsAdmin[client]?adminSpecCount[target]:normalSpecCount[target]);

	PrintKeyHintText(client, sKeyHintMessage);
}

/* HUD SYNCHRONIZER */
void ShowHudSyncMessage(int client, int target)
{
	bool bShowMessage;
	char sSyncMessage[256], sWorldRecord[128], sName[MAX_NAME_LENGTH];
	int bot;
	
	if((g_bReplayLoaded == true && Replay_IsClientReplayBot(target)) || (g_bReplay3Loaded == true && (bot = Replay_GetReplayBot(target)) != -1))
	{
		int type, style, tas;
		bool isReplaying;
		
		if(g_bReplayLoaded == true)
		{
			if(Replay_IsReplaying() == true)
			{
				type  = Replay_GetCurrentReplayType(); 
				style = Replay_GetCurrentReplayStyle();
				tas   = view_as<int>(Replay_GetCurrentReplayTAS());
				Replay_GetPlayerName(type, style, tas, sName, sizeof(sName));
				isReplaying = true;
			}
		}
		else if(g_bReplay3Loaded == true)
		{
			if(Replay_IsBotReplaying(bot) == true)
			{
				type  = Replay_GetBotRunType(bot);
				style = Replay_GetBotRunStyle(bot);
				tas   = Replay_GetBotRunTAS(bot);
				Replay_GetBotPlayerName(bot, sName, sizeof(sName));
				isReplaying = true;
			}
		}
		
		if(isReplaying)
		{
			// World record display
			FormatPlayerTime(Timer_GetTimeAtPosition(type, style, tas, 0), sWorldRecord, sizeof(sWorldRecord), 1);
			Timer_GetNameAtPosition(type, style, tas, 0, sName, MAX_NAME_LENGTH);
			Format(sWorldRecord, sizeof(sWorldRecord), "WR: %s (%s)", sWorldRecord, sName);
			
			FormatEx(sSyncMessage, sizeof(sSyncMessage), sWorldRecord);
			bShowMessage = true;
		}
	}
	else
	{
		char sPersonalBest[128], sStyle[128];
		int Type  = TimerInfo(target).Type;
		int style = TimerInfo(target).ActiveStyle;
		int tas   = (g_bTasLoaded && TAS_InEditMode(target))?1:0;
		
		// World record display
		if(Timer_GetTimesCount(Type, style, tas) > 0)
		{
			FormatPlayerTime(Timer_GetTimeAtPosition(Type, style, tas, 0), sWorldRecord, sizeof(sWorldRecord), 1);
			Timer_GetNameAtPosition(Type, style, tas, 0, sName, MAX_NAME_LENGTH);
			Format(sWorldRecord, sizeof(sWorldRecord), "WR: %s (%s)\n", sWorldRecord, sName);
		}
		else
		{
			FormatEx(sWorldRecord, sizeof(sWorldRecord), "WR: N/A\n");
		}
		
		// Target personal best
		if(Timer_PlayerHasTime(target, Type, style, tas))
		{
			FormatPlayerTime(Timer_GetPersonalBest(target, Type, style, tas), sPersonalBest, sizeof(sPersonalBest), 1);
			Format(sPersonalBest, sizeof(sPersonalBest), "PB: %s\n", sPersonalBest);
		}
		else
		{
			FormatEx(sPersonalBest, sizeof(sPersonalBest), "PB: N/A\n");
		}
		
		
		// Style name
		Style(style).GetName(sStyle, sizeof(sStyle));
		Format(sStyle, sizeof(sStyle), "Style: %s", sStyle);
		
		if(Type == TIMER_BONUS)
		{
			Format(sStyle, sizeof(sStyle), "%s (Bonus)", sStyle);
		}
		
		if(tas == 1)
		{
			Format(sStyle, sizeof(sStyle), "%s (TAS)", sStyle);
		}
		
		// Aggregate strings
		FormatEx(sSyncMessage, sizeof(sSyncMessage), "%s%s%s", sWorldRecord, sPersonalBest, sStyle);
		bShowMessage = true;
	}
	
	if(bShowMessage == true)
	{
		Handle hText = CreateHudSynchronizer();
		if(hText != INVALID_HANDLE)
		{
			SetHudTextParams(0.005, 0.0, g_cHudRefreshSpeed.FloatValue, 255, 255, 255, 255);
			ShowSyncHudText(client, hText, sSyncMessage);
			CloseHandle(hText);
		}
	}
}

void PrintKeyHintText(client, char[] message)
{
	Handle hMessage = StartMessageOne("KeyHintText", client);
	if (hMessage != INVALID_HANDLE) 
	{ 
		BfWriteByte(hMessage, 1); 
		BfWriteString(hMessage, message);
	}
	EndMessage();
}

void SpecCountToArrays(int[] clients, int[] admins)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(!IsPlayerAlive(client))
			{
				int Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				int ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
				if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5 || ObserverMode == 6))
				{
					if(g_bIsAdmin[client] == false)
						clients[Target]++;
					admins[Target]++;
				}
			}
		}
	}
}

// Toggles between 2d vector and 3d vector velocity
public Action SM_TrueVelocity(int client, int args)
{	
	SetCookieBool(client, g_hVelCookie, !GetCookieBool(client, g_hVelCookie));
	
	if(GetCookieBool(client, g_hVelCookie))
	{
		PrintColorText(client, "%s%sShowing %strue %svelocity",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%sShowing %snormal %svelocity",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action SM_Keys(int client, int args)
{	
	SetCookieBool(client, g_hKeysCookie, !GetCookieBool(client, g_hKeysCookie));
	
	if(GetCookieBool(client, g_hKeysCookie))
	{
		PrintColorText(client, "%s%sShowing movement keys",
			g_msg_start,
			g_msg_textcol);
	}
	else
	{
		PrintCenterText(client, "");
		PrintColorText(client, "%s%sNo longer showing movement keys",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

float g_fOldAngle[MAXPLAYERS + 1];
bool  g_bHadTarget[MAXPLAYERS + 1];
void SendKeysMessage(int client)
{
	if(GetCookieBool(client, g_hKeysCookie) == false)
	{
		return;
	}
	
	if((GetConVarBool(g_cSendKeysAlive) && IsPlayerAlive(client)) || !IsPlayerAlive(client))
	{
		int target;
		if(IsPlayerAlive(client))
		{
			target = client;
		}
		else
		{
			int obTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			int obMode   = GetEntProp(client, Prop_Send, "m_iObserverMode");
			
			if((0 < obTarget <= MaxClients) && (obMode == 4 || obMode == 5 || obMode == 6))
			{
				target = obTarget;
			}
			else
			{
				if(g_bHadTarget[client] == true)
				{
					PrintCenterText(client, "");
					g_bHadTarget[client] = false;
				}
				return;
			}
		}
		
		g_bHadTarget[client] = true;
		
		float fAng[3];
		GetClientEyeAngles(target, fAng);
	
		int buttons = GetClientButtons(target);
		
		char sForward[1], sBack[1], sMoveleft[2], sMoveright[2];
		char sTurnLeft[8], sTurnRight[8];
		char sKeys[128];
		
		if(buttons & IN_FORWARD)
			sForward[0] = 'W';
		else
			sForward[0] = 32;
			
		if(buttons & IN_MOVELEFT)
		{
			sMoveleft[0] = 'A';
			sMoveleft[1] = 0;
		}
		else
		{
			sMoveleft[0] = 32;
			sMoveleft[1] = 32;
		}
		
		if(buttons & IN_MOVERIGHT)
		{
			sMoveright[0] = 'D';
			sMoveright[1] = 0;
		}
		else
		{
			sMoveright[0] = 32;
			sMoveright[1] = 32;
		}
		
		float fAngleDiff = fAng[1] - g_fOldAngle[target];
		if (fAngleDiff > 180)
			fAngleDiff -= 360;
		else if(fAngleDiff < -180)
			fAngleDiff += 360;
			
		g_fOldAngle[target] = fAng[1];
		if(fAngleDiff > 0)
		{
			FormatEx(sTurnLeft, sizeof(sTurnLeft), "←");
		}
		else
		{
			FormatEx(sTurnLeft, sizeof(sTurnLeft), "    ");
		}
		
		if(fAngleDiff < 0)
		{
			FormatEx(sTurnRight, sizeof(sTurnRight), "→");
		}
		else
		{
			FormatEx(sTurnRight, sizeof(sTurnRight), "    ");
		}
		
		if(buttons & IN_BACK)
			sBack[0] = 'S';
		else
			sBack[0] = 32;
		
		Format(sKeys, sizeof(sKeys), "       %s\n%s%s     %s%s\n        %s", sForward, sTurnLeft, sMoveleft, sMoveright, sTurnRight, sBack);
		
		if(buttons & IN_DUCK)
		{
			Format(sKeys, sizeof(sKeys), "%s\n    DUCK", sKeys);
		}
		else
		{
			Format(sKeys, sizeof(sKeys), "%s\n ", sKeys);
		}
		
		if(buttons & IN_JUMP)
		{
			Format(sKeys, sizeof(sKeys), "%s\n    JUMP", sKeys);
		}
		
		PrintCenterText(client, sKeys);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	SendKeysMessage(client);
}