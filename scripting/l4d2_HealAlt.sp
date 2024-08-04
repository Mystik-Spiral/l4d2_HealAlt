// ====================================================================================================
// Defines for Plugin Info
// ====================================================================================================
#define PLUGIN_NAME               "[L4D2] Healing Alternative"
#define PLUGIN_AUTHOR             "Mystik Spiral"
#define PLUGIN_DESCRIPTION        "Improve when healing items are used."
#define PLUGIN_VERSION            "1.1"
#define PLUGIN_URL                "https://forums.alliedmods.net/showthread.php?t=347667"

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
#define SURVIVOR_TEAM             2
#define EMPTY_SLOT                -1
#define INVALID_ENTITY            -1
#define PILLS_TARGET              39.0
#define MEDKIT_TARGET             34.0

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

//Allowed Game Modes related
ConVar	g_hCvarAllow, g_hCvarMPGameMode;
ConVar	g_hCvarModesOn, g_hCvarModesOff, g_hCvarModesTog;
bool	g_bCvarAllow, g_bMapStarted;
int		g_iCurrentMode;

//Required extensions related
bool g_bExtensionActions;
bool g_bExtensionScramble;

//Required ConVar values related
ConVar g_hCvar_fSTHCF;
ConVar g_hCvar_iSTB, g_hCvar_iPPHT;
float g_Save_fSTHCF;
int g_Save_iSTB, g_Save_iPPHT;

//Plugin late load flag
bool g_bLateLoad;

//ConVar hook related
ConVar g_hCvar_fRange;
float g_fRange;

//Mouse button related
bool g_bStartPressingM1[MAXPLAYERS + 1];
bool g_bStopPressingM1[MAXPLAYERS + 1];
bool g_bM1pressed[MAXPLAYERS +1];
bool g_bM2pressed[MAXPLAYERS + 1];

//Prevent chat spam related
Handle g_hChatSpam[MAXPLAYERS + 1];
bool g_bChatSpam[MAXPLAYERS + 1];

//Healing targets related
float g_fMedkit = MEDKIT_TARGET;
float g_fPills = PILLS_TARGET;

//MemoryPatch related
bool g_bPatched;
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
	// en,es,fr,ru,zho
	// ====================
	LoadPluginTranslations();
	
	// ====================
	// Set default ConVars
	// ====================
	CreateConVar("HealAlt_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);

	//Allowed Game Modes
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarAllow = CreateConVar("HealAlt_enabled", "1", "0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModesOn = CreateConVar("HealAlt_modes_on", "", "Game mode names on, comma separated, no spaces. (Empty=all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar("HealAlt_modes_off", "", "Game mode names off, comma separated, no spaces. (Empty=none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar("HealAlt_modes_tog", "1", "Game type bitflags on, add #s together. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge", CVAR_FLAGS );

	//Other ConVars
	g_hCvar_fRange = FindConVar("player_use_radius");
	g_hCvar_fSTHCF = FindConVar("sb_temp_health_consider_factor");
	g_hCvar_iSTB = FindConVar("sb_toughness_buffer");
	g_hCvar_iPPHT = FindConVar("pain_pills_health_threshold");
	
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
	
	//Other ConVar hooks
	g_hCvar_fRange.AddChangeHook(ConVarChanged_Cvars);
	
	// ====================
	// Hook events
	// ====================
	HookEvent("heal_success", HealSuccess, EventHookMode_Post);
	HookEvent("pills_used", PillsUsed, EventHookMode_Post);
	HookEvent("adrenaline_used", AdrenalineUsed, EventHookMode_Post);
	HookEvent("weapon_given", WeaponGiven, EventHookMode_Post);
	HookEvent("door_close", DoorClose, EventHookMode_Pre);
	HookEvent("round_start", RoundStart, EventHookMode_PostNoCopy);
	
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
		g_bMapStarted = true;
		IsAllowed();
		if (g_bCvarAllow)
		{
			GetCvars();
			EnablePatches();
		}
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
	if (g_bCvarAllow)
	{
		if (!g_bPatched)
		{
			EnablePatches();
		}
	}
	else
	{
		if (g_bPatched)
		{
			DisablePatches();
		}
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
	// First Aid
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
	// Pills
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

	// ====================
	// Hook ConVars
	// ====================
	g_hCvar_fSTHCF.AddChangeHook(ConVarChanged_Cvars);
	g_hCvar_iSTB.AddChangeHook(ConVarChanged_Cvars);
	g_hCvar_iPPHT.AddChangeHook(ConVarChanged_Cvars);
	
	PrintToServer("[HealAlt] Enabled memory patches and ConVar changes");
}

/****************************************************************************************************/
public void DisablePatches()
{
	g_hPatchFirst1.Disable();
	g_hPatchFirst2.Disable();
	g_hPatchPills1.Disable();
	g_hPatchPills2.Disable();

	g_bPatched = false;

	// ====================
	// Unhook ConVars
	// ====================
	g_hCvar_fSTHCF.RemoveChangeHook(ConVarChanged_Cvars);
	g_hCvar_iSTB.RemoveChangeHook(ConVarChanged_Cvars);
	g_hCvar_iPPHT.RemoveChangeHook(ConVarChanged_Cvars);
	
	// ====================
	// Restore ConVars
	// ====================
	g_hCvar_fSTHCF.SetFloat(g_Save_fSTHCF);
	g_hCvar_iSTB.SetInt(g_Save_iSTB);
	g_hCvar_iPPHT.SetInt(g_Save_iPPHT);
	
	PrintToServer("[HealAlt] Disabled memory patches and ConVar changes");
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
public void RoundStart(Event event, char[] name, bool dontBroadcast)
{
	//safety clear to prevent stuck M1 key
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bStartPressingM1[i] = false;
		g_bStopPressingM1[i] = true;
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
	//player_use_radius
	g_fRange = g_hCvar_fRange.FloatValue;

	//sb_temp_health_consider_factor
	if (g_hCvar_fSTHCF.FloatValue != 1.0)
	{
		g_Save_fSTHCF = g_hCvar_fSTHCF.FloatValue;
		g_hCvar_fSTHCF.SetFloat(1.0);
	}
	//sb_toughness_buffer
	if (g_hCvar_iSTB.IntValue != 0)
	{
		g_Save_iSTB = g_hCvar_iSTB.IntValue;
		g_hCvar_iSTB.SetInt(0);
	}
	//pain_pills_health_threshold
	if (g_hCvar_iPPHT.IntValue != 90)
	{
		g_Save_iPPHT = g_hCvar_iPPHT.IntValue;
		g_hCvar_iPPHT.SetInt(90);
	}
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
		bool players = true;
		target = L4D_FindUseEntity(client, players, g_fRange);
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
			if (IsInGameAliveSurvivor(i) && GetClientHealth(i) < iLowestHealth && !HasFirstAidKit(i))
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

/****************************************************************************************************/
public void HealSuccess(Event event, char[] name, bool dontBroadcast)
{
	if (!g_bCvarAllow)
	{
		return;
	}
	float fTime = GetGameTime();
	int iHealer = GetClientOfUserId(GetEventInt(event,"userid"));
	int iHealee = GetClientOfUserId(GetEventInt(event,"subject"));
	if ((iHealer > 0 && iHealer <= MaxClients) && (iHealee > 0 && iHealee <= MaxClients) && IsFakeClient(iHealer))
	{
		if (iHealer != iHealee)
		{
			PrintToServer("[HealAlt] %f: %N healed %N", fTime, iHealer, iHealee);
		}
		else
		{
			PrintToServer("[HealAlt] %f: %N healed self", fTime, iHealer);
		}
		g_bStartPressingM1[iHealer] = false;
		g_bStopPressingM1[iHealer] = true;
	}
}

/****************************************************************************************************/
public void PillsUsed(Event event, char[] name, bool dontBroadcast)
{
	if (!g_bCvarAllow)
	{
		return;
	}
	float fTime = GetGameTime();
	int iHealer = GetClientOfUserId(GetEventInt(event,"subject"));
	if (iHealer > 0 && iHealer <= MaxClients && IsFakeClient(iHealer))
	{
		PrintToServer("[HealAlt] %f: %N swallowed pills", fTime, iHealer);
		g_bStartPressingM1[iHealer] = false;
		g_bStopPressingM1[iHealer] = true;
	}
}

/****************************************************************************************************/
public void AdrenalineUsed(Event event, char[] name, bool dontBroadcast)
{
	if (!g_bCvarAllow)
	{
		return;
	}
	float fTime = GetGameTime();
	int iHealer = GetClientOfUserId(GetEventInt(event,"userid"));
	if (iHealer > 0 && iHealer <= MaxClients && IsFakeClient(iHealer))
	{
		PrintToServer("[HealAlt] %f: %N injected adrenaline", fTime, iHealer);
		g_bStartPressingM1[iHealer] = false;
		g_bStopPressingM1[iHealer] = true;
	}
}

/****************************************************************************************************/
public void WeaponGiven(Event event, char[] name, bool dontBroadcast)
{
	if (!g_bCvarAllow)
	{
		return;
	}
	float fTime = GetGameTime();
	int iWeapId = GetEventInt(event, "weapon");
	int iRcvr = GetClientOfUserId(GetEventInt(event,"userid"));
	int iGvr = GetClientOfUserId(GetEventInt(event,"giver"));
	if (iGvr > 0 && iGvr <= MaxClients && iRcvr > 0 && iRcvr <= MaxClients && IsFakeClient(iGvr))
	{
		if (iWeapId == 15)		//pain_pills
		{
			PrintToServer("[HealAlt] %f: %N gave pills to %N", fTime, iGvr, iRcvr);
		}
		else if (iWeapId == 23)	//adrenaline
		{
			PrintToServer("[HealAlt] %f: %N gave adrenaline to %N", fTime, iGvr, iRcvr);
		}
	}
}

/****************************************************************************************************/
public void DoorClose(Event event, char[] name, bool dontBroadcast)
{
	if (!g_bCvarAllow)
	{
		return;
	}
	bool bCPdoor = (GetEventBool(event, "checkpoint"));
	if (bCPdoor)
	{
		bool bWillTriggerMT = true;
		//check if any alive survivor is outside the ending safe area
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsInGameAliveSurvivor(i))
			{
				if (!L4D_IsInLastCheckpoint(i))
				{
					bWillTriggerMT = false;
					break;
				}
			}
		}
		if (bWillTriggerMT)
		{
			//map_transition is about to be triggered
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsInGameAliveSurvivor(i))
				{
					int iHealth = GetClientHealth(i);
					if (IsFakeClient(i) && HasFirstAidKit(i))
					{
						if (iHealth < 80)
						{
							//survivor bot with medkit and < 80 health should heal
							SetEntityHealth(i, iHealth + RoundToFloor((100 - iHealth) * 0.8));
							L4D_SetTempHealth(i, 0.0);
							SetEntProp(i, Prop_Send, "m_currentReviveCount", 0);
							SetEntProp(i, Prop_Send, "m_bIsOnThirdStrike", 0);
							SetEntProp(i, Prop_Send, "m_isGoingToDie", 0);
							StopSound(i, SNDCHAN_AUTO, HEARTBEAT_SOUND);
							StopSound(i, SNDCHAN_STATIC, HEARTBEAT_SOUND);
							PrintToServer("[HealAlt] %f: %N healed self", GetGameTime(), i);
							RemoveEntity(GetPlayerWeaponSlot(i, 3));
						}
					}
					else
					{
						if (iHealth < 40 && !HasFirstAidKit(i))
						{
							//any survivor without a medkit and < 40 health gets a minimal heal
							SetEntityHealth(i, 40);
							L4D_SetTempHealth(i, 0.0);
							SetEntProp(i, Prop_Send, "m_currentReviveCount", 0);
							SetEntProp(i, Prop_Send, "m_bIsOnThirdStrike", 0);
							SetEntProp(i, Prop_Send, "m_isGoingToDie", 0);
							StopSound(i, SNDCHAN_AUTO, HEARTBEAT_SOUND);
							StopSound(i, SNDCHAN_STATIC, HEARTBEAT_SOUND);
							PrintToServer("[HealAlt] %f: %N received minimal heal", GetGameTime(), i);
						}
					}
				}
			}
		}
	}
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
	bool bBW = GetEntProp(actor, Prop_Send, "m_bIsOnThirdStrike") == 1;
	bool bInChkPt = L4D_IsInFirstCheckpoint(actor) || L4D_IsInLastCheckpoint(actor);
	float fTime = GetGameTime();
	//chance to skip action redirect
	bool bChance = false;
	if (L4D_IsMissionFinalMap())
	{
		bChance = GetRandomInt(1, 10) > 1;	//90%
	}
	else
	{
		bChance = GetRandomInt(1, 10) > 9;	//10%
	}
	//check if bot should take pills/adrenaline instead of using medkit
	if (!bChance && !bInChkPt && !bBW && HasPillsOrAdrenaline(actor))
	{
		PrintToServer("[HealAlt] %f: %N will attempt to use pills/adrenaline instead of healing self with medkit.", fTime, actor);
		SurvivorPillsAdrenHealSelf take = SurvivorPillsAdrenHealSelf();
		action.ChangeTo(take, "TakePills_InsteadOf_HealSelf");
		return Plugin_Handled;
	}
	
	PrintToServer("[HealAlt] %f: %N allowed to heal self with medkit.", fTime, actor);
	return Plugin_Continue;
}

/****************************************************************************************************/
public Action OnFriendActionMedkit(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	int target = action.Get(0x34) & 0xFFF;
	bool bHasHealingItems = HasFirstAidKit(target) || HasPillsOrAdrenaline(target);
	int iTotalHealthFriend = GetClientHealth(target) + L4D_GetPlayerTempHealth(target);
	int iTotalHealthSelf = GetClientHealth(actor) + L4D_GetPlayerTempHealth(actor);
	bool bInChkPt = L4D_IsInFirstCheckpoint(target) || L4D_IsInLastCheckpoint(target);
	float fTime = GetGameTime();
	//chance to skip action redirect
	bool bChance = false;
	if (L4D_IsMissionFinalMap())
	{
		bChance = GetRandomInt(1, 10) > 1;	//90%
	}
	else
	{
		bChance = GetRandomInt(1, 10) > 9;	//10%
	}
	//check if bot should heal friend with medkit
	bool allow = (GetEntProp(target, Prop_Send, "m_bIsOnThirdStrike") == 1 && !HasFirstAidKit(target)) || bChance || bInChkPt || (iTotalHealthFriend <= MEDKIT_TARGET && !bHasHealingItems);

	//check if bot should take pills/adrenaline instead of healing friend with medkit
	if (!allow && HasPillsOrAdrenaline(actor) && (!HasFirstAidKit(actor) || (HasFirstAidKit(actor) && GetEntProp(actor, Prop_Send, "m_bIsOnThirdStrike") != 1)) && iTotalHealthSelf <= PILLS_TARGET)
	{
		PrintToServer("[HealAlt] %f: %N will attempt to use pills/adrenaline instead of healing %N with medkit.", fTime, actor, target);
		SurvivorPillsAdrenHealSelf take = SurvivorPillsAdrenHealSelf();
		action.ChangeTo(take, "TakePills_InsteadOf_HealFriend");
		return Plugin_Handled;
	}
	
	//check if bot should heal self with medkit instead of healing friend with medkit
	if (!allow && HasFirstAidKit(actor) && (GetEntProp(actor, Prop_Send, "m_bIsOnThirdStrike") == 1 || iTotalHealthSelf <= MEDKIT_TARGET))
	{
		PrintToServer("[HealAlt] %f: %N will attempt to heal self with medkit instead of healing %N with medkit.", fTime, actor, target);
		SurvivorMedkitHealSelf take = SurvivorMedkitHealSelf();
		action.ChangeTo(take, "HealSelf_InsteadOf_HealFriend");
		return Plugin_Handled;
	}
	
	if (allow)
	{
		PrintToServer("[HealAlt] %f: %N allowed to heal %N with medkit.", fTime, actor, target);
	}
	else
	{
		PrintToServer("[HealAlt] %f: %N blocked from healing %N with medkit.", fTime, actor, target);
	}
	
	result.type = allow ? CONTINUE : DONE;
	return Plugin_Changed;
}

/****************************************************************************************************/
public Action OnSelfActionPills(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	float fTime = GetGameTime();
	//check if bot should heal self with medkit instead of taking pills/adrenaline
	if (HasFirstAidKit(actor) && GetEntProp(actor, Prop_Send, "m_bIsOnThirdStrike") == 1)
	{
		PrintToServer("[HealAlt] %f: %N will attempt to heal self with medkit instead of taking pills/adrenaline.", fTime, actor);
		SurvivorMedkitHealSelf take = SurvivorMedkitHealSelf();
		action.ChangeTo(take, "HealSelf_InsteadOf_TakePills");
		return Plugin_Handled;
	}
	
	PrintToServer("[HealAlt] %f: %N allowed to use pills/adrenaline.", fTime, actor);
	return Plugin_Continue;
}

/****************************************************************************************************/
public Action OnFriendActionPills(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	int target = action.Get(0x34) & 0xFFF;
	int iTotalHealthSelf = GetClientHealth(actor) + L4D_GetPlayerTempHealth(actor);
	float fTime = GetGameTime();
	
	//check if bot should take pills/adrenaline instead of giving pills/adrenaline to friend
	if (HasPillsOrAdrenaline(actor) && iTotalHealthSelf <= PILLS_TARGET && !(HasFirstAidKit(actor) && GetEntProp(actor, Prop_Send, "m_bIsOnThirdStrike") == 1))
	{
		PrintToServer("[HealAlt] %f: %N will attempt to use pills/adrenaline instead of giving pills/adrenaline to %N.", fTime, actor, target);
		SurvivorPillsAdrenHealSelf take = SurvivorPillsAdrenHealSelf();
		action.ChangeTo(take, "TakePills_InsteadOf_GivePillsToFriend");
		return Plugin_Handled;
	}
	
	PrintToServer("[HealAlt] %f: %N allowed to give pills/adrenaline to %N.", fTime, actor, target);
	return Plugin_Continue;
}

// ====================================================================================================
// OnStart custom actions
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
		return action.Done("Used pills/adrenaline");
	}
	//true=holding, false=switch next frame
	if (IsHoldingWeapon(actor, 4))
	{
		g_bStartPressingM1[actor] = true;
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
	}
	return action.Continue();
}

// ====================================================================================================
// OnEnd custom actions
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
// Check, start pressing, or stop pressing mouse button
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
	if (buttons & IN_ATTACK2)
	{
		g_bM2pressed[client] = true;
	}
	else
	{
		g_bM2pressed[client] = false;
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
// Prevent spamming chat messages
// ====================================================================================================
public Action ChatSpamTimer(Handle timer, int client)
{
	g_bChatSpam[client] = false;
	g_hChatSpam[client] = INVALID_HANDLE;
	return Plugin_Continue;
}

// ====================================================================================================
// Common client check
// ====================================================================================================
public bool IsInGameAliveSurvivor(int client)
{
	return IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == SURVIVOR_TEAM;
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
	//get name of weapon in slot
	static char sWeapon[32];
	GetEdictClassname(iWeaponSlot, sWeapon, sizeof(sWeapon));
	//switch slot weapon to active weapon and check again in next frame
	FakeClientCommand(client, "use %s", sWeapon);
	return false;
}
