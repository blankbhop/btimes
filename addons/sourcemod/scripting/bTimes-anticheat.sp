#include <sourcemod>
#include <bTimes-core>
#include <bTimes-timer>
#include <sdktools>
#include <sdkhooks>

#undef REQUIRE_EXTENSIONS
#include <dhooks>

#define MAX_FRAMES 5

bool g_bCheck[MAXPLAYERS + 1];
int  g_iCheck[MAXPLAYERS + 1];
float g_fAngles[MAXPLAYERS + 1][3];
Handle g_hTeleport;
float g_fDifference[MAXPLAYERS + 1][MAX_FRAMES];
int   g_iFrame[MAXPLAYERS + 1];


// Anti crouch bug
ConVar g_hAllowCrouchBug;
int g_iLastButtons[MAXPLAYERS + 1];
int g_iLastDuckTick[MAXPLAYERS + 1];
EngineVersion g_Engine;

public Plugin:myinfo = 
{
	name = "[Timer] - Anti-cheat",
	author = "blacky",
	description = "Anti-cheat for some stuff..",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

public void OnPluginStart()
{
	g_hAllowCrouchBug = CreateConVar("timer_allowcrouchbug", "0", "Lets players use a bind to crouch and jump in the same tick", 0, true, 0.0, true, 1.0);
	g_Engine = GetEngineVersion();
	
	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Post);
}

public Action Event_PlayerJump(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(client != 0)
	{
		/*if(IsBlacky(client))
		{
			PrintToChat(client, "%d %d", GetGameTickCount(), g_iLastDuckTick[client]);
		}
		*/
		if(GetGameTickCount() == g_iLastDuckTick[client])
		{
			//SetEntProp(client, Prop_Send, "m_bDucking", 0);
		}
	}
}

public void OnAllPluginsLoaded()
{
	if(g_hTeleport == INVALID_HANDLE && LibraryExists("dhooks"))
	{
		Initialize();
	}
}

public void OnLibraryAdded(const char[] name)
{
    if(StrEqual(name, "dhooks") && g_hTeleport == INVALID_HANDLE)
	{
        Initialize();
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ac");
}

void Initialize()
{
	Handle hGameData = LoadGameConfigFile("sdktools.games");
	if(hGameData == INVALID_HANDLE)
		return;
	
	int iOffset = GameConfGetOffset(hGameData, "Teleport");
	
	CloseHandle(hGameData);
	
	if(iOffset == -1)
		return;
	
	g_hTeleport = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, Hook_DHooks_Teleport);
	
	if(g_hTeleport == INVALID_HANDLE){
		PrintToServer("\n!! g_hTeleport -> INVALID_HANDLE !!\n");
		return;
	}
	
	DHookAddParam(g_hTeleport, HookParamType_VectorPtr);
	DHookAddParam(g_hTeleport, HookParamType_ObjectPtr);
	DHookAddParam(g_hTeleport, HookParamType_VectorPtr);
	
	if(g_Engine == Engine_CSGO)
		DHookAddParam(g_hTeleport, HookParamType_Bool); // CS:GO only
	
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public void OnClientPutInServer(int client)
{
    if(g_hTeleport != INVALID_HANDLE)
	{
		g_bCheck[client] = false;
		g_iFrame[client] = 0;
		DHookEntity(g_hTeleport, false, client);
		SDKHook(client, SDKHook_PostThinkPost, Hook_PostThink);
	}
}

public void Hook_PostThink(int client)
{
	if(g_bCheck[client] == true && g_iCheck[client]++ > RoundToCeil(GetClientLatency(client, NetFlow_Both) * (1 / GetTickInterval())))
	{
		if(IsPlayerAlive(client))
		{
			float fAng[3];
			GetClientEyeAngles(client, fAng);
			//PrintToBlacky("2: %f", fAng[1]);
			
			float fAngleDiff = g_fAngles[client][1] - fAng[1];
			if(fAngleDiff > 180)
			{
				fAngleDiff -= 360;
			}
			else if(fAngleDiff < -180)
			{
				fAngleDiff += 360;
			}
			
			/*
			for(int target = 1; target <= MaxClients; target++)
			{
				if(IsClientInGame(target) && ((IsBlacky(target) && GetEntPropEnt(target, Prop_Send, "m_hObserverTarget") == client && !IsPlayerAlive(target)) || IsBlacky(client)))
				{
					PrintToBlacky("AngleDiff: %.1f", FloatAbs(fAngleDiff));
					break;
				}
			}
			*/
			
			g_fDifference[client][g_iFrame[client]] = FloatAbs(fAngleDiff);
			g_iFrame[client] = (g_iFrame[client] + 1) % MAX_FRAMES;
			if(g_iFrame[client] == MAX_FRAMES - 1)
			{
				AnalyzePlayer(client);
			}
		}
		
		
		g_bCheck[client] = false;
	}
}

void AnalyzePlayer(int client)
{
	float avg = GetAverage(g_fDifference[client], MAX_FRAMES);
	float dev = StandardDeviation(g_fDifference[client], MAX_FRAMES, avg);
	
	if(avg > 70.0 && dev < 20.0)
	{
		char sStyle[32];
		Style(TimerInfo(client).GetStyle(TimerInfo(client).Type)).GetName(sStyle, sizeof(sStyle));
		PrintToBlacky("%N Average: %.1f Deviation: %.1f,  Style: %s - BAN", client, avg, dev, sStyle);
		AnticheatLog("%L Average: %.1f Deviation: %.1f,  Style: %s - BAN", client, avg, dev, sStyle);
	}
}

stock bool AnticheatLog(const char[] log, any ...)
{
	char buffer[1024];
	VFormat(buffer, sizeof(buffer), log, 2);
	
	Handle myHandle = GetMyHandle();
	char sPlugin[PLATFORM_MAX_PATH];
	GetPluginFilename(myHandle, sPlugin, PLATFORM_MAX_PATH);
	
	char sTime[64];
	FormatTime(sTime, sizeof(sTime), "%X", GetTime());
	Format(buffer, 1024, "[%s] %s: %s", sPlugin, sTime, buffer);
	
	char sDate[64];
	FormatTime(sDate, sizeof(sDate), "%y%m%d", GetTime());
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/ac_%s.txt", sDate);
	File hFile = OpenFile(sPath, "a");
	if(hFile != INVALID_HANDLE)
	{
		WriteFileLine(hFile, buffer);
		delete hFile;
		return true;
	}
	else
	{
		LogError("Couldn't open timer log file.");
		return false;
	}
}


float StandardDeviation(float[] array, int size, float mean, bool countZeroes = true)
{
	float sd;
	
	for(int idx; idx < size; idx++)
	{
		if(countZeroes || array[idx] != 0)
		{
			sd += Pow(array[idx] - mean, 2.0);
		}
	}
	
	return SquareRoot(sd/size);
}

float GetAverage(float[] array, int size, bool countZeroes = true)
{
	float total;
	
	for(int idx; idx < size; idx++)
	{
		if(countZeroes || array[idx] != 0)
		{
			total += array[idx];
		}
		
	}
	
	return total / size;
}

public MRESReturn Hook_DHooks_Teleport(int client, Handle hParams)
{
	if(!IsClientConnected(client) || IsFakeClient(client) || !IsPlayerAlive(client))
		return MRES_Ignored;
		
	//int style = TimerInfo(client).GetStyle(TimerInfo(client).Type);
	//if(!Style(style).HasSpecialKey("ac"))
	//	return MRES_Ignored;
    
	if(!DHookIsNullParam(hParams, 2))
	{
		for(int i = 0; i < 3; i++)
		{
			g_fAngles[client][i] = DHookGetParamObjectPtrVar(hParams, 2, i*4, ObjectValueType_Float);
		}
		
		g_bCheck[client] = true;
		g_iCheck[client] = 0;
	}
    
	return MRES_Ignored;
}

public Native_CheckAngles(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	//int style = TimerInfo(client).GetStyle(TimerInfo(client).Type);
	//if(Style(style).HasSpecialKey("ac"))
	//{
	GetNativeArray(2, g_fAngles[client], 3);
	g_bCheck[client] = true;
	g_iCheck[client] = 0;
	//}
	
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(GetConVarBool(g_hAllowCrouchBug) == false)
	{
		if((buttons & IN_DUCK) && !(g_iLastButtons[client] & IN_DUCK)) 
		{
			g_iLastDuckTick[client] = GetGameTickCount();
		}
	}
	
	g_iLastButtons[client] = buttons;
}