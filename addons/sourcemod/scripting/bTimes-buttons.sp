#pragma semicolon 1

#include <sourcemod>
#include <bTimes-core>
#include <bTimes-timer>
#include <sdktools>
#include <sdkhooks>
#include <smlib/entities>
#include <csgocolors>

#undef REQUIRE_PLUGIN
#include <adminmenu>

// Methods that define what to do with buttons
#define METHOD_SET 1
#define METHOD_CREATE 2
#define METHOD_DISABLE 3

#define BUTTON_MAINSTART 0
#define BUTTON_MAINEND 1
#define BUTTON_BONUSSTART 2
#define BUTTON_BONUSEND 3

enum
{
	GameType_CSS,
	GameType_CSGO
};

new 	g_GameType;

new	Handle:g_LiteDB,
	String:g_sMapName[64];
	
new	Handle:g_hMapButtonList;

enum ButtonProperties
{
	ButtonRowID,
	ButtonMethod,
	ButtonType,
	ButtonEntity,
	ButtonSpriteEntity
};

new	Handle:g_hDatabaseMethodList;
	
// Create button setup
enum ButtonSetup
{
	Handle:SetupHandle,
	SetupEntity
};

new g_ButtonSetup[MAXPLAYERS + 1][ButtonSetup];

new	bool:g_bPluginUnloading;

public Plugin:myinfo = 
{
	name = "[Timer] Buttons",
	author = "blacky",
	description = "Everything about timer start and end buttons",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

public OnPluginStart()
{
	decl String:sGame[64];
	GetGameFolderName(sGame, sizeof(sGame));
	
	if(StrEqual(sGame, "cstrike"))
		g_GameType = GameType_CSS;
	else if(StrEqual(sGame, "csgo"))
		g_GameType = GameType_CSGO;
	else
		SetFailState("This timer does not support this game (%s)", sGame);
	
	RegConsoleCmd("sm_buttons", SM_Buttons, "Opens the button control menu.");
	
	if(g_GameType == GameType_CSGO)
	{
		HookEvent("round_start", Event_RoundStart);
	}
	
	DB_Connect();
	
	g_hMapButtonList      = CreateArray();
	g_hDatabaseMethodList = CreateArray(view_as<any>(ButtonProperties));
	HookEntityOutput("prop_physics_override", "OnPlayerUse", OnPlayerUse);
}

public void OnPlayerUse(const char[] output, int caller, int activator, float delay)
{
	PrintToChatAll("Test");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("timer-buttons");
	
	if(late)
	{
		UpdateMessages();
	}
	
	return APLRes_Success;
}

public OnPluginEnd()
{
	g_bPluginUnloading = true;
	
	// Delete any existing custom created button in case the plugin is being restarted
	new iSize = GetArraySize(g_hDatabaseMethodList);
	
	new entity, sprite;
	for(new idx; idx < iSize; idx++)
	{
		if(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonMethod)) == METHOD_CREATE)
		{
			entity = EntRefToEntIndex(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonEntity)));
			
			if(entity != -1)
			{
				AcceptEntityInput(entity, "Kill");
			}
			
			sprite = EntRefToEntIndex(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonSpriteEntity)));
			
			if(sprite != -1)
			{
				AcceptEntityInput(sprite, "Kill");
			}
		}
	}
}

public OnMapStart()
{
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	SearchForButtons();
	DB_LoadButtons();
	
	// Precache and add to downloads table
	AddFileToDownloadsTable("models/props/switch001.mdl");
	AddFileToDownloadsTable("models/props/switch001.vvd");
	AddFileToDownloadsTable("models/props/switch001.phy");
	AddFileToDownloadsTable("models/props/switch001.vtx");
	AddFileToDownloadsTable("models/props/switch001.dx90.vtx");		
	AddFileToDownloadsTable("materials/models/props/switch.vmt");
	AddFileToDownloadsTable("materials/models/props/switch.vtf");
	AddFileToDownloadsTable("materials/models/props/switch001.vmt");
	AddFileToDownloadsTable("materials/models/props/switch001.vtf");
	AddFileToDownloadsTable("materials/models/props/startkztimer.vmt");
	AddFileToDownloadsTable("materials/models/props/startkztimer.vtf");	
	AddFileToDownloadsTable("materials/models/props/stopkztimer.vmt");
	AddFileToDownloadsTable("materials/models/props/stopkztimer.vtf");
	
	PrecacheModel("materials/models/props/startkztimer.vmt", true);
	PrecacheModel("materials/models/props/stopkztimer.vmt", true);
	PrecacheModel("models/props/switch001.mdl", true);
	PrecacheModel("materials/sprites/bluelaser1.vmt", true);
	
	PrecacheSound("buttons/button3.wav", true);
}

public Hook_OnUsePost(entity, activator, caller, UseType:type, Float:value)
{
	if(activator <= 0 || activator > MaxClients)
		return;
	
	decl String:sClassname[64];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	
	if(StrEqual(sClassname, "func_button") && bool:GetEntProp(entity, Prop_Data, "m_bLocked") == true)
		return;
	
	new iSize = GetArraySize(g_hDatabaseMethodList);
	
	for(new idx; idx < iSize; idx++)
	{
		if(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonEntity)) == EntIndexToEntRef(entity))
		{
			new Type = GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonType));
			switch(Type)
			{
				case BUTTON_MAINSTART:
				{
					StartTimer(activator, TIMER_MAIN, _, StartMethod_Buttons);
				}
				case BUTTON_MAINEND:
				{
					FinishTimer(activator);
				}
				case BUTTON_BONUSSTART:
				{
					StartTimer(activator, TIMER_BONUS, _, StartMethod_Buttons);
				}
				case BUTTON_BONUSEND:
				{
					FinishTimer(activator);
				}
			}
			
			if(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonMethod)) == METHOD_CREATE)
			{
				EmitSoundToClient(activator, "buttons/button3.wav");
			}
			
			break;
		}
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	SearchForButtons();
	DB_LoadButtons();
}

SearchForButtons()
{
	// Import all buttons in the map to an array for efficient lookup
	ClearArray(g_hMapButtonList);
	ClearArray(g_hDatabaseMethodList);
	
	decl String:sTargetname[64];
	
	new entity = -1;
	while((entity = FindEntityByClassname(entity, "func_button")) != -1)
	{
		PushArrayCell(g_hMapButtonList, EntIndexToEntRef(entity));
		
		GetButtonName(entity, sTargetname, sizeof(sTargetname));
		
		if(StrEqual(sTargetname, "climb_startbutton", false))
		{
			AddToDatabaseMethodList(entity, METHOD_SET, BUTTON_MAINSTART, -1, -1);
		}
		else if(StrEqual(sTargetname, "climb_endbutton", false))
		{
			AddToDatabaseMethodList(entity, METHOD_SET, BUTTON_MAINEND, -1, -1);
		}
		
		SDKHook(entity, SDKHook_UsePost, Hook_OnUsePost);
	}
}

GetZoneName(Zone, String:buffer[], maxlength)
{
	switch(Zone)
	{
		case BUTTON_MAINSTART:
		{
			FormatEx(buffer, maxlength, "Main Start");
		}
		case BUTTON_MAINEND:
		{
			FormatEx(buffer, maxlength, "Main End");
		}
		case BUTTON_BONUSSTART:
		{
			FormatEx(buffer, maxlength, "Bonus Start");
		}
		case BUTTON_BONUSEND:
		{
			FormatEx(buffer, maxlength, "Bonus End");
		}
		default:
		{
			FormatEx(buffer, maxlength, "Unknown");
		}
	}
}

public Action:SM_Buttons(client, args)
{
	new AdminFlag:flag = Admin_Config;
	Timer_GetAdminFlag("zones", flag);
	
	if(!GetAdminFlag(GetUserAdmin(client), flag))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	OpenButtonsMenu(client);
	
	return Plugin_Handled;
}

OpenButtonsMenu(client)
{
	new Handle:hMenu = CreateMenu(Menu_Buttons);
	
	SetMenuTitle(hMenu, "Button control");
	
	AddMenuItem(hMenu, "set", "Set a button");
	AddMenuItem(hMenu, "unset", "Unset selected button");
	AddMenuItem(hMenu, "create", "Create a custom button");
	AddMenuItem(hMenu, "del", "Delete a custom button");
	AddMenuItem(hMenu, "disable", "Disable selected map button");
	AddMenuItem(hMenu, "enable", "Enable selected map button");
	
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public Menu_Buttons(Handle:menu, MenuAction:action, client, param2)
{
	if(action & MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrEqual(info, "set"))
		{
			OpenSetButtonMenu(client);
		}
		else if(StrEqual(info, "unset"))
		{
			UnsetButton(client);
			OpenButtonsMenu(client);
		}
		else if(StrEqual(info, "create"))
		{
			OpenCreateButtonMenu(client);
		}
		else if(StrEqual(info, "del"))
		{
			DeleteCustomButton(client);
			OpenButtonsMenu(client);
		}
		else if(StrEqual(info, "disable"))
		{
			DisableSelectedMapButton(client);
			OpenButtonsMenu(client);
		}
		else if(StrEqual(info, "enable"))
		{
			EnableSelectedMapButton(client);
			OpenButtonsMenu(client);
		}
	}
	
	if(action & MenuAction_Cancel)
	{
		if(LibraryExists("adminmenu") && param2 == MenuCancel_ExitBack)
		{
			new AdminFlag:Flag = Admin_Custom5;
			Timer_GetAdminFlag("adminmenu", Flag);
			if(GetAdminFlag(GetUserAdmin(client), Flag))
			{
				new TopMenuObject:TimerCommands = FindTopMenuCategory(GetAdminTopMenu(), "TimerCommands");
				
				if(TimerCommands != INVALID_TOPMENUOBJECT)
				{
					DisplayTopMenuCategory(GetAdminTopMenu(), TimerCommands, client);
				}
			}
		}
	}
	
	if(action & MenuAction_End)
	{
		CloseHandle(menu);
	}
}

OpenSetButtonMenu(client)
{
	new Handle:hMenu = CreateMenu(Menu_SetButton);
	
	SetMenuTitle(hMenu, "Set button");
	
	AddMenuItem(hMenu, "0", "Main start");
	AddMenuItem(hMenu, "1", "Main end");
	AddMenuItem(hMenu, "2", "Bonus start");
	AddMenuItem(hMenu, "3", "Bonus end");
	
	SetMenuExitBackButton(hMenu, true);
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public Menu_SetButton(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:sInfo[32];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		SetButton(client, StringToInt(sInfo));
		
		OpenSetButtonMenu(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenButtonsMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

SetButton(client, Type)
{
	new button = GetClientAimTarget(client, false);
	
	if(button != -1)
	{
		decl String:sClassname[64];
		GetEntityClassname(button, sClassname, sizeof(sClassname));
		
		if(StrEqual(sClassname, "func_button"))
		{
			new iSize = GetArraySize(g_hDatabaseMethodList);
				
			for(new idx; idx < iSize; idx++)
			{
				if(EntIndexToEntRef(button) == GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonEntity)))
				{
					if(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonMethod)) == METHOD_SET)
					{
						PrintColorText(client, "%s%sThe selected button is already set to perform a timer action.",
							g_msg_start,
							g_msg_textcol);
						return;
					}
				}
			}
			
			// Save button information to database
			new Float:fPos[3];
			Entity_GetAbsOrigin(button, fPos);
			
			decl String:sQuery[256];
			FormatEx(sQuery, sizeof(sQuery), "INSERT INTO buttons (MapName, Method, Type, Pos0, Pos1, Pos2) VALUES('%s', %d, %d, %f, %f, %f)",
				g_sMapName,
				METHOD_SET,
				Type,
				fPos[0],
				fPos[1],
				fPos[2]);
			
			new Handle:hPack = CreateDataPack();
			WritePackCell(hPack, GetClientUserId(client));
			WritePackCell(hPack, button);
			WritePackCell(hPack, Type);
				
			SQL_TQuery(g_LiteDB, SetButton_Callback, sQuery, hPack);
			
		}
		else
		{
			PrintColorText(client, "%s%sNo button found.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		PrintColorText(client, "%s%sNo button found.",
			g_msg_start,
			g_msg_textcol);
	}
}

public SetButton_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		
		new client = GetClientOfUserId(ReadPackCell(data));
		new button = ReadPackCell(data);
		new Type   = ReadPackCell(data);
		
		new RowID  = SQL_GetInsertId(hndl);
		
		AddToDatabaseMethodList(button, METHOD_SET, Type, RowID, -1);
		
		if(client != 0)
		{
			decl String:sButton[64];
			GetZoneName(Type, sButton, sizeof(sButton));
			
			PrintColorText(client, "%s%sSelected button is now saved as %s%s%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sButton,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

UnsetButton(client)
{
	new button = GetClientAimTarget(client, false);
	
	if(button != -1)
	{
		decl String:sClassname[64];
		GetEntityClassname(button, sClassname, sizeof(sClassname));
		
		if(StrEqual(sClassname, "func_button"))
		{
			// Delete button information from database
			new iSize = GetArraySize(g_hDatabaseMethodList);
			
			for(new idx; idx < iSize; idx++)
			{
				if(EntIndexToEntRef(button) == GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonEntity)))
				{
					if(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonMethod)) == METHOD_SET && GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonRowID)) != -1)
					{
						decl String:sQuery[256];
						FormatEx(sQuery, sizeof(sQuery), "DELETE FROM buttons WHERE RowID=%d",
							GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonRowID)));
							
						SQL_TQuery(g_LiteDB, UnsetButton_Callback, sQuery, GetClientUserId(client));
						
						RemoveFromArray(g_hDatabaseMethodList, idx);
						
						return;
					}
				}
			}
			
			PrintColorText(client, "%s%sSelected button is either not found in the database or is not set to perform a timer action.",
				g_msg_start,
				g_msg_textcol);
		}
		else
		{
			PrintColorText(client, "%s%sNo button found.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		PrintColorText(client, "%s%sNo button found.",
			g_msg_start,
			g_msg_textcol);
	}
}

public UnsetButton_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new client = GetClientOfUserId(data);
		
		if(client != 0)
		{
			PrintColorText(client, "%s%sYour selected button has been unset to perform any timer action.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
}

OpenCreateButtonMenu(client)
{
	new Handle:hMenu = CreateMenu(Menu_CreateButton);
	
	InitializeButtonSpawningLoop(client);
	
	SetMenuTitle(hMenu, "Create button");
	
	AddMenuItem(hMenu, "0", "Main start");
	AddMenuItem(hMenu, "1", "Main end");
	AddMenuItem(hMenu, "2", "Bonus start");
	AddMenuItem(hMenu, "3", "Bonus end");
	
	SetMenuExitBackButton(hMenu, true);
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public Menu_CreateButton(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		EndButtonSpawningLoop(client);
		
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		new Type = StringToInt(info);
		
		new button = SpawnButton("custombutton");
		
		if(button != -1)
		{
			TeleportNewButtonToPosition(client, button);
			new sprite = GiveButtonSprite(button, Type);
			
			new Float:fPos[3];
			Entity_GetAbsOrigin(button, fPos);
			
			new Float:fAng[3];
			Entity_GetAbsAngles(button, fAng);
			
			decl String:sQuery[256];
			FormatEx(sQuery, sizeof(sQuery), "INSERT INTO buttons(MapName, Method, Type, Pos0, Pos1, Pos2, Ang0, Ang1) VALUES('%s', %d, %d, %f, %f, %f, %f, %f)",
				g_sMapName,
				METHOD_CREATE,
				Type,
				fPos[0],
				fPos[1],
				fPos[2],
				fAng[0],
				fAng[1]);
				
			new Handle:hPack = CreateDataPack();
			WritePackCell(hPack, GetClientUserId(client));
			WritePackCell(hPack, button);
			WritePackCell(hPack, Type);
			WritePackCell(hPack, sprite);
			SQL_TQuery(g_LiteDB, CreateButton_Callback, sQuery, hPack);	
		}
		else
		{
			PrintColorText(client, "%s%sAn error occurred attempting to create the button entity.",
				g_msg_start,
				g_msg_textcol);
		}
		
		OpenCreateButtonMenu(client);
	}
	else if(action == MenuAction_Cancel)
	{
		EndButtonSpawningLoop(client);
		
		if(param2 == MenuCancel_ExitBack)
			OpenButtonsMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public CreateButton_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		
		new client = GetClientOfUserId(ReadPackCell(data));
		
		if(client != 0)
		{
			PrintColorText(client, "%s%sNew button saved.",
				g_msg_start,
				g_msg_textcol);
		}
		
		new button = ReadPackCell(data);
		new Type   = ReadPackCell(data);
		new sprite = ReadPackCell(data);
		
		AddToDatabaseMethodList(button, METHOD_CREATE, Type, SQL_GetInsertId(hndl), sprite);
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

InitializeButtonSpawningLoop(client) 
{
	g_ButtonSetup[client][SetupEntity] = SpawnButton("loopbutton");
	
	if(g_ButtonSetup[client][SetupEntity] != -1)
	{
		TeleportNewButtonToPosition(client, g_ButtonSetup[client][SetupEntity]);
	}
	
	new Handle:hPack;
	g_ButtonSetup[client][SetupHandle] = CreateDataTimer(0.1, Timer_TeleportButton, hPack, TIMER_REPEAT);
	WritePackCell(hPack, GetClientUserId(client));
	WritePackCell(hPack, EntIndexToEntRef(g_ButtonSetup[client][SetupEntity]));
}

public Action:Timer_TeleportButton(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	
	new client = GetClientOfUserId(ReadPackCell(pack));
	
	if(client != 0)
	{
		new button = EntRefToEntIndex(ReadPackCell(pack));
		
		if(button != INVALID_ENT_REFERENCE)
		{
			TeleportNewButtonToPosition(client, button);
		}
	}
	else
	{
		if(timer != INVALID_HANDLE)
		{
			KillTimer(timer, true);
			timer = INVALID_HANDLE;
		}
	}
}

TeleportNewButtonToPosition(client, button)
{
	new Float:fPos[3];
	GetClientEyePosition(client, fPos);
	
	new Float:fAng[3];
	GetClientEyeAngles(client, fAng);
	
	TR_TraceRayFilter(fPos, fAng, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, button);
	
	new Float:fNewPos[3];
	if(TR_DidHit())
	{
		TR_GetEndPosition(fNewPos);
		
		if(GetVectorDistance(fPos, fNewPos) > 200)
		{
			fNewPos = fPos;
			
			new Float:vAng[3];
			GetAngleVectors(fAng, vAng, NULL_VECTOR, NULL_VECTOR);
			for(new idx; idx < 3; idx++)
				fNewPos[idx] += vAng[idx] * 200;
		}
	}
	else
	{
		new Float:vAng[3];
		GetAngleVectors(fAng, vAng, NULL_VECTOR, NULL_VECTOR);
		
		fNewPos = fPos;
		
		for(new idx; idx < 3; idx++)
			fNewPos[idx] += vAng[idx] * 200;
	}
	
	fAng[0] = 0.0;
	fAng[1] += 180;
	
	TeleportEntity(button, fNewPos, fAng, NULL_VECTOR);
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

EndButtonSpawningLoop(client)
{
	if(IsValidEntity(g_ButtonSetup[client][SetupEntity]))
	{
		AcceptEntityInput(g_ButtonSetup[client][SetupEntity], "Kill");
	}
		
	if(g_ButtonSetup[client][SetupHandle] != INVALID_HANDLE && g_bPluginUnloading == false)
	{
		KillTimer(g_ButtonSetup[client][SetupHandle]);
		g_ButtonSetup[client][SetupHandle] = INVALID_HANDLE;
	}
}

SpawnButton(const String:targetname[])
{
	new entity = CreateEntityByName("prop_physics_override");
	if (entity != -1)
	{  
		DispatchKeyValue(entity, "model", "models/props/switch001.mdl");
		DispatchKeyValue(entity, "spawnflags", "264");
		//DispatchKeyValue(entity, "spawnflags", "256");
		DispatchKeyValue(entity, "targetname", targetname);
		DispatchSpawn(entity);
		SetEntProp(entity, Prop_Data, "m_nHitboxSet", 1);
		SetEntProp(entity, Prop_Data, "m_nSolidType", 2); //2
		SetEntProp(entity, Prop_Data, "m_usSolidFlags", 0x0008); //16
		SetEntProp(entity, Prop_Data, "m_CollisionGroup", 3); //3
		
		
		SDKHook(entity, SDKHook_UsePost, Hook_OnUsePost);
	}
	
	return entity;
}

GiveButtonSprite(button, Type)
{
	new sprite = CreateEntityByName("env_sprite");
	if(sprite != -1) 
	{ 
		DispatchKeyValue(sprite, "spawnflags", "1");
		DispatchKeyValue(sprite, "scale", "0.2");
		
		if (Type == BUTTON_MAINSTART || Type == BUTTON_BONUSSTART)
		{
			DispatchKeyValue(sprite, "model", "materials/models/props/startkztimer.vmt"); 
			DispatchKeyValue(sprite, "targetname", "starttimersign");
		}
		else
		{
			DispatchKeyValue(sprite, "model", "materials/models/props/stopkztimer.vmt"); 
			DispatchKeyValue(sprite, "targetname", "stoptimersign");
		}
		
		DispatchKeyValue(sprite, "rendermode", "1");
		//DispatchKeyValue(sprite, "framerate", "0");
		DispatchKeyValue(sprite, "HDRColorScale", "1.0");
		DispatchKeyValue(sprite, "rendercolor", "255 255 255");
		DispatchKeyValue(sprite, "renderamt", "255");
		DispatchSpawn(sprite);
		
		new Float:fPos[3];
		Entity_GetAbsOrigin(button, fPos);
		fPos[2] += 95;
		TeleportEntity(sprite, fPos, Float:{0.0, 0.0, 0.0}, NULL_VECTOR);
	}
	
	return sprite;
}

DeleteCustomButton(client)
{
	new button = GetClientAimTargetEx(client);
	PrintToChatAll("%d", button);
	if(button != -1)
	{
		decl String:sClassname[64];
		GetEntityClassname(button, sClassname, sizeof(sClassname));
		
		if(StrEqual(sClassname, "prop_physics"))
		{
			// Delete button information from database
			new iSize = GetArraySize(g_hDatabaseMethodList);
			
			for(new idx; idx < iSize; idx++)
			{
				if(EntIndexToEntRef(button) == GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonEntity)))
				{
					if(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonMethod)) == METHOD_CREATE && GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonRowID)) != -1)
					{
						decl String:sQuery[256];
						FormatEx(sQuery, sizeof(sQuery), "DELETE FROM buttons WHERE RowID=%d",
							GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonRowID)));
							
						SQL_TQuery(g_LiteDB, DeleteCustomButton_Callback, sQuery, GetClientUserId(client));
						
						AcceptEntityInput(button, "Kill");
						
						new sprite = EntRefToEntIndex(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonSpriteEntity)));
						if(sprite != -1)
						{
							AcceptEntityInput(sprite, "Kill");
						}
						
						RemoveFromArray(g_hDatabaseMethodList, idx);
						
						return;
					}
				}
			}
			
			PrintColorText(client, "%s%sSelected button is not a custom button.",
				g_msg_start,
				g_msg_textcol);
		}
		else
		{
			PrintColorText(client, "%s%sNo button found.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		PrintColorText(client, "%s%sNo button found.",
			g_msg_start,
			g_msg_textcol);
	}
}

int GetClientAimTargetEx(int client)
{
	float vPos[3];
	GetClientEyePosition(client, vPos);
	
	float vAng[3];
	GetClientEyeAngles(client, vAng);
	
	TR_TraceRayFilter(vPos, vAng, MASK_VISIBLE, RayType_Infinite, TraceRayDontHitSelf, client);
	
	return TR_GetEntityIndex();
}

public DeleteCustomButton_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new client = GetClientOfUserId(data);
		
		if(client != 0)
		{
			PrintColorText(client, "%s%sButton deleted.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
}

DisableSelectedMapButton(client)
{
	new button = GetClientAimTarget(client, false);
	
	if(button != -1)
	{
		decl String:sClassname[64];
		GetEntityClassname(button, sClassname, sizeof(sClassname));
		if(StrEqual(sClassname, "func_button"))
		{
			new iSize = GetArraySize(g_hDatabaseMethodList);
			
			for(new idx; idx < iSize; idx++)
			{
				if(EntIndexToEntRef(button) == GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonEntity)))
				{
					if(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonMethod)) == METHOD_DISABLE)
					{
						new bool:bLocked = bool:GetEntProp(button, Prop_Data, "m_bLocked");
						
						if(bLocked == true)
						{
							PrintColorText(client, "%s%sThe selected button is already disabled.",
								g_msg_start,
								g_msg_textcol);
						}
						else
						{
							SetEntProp(button, Prop_Data, "m_bLocked", true);
							PrintColorText(client, "%s%sThe selected button should have been already disabled but wasn't. It is now disabled.",
								g_msg_start,
								g_msg_textcol);
						}
						
						return;
					}
				}
			}
			
			SetEntProp(button, Prop_Data, "m_bLocked", true);
			
			new Float:fPos[3];
			Entity_GetAbsOrigin(button, fPos);
			
			decl String:sQuery[256];
			FormatEx(sQuery, sizeof(sQuery), "INSERT INTO buttons (MapName, Method, Pos0, Pos1, Pos2) VALUES ('%s', %d, %f, %f, %f)",
				g_sMapName,
				METHOD_DISABLE,
				fPos[0],
				fPos[1],
				fPos[2]);
				
			new Handle:hPack = CreateDataPack();
			WritePackCell(hPack, GetClientUserId(client));
			WritePackCell(hPack, button);
			SQL_TQuery(g_LiteDB, DisableButton_Callback, sQuery, hPack);
		}
		else
		{
			PrintColorText(client, "%s%sNo button found.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		PrintColorText(client, "%s%sNo button found.",
			g_msg_start,
			g_msg_textcol);
	}
}

public DisableButton_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client = GetClientOfUserId(ReadPackCell(data));
		new button = ReadPackCell(data);
		
		AddToDatabaseMethodList(button, METHOD_DISABLE, -1, SQL_GetInsertId(hndl), -1);
		
		if(client != 0)
		{
			PrintColorText(client, "%s%sButton disabled (Saved).",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
}

EnableSelectedMapButton(client)
{
	new button = GetClientAimTarget(client, false);
	
	if(button != -1)
	{
		decl String:sClassname[64];
		GetEntityClassname(button, sClassname, sizeof(sClassname));
		if(StrEqual(sClassname, "func_button"))
		{
			new iSize = GetArraySize(g_hDatabaseMethodList);
			
			for(new idx; idx < iSize; idx++)
			{
				if(EntIndexToEntRef(button) == GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonEntity)))
				{
					if(GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonMethod)) == METHOD_DISABLE)
					{
						SetEntProp(button, Prop_Data, "m_bLocked", false);
						
						decl String:sQuery[256];
						FormatEx(sQuery, sizeof(sQuery), "DELETE FROM buttons WHERE RowID = %d",
							GetArrayCell(g_hDatabaseMethodList, idx, view_as<int>(ButtonRowID)));
						SQL_TQuery(g_LiteDB, EnableButton_Callback, sQuery, GetClientUserId(client));
						
						RemoveFromArray(g_hDatabaseMethodList, idx);
						
						return;
					}
				}
			}
			
			
		}
		else
		{
			PrintColorText(client, "%s%sNo button found.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		PrintColorText(client, "%s%sNo button found.",
			g_msg_start,
			g_msg_textcol);
	}
}

public EnableButton_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new client = GetClientOfUserId(data);
		
		if(client != 0)
		{
			PrintColorText(client, "%s%sButton enabled (Saved).",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
}

DB_Connect()
{
	if(g_LiteDB != INVALID_HANDLE)
		CloseHandle(g_LiteDB);
	
	decl String:sError[255];
	g_LiteDB = SQLite_UseDatabase("timer", sError, sizeof(sError));
	
	if(g_LiteDB == INVALID_HANDLE)
	{
		LogError(sError);
		CloseHandle(g_LiteDB);
	}
	else
	{
		decl String:sQuery[256];
		FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS buttons (RowID INTEGER PRIMARY KEY AUTOINCREMENT, MapName TEXT, Method INTEGER, Type INTEGER, Pos0 FLOAT, Pos1 FLOAT, Pos2 FLOAT, Ang0 FLOAT, Ang1 FLOAT)");
		new Handle:hQuery = SQL_Query(g_LiteDB, sQuery);
		
		if(hQuery == INVALID_HANDLE)
		{
			SQL_GetError(hQuery, sError, sizeof(sError));
			LogError(sError);
		}
	}
}

DB_LoadButtons()
{
	decl String:sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), "SELECT Method, Type, Pos0, Pos1, Pos2, Ang0, Ang1, RowID FROM buttons WHERE MapName='%s' ORDER BY Method", g_sMapName);
	SQL_TQuery(g_LiteDB, LoadButtons_Callback, sQuery);
}

public LoadButtons_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new Method, Type, Float:fPos[3], Float:fAng[3], ent = -1, RowID;
		
		while(SQL_FetchRow(hndl))
		{
			Method = SQL_FetchInt(hndl, 0);
			
			switch(Method)
			{
				case METHOD_SET:
				{
					fPos[0] = SQL_FetchFloat(hndl, 2);
					fPos[1] = SQL_FetchFloat(hndl, 3);
					fPos[2] = SQL_FetchFloat(hndl, 4);
					
					if((ent = FindMapButtonByPosition(fPos)) != -1)
					{
						Type  = SQL_FetchInt(hndl, 1);
						RowID = SQL_FetchInt(hndl, 7);
						
						AddToDatabaseMethodList(ent, Method, Type, RowID, -1);
					}
				}
				case METHOD_CREATE:
				{
					ent = SpawnButton("custombutton");
					
					if(ent != -1)
					{
						Type    = SQL_FetchInt(hndl, 1);
						fPos[0] = SQL_FetchFloat(hndl, 2);
						fPos[1] = SQL_FetchFloat(hndl, 3);
						fPos[2] = SQL_FetchFloat(hndl, 4);
						fAng[0] = SQL_FetchFloat(hndl, 5);
						fAng[1] = SQL_FetchFloat(hndl, 6);
						RowID   = SQL_FetchInt(hndl, 7);
						
						TeleportEntity(ent, fPos, fAng, NULL_VECTOR);
						
						new sprite = GiveButtonSprite(ent, Type);
						AddToDatabaseMethodList(ent, Method, Type, RowID, sprite);
					}
				}
				case METHOD_DISABLE:
				{
					fPos[0] = SQL_FetchFloat(hndl, 2);
					fPos[1] = SQL_FetchFloat(hndl, 3);
					fPos[2] = SQL_FetchFloat(hndl, 4);
					RowID   = SQL_FetchInt(hndl, 7);
					
					if((ent = FindMapButtonByPosition(fPos)) != -1)
					{
						SetEntProp(ent, Prop_Data, "m_bLocked", true);
						AddToDatabaseMethodList(ent, Method, -1, RowID, -1);
					}
				}
			}
		}
	}
	else
	{
		LogError(error);
	}
}

/*
* Finds a map button by its position
*/
FindMapButtonByPosition(Float:pos[3])
{
	new iSize = GetArraySize(g_hMapButtonList);
	
	new entity, Float:fEntityPos[3];
	for(new idx; idx < iSize; idx++)
	{
		if((entity = EntRefToEntIndex(GetArrayCell(g_hMapButtonList, idx))) != INVALID_ENT_REFERENCE)
		{
			Entity_GetAbsOrigin(entity, fEntityPos);
			
			if(GetVectorDistance(pos, fEntityPos) < 0.1)
				return entity;
		}
	}
	
	return -1;
}

/*
* Finds a button in the database by its entity index
*/
stock FindDatabaseButtonByEntity(entity)
{
	new iSize = GetArraySize(g_hDatabaseMethodList);
	
	for(new idx; idx < iSize; idx++)
	{
		if(EntIndexToEntRef(entity) == GetArrayCell(g_hDatabaseMethodList, idx, ButtonEntity))
		{
			return idx;
		}
	}
	
	return -1;
}

/*
* Gets the m_iName property of a button or any other type of entity
*/
bool:GetButtonName(button, String:name[], maxlength)
{
	if(!IsValidEntity(button) || !IsValidEdict(button))
		return false;
	
	GetEntPropString(button, Prop_Data, "m_iName", name, maxlength);
	
	return true;
}

/*
* Adds a button to the list of map buttons that affect the timer
*/
AddToDatabaseMethodList(button, Method, Type, RowID, sprite)
{
	any[] Properties = new any[ButtonProperties];
	Properties[ButtonRowID]  = RowID;
	Properties[ButtonMethod] = Method;
	Properties[ButtonType]   = Type;
	
	if(button != -1)
	{
		Properties[ButtonEntity] = EntIndexToEntRef(button);
	}
	
	if(sprite != -1)
	{
		Properties[ButtonSpriteEntity] = EntIndexToEntRef(sprite);
	}
	
	return PushArrayArray(g_hDatabaseMethodList, Properties);
}