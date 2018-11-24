#if defined _cvarenf_included
  #endinput
#endif
#define _cvarenf_included

native void Cvar_Enforce(const char[] sCvar, const char[] sValue);

native bool Cvar_Unenforce(const char[] sCvar);

native bool Cvar_IsEnforced(const char[] sCvar);

public SharedPlugin:__pl_cvarenf = 
{
	name = "cvarenf",
	file = "cvarenf.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_cvarenf_SetNTVOptional()
{
	MarkNativeAsOptional("Cvar_Enforce");
	MarkNativeAsOptional("Cvar_Unenforce");
	MarkNativeAsOptional("Cvar_IsEnforced");
}
#endif