#if defined _smartmsg_included
  #endinput
#endif
#define _smartmsg_included

typedef SmartMessageCallback = function bool (int client);

native void RegisterSmartMessage(SmartMessageCallback cb);

public SharedPlugin:__pl_smartmsg = 
{
	name = "smartmsg",
	file = "smartmsg.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_smartmsg_SetNTVOptional()
{
	MarkNativeAsOptional("RegisterSmartMessage");
}
#endif