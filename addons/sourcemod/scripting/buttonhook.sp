#include <sourcemod>
#include <buttonhook>

Handle g_hFwdOnButtonPressed;

int g_LastButtons[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hFwdOnButtonPressed = CreateGlobalForward("OnButtonPressed", ET_Event, Param_Cell, Param_Cell);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int buttonsPressed;
	for(int i; i < 32; i++)
	{
		if((buttons & (1 << i)) && !(g_LastButtons[client] & (1 << i)))
		{
			buttonsPressed |= (1 << i);
		}
	}
	
	if(buttonsPressed != 0)
	{
		Call_StartForward(g_hFwdOnButtonPressed);
		Call_PushCell(client);
		Call_PushCell(buttonsPressed);
		Call_Finish();
	}

	g_LastButtons[client] = buttons;
}