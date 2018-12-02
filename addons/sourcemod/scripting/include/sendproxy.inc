#if !defined _SENDPROXYMANAGER_INC_
#define _SENDPROXYMANAGER_INC_



enum SendPropType {
	Prop_Int = 0,
	Prop_Float = 1,
	Prop_String = 2,
	//Prop_Array = 3,
	Prop_Vector = 4,
	Prop_Max
};

funcenum SendProxyCallback
{
	Action:public(entity, const String:PropName[], &iValue, element), //Prop_Int
	Action:public(entity, const String:PropName[], &Float:flValue, element), //Prop_Float
	Action:public(entity, const String:PropName[], String:modifiedValue[4096], element), //Prop_String
	Action:public(entity, const String:PropName[], Float:vecValues[3], element), //Prop_Vector
};

funcenum PropChangedCallback
{
	public(entity, const String:PropName[], const String:oldValue[], const String:newValue[]),
};

//Returns true upon success, false upon failure
native bool:SendProxy_Hook(entity, String:propname[], SendPropType:proptype, SendProxyCallback:callback);
native bool:SendProxy_HookArrayProp(entity, const String:name[], element, SendPropType:type, SendProxyCallback:callback);
native bool:SendProxy_UnhookArrayProp(entity, const String:name[], element, SendPropType:type, SendProxyCallback:callback);
native bool:SendProxy_Unhook(entity, String:propname[], SendProxyCallback:callback);
native bool:SendProxy_IsHooked(entity, String:propname[]);

native bool:SendProxy_HookPropChange(entity, const String:name[], PropChangedCallback:callback);
native SendProxy_UnhookPropChange(entity, const String:name[], PropChangedCallback:callback);

#if !defined REQUIRE_EXTENSIONS
public __ext_sendproxymanager_SetNTVOptional()
{
    MarkNativeAsOptional("SendProxy_Hook");
    MarkNativeAsOptional("SendProxy_HookArrayProp");
    MarkNativeAsOptional("SendProxy_Unhook");
    MarkNativeAsOptional("SendProxy_IsHooked");
    MarkNativeAsOptional("SendProxy_HookPropChange");
    MarkNativeAsOptional("SendProxy_UnhookPropChange");
}
#endif  

public Extension:__ext_sendproxymanager = 
{
	name = "SendProxy Manager",
	file = "sendproxy.ext",
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

#endif