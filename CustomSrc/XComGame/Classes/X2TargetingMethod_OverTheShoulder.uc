//---------------------------------------------------------------------------------------
//  FILE:    X2TargetingMethod_OverTheShoulder.uc
//  AUTHOR:  David Burchanowski  --  2/10/2014
//  PURPOSE: Targeting method for looking at a single target over a unit's shoulder
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2TargetingMethod_OverTheShoulder extends X2TargetingMethod;

var /*private*/ int LastTarget;

function Init(AvailableAction InAction, int NewTargetIndex)
{
	super.Init(InAction, NewTargetIndex);

	// Make sure we have targets of some kind.
	`assert(Action.AvailableTargets.Length > 0);

	// select the target before setting up the midpoint cam so we know where we are midpointing to
	DirectSetTarget(NewTargetIndex);

	UpdatePostProcessEffects(true);
}

private function AddTargetingCamera(Actor NewTargetActor, bool ShouldUseMidpointCamera)
{
	local X2Camera_Midpoint MidpointCamera;
	local X2Camera_OTSTargeting OTSCamera;
	local X2Camera_MidpointTimed LookAtMidpointCamera;
	local bool bCurrentTargetingCameraIsMidpoint;
	local bool bShouldAddNewTargetingCameraToStack;

	if( FiringUnit.TargetingCamera != None )
	{
		bCurrentTargetingCameraIsMidpoint = (X2Camera_Midpoint(FiringUnit.TargetingCamera) != None);

		if( bCurrentTargetingCameraIsMidpoint != ShouldUseMidpointCamera )
		{
			RemoveTargetingCamera();
		}
	}

	if( ShouldUseMidpointCamera )
	{
		if( FiringUnit.TargetingCamera == None )
		{
			FiringUnit.TargetingCamera = new class'X2Camera_Midpoint';
			bShouldAddNewTargetingCameraToStack = true;
		}

		MidpointCamera = X2Camera_Midpoint(FiringUnit.TargetingCamera);
		MidpointCamera.TargetActor = NewTargetActor;
		MidpointCamera.ClearFocusActors();
		MidpointCamera.AddFocusActor(FiringUnit);
		MidpointCamera.AddFocusActor(NewTargetActor);

		// the following only needed if bQuickTargetSelectEnabled were desired
		//if( TacticalHud.m_kAbilityHUD.LastTargetActor != None )
		//{
		//	MidpointCamera.AddFocusActor(TacticalHud.m_kAbilityHUD.LastTargetActor);
		//}

		if( bShouldAddNewTargetingCameraToStack )
		{
			`CAMERASTACK.AddCamera(FiringUnit.TargetingCamera);
		}

		MidpointCamera.RecomputeLookatPointAndZoom(false);
	}
	else
	{
		if( FiringUnit.TargetingCamera == None )
		{
			FiringUnit.TargetingCamera = new class'X2Camera_OTSTargeting';
			bShouldAddNewTargetingCameraToStack = true;
		}

		OTSCamera = X2Camera_OTSTargeting(FiringUnit.TargetingCamera);
		OTSCamera.FiringUnit = FiringUnit;
		OTSCamera.CandidateMatineeCommentPrefix = UnitState.GetMyTemplate().strTargetingMatineePrefix;
		OTSCamera.ShouldBlend = class'X2Camera_LookAt'.default.UseSwoopyCam;
		OTSCamera.ShouldHideUI = false;

		if( bShouldAddNewTargetingCameraToStack )
		{
			`CAMERASTACK.AddCamera(FiringUnit.TargetingCamera);
		}

		// add swoopy midpoint
		if( !OTSCamera.ShouldBlend )
		{
			LookAtMidpointCamera = new class'X2Camera_MidpointTimed';
			LookAtMidpointCamera.AddFocusActor(FiringUnit);
			LookAtMidpointCamera.LookAtDuration = 0.0f;
			LookAtMidpointCamera.AddFocusPoint(OTSCamera.GetTargetLocation());
			OTSCamera.PushCamera(LookAtMidpointCamera);
		}

		// have the camera look at the new target
		OTSCamera.SetTarget(NewTargetActor);
	}
}


/*private*/ function RemoveTargetingCamera()
{
	if( FiringUnit.TargetingCamera != none )
	{
		`CAMERASTACK.RemoveCamera(FiringUnit.TargetingCamera);
		FiringUnit.TargetingCamera = none;
	}
}

function Canceled()
{
	super.Canceled();

	ClearTargetedActors();
	RemoveTargetingCamera();

	FiringUnit.IdleStateMachine.bTargeting = false;
	NotifyTargetTargeted(false);

	UpdatePostProcessEffects(false);
}

function Committed()
{
	AOEMeshActor.Destroy();
	ClearTargetedActors();

	if(!Ability.GetMyTemplate().bUsesFiringCamera)
	{
		RemoveTargetingCamera();
	}

	UpdatePostProcessEffects(false);
}

function Update(float DeltaTime);

function NextTarget()
{
	DirectSetTarget(LastTarget + 1);
}

function PrevTarget()
{
	DirectSetTarget(LastTarget - 1);
}

function int GetTargetIndex()
{
	return LastTarget;
}

function DirectSetTarget(int TargetIndex)
{
	local XComPresentationLayer Pres;
	local UITacticalHUD TacticalHud;
	local Actor NewTargetActor;
	local bool ShouldUseMidpointCamera;
	local array<TTile> Tiles;
	local XComDestructibleActor Destructible;
	local Vector TilePosition;
	local TTile CurrentTile;
	local XComWorldData World;
	local array<Actor> CurrentlyMarkedTargets;

	Pres = `PRES;
	World = `XWORLD;
	
	NotifyTargetTargeted(false);

	// make sure our target is in bounds (wrap around out of bounds values)
	LastTarget = TargetIndex;
	LastTarget = LastTarget % Action.AvailableTargets.Length;
	if (LastTarget < 0) LastTarget = Action.AvailableTargets.Length + LastTarget;

	ShouldUseMidpointCamera = ShouldUseMidpointCameraForTarget(Action.AvailableTargets[LastTarget].PrimaryTarget.ObjectID) || !`Battle.ProfileSettingsGlamCam();

	NewTargetActor = GetTargetedActor();

	AddTargetingCamera(NewTargetActor, ShouldUseMidpointCamera);

	// put the targeting reticle on the new target
	TacticalHud = Pres.GetTacticalHUD();
	TacticalHud.TargetEnemy(GetTargetedObjectID());


	FiringUnit.IdleStateMachine.bTargeting = true;
	FiringUnit.IdleStateMachine.CheckForStanceUpdate();

	class'WorldInfo'.static.GetWorldInfo().PlayAKEvent(AkEvent'SoundTacticalUI.TacticalUI_TargetSelect');

	NotifyTargetTargeted(true);

	Destructible = XComDestructibleActor(NewTargetActor);
	if( Destructible != None )
	{
		Destructible.GetRadialDamageTiles(Tiles);
	}
	else
	{
		GetEffectAOETiles(Tiles);
	}

	//	reset these values when changing targets
	bFriendlyFireAgainstObjects = false;
	bFriendlyFireAgainstUnits = false;

	if( Tiles.Length > 1 )
	{
		if( ShouldUseMidpointCamera )
		{
			foreach Tiles(CurrentTile)
			{
				TilePosition = World.GetPositionFromTileCoordinates(CurrentTile);
				if( World.Volume.EncompassesPoint(TilePosition) )
				{
					X2Camera_Midpoint(FiringUnit.TargetingCamera).AddFocusPoint(TilePosition, true);
				}
			}
			
		}
		GetTargetedActorsInTiles(Tiles, CurrentlyMarkedTargets, false);
		CheckForFriendlyUnit(CurrentlyMarkedTargets);
		MarkTargetedActors(CurrentlyMarkedTargets, (!AbilityIsOffensive) ? FiringUnit.GetTeam() : eTeam_None);
		DrawAOETiles(Tiles);
		AOEMeshActor.SetHidden(false);
	}
	else
	{
		ClearTargetedActors();
		AOEMeshActor.SetHidden(true);
	}
}

/*private*/ function GetEffectAOETiles(out array<TTile> TilesToBeDamaged)
{
	local XComGameState_Unit TargetUnit;
	local XComGameStateHistory History;
	local XComGameState_Effect EffectState;
	local StateObjectReference EffectRef;
	local XComGameState_Unit SourceUnit;

	History = `XCOMHISTORY;

	TargetUnit = XComGameState_Unit(History.GetGameStateForObjectID(GetTargetedObjectID()));
	if( TargetUnit != None )
	{
		foreach TargetUnit.AffectedByEffects(EffectRef)
		{
			EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
			if( EffectState != None )
			{
				SourceUnit = XComGameState_Unit(History.GetGameStateForObjectID(EffectState.ApplyEffectParameters.SourceStateObjectRef.ObjectID));
				if( SourceUnit != None )
				{
					EffectState.GetX2Effect().GetAOETiles(SourceUnit, TargetUnit, TilesToBeDamaged);
				}
			}
		}
	}
}

/*private*/ function NotifyTargetTargeted(bool Targeted)
{
	local XComGameStateHistory History;
	local XGUnit TargetUnit;

	History = `XCOMHISTORY;

	if( LastTarget != -1 )
	{
		TargetUnit = XGUnit(History.GetVisualizer(GetTargetedObjectID()));
	}

	if( TargetUnit != None )
	{
		// only have the target peek if he isn't peeking into the shooters tile. Otherwise they get really kissy.
		// setting the "bTargeting" flag will make the unit do the hold peek.
		TargetUnit.IdleStateMachine.bTargeting = Targeted && !FiringUnit.HasSameStepoutTile(TargetUnit);
		TargetUnit.IdleStateMachine.CheckForStanceUpdate();
	}
}

function bool GetCurrentTargetFocus(out Vector Focus)
{
	if( FiringUnit.TargetingCamera != None )
	{
		Focus = FiringUnit.TargetingCamera.GetTargetLocation();
	}
	else
	{
		Focus = GetTargetedActor().Location;
	}
	return true;
}

static function bool ShouldWaitForFramingCamera()
{
	// we only need to disable the framing camera if we are pushing an OTS targeting camera, which we don't do when user
	// has disabled glam cams
	return !`BATTLE.ProfileSettingsGlamCam();
}

defaultproperties
{
	LastTarget = -1;
}