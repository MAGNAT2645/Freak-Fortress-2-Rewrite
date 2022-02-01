/*
	void ConVar_PluginStart()
	void ConVar_Enable()
	void ConVar_Disable()
*/

enum struct CvarInfo
{
	ConVar cvar;
	char value[16];
	char defaul[16];
	bool enforce;
}

static ArrayList CvarList;
static bool CvarHooked;

void ConVar_PluginStart()
{
	CreateConVar("ff2_version", "Rewrite " ... PLUGIN_VERSION, "Freak Fortress 2 Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CvarCharset = CreateConVar("ff2_charset", "0", "Boss pack set for next load", FCVAR_DONTRECORD);
	CvarDebug = CreateConVar("ff2_debug", "1", "If to display debug outputs", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	CvarSpecTeam = CreateConVar("ff2_game_spec", "1", "If to handle spectator teams as real fighting teams", _, true, 0.0, true, 1.0);
	CvarBossVsBoss = CreateConVar("ff2_game_bvb", "0", "How many bosses per a team, 0 to disable", _, true, 0.0, true, float(MaxClients/2));
	CvarBossSewer = CreateConVar("ff2_game_suicide", "1", "If bosses can use kill binds during the round", _, true, 0.0, true, 1.0);
	CvarHealthBar = CreateConVar("ff2_game_healthbar", "3", "If a health bar and/or text will be shown, 1 = Health Bar, 2 = Health Display, 3 = Both", _, true, 0.0, true, 3.0);
	CvarBossTriple = CreateConVar("ff2_boss_triple", "1", "If v1 bosses will deal extra damage versus players by default", _, true, 0.0, true, 1.0);
	CvarBossCrits = CreateConVar("ff2_boss_crits", "0", "If v1 bosses can perform random crits by default", _, true, 0.0, true, 1.0);
	CvarBossKnockback = CreateConVar("ff2_boss_knockback", "0", "If v1 bosses can perform self-knockback by default, 2 will also allow self-damage", _, true, 0.0, true, 2.0);
	CvarPrefBlacklist = CreateConVar("ff2_pref_blacklist", "-1", "If boss selection whitelist is a blacklist instead with the limit being the value of this cvar", _, true, 0.0);
	
	CreateConVar("ff2_oldjump", "1", "Backwards Compatibility ConVar", FCVAR_DONTRECORD|FCVAR_HIDDEN, true, 0.0, true, 1.0);
	CreateConVar("ff2_base_jumper_stun", "0", "Backwards Compatibility ConVar", FCVAR_DONTRECORD|FCVAR_HIDDEN, true, 0.0, true, 1.0);
	CreateConVar("ff2_solo_shame", "0", "Backwards Compatibility ConVar", FCVAR_DONTRECORD|FCVAR_HIDDEN, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "FF2Rewrite");
	
	CvarAllowSpectators = FindConVar("mp_allowspectators");
	CvarMovementFreeze = FindConVar("tf_player_movement_restart_freeze");
	CvarPreroundTime = FindConVar("tf_arena_preround_time");
	CvarTournament = FindConVar("mp_tournament");
	CvarTournament.Flags &= ~(FCVAR_NOTIFY|FCVAR_REPLICATED);
	
	if(CvarList != INVALID_HANDLE)
		delete CvarList;
	
	CvarList = new ArrayList(sizeof(CvarInfo));
	
	ConVar_Add("tf_arena_first_blood", "0");
	ConVar_Add("tf_arena_use_queue", "0");
	ConVar_Add("mp_forcecamera", "0", false);
	ConVar_Add("mp_humans_must_join_team", "any");
	ConVar_Add("mp_teams_unbalance_limit", "0");
	ConVar_Add("mp_waitingforplayers_time", "90.0", false);
}

static void ConVar_Add(const char[] name, const char[] value, bool enforce=true)
{
	CvarInfo info;
	info.cvar = FindConVar(name);
	strcopy(info.value, sizeof(info.value), value);
	info.enforce = enforce;

	if(CvarHooked)
	{
		info.cvar.GetString(info.defaul, sizeof(info.defaul));
		info.cvar.SetString(info.value);
		info.cvar.AddChangeHook(ConVar_OnChanged);
	}

	CvarList.PushArray(info);
}

stock void ConVar_Remove(const char[] name)
{
	ConVar cvar = FindConVar(name);
	int index = CvarList.FindValue(cvar, CvarInfo::cvar);
	if(index != -1)
	{
		CvarInfo info;
		CvarList.GetArray(index, info);
		CvarList.Erase(index);

		if(CvarHooked)
		{
			info.cvar.RemoveChangeHook(ConVar_OnChanged);
			info.cvar.SetString(info.defaul);
		}
	}
}

void ConVar_Enable()
{
	if(!CvarHooked)
	{
		int length = CvarList.Length;
		for(int i; i<length; i++)
		{
			CvarInfo info;
			CvarList.GetArray(i, info);
			info.cvar.GetString(info.defaul, sizeof(info.defaul));
			CvarList.SetArray(i, info);

			info.cvar.SetString(info.value);
			info.cvar.AddChangeHook(ConVar_OnChanged);
		}

		CvarHooked = true;
	}
}

void ConVar_Disable()
{
	if(CvarHooked)
	{
		int length = CvarList.Length;
		for(int i; i<length; i++)
		{
			CvarInfo info;
			CvarList.GetArray(i, info);

			info.cvar.RemoveChangeHook(ConVar_OnChanged);
			info.cvar.SetString(info.defaul);
		}

		CvarHooked = false;
	}
}

public void ConVar_OnChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	int index = CvarList.FindValue(cvar, CvarInfo::cvar);
	if(index != -1)
	{
		CvarInfo info;
		CvarList.GetArray(index, info);

		if(!StrEqual(info.value, newValue))
		{
			if(info.enforce)
			{
				strcopy(info.defaul, sizeof(info.defaul), newValue);
				CvarList.SetArray(index, info);
				info.cvar.SetString(info.value);
			}
			else
			{
				char buffer[64];
				cvar.GetName(buffer, sizeof(buffer));
				Debug("Removed ConVar %s", buffer);
				info.cvar.RemoveChangeHook(ConVar_OnChanged);
				CvarList.Erase(index);
			}
		}
	}
}