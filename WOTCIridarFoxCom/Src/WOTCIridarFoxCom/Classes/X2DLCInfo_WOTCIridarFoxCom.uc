class X2DLCInfo_WOTCIridarFoxCom extends X2DownloadableContentInfo;

static function OnPreCreateTemplates()
{
	//class'X2EventListener_WoundTimers'.static.OnPreCreateTemplates();
}

static event OnPostTemplatesCreated()
{
	class'X2WeaponStatsTemplate'.static.PatchWeaponTemplates();
}

static function ModifyEarnedSoldierAbilities(out array<SoldierClassAbilityType> EarnedAbilities, XComGameState_Unit UnitState)
{
	class'X2Ability_BleedoutPenalty'.static.ModifyEarnedSoldierAbilities(EarnedAbilities, UnitState);
}

static function bool AbilityTagExpandHandler_CH(string InString, out string OutString, Object ParseObj, Object StrategyParseOb, XComGameState GameState)
{
	return class'X2EventListener_BleedoutPenalty'.static.AbilityTagExpandHandler_CH(InString, OutString, ParseObj, StrategyParseOb, GameState);
}

static event InstallNewCampaign(XComGameState StartState)
{
	StartState.CreateNewStateObject(class'X2CustomCardManager');
}
static event OnLoadedSavedGame()
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(default.DLCIdentifier $ " Creating Custom Card Manager");
	NewGameState.CreateNewStateObject(class'X2CustomCardManager');
	`XCOMHISTORY.AddGameStateToHistory(NewGameState);
}