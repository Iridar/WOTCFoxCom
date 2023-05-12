class X2Action_Death_Override extends X2Action_Death;

/*
simulated function Name ComputeAnimationToPlay()
{
	local float fDot;
	local vector UnitRight;
	local float fDotRight;
	local vector WorldUp;
	local Name AnimName;
	local string AnimString;
	local XComGameState_Ability AbilityState;
	local bool ShouldUseMeleeDeath;
	local X2Effect_Persistent PersistentEffect; 

	// Start Issue #488
	if (CustomDeathAnimationName != 'None' && UnitPawn.GetAnimTreeController().CanPlayAnimation(CustomDeathAnimationName))
	{
		return CustomDeathAnimationName;
	}
	// End Issue #488

	WorldUp.X = 0.0f;
	WorldUp.Y = 0.0f;
	WorldUp.Z = 1.0f;

	if( AbilityContext != None && class'XComTacticalGRI'.static.GetReactionFireSequencer().IsReactionFire(AbilityContext) )
	{
		UnitPawn.bReactionFireDeath = true;
		//Most units will not specify a ReactionFireDeathAnim ( the bone springs system will turn us into a rag doll in due time )
		return NewUnitState.GetMyTemplate().ReactionFireDeathAnim;
	}

	OverrideOldUnitState = XComGameState_Unit(Metadata.StateObject_OldState);
	bDoOverrideAnim = class'X2StatusEffects'.static.GetHighestEffectOnUnit(OverrideOldUnitState, PersistentEffect, true);

	OverrideAnimEffectString = "";
	if(bDoOverrideAnim)
	{
		// Allow new animations to play
		UnitPawn.GetAnimTreeController().SetAllowNewAnimations(true);
		OverrideAnimEffectString = string(PersistentEffect.EffectName);
	}
	
	if (AbilityTemplate != none && AbilityTemplate.AbilityTargetStyle.IsA('X2AbilityTarget_Cursor'))
	{
		//Damage from position-based abilities should have their damage direction based on the target location
		`assert( AbilityContext.InputContext.TargetLocations.Length > 0 );
		vHitDir = Unit.GetPawn().Location - AbilityContext.InputContext.TargetLocations[0];
	}
	else if (DamageDealer != none)
	{
		vHitDir = Unit.GetPawn().Location - DamageDealer.Location;
	}
	else
	{
		vHitDir = -Vector(Unit.GetPawn().Rotation);
	}

	vHitDir = Normal(vHitDir);

	fDot = vHitDir dot vector(Unit.GetPawn().Rotation);
	UnitRight = Vector(Unit.GetPawn().Rotation) cross WorldUp;
	fDotRight = vHitDir dot UnitRight;

	// Fallback default death
	AnimString = "HL_MeleeDeath";

	// FOXCOM: Use hurt animation for subsystems.
	if (NewUnitState.m_bSubsystem)
	{
		AnimString = "HL_HurtFront";
	}
	else if( Unit.IsTurret() )
	{
		if( Unit.GetTeam() == eTeam_Alien )
		{
			AnimString = "NO_"$OverrideAnimEffectString$"Death_Advent";
		}
		else
		{
			AnimString = "NO_"$OverrideAnimEffectString$"Death_Xcom";
		}
	}
	else
	{
		if(fDot < 0.5f) //There are no "shot from the back" anims, so skip the anim selection process for those
		{
			if(abs(fDot) >= abs(fDotRight))
			{
				AnimString = "HL_"$OverrideAnimEffectString$"Death";

				//Have a fallback ready for the "typical" death situation - where the unit is facing us. The "side" deaths below can fall back to the pure physics death
				if(!Unit.GetPawn().GetAnimTreeController().CanPlayAnimation(name(AnimString)))
				{
					AnimName = 'HL_Death';
				}
			}
			else
			{
				if(fDotRight > 0)
				{
					AnimString = "HL_"$OverrideAnimEffectString$"DeathRight";
				}
				else
				{
					AnimString = "HL_"$OverrideAnimEffectString$"DeathLeft";
				}
			}
		}
	}

	AbilityState = AbilityContext != none ? XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(AbilityContext.InputContext.AbilityRef.ObjectID)) : none;
	ShouldUseMeleeDeath = (AbilityState != none) && AbilityState.GetMyTemplate().ShouldPlayMeleeDeath();
	if( (WeaponData != None && WeaponData.bOverrideMeleeDeath == true) || UnitPawn.GetAnimTreeController().CanPlayAnimation('HL_MeleeDeath') == false )
	{
		ShouldUseMeleeDeath = false;
	}

	if( ShouldUseMeleeDeath || bForceMeleeDeath )
	{
		AnimString = "HL_MeleeDeath";
	}

	AnimName = name(AnimString); //If the pawn cannot play this animation, that is handled in UnitPawn.PlayDying

	return AnimName;
}
*/

/*
simulated state Executing
{	

Begin:

	// FOXCOM: Different track for subsystems.
	if (NewUnitState.m_bSubsystem)
	{
	}
	else
	{
		StopAllPreviousRunningActions(Unit);

		Unit.SetForceVisibility(eForceVisible);

		//Ensure Time Dilation is full speed
		VisualizationMgr.SetInterruptionSloMoFactor(Metadata.VisualizeActor, 1.0f);

		Unit.PreDeathRotation = UnitPawn.Rotation;

		//Death might already have been played by X2Actions_Knockback.
		if (!UnitPawn.bPlayedDeath)
		{
			Unit.OnDeath(m_kDamageType, XGUnit(DamageDealer));

			AnimationName = ComputeAnimationToPlay();

			UnitPawn.SetFinalRagdoll(true);
			UnitPawn.TearOffMomentum = vHitDir; //Use archaic Unreal values for great justice	
			UnitPawn.PlayDying(none, UnitPawn.GetHeadshotLocation(), AnimationName, Destination);
		}

		//Since we have a unit dying, update the music if necessary
		`XTACTICALSOUNDMGR.EvaluateTacticalMusicState();

		Unit.GotoState('Dead');

		if( bDoOverrideAnim )
		{
			// Turn off new animation playing
			UnitPawn.GetAnimTreeController().SetAllowNewAnimations(false);
		}

		while( DoWaitUntilNotified() && !IsTimedOut() )
		{
			Sleep(0.0f);
		}
	}

	CompleteAction();
}*/