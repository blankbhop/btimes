new Address:addy;
new bool:Linux;

public OnPluginStart()
{
	addy = GameConfGetAddress(LoadGameConfigFile("TeamFullPatch2"), "TEAMFULL_2");
	
	if (GetEngineVersion() == Engine_CSS)
	{
		new OS = LoadFromAddress(addy + Address:1, NumberType_Int8);
		switch(OS)
		{
			case 0x31: //Linux
			{
				StoreToAddress(addy + Address:357, 0x90, NumberType_Int8);
				StoreToAddress(addy + Address:358, 0xE9, NumberType_Int8);
				Linux = true;
			}
			case 0x8B: //Windows
			{
				StoreToAddress(addy + Address:687, 0xEB, NumberType_Int8);
				Linux = false;
			}
			default:
			{
				SetFailState("TeamFullFix Signature Incorrect. (0x%x)", OS);
			}
		}
	} 
	else if (GetEngineVersion() == Engine_CSGO)
	{
		new OS = LoadFromAddress(addy + Address:1, NumberType_Int8);
		switch(OS)
		{
			case 0x89: //Linux
			{
				StoreToAddress(addy + Address:242, 0x90, NumberType_Int8);
				StoreToAddress(addy + Address:243, 0xE9, NumberType_Int8);
				Linux = true;
			}
			case 0x8B: //Windows
			{
				StoreToAddress(addy + Address:770, 0xEB, NumberType_Int8);
				Linux = false;
			}
			default:
			{
				SetFailState("TeamFullFix Signature Incorrect. (0x%x)", OS);
			}
		}
	}
	else
		SetFailState("GameMode Not Supported (%s)", GetEngineVersion());
}

public OnPluginEnd()
{
	if (GetEngineVersion() == Engine_CSS)
	{
		if(Linux)
		{
			StoreToAddress(addy + Address:357, 0x0F, NumberType_Int8);
			StoreToAddress(addy + Address:358, 0x84, NumberType_Int8);
		}
		else
		{
			StoreToAddress(addy + Address:687, 0x74, NumberType_Int8);
		}
	}
	else if (GetEngineVersion() == Engine_CSGO)
	{
		if(Linux)
		{
			StoreToAddress(addy + Address:242, 0x0F, NumberType_Int8);
			StoreToAddress(addy + Address:243, 0x84, NumberType_Int8);
		}
		else
		{
			StoreToAddress(addy + Address:770, 0x74, NumberType_Int8);
		}
	}
	else
		SetFailState("GameMode Not Supported (%s)", GetEngineVersion());
}