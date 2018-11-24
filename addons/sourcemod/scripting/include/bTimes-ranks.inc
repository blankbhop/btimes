/*
* Updates the rankings for the current map, probably will become useless eventually
* 
* @param sMapName      The map to update ranks for.
* @param Type          The timer type to update ranks for.
* @param Style         The timer style to update ranks for.
*/
native DB_UpdateRanks(const String:sMapName[], Type, Style);

/*
* Gives custom chat privileges to a specified SteamID.
* 
* @param sAuth         The SteamID to enable custom chat for.
*/
native Timer_EnableCustomChat(const String:sAuth[]);

/*
* Disables custom chat privileges for a specified SteamID.
* 
* @param sAuth         The SteamID to disable custom chat for.
*/
native Timer_DisableCustomChat(const String:sAuth[]);

/*
* Gets if a specified SteamID has custom chat privileges
* 
* @param sAuth         The SteamID to get custom chat privileges for
*/
native Timer_SteamIDHasCustomChat(const String:sAuth[]);

/*
* Opens the stats menu to a client for the specified PlayerID
* 
* @param client        Client index.
* @param PlayerID      PlayerID from the database to show stats for.
* @param Type          Timer type to show stats.
* @param Style         Timer style to show stats.
*/
native Timer_OpenStatsMenu(client, PlayerID, Type, Style);