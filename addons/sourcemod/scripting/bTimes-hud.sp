#include <sourcemod>
#include <sdkhooks>
#include <bTimes-core>
#include <bTimes-zones>
#include <bTimes-timer>
#include <sdktools>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#include <bTimes-replay>
#include <bTimes-replay3>
#include <bTimes-tas>
	
bool g_bIsAdmin[MAXPLAYERS + 1];

int g_CurrentValue[3];
int g_ExpectedValue[3];
int g_FadeSpeed;

Handle g_hVelCookie;

ConVar g_cFadeSpeed;
ConVar g_cHudSyncPos[2];
ConVar g_cHudSyncEnable;

bool g_bReplayLoaded;
bool g_bReplay3Loaded;
bool g_bTasLoaded;
bool g_bLateLoad;

//space is 70
// fuck yes
int g_charWidth[128] = {200, 200, 200, 200, 200, 200, 200, 200, 200, 0, 0, 200, 200, 
0, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 
200, 60, 79, 92, 164, 127, 215, 145, 54, 91, 91, 127, 164, 73, 91, 73, 91, 127, 
127, 127, 127, 127, 127, 127, 127, 127, 127, 91, 91, 164, 164, 164,109, 200, 137, 137, 
140, 154, 126, 115, 155, 150, 83, 91, 139, 111, 169, 150, 157, 121, 157, 139, 137, 
123, 146, 137, 198, 137, 123, 137, 91, 91, 91, 164, 127,127, 120, 125, 104, 125, 119, 70, 
125, 127, 54, 69, 118, 54, 195, 127, 121, 125, 125, 85, 104, 79, 127, 118, 164, 
118, 118, 105, 127, 91, 127, 164, 200};

public Plugin:myinfo = 
{
	name = "[Timer] - HUD",
	author = "blacky",
	description = "Displays the hint text to clients.",
	version = "1.0",
	url = "http://steamcommunity.com/id/blaackyy/"
}

public void OnPluginStart()
{
	RegConsoleCmdEx("sm_truevel",  SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters.");
	RegConsoleCmdEx("sm_velocity", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters.");

	g_cFadeSpeed = CreateConVar("hud_fadespeed", "20", "Changes how fast the HUD Start Zone message fades.", 0, true, 0.0, true, 255.0);
	g_cHudSyncPos[0] = CreateConVar("hud_syncpos_x", "0.005", "X Position of WR/PB/Style message", 0, true, 0.0, true, 1.0);
	g_cHudSyncPos[1] = CreateConVar("hud_syncpos_y", "0.0", "Y Position of WR/PB/Style message", 0, true, 0.0, true, 1.0);
	g_cHudSyncEnable = CreateConVar("hud_syncenable", "1", "Enable hud syncronizer message", 0, true, 0.0, true, 1.0);
	HookConVarChange(g_cFadeSpeed, OnFadeSpeedChanged);
	AutoExecConfig(true, "hud", "timer");
	
	g_hVelCookie  = RegClientCookie("timer_truevel", "True velocity meter.", CookieAccess_Public);
	SetCookiePrefabMenu(g_hVelCookie, CookieMenu_OnOff, "True velocity meter");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		FormatEx(error, err_max, "The plugin only works on CS:GO");
		return APLRes_Failure;
	}

	g_bLateLoad = late;
	
	if(late)
	{
		UpdateMessages();
	}
	
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bReplayLoaded  = LibraryExists("replay");
	g_bReplay3Loaded = LibraryExists("replay3");
	g_bTasLoaded     = LibraryExists("tas");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "replay"))
	{
		g_bReplayLoaded = true;
	}
	else if(StrEqual(name, "replay3"))
	{
		g_bReplay3Loaded = true;
	}
	else if(StrEqual(name, "tas"))
	{
		g_bTasLoaded = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "replay"))
	{
		g_bReplayLoaded = false;
	}
	else if(StrEqual(name, "replay3"))
	{
		g_bReplay3Loaded = false;
	}
	else if(StrEqual(name, "tas"))
	{
		g_bTasLoaded = false;
	}
}

public void OnConfigsExecuted()
{
	g_FadeSpeed = g_cFadeSpeed.IntValue;
}

public void OnFadeSpeedChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_FadeSpeed = convar.IntValue;
}

public void OnMapStart()
{
	if(g_bLateLoad)
	{
		AdminFlag flag = Admin_Generic;
		Timer_GetAdminFlag("basic", flag);
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && IsClientAuthorized(client))
			{
				g_bIsAdmin[client] = GetAdminFlag(GetUserAdmin(client), flag, Access_Effective);
			}
		}
	}

	CreateTimer(0.1, Timer_DrawHintText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(3.0, Timer_DrawSyncText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int client)
{
	g_bIsAdmin[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	AdminFlag flag = Admin_Generic;
	Timer_GetAdminFlag("basic", flag);
	g_bIsAdmin[client] = GetAdminFlag(GetUserAdmin(client), flag, Access_Effective);
}

public void OnClientCookiesCached(int client)
{
	char sCookie[32];
	GetClientCookie(client, g_hVelCookie, sCookie, sizeof(sCookie));
	if(strlen(sCookie) == 0)
	{
		SetClientCookie(client, g_hVelCookie, "1");
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

public Action Timer_DrawSyncText(Handle timer, any data)
{
	if(g_cHudSyncEnable.BoolValue)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(!IsClientInGame(client))
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
				
				if((0 < ObserverTarget <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
					target = ObserverTarget;
				else
					continue;
			}
			
			ShowSyncMessage(client, target);
		}
	}

}

public Action Timer_DrawHintText(Handle timer, any data)
{
	// Start Zone message color fading
	for(int idx; idx < 3; idx++)
	{
		if (g_ExpectedValue[idx] > g_CurrentValue[idx])
		{
			if(g_CurrentValue[idx] + g_FadeSpeed > g_ExpectedValue[idx])
				g_CurrentValue[idx] = g_ExpectedValue[idx];
			else
				g_CurrentValue[idx] += g_FadeSpeed;
		}
		 
		if (g_ExpectedValue[idx] < g_CurrentValue[idx])
		{
			if(g_CurrentValue[idx] - g_FadeSpeed < g_ExpectedValue[idx])
				g_CurrentValue[idx] = g_ExpectedValue[idx];
			else
				g_CurrentValue[idx] -= g_FadeSpeed;
		}

		if (g_ExpectedValue[idx] == g_CurrentValue[idx])
		{
			g_ExpectedValue[idx] = GetRandomInt(0, 255);
		}
	}
	
	char sHex[32];
	FormatEx(sHex, sizeof(sHex), "#%02X%02X%02X",
		g_CurrentValue[0],
		g_CurrentValue[1],
		g_CurrentValue[2]);
		
	int[] normalSpecCount = new int[MaxClients + 1];
	int[] adminSpecCount  = new int[MaxClients + 1];
	SpecCountToArrays(normalSpecCount, adminSpecCount);
	
	
	Style s;
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;
		
		char sStyle[128], sTime[256], sSpeed[128], sSpecs[64], sSync[64];
		int target;
		if(IsPlayerAlive(client))
		{
			target = client;
		}
		else
		{
			int ObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			int ObserverMode   = GetEntProp(client, Prop_Send, "m_iObserverMode");
			
			if((0 < ObserverTarget <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
				target = ObserverTarget;
			else
				continue;
		}
		
		bool cookiesCached = AreClientCookiesCached(client);
		
		int bot;
		if((g_bReplayLoaded == true && Replay_IsClientReplayBot(target)) || (g_bReplay3Loaded == true && (bot = Replay_GetReplayBot(target)) != -1))
		{
			int type, style, tas;
			float fTime;
			char sName[MAX_NAME_LENGTH];
			bool isReplaying;
			
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
			
			if(isReplaying == true)
			{
				char sType[32], sParseType[64], sParseStyle[64], sParseSpecs[64];
				GetTypeName(type, sType, sizeof(sType));
				Style(style).GetName(sStyle, sizeof(sStyle));
				FormatPlayerTime(fTime, sTime, sizeof(sTime), 0);
				FormatEx(sParseType, sizeof(sParseType), "Timer: %s", sType);
				
				char sTabs1[32];
				int width = GetStringWidth(sParseType);
				if(width < 1397)
					FormatEx(sTabs1, sizeof(sTabs1), "\t\t\t");
				else if(width < 2046)
					FormatEx(sTabs1, sizeof(sTabs1), "\t\t");
				else
					FormatEx(sTabs1, sizeof(sTabs1), "\t");
					
				FormatEx(sParseStyle, sizeof(sParseStyle), "Style: %s%s", sStyle, tas?" (TAS)":"");
				char sTabs2[32];
				width = GetStringWidth(sParseStyle);
				if(width < 1397)
					FormatEx(sTabs2, sizeof(sTabs2), "\t\t\t");
				else if(width < 2046)
					FormatEx(sTabs2, sizeof(sTabs2), "\t\t");
				else
					FormatEx(sTabs2, sizeof(sTabs2), "\t");
					
				FormatEx(sParseSpecs, sizeof(sParseSpecs), "Specs: %d", g_bIsAdmin[client]?adminSpecCount[target]:normalSpecCount[target]);
				char sTabsSpecs[32];
				width = GetStringWidth(sParseSpecs);
				if(width < 1397)
					FormatEx(sTabsSpecs, sizeof(sTabsSpecs), "\t\t\t");
				else if(width < 2046)
					FormatEx(sTabsSpecs, sizeof(sTabsSpecs), "\t\t");
				else
					FormatEx(sTabsSpecs, sizeof(sTabsSpecs), "\t");
				
				
				PrintHintText(client, "<font size=\"16\" face=\"verdana\">\
					<font color=\"%s\"><u>Replay Bot</u></font>\n\
					%s%sPlayer: %s\n\
					%s%sTime: <font color=\"#00FF00\">%s</font>\n\
					%s%sSpeed: %.0f</font>",
					sHex,
					sParseType,	sTabs1, sName,
					sParseStyle, sTabs2, sTime,
					sParseSpecs, sTabsSpecs, GetClientVelocity(target, true, true, cookiesCached?!GetCookieBool(client, g_hVelCookie):false));
					
			}
			else
			{
				PrintHintText(client, "<font size=\"20\" face=\"verdana\">\
					Press your <font color=\"%s\">+use</font> key to watch a record\
					</font>", sHex);
			}
			
			continue;
		}
		
		int type  = TimerInfo(target).Type;
		int style = TimerInfo(target).ActiveStyle;
		int tas = g_bTasLoaded?view_as<int>(TAS_InEditMode(target)):0;
		
		if(Timer_InsideZone(target, MAIN_START) != -1 || Timer_InsideZone(target, BONUS_START) != -1)
		{
			PrintHintText(client, "<font face=\"verdana\" size=\"43\" color=\"%s\">Start Zone</font>\nSpeed: %d\tSpecs: %d",
				sHex,
				RoundToFloor(GetClientVelocity(client, true, true, false)),
				g_bIsAdmin[client]?adminSpecCount[target]:normalSpecCount[target]);
			continue;
		}
		
		TimerInfo t;
		Timer_GetClientTimerInfo(target, t);
		GetStyleConfig(t.GetStyle(t.Type), s);
		s.GetName(sStyle, sizeof(sStyle));
		int tabs;
		if(t.IsTiming)
		{
			int buttons = Timer_GetButtons(target);
			char sTimeNC[128];
			// Time/keys section
			FormatPlayerTime(t.CurrentTime, sTime, sizeof(sTime), 0);
			Format(sTimeNC, sizeof(sTimeNC), "Time: %s          %s", sTime, (buttons & IN_FORWARD)?"W":"   ");
			int width = GetStringWidth(sTimeNC);
			tabs = GetNecessaryTabs(sTimeNC);
			if(Timer_GetTimesCount(type, style, tas) > 0)
			{
				float wrTime = Timer_GetTimeAtPosition(type, style, tas, 0);
				float pbTime = Timer_GetPersonalBest(target, type, style, tas)
				if(t.CurrentTime > pbTime && Timer_PlayerHasTime(target, type, style, tas))
				{
					Format(sTime, sizeof(sTime), "<font color=\"#ff0000\">%s</font>", sTime);
				}
				else if(t.CurrentTime > wrTime)
				{
					Format(sTime, sizeof(sTime), "<font color=\"#ffff00\">%s</font>", sTime);
				}
				else
				{
					Format(sTime, sizeof(sTime), "<font color=\"#00ff00\">%s</font>", sTime);
				}
			}
			else
			{
				Format(sTime, sizeof(sTime), "<font color=\"#9999ff\">%s</font>", sTime);
			}
	
			Format(sTime, sizeof(sTime), "Time: %s          %s", sTime, (buttons & IN_FORWARD)?"W":"   ");
			AddTabs(sTime, sizeof(sTime), tabs);
			
			// Speed/keys section
			FormatEx(sSpeed, sizeof(sSpeed), "Speed: %d", RoundToFloor(GetClientVelocity(target, true, true, cookiesCached?!GetCookieBool(client, g_hVelCookie):false)));
			int iLen = strlen(sSpeed);
			while(GetStringWidth(sSpeed) + (GetStringWidth(" ") * 7) <= width)
			{
				sSpeed[iLen++] = ' ';
			}
			Format(sSpeed, sizeof(sSpeed), "%s%s%s%s", sSpeed, (buttons & IN_MOVELEFT)?"A ":"   ", (buttons & IN_BACK)?"S ":"    ", (buttons & IN_MOVERIGHT)?"D":"");
			tabs = GetNecessaryTabs(sSpeed);
			AddTabs(sSpeed, sizeof(sSpeed), tabs);
			
			// Specs section
			FormatEx(sSpecs, sizeof(sSpecs), "Specs: %d", g_bIsAdmin[client]?adminSpecCount[target]:normalSpecCount[target]);
			tabs = GetNecessaryTabs(sSpecs);
			AddTabs(sSpecs, sizeof(sSpecs), tabs);
			
			// Sync section
			if(s.CalculateSync)
			{
				FormatEx(sSync, sizeof(sSync), "Sync: %.1f%%", t.Sync);
			}
			else
			{
				FormatEx(sSync, sizeof(sSync), "");
			}
			
			char sHint[512];
			FormatEx(sHint, sizeof(sHint),
				"<font face='verdana' size='16'>\
				%sJumps: %d\n\
				%sStrafes: %d\n\
				%s%s\n\
				</font>",
				sTime, t.Jumps,
				sSpeed, t.Strafes,
				sSpecs, sSync);
				
			PrintHintText(client, sHint);
		}
		else
		{
			PrintHintText(client, "<font face=\"verdana\" size=\"43\" color=\"%s\">No Timer</font>\nSpeed: %d\tSpecs: %d",
				sHex,
				RoundToFloor(GetClientVelocity(client, true, true, false)),
				g_bIsAdmin[client]?adminSpecCount[target]:normalSpecCount[target]);
		}
	}
}

void ShowSyncMessage(int client, int target)
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
			if(Replay_IsBotReplaying(bot) == false)
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
		int type  = TimerInfo(target).Type;
		int style = TimerInfo(target).ActiveStyle;
		int tas   = (g_bTasLoaded && TAS_InEditMode(target))?1:0;
		
		// World record display
		if(Timer_GetTimesCount(type, style, tas) > 0)
		{
			FormatPlayerTime(Timer_GetTimeAtPosition(type, style, tas, 0), sWorldRecord, sizeof(sWorldRecord), 1);
			Timer_GetNameAtPosition(type, style, tas, 0, sName, MAX_NAME_LENGTH);
			Format(sWorldRecord, sizeof(sWorldRecord), "WR: %s (%s)\n", sWorldRecord, sName);
		}
		else
		{
			FormatEx(sWorldRecord, sizeof(sWorldRecord), "WR: N/A\n");
		}
		
		// Target personal best
		if(Timer_PlayerHasTime(target, type, style, tas))
		{
			FormatPlayerTime(Timer_GetPersonalBest(target, type, style, tas), sPersonalBest, sizeof(sPersonalBest), 1);
			Format(sPersonalBest, sizeof(sPersonalBest), "PB: %s\n", sPersonalBest);
		}
		else
		{
			FormatEx(sPersonalBest, sizeof(sPersonalBest), "PB: N/A\n");
		}
		
		// Style name
		Style(style).GetName(sStyle, sizeof(sStyle));
		Format(sStyle, sizeof(sStyle), "Style: %s", sStyle);
		
		if(type == TIMER_BONUS)
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
			SetHudTextParams(g_cHudSyncPos[0].FloatValue, g_cHudSyncPos[1].FloatValue, 3.0, 255, 255, 255, 255);
			ShowSyncHudText(client, hText, sSyncMessage);
			CloseHandle(hText);
		}
	}
}

int GetNecessaryTabs(const char[] sInput, any ...)
{
	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sInput, 2);
	int width = GetStringWidth(sBuffer);
	
	if(width < 1397)
	{
		return 3;
	}
	else if(width < 2005) //2046
	{
		return 2;
	}
	else
	{
		return 1;
	}
}

void AddTabs(char[] sBuffer, int maxlength, int numTabs)
{
	if(numTabs == 3)
		Format(sBuffer, maxlength, "%s\t\t\t", sBuffer);
	else if(numTabs == 2)
		Format(sBuffer, maxlength, "%s\t\t", sBuffer);
	else
		Format(sBuffer, maxlength, "%s\t", sBuffer);
}

int GetStringWidth(const char[] sInput)
{
	int len = strlen(sInput);
	
	int width;
	for(int idx; idx < len; idx++)
	{
		if(!(sInput[idx] >= 127))
		{
			width += g_charWidth[sInput[idx]];
		}
	}
	
	return width;
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
				if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
				{
					if(g_bIsAdmin[client] == false)
						clients[Target]++;
					admins[Target]++;
				}
			}
		}
	}
}