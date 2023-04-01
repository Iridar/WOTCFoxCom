class X2AbilityTemplate_FOXCOM extends X2AbilityTemplate;

// Use LocHelpText if we're not given a unit state.
simulated function string GetExpandedDescription(XComGameState_Ability AbilityState, XComGameState_Unit StrategyUnitState, bool bUseLongDescription, XComGameState CheckGameState)
{
	if (StrategyUnitState == none)
	{	
		return super.GetExpandedDescription(AbilityState, StrategyUnitState, false, CheckGameState);
	}
	return super.GetExpandedDescription(AbilityState, StrategyUnitState, bUseLongDescription, CheckGameState);
}