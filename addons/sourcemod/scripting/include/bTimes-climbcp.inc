/*
* Returns how many checkpoints a player has used
* 
* @param client        Client index.
*/
native void Timer_GetUsedCpCount(int client);

/*
* Sets how many checkpoints a client has used.
* 
* @param client        Client index.
* @param count         Amount of checkpoints to set it to.
*/
native void Timer_SetUsedCpCount(int client, int count);

/*
* Called before a client saves a checkpoint.
* 
* @param client        Client index.
*/
forward Action OnCheckpointSaved_Pre(int client);

/*
* Called before a client uses a checkpoint.
* 
* @param client        Client index.
*/
forward Action OnCheckpointUsed_Pre(int client);

/*
* Called before a client saves a checkpoint.
* 
* @param client        Client index.
*/
forward void OnCheckpointSaved_Post(int client);

/*
* Called before a client uses a checkpoint.
* 
* @param client        Client index.
*/
forward void OnCheckpointUsed_Post(int client);

public SharedPlugin:__pl_climbcp = 
{
	name = "climbcp",
	file = "bTimes-climbcp.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_climbcp_SetNTVOptional()
{
	MarkNativeAsOptional("Timer_GetUsedCpCount");
	MarkNativeAsOptional("Timer_SetUsedCpCount");
}
#endif