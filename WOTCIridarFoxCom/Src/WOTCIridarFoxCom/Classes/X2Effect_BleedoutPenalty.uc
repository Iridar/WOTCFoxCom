class X2Effect_BleedoutPenalty extends X2Effect_Persistent;

function bool IsEffectCurrentlyRelevant(XComGameState_Effect EffectGameState, XComGameState_Unit TargetUnit) 
{
	return class'X2EventListener_BleedoutPenalty'.static.DoesUnitHaveAnyPenalty(TargetUnit); 
}

defaultproperties
{
	DuplicateResponse = eDupe_Ignore
	EffectName = "IRI_FOXCOM_X2Effect_BleedoutPenalty_Effect"
}
