#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sourcemod>
#include <csgo_colors>
#include <clientprefs>
#include <FakeRank_Sync>

KeyValues kv;
Cookie gCookie;

#define IND "personal"

public Plugin myinfo = 
{
	name		= "[FRS] Personal",
	version		= "1.2.1",
	description	= "Personal fakeranks",
	author		= "iLoco",
	url			= "https://github.com/IL0co"
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

	gCookie = new Cookie("CustomFakeRank_Enable", "CustomFakeRank_Enable", CookieAccess_Private);
	SetCookieMenuItem(CookieHendler_Enable, 0, "CustomFakeRank_Enable");

	LoadCfg();
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
	int id;
	eSides align;
	if(CheckClientCookie(client))
	{
		id = GetClientRank(client, align);
		FRS_SetClientRankId(client, (id), IND, align);
	}
}

public void OnMapStart()
{
	LoadCfg();
}

public void CookieHendler_Enable(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
			FormatEx(buffer, maxlen, "%T", "Menu. Cookie", client, (CheckClientCookie(client) ? "Menu. Plus" : "Menu. Minus"));
		}
		case CookieMenuAction_SelectOption:
		{
			if(CheckClientCookie(client))
			{
				FRS_SetClientRankId(client, 0, IND, Right);
				gCookie.Set(client, "0");
			}
			else
			{
				eSides align;
				int id = GetClientRank(client, align);
				gCookie.Set(client, "1");
				FRS_SetClientRankId(client, id, IND, align);
			}

			ShowCookieMenu(client);
		}
	}
}

public Action Cmd_Toggle(int client, int args)
{
	if(!client) 
		return Plugin_Continue;

	if(CheckClientCookie(client))
	{
		CGOPrintToChat(client, "%t", "Disable Rank");
		FRS_SetClientRankId(client, 0, IND, Right);
		gCookie.Set(client, "0");
	}
	else
	{
		eSides align;
		int id = GetClientRank(client, align);
		CGOPrintToChat(client, "%t", "Enable Rank");
		gCookie.Set(client, "1");
		FRS_SetClientRankId(client, id, IND, align);
	}

	return Plugin_Handled;
}

public Action Command_Reload(int client, int args)
{
	LoadCfg();
	
	for (int i = 1; i <= MaxClients; i++)	if (IsClientInGame(i) && IsClientAuthorized(i))
	{
		FRS_OnClientLoaded(i);
	}

	ReplyToCommand(client, "[Custom FakeRank] - Файл конфигураций перезагружен!");
	
	return Plugin_Handled;
}

stock int GetClientRank(int client, eSides &align)
{
	char buffer[64];
	kv.Rewind();

	GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
	if(kv.JumpToKey("SteamIds") && kv.JumpToKey(buffer))
	{
		align = (kv.GetNum("align", 1) == 1 ? Right : Left);
		return kv.GetNum("id", 0);
	}
	kv.Rewind();

	GetClientIP(client, buffer, sizeof(buffer));
	if(kv.JumpToKey("Ips") && kv.JumpToKey(buffer))
	{
		align = (kv.GetNum("align", 1) == 1 ? Right : Left);
		return kv.GetNum("id", 0);
	}
	kv.Rewind();

	GetClientName(client, buffer, sizeof(buffer));
	if(kv.JumpToKey("Names") && kv.JumpToKey(buffer))
	{
		align = (kv.GetNum("align", 1) == 1 ? Right : Left);
		return kv.GetNum("id", 0);
	}
	kv.Rewind();

	if(kv.JumpToKey("Groups"))
	{
		AdminId id = GetUserAdmin(client);
		if(id != INVALID_ADMIN_ID) for(int i, num = GetAdminGroupCount(id); i < num; i++)
		{
			if(GetAdminGroup(id, i, buffer, sizeof(buffer)) != INVALID_GROUP_ID && kv.JumpToKey(buffer))
			{
				align = (kv.GetNum("align", 1) == 1 ? Right : Left);
				return kv.GetNum("id", 0);
			}
		}
	}
	kv.Rewind();

	int flags = GetUserFlagBits(client);
	if(kv.JumpToKey("Flags") && kv.GotoFirstSubKey())
	{
		do
		{
			kv.GetSectionName(buffer, sizeof(buffer));
			if(flags & ReadFlagString(buffer))
			{
				align = (kv.GetNum("align", 1) == 1 ? Right : Left);
				return kv.GetNum("id", 0);
			}
		}
		while(kv.GotoNextKey());
	}
	kv.Rewind();

	if(kv.JumpToKey("all"))
	{
		align = (kv.GetNum("align", 1) == 1 ? Right : Left);
		return kv.GetNum("id", 0);
	}

	return 0;
}

stock bool CheckClientCookie(int client)
{
	if(IsFakeClient(client))
		return false;

	char buff[3];
	gCookie.Get(client, buff, sizeof(buff));

	if(buff[0] == '0') 
		return false;

	return true;
}

stock void LoadCfg()
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
