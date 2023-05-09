class UITacticalHUD_Enemies_Override extends UITacticalHUD_Enemies;

simulated function UpdateVisibleEnemies(int HistoryIndex)
{
	local XGUnit kActiveUnit;
	local XComGameState_Unit ActiveUnit;
	local XComGameStateHistory History;
	local int i;
	local XComGameState_Ability CurrentAbilityState;
	local X2AbilityTemplate AbilityTemplate;

	local XComGameState_Unit TargetUnit;

	m_arrSSEnemies.length = 0;
	m_arrCurrentlyAffectable.length = 0;

	kActiveUnit = XComTacticalController(PC).GetActiveUnit();
	if (kActiveUnit != none)
	{
		// DATA: -----------------------------------------------------------
		History = `XCOMHISTORY;
		ActiveUnit = XComGameState_Unit(History.GetGameStateForObjectID(kActiveUnit.ObjectID, , HistoryIndex));

		CurrentAbilityState = XComPresentationLayer(Movie.Pres).GetTacticalHUD().m_kAbilityHUD.GetCurrentSelectedAbility();
		AbilityTemplate = CurrentAbilityState != none ? CurrentAbilityState.GetMyTemplate() : none;

		if (AbilityTemplate != none && AbilityTemplate.AbilityTargetStyle.SuppressShotHudTargetIcons())
		{
			m_arrTargets.Length = 0;
		}
		else
		{
			ActiveUnit.GetUISummary_TargetableUnits(m_arrTargets, m_arrSSEnemies, m_arrCurrentlyAffectable, CurrentAbilityState, HistoryIndex);
		}

		// if the currently selected ability requires the list of ability targets be restricted to only the ones that can be affected by the available action, 
		// use that list of targets instead
		if (AbilityTemplate != none)
		{
			if (AbilityTemplate.bLimitTargetIcons)
			{
				m_arrTargets = m_arrCurrentlyAffectable;
			}
			else
			{
				//  make sure that all possible targets are in the targets list - as they may not be visible enemies
				for (i = 0; i < m_arrCurrentlyAffectable.Length; ++i)
				{
					if (m_arrTargets.Find('ObjectID', m_arrCurrentlyAffectable[i].ObjectID) == INDEX_NONE)
						m_arrTargets.AddItem(m_arrCurrentlyAffectable[i]);
				}
			}
		}

		// FOXCOM: Don't display subsystem units unless in weakpoint targeting mode.
		if (!class'Foxcom'.static.IsUnitWeakpointTargeting(ActiveUnit))
		{
			for (i = m_arrTargets.Length - 1; i >= 0; i--)
			{
				TargetUnit = XComGameState_Unit(History.GetGameStateForObjectID(m_arrTargets[i].ObjectID));
				if (TargetUnit == none)
					continue;

				if (TargetUnit.m_bSubsystem)
				{
					m_arrTargets.Remove(i, 1);
				}
			}
		}
		
		
		iNumVisibleEnemies = m_arrTargets.Length;

		m_arrTargets.Sort(SortEnemies);
		UpdateVisuals(HistoryIndex);
	}
}

