#if defined _replay_included
  #endinput
#endif
#define _replay_included

native bool  Replay_IsReplaying();

native bool  Replay_IsClientReplayBot(int client);

native int   Replay_GetCurrentReplayType();

native int   Replay_GetCurrentReplayStyle();

native bool  Replay_GetCurrentReplayTAS();

native void  Replay_GetPlayerName(int Type, int style, int tas, char[] name, int maxlength);

native int   Replay_GetPlayerId(int Type, int style, int tas);

native float Replay_GetReplayTime(int Type, int style, int tas);

native float Replay_GetCurrentTimeInRun();

public SharedPlugin:__pl_replay = 
{
	name = "replay",
	file = "bTimes-replay.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_replay_SetNTVOptional()
{
	MarkNativeAsOptional("Replay_IsReplaying");
	MarkNativeAsOptional("Replay_IsClientReplayBot");
	MarkNativeAsOptional("Replay_GetCurrentReplayType");
	MarkNativeAsOptional("Replay_GetCurrentReplayStyle");
	MarkNativeAsOptional("Replay_GetPlayerName");
	MarkNativeAsOptional("Replay_GetPlayerId");
	MarkNativeAsOptional("Replay_GetTime");
	MarkNativeAsOptional("Replay_GetCurrentTimeInRun");
	MarkNativeAsOptional("Replay_GetCurrentReplayTAS");
}
#endif