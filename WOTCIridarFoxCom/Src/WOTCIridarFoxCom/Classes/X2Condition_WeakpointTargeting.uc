class X2Condition_WeakpointTargeting extends X2Condition;

/*
return 'AA_TileIsBlocked';
return 'AA_UnitIsWrongType';
return 'AA_WeaponIncompatible';
return 'AA_AbilityUnavailable';
return 'AA_CannotAfford_ActionPoints';
return 'AA_CannotAfford_Charges';
return 'AA_CannotAfford_AmmoCost';
return 'AA_CannotAfford_ReserveActionPoints';
return 'AA_CannotAfford_Focus';
return 'AA_UnitIsFlanked';
return 'AA_UnitIsConcealed';
return 'AA_UnitIsDead';
return 'AA_UnitIsInStasis';
return 'AA_UnitIsImmune';
return 'AA_UnitIsFriendly';
return 'AA_UnitIsHostile';
return 'AA_UnitIsPanicked';
return 'AA_UnitIsNotImpaired';
return 'AA_WrongBiome';
return 'AA_NotInRange';
return 'AA_NoTargets';
return 'AA_NotVisible';
*/

event name CallMeetsConditionWithSource(XComGameState_BaseObject kTarget, XComGameState_BaseObject kSource) 
{ 
	local XComGameState_Unit	SourceUnit;
	local XComGameState_Unit	TargetUnit;
	
	SourceUnit = XComGameState_Unit(kSource);
	TargetUnit = XComGameState_Unit(kTarget);
	
	if (SourceUnit != none)
	{
		//`AMLOG("Source unit:" @ SourceUnit.GetFullName() @ class'Foxcom'.static.IsUnitWeakpointTargeting(SourceUnit) @ "TargetUnit:" @ TargetUnit.GetFullName() @ TargetUnit.m_bSubsystem);
		if (class'Foxcom'.static.IsUnitWeakpointTargeting(SourceUnit))
		{
			// During weakpoint targeting, we want only subsystem units as viable targets.
			if (TargetUnit == none || !TargetUnit.m_bSubsystem)
			{
				return 'AA_UnitIsWrongType';
			}
		}
		else
		{
			// Outside of weakpoint targeting, subsystem units are not viable targets.
			if (TargetUnit != none && TargetUnit.m_bSubsystem)
			{
				return 'AA_UnitIsWrongType';
			}
		}
	}
	
	return 'AA_Success'; 
}
