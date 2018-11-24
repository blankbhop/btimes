#if defined _tas_included
  #endinput
#endif
#define _tas_included

native bool      TAS_InEditMode(int client);

native bool      TAS_IsPaused(int client);

native ArrayList TAS_GetRunHandle(int client);

native int       TAS_GetCurrentFrame(int client);

forward void OnTASPauseChanged(int client, bool paused);

forward void OnTASFrameRecorded(int client, int frame);

public SharedPlugin:__pl_tas = 
{
	name = "tas",
	file = "bTimes-tas.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_tas_SetNTVOptional()
{
	MarkNativeAsOptional("TAS_InEditMode");
	MarkNativeAsOptional("TAS_IsPaused");
	MarkNativeAsOptional("TAS_GetRunHandle");
	MarkNativeAsOptional("TAS_GetCurrentFrame");
}
#endif