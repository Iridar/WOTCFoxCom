class X2Effect_BleedoutPenalty extends X2Effect_PersistentStatChange config(BleedoutPenalty);

var private config array<ECharStatType>	PossibleStatPenalties;	// Default deck

var private config array<int>			MaxTotalStatPenalty;
var private config array<int>			MinPenaltyValue;
var private config array<int>			MaxPenaltyValue;

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager EventMgr;
	local XComGameState_Unit UnitState;
	local Object EffectObj;

	if (!`GetMCMSettingBool("STAT_PENALTY_ON_BLEEDOUT"))
		return;

	EventMgr = `XEVENTMGR;

	EffectObj = EffectGameState;
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.SourceStateObjectRef.ObjectID));
	if (UnitState == none)
		return;
	//EventMgr.RegisterForEvent(EffectObj, 'X2Effect_BleedoutPenalty_Event', EffectGameState.TriggerAbilityFlyover, ELD_OnStateSubmitted, , UnitState);
	
	//	local X2EventManager EventMgr;
	//	AbilityState = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(SourceUnit.FindAbility('ABILITY_NAME').ObjectID));
	//	EventMgr = `XEVENTMGR;
	//	EventMgr.TriggerEvent('X2Effect_BleedoutPenalty_Event', AbilityState, SourceUnit, NewGameState);
	
	EventMgr.RegisterForEvent(EffectObj, 'UnitBleedingOut', OnUnitBleedingOut, ELD_Immediate,, UnitState,, EffectObj);	
	/*
	native function RegisterForEvent( ref Object SourceObj, 
									Name EventID, 
									delegate<OnEventDelegate> NewDelegate, 
									optional EventListenerDeferral Deferral=ELD_Immediate, 
									optional int Priority=50, 
									optional Object PreFilterObject, 
									optional bool bPersistent, 
									optional Object CallbackData );*/
	
	super.RegisterForEvents(EffectGameState);
}


static private function EventListenerReturn OnUnitBleedingOut(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit	UnitState;
	local UnitValue				UV;

	if (!`GetMCMSettingBool("STAT_PENALTY_ON_BLEEDOUT"))
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	if (UnitState == none)
		return ELR_NoInterrupt;

	if (GeneratePenaltyForUnit(UnitState, NewGameState))
	{	
		// Use the effect name as the name of the unit value for tracking how many times this unit was penalized.
		UnitState.GetUnitValue(default.EffectName, UV);
		UnitState.SetUnitFloatValue(default.EffectName, UV.fValue + 1, eCleanup_Never);

		// TODO: Add visualization
	}

	return ELR_NoInterrupt;
}

function bool IsEffectCurrentlyRelevant(XComGameState_Effect EffectGameState, XComGameState_Unit TargetUnit) 
{
	return EffectGameState.StatChanges.Length > 0;
	//return DoesUnitHaveAnyPenalty(TargetUnit); 
}

static final function bool DoesUnitHaveAnyPenalty(const XComGameState_Unit UnitState)
{
	local UnitValue UV;

	return UnitState.GetUnitValue(default.EffectName, UV);
}

static private function bool GeneratePenaltyForUnit(XComGameState_Unit UnitState, XComGameState NewGameState)
{
	local X2CustomCardManager	CardMgr;
	local name					DeckName;
	local ECharStatType			StatType;
	local string				DrawnCard;
	local int					GeneratedPenaltyValue;
	local int					MinValue;
	local int					MaxValue;

	`AMLOG("STAT_PENALTY_ON_BLEEDOUT Running for:" @ UnitState.GetFullName());

	CardMgr = class'X2CustomCardManager'.static.GetAndPrepCustomCardManager(NewGameState);
	DeckName = name(default.EffectName $ UnitState.ObjectID);

	// Fill deck for this unit if we haven't done so previously.
	if (!CardMgr.DoesDeckExist(DeckName))
	{
		`AMLOG("First time bleedout - generating deck:" @ DeckName);
		foreach default.PossibleStatPenalties(StatType)
		{
			// Double conversion to store as int, otherwise the enum gets stored as a string and cannot be easily converted back.
			CardMgr.AddCardToDeck(DeckName, string(int(StatType))); 
		}
	}

	// If the deck has been completely exhausted, then all stat penalties are already at maximum, and we don't need to do anything.
	if (CardMgr.GetNumCardsInDeck(DeckName) <= 0)
	{
		`AMLOG("Deck:" @ DeckName @ "is empty, exiting.");
		return false;
	}

	CardMgr.SelectNextCardFromDeck(DeckName, DrawnCard,,, true);

	StatType = ECharStatType(int(DrawnCard));

	// [x; y] randomization
	MinValue = default.MinPenaltyValue[StatType];
	MaxValue = default.MaxPenaltyValue[StatType];
	if (MinValue == MaxValue)
	{
		GeneratedPenaltyValue = MinValue;
	}
	else
	{
		// Put minuses everywhere cuz int rand don't like no negative numbers
		GeneratedPenaltyValue = -class'Help'.static.GetRandomInt(-MinValue, -MaxValue);
	}

	`AMLOG("Selected stat to penalyze:" @ StatType @ "Generated penalty:" @ GeneratedPenaltyValue @ "out of:" @ MinValue @ "-" @ MaxValue);

	// If this penalty is at maximum, remove it from the deck so it cannot be drawn again.
	if (SetCurrentStatPenalty(UnitState, StatType, GeneratedPenaltyValue))
	{
		`AMLOG("This penalty is at maximum, removing card from deck.");

		CardMgr.RemoveCardFromDeck(DeckName, DrawnCard);
	}

	return true;
}



static private function int GetCurrentStatPenalty(const XComGameState_Unit UnitState, const ECharStatType StatType)
{
	local UnitValue UV;
	local name ValueName;

	ValueName = name(default.EffectName $ StatType);

	UnitState.GetUnitValue(ValueName, UV);

	return UV.fValue;
}

static private function bool SetCurrentStatPenalty(XComGameState_Unit NewUnitState, const ECharStatType StatType, int PenaltyValue)
{
	local name ValueName;
	local bool bPenaltyReachedMaximum;

	ValueName = name(default.EffectName $ StatType);

	PenaltyValue += GetCurrentStatPenalty(NewUnitState, StatType);

	if (PenaltyValue <= default.MaxTotalStatPenalty[StatType])
	{
		PenaltyValue = default.MaxTotalStatPenalty[StatType];
		bPenaltyReachedMaximum = true;
	}

	NewUnitState.SetUnitFloatValue(ValueName, PenaltyValue, eCleanup_Never);

	return bPenaltyReachedMaximum;
}

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local StatChange			Change;
	local ECharStatType			PossibleStatPenalty;
	local XComGameState_Unit	UnitState;

	m_aStatChanges.Length = 0;

	if (!`GetMCMSettingBool("STAT_PENALTY_ON_BLEEDOUT"))
		return;

	UnitState = XComGameState_Unit(kNewTargetState);
	if (UnitState == none)
		return;

	`AMLOG("STAT_PENALTY_ON_BLEEDOUT Running for unit:" @ UnitState.GetFullName());

	foreach PossibleStatPenalties(PossibleStatPenalty)
	{
		Change.StatAmount = GetCurrentStatPenalty(UnitState, PossibleStatPenalty);
		if (Change.StatAmount > 0)
		{
			Change.StatType = PossibleStatPenalty;

			`AMLOG("Adding penalty to stat:" @ Change.StatType $ ", amount:" @ Change.StatAmount);

			m_aStatChanges.AddItem(Change);
		}
	}

	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
}


static final function bool AbilityTagExpandHandler_CH(string InString, out string OutString, Object ParseObj, Object StrategyParseOb, XComGameState GameState)
{
    local XComGameState_Effect	EffectState;
    local XComGameState_Ability	AbilityState;
    local XComGameState_Unit	UnitState;
	local ECharStatType			PossibleStatPenalty;
	local int					PenaltyAmount;

    //  Process only the "ForceAlignment" tag.
    if (InString != "IRI_FOXCOM_BleedoutPenalty")
		return false;
    
	UnitState = XComGameState_Unit(StrategyParseOb);
	if (UnitState == none)
	{
		EffectState = XComGameState_Effect(ParseObj);
		if (EffectState == none)
		{
			AbilityState = XComGameState_Ability(ParseObj);
			if (AbilityState != none)
			{
				UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(AbilityState.OwnerStateObject.ObjectID));
			}
			else
			{
				return true;
			}
		}
		else
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectState.ApplyEffectParameters.SourceStateObjectRef.ObjectID));
		}
	}
	if (UnitState == none)
		return true;

	foreach default.PossibleStatPenalties(PossibleStatPenalty)
	{
		PenaltyAmount = GetCurrentStatPenalty(UnitState, PossibleStatPenalty);
		if (PenaltyAmount > 0)
		{
			OutString $= "\n * " $ GetStatLabel $": " $ PenaltyAmount;
		}
	}

	return true;
}

static private function string GetStatLabel(const ECharStatType StatType)
{
	local string ReturnString;

	ReturnString = class'X2TacticalGameRulesetDataStructures'.default.m_aCharStatLabels[StatType];
	if (ReturnString == "")
	{
		ReturnString = string(StatType);
		ReturnString = Repl(ReturnString, "eStat_", "", true);

		`AMLOG("Generated stat label:" @ ReturnString);
	}
	return ReturnString;
}




defaultproperties
{
	DuplicateResponse = eDupe_Ignore
	EffectName = "IRI_FOXCOM_X2Effect_BleedoutPenalty_Effect"
}
