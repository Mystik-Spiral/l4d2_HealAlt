/*
  
[COLOR=Silver].[/COLOR]
[B][COLOR=Red]Healing Alternative[/COLOR][/B] (l4d2_HealAlt) by [COLOR=Green][I][B]Mystik Spiral[/B][/I][/COLOR]

Improve when healing items (first aid kits, pain pills, and adrenaline shots) are used.


[B]Summary of healing behavioral changes:[/B]

[LIST]
[*]Bots prefer to use/give pills/adrenaline instead of first aid kits.
[*]Bots will wait longer to use first aid kits on self or others.
[*]Bots will never heal another player that has their own healing items.
[*]Survivors with a first aid kit are healed using the standard algorithm during map changes.
[*]Survivors without a first aid kit are healed to 50, same as a respawned dead player, during map changes.
[*]All survivors are given a first aid kit during map changes.
[/LIST]


[B]Options:[/B]

For proper operation, set the following Valve ConVars in your server.cfg file:

[LIST]
[*][URL="https://developer.valvesoftware.com/wiki/List_of_L4D2_Cvars"]sb_toughness_buffer 0[/URL]
[*][URL="https://developer.valvesoftware.com/wiki/List_of_L4D2_Cvars"]sb_temp_health_consider_factor 0.0[/URL]
[*][URL="https://developer.valvesoftware.com/wiki/List_of_L4D2_Cvars"]pain_pills_health_threshold 90[/URL]
[/LIST]


[COLOR=Red][B]Prerequisites:[/B][/COLOR]

[LIST]
[*][URL="https://forums.alliedmods.net/showthread.php?t=336374"]Actions extension by BHaType[/URL]
[*][URL="https://forums.alliedmods.net/showthread.php?t=317175"]Source Scramble plugin by nosoop[/URL]
[*][URL="https://forums.alliedmods.net/showthread.php?t=321696"]Left 4 DHooks Direct by Silvers[/URL]
[/LIST]


[B]Notes:[/B]  

By default, this plugin will only run in the cooperative (coop) gamemode and is intended to only be used on dedicated servers that have not modified the default values of player health or healing items.

I plan to eventually add handling for first aid kits found outside of safe rooms.  I will not be adding support for L4D1.

Please let me know if you find any bugs, but before reporting, connect to the dedicated server system console and type:

[I]sm plugins list;sm_cvar mp_gamemode[/I]

Check that the gamemode is "coop" and whether you see "[L4D2] Healing Alternative" or error messages, especially errors related to missing prerequisites.

[URL="https://github.com/Mystik-Spiral/l4d2_HealAlt"]GitHub[/URL]  
[URL="https://forums.alliedmods.net/showthread.php?t=xxxxxx"]Discussion[/URL]


[B]Acknowledgements and Thanks:[/B]

Silvers: For the original [URL="https://forums.alliedmods.net/showthread.php?t=338889"]Bot Healing Values[/URL] plugin this is forked from, Left4DHooks, gamedata, Allowed Game Modes code, and many code examples.
BHaType: For help and code examples for custom Actions, and the Actions plugin.
nosoop: For the Source Scramble plugin.
Spirit_12: For help with determing navigation flow distance.
BRU7US: For help with the map_transition event.


[B]Changelog:[/B]  

[CODE]
12-May-2024 v1.0
- Initial release.
[/CODE]


[COLOR=Cornflowerblue][B]Installation:[/B][/COLOR]

Easiest:
Download the l4d2_HealAlt.zip file, place it in the addons/sourcemod directory, unzip.

Manual:
Extract the l4d2_HealAlt.smx file to the "plugins" directory.
Extract the l4d2_HealAlt.txt file to the "gamedata" directory.
Extract the l4d2_HealAlt.phrases.txt file to the "translations" directory.
Extract the l4d2_HealAlt.sp file to the "scripting" directory.

[COLOR=Silver].[/COLOR]

*/

// ====================================================================================================
// Defines for Plugin Info
// ====================================================================================================
#define PLUGIN_NAME               "[L4D2] Healing Alternative"
#define PLUGIN_AUTHOR             "Mystik Spiral"
#define PLUGIN_DESCRIPTION        "Improve when healing items are used."
#define PLUGIN_VERSION            "0.2024.05.10"
#define PLUGIN_URL                "https://forums.alliedmods.net/showthread.php?t=xxxxxx"

// ====================================================================================================
// Plugin Info
// ====================================================================================================
public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL
}

// ====================================================================================================
// Additional Defines
// ====================================================================================================
#define GAMEDATA                  "l4d2_HealAlt"
#define TRANSLATION_FILENAME      "l4d2_HealAlt.phrases"
#define CVAR_FLAGS                FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY
#define HEARTBEAT_SOUND           "player/heartbeatloop.wav"
#define SOUND_RCV_HEALITEM        "UI/LittleReward.wav"
#define SURVIVOR_TEAM             2
#define EMPTY_SLOT                -1
#define INVALID_ENTITY            -1
#define LAGNIAPPE                 48.0
#define PILLS_TARGET              39.0
#define MEDKIT_TARGET             23.0
#define SAFEROOM_RANGE            2000.0
#define MAX_REM_MEDKITS           4

// ====================================================================================================
// Includes
// ====================================================================================================
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <sourcescramble>
#include <actions>

// ====================================================================================================
// Pragmas
// ====================================================================================================
#pragma semicolon 1
#pragma newdecls required

// ====================================================================================================
// Global Variables
// ====================================================================================================

//Allowed Game Modes
ConVar	g_hCvarAllow, g_hCvarMPGameMode;
ConVar	g_hCvarModesOn, g_hCvarModesOff, g_hCvarModesTog;
bool	g_bCvarAllow, g_bMapStarted;
int		g_iCurrentMode;

//Handle
Handle g_hFailSafeMedkit[MAXPLAYERS + 1];
Handle g_hFailSafePillsAdren[MAXPLAYERS + 1];
Handle g_hChatSpam[MAXPLAYERS + 1];

//Boolean
bool g_bLateLoad;
bool g_bChatSpam[MAXPLAYERS + 1];
bool g_bStartPressingM1[MAXPLAYERS + 1];
bool g_bStopPressingM1[MAXPLAYERS + 1];
bool g_bM1pressed[MAXPLAYERS +1];
bool g_bHealingDoorClose[MAXPLAYERS + 1];
bool g_bMissionLost, g_bMissionWon;
bool g_bExtensionActions;
bool g_bExtensionScramble;
bool g_bPatched;
bool g_bRoundStartTwoMinute;
bool g_bFlashHealthRunning;
bool g_bFlashHealthComplete;

//Integer
int g_iSavedHealth[MAXPLAYERS + 1];

//Float
float g_fMedkit = MEDKIT_TARGET;
float g_fPills = PILLS_TARGET;

//MemoryPatch
MemoryPatch g_hPatchFirst1;
MemoryPatch g_hPatchFirst2;
MemoryPatch g_hPatchPills1;
MemoryPatch g_hPatchPills2;

// ====================================================================================================
// Verify game engine
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead2)
	{
		g_bLateLoad = late;
		return APLRes_Success;
	}
	else
	{
		strcopy(error, err_max, "[L4D2] Healing Alternative only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
}

// ====================================================================================================
// Method Maps
// ====================================================================================================
methodmap SurvivorMedkitHealSelf < BehaviorAction
{
	public SurvivorMedkitHealSelf()
	{
		SurvivorMedkitHealSelf action = view_as<SurvivorMedkitHealSelf>(ActionsManager.Create("SurvivorMedkitHealSelf"));
		action.OnStart = SurvivorMedkitHealSelf_OnStart;
		action.Update = SurvivorMedkitHealSelf_Update;
		action.OnEnd = SurvivorMedkitHealSelf_OnEnd;
		return action;
	}
}

/****************************************************************************************************/
methodmap SurvivorPillsAdrenHealSelf < BehaviorAction
{
	public SurvivorPillsAdrenHealSelf()
	{
		SurvivorPillsAdrenHealSelf action = view_as<SurvivorPillsAdrenHealSelf>(ActionsManager.Create("SurvivorPillsAdrenHealSelf"));
		action.OnStart = SurvivorPillsAdrenHealSelf_OnStart;
		action.Update = SurvivorPillsAdrenHealSelf_Update;
		action.OnEnd = SurvivorPillsAdrenHealSelf_OnEnd;
		return action;
	}
}

// ====================================================================================================
// Functions
// ====================================================================================================
public void OnPluginStart()
{
	// ====================
	// en,fr,es,ru,zho
	// ====================
	LoadPluginTranslations();
	
	// ====================
	// Set default ConVars
	// ====================
	CreateConVar("HealAlt_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);

	//Allowed Game Modes ConVars
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarAllow = CreateConVar("HealAlt_enabled", "1", "0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModesOn = CreateConVar("HealAlt_modes_on", "", "Game mode names on, comma separated, no spaces. (Empty=all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar("HealAlt_modes_off", "", "Game mode names off, comma separated, no spaces. (Empty=none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar("HealAlt_modes_tog", "1", "Game type bitflags on, add #s together. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge", CVAR_FLAGS );

	//Default plugin ConVars
	//g_hCvarStuff1 = CreateConVar("HealAlt_stuff1", "", "Stuff1", CVAR_FLAGS );
	//g_hCvarStuff2 = CreateConVar("HealAlt_stuff2", "", "Stuff2", CVAR_FLAGS );
	//g_hCvarStuff3 = CreateConVar("HealAlt_stuff3", "", "Stuff3", CVAR_FLAGS );

	//Load ConVars from cfg file
	AutoExecConfig(true, "l4d2_HealAlt");
	
	// ====================
	// Hook ConVar changes
	// ====================

	//Allowed Game Mode ConVar hooks
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOn.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);

	//Additional ConVar hooks
	//g_hCvarStuff1.AddChangeHook(ConVarChanged_Cvars);
	//g_hCvarStuff2.AddChangeHook(ConVarChanged_Cvars);
	//g_hCvarStuff3.AddChangeHook(ConVarChanged_Cvars);
	
	// ====================
	// Hook events
	// ====================
	HookEvent("map_transition", MapTransition, EventHookMode_PostNoCopy);	//round succeeded
	HookEvent("mission_lost", MissionLost, EventHookMode_PostNoCopy);		//round failed
	HookEvent("round_start", RoundStart, EventHookMode_PostNoCopy);			//round start
	
	// ====================
	// Validate extensions
	// ====================
	g_bExtensionActions = LibraryExists("actionslib");
	g_bExtensionScramble = GetFeatureStatus(FeatureType_Native, "MemoryPatch.CreateFromConf") == FeatureStatus_Available;
	if (!g_bExtensionActions && !g_bExtensionScramble)
	{
		SetFailState("\n==========\nMissing required extensions: \"Actions\" and \"SourceScramble\".\n==========");
	}
	else if (!g_bExtensionActions)
	{
		SetFailState("\n==========\nMissing required extension: \"Actions\".\n==========");
	}
	else if(!g_bExtensionScramble)
	{
		SetFailState("\n==========\nMissing required extension: \"SourceScramble\".\n==========");
	}
	
	// ====================
	// Late Load
	// ====================
	if (g_bLateLoad)
	{
		Event event = CreateEvent("round_start");
		if (event != null)
		{
			event.Fire();
		}
		OnMapStart();
		g_bPatched = false;
		OnConfigsExecuted();
	}
}

/****************************************************************************************************/
public void OnPluginEnd()
{
	DisablePatches();
}

/****************************************************************************************************/
public void OnConfigsExecuted()
{
	IsAllowed();
	if (!g_bPatched && g_bCvarAllow)
	{
		EnablePatches();
	}
	else if (!g_bCvarAllow && g_bPatched)
	{
		DisablePatches();
	}
}

/****************************************************************************************************/
public void EnablePatches()
{
	// ====================
	// Load GameData
	// ====================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if (FileExists(sPath) == false)
	{
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);
	}
	GameData hGameData = new GameData(GAMEDATA);
	if (hGameData == null)
	{
		SetFailState("\n==========\nFailed to load \"%s.txt\" gamedata.\n==========", GAMEDATA);
	}
	
	// ====================
	// Validate patches
	// ====================
	g_hPatchFirst1 = MemoryPatch.CreateFromConf(hGameData, "BotHealing_FirstAid_A");
	if (!g_hPatchFirst1.Validate())
	{
		SetFailState("Failed to validate \"BotHealing_FirstAid_A\" target.");
	}
	g_hPatchFirst2 = MemoryPatch.CreateFromConf(hGameData, "BotHealing_FirstAid_B");
	if (!g_hPatchFirst2.Validate())
	{
		SetFailState("Failed to validate \"BotHealing_FirstAid_B\" target.");
	}
	g_hPatchPills1 = MemoryPatch.CreateFromConf(hGameData, "BotHealing_Pills_A");
	if (!g_hPatchPills1.Validate())
	{
		SetFailState("Failed to validate \"BotHealing_Pills_A\" target.");
	}
	g_hPatchPills2 = MemoryPatch.CreateFromConf(hGameData, "BotHealing_Pills_B");
	if (!g_hPatchPills2.Validate())
	{
		SetFailState("Failed to validate \"BotHealing_Pills_B\" target.");
	}
	
	// ====================
	// Enable patches
	// ====================
	// First Aid
	if (!g_hPatchFirst1.Enable())
	{
		SetFailState("Failed to patch \"BotHealing_FirstAid_A\" target.");
	}
	if (!g_hPatchFirst2.Enable())
	{
		SetFailState("Failed to patch \"BotHealing_FirstAid_B\" target.");
	}
	// Pills
	if (!g_hPatchPills1.Enable())
	{
		SetFailState("Failed to patch \"BotHealing_Pills_A\" target.");
	}
	if (!g_hPatchPills2.Enable())
	{
		SetFailState("Failed to patch \"BotHealing_Pills_B\" target.");
	}
	
	// ====================
	// Patch memory
	// ====================
	
	// First Aid
	StoreToAddress(g_hPatchFirst1.Address + view_as<Address>(2), GetAddressOfCell(g_fMedkit), NumberType_Int32);
	StoreToAddress(g_hPatchFirst2.Address + view_as<Address>(2), GetAddressOfCell(g_fMedkit), NumberType_Int32);
	
	// Pills
	StoreToAddress(g_hPatchPills1.Address + view_as<Address>(2), GetAddressOfCell(g_fPills), NumberType_Int32);
	StoreToAddress(g_hPatchPills2.Address + view_as<Address>(2), GetAddressOfCell(g_fPills), NumberType_Int32);
	
	g_bPatched = true;
	//PrintToServer("[HealAlt] Enabled Memory Patches");
}

/****************************************************************************************************/
public void DisablePatches()
{
	g_hPatchFirst1.Disable();
	g_hPatchFirst2.Disable();
	g_hPatchPills1.Disable();
	g_hPatchPills2.Disable();

	g_bPatched = false;
	//PrintToServer("[HealAlt] Disabled Memory Patches");
}

/****************************************************************************************************/
public void LoadPluginTranslations()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "translations/%s.txt", TRANSLATION_FILENAME);
	if (FileExists(path))
	{
		LoadTranslations(TRANSLATION_FILENAME);
	}
	else
	{
		SetFailState("Missing required translation file \"<left4dead2>\\%s\".", path, TRANSLATION_FILENAME);
	}
}

/****************************************************************************************************/
public void OnMapStart()
{
	g_bMapStarted = true;
}

/****************************************************************************************************/
public void OnMapEnd()
{
	g_bMapStarted = false;
}

/****************************************************************************************************/
public void RoundStart(Event event, char[] name, bool dontBroadcast)
{
	CreateTimer(30.0, FAKScan);
	CreateTimer(60.0, FlashHealth);
	CreateTimer(120.0, RoundStartTwoMinuteTimer);
	g_bRoundStartTwoMinute = true;
	g_bFlashHealthRunning = false;
	g_bFlashHealthComplete = false;
	
	if (g_bMissionWon)
	{
		g_bMissionWon = false;
	}
	
	if (g_bMissionLost)
	{
		g_bMissionLost = false;
		if (!L4D_IsFirstMapInScenario())
		{
			//on map failure, if not first map, check/give medkit to all survivors
			CreateTimer(1.0, CheckGiveMedkit, -1);
		}
	}
}

/****************************************************************************************************/
public Action RoundStartTwoMinuteTimer(Handle timer)
{
	g_bRoundStartTwoMinute = false;
	return Plugin_Continue;
}

/****************************************************************************************************/
public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
	if (!g_bPatched && g_bCvarAllow)
	{
		EnablePatches();
	}
	else if (!g_bCvarAllow && g_bPatched)
	{
		DisablePatches();
	}
}

/****************************************************************************************************/
public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

/****************************************************************************************************/
void GetCvars()
{
	//g_iCvarStuff1 = g_hCvarStuff1.IntValue;
	//g_fCvarStuff2 = g_hCvarStuff2.FloatValue;
	//g_bCvarStuff3 = g_hCvarStuff3.BoolValue;
}

/****************************************************************************************************/
void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();
	if (g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true)
	{
		g_bCvarAllow = true;
	}
	else if (g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false))
	{
		g_bCvarAllow = false;
	}
}

/****************************************************************************************************/
bool IsAllowedGameMode()
{
	if (g_hCvarMPGameMode == null)
		return false;
	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if (iCvarModesTog != 0 && iCvarModesTog != 15)
	{
		if (g_bMapStarted == false)
			return false;
		g_iCurrentMode = 0;
		int entity = CreateEntityByName("info_gamemode");
		if (IsValidEntity(entity))
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if (IsValidEntity(entity))	//Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity);	//Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}
		if (g_iCurrentMode == 0)
			return false;
		if (!(iCvarModesTog & g_iCurrentMode))
			return false;
	}
	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);
	g_hCvarModesOn.GetString(sGameModes, sizeof(sGameModes));
	if (sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}
	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if (sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}
	return true;
}

/****************************************************************************************************/
public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if (strcmp(output, "OnCoop") == 0)
		g_iCurrentMode = 1;
	else if (strcmp(output, "OnSurvival") == 0)
		g_iCurrentMode = 2;
	else if (strcmp(output, "OnVersus") == 0)
		g_iCurrentMode = 4;
	else if (strcmp(output, "OnScavenge") == 0)
		g_iCurrentMode = 8;
}

/****************************************************************************************************/
public void MissionLost(Event event, char[] name, bool dontBroadcast)
{
	g_bMissionLost = true;
}

/****************************************************************************************************/
public void MapTransition(Event event, char[] name, bool dontBroadcast)
{
	g_bMissionWon = true;
	//skip InstaHeal for Tank Challenge and Tanks Playground campaigns
	static char sMapName[64];
	GetCurrentMap(sMapName, sizeof(sMapName));
	if (!g_bCvarAllow || strncmp(sMapName, "l4d2_tank", 9) == 0)
	{
		return;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == SURVIVOR_TEAM)
		{
			//check if any alive survivors are already healing self (Director inta-heal)
			int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(iActiveWeapon) && iActiveWeapon > 0)
			{
				static char sWeaponName[32];
				GetEntityClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
				//check if mouse1 button is being pressed while holding medkit (self healing)
				if (strcmp(sWeaponName, "weapon_first_aid_kit") == 0 && g_bM1pressed[client] == true)
				{
					g_bHealingDoorClose[client] = true;
				}
				else
				{
					g_bHealingDoorClose[client] = false;
				}
			}

			//check if survivors with medkit should insta-heal self or others
			int iPermHealth = GetClientHealth(client);
			if (HasFirstAidKit(client))
			{
				static char sName1[32];
				GetClientName(client, sName1, sizeof(sName1));
				//check if Director will insta-heal client
				//this happens when client is healing with medkit when safe room door is closed
				if (g_bHealingDoorClose[client] == true)
				{
					//skip insta-heal for this client
					PrintToChatAll("\x04[HealAlt]\x03 %t", "DirectorHeal", sName1);
					//PrintToServer("[HealAlt] %N will be healed by the Director", client);
				}
				else if (iPermHealth < 90)
				{
					//survivor with medkit and < 90 health should insta-heal self
					int iNewClientHealth = iPermHealth + RoundToFloor((100 - iPermHealth) * 0.8);
					SetEntityHealth(client, iNewClientHealth);
					L4D_SetTempHealth(client, 0.0);
					SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
					SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
					SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
					StopSound(client, SNDCHAN_AUTO, HEARTBEAT_SOUND);
					StopSound(client, SNDCHAN_STATIC, HEARTBEAT_SOUND);
					//announce player sName1 healed self
					PrintToChatAll("\x04[HealAlt]\x03 %t", "HealedSelf", sName1);
					//PrintToServer("[HealAlt] %N healed self", client);
				}
				else
				{
					//client has medkit and > 89 health so...
					//scan all players without medkit to get insta-heal target
					int iLowestHealth = 101;
					int iLowestHealthClient;
					int iClntHlth;
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == SURVIVOR_TEAM && GetClientHealth(i) < iLowestHealth && !HasFirstAidKit(i))
						{
							iClntHlth = GetClientHealth(i);
							if (iClntHlth < iLowestHealth)
							{
								iLowestHealth = iClntHlth;
								iLowestHealthClient = i;
							}
						}
					}
					//if no targets found, scan again including players with medkit
					if (iLowestHealthClient == 0)
					{
						for (int i = 1; i <= MaxClients; i++)
						{
							if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == SURVIVOR_TEAM && i != client && GetClientHealth(i) < iPermHealth)
							{
								iClntHlth = GetClientHealth(i);
								if (iClntHlth < iLowestHealth)
								{
									iLowestHealth = iClntHlth;
									iLowestHealthClient = i;
								}
							}
						}
					}
					//if still no targets found, heal self
					if (iLowestHealthClient == 0)
					{
						iLowestHealthClient = client;
					}
					//heal iLowestHealthClient
					static char sName2[32];
					GetClientName(iLowestHealthClient, sName2, sizeof(sName2));
					int iNewClientHealth = iLowestHealth + RoundToFloor((100 - iLowestHealth) * 0.8);
					SetEntityHealth(iLowestHealthClient, iNewClientHealth);
					L4D_SetTempHealth(iLowestHealthClient, 0.0);
					SetEntProp(iLowestHealthClient, Prop_Send, "m_currentReviveCount", 0);
					SetEntProp(iLowestHealthClient, Prop_Send, "m_bIsOnThirdStrike", 0);
					SetEntProp(iLowestHealthClient, Prop_Send, "m_isGoingToDie", 0);
					StopSound(iLowestHealthClient, SNDCHAN_AUTO, HEARTBEAT_SOUND);
					StopSound(iLowestHealthClient, SNDCHAN_STATIC, HEARTBEAT_SOUND);
					if (iLowestHealthClient != client)
					{
						//announce player sName1 healed player sName2
						PrintToChatAll("\x04[HealAlt]\x03 %t", "HealedFriend", sName1, sName2);
						//PrintToServer("[HealAlt] %N healed %N.", client, iLowestHealthClient);
					}
					else
					{
						//announce player sName1 healed self
						PrintToChatAll("\x04[HealAlt]\x03 %t", "HealedSelf", sName1);
						//PrintToServer("[HealAlt] %N healed self.", client);
					}
				}
			}
		}
		g_bHealingDoorClose[client] = false;
	}
	//scan clients for minimal heal targets after all insta-heals are complete
	for (int client = 1; client <= MaxClients; client++)
	{
		//find all alive survivors
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == SURVIVOR_TEAM)
		{
			if (!HasFirstAidKit(client))
			{
				int iPermHealth = GetClientHealth(client);
				if (iPermHealth < 50)
				{
					//minimal heal (same as a dead player that respawns in safe room)
					SetEntityHealth(client, 50);
					L4D_SetTempHealth(client, 0.0);
					SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
					SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
					SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
					StopSound(client, SNDCHAN_AUTO, HEARTBEAT_SOUND);
					StopSound(client, SNDCHAN_STATIC, HEARTBEAT_SOUND);
					//PrintToServer("[HealAlt] %N received minimal heal.", client);
				}
			}
		}
	}		
	return;
}

/****************************************************************************************************/
public void OnClientPostAdminCheck(int client)
{
	if (!L4D_IsFirstMapInScenario())
	{
		//need a few more frames to ensure client is in game and assigned a team
		CreateTimer(1.0, CheckGiveMedkit, client);
	}
}

/****************************************************************************************************/
public Action CheckGiveMedkit(Handle timer, int client)
{
	static char sMapName[64];
	GetCurrentMap(sMapName, sizeof(sMapName));
	if (!g_bCvarAllow || strncmp(sMapName, "l4d2_tank", 9) == 0)
	{
		return Plugin_Continue;
	}
	//called from RoundStart/g_bMissionLost
	if (client == -1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == SURVIVOR_TEAM)
			{
				if (!HasFirstAidKit(i))
				{
					//drop existing weapon in slot 3 before giving medkit
					int iEntFDU = GetPlayerWeaponSlot(i, 3);
					if (IsValidEntity(iEntFDU) && iEntFDU > 0)
					{
						SDKHooks_DropWeapon(i, iEntFDU);
					}
					//give survivor a medkit
					GivePlayerItem(i, "weapon_first_aid_kit");
				}
				static char sName1[32];
				GetClientName(i, sName1, sizeof(sName1));
				//announce player sName1 took a medkit
				PrintToChatAll("\x04[HealAlt]\x03 %t", "TookFAK", sName1);
				//PrintToServer("[HealAlt] %N took a first aid kit.", i);
			}
		}
	}
	//called from OnClientPostAdminCheck
	else
	{
		//in the first two minutes since round start, check if survivor is alive without a medkit
		if (g_bRoundStartTwoMinute && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == SURVIVOR_TEAM)
		{
			if (!HasFirstAidKit(client))
			{
				//drop existing weapon in slot 3 before giving medkit
				int iEntFDU = GetPlayerWeaponSlot(client, 3);
				if (IsValidEntity(iEntFDU) && iEntFDU > 0)
				{
					SDKHooks_DropWeapon(client, iEntFDU);
				}	
				//give survivor a medkit
				GivePlayerItem(client, "weapon_first_aid_kit");
			}
			static char sName1[32];
			GetClientName(client, sName1, sizeof(sName1));
			//announce player sName1 took a medkit
			PrintToChatAll("\x04[HealAlt]\x03 %t", "TookFAK", sName1);
			//PrintToServer("[HealAlt] %N took a first aid kit.", client);
		}
	}
	
	return Plugin_Continue;
}

/****************************************************************************************************/
public void OnClientDisconnect(int client)
{
	if (IsClientInGame(client) && GetClientTeam(client) == SURVIVOR_TEAM && L4D_IsInFirstCheckpoint(client))
	{
		//PrintToServer("[HealAlt] %N disconnecting", client);
		if (g_bFlashHealthComplete)
		{
			//PrintToServer("[HealAlt] Will run FlashHealth again");
			g_bFlashHealthRunning = false;
			g_bFlashHealthComplete = false;
			CreateTimer(0.2, FlashHealth);
		}
	}
}

/****************************************************************************************************/
public Action FlashHealth(Handle timer)
{
	//Hack for all bot survivor team stuck in the starting safe room when one or more survivors want
	//to heal before leaving the safe room and are blocked.  This will temporarily set the bots
	//health to max until they leave the safe room, then reset their health to the correct values.
	
	if (g_bFlashHealthRunning || g_bFlashHealthComplete || !g_bCvarAllow || L4D_HasAnySurvivorLeftSafeArea())
	{
		//PrintToServer("[HealAlt] FlashHealth status - running/complete: %b/%b", g_bFlashHealthRunning, g_bFlashHealthComplete);
		return Plugin_Continue;
	}
	g_bFlashHealthRunning = true;
	//PrintToServer("[HealAlt] FlashHealth status - running/complete: %b/%b", g_bFlashHealthRunning, g_bFlashHealthComplete);
	for (int client = 1; client <= MaxClients; client++)
	{
		g_iSavedHealth[client] = 0;
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == SURVIVOR_TEAM)
		{
			if (!IsFakeClient(client) || !L4D_IsInFirstCheckpoint(client))
			{
				for (int i = 1; i <= client; i++)
				{
					g_iSavedHealth[i] = 0;
				}
				//PrintToServer("[HealAlt] FlashHealth aborting for %N.", client);
				g_bFlashHealthRunning = false;
				g_bFlashHealthComplete = true;
				return Plugin_Continue;
			}
			else
			{
				//save health
				g_iSavedHealth[client] = GetClientHealth(client);
				//PrintToServer("[HealAlt] FlashHealth saved %N: %i", client, g_iSavedHealth[client]);
				//change health
				SetEntityHealth(client, 100);
			}
		}
	}
	return Plugin_Continue;
}

/****************************************************************************************************/
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	//PrintToServer("[HealAlt] Survivor(s) left the safe area...");
	if (g_bFlashHealthRunning)
	{
		//PrintToServer("[HealAlt] ...while FlashHealth is running.");
		CreateTimer(0.5, ResetFlashHealth);
	}
	else
	{
		//PrintToServer("[HealAlt] ...while FlashHealth is not running.");
		g_bFlashHealthComplete = true;
	}
	return Plugin_Continue;
}

/****************************************************************************************************/
public Action ResetFlashHealth(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (g_iSavedHealth[client] > 0 && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == SURVIVOR_TEAM)
		{
			//reset bot health
			SetEntityHealth(client, g_iSavedHealth[client]);
			//PrintToServer("[HealAlt] ResetFlashHealth restored %N: %i", client, g_iSavedHealth[client]);
		}
		g_iSavedHealth[client] = 0;
	}
	g_bFlashHealthRunning = false;
	g_bFlashHealthComplete = true;
	return Plugin_Continue;
}

/****************************************************************************************************/
public Action FAKScan(Handle timer)
{
	static char sMapName[64];
	GetCurrentMap(sMapName, sizeof(sMapName));
	if (!g_bCvarAllow || L4D_IsMissionFinalMap() || strncmp(sMapName, "l4d2_tank", 9) == 0)
	{
		return Plugin_Continue;
	}
	int iNumMedkits = MAX_REM_MEDKITS;
	float fMedkitPos[3];
	int iMedkitEnt = INVALID_ENT_REFERENCE;
	//find all medkits
	while ((iMedkitEnt = FindEntityByClassname(iMedkitEnt, "weapon_first_aid_kit_spawn")) != INVALID_ENT_REFERENCE)
	{
		//get vector position of found medkit
		GetEntPropVector(iMedkitEnt, Prop_Send, "m_vecOrigin", fMedkitPos);
		fMedkitPos[2]+=5.0;	//workaround for LOS to nav area, especially C4M1
		if (L4D_IsPositionInLastCheckpoint(fMedkitPos))
		{
			//remove up to MAX_REM_MEDKITS medkits in ending saferoom
			if (iNumMedkits > 0 && IsValidEntity(iMedkitEnt) && iMedkitEnt > 0)
			{
				iNumMedkits--;
				//AcceptEntityInput(iMedkitEnt, "kill");
				RemoveEntity(iMedkitEnt);
				//PrintToServer("[HealAlt] Removed medkit %i in ending saferoom", iMedkitEnt);
			}
		}
	}
	return Plugin_Continue;
}

/****************************************************************************************************/
public Action L4D2_BackpackItem_StartAction(int client, int entity, any type)
{
	if (!g_bCvarAllow)
	{
		return Plugin_Continue;
	}
	int target;
	if (g_bM1pressed[client])
	{
		target = client;
	}
	else
	{
		float range = FindConVar("player_use_radius").FloatValue;
		bool players = true;
		target = L4D_FindUseEntity(client, players, range);
		if (target < 0 || target > MaxClients)
		{
			target = 0;
		}
	}
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == SURVIVOR_TEAM && client == target && type == L4D2WeaponId_FirstAidKit && GetClientHealth(client) > 89)
	{
		bool bNoFAKlt60;
		int iLowestHealth = 60;
		int iLowestHealthClient;
		int iClntHlth;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == SURVIVOR_TEAM && GetClientHealth(i) < iLowestHealth && !HasFirstAidKit(i))
			{
				iClntHlth = GetClientHealth(i);
				bNoFAKlt60 = true;
				if (iClntHlth < iLowestHealth)
				{
					iLowestHealth = iClntHlth;
					iLowestHealthClient = i;
				}
			}
		}
		if (bNoFAKlt60)
		{
			if (!g_bChatSpam[client])
			{
				//tell client they do not need to heal and who they should heal
				static char sName1[32];
				GetClientName(iLowestHealthClient, sName1, sizeof(sName1));
				PrintToChat(client, "\x04[HealAlt]\x03 %t", "DoNotNeedToHeal", sName1);
				g_bChatSpam[client] = true;
				g_hChatSpam[client] = CreateTimer(11.0, ChatSpamTimer, client);
			}
			return Plugin_Handled;
		}
		else
		{
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

// ====================================================================================================
//					ACTIONS EXTENSION
// ====================================================================================================
public void OnActionCreated(BehaviorAction action, int actor, const char[] name)
{
	if (g_bCvarAllow && strncmp(name, "Survivor", 8) == 0)
	{
		//Hook bot wants to heal self with medkit
		if (strcmp(name[8], "HealSelf") == 0)
		{
			action.OnStart = OnSelfActionMedkit;
		}
		//Hook bot wants to heal friend with medkit
		else if (strcmp(name[8], "HealFriend") == 0)
		{
			action.OnStartPost = OnFriendActionMedkit;
		}
		//Hook bot wants to heal self with pills/adrenaline
		else if (strcmp(name[8], "TakePills") == 0)
		{
			action.OnStart = OnSelfActionPills;
		}
		//Hook bot wants to heal friend with pills/adrenaline
		else if (strcmp(name[8], "GivePillsToFriend") == 0)
		{
			action.OnStartPost = OnFriendActionPills;
		}
	}
}

/****************************************************************************************************/
public Action OnSelfActionMedkit(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	int iPermHealth = GetClientHealth(actor);
	int iTempHealth = L4D_GetPlayerTempHealth(actor);
	int iTotalHealth = iPermHealth + iTempHealth;
	bool bBW = GetEntProp(actor, Prop_Send, "m_bIsOnThirdStrike") == 1;
	bool bFinale = L4D_IsMissionFinalMap();
	bool bFirstCP = L4D_IsInFirstCheckpoint(actor);
	bool bLastCP = L4D_IsInLastCheckpoint(actor);
	float flowdist = L4D2Direct_GetMapMaxFlowDistance() - L4D2Direct_GetFlowDistance(actor);
	
	//allow bot to heal with medkit if B&W (third strike) or in last map
	bool allow = bBW || bFinale;

	//check if bot should take pills/adren instead of using medkit
	if (!allow && !bFirstCP && HasPillsOrAdrenaline(actor) && (bFinale || flowdist > SAFEROOM_RANGE))
	{
		//PrintToServer("[HealAlt] %N will attempt to heal self with pills/adren instead of healing self with medkit.", actor);
		//Create action to change to
		SurvivorPillsAdrenHealSelf take = SurvivorPillsAdrenHealSelf();
		action.ChangeTo(take, "TakePills_InsteadOf_HealSelf");
		return Plugin_Handled;
	}
	
	//allow bot to heal with medkit if not in safe room and total health < 23
	if (!allow && !bFirstCP && !bLastCP && iTotalHealth <= MEDKIT_TARGET)
	{
		allow = true;
	}
	
	if (allow)
	{
		//PrintToServer("[HealAlt] %N will attempt to heal self with medkit: %i/%i/%b/%b/%b/%b prm/tmp/bw/fin/fcp/lcp.", actor, iPermHealth, iTempHealth, bBW, bFinale, bFirstCP, bLastCP);
	}
	result.type = allow ? CONTINUE : DONE;
	return Plugin_Changed;
}

/****************************************************************************************************/
public Action OnFriendActionMedkit(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	int target = action.Get(0x34) & 0xFFF;
	bool bHasHealingItems = HasFirstAidKit(target) || HasPillsOrAdrenaline(target);
	//int iTotalHealthFriend = GetClientHealth(target) + L4D_GetPlayerTempHealth(target);
	int iPermHealthSelf = GetClientHealth(actor);
	int iTotalHealthSelf = iPermHealthSelf + L4D_GetPlayerTempHealth(actor);
	float flowdist = L4D2Direct_GetMapMaxFlowDistance() - L4D2Direct_GetFlowDistance(actor);
	
	//check if bot should heal friend with medkit
	bool allow = GetEntProp(target, Prop_Send, "m_bIsOnThirdStrike") == 1 && !bHasHealingItems;

	//check if bot should give friend pills/adren instead of healing friend with medkit
	if (!allow && !bHasHealingItems && HasPillsOrAdrenaline(actor))
	{
		int iPillsAdrenId = GetPlayerWeaponSlot(actor, 4);
		if (IsValidEntity(iPillsAdrenId) && iPillsAdrenId > 0)
		{
			static float vPosClient[3], vPosTarget[3], dist, range;
			GetClientEyePosition(actor, vPosClient);
			GetClientEyePosition(target, vPosTarget);
			dist = GetVectorDistance(vPosClient, vPosTarget);
			range = FindConVar("player_use_radius").FloatValue + LAGNIAPPE;
			if (dist < range)
			{
				static char sPillsAdrenNm[24];
				GetEntityClassname(iPillsAdrenId, sPillsAdrenNm, sizeof(sPillsAdrenNm));
				RemovePlayerItem(actor, iPillsAdrenId);
				GivePlayerItem(target, sPillsAdrenNm);
				PlaySound(target, SOUND_RCV_HEALITEM);
				static char sName1[32];
				GetClientName(actor, sName1, sizeof(sName1));
				static char sName2[32];
				GetClientName(target, sName2, sizeof(sName2));
				if (CharToLower(sPillsAdrenNm[7]) == 'a')
				{
					PrintToChatAll("\x04[HealAlt]\x03 %t", "GaveAdren", sName1, sName2);
				}
				else
				{
					PrintToChatAll("\x04[HealAlt]\x03 %t", "GavePills", sName1, sName2);
				}
				//PrintToServer("[HealAlt] %N gave %s to %N.", actor, sPillsAdrenNm, target);
				return Plugin_Handled;
			}
		}
	}

	//check if bot should take pills/adren instead of healing friend with medkit
	if (!allow && HasPillsOrAdrenaline(actor) && (!HasFirstAidKit(actor) || (HasFirstAidKit && GetEntProp(actor, Prop_Send, "m_bIsOnThirdStrike") != 1)) && iTotalHealthSelf <= PILLS_TARGET && (L4D_IsMissionFinalMap() || flowdist > SAFEROOM_RANGE))
	{
		//PrintToServer("[HealAlt] %N will attempt to heal self with pills/adren instead of healing %N with medkit.", actor, target);
		//Create action to change to
		SurvivorPillsAdrenHealSelf take = SurvivorPillsAdrenHealSelf();
		action.ChangeTo(take, "TakePills_InsteadOf_HealFriend");
		return Plugin_Handled;
	}
	
	//check if bot should heal self with medkit instead of healing friend with medkit
	if (!allow && HasFirstAidKit(actor) && (GetEntProp(actor, Prop_Send, "m_bIsOnThirdStrike") == 1 || iTotalHealthSelf <= MEDKIT_TARGET))
	{
		//PrintToServer("[HealAlt] %N will attempt to heal self with medkit instead of healing %N with medkit.", actor, target);
		//Create action to change to
		SurvivorMedkitHealSelf take = SurvivorMedkitHealSelf();
		action.ChangeTo(take, "HealSelf_InsteadOf_HealFriend");
		return Plugin_Handled;
	}
	
	if (allow)
	{
		//PrintToServer("[HealAlt] %N will attempt to heal %N with medkit.", actor, target);
	}
	result.type = allow ? CONTINUE : DONE;
	return Plugin_Changed;
}

/****************************************************************************************************/
public Action OnSelfActionPills(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	bool allow = true;
	float flowdist = L4D2Direct_GetMapMaxFlowDistance() - L4D2Direct_GetFlowDistance(actor);
	static char sMapName[64];
	GetCurrentMap(sMapName, sizeof(sMapName));
	
	//check if bot is too close to ending saferoom to take pills/adren
	if (!L4D_IsMissionFinalMap() && strncmp(sMapName, "l4d2_tank", 9) != 0 && flowdist < SAFEROOM_RANGE)
	{
		allow = false;
	}
	
	if (allow)
	{
		//PrintToServer("[HealAlt] %N will attempt to heal self with pills/adren.", actor);
	}
	else
	{
		//PrintToServer("[HealAlt] %N is too close to ending saferoom and will not take pills/adren.", actor);
	}
	result.type = allow ? CONTINUE : DONE;
	return Plugin_Changed;
}

/****************************************************************************************************/
public Action OnFriendActionPills(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	int target = action.Get(0x34) & 0xFFF;
	int iTotalHealthFriend = GetClientHealth(target) + L4D_GetPlayerTempHealth(target);
	int iTotalHealthSelf = GetClientHealth(actor) + L4D_GetPlayerTempHealth(actor);
	float flowdist_target = L4D2Direct_GetMapMaxFlowDistance() - L4D2Direct_GetFlowDistance(target);
	float flowdist_actor = L4D2Direct_GetMapMaxFlowDistance() - L4D2Direct_GetFlowDistance(actor);
	static char sMapName[64];
	GetCurrentMap(sMapName, sizeof(sMapName));

	//check if bot should give pills/adren to friend
	bool allow = GetEntProp(target, Prop_Send, "m_bIsOnThirdStrike") == 1 || iTotalHealthFriend <= PILLS_TARGET;
	
	//check if friend is too close to ending saferoom to give pills/adren
	if (allow && !L4D_IsMissionFinalMap() && strncmp(sMapName, "l4d2_tank", 9) != 0 && flowdist_target < SAFEROOM_RANGE)
	{
		allow = false;
	}
	
	//check if bot should take pills/adren instead of giving pills/adren to friend
	if (!allow && iTotalHealthSelf <= PILLS_TARGET && flowdist_actor > SAFEROOM_RANGE && (L4D_IsMissionFinalMap() || strncmp(sMapName, "l4d2_tank", 9) == 0))
	{
		//PrintToServer("[HealAlt] %N will attempt to heal self with pills/adren instead of healing %N with pills/adren.", actor, target);
		//Create action to change to
		SurvivorPillsAdrenHealSelf take = SurvivorPillsAdrenHealSelf();
		action.ChangeTo(take, "TakePills_InsteadOf_GivePillsToFriend");
		return Plugin_Handled;
	}
	
	if (allow)
	{
		//PrintToServer("[HealAlt] %N will attempt to heal %N with pills/adren.", actor, target);
	}
	result.type = allow ? CONTINUE : DONE;
	return Plugin_Changed;
}

// ====================================================================================================
// Start custom actions
// ====================================================================================================
public Action SurvivorPillsAdrenHealSelf_OnStart( SurvivorPillsAdrenHealSelf action, int actor, BehaviorAction priorAction, ActionResult result )
{
	/* Action transitions are not instant and we could lose pills/adrenaline while transitioning, check it again */
	if (!HasPillsOrAdrenaline(actor))
	{
		return action.Done("I do not have pills or adrenaline");
	}
	return action.Continue();
}

/****************************************************************************************************/
public Action SurvivorMedkitHealSelf_OnStart( SurvivorMedkitHealSelf action, int actor, BehaviorAction priorAction, ActionResult result )
{
	/* Action transitions are not instant and we could lose medkit while transitioning, check it again */
	if (!HasFirstAidKit(actor))
	{
		return action.Done("I do not have a medkit");
	}
	return action.Continue();
}

// ====================================================================================================
// Update custom actions
// ====================================================================================================
public Action SurvivorPillsAdrenHealSelf_Update( SurvivorPillsAdrenHealSelf action, int actor, BehaviorAction priorAction, ActionResult result )
{
	/* If we used pills then we don't have them anymore */
	if (!HasPillsOrAdrenaline(actor))
	{
		g_bStartPressingM1[actor] = false;
		g_bStopPressingM1[actor] = true;
		return action.Done("Used pills/adren");
	}
	//true=holding, false=switch next frame
	if (IsHoldingWeapon(actor, 4))
	{
		g_bStartPressingM1[actor] = true;
		if (g_hFailSafePillsAdren[actor] == INVALID_HANDLE)
		{
			g_hFailSafePillsAdren[actor] = CreateTimer(3.0, PillsAdrenFSTimer, actor);
		}
	}
	return action.Continue();
}

/****************************************************************************************************/
public Action SurvivorMedkitHealSelf_Update( SurvivorMedkitHealSelf action, int actor, BehaviorAction priorAction, ActionResult result )
{
	/* If we used medkit then we don't have it anymore */
	if (!HasFirstAidKit(actor))
	{
		g_bStartPressingM1[actor] = false;
		g_bStopPressingM1[actor] = true;
		return action.Done("Used medkit");
	}
	//true=holding, false=switch next frame
	if (IsHoldingWeapon(actor, 3))
	{
		g_bStartPressingM1[actor] = true;
		if (g_hFailSafeMedkit[actor] == INVALID_HANDLE)
		{
			g_hFailSafeMedkit[actor] = CreateTimer(8.0, MedkitFSTimer, actor);
		}
	}
	return action.Continue();
}

// ====================================================================================================
// End custom actions
// ====================================================================================================
public void SurvivorPillsAdrenHealSelf_OnEnd( SurvivorPillsAdrenHealSelf action, int actor, BehaviorAction priorAction, ActionResult result )
{
	g_bStartPressingM1[actor] = false;
	g_bStopPressingM1[actor] = true;
}

/****************************************************************************************************/
public void SurvivorMedkitHealSelf_OnEnd( SurvivorMedkitHealSelf action, int actor, BehaviorAction priorAction, ActionResult result )
{
	g_bStartPressingM1[actor] = false;
	g_bStopPressingM1[actor] = true;
}

// ====================================================================================================
// Failsafe to prevent stuck primary mouse button
// ====================================================================================================
public Action PillsAdrenFSTimer(Handle timer, int client)
{
	g_bStartPressingM1[client] = false;
	g_bStopPressingM1[client] = true;
	g_hFailSafePillsAdren[client] = INVALID_HANDLE;
	return Plugin_Continue;
}

/****************************************************************************************************/
public Action MedkitFSTimer(Handle timer, int client)
{
	g_bStartPressingM1[client] = false;
	g_bStopPressingM1[client] = true;
	g_hFailSafeMedkit[client] = INVALID_HANDLE;
	return Plugin_Continue;
}

// ====================================================================================================
// Check, start pressing, or stop pressing primary mouse button
// ====================================================================================================
public Action OnPlayerRunCmd(int client, int& buttons)
{
	if (buttons & IN_ATTACK)
	{
		g_bM1pressed[client] = true;
	}
	else
	{
		g_bM1pressed[client] = false;
	}
	if (g_bStartPressingM1[client])
	{
		buttons |= IN_ATTACK;
		return Plugin_Changed;
	}
	if (g_bStopPressingM1[client])
	{
		buttons &= ~IN_ATTACK;
		g_bStopPressingM1[client] = false;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

// ====================================================================================================
// Play sound
// ====================================================================================================
void PlaySound(int client, const char sound[32])
{
	EmitSoundToClient(client, sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

// ====================================================================================================
// Prevent spamming chat messages
// ====================================================================================================
public Action ChatSpamTimer(Handle timer, int client)
{
	g_bChatSpam[client] = false;
	g_hChatSpam[client] = INVALID_HANDLE;
	return Plugin_Continue;
}

// ====================================================================================================
// Inventory functions
// ====================================================================================================
bool HasPillsOrAdrenaline(int client)
{
	return GetPlayerWeaponSlot(client, 4) != EMPTY_SLOT;
}

/****************************************************************************************************/
bool HasFirstAidKit(int client)
{
	int iFDU = GetPlayerWeaponSlot(client, 3);
	if (!IsValidEntity(iFDU))
	{
		return false;
	}
	static char sFDU[32];
	GetEntityClassname(iFDU, sFDU, sizeof(sFDU));
	return (strcmp(sFDU[7], "first_aid_kit") == 0);
}

/****************************************************************************************************/
public bool IsHoldingWeapon(int client, int slot)
{
	//get entity id of weapon in slot
	int iWeaponSlot = GetPlayerWeaponSlot(client, slot);
	if (!IsValidEntity(iWeaponSlot) || iWeaponSlot == 0)
	{
		return false;
	}
	//get entity id of active weapon
	int iWeaponActive = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (iWeaponActive == iWeaponSlot)
	{
		//active weapon is weapon in specified slot
		return true;
	}
	//switch to weapon in slot and check again in next frame
	EquipPlayerWeapon(client, iWeaponSlot);
	return false;
}
