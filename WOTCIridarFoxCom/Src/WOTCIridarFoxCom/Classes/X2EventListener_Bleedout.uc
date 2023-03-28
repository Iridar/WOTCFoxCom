class X2EventListener_Bleedout extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	if (`GetMCMSettingBool("PATCH_BLEEDOUT"))
	{
		Templates.AddItem(Create_ListenerTemplate());
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

static private function CHEventListenerTemplate Create_ListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_FOXCOM_X2EventListener_Bleedout_Tactical');

	Template.RegisterInTactical = true;
	Template.RegisterInStrategy = false;

	if (`GetMCMSettingBool("PATCH_BLEEDOUT"))
	{
		Template.AddCHEvent('OverrideBleedoutChance', OnOverrideBleedoutChance, ELD_Immediate, 10);
		Template.AddCHEvent('UnitBleedingOut', OnUnitBleedingOut, ELD_Immediate, 10);
	}

	return Template;
}

static private function EventListenerReturn OnOverrideBleedoutChance(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit UnitState;
	local XComLWTuple Tuple;

	if (!`GetMCMSettingBool("PATCH_BLEEDOUT"))
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	`AMLOG("PATCH_BLEEDOUT" @ UnitState.GetFullName() @ "Max HP:" @ UnitState.GetMaxStat(eStat_HP) @ "Overkill Damage:" @ Tuple.Data[2].i);

	// If Overkill Damage is greater or equal to unit's Max HP then they don't bleedout.
	if (Tuple.Data[2].i >= UnitState.GetMaxStat(eStat_HP))
	{
		`AMLOG("PATCH_BLEEDOUT Overkill damage is greater or equal to unit's Max HP, force death.");
		Tuple.Data[0].i = 0;
	}
	else
	{
		`AMLOG("PATCH_BLEEDOUT Overkill damage is lower than unit's Max HP, force bleedout.");
		Tuple.Data[0].i = 999;
	}

	return ELR_NoInterrupt;
}

static private function EventListenerReturn OnUnitBleedingOut(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit	UnitState;
	local XComGameState_Effect	EffectState;
	local UnitValue				UV;

	if (!`GetMCMSettingBool("PATCH_BLEEDOUT"))
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	if (UnitState == none)
		return ELR_NoInterrupt;

	if (!UnitState.GetUnitValue('OverKillDamage', UV))
		return ELR_NoInterrupt;

	foreach NewGameState.IterateByClassType(class'XComGameState_Effect', EffectState)
	{
		if (EffectState.GetX2Effect().EffectName != class'X2StatusEffects'.default.BleedingOutName)
			continue;

		if (EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID == UnitState.ObjectID)
		{
			EffectState.iTurnsRemaining = UnitState.GetMaxStat(eStat_HP) - UV.fValue;

			`AMLOG("PATCH_BLEEDOUT" @ UnitState.GetFullName() @ "Max HP:" @ UnitState.GetMaxStat(eStat_HP) @ "Overkill Damage:" @ int(UV.fValue) @ "setting bleedout duration to:" @ EffectState.iTurnsRemaining @ "turn(s).");
			break;
		}
	}

	return ELR_NoInterrupt;
}