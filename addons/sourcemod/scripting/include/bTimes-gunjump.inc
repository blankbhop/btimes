#if defined _gunjump_included
  #endinput
#endif
#define _gunjump_included

enum _:GunJumpConfig
{
	String:Weapon[64],
	Float:Range,
	Float:Damage,
	bool:Auto_Health_Regen,
	Health_Regen_Rate,
	Max_Health,
	Float:Boost_Horizontal,
	Float:Boost_Vertical,
	Primary_Clip_Size,
	Primary_Clip_Max_Size,
	Primary_Clip_Regen_Rate,
	bool:Primary_Clip_Auto_Regen,
	Secondary_Clip_Size,
	Secondary_Clip_Max_Size,
	Secondary_Clip_Regen_Rate,
	bool:Secondary_Clip_Auto_Regen
};

/**
 * Returns whether a client has just gun boosted, similar to the IsChatTrigger function.
 * 
 * @return             True if a client just gun boosted, false otherwise
 */
native bool:Timer_IsGunJump();

public SharedPlugin:__pl_gunjump = 
{
	name = "gunjump",
	file = "bTimes-gunjump.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_gunjump_SetNTVOptional()
{
	MarkNativeAsOptional("Timer_IsGunJump");
}
#endif