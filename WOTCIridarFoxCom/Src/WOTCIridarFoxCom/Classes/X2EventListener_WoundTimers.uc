class X2EventListener_WoundTimers extends X2EventListener config(WoundTimers);

// Wound Timers in base game are highly inconsistent. They depend on the soldier's missing percent HP,
// and are heavily randomized.
// FOXCOM changes this logic in the following ways:
// 1. The base wound recovery time is flat and depends on how many points of HP need to be recovered, 
// where each point takes X days to recover.
// 2. Each turn the soldier spends wounded, extra healing time is added depending on how badly the soldier is wounded.
// 3. If the soldier is healed up, this extra time is reduced or removed completely.
// This creates an incentive to evacuate heavily wounded soldiers early, and increases the importance of mid-mission healing.

var private name				WoundTimerValue;

var private config float		BaseHealingTimeDaysPerMissingHP;
var private config array<float>	ExtraHealingTimeDaysPerTurnWoundedScaling;
var private config array<float>	HealedHealthWoundTimeReduction;

//static final function OnPreCreateTemplates()
//{
//	if (!`GetMCMSettingBool("PATCH_WOUND_TIMERS"))
//		return;
//}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	if (`GetMCMSettingBool("PATCH_WOUND_TIMERS"))
	{
		Templates.AddItem(Create_ListenerTemplate_Tactical());
		Templates.AddItem(Create_ListenerTemplate_Strategy());
	}

	return Templates;
}

/*
'AbilityActivated', AbilityState, SourceUnitState, NewGameState
'PlayerTurnBegun', PlayerState, PlayerState, NewGameState
'PlayerTurnEnded', PlayerState, PlayerState, NewGameState
'UnitDied', UnitState, UnitState, NewGameState
'KillMail', UnitState, Killer, NewGameState
'UnitTakeEffectDamage', UnitState, UnitState, NewGameState
'OnUnitBeginPlay', UnitState, UnitState, NewGameState
'OnTacticalBeginPlay', X2TacticalGameRuleset, none, NewGameState
*/

// Increase total healing time each turn
static function CHEventListenerTemplate Create_ListenerTemplate_Tactical()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_FOXCOM_X2EventListener_WoundTimers_Tactical');

	Template.RegisterInTactical = true;
	Template.RegisterInStrategy = false;

	if (`GetMCMSettingBool("PATCH_WOUND_TIMERS"))
	{	
		// Using on turn begin so that extra wound time isn't applied if the wound happened on the very last turn
		Template.AddCHEvent('PlayerTurnBegun', OnPlayerTurnBegun, ELD_OnStateSubmitted, 50);
	}

	return Template;
}

static private function EventListenerReturn OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState			NewGameState;
	local XComGameState_Unit	UnitState;
	local XComGameStateHistory	History;
	local XComGameState_Player	PlayerState;
	local float					ExtraHealingTime;


	if (!`GetMCMSettingBool("PATCH_WOUND_TIMERS"))
		return ELR_NoInterrupt;

	PlayerState = XComGameState_Player(EventSource);
	if (PlayerState == none || PlayerState.GetTeam() != eTeam_XCom)
		return ELR_NoInterrupt;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("FOXCOM PATCH_WOUND_TIMERS VALUE STEP");

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
    {
		// We care about not currently injured, as they might be simply healed up.
		if (!UnitState.IsInPlay() || UnitState.bRemovedFromPlay || UnitState.IsDead() /*|| !UnitState.IsInjured()*/ ) 
			continue;

		if (UnitState.ControllingPlayer.ObjectID != PlayerState.ObjectID)
			continue;
		
		// If we're here, this is a player-controlled unit that is wounded

		ExtraHealingTime = CalculateExtraHealingTime(UnitState);

		`AMLOG("PATCH_WOUND_TIMERS" @ UnitState.GetFullName() @ "Adding Healing Time:" @ ExtraHealingTime);
		
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
		UnitState.SetUnitFloatValue(default.WoundTimerValue, ExtraHealingTime, eCleanup_BeginTactical);
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`GAMERULES.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}
static private function float CalculateExtraHealingTime(const XComGameState_Unit UnitState)
{
	local UnitValue		UV;
	local int			Difficulty;
	local float			HealthPercent;
	local float			HealedHP;
	local float			AdjustedLowestHP;
	local float			HealingTime;

	Difficulty = `StrategyDifficultySetting;
	UnitState.GetUnitValue(default.WoundTimerValue, UV);

	HealedHP = UnitState.GetCurrentStat(eStat_HP) - UnitState.LowestHP;

	AdjustedLowestHP = UnitState.LowestHP + HealedHP * default.HealedHealthWoundTimeReduction[Difficulty];

	HealthPercent = UnitState.GetCurrentStat(eStat_HP) / UnitState.GetMaxStat(eStat_HP);

	`AMLOG("PATCH_WOUND_TIMERS" @ UnitState.GetFullName() @ "Lowest HP:" @ UnitState.LowestHP @ `ShowVar(HealedHP)  @ `ShowVar(AdjustedLowestHP) @ "Max HP:" @ UnitState.GetMaxStat(eStat_HP) @ `ShowVar(HealthPercent));
	
	HealingTime = default.ExtraHealingTimeDaysPerTurnWoundedScaling[Difficulty] * (1 - HealthPercent);

	`AMLOG("PATCH_WOUND_TIMERS" @ "previous extra Healing Time:" @ UV.fValue @ ", calculated extra Healing Time:" @ HealingTime @ ", total extra Healing Time:" @ HealingTime + UV.fValue);

	return HealingTime + UV.fValue;
}

// When tactical ends, assign accumulated healing time

static function CHEventListenerTemplate Create_ListenerTemplate_Strategy()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_FOXCOM_X2EventListener_WoundTimers_Strategy');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	if (`GetMCMSettingBool("PATCH_WOUND_TIMERS"))
	{	
		Template.AddCHEvent('PostMissionUpdateSoldierHealing', OnPostMissionUpdateSoldierHealing, ELD_OnStateSubmitted, 50);
	}

	return Template;
}

static private function EventListenerReturn OnPostMissionUpdateSoldierHealing(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState			NewGameState;
	local XComGameState_Unit	UnitState;
	local XComLWTuple			Tuple;
	local UnitValue				UV;
	local float					BaseHealingTime;
	local float					ExtraHealingTime;
	local int					TotalHealingTime;
	local XComGameState_HeadquartersProjectHealSoldier ProjectState;
	//local XComGameState_HeadquartersProjectHealSoldier OldProjectState;

	if (!`GetMCMSettingBool("PATCH_WOUND_TIMERS"))
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	// Soldier doesn't require healing.
	//if (UnitState.IsDead() || UnitState.bCaptured || !UnitState.IsSoldier() || !UnitState.IsInjured())
	//	return ELR_NoInterrupt;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	if (!Tuple.Data[0].b)
	{
		`AMLOG("PATCH_WOUND_TIMERS" @ UnitState.GetFullName() @ "Exiting because an event listener has disabled post mission healing.");
		return ELR_NoInterrupt;
	}

	foreach GameState.IterateByClassType(class'XComGameState_HeadquartersProjectHealSoldier', ProjectState)
	{
		if (ProjectState.ProjectFocus.ObjectID == UnitState.ObjectID)
		{
			// Old Project State is the healing project that already existed for this soldier before the mission,
			// because they went on the mission wounded.
			// but do we really want to double the healing time?
			// Scenario:
			// Soldier went on a mission, get wounded, returned with X base healing time + Y extra.
			// Went on another mission wounded, returned with P base healing time + Q extra, 
			// Both P and Q will be extra big, and already include X and  roughly Y (if soldier is not healed up at mission start)
			// So if we grab Old Project State here, we're gonna essentially double the healing time for no good reason.
			//OldProjectState = XComGameState_HeadquartersProjectHealSoldier(`XCOMHISTORY.GetGameStateForObjectID(ProjectState.ObjectID,, GameState.HistoryIndex - 1));

			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("FOXCOM PATCH_WOUND_TIMERS" @ UnitState.GetFullName());
			ProjectState = XComGameState_HeadquartersProjectHealSoldier(NewGameState.ModifyStateObject(ProjectState.Class, ProjectState.ObjectID));

			//if (OldProjectState != none)
			//{
			//	ProjectState.BlockPointsRemaining = OldProjectState.BlockPointsRemaining;
			//	ProjectState.ProjectPointsRemaining = OldProjectState.ProjectPointsRemaining;
			//}
			//else
			//{
				ProjectState.BlockPointsRemaining = 0;
				ProjectState.ProjectPointsRemaining = 0;
			//}

			BaseHealingTime = default.BaseHealingTimeDaysPerMissingHP * (UnitState.GetBaseStat(eStat_HP) - UnitState.GetCurrentStat(eStat_HP));
			
			UnitState.GetUnitValue(default.WoundTimerValue, UV);
			ExtraHealingTime = UV.fValue;

			TotalHealingTime = Round(BaseHealingTime + ExtraHealingTime);

			`AMLOG("PATCH_WOUND_TIMERS" @ UnitState.GetFullName() @ "Adding base Healing Time:" @ BaseHealingTime @ ", extra Healing Time:" @ ExtraHealingTime @ ", total:" @ TotalHealingTime @ "days.");

			ProjectState.AddRecoveryDays(TotalHealingTime);

			`GAMERULES.SubmitGameState(NewGameState);
			break;
		}
	}

	return ELR_NoInterrupt;
}




defaultproperties
{
	WoundTimerValue = "IRI_FOXCOM_WoundTimer_Value"
}