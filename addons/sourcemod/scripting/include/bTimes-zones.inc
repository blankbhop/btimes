#define ZONE_COUNT 7

#define MAIN_START  0
#define MAIN_END    1
#define BONUS_START 2
#define BONUS_END   3
#define ANTICHEAT   4
#define FREESTYLE   5
#define SLIDE       6


// Zone properties
enum ZoneProperties
{
	bool:zEnabled,
	zMax,
	zCount,
	zEntity[64],
	bool:zReady[64],
	zRowID[64],
	zAc_Type[64],
	zFs_Unrestrict[64],
	zFs_EzHop[64],
	zFs_Auto[64],
	zFs_NoLimit[64],
	bool:zReplaceable,
	bool:zTriggerBased,
	String:zName[64],
	zColor[4],
	zHaloIndex,
	zModelIndex,
	zOffset,
	zSpeed
};

#define FLAG_ANTICHEAT_MAIN  1<<0
#define FLAG_ANTICHEAT_BONUS 1<<1

/*
* Gets number of specified zones loaded
*
* @param Zone          Zone type
*
* @return              Number of zones
*/
native int Timer_GetZoneCount(Zone);

/*
* Gets if a client is inside a zone type
* 
* @param client        Client index.
* @param Zone          The zone type to check if they are inside.
* @param flags         Optional flags required for a zone to have, -1 for no flags required
* 
* @return              The ZoneNumber a client is inside of, -1 if client is not inside a zone with the given parameters.
*/
native int Timer_InsideZone(client, Zone, flags = -1, flagtype = -1);

/*
* Gets if a point is inside a zone
* 
* @param pos           The position to check is inside a zone.
* @param Zone          Zone type.
* @param ZoneNumber    Zone number.
* 
* @return              True if the point is inside the specified zone, false otherwise.
*/
native bool Timer_IsPointInsideZone(Float:pos[3], Zone, ZoneNumber);

/*
* Teleports a client to a specified zone
* 
* @param client        Client index.
* @param Zone          The zone type to teleport to.
* @param ZoneNumber    The zone number to teleport to.
* @param bottom        If set to true, the client will teleport to the bottom of the zone.
* 
* @noreturn
*/
native void Timer_TeleportToZone(client, Zone, ZoneNumber, bool:bottom = false);

/*
* Gets how many zones their are in the database for every map in the map list.
* 
* @param Zone          Zone type to check.
* 
* @return              Total number of zones for the zone type.
*/
native int GetTotalZonesAllMaps(Zone);

/*
* Called when the zones have been loaded.
*/
forward void OnZonesLoaded();

/*
* Called when someone enters a zone
*/
forward void OnZoneStartTouch(client, Zone, ZoneNumber);

/*
* Called when someone leaves a zone
*/
forward void OnZoneEndTouch(client, Zone, ZoneNumber);

/*
* Called when someone teleports to a zone
*/
forward void OnTeleportToZone(client, Zone, ZoneNumber);
