class UITacticalHUD_Override extends UITacticalHUD;

function UpdateReticle( AvailableAction kAbility, int TargetIndex )
{	
	local XComGameState_BaseObject  TargetState;
	local XComGameState_Ability AbilityState;
	local int reticuleIndex;
	local string strLabel;
	local name WeaponTech;

	local XComGameState_Unit	UnitState;
	local X2WeakpointTemplate	WeakpointTemplate;

	if( !kAbility.bFreeAim && TargetIndex < kAbility.AvailableTargets.Length )
	{
		TargetState = `XCOMHISTORY.GetGameStateForObjectID( kAbility.AvailableTargets[TargetIndex].PrimaryTarget.ObjectID );			
	}

	UnitState = XComGameState_Unit(TargetState);
	if (UnitState != none)
	{	
		WeakpointTemplate = X2WeakpointTemplate(UnitState.GetMyTemplate());
		if (WeakpointTemplate != none)
		{
			UITargetingReticle_Override(m_kTargetReticle).WeakpointTemplate = WeakpointTemplate;
		}
		else 
		{
			UITargetingReticle_Override(m_kTargetReticle).WeakpointTemplate = none;
		}
	}
	else 
	{
		UITargetingReticle_Override(m_kTargetReticle).WeakpointTemplate = none;
	}
	
	m_kTargetReticle.SetTarget(TargetState != None ? TargetState.GetVisualizer() : None);

	AbilityState = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID( kAbility.AbilityObjectRef.ObjectID ));
	if (AbilityState != none)
	{
		reticuleIndex = AbilityState.GetUIReticleIndex();
		m_kTargetReticle.SetMode(reticuleIndex);


		if (reticuleIndex == eUIReticle_Vektor)
		{
			WeaponTech = AbilityState.GetWeaponTech();
			if (AbilityState.GetMyTemplate().AbilityTargetStyle.IsA('X2AbilityTarget_Single') && kAbility.AvailableTargets.Length > 0)
			{
				if (ConcealmentMode == eUIConcealment_Super)
				{
					m_currentScopeOn = class'X2SoldierClass_DefaultChampionClasses'.default.ShadowScopePostProcessOn;
					m_currentScopeOff = class'X2SoldierClass_DefaultChampionClasses'.default.ShadowScopePostProcessOff;
					`Pres.EnablePostProcessEffect('ShadowModeOn', false);
				}
				else
				{
					m_currentScopeOn = class'X2SoldierClass_DefaultChampionClasses'.default.ScopePostProcessOn;
					m_currentScopeOff = class'X2SoldierClass_DefaultChampionClasses'.default.ScopePostProcessOff;
				}

				
				`Pres.EnablePostProcessEffect(m_currentScopeOff, false);
				`Pres.EnablePostProcessEffect(m_currentScopeOn, true, true);
			}
			if (WeaponTech == 'magnetic')
				strLabel = m_strMagVektor;
			else if(WeaponTech == 'beam')
				strLabel = m_strBeamVektor;
			else
				strLabel = m_strConvVektor;

			m_kTargetReticle.SetReaperLabels(m_strHitChance, strLabel);
		}
		else
		{
			`Pres.EnablePostProcessEffect(m_currentScopeOff, true, true);
			`Pres.EnablePostProcessEffect(m_currentScopeOn, false);
			if (ConcealmentMode == eUIConcealment_Super)
			{
				`Pres.EnablePostProcessEffect('ShadowModeOn', true, true);
			}
		}
	}
}
/*
var bool bWeakpointTargeting;

simulated function bool OnUnrealCommand(int cmd, int arg)
{	
	local bool bHandled;    // Has input been 'consumed'?

	//set the current selection in the AbilityContainer
	if ( ( arg & class'UIUtilities_Input'.const.FXS_ACTION_PRESS) != 0 && m_kAbilityHUD != none)
		m_kAbilityHUD.SetSelectionOnInputPress(cmd);

	if( m_kEnemyPreview != none )
	{
		bHandled = m_kEnemyPreview.OnUnrealCommand(cmd, arg);
	}

	// Only allow releases through past this point.
	if ( ( arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == 0 )
		return false;

	if( m_kAbilityHUD != none )
	{
		bHandled = m_kAbilityHUD.OnUnrealCommand(cmd, arg); 
	}


	// Rest of the system ignores input if not in a shot menu mode.
	// Need to return bHandled to prevent double weapon switching. -TMH
 	if ( !m_isMenuRaised )		
		return bHandled;

	if ( !bHandled )
		bHandled = m_kShotHUD.OnUnrealCommand(cmd, arg);

	if ( !bHandled )
	{
		if (cmd >= class'UIUtilities_Input'.const.FXS_KEY_F1 && cmd <= class'UIUtilities_Input'.const.FXS_KEY_F8)
		{
			bHandled = SelectTargetByHotKey(arg, cmd);
		}
		else
		{
			switch(cmd)
			{
				case (class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER):	
				case (class'UIUtilities_Input'.const.FXS_MOUSE_4):
					if (bWeakpointTargeting)
					{
						PrevWeakpoint();
					}
					else
					{
						GetTargetingMethod().PrevTarget();
					}	
					bHandled=true;
					break;

				case (class'UIUtilities_Input'.const.FXS_KEY_LEFT_SHIFT):
					if(IsActionPathingWithTarget())
					{
						bHandled = false;
					}
					else
					{
						if (bWeakpointTargeting)
						{
							PrevWeakpoint();
						}
						else
						{
							GetTargetingMethod().PrevTarget();
						}
						bHandled = true;
					}
					break;

				case (class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER):
				case (class'UIUtilities_Input'.const.FXS_KEY_TAB):
				case (class'UIUtilities_Input'.const.FXS_MOUSE_5):	
					if (bWeakpointTargeting)
					{
						NextWeakpoint();
					}
					else
					{
						GetTargetingMethod().NextTarget();
					}
					bHandled=true;
					break;

				case (class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER): // if the press the button to raise the menu again, close it.
				case (class'UIUtilities_Input'.const.FXS_KEY_ESCAPE):
					bHandled = CancelTargetingAction();
					break; 

				case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
					if (!IsActionPathingWithTarget())
					{
						bHandled = CancelTargetingAction();
					}
					else
					{
						bHandled = false;
					}
					break;

				case (class'UIUtilities_Input'.const.FXS_BUTTON_START):

					CancelTargetingAction();
					Movie.Pres.UIPauseMenu( );
					bHandled = true;
					break;
			
				default: 				
					bHandled = false;
					break;
			}
		}
	}

	if ( !bHandled )
		bHandled = super(UIScreen).OnUnrealCommand(cmd, arg);

	return bHandled;
}

private function PrevWeakpoint()
{
}

private function NextWeakpoint()
{
}

simulated function bool CancelTargetingAction()
{
	if (bWeakpointTargeting)
	{
		bWeakpointTargeting = false;
	}
	else
	{
		LowerTargetSystem(true);
		//XComPresentationLayer(Movie.Pres).m_kSightlineHUD.ClearSelectedEnemy();
		PC.SetInputState('ActiveUnit_Moving');
	}
	return true; // controller: return false ? bsteiner 
}*/