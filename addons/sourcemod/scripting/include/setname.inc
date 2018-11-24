#if defined _setname_included
  #endinput
#endif
#define _setname_included

#include <sourcemod>
#include <sdktools>

stock CS_SetClientName(client, String:name[])
{
	static Handle:hSetName = INVALID_HANDLE;
	
	if (hSetName == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetFromConf(GetSetNameConf(), SDKConf_Virtual, "CBaseClient::SetName");
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		hSetName = EndPrepSDKCall();
	}
	
	return SDKCall(hSetName, GetBaseClient(client - 1), name);
}

stock CS_GetClientName(client, String:name[], maxlen)
{
	static Handle:hGetName = INVALID_HANDLE;
	
	if (hGetName == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetFromConf(GetSetNameConf(), SDKConf_Virtual, "CBaseClient::GetClientName");
		PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
		hGetName = EndPrepSDKCall();
	}
	
	SDKCall(hGetName, GetIClient(client - 1), name, maxlen);
}

/*
* Internal Functions
*/
stock Handle:GetSetNameConf()
{
	static Handle:hGameConf = INVALID_HANDLE;
	
	if (hGameConf == INVALID_HANDLE)
	{
		hGameConf = LoadGameConfigFile("setname.games");
	}
	
	return hGameConf;
}

stock Address:GetBaseServer()
{
	static Address:pBaseServer = Address_Null;
	
	if (pBaseServer == Address_Null)
	{
		pBaseServer = GameConfGetAddress(GetSetNameConf(), "CBaseServer");
	}
	
	return pBaseServer;
}

stock Address:GetIClient(client)
{
	static Handle:hGetClient = INVALID_HANDLE;
	
	if (hGetClient == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetFromConf(GetSetNameConf(), SDKConf_Virtual, "CBaseServer::GetClient");
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		hGetClient = EndPrepSDKCall();
	}
	
	return Address:SDKCall(hGetClient, GetBaseServer(), client);
}

stock Address:GetBaseClient(client)
{
	return GetIClient(client) - Address:4;
}
