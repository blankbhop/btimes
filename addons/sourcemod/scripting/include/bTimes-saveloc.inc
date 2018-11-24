forward bool OnSaveLocCreated_Pre(int client);

forward void OnSaveLocCreated_Post(int client);

native bool SaveLoc_PlayerHasSaveLoc(int client);

public SharedPlugin:__pl_saveloc = 
{
	name = "saveloc",
	file = "bTimes-saveloc.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_replay3_SetNTVOptional()
{
	MarkNativeAsOptional("SaveLoc_PlayerHasSaveLoc");
}
#endif