class X2Ability_BleedoutPenalty extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	if (!`GetMCMSettingBool("STAT_PENALTY_ON_BLEEDOUT"))
		return Templates;

	// This will display the stat changes in the interface.
	Templates.AddItem(IRI_FOXCOM_BleedoutPenalty());

	return Templates;
}

static private function X2AbilityTemplate IRI_FOXCOM_BleedoutPenalty()
{
	local X2AbilityTemplate			Template;
	local X2Effect_BleedoutPenalty	BleedoutPenalty;
	
	`CREATE_X2TEMPLATE(class'X2AbilityTemplate_FOXCOM', Template, 'IRI_FOXCOM_BleedoutPenalty');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_standard";
	Template.AbilitySourceName = 'eAbilitySource_Debuff';
	
	// Hide ability everywhere except for Armory summary.
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.bDisplayInUITacticalText = false;
	Template.bDisplayInUITooltip = false;
	Template.bDontDisplayInAbilitySummary = false;
	Template.bHideOnClassUnlock = true;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);
	
	BleedoutPenalty = new class'X2Effect_BleedoutPenalty';
	BleedoutPenalty.BuildPersistentEffect(1, true, false, false);
	BleedoutPenalty.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.LocLongDescription, Template.IconImage, true,, Template.AbilitySourceName);
	Template.AddShooterEffect(BleedoutPenalty);

	Template.bSkipFireAction = true;
	Template.bShowActivation = false;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

//	========================================
//				X2 DLC Info Methods
//	========================================

static function ModifyEarnedSoldierAbilities(out array<SoldierClassAbilityType> EarnedAbilities, XComGameState_Unit UnitState)
{
	local SoldierClassAbilityType NewAbility;

	`AMLOG("Running for unit:" @ UnitState.GetFullName());

	if (!`GetMCMSettingBool("STAT_PENALTY_ON_BLEEDOUT") || !UnitState.IsSoldier() || !UnitState.GetMyTemplate().bCanBeCriticallyWounded)
		return;

	if (`TACTICALRULES != none || class'X2EventListener_BleedoutPenalty'.static.DoesUnitHaveAnyPenalty(UnitState))
	{
		`AMLOG("Adding bleedout penalty");

		NewAbility.AbilityName = 'IRI_FOXCOM_BleedoutPenalty';
		EarnedAbilities.AddItem(NewAbility);
	}
}
