#if defined _replay3_included
  #endinput
#endif
#define _replay3_included

// Data from replay files
#define REPLAY_DATA_POS_0 0
#define REPLAY_DATA_POS_1 1
#define REPLAY_DATA_POS_2 2
#define REPLAY_DATA_ANG_0 3
#define REPLAY_DATA_ANG_1 4
#define REPLAY_DATA_BTN   5
#define REPLAY_FRAME_SIZE 6

// Bot config
#define MAX_BOTS 32 // Max number of bots allowed in the config

enum BotActivationType(+=1)
{
	BOTTYPE_MENU = 0,
	BOTTYPE_CYCLE
};

enum PlayReplayReason(+=1)
{
	PRR_BOT_NOT_INGAME = 0,
	PRR_BOT_IN_USE,
	PRR_NO_REPLAY_FILE,
	PRR_CATEGORY_NOT_IN_CONFIG,
	PRR_ONLY_CYCLE_BOTS,
	PRR_SUCCESS
};

/*
* Gets the bot index of a client. -1 if the client isn't a bot
*
* @param client        Client index
*
* @return              Bot number
*/
native int Replay_GetReplayBot(int client);


/*
* Gets if a bot is currently playing a style
*
* @param bot           Bot number
*
* @return              Is bot replaying
*/
native bool Replay_IsBotReplaying(int bot);

/*
* Gets bot run time
*
* @param bot           Bot number
*
* @return              Bot current run time
*/
native float Replay_GetBotRunTime(int bot);

/*
* Gets bot timer type
*
* @param bot           Bot number
*
* @return              Bot timer type
*/
native int Replay_GetBotRunType(int bot);

/*
* Gets bot timer style
*
* @param bot           Bot number
*
* @return              Bot timer style
*/
native int Replay_GetBotRunStyle(int bot);

/*
* Gets bot TAS setting
*
* @param bot           Bot number
*
* @return              Bot TAS setting
*/
native int Replay_GetBotRunTAS(int bot);

/*
* Gets the player id of the player the bot is saved from
*
* @param bot           Bot number
*
* @return              Owner's playerid
*/
native int Replay_GetBotPlayerId(int bot);

/*
* Gets the player name of the player the bot is saved from
*
* @param bot           Bot number
* @param output        Player's name
* @param maxlength     Maxlength of output parameter
*
* @noreturn
*/
native void Replay_GetBotPlayerName(int bot, char[] output, int maxlength);

/*
* Gets the method used to activate the bot's runs (via menu (aka !replay/manual) or automatic/cyclic)
*
* @param bot           Bot number
*
* @return              Bot activation type (BOT_MENU or BOT_CYCLE defined in this include file)
*/
native BotActivationType Replay_GetBotActivationType(int bot);

/*
* Gets the ticks in the player's recordings that they started their run (for the bTimes-saveloc plugin)
*
* @param client          Client index
* @param startFrame      This frame is a certain amount of ticks (defined by the replay_preruntime convar)
* @param timerStartFrame The exact frame that the player's timer started

* @noreturn
*/
native void Replay_GetPlayerStartTicks(int client, int &startFrame, int &timerStartFrame);

/*
* Sets the players start ticks in the player's recording for the bTimes-saveloc plugin
*
* @param client          Client index
* @param startFrame      This frame is a certain amount of ticks (defined by the replay_preruntime convar)
* @param timerStartFrame The exact frame that the player's timer started
*
* @return                True if the startFrame and timerStartFrame values lie within the size of the player's recording handle, false otherwise.
*/
native bool Replay_SetPlayerStartTicks(int client, int startFrame, int timerStartFrame);

/*
* Gets if the player is currently allowed to record, this only exists in case the plugin is reloaded to prevent replay bots that only show half the map
*
* @param client        Client index
*
* @return              Bot number
*/
native bool Replay_PlayerIsRecording(int client);

/*
* Gets the ArrayList handle to the player's recording data
*
* @param client        Client index
*
* @return              Player's recording data
*/
native ArrayList Replay_GetPlayerRecordingHandle(int client);

public SharedPlugin:__pl_replay3 = 
{
	name = "replay3",
	file = "bTimes-replay3.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_replay3_SetNTVOptional()
{
	MarkNativeAsOptional("Replay_GetReplayBot");
	MarkNativeAsOptional("Replay_IsBotReplaying");
	MarkNativeAsOptional("Replay_GetBotRunTime");
	MarkNativeAsOptional("Replay_GetBotRunType");
	MarkNativeAsOptional("Replay_GetBotRunStyle");
	MarkNativeAsOptional("Replay_GetBotRunTAS");
	MarkNativeAsOptional("Replay_GetBotPlayerId");
	MarkNativeAsOptional("Replay_GetBotPlayerName");
	MarkNativeAsOptional("Replay_GetBotActivationType");
	MarkNativeAsOptional("Replay_GetPlayerStartTicks");
	MarkNativeAsOptional("Replay_SetPlayerStartTicks");
	MarkNativeAsOptional("Replay_PlayerIsRecording");
	MarkNativeAsOptional("Replay_GetPlayerRecordingHandle");
}
#endif