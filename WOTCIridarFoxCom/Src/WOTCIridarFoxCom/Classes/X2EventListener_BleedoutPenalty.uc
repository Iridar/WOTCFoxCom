class X2EventListener_BleedoutPenalty extends X2EventListener config(BleedoutPenalty);

struct BleedoutPenaltyStruct
{
	var ECharStatType StatType;
	var int MinValue;
	var int MaxValue;
	var int TotalMaxPenalty;
	var int MinStatValue;
};
var private config array<BleedoutPenaltyStruct>	PossibleStatPenalties;	// Default deck

var private name ValueName;
var private name VizValueName_StatType;
var private name VizValueName_StatValue;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	if (`GetMCMSettingBool("STAT_PENALTY_ON_BLEEDOUT"))
	{
		Templates.AddItem(Create_ListenerTemplate());
	}

	return Templates;
}
static private function CHEventListenerTemplate Create_ListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_FOXCOM_X2EventListener_BleedoutPenalty_Tactical');

	Template.RegisterInTactical = true;
	Template.RegisterInStrategy = false;

	if (`GetMCMSettingBool("STAT_PENALTY_ON_BLEEDOUT"))
	{
		Template.AddCHEvent('UnitBleedingOut', OnUnitBleedingOut, ELD_Immediate, 50);
	}

	return Template;
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

	// Store the number of how many times this unit has received a penalty.
	UnitState.GetUnitValue(default.ValueName, UV);
	UnitState.SetUnitFloatValue(default.ValueName, UV.fValue + 1, eCleanup_Never);

	if (GeneratePenaltyForUnit(UnitState, NewGameState))
	{		
		if (NewGameState.GetContext().PostBuildVisualizationFn.Find(BleedoutPenalty_PostBuildVisualization) == INDEX_NONE)
		{
			`AMLOG("Inserting Post Build Vis");
			NewGameState.GetContext().PostBuildVisualizationFn.AddItem(BleedoutPenalty_PostBuildVisualization);
		}
	}

	return ELR_NoInterrupt;
}

static private function BleedoutPenalty_PostBuildVisualization(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata	ActionMetadata;
	local X2Action_PlayMessageBanner	BannerAction;
	local XComGameState_Unit			UnitState;
	local UnitValue						UV;
	local XComGameStateHistory			History;
	local ECharStatType					StatType;
	local int							StatValue;
	local XComGameStateVisualizationMgr VisMgr;
	local array<X2Action>				FindActions;
	local X2Action						FindAction;
	local string						strTitle;
	local string						strUnitName;
	local string						strMessage;

	`AMLOG("Running");

	VisMgr = `XCOMVISUALIZATIONMGR;

	History = `XCOMHISTORY;
	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		`AMLOG("Unit:" @ UnitState.GetFullName());
		if (!UnitState.GetUnitValue(default.VizValueName_StatType, UV))
			continue;

		StatType = ECharStatType(int(UV.fValue));

		if (!UnitState.GetUnitValue(default.VizValueName_StatValue, UV))
			continue;

		StatValue = int(UV.fValue);

		

		VisMgr.GetNodesOfType(VisMgr.BuildVisTree, class'X2Action_PlayMessageBanner', FindActions,, UnitState.ObjectID);

		`AMLOG("Penalty:" @ StatType @ StatValue @ "found actions:" @ FindActions.Length);

		foreach FindActions(FindAction)
		{
			BannerAction = X2Action_PlayMessageBanner(FindAction);
			if (BannerAction.BannerMessages.Length == 0)
				continue;

			//`AMLOG(BannerAction.BannerMessages[0].Message @ "vs" @ class'UIEventNoticesTactical'.default.BleedingTitle);
			//`AMLOG(BannerAction.BannerMessages[0].IconPath @ "vs" @ "img:UILibrary_PerkIcons.UIPerk_bleeding");
			//`AMLOG(BannerAction.BannerMessages[0].Value @ "vs" @ class'X2StatusEffects'.default.BleedingEffectAcquiredString);
			//`AMLOG(BannerAction.BannerMessages[0].eState @ "vs" @ "eUIState_Bad");

			if (BannerAction.BannerMessages[0].Message == class'UIEventNoticesTactical'.default.BleedingOutTitle &&
				BannerAction.BannerMessages[0].IconPath == "img:///UILibrary_XPACK_Common.WorldMessage" &&
				BannerAction.BannerMessages[0].eState == eUIState_Bad)
			{
				`AMLOG("Altering message");
				BannerAction.BannerMessages[0].Value @= StatValue @ `GetLocalizedString("max") @ GetStatLabel(StatType) @ `GetLocalizedString("penalty");
				break;
			}
		}

		//ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(UnitState.ObjectID,, VisualizeGameState.HistoryIndex - 1);
		//ActionMetadata.StateObject_NewState = UnitState;
		//ActionMetadata.VisualizeActor = UnitState.GetVisualizer();
		//
		//
		//strTitle = 
		//strUnitName = UnitState.GetName(eNameType_RankFull);
		//strMessage
		//
		//
		//
		//BannerAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(),,, FindActions));
		//BannerAction.AddMessageBanner(UnitState.GetFullName() @ "received a permanent stat penalty!", "img:///UILibrary_PerkIcons.UIPerk_willtosurvive", strUnitName, string(StatValue), eUIState_Bad);
	}
}

static private function bool GeneratePenaltyForUnit(XComGameState_Unit UnitState, XComGameState NewGameState)
{
	local X2CustomCardManager	CardMgr;
	local name					DeckName;
	local ECharStatType			StatType;
	local string				DrawnCard;
	local BleedoutPenaltyStruct BleedoutPenalty;
	local int					Index;

	`AMLOG("STAT_PENALTY_ON_BLEEDOUT Running for:" @ UnitState.GetFullName());

	CardMgr = class'X2CustomCardManager'.static.GetAndPrepCustomCardManager(NewGameState);
	DeckName = name(default.ValueName $ UnitState.ObjectID);

	// #1. Fill deck for this unit if we haven't done so previously.
	if (!CardMgr.DoesDeckExist(DeckName))
	{
		`AMLOG("First time bleedout - generating deck:" @ DeckName);
		foreach default.PossibleStatPenalties(BleedoutPenalty)
		{
			// Double conversion to store as int, otherwise the enum gets stored as a string and cannot be easily converted back.
			CardMgr.AddCardToDeck(DeckName, string(int(BleedoutPenalty.StatType))); 
		}
	}

	// #2. If the deck has been completely exhausted, then all stat penalties are already at maximum, and we don't need to do anything.
	if (CardMgr.GetNumCardsInDeck(DeckName) <= 0)
	{
		`AMLOG("Deck:" @ DeckName @ "is empty, exiting.");
		return false;
	}

	// #3. Find the stat penalty to apply.

	CardMgr.SelectNextCardFromDeck(DeckName, DrawnCard,,, true);
	StatType = ECharStatType(int(DrawnCard));

	Index = default.PossibleStatPenalties.Find('StatType', StatType);
	if (Index == INDEX_NONE)
		return false;

	BleedoutPenalty = default.PossibleStatPenalties[INDEX];

	// Apply it.
	if (ApplyStatPenalty(UnitState, BleedoutPenalty))
	{
		// If this penalty is at maximum, remove it from the deck so it cannot be drawn again.
		`AMLOG("This penalty is at maximum, removing card from deck.");
		CardMgr.RemoveCardFromDeck(DeckName, DrawnCard);
	}

	return true;
}

static private function bool ApplyStatPenalty(XComGameState_Unit UnitState, const out BleedoutPenaltyStruct Penalty)
{
	local int GeneratedPenaltyValue;
	local int CurrentPenalty;
	local int TotalPenalty;
	local bool bReachedMaximumPenalty;
	local float BaseStat;
	local float NewBaseStat;
	local float CurrentStat;
	local float NewCurrentStat;

	// #1. Generate the penalty value.
	if (Penalty.MinValue == Penalty.MaxValue)
	{
		GeneratedPenaltyValue = Penalty.MinValue;
	}
	else
	{
		GeneratedPenaltyValue = -class'Help'.static.GetRandomInt(-Penalty.MinValue, -Penalty.MaxValue);
	}
	`AMLOG("Selected stat to penalyze:" @ Penalty.StatType @ "Generated penalty:" @ GeneratedPenaltyValue @ "out of:" @ Penalty.MinValue @ "/" @ Penalty.MaxValue);

	// #2. Make sure it does not exceed the maximum.
	CurrentPenalty = GetCurrentStatPenalty(UnitState, Penalty.StatType);
	TotalPenalty = CurrentPenalty + GeneratedPenaltyValue;
	if (TotalPenalty < Penalty.TotalMaxPenalty)
	{
		GeneratedPenaltyValue = Penalty.TotalMaxPenalty - CurrentPenalty;
		TotalPenalty = Penalty.TotalMaxPenalty;
		bReachedMaximumPenalty = true;

		`AMLOG("Penalty reached maximum of:" @ Penalty.TotalMaxPenalty @ ", setting it to:" @ GeneratedPenaltyValue);
	}

	BaseStat = UnitState.GetBaseStat(Penalty.StatType);
	CurrentStat = UnitState.GetCurrentStat(Penalty.StatType);

	NewBaseStat = BaseStat + GeneratedPenaltyValue;
	NewCurrentStat = Min(CurrentStat, NewBaseStat);

	`AMLOG("Base Stat:" @ int(BaseStat) @ "Current Stat:" @ int(CurrentStat) @ "New Base Stat:" @ int(NewBaseStat) @ "NewCurrentStat:" @ int(NewCurrentStat));

	// Make sure we don't reduce any stats below 1.
	if (NewBaseStat < Penalty.MinStatValue)
	{
		NewBaseStat = Penalty.MinStatValue;
		NewCurrentStat = Penalty.MinStatValue;
		GeneratedPenaltyValue = NewBaseStat - BaseStat;
		bReachedMaximumPenalty = true;

		`AMLOG("Reached minimum value, setting it to:" @ Penalty.MinStatValue @ "instead.");
	}

	UnitState.SetBaseMaxStat(Penalty.StatType, NewBaseStat);
	UnitState.SetCurrentStat(Penalty.StatType, NewCurrentStat);

	SetCurrentStatPenalty(UnitState, Penalty.StatType, TotalPenalty);

	// Record the last applied penalty for visualization purposes
	UnitState.SetUnitFloatValue(default.VizValueName_StatType, int(Penalty.StatType), eCleanup_BeginTurn);
	UnitState.SetUnitFloatValue(default.VizValueName_StatValue, GeneratedPenaltyValue, eCleanup_BeginTurn);

	return bReachedMaximumPenalty;
}

static private function int GetCurrentStatPenalty(const XComGameState_Unit UnitState, const ECharStatType StatType)
{
	local UnitValue UV;
	local name LocValueName;

	LocValueName = name(default.ValueName $ int(StatType));

	UnitState.GetUnitValue(LocValueName, UV);

	`AMLOG("Retrieved penalty for unit:" @ LocValueName @ StatType @ int(UV.fValue));

	return UV.fValue;
}
static private function SetCurrentStatPenalty(XComGameState_Unit NewUnitState, const ECharStatType StatType, int PenaltyValue)
{
	local name LocValueName;

	LocValueName = name(default.ValueName $ int(StatType));

	`AMLOG("Recording penalty for unit:" @ LocValueName @ StatType @ PenaltyValue);

	NewUnitState.SetUnitFloatValue(LocValueName, PenaltyValue, eCleanup_Never);
}


static final function bool DoesUnitHaveAnyPenalty(const XComGameState_Unit UnitState)
{
	local BleedoutPenaltyStruct PossibleStatPenalty;

	foreach default.PossibleStatPenalties(PossibleStatPenalty)
	{
		if (GetCurrentStatPenalty(UnitState, PossibleStatPenalty.StatType) != 0)
		{
			return true;
		}
	}

	return false;
}
static final function bool AbilityTagExpandHandler_CH(string InString, out string OutString, Object ParseObj, Object StrategyParseOb, XComGameState GameState)
{
    local XComGameState_Effect	EffectState;
    local XComGameState_Ability	AbilityState;
    local XComGameState_Unit	UnitState;
	local BleedoutPenaltyStruct PossibleStatPenalty;
	local int					PenaltyAmount;

    if (InString != "IRI_FOXCOM_BleedoutPenalty")
		return false;

	`AMLOG("Running" @ ParseObj.Class.Name @ StrategyParseOb.Class.Name);
    
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
				`AMLOG("No face, no name, no number");
				return true;
			}
		}
		else
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectState.ApplyEffectParameters.SourceStateObjectRef.ObjectID));
		}
	}
	if (UnitState == none)
	{
		`AMLOG("Failed to acquire unit state.");
		return true;
	}

	`AMLOG("Unit:" @ UnitState.GetFullName());
	foreach default.PossibleStatPenalties(PossibleStatPenalty)
	{
		PenaltyAmount = GetCurrentStatPenalty(UnitState, PossibleStatPenalty.StatType);
		if (PenaltyAmount < 0)
		{
			OutString $= "\n * " $ GetStatLabel(PossibleStatPenalty.StatType) $": " $ PenaltyAmount;
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
	ValueName = "IRI_FOXCOM_BleedoutPenalty_Value"
	VizValueName_StatType = "IRI_FOXCOM_BleedoutPenalty_VizValue_Stat"
	VizValueName_StatValue = "IRI_FOXCOM_BleedoutPenalty_VizValue_Value"
}

