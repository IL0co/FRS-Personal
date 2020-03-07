#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <csgo_colors>
#include <clientprefs>
#include <FakeRank_Sync>

KeyValues kv;
bool myBool[MAXPLAYERS+1];
Handle g_hCookie_enable;
int myIdBuff[MAXPLAYERS+1];

#define IND "personal"

public Plugin myinfo = 
{
	name		= "[FRS] Personal",
	version		= "1.2",
	description	= "Personal fakeranks",
	author		= "ღ λŌK0ЌЭŦ ღ ™",
	url			= "https://hlmod.ru/resources/custom-fakerank.1271/"
}

public void OnPluginEnd()
{
	FRS_UnRegisterMe();
}

public void OnPluginStart()
{
	RegAdminCmd("sm_reload_perconal_cfg", Command_Reload, ADMFLAG_ROOT);
	RegConsoleCmd("sm_cfr", Cmd_Toggle, "On/Off draw Personal FakeRank");
	LoadTranslations("FRS_Personal.phrases");

	g_hCookie_enable = RegClientCookie("CustomFakeRank_Enable", "CustomFakeRank_Enable", CookieAccess_Private);

	ReadConfig();
	FRS_OnCoreLoaded();

	for(int i = 1; i <= MaxClients; i++) if(IsClientAuthorized(i) && IsClientInGame(i))
	{
		FRS_OnClientLoaded(i);
	}
}

public void FRS_OnCoreLoaded()
{
	FRS_RegisterKey(IND);
}

public void FRS_OnClientLoaded(int client)
{
	myBool[client] = false;	
	myIdBuff[client] = ApplyRank(client);
	CheckCookie(client);
	FRS_SetClientRankId(client, myIdBuff[client], IND);
}

public void OnMapStart()
{
	ReadConfig();
}

public Action Cmd_Toggle(int client, int args)
{
	if(!client) return Plugin_Continue;

	if(myBool[client])
	{
		char buff2[4];
		GetClientCookie(client, g_hCookie_enable, buff2, sizeof(buff2));

		bool off = !StringToInt(buff2);
		SetClientCookie(client, g_hCookie_enable, off ? "1" : "0");
		CGOPrintToChat(client, "%t", off ? "Enable Rank" : "Disable Rank");
		CheckCookie(client);
	}
	else CGOPrintToChat(client, "%t", "No Available Rank");

	return Plugin_Handled;
}

public Action Command_Reload(int client, int args)
{
	ReadConfig();
	
	for (int i = 1; i <= MaxClients; i++)	if (IsClientInGame(i) && IsClientAuthorized(i))
	{
		FRS_OnClientLoaded(i);
	}

	ReplyToCommand(client, "[Custom FakeRank] - Файл конфигураций перезагружен!");
	
	return Plugin_Handled;
}

stock void ReadConfig()
{
	if(kv) delete kv;
	kv = new KeyValues("Custom_FakeRanks");
	
	if(!kv.ImportFromFile("addons/sourcemod/configs/FRS_Personal.txt")) SetFailState("[Custom FakeRank] - Файл конфигураций не найден");
	char szBuffer[256], buff[64];
	static const char Groupses[][] = {"Groups", "Names", "Flags",  "Ips", "SteamIds"};

	FormatEx(szBuffer, sizeof(szBuffer), "materials/panorama/images/icons/skillgroups/skillgroup%i.svg", kv.GetNum("all"));
	if(FileExists(szBuffer))	AddFileToDownloadsTable(szBuffer);

	for(int i = 0; i <= 4; i++)
	{
		if(kv.JumpToKey(Groupses[i]) && kv.GotoFirstSubKey(false))
		{
			do
			{
				kv.GetSectionName(buff, sizeof(buff));
				kv.GoBack();

				FormatEx(szBuffer, sizeof(szBuffer), "materials/panorama/images/icons/skillgroups/skillgroup%i.svg", kv.GetNum(buff));
				if(FileExists(szBuffer))	AddFileToDownloadsTable(szBuffer);

				kv.JumpToKey(buff, false);
			}
			while( KvGotoNextKey( kv, false ));
		} 
		kv.Rewind();
	}
	
}

stock int ApplyRank(int client)
{
	int val;
	char buffer[64];
	kv.Rewind();

	GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
	if(kv.JumpToKey("SteamIds") && (val = kv.GetNum(buffer, 0)))
	{
		myBool[client] = true;
		return val;
	}
	kv.Rewind();

	GetClientIP(client, buffer, sizeof(buffer));
	if(kv.JumpToKey("Ips") && (val = kv.GetNum(buffer, 0)))
	{
		myBool[client] = true;
		return val;
	}
	kv.Rewind();

	GetClientName(client, buffer, sizeof(buffer));
	if(kv.JumpToKey("Names") && (val = kv.GetNum(buffer, 0)))
	{
		myBool[client] = true;
		return val;
	}
	kv.Rewind();

	if(kv.JumpToKey("Groups"))
	{
		AdminId id = GetUserAdmin(client);
		if(id != INVALID_ADMIN_ID) for(int i, num = GetAdminGroupCount(id); i < num; i++)
			if(GetAdminGroup(id, i, buffer, sizeof(buffer)) != INVALID_GROUP_ID && (val = kv.GetNum(buffer, 0)))
			{
				myBool[client] = true;
				return val;
			}
	}
	kv.Rewind();

	int flags = GetUserFlagBits(client);
	if(kv.JumpToKey("Flags") && kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(buffer, sizeof(buffer));
			kv.GoBack();
			if(flags & ReadFlagString(buffer))
			{
				myBool[client] = true;
				return kv.GetNum(buffer, 0);
			}
			kv.JumpToKey(buffer, false);
		}
		while(kv.GotoNextKey(false));
	}
	kv.Rewind();

	if((val = kv.GetNum("all", 0)))
	{
		myBool[client] = true;
		return val;
	}
	return 0;
}

stock void CheckCookie(int client)
{
	if(IsFakeClient(client))
		return;

	char buff[3];
	GetClientCookie(client, g_hCookie_enable, buff, sizeof(buff));

	if(!StringToInt(buff))	FRS_SetClientRankId(client, 0, IND);
	else	FRS_SetClientRankId(client, myIdBuff[client], IND);
}
