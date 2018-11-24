#if defined _ac_included
  #endinput
#endif
#define _ac_included

native void AC_CheckAngles(client, const float vExpectedAngles[3]);

public SharedPlugin:__pl_ac = 
{
	name = "ac",
	file = "bTimes-anticheat.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_ac_SetNTVOptional()
{
	MarkNativeAsOptional("AC_CheckAngles");
}
#endif