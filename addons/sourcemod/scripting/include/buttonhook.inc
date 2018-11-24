#if defined _buttonhook_included
  #endinput
#endif
#define _buttonhook_included

forward void OnButtonPressed(int client, int button);

public SharedPlugin:__pl_buttonhook = 
{
	name = "buttonhook",
	file = "buttonhook.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};