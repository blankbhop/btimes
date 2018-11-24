#if defined _ranks_included
  #endinput
#endif
#define _ranks_included

enum RecalculateReason
{
	Recalculate_NewTime = 0,
	Recalculate_TimesDeleted = 1
};

native int Ranks_GetClientOverallRecordRank(int client);

native int Ranks_GetClientOverallRank(int client);

native int Ranks_GetClientStyleRank(int client, int Type, int style);

native int Ranks_GetTotalOverallRanks();

native int Ranks_GetTotalStyleRanks(int Type, int style);

native int Ranks_IsClientRankedOverall(int client);

native int Ranks_IsClientRankedStyle(int client, int Type, int style);

native int Ranks_IsClientRankLoaded(int client);

native int Ranks_GetMapTier(const char[] map);

native bool Ranks_AreTiersLoaded();

native ArrayList Ranks_GetMapList();

native ArrayList Ranks_GetTierList();

forward void OnPointsRecalculated(RecalculateReason reason, any data);

forward void OnClientRankLoaded(int client);

forward void OnClientOverallRankChanged(int client, int oldRank, int newRank);

forward void OnClientStyleRankChanged(int client, int oldRank, int newRank, int Type, int style);

forward void OnTierListLoaded();

public SharedPlugin:__pl_ranks = 
{
	name = "ranks",
	file = "bTimes-rank2.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_ranks_SetNTVOptional()
{
	MarkNativeAsOptional("Ranks_GetClientOverallRecordRank");
	MarkNativeAsOptional("Ranks_GetClientOverallRank");
	MarkNativeAsOptional("Ranks_GetClientStyleRank");
	MarkNativeAsOptional("Ranks_GetTotalOverallRanks");
	MarkNativeAsOptional("Ranks_GetTotalStyleRanks");
	MarkNativeAsOptional("Ranks_IsClientRankedOverall");
	MarkNativeAsOptional("Ranks_IsClientRankedStyle");
	MarkNativeAsOptional("Ranks_IsClientRankLoaded");
	MarkNativeAsOptional("Ranks_GetMapTier");
	MarkNativeAsOptional("Ranks_AreTiersLoaded");
	MarkNativeAsOptional("Ranks_GetMapList");
	MarkNativeAsOptional("Ranks_GetTierList");
	
}
#endif