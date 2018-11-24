#if defined _soundscapehook_included
 #endinput
#endif
#define _soundscapehook_included

/**
 * Called when the function CEnvSoundscape::UpdateForPlayer is called
 * by the engine.
 * 
 * @param soundscape		Soundscape entity. (NB: Not necessarily
 *							valid, you may want to check this before
 *							you return Plugin_Handled)
 * @param client			Client used in the update. 
 *
 * @return					Plugin_Continue to allow UpdateForPlayer
 *							to call,otherwise UpdateForPlayer is not
 *							called by the engine.
 */
forward Action SoundscapeUpdateForPlayer(int entity, int client);

public Extension __ext_soundscapehook = {
	name = "soundscapehook",
	file = "soundscapehook.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
};