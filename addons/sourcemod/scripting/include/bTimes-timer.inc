#if defined _timer_included
  #endinput
#endif
#define _timer_included

#include <bTimes-core>

#define MAX_STYLES 32

#define StartMethod_Zones 0
#define StartMethod_Buttons 1
#define StartMethod_SaveLocation 2

char  g_StyleName[MAX_STYLES][32];
char  g_StyleNameShort[MAX_STYLES][32];
bool  g_StyleEnabledInConfig[MAX_STYLES];
bool  g_StyleEnabled[MAX_STYLES];
bool  g_AllowType[MAX_STYLES][2];
bool  g_Freestyle[MAX_STYLES];
bool  g_FreestyleUnrestrict[MAX_STYLES];
bool  g_FreestyleEzHop[MAX_STYLES];
bool  g_FreestyleAuto[MAX_STYLES];
bool  g_FreestyleNoLimit[MAX_STYLES];
bool  g_StyleUsesAuto[MAX_STYLES];
bool  g_StyleUsesEzHop[MAX_STYLES];
int   g_StyleGravity[MAX_STYLES];
float g_StyleRunSpeed[MAX_STYLES];
float g_StyleMaxVel[MAX_STYLES];
float g_StyleMinFPS[MAX_STYLES];
bool  g_StyleCalcSync[MAX_STYLES];
bool  g_StylePreventLeft[MAX_STYLES];
bool  g_StylePreventRight[MAX_STYLES];
bool  g_StylePreventBack[MAX_STYLES];
bool  g_StylePreventForward[MAX_STYLES];
bool  g_StyleRequireLeft[MAX_STYLES];
bool  g_StyleRequireRight[MAX_STYLES];
bool  g_StyleRequireBack[MAX_STYLES];
bool  g_StyleRequireForward[MAX_STYLES];
bool  g_ShowStyleOnHud[MAX_STYLES];
bool  g_ShowStrafesOnHud[MAX_STYLES];
bool  g_ShowJumpsOnHud[MAX_STYLES];
bool  g_CountLeftStrafe[MAX_STYLES];
bool  g_CountRightStrafe[MAX_STYLES];
bool  g_CountBackStrafe[MAX_STYLES];
bool  g_CountForwardStrafe[MAX_STYLES];
bool  g_UseGhost[MAX_STYLES][2];
bool  g_SaveGhost[MAX_STYLES][2];
float g_MaxPrespeed[MAX_STYLES];
float g_SlowedSpeed[MAX_STYLES];
bool  g_StyleIsSpecial[MAX_STYLES];
char  g_StyleSpecialKey[MAX_STYLES][64];
bool  g_AllowCheckpoints[MAX_STYLES];
float g_StylePointScale[MAX_STYLES];
int   g_StyleAirAcceleration[MAX_STYLES];
bool  g_StyleEnableBunnyhopping[MAX_STYLES];
int   g_StyleBreak[MAX_STYLES];
int   g_StyleStart[MAX_STYLES];
int   g_StyleSelectable[MAX_STYLES];
bool  g_StyleAllowTAS[MAX_STYLES];
bool  g_StyleAntiNoClip[MAX_STYLES];
bool  g_StyleGroundStartOnly[MAX_STYLES];

methodmap Style
{
	// Creates new style at specified number
	public native Style(int index);
	
	property int Index
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	// Get the style name
	public native void GetName(char[] name, int maxlength);
	
	// Set the style name
	public void SetName(char[] name)
	{
		FormatEx(g_StyleName[this.Index], sizeof(g_StyleName[]), name);
	}
	
	// Get the style name abbreviated
	public native void GetNameShort(char[] name, int maxlength);
	
	// Set the abbreviated style name
	public void SetNameShort(char[] name)
	{
		FormatEx(g_StyleNameShort[this.Index], sizeof(g_StyleName[]), name);
	}
	
	// If 'Enabled' in the config is set to 1 or 0
	property bool EnabledInConfig
	{
		public native get();
		public set(bool value)
		{
			g_StyleEnabledInConfig[this.Index] = value;
		}
	}
	
	// A value that can dynamically change per map or whenever an admin wants
	property bool Enabled
	{
		public native get();
		public set(bool value)
		{
			g_StyleEnabled[this.Index] = value;
		}
	}
	
	// Whether or not this style is allowed on the specified type
	public void SetAllowType(int type, bool value)
	{
		g_AllowType[this.Index][type] = value;
	}
	
	public native bool GetAllowType(int type);
	
	property bool Freestyle
	{
		public native get();
		public set(bool value)
		{
			g_Freestyle[this.Index] = value;
		}
	}
	
	property bool FreestyleUnrestrict
	{
		public native get();
		public set(bool value)
		{
			g_FreestyleUnrestrict[this.Index] = value;
		}
	}
	
	property bool FreestyleEzHop
	{
		public native get();
		public set(bool value)
		{
			g_FreestyleEzHop[this.Index] = value;
		}
	}
	
	property bool FreestyleAuto
	{
		public native get();
		public set(bool value)
		{
			g_FreestyleAuto[this.Index] = value;
		}
	}
	
	property bool FreestyleNoLimit
	{
		public native get();
		public set(bool value)
		{
			g_FreestyleNoLimit[this.Index] = value;
		}
	}
	
	// Autohop on the style
	property bool Auto
	{
		public native get();
		public set(bool value)
		{
			g_StyleUsesAuto[this.Index] = value;
		}	
	}
	
	// EzHop on the style
	property bool EzHop
	{
		public native get();
		public set(bool value)
		{
			g_StyleUsesEzHop[this.Index] = value;
		}	
	}
	
	// The style's gravity
	property int Gravity
	{
		public native get();
		public set(int value)
		{
			g_StyleGravity[this.Index] = value;
		}
	}
	
	// The styles runspeed
	property float RunSpeed
	{
		public native get();
		public set(float value)
		{
			g_StyleRunSpeed[this.Index] = value;
		}
	}
	
	// The styles max velocity
	property float MaxVelocity
	{
		public native get();
		public set(float value)
		{
			g_StyleMaxVel[this.Index] = value;
		}
	}
	
	// The styles minimum fps
	property float MinimumFPS
	{
		public native get();
		public set(float value)
		{
			g_StyleMinFPS[this.Index] = value;
		}
	}
	
	// Whether or not the style calculates sync (only possible on a/d styles)
	property bool CalculateSync
	{
		public native get();
		public set(bool value)
		{
			g_StyleCalcSync[this.Index] = value;
		}
	}
	
	// Whether or not the style prevents using the left movement button
	property bool PreventLeft
	{
		public native get();
		public set(bool value)
		{
			g_StylePreventLeft[this.Index] = value;
		}
	}
	
	// Whether or not the style prevents using the right movement button
	property bool PreventRight
	{
		public native get();
		public set(bool value)
		{
			g_StylePreventRight[this.Index] = value;
		}
	}
	
	// Whether or not the style prevents using the back movement button
	property bool PreventBack
	{
		public native get();
		public set(bool value)
		{
			g_StylePreventBack[this.Index] = value;
		}
	}
	
	// Whether or not the style prevents using the forward movement button
	property bool PreventForward
	{
		public native get();
		public set(bool value)
		{
			g_StylePreventForward[this.Index] = value;
		}
	}
	
	// Whethere or not the style requires the left movement button
	property bool RequireLeft
	{
		public native get();
		public set(bool value)
		{
			g_StyleRequireLeft[this.Index] = value;
		}
	}
	
	// Whethere or not the style requires the right movement button
	property bool RequireRight
	{
		public native get();
		public set(bool value)
		{
			g_StyleRequireRight[this.Index] = value;
		}
	}
	
	// Whethere or not the style requires the back movement button
	property bool RequireBack
	{
		public native get();
		public set(bool value)
		{
			g_StyleRequireBack[this.Index] = value;
		}
	}
	
	// Whethere or not the style requires the forward movement button
	property bool RequireForward
	{
		public native get();
		public set(bool value)
		{
			g_StyleRequireForward[this.Index] = value;
		}
	}
	
	// Whether or not the style's name is shown on the HUD
	property bool ShowNameOnHud
	{
		public native get();
		public set(bool value)
		{
			g_ShowStyleOnHud[this.Index] = value;
		}
	}
	
	// Whether or not the strafes are shown on the HUD
	property bool ShowStrafesOnHud
	{
		public native get();
		public set(bool value)
		{
			g_ShowStrafesOnHud[this.Index] = value;
		}
	}
	
	// Whether or not the jumps are shown on the HUD
	property bool ShowJumpsOnHud
	{
		public native get();
		public set(bool value)
		{
			g_ShowJumpsOnHud[this.Index] = value;
		}
	}
	
	// Whether or not using the left movement button adds to the strafe counter
	property bool CountLeftStrafe
	{
		public native get();
		public set(bool value)
		{
			g_CountLeftStrafe[this.Index] = value;
		}
	}
	
	// Whether or not using the right movement button adds to the strafe counter
	property bool CountRightStrafe
	{
		public native get();
		public set(bool value)
		{
			g_CountRightStrafe[this.Index] = value;
		}
	}
	
	// Whether or not using the back movement button adds to the strafe counter
	property bool CountBackStrafe
	{
		public native get();
		public set(bool value)
		{
			g_CountBackStrafe[this.Index] = value;
		}
	}
	
	// Whether or not using the forward movement button adds to the strafe counter
	property bool CountForwardStrafe
	{
		public native get();
		public set(bool value)
		{
			g_CountForwardStrafe[this.Index] = value;
		}
	}
	
	// Whether or not the style uses a replay bot
	public void SetUseGhost(int Type, bool value)
	{
		g_UseGhost[this.Index][Type] = value;
	}
	
	public native bool GetUseGhost(int Type);
	
	// Whether or not the style saves the replay bots
	public void SetSaveGhost(int Type, bool value)
	{
		g_SaveGhost[this.Index][Type] = value;
	}
	
	public native bool GetSaveGhost(int Type);
	
	// The max prespeed in the start zones for the style
	property float MaxPrespeed
	{
		public native get();
		public set(float value)
		{
			g_MaxPrespeed[this.Index] = value;
		}
	}
	
	// The speed players are set to when they are caught prespeeding
	property float SlowedSpeed
	{
		public native get();
		public set(float value)
		{
			g_SlowedSpeed[this.Index] = value;
		}
	}
	
	// Whether or not the style has a special function to it that cannot be put inside the config
	property bool IsSpecial
	{
		public native get();
		public set(bool value)
		{
			g_StyleIsSpecial[this.Index] = value;
		}
	}
	
	// The key(s) to the style to specify what special function is applied to it
	public void SetSpecialKey(char[] key, int maxlength)
	{
		FormatEx(g_StyleSpecialKey[this.Index], maxlength, key);
	}
	
	public native bool HasSpecialKey(char[] specialKey);
	
	// Whether or not the style allows using checkpoints
	property bool AllowCheckpoints
	{
		public native get();
		public set(bool value)
		{
			g_AllowCheckpoints[this.Index] = value;
		}
	}
	
	property int AirAcceleration
	{
		public native get();
		public set(int value)
		{
			g_StyleAirAcceleration[this.Index] = value;
		}
	}
	
	property bool EnableBunnyhopping
	{
		public native get();
		public set(bool value)
		{
			g_StyleEnableBunnyhopping[this.Index] = value;
		}
	}
	
	property float PointScale
	{
		public native get();
		public set(float value)
		{
			g_StylePointScale[this.Index] = value;
		}
	}
	
	property int Break
	{
		public native get();
		public set(int value)
		{
			g_StyleBreak[this.Index] = value;
		}
	}
	
	property int Start
	{
		public native get();
		public set(int value)
		{
			g_StyleStart[this.Index] = value;
		}
	}
	
	property int Selectable
	{
		public native get();
		public set(int value)
		{
			g_StyleSelectable[this.Index] = value;
		}
	}
	
	property bool AllowTAS
	{
		public native get();
		public set(bool value)
		{
			g_StyleAllowTAS[this.Index] = value;
		}
	}
	
	property bool AntiNoClip
	{
		public native get();
		public set(bool value)
		{
			g_StyleAntiNoClip[this.Index] = value;
		}
	}
	
	property bool GroundStartOnly
	{
		public native get();
		public set(bool value)
		{
			g_StyleGroundStartOnly[this.Index] = value;
		}
	}
}

stock bool  g_TimerIsTiming[MAXPLAYERS + 1];
stock int   g_TimerType[MAXPLAYERS + 1];
stock int   g_TimerStyle[MAXPLAYERS + 1][2];
stock int   g_TimerJumps[MAXPLAYERS + 1];
stock int   g_TimerStrafes[MAXPLAYERS + 1];
stock int   g_TimerTotalSync[MAXPLAYERS + 1];
stock int   g_TimerGoodSync[MAXPLAYERS + 1];
stock int   g_TimerCheckpointsUsed[MAXPLAYERS + 1];
stock bool  g_TimerPaused[MAXPLAYERS + 1];
stock float g_TimerCurrentTime[MAXPLAYERS + 1];
stock int   g_TimerActiveStyle[MAXPLAYERS + 1];

methodmap TimerInfo
{
	public native TimerInfo(int client);
	
	property bool IsTiming
	{
		public native get();
		public native set(bool value);
	}
	
	property bool Paused
	{
		public native get();
		public native set(bool value);
	}
	
	property float CurrentTime
	{
		public native get();
		public native set(float value);
	}
	
	property int Type
	{
		public native get();
		public native set(int value);
	}
	
	public native int GetStyle(int Type);
	public native void SetStyle(int Type, int style);
	
	property int TotalSync
	{
		public native get();
		public native set(int value);
	}
	
	property int GoodSync
	{
		public native get();
		public native set(int value);
	}
	
	property float Sync
	{
		public native get();
	}
	
	property int CheckpointsUsed
	{
		public native get();
		public native set(int value);
	}
	
	property int Jumps
	{
		public native get();
		public native set(int value);
	}
	
	property int Strafes
	{
		public native get();
		public native set(int value);
	}
	
	property int ActiveStyle
	{
		public native get();
	}
}

/**
* Gets the total number of styles listed in the styles config.
*
* @return              Total number of styles.
*/
native int GetTotalStyles();


/*
* Stops a client's timer.
* 
* @param client		Client index.
* 
* @noreturn
*/
native StopTimer(client);

/*
* Starts a client's timer.
* 
* @param client        Client index.
* @param Type          Timer type to start the timer on.
* @param StartTime     The starting time the player will have (usually 0.0 unless the player runs from a saved spot)
* @param Method        The method the client used the start the timer (Zones, Buttons, or Saved location)
* 
* @noreturn
*/
native bool:StartTimer(client, Type, Float:StartTime = 0.0, Method = StartMethod_Zones);

/*
* Gets if someone is being timed.
* 
* @param client        Client index.
* @param Type          The timer type being checked.
* 
* @return              True if they are being timed, false otherwise.
*/
native bool:IsBeingTimed(client, Type);

/*
* Ends someone's timer, attempting to save their time if it is new.
* 
* @param client        Client index.
* 
* @noreturn
*/
native FinishTimer(client);

/*
* Gets a client's style (Normal, Sideways, etc..).
* 
* @param client        Client index
* 
* @return              The client's style.
*/
native GetClientStyle(client);

/*
* Gets a client's timer type (main or bonus).
* 
* @param client        Client index.
* 
* @return              The client's timer type.
*/
native GetClientTimerType(client);

/*
* Gets if a player has their timer paused.
* 
* @param client        Client index.
* 
* @return              True if they are paused, false otherwise.
*/
native bool:IsTimerPaused(client);

/*
* Gets the complete configuration for a specified style.
* 
* @param style         The style to get a configuration for.
* @param s             The buffer to store the style methodmap.
* 
* @noreturn
*/
native void GetStyleConfig(int style, Style &styleConfig);

/*
* Used to tell what type and what style a player wants information for given a command, can only be used during a command callback.
* 
* @param sCommand      The command the player used.
* @param sDelimeter    The delimeter to get the type and style strings.
* @param Type          The timer type to return.
* @param Style         The timer style to return.
* 
* @return              True if a type and a style were found, false otherwise.
*/
native bool GetTypeStyleFromCommand(char[] sDelimiter, int &Type, int &style);

/*
* Gets the unaffected bitsum of buttons (in case someone wants to do something with something like the IN_JUMP value to players on auto)
* 
* @param client        Client index.
*/
native Timer_GetButtons(client);

native Timer_GetFlags(client);

/*
* Pauses or unpauses a client's timer
* 
* @param client        Client index.
* @param pause         True if pause, false if unpause
* 
* @return              True if pause or unpause is successful
*/
native bool Timer_Pause(int client, bool pause);

/*
* Gets various information about a player's current timer.
* 
* @param client        Client index.
* @param Info          Array of information, uses the TimerStats enum.
*/
native void Timer_GetClientTimerInfo(int client, TimerInfo &t);

/*
* Sets a client's timer information. Can be used to even start a client's timer.
* 
* @param client        Client index.
* @param Info          Information to set for the client. Uses the TimerStats enum.
*/
native Timer_SetClientTimerInfo(int client, TimerInfo info);

/**
* Gets a client's personal best on the specified timer type and style.
*
* @param client        Client index.
* @param Type          Timer type.
* @param style         Timer style.
* @param tas           TAS Mode or not.
*
* @return              Personal best.
*/
native float Timer_GetPersonalBest(int client, int Type, int style, int tas);

/*
* Checks if a player has a time on the specified timer type and style.
*
* @param client        Client index.
* @param Type          Timer type.
* @param style         Timer style.
* @param tas           TAS Mode or not.
*
* @return              True if player has a time, false otherwise.
*/
native bool Timer_PlayerHasTime(int client, int Type, int style, int tas);

/**
* Get the amount of times on the current map for the specified timer settings
*
* @param Type          Timer type.
* @param style         Timer style.
* @param tas           TAS Mode or not.
*
* @return              Number of times on the map.
*/
native int Timer_GetTimesCount(int Type, int style, int tas);

/**
* Get the time on the map at the specified position.
*
* @param Type          Timer type.
* @param style         Timer style.
* @param tas           TAS Mode or not.
* @param position      The position to get the time at.
*
* @return              The needed time.
*/
native float Timer_GetTimeAtPosition(int Type, int style, int tas, int position);

/**
* Get the player's name at the specified position.
*
* @param Type          Timer type.
* @param style         Timer style.
* @param tas           TAS Mode or not.
* @param position      The position to get the time at.
* @param sName         String to hold the name.
* @param maxlength     Max length of given string.
*
* @return              The needed time.
*/
native bool  Timer_GetNameAtPosition(int Type, int style, int tas, int position, char[] sName, int maxlength);

/**
* Shows a menu of a specific time on the server and information about it
* 
* @param client        Player to show the time information to
* @param type		   Timer type
* @param style		   Timer style
* @param tas		   Is TAS Mode
* @param playerId	   Player ID
* @param sMap          Map name
* 
* @noreturn
*/
native void  Timer_ShowPlayerTime(int client, int type, int style, int tas, int playerId, char[] sMap);

/**
* Gets the player's position on the current map
*
* @param client        Player to get the position of
* @param type          Timer type
* @param style         Timer style
* @param tas           Is TAS Mode
*
* @reeturn             The player's position, or -1 if the player doesnt have a time
*/
native void Timer_GetPlayerMapRank(int client, int type, int style, int tas);

/**
* Called when time is about to be added to a player's timer.
*
* @param client        Client index.
*/
forward Action OnTimeAddedToTimer(int client);

/**
* Called before a player finishes their run.
* 
* @param client        Client index.
* @param Type          Timer type.
* @param Style         Timer style.
*/
forward Action OnTimerFinished_Pre(int client, int Type, int style);

/*
* Called after a player finishes their run.
* 
* @param client        Client index.
* @param Time          The player's finishing time.
* @param Type          The player's timer type.
* @param Style         The player's timer style.
* @param tas           Whether or not the player was using tas.
* @param NewTime       true if it's a new time, false otherwise.
* @param OldPosition   The player's position before finishing the map.
* @param NewPosition   The player's position after finishing the map.
*/
forward void OnTimerFinished_Post(int client, float Time, int Type, int style, bool tas, bool NewTime, int OldPosition, int NewPosition);

/*
* Called when their is an attempt to start a client's timer.
* 
* @param client        Client index.
* @param Type          Timer type.
* @param Style         Timer style.
*/
forward Action OnTimerStart_Pre(int client, int Type, int style, int Method);

/*
* Called after a player's timer is started.
* 
* @param client        Client index.
* @param Type          Timer type.
* @param Style         Timer style.
*/
forward void OnTimerStart_Post(int client, int Type, int style, int Method);

/*
* Called when a player's timer is stopped.
* 
* @param client        Client index.
*/
forward void OnTimerStopped(int client);

/*
* Called when times have been deleted.
* 
* @param sMap          The map times were deleted on.
* @param type          The timer type of the times deleted.
* @param style         The timer style of the times deleted.
* @param tas           Whether it was TAS times that were deleted.
* @param minPos        The first record in the range of records deleted.
* @param maxPos        The last record in the range of records deleted.
*/
forward void OnTimesDeleted(const char[] sMap, int type, int style, bool tas, int minPos, int maxPos);

/*
* Called when times have been updated in the database.
* 
* @param Type          The timer type of the times updated.
* @param Style         The timer style of the times updated.
* @param Times         The adt_array of all the map times before the times have been updated.
*/
forward void OnTimesUpdated(const String:sMapName[], Type, Style, tas, Handle:Times);

/*
* Called when the style have been read from the styles.cfg file
*/
forward void OnStylesLoaded();

/*
* Called when a map's times have been loaded
*/
forward OnMapTimesLoaded();

/**
* Called when a client changes their style. (Can be called if a client switches the to the style they were already on)
* 
* @param client        Client index.
* @param oldStyle      The previous style a player was on.
* @param newStyle      The new style a player is on.
* @param type          The timer type the styles are being changed for.
*/
forward void OnStyleChanged(int client, int oldStyle, int newStyle, int type);

any g_STCB_Data[MAXPLAYERS + 1];
DataPack g_STFxnPack[MAXPLAYERS + 1];
int g_SelectTimer_Type[MAXPLAYERS + 1];
int g_SelectTimer_Style[MAXPLAYERS + 1];
int g_SelectTimer_TAS[MAXPLAYERS + 1];
bool g_SelectTimer_All[MAXPLAYERS + 1];

typedef SelectTimerCallback = function void (int client, int type, int style, bool tas, bool all, any data);

// -1 for startvalues to not display
void CreateTimerSelection(int client, const char[] title, int startType, int startStyle, int startTas, bool all, SelectTimerCallback stcb, any data)
{
	g_SelectTimer_Type[client]  = startType;
	g_SelectTimer_Style[client] = startStyle;
	g_SelectTimer_TAS[client]   = startTas;
	g_SelectTimer_All[client]   = all;
	
	Menu menu = new Menu(Menu_TimerSelection);
	menu.SetTitle(title);
	
	if(all == true)
	{
		menu.AddItem("all", "All");
	}
	
	if(g_STFxnPack[client] != INVALID_HANDLE)
	{
		delete g_STFxnPack[client];
	}

	g_STFxnPack[client] = CreateDataPack();
	g_STFxnPack[client].WriteFunction(stcb);
	
	g_STCB_Data[client] = data;
	
	char sDisplay[128];
	if(startType != -1)
	{
		GetTypeName(startType, sDisplay, sizeof(sDisplay));
		Format(sDisplay, sizeof(sDisplay), "Type: %s", sDisplay);
		menu.AddItem("type", sDisplay);
	}
	
	if(startStyle != -1)
	{
		Style(startStyle).GetName(sDisplay, sizeof(sDisplay));
		Format(sDisplay, sizeof(sDisplay), "Style: %s", sDisplay);
		menu.AddItem("style", sDisplay);
	}
	
	if(startTas != -1)
	{
		FormatEx(sDisplay, sizeof(sDisplay), "%s", startTas?"TAS: Yes":"TAS: No");
		menu.AddItem("tas", sDisplay);
	}
	
	menu.AddItem("confirm", "Confirm");
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_TimerSelection(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "type"))
		{
			g_SelectTimer_Type[client] = (g_SelectTimer_Type[client] + 1) % MAX_TYPES;
			
			char sTitle[128];
			menu.GetTitle(sTitle, sizeof(sTitle));
			
			ResetPack(g_STFxnPack[client]);
			CreateTimerSelection(
				client, 
				sTitle, 
				g_SelectTimer_Type[client], 
				g_SelectTimer_Style[client], 
				g_SelectTimer_TAS[client], 
				g_SelectTimer_All[client],
				SelectTimerCallback:g_STFxnPack[client].ReadFunction(), 
				g_STCB_Data[client]);			
		}
		else if(StrEqual(sInfo, "style"))
		{
			int totalStyles = GetTotalStyles();
			
			do
			{
				g_SelectTimer_Style[client] = (g_SelectTimer_Style[client] + 1) % totalStyles;
			}
			while(Style(g_SelectTimer_Style[client]).Enabled == false && 
			Style(g_SelectTimer_Style[client]).GetAllowType(g_SelectTimer_Type[client]) == false);
			
			char sTitle[128];
			menu.GetTitle(sTitle, sizeof(sTitle));
			
			ResetPack(g_STFxnPack[client]);
			CreateTimerSelection(
				client, 
				sTitle, 
				g_SelectTimer_Type[client], 
				g_SelectTimer_Style[client], 
				g_SelectTimer_TAS[client], 
				g_SelectTimer_All[client],
				SelectTimerCallback:g_STFxnPack[client].ReadFunction(), 
				g_STCB_Data[client]);
		}
		else if(StrEqual(sInfo, "tas"))
		{
			g_SelectTimer_TAS[client] = !g_SelectTimer_TAS[client];
			
			char sTitle[128];
			menu.GetTitle(sTitle, sizeof(sTitle));
			
			ResetPack(g_STFxnPack[client]);
			CreateTimerSelection(
				client, 
				sTitle, 
				g_SelectTimer_Type[client], 
				g_SelectTimer_Style[client], 
				g_SelectTimer_TAS[client], 
				g_SelectTimer_All[client],
				SelectTimerCallback:g_STFxnPack[client].ReadFunction(), 
				g_STCB_Data[client]);
		}
		else if(StrEqual(sInfo, "all"))
		{
			ResetPack(g_STFxnPack[client]);
			Call_StartFunction(GetMyHandle(), g_STFxnPack[client].ReadFunction());
			Call_PushCell(client);
			Call_PushCell(g_SelectTimer_Type[client]);
			Call_PushCell(g_SelectTimer_Style[client]);
			Call_PushCell(g_SelectTimer_TAS[client]);
			Call_PushCell(1);
			Call_PushCell(g_STCB_Data[client]);
			Call_Finish();
		}
		else if(StrEqual(sInfo, "confirm"))
		{
			ResetPack(g_STFxnPack[client]);
			Call_StartFunction(GetMyHandle(), g_STFxnPack[client].ReadFunction());
			Call_PushCell(client);
			Call_PushCell(g_SelectTimer_Type[client]);
			Call_PushCell(g_SelectTimer_Style[client]);
			Call_PushCell(g_SelectTimer_TAS[client]);
			Call_PushCell(0);
			Call_PushCell(g_STCB_Data[client]);
			Call_Finish();
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

stock void ShowPlayerStats(int client, int playerId, int type, int style, int tas)
{
	ConVar c = FindConVar("timer_statsurl");
	if(c == null)
	{
		return;
	}
	
	char sStatsCvar[PLATFORM_MAX_PATH];
	c.GetString(sStatsCvar, PLATFORM_MAX_PATH);
	
	char sURL[PLATFORM_MAX_PATH];
	FormatEx(sURL, PLATFORM_MAX_PATH, "%su=%d&s=%d&t=%d",
		sStatsCvar, playerId, style, type);

	ShowMOTDPanel(client, "Player stats", sURL, MOTDPANEL_TYPE_URL);
}