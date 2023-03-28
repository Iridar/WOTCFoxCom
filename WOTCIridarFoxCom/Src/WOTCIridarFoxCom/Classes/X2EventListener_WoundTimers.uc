class X2EventListener_WoundTimers extends X2EventListener;

var private name WoundTimerValue;

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

static function CHEventListenerTemplate Create_ListenerTemplate_Tactical()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_FOXCOM_X2EventListener_WoundTimers_Tactical');

	Template.RegisterInTactical = true;
	Template.RegisterInStrategy = false;

	if (`GetMCMSettingBool("PATCH_WOUND_TIMERS"))
	{	
		Template.AddCHEvent('PlayerTurnEnded', OnPlayerTurnEnded, ELD_OnStateSubmitted, 50);
	}

	return Template;
}

static private function EventListenerReturn OnPlayerTurnEnded(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState			NewGameState;
	local XComGameState_Unit	UnitState;
	local XComGameStateHistory	History;
	local XComGameState_Player	PlayerState;
	local UnitValue				UV;
	local int					AddRecoveryTime;

	if (!`GetMCMSettingBool("PATCH_WOUND_TIMERS"))
		return ELR_NoInterrupt;

	PlayerState = XComGameState_Player(EventSource);
	if (PlayerState == none || PlayerState.GetTeam() != eTeam_XCom)
		return ELR_NoInterrupt;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("FOXCOM PATCH_WOUND_TIMERS VALUE STEP");

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
    {
		if (!UnitState.IsInPlay() || UnitState.bRemovedFromPlay || UnitState.IsDead() || !UnitState.IsInjured())
			continue;

		if (UnitState.ControllingPlayer.ObjectID != PlayerState.ObjectID)
			continue;
		
		// If we're here, this is a player-controlled unit that is wounded

		AddRecoveryTime = UnitState.GetMaxStat(eStat_HP) - UnitState.GetCurrentStat(eStat_HP);
		UnitState.GetUnitValue(default.WoundTimerValue, UV);

		`AMLOG("PATCH_WOUND_TIMERS" @ UnitState.GetFullName() @ "Current recovery time:" @ UV.fValue @ "Adding recovery time:" @ AddRecoveryTime);

		UV.fValue += AddRecoveryTime;
		
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
		UnitState.SetUnitFloatValue(default.WoundTimerValue, UV.fValue, eCleanup_BeginTactical);
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
	local XComGameState_HeadquartersProjectHealSoldier ProjectState;
	local XComGameState_HeadquartersProjectHealSoldier OldProjectState;

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

	if (!UnitState.GetUnitValue(default.WoundTimerValue, UV))
	{
		`AMLOG("PATCH_WOUND_TIMERS" @ UnitState.GetFullName() @ "Exiting because the Unit doesn't have a Unit Timer value.");
		return ELR_NoInterrupt;
	}

	foreach GameState.IterateByClassType(class'XComGameState_HeadquartersProjectHealSoldier', ProjectState)
	{
		if (ProjectState.ProjectFocus.ObjectID == UnitState.ObjectID)
		{
			OldProjectState = XComGameState_HeadquartersProjectHealSoldier(`XCOMHISTORY.GetGameStateForObjectID(ProjectState.ObjectID,, GameState.HistoryIndex - 1));

			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("FOXCOM PATCH_WOUND_TIMERS" @ UnitState.GetFullName());
			ProjectState = XComGameState_HeadquartersProjectHealSoldier(NewGameState.ModifyStateObject(ProjectState.Class, ProjectState.ObjectID));

			if (OldProjectState != none)
			{
				ProjectState.BlockPointsRemaining = OldProjectState.BlockPointsRemaining;
				ProjectState.ProjectPointsRemaining = OldProjectState.ProjectPointsRemaining;
			}
			else
			{
				ProjectState.BlockPointsRemaining = 0;
				ProjectState.ProjectPointsRemaining = 0;
			}
			ProjectState.AddRecoveryDays(UV.fValue);

			`AMLOG("PATCH_WOUND_TIMERS" @ UnitState.GetFullName() @ "Adding" @ int(UV.fValue) @ "days of healing time.");

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