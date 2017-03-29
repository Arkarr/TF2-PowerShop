#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <tf2attributes>

#pragma newdecls required

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"1.0"
#define PLUGIN_TAG 		"{purple}[TF2 Power Shop]{default}"

#define TEAM_LESS 	0
#define TEAM_SPEC 	1
#define TEAM_RED 	2
#define TEAM_BLU 	3

#define MENU_OPTION_PU 0
#define MENU_OPTION_WU 1
#define MENU_OPTION_OU 2
#define MENU_OPTION_RA 3

#define MENU_OPTION_PREVIOUS 7

#define MENU_OPTION_YES 3
#define MENU_OPTION_NO 	4

#define MENU_MAINMENU 0
#define MENU_PHYSIUPG 1
#define MENU_WEAPOUPG 2
#define MENU_OTHERUPG 3
#define MENU_REFUNUPG 4

#define UPGRADE_PHYSI 1
#define UPGRADE_WEAPO 2
#define UPGRADE_OTHER 3

#define QUERY_CREATE_T_CLIENTS		"CREATE TABLE IF NOT EXISTS `PowerShop`.`t_client` (`client_steamid64` VARCHAR(50) NOT NULL,`client_credits` INT(11) NOT NULL,`client_name` VARCHAR(50) NOT NULL,PRIMARY KEY (`client_steamid64`))ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;"
#define QUERY_CREATE_T_UPGRADES		"CREATE TABLE IF NOT EXISTS `PowerShop`.`t_upgrade` ( `upgrade_id` INT(11) NOT NULL, `upgrade_name` VARCHAR(45) NOT NULL, `upgrade_type` VARCHAR(15) NOT NULL, `upgrade_cost` INT(11) NOT NULL, `upgrade_description1` VARCHAR(100) NOT NULL, `upgrade_description2` VARCHAR(100) NOT NULL, `upgrade_maxvalue` DOUBLE NOT NULL, `upgrade_increasevalue` DOUBLE NOT NULL, `upgrade_defaultvalue` DOUBLE NOT NULL, `upgrade_attributname` VARCHAR(100) NOT NULL, PRIMARY KEY (`upgrade_id`))  ENGINE = InnoDB  DEFAULT CHARACTER SET = latin1;"
#define QUERY_RESET_T_CLIENTUPGRADE	"CREATE TABLE IF NOT EXISTS `PowerShop`.`t_clientupgrade` ( `clientupgrade_currentvalue` VARCHAR(50) NOT NULL,`clientupgrade_attributname` VARCHAR(100) NOT NULL, `clientupgrade_spent` INT(11) NOT NULL, `has_changed` INT(11) NOT NULL, `t_client_steamid64` VARCHAR(50) NOT NULL, `t_upgrade_id` INT(11) NOT NULL AUTO_INCREMENT, INDEX `fk_t_clientupgrade_t_client1_idx` (`t_client_steamid64` ASC), INDEX `fk_t_clientupgrade_t_upgrade1_idx` (`t_upgrade_id` ASC), CONSTRAINT PK_Person PRIMARY KEY (`t_upgrade_id`))  ENGINE = InnoDB  DEFAULT CHARACTER SET = latin1;"
#define QUERY_GET_CLIENT_INFOS		"SELECT `client_credits`,`client_name` FROM `PowerShop`.`t_client` WHERE `client_steamid64`=\"%s\""
#define QUERY_UPDATE_CLIENT_INFOS	"UPDATE `PowerShop`.`t_client` SET `client_name`=\"%s\", `client_credits`=%i WHERE `client_steamid64`=\"%s\";"
#define QUERY_INSERT_CLIENT			"INSERT INTO `PowerShop`.`t_client` (`client_steamid64`,`client_name`,`client_credits`) VALUES (\"%s\", \"%s\", %i);"
#define QUERY_INSERT_UPGRADE		"INSERT INTO `PowerShop`.`t_upgrade` (`upgrade_id`, `upgrade_name`, `upgrade_type`, `upgrade_cost`, `upgrade_description1`, `upgrade_description2`, `upgrade_maxvalue`, `upgrade_increasevalue`, `upgrade_defaultvalue`, `upgrade_attributname`) VALUES (\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\");"
#define QUERY_SELECT_UPGRADE		"SELECT `upgrade_id`, `upgrade_type`, `upgrade_cost`, `upgrade_maxvalue`, `upgrade_increasevalue`, `upgrade_defaultvalue`, `upgrade_attributname` FROM `PowerShop`.`t_upgrade` WHERE `upgrade_id`=\"%s\""
#define QUERY_UPDATE_UPGRADE		"UPDATE `PowerShop`.`t_upgrade` SET `upgrade_type`=\"%s\", `upgrade_cost`=\"%s\", `upgrade_maxvalue`=\"%s\", `upgrade_increasevalue`=\"%s\", `upgrade_defaultvalue`=\"%s\", `upgrade_attributname`=\"%s\", `upgrade_description1`=\"%s\", `upgrade_description2`=\"%s\" WHERE `upgrade_id`=\"%i\""
#define QUERY_UPDATE_CLIENTUPGRADE	"UPDATE `PowerShop`.`t_clientupgrade` SET `has_changed` = 1 WHERE `t_upgrade_id`=\"%i\""
#define QUERY_SELECT_UPGRADECLIENTC	"SELECT `clientupgrade_spent` FROM `PowerShop`.`t_clientupgrade` WHERE `t_client_steamid64`=\"%s\" AND `has_changed`=1"
#define QUERY_UPDATE_CLIENTCREDIT	"UPDATE `PowerShop`.`t_client` SET `client_credits`=`client_credits`+%i WHERE `client_steamid64`=\"%s\""
#define QUERY_DELETE_CLIENTUPGRADEC	"DELETE FROM `PowerShop`.`t_clientupgrade` WHERE `has_changed`=1 AND `t_client_steamid64`=\"%s\"; "
#define QUERY_SELECT_CLIENTUPGRADE	"SELECT `clientupgrade_attributname`, `clientupgrade_currentvalue` FROM `PowerShop`.`t_clientupgrade` WHERE `t_client_steamid64`=\"%s\"; "
#define QUERY_SELECT_CLIENTUPBYID	"SELECT `clientupgrade_attributname`, `clientupgrade_currentvalue`, `clientupgrade_spent` FROM `PowerShop`.`t_clientupgrade` WHERE `t_client_steamid64`=\"%s\" AND `t_upgrade_id`=\"%i\";"
#define QUERY_UPDATE_CLIENTUPBYID	"UPDATE `PowerShop`.`t_clientupgrade` SET `clientupgrade_currentvalue`=\"%.2f\", `clientupgrade_spent`=%i WHERE `t_client_steamid64`=\"%s\" AND `t_upgrade_id`=\"%i\";"
#define QUERY_INSERT_CLIENTUPBYID	"INSERT INTO `PowerShop`.`t_clientupgrade` (`clientupgrade_currentvalue`, `clientupgrade_attributname`, `clientupgrade_spent`, `has_changed`, `t_client_steamid64`, `t_upgrade_id`) VALUES ('%.2f', '%s', '%i', '0', '%s', '%i')"
#define QUERY_DELETE_ALLBOUGHTUPGRD	"DELETE FROM `PowerShop`.`t_clientupgrade` WHERE `t_client_steamid64`=\"%s\";"
#define QUERY_SELECT_ALLUPGRDCLIENT	"SELECT `clientupgrade_spent` FROM `PowerShop`.`t_clientupgrade` WHERE `t_client_steamid64`=\"%s\""

Transaction DBTRANS_UpdateUpgrade;
Transaction DBTRANS_SelectBoughtUpgrade;

Handle CVAR_KillCredit;
Handle CVAR_TeamWinCredit;
Handle CVAR_TeamLostCredit;
Handle CVAR_TimedCredit;
Handle CVAR_DeathDeduction;
Handle CVAR_CommandRestriction;
Handle CVAR_DBConfigurationName;
Handle ARRAY_Upgrades;
Handle DATABASE_PowerShop;

int credits[MAXPLAYERS + 1];
int upgradeID[MAXPLAYERS + 1];
int upgradeCost[MAXPLAYERS + 1];
int roundLoose[4];
int actualMenu[MAXPLAYERS + 1];
int priceToPay[MAXPLAYERS + 1];
int queryUpgradeCount;

float propValue[MAXPLAYERS + 1];
float defaultVal[MAXPLAYERS + 1];

char clientProp[MAXPLAYERS + 1][125];
char attributID[10];
char attributName[100];
char defaultValue[10];
char increaseValue[10];
char maxValue[10];
char descriptionLine1[100];
char descriptionLine2[100];
char coststr[10];
char upgradetype[30];
char menuItemName[45];

bool isAttributes[MAXPLAYERS + 1];
bool debugMode = true; //false;

public Plugin myinfo = 
{
	name = "[TF2] Power Shop", 
	author = PLUGIN_AUTHOR, 
	description = "A shop.", 
	version = PLUGIN_VERSION, 
	url = "www.sourcemod.net"
};

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("teamplay_round_win", Event_TeamWin);
	
	CVAR_KillCredit = CreateConVar("sm_tf2ps_kill_credits", "3", "How much credits to give on kill.", _, true, _, false, _);
	CVAR_TeamWinCredit = CreateConVar("sm_tf2ps_teamWin_credits", "10", "How much credits to give on team win.", _, true, _, false, _);
	CVAR_TeamLostCredit = CreateConVar("sm_tf2ps_teamLooseX3_credits", "30", "How much credits to give on team loose x 3.", _, true, _, false, _);
	CVAR_TimedCredit = CreateConVar("sm_tf2ps_time_credits", "10", "How much credits to give on every 90 seconds.", _, true, _, false, _);
	CVAR_DeathDeduction = CreateConVar("sm_tf2ps_death_deduction", "5", "How much credit to deduct when you die.", _, true, _, false, _);
	CVAR_CommandRestriction = CreateConVar("sm_tf2ps_shop_restriction", "-1", "Restric the command !shop to 1 team only. (-1 no restriction, 0 RED only, 1 BLU only)", _, true, -1.0, true, 1.0);
	CVAR_DBConfigurationName = CreateConVar("sm_tf2ps_configuration_name", "powershop", "Configuration name in database.cfg, by default, all results are saved in the sqlite database.");
	
	RegConsoleCmd("sm_shop", CMD_DisplayShop, "Display the shop menu.");
	RegConsoleCmd("sm_credits", CMD_DisplayCredits, "Display the your credits ammount.");
	RegAdminCmd("sm_addcredit", CMD_AddCredits, ADMFLAG_CHEATS, "Add credits to a player.");
	
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClient(i))
		{
			Handle hHudText = CreateHudSynchronizer();
			SetHudTextParams(0.14, 0.9, 0.5, 0, 255, 0, 255, 0, 0.00001, 0.000001, 0.000001);
			ShowSyncHudText(i, hHudText, "Credits : %i", credits[i]);
			CloseHandle(hHudText);
		}
	}
	
	ARRAY_Upgrades = CreateArray();
	
	LoadTranslations("common.phrases");
	LoadTranslations("powershop.phrases");
	
	AutoExecConfig(true, "Powershop");
}

public void OnConfigsExecuted()
{
	char dbconfig[45];
	GetConVarString(CVAR_DBConfigurationName, dbconfig, sizeof(dbconfig));
	SQL_TConnect(GotDatabase, dbconfig);
}

public void OnClientPostAdminFilter(int client)
{
	char query[400];
	char steamID[45];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	Format(query, sizeof(query), QUERY_SELECT_UPGRADECLIENTC, steamID);
	SQL_TQuery(DATABASE_PowerShop, RefundClient, query, GetClientUserId(client));
	
	Format(query, sizeof(query), QUERY_SELECT_CLIENTUPGRADE, steamID);
	SQL_TQuery(DATABASE_PowerShop, GetClientUpgrades, query, GetClientUserId(client));
}

public void OnClientDisconnect(int client)
{
	char query[200];
	char steamID[45];
	char clientName[45];
	
	GetClientName(client, clientName, sizeof(clientName));
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	SQL_EscapeString(DATABASE_PowerShop, clientName, clientName, sizeof(clientName));
	
	PrintToServer(">>>> %i", credits[client]);
	Format(query, sizeof(query), QUERY_UPDATE_CLIENT_INFOS, clientName, credits[client], steamID);
	
	DBFastQuery(query);
}

public void OnMapStart()
{
	roundLoose[TEAM_RED] = 0;
	roundLoose[TEAM_BLU] = 0;
	
	for (int i = MaxClients; i > 0; --i)
	credits[i] = 0;
	
	CreateTimer(0.49, RefreshCreditsHUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(90.0, TMR_AddCredit, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

//////////////////
//    COMMANDS  //
//////////////////
public Action CMD_AddCredits(int client, int args)
{
	if (args != 2)
	{
		CPrintToChat(client, "%s Usage : sm_addcredit <target> <ammount>.", PLUGIN_TAG);
		return Plugin_Handled;
	}
	
	char arg1[10];
	char arg2[10];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1, true);
	
	if (target != -1)
	{
		credits[target] += StringToInt(arg2);
		CPrintToChat(client, "%s Sucessfully added %s credit to %N (%i credits)", PLUGIN_TAG, arg2, target, credits[target]);
	}
	
	return Plugin_Handled;
}

public Action CMD_DisplayShop(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "Damn it ! Waht are you trying to do ?! This is a game command only !");
		return Plugin_Handled;
	}
	
	if (GetConVarInt(CVAR_CommandRestriction) == -1)
		DisplayMainMenu(client);
	else if (GetClientTeam(client) == GetConVarInt(CVAR_CommandRestriction) + 2)
		DisplayMainMenu(client);
	else
		CPrintToChat(client, "%s Your team is not allowed to use !shop !", PLUGIN_TAG);
	
	
	return Plugin_Handled;
}

public Action CMD_DisplayCredits(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "Damn it ! Waht are you trying to do ?! This is a game command only !");
		return Plugin_Handled;
	}
	
	CPrintToChat(client, "%s You have %i credits.", PLUGIN_TAG, credits[client]);
	
	return Plugin_Handled;
}


//////////////////
// MENU HANDLER //
//////////////////
public int MenuHandle_MainMenu(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		char description[32];
		GetMenuItem(menu, itemIndex, description, sizeof(description));
		if (itemIndex == MENU_OPTION_PU)
		{
			DisplayPUMenu(client);
		}
		else if (itemIndex == MENU_OPTION_WU)
		{
			DisplayWUMenu(client);
		}
		else if (itemIndex == MENU_OPTION_OU)
		{
			DisplayOUMenu(client);
		}
		else if (itemIndex == MENU_OPTION_RA)
		{
			DisplayRAMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public int MenuHandle_OptionChoose(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		char description[32];
		char line3[125];
		GetMenuItem(menu, itemIndex, description, sizeof(description));
		
		Handle tmpHashMap = GetArrayCell(ARRAY_Upgrades, StringToInt(description));
		
		if (StrEqual(description, "return"))
		{
			DisplayPreviousMenu(client);
			return;
		}
		
		if (tmpHashMap != INVALID_HANDLE)
		{
			char upTrieID[10];
			GetTrieString(tmpHashMap, "attributName", attributName, sizeof(attributName));
			GetTrieString(tmpHashMap, "defaultValue", defaultValue, sizeof(defaultValue));
			GetTrieString(tmpHashMap, "descriptionLine1", descriptionLine1, sizeof(descriptionLine1));
			GetTrieString(tmpHashMap, "descriptionLine2", descriptionLine2, sizeof(descriptionLine2));
			GetTrieString(tmpHashMap, "maxValue", maxValue, sizeof(maxValue));
			GetTrieString(tmpHashMap, "increaseValue", increaseValue, sizeof(increaseValue));
			GetTrieString(tmpHashMap, "cost", coststr, sizeof(coststr));
			GetTrieString(tmpHashMap, "attributID", upTrieID, sizeof(upTrieID));
			
			float result = StringToFloat(defaultValue);
			Address address = TF2Attrib_GetByName(client, attributName);
			if (address != Address_Null)
				result = TF2Attrib_GetValue(address);
			
			
			if (result >= StringToFloat(maxValue) && StringToFloat(maxValue) > 0.0)
			{
				CPrintToChat(client, "%s Sorry, you can't buy this upgrade anymore.", PLUGIN_TAG);
				DisplayPreviousMenu(client);
			}
			else if (result <= StringToFloat(maxValue) && StringToFloat(maxValue) < 0.0)
			{
				CPrintToChat(client, "%s Sorry, you can't buy this upgrade anymore.", PLUGIN_TAG);
				DisplayPreviousMenu(client);
			}
			else
			{
				Format(line3, sizeof(line3), "Your upgrade value is : %.2f", result);
				DisplayInfoPanel(client, descriptionLine1, descriptionLine2, line3, StringToInt(coststr));
				
				Format(clientProp[client], 125, attributName);
				propValue[client] = StringToFloat(increaseValue);
				defaultVal[client] = StringToFloat(defaultValue);
				isAttributes[client] = true;
				upgradeCost[client] = StringToInt(coststr);
				upgradeID[client] = StringToInt(upTrieID);
			}
		}
		else if (itemIndex == MENU_OPTION_PREVIOUS)
		{
			DisplayMainMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public int MenuHandle_YesNo(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		if (itemIndex == MENU_OPTION_YES)
		{
			ApplyUpgrades(client, clientProp[client], propValue[client], isAttributes[client]);
			credits[client] -= priceToPay[client];
			
			char query[500];
			char steamID64[50];
			GetClientAuthId(client, AuthId_SteamID64, steamID64, sizeof(steamID64));
			Format(query, sizeof(query), QUERY_SELECT_CLIENTUPBYID, steamID64, upgradeID[client]);
			SQL_TQuery(DATABASE_PowerShop, SetClientUpgrade, query, GetClientUserId(client));
		}
		DisplayPreviousMenu(client);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

/////////////////
//	 EVENTS    //
/////////////////

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (attacker == 0 || victim == attacker)
		return Plugin_Continue;
	
	int creditKill = GetConVarInt(CVAR_KillCredit);
	int creditDeath = GetConVarInt(CVAR_DeathDeduction);
	
	credits[attacker] += creditKill;
	credits[victim] -= creditDeath;
	
	if (IsValidClient(attacker) && IsValidClient(victim))
		CPrintToChat(attacker, "%s You got {green}+%i{default} credits for killing %N !", PLUGIN_TAG, creditKill, victim);
	
	if (IsValidClient(victim))
		CPrintToChat(victim, "%s You lost {green}-%i{default} credits for dying !", PLUGIN_TAG, creditDeath);
	
	return Plugin_Continue;
}

public Action Event_TeamWin(Handle event, const char[] name, bool dontBroadcast)
{
	int WinnerTeam = GetEventInt(event, "team");
	bool AddLoosersCredit = false;
	
	if (WinnerTeam != TEAM_RED) //BLU won.
	{
		roundLoose[TEAM_RED]++;
		if (roundLoose[TEAM_RED] == 3)
		{
			roundLoose[TEAM_RED] = 0;
			AddLoosersCredit = true;
		}
	}
	else //RED won.
	{
		roundLoose[TEAM_BLU]++;
		if (roundLoose[TEAM_BLU] == 3)
		{
			roundLoose[TEAM_BLU] = 0;
			AddLoosersCredit = true;
		}
	}
	
	int creditTeamWin = GetConVarInt(CVAR_TeamWinCredit);
	int creditTeamLost = GetConVarInt(CVAR_TeamLostCredit);
	
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClient(i))
		{
			if (GetClientTeam(i) == WinnerTeam)
			{
				credits[i] += creditTeamWin;
				CPrintToChat(i, "%s You got {green}+%i{default} credits for winning this round !", PLUGIN_TAG, creditTeamLost);
			}
			else if (AddLoosersCredit)
			{
				credits[i] += creditTeamLost;
				CPrintToChat(i, "%s You got {green}+%i{default} credits for loosing 3 round in a row !", PLUGIN_TAG, creditTeamLost);
			}
		}
	}
	
	return Plugin_Continue;
}


/////////////////
//	  MENU     //
/////////////////
public void DisplayMainMenu(int client)
{
	actualMenu[client] = MENU_MAINMENU;
	Handle menu = CreateMenu(MenuHandle_MainMenu);
	SetMenuTitle(menu, "Power Shop - %i Credits", credits[client]);
	AddMenuItem(menu, "physUpg", "Physical Upgrades");
	AddMenuItem(menu, "WeapUpg", "Weapon Upgrades");
	AddMenuItem(menu, "OtheUpg", "Other Upgrades");
	AddMenuItem(menu, "RefuAll", "Refund All");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void DisplayPUMenu(int client)
{
	actualMenu[client] = MENU_PHYSIUPG;
	Handle menu = CreateMenu(MenuHandle_OptionChoose);
	bool itemFound = false;
	SetMenuTitle(menu, "Power Shop [Phys Upg] - %i Credits", credits[client]);
	for (int i = 0; i < GetArraySize(ARRAY_Upgrades); i++)
	{
		Handle tmpHashMap = GetArrayCell(ARRAY_Upgrades, i);
		
		if (tmpHashMap != INVALID_HANDLE)
		{
			GetTrieString(tmpHashMap, "upgradetype", upgradetype, sizeof(upgradetype));
			if (StringToInt(upgradetype) == UPGRADE_PHYSI)
			{
				char strIndex[10];
				GetTrieString(tmpHashMap, "menuItemName", menuItemName, sizeof(menuItemName));
				IntToString(i, strIndex, sizeof(strIndex));
				AddMenuItem(menu, strIndex, menuItemName);
				itemFound = true;
			}
		}
		else
		{
			CPrintToChat(client, "%s No items found !", PLUGIN_TAG);
			DisplayPreviousMenu(client);
		}
	}
	
	if (itemFound)
	{
		AddMenuItem(menu, "return", "Back");
	}
	else
	{
		CPrintToChat(client, "%s No items found !", PLUGIN_TAG);
		DisplayPreviousMenu(client);
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void DisplayWUMenu(int client)
{
	actualMenu[client] = MENU_WEAPOUPG;
	Handle menu = CreateMenu(MenuHandle_OptionChoose);
	bool itemFound = false;
	SetMenuTitle(menu, "Power Shop [Weap Upg] - %i Credits", credits[client]);
	for (int i = 0; i < GetArraySize(ARRAY_Upgrades); i++)
	{
		Handle tmpHashMap = GetArrayCell(ARRAY_Upgrades, i);
		
		if (tmpHashMap != INVALID_HANDLE)
		{
			GetTrieString(tmpHashMap, "upgradetype", upgradetype, sizeof(upgradetype));
			if (StringToInt(upgradetype) == UPGRADE_WEAPO)
			{
				char strIndex[10];
				GetTrieString(tmpHashMap, "menuItemName", menuItemName, sizeof(menuItemName));
				IntToString(i, strIndex, sizeof(strIndex));
				AddMenuItem(menu, strIndex, menuItemName);
				itemFound = true;
			}
		}
		/*else
		{
			CPrintToChat(client, "%s No items found !", PLUGIN_TAG);
			DisplayPreviousMenu(client);	
		}*/
	}
	
	
	if (itemFound)
	{
		AddMenuItem(menu, "return", "Back");
	}
	else
	{
		CPrintToChat(client, "%s No items found !", PLUGIN_TAG);
		DisplayPreviousMenu(client);
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void DisplayOUMenu(int client)
{
	actualMenu[client] = MENU_OTHERUPG;
	bool itemFound = false
	Handle menu = CreateMenu(MenuHandle_OptionChoose);
	SetMenuTitle(menu, "Power Shop [Other Upg] - %i Credits", credits[client]);
	for (int i = 0; i < GetArraySize(ARRAY_Upgrades); i++)
	{
		Handle tmpHashMap = GetArrayCell(ARRAY_Upgrades, i);
		
		if (tmpHashMap != INVALID_HANDLE)
		{
			GetTrieString(tmpHashMap, "upgradetype", upgradetype, sizeof(upgradetype));
			if (StringToInt(upgradetype) == UPGRADE_OTHER)
			{
				char strIndex[10];
				GetTrieString(tmpHashMap, "menuItemName", menuItemName, sizeof(menuItemName));
				IntToString(i, strIndex, sizeof(strIndex));
				AddMenuItem(menu, strIndex, menuItemName);
				itemFound = true;
			}
		}
	}
	
	if (itemFound)
	{
		AddMenuItem(menu, "return", "Back");
	}
	else
	{
		CPrintToChat(client, "%s No items found !", PLUGIN_TAG);
		DisplayPreviousMenu(client);
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void DisplayRAMenu(int client)
{
	actualMenu[client] = MENU_REFUNUPG;
	
	char steamID[45];
	char query[300];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));

	Format(query, sizeof(query), QUERY_SELECT_ALLUPGRDCLIENT, steamID);
	SQL_TQuery(DATABASE_PowerShop, RefundAllClient, query, GetClientUserId(client));
	
	//CPrintToChat(client, "%s Na.", PLUGIN_TAG);
}

public void DisplayPreviousMenu(int client)
{
	/*if(actualMenu[client] == MENU_MAINMENU)
		DisplayMainMenu(client);
	else if(actualMenu[client] == MENU_PHYSIUPG)
		DisplayPUMenu(client);
	else if(actualMenu[client] == MENU_WEAPOUPG)
		DisplayWUMenu(client);
	else if(actualMenu[client] == MENU_OTHERUPG)
		DisplayOUMenu(client);
	else if(actualMenu[client] == MENU_REFUNUPG)
		DisplayRAMenu(client);*/
	DisplayMainMenu(client);
}

public void DisplayInfoPanel(int client, const char[] line1, const char[] line2, const char[] line3, int cost)
{
	if (cost > credits[client])
	{
		CPrintToChat(client, "%s You don't have enough credits !", PLUGIN_TAG);
		DisplayPreviousMenu(client);
	}
	else
	{
		priceToPay[client] = cost;
		char price[45];
		Format(price, sizeof(price), "Cost %i credits", cost);
		Handle panel = CreatePanel();
		SetPanelTitle(panel, "Upgrade information");
		DrawPanelItem(panel, "", ITEMDRAW_SPACER);
		DrawPanelText(panel, line1);
		DrawPanelText(panel, line2);
		DrawPanelText(panel, line3);
		DrawPanelText(panel, price);
		DrawPanelItem(panel, "", ITEMDRAW_SPACER);
		DrawPanelItem(panel, "Yes");
		DrawPanelItem(panel, "No");
		
		SendPanelToClient(panel, client, MenuHandle_YesNo, MENU_TIME_FOREVER);
		
		CloseHandle(panel);
	}
}

/////////////////
//	  TIMER    //
/////////////////
public Action TMR_QueryFinished(Handle tmr)
{
	if(queryUpgradeCount > 0)
	{
		CreateTimer(1.00, TMR_QueryFinished);
		return Plugin_Continue;
	}
	
	SQL_ExecuteTransaction(DATABASE_PowerShop, DBTRANS_UpdateUpgrade);
	SQL_ExecuteTransaction(DATABASE_PowerShop, DBTRANS_SelectBoughtUpgrade);
	
	return Plugin_Continue;
}

public Action TMR_AddCredit(Handle tmr)
{
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClient(i))
		{
			int credit = GetConVarInt(CVAR_TimedCredit);
			credits[i] += credit;
			CPrintToChat(i, "%s You got {green}+%i{default} bonus credits, thanks for playing on our server !", PLUGIN_TAG, credit);
		}
	}
	
	return Plugin_Continue;
}

public Action RefreshCreditsHUD(Handle tmr)
{
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClient(i))
		{
			SetHudTextParams(0.14, 0.9, 0.5, 0, 255, 0, 255, 0, 0.00001, 0.000001, 0.000001);
			ShowHudText(i, -1, "Credits : %i", credits[i]);
		}
	}
	
	return Plugin_Continue;
}

/////////////////
//	DATABASE   //
/////////////////
public void GotDatabase(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		SetFailState(error);
	}
	else
	{
		DATABASE_PowerShop = hndl;
		
		if (DBFastQuery(QUERY_CREATE_T_CLIENTS) && 
			DBFastQuery(QUERY_CREATE_T_UPGRADES) && 
			DBFastQuery(QUERY_RESET_T_CLIENTUPGRADE))
		{
			ReadConfigFile();
			
			PrintToServer("[TF2 Power Shop] Connected to the database sucessfully !");
		}
	}
}

public void RefundAllClient(Handle db, Handle results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (client == 0)
		return;
	
	if (results == INVALID_HANDLE)
	{
		SetFailState("%t", "Database_failed", error);
		return;
	}
	
	char query[400];
	char steamID[45];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	int credit = 0;
	while(SQL_FetchRow(results))
		credit += SQL_FetchInt(results, 0);

	Format(query, sizeof(query), QUERY_DELETE_ALLBOUGHTUPGRD, steamID);
	DBFastQuery(query);
	
	CPrintToChat(client, "%s Done ! +%i credits refunded !", PLUGIN_TAG, credit);
	
	TF2Attrib_RemoveAll(client);
	
	credits[client] += credit;
}




public void RefundClient(Handle db, Handle results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (client == 0)
		return;
	
	if (results == INVALID_HANDLE)
	{
		SetFailState("%t", "Database_failed", error);
		return;
	}
	
	char query[400];
	char steamID[45];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	int credit = 0;
	while(SQL_FetchRow(results))
		credit += SQL_FetchInt(results, 0);
		
	Format(query, sizeof(query), QUERY_UPDATE_CLIENTCREDIT, credit, steamID);
	DBFastQuery(query);
	Format(query, sizeof(query), QUERY_DELETE_CLIENTUPGRADEC, steamID);
	DBFastQuery(query);
	
	Format(query, sizeof(query), QUERY_GET_CLIENT_INFOS, steamID);
	SQL_TQuery(DATABASE_PowerShop, GetClientInfos, query, GetClientUserId(client));
}

public void GetClientUpgrades(Handle db, Handle results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (client == 0)
		return;
	
	if (results == INVALID_HANDLE)
	{
		SetFailState("%t", "Database_failed", error);
		return;
	}
	
	char attributname[100];
	char attributvalue[10];
	
	while(SQL_FetchRow(results))
	{
		SQL_FetchString(results, 0, attributname, sizeof(attributname));
		SQL_FetchString(results, 1, attributvalue, sizeof(attributvalue));
		
		ApplyUpgrades(client, attributname, StringToFloat(attributvalue), true);
	}
}

public void SetClientUpgrade(Handle db, Handle results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (client == 0)
		return;
	
	if (results == INVALID_HANDLE)
	{
		SetFailState("%t", "Database_failed", error);
		return;
	}
	
	char attrName[100];
	char attrValue[10];
	char creditsSpent[40];
	
	char steamID[45];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));

	char query[500];
	if(SQL_FetchRow(results))
	{
		SQL_FetchString(results, 0, attrName, sizeof(attrName));
		SQL_FetchString(results, 1, attrValue, sizeof(attrValue));
		SQL_FetchString(results, 2, creditsSpent, sizeof(creditsSpent));
		
		Format(query, sizeof(query), QUERY_UPDATE_CLIENTUPBYID, (StringToFloat(attrValue)+propValue[client]), StringToInt(creditsSpent)+upgradeCost[client],steamID, upgradeID[client]);
	}
	else
	{
		Format(query, sizeof(query), QUERY_INSERT_CLIENTUPBYID, (StringToFloat(attrValue)+propValue[client]), clientProp[client], upgradeCost[client], steamID, upgradeID[client]);
	}
		
	DBFastQuery(query);
}

public void GetClientInfos(Handle db, Handle results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (client == 0)
		return;
	
	if (results == INVALID_HANDLE)
	{
		SetFailState("%t", "Database_failed", error);
		return;
	}
	
	char query[400];
	char steamID[45];
	char clientName[45];
	char sqlClientName[45];
	
	GetClientName(client, clientName, sizeof(clientName));
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	if (SQL_FetchRow(results))
	{
		credits[client] = SQL_FetchInt(results, 0);
		SQL_FetchString(results, 1, sqlClientName, sizeof(sqlClientName));
		
		if (!StrEqual(clientName, sqlClientName))
		{
			PrintToServer(">>>> %i", credits[client]);
			Format(query, sizeof(query), QUERY_UPDATE_CLIENT_INFOS, clientName, credits[client], steamID);
			DBFastQuery(query);
		}
	}
	else
	{
		SQL_EscapeString(DATABASE_PowerShop, clientName, clientName, sizeof(clientName));
		Format(query, sizeof(query), QUERY_INSERT_CLIENT, steamID, clientName, 0);
		DBFastQuery(query);
		PrintToServer("[TF2 Power Shop] New client found, adding to the database.");
	}
}

public void UpdateUpgrade(Handle db, Handle results, const char[] error, any data)
{
	int upID;
	int uptype;
	int upcost;
	int upmaxval;
	int upincval;
	int updefval;
	char upattrname[50];
	
	char upTrieType[10];
	char upTrieID[10];
	char upTrieCost[10];
	char upTrieMaxVal[10];
	char upTrieIncVal[10];
	char upTrieDefVal[10];
	char upTrieName[100];
	char upTrieMName[100];
	char upTrieD1[100];
	char upTrieD2[100];
	
	if (results == INVALID_HANDLE)
	{
		SetFailState("%t", "Database_failed", error);
		return;
	}
	
	GetTrieString(data, "attributName", upTrieName, sizeof(upTrieName));
	GetTrieString(data, "defaultValue", upTrieDefVal, sizeof(upTrieDefVal));
	GetTrieString(data, "increaseValue", upTrieIncVal, sizeof(upTrieIncVal));
	GetTrieString(data, "maxValue", upTrieMaxVal, sizeof(upTrieMaxVal));
	GetTrieString(data, "cost", upTrieCost, sizeof(upTrieCost));
	GetTrieString(data, "upgradetype", upTrieType, sizeof(upTrieType));
	GetTrieString(data, "menuItemName", upTrieMName, sizeof(upTrieMName));
	GetTrieString(data, "descriptionLine1", upTrieD1, sizeof(upTrieD1));
	GetTrieString(data, "descriptionLine2", upTrieD2, sizeof(upTrieD2));
	
	if (SQL_FetchRow(results))
	{
		upID = SQL_FetchInt(results, 0);
		uptype = SQL_FetchInt(results, 1);
		upcost = SQL_FetchInt(results, 2);
		upmaxval = SQL_FetchInt(results, 3);
		upincval = SQL_FetchInt(results, 4);
		updefval = SQL_FetchInt(results, 5);
		SQL_FetchString(results, 6, upattrname, sizeof(upattrname));
		
		if (uptype != StringToInt(upTrieType) || 
			upcost != StringToInt(upTrieCost) || 
			upmaxval != StringToInt(upTrieMaxVal) || 
			upincval != StringToInt(upTrieIncVal) || 
			updefval != StringToInt(upTrieDefVal) || 
			!StrEqual(upTrieName, upattrname)
			)
		{
			char query[500];
			Format(query, sizeof(query), QUERY_UPDATE_UPGRADE, upTrieType, upTrieCost, upTrieMaxVal, upTrieIncVal, upTrieDefVal, upTrieName, upTrieD1, upTrieD2, upID);
			SQL_AddQuery(DBTRANS_UpdateUpgrade, query);
			
			Format(query, sizeof(query), QUERY_UPDATE_CLIENTUPGRADE, upID);
			SQL_AddQuery(DBTRANS_SelectBoughtUpgrade, query);
		}
	}
	else
	{
		GetTrieString(data, "attributID", upTrieID, sizeof(upTrieID));
		
		char query[500];
		Format(query, sizeof(query), QUERY_INSERT_UPGRADE, upTrieID, upTrieMName, upTrieType, upTrieCost, upTrieD1, upTrieD2, upTrieMaxVal, upTrieIncVal, upTrieDefVal, upTrieName);
		SQL_AddQuery(DBTRANS_UpdateUpgrade, query);
	}
	
	queryUpgradeCount--;
}

public bool DBFastQuery(const char[] sql)
{
	if (debugMode)
	{
		PrintToServer("New query :");
		PrintToServer(sql);
	}
	
	char error[400];
	SQL_FastQuery(DATABASE_PowerShop, sql);
	if (SQL_GetError(DATABASE_PowerShop, error, sizeof(error)))
	{
		PrintToServer("%s %t", "[TF2 Power Shop]", "Database_failed", error);
		return false;
	}
	
	return true;
}

/////////////////
//	  STOCK    //
/////////////////
stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
} 

stock bool ReadConfigFile()
{
	char path[100];
	char query[200];
	Handle kv = CreateKeyValues("PowerShop_Items");
	Handle tmpHashMap;
	BuildPath(Path_SM, path, sizeof(path), "/configs/TF2_PSitems.cfg");
	FileToKeyValues(kv, path);
	
	if (!KvGotoFirstSubKey(kv))
		return;
	
	DBTRANS_UpdateUpgrade = SQL_CreateTransaction();
	DBTRANS_SelectBoughtUpgrade = SQL_CreateTransaction();
	
	do
	{
		KvGetSectionName(kv, attributID, sizeof(attributID));
		KvGetString(kv, "attributName", attributName, sizeof(attributName));
		KvGetString(kv, "defaultValue", defaultValue, sizeof(defaultValue));
		KvGetString(kv, "increaseValue", increaseValue, sizeof(increaseValue));
		KvGetString(kv, "maxValue", maxValue, sizeof(maxValue));
		KvGetString(kv, "descriptionLine1", descriptionLine1, sizeof(descriptionLine1));
		KvGetString(kv, "descriptionLine2", descriptionLine2, sizeof(descriptionLine2));
		KvGetString(kv, "cost", coststr, sizeof(coststr));
		KvGetString(kv, "upgradetype", upgradetype, sizeof(upgradetype));
		KvGetString(kv, "menuItemName", menuItemName, sizeof(menuItemName));
		
		tmpHashMap = CreateTrie();
		SetTrieString(tmpHashMap, "attributID", attributID, false);
		SetTrieString(tmpHashMap, "attributName", attributName, false);
		SetTrieString(tmpHashMap, "defaultValue", defaultValue, false);
		SetTrieString(tmpHashMap, "increaseValue", increaseValue, false);
		SetTrieString(tmpHashMap, "maxValue", maxValue, false);
		SetTrieString(tmpHashMap, "descriptionLine1", descriptionLine1, false);
		SetTrieString(tmpHashMap, "descriptionLine2", descriptionLine2, false);
		SetTrieString(tmpHashMap, "upgradetype", upgradetype, false);
		SetTrieString(tmpHashMap, "cost", coststr, false);
		SetTrieString(tmpHashMap, "menuItemName", menuItemName, false);
		
		PushArrayCell(ARRAY_Upgrades, tmpHashMap);
		
		queryUpgradeCount++;
		
		Format(query, sizeof(query), QUERY_SELECT_UPGRADE, attributID);
		SQL_TQuery(DATABASE_PowerShop, UpdateUpgrade, query, tmpHashMap);
		
	} while (KvGotoNextKey(kv));
	
	CreateTimer(1.00, TMR_QueryFinished);
	
	CloseHandle(kv);
}

stock void ApplyUpgrades(int client, char[] attr, float value, bool isAttribute)
{
	if (isAttribute)
	{
		Address address = TF2Attrib_GetByName(client, attr);
		float attrValue = defaultVal[client];
		if (address != Address_Null)
			attrValue = TF2Attrib_GetValue(address);
		
		attrValue += value;
		
		TF2Attrib_SetByName(client, attr, attrValue);
	}
	else
	{
		float attrValue = GetEntPropFloat(client, Prop_Send, attr);
		attrValue += value;
		SetEntPropFloat(client, Prop_Send, attr, attrValue);
	}
}