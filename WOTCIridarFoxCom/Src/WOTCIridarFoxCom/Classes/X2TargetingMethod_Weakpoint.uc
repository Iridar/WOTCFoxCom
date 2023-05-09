class X2TargetingMethod_Weakpoint extends X2TargetingMethod_OverTheShoulder;

var private XComPresentationLayer Pres;
var private UITacticalHUD TacticalHud;

function Init(AvailableAction InAction, int NewTargetIndex)
{
	super.Init(InAction, NewTargetIndex);

	Pres = `PRES;
	TacticalHud = Pres.GetTacticalHUD();

		`AMLOG("Nuking ability HUD:" @ TacticalHud != none @ TacticalHud.m_kAbilityHUD.m_arrAbilities.Length @ TacticalHud.m_kAbilityHUD.m_arrUIAbilities.Length);
	
	//TacticalHud.m_kAbilityHUD.m_arrAbilities.Length = 0;
	//TacticalHud.m_kAbilityHUD.m_arrUIAbilities.Length = 0;
}

// OnInit: display flags for all weakpoints for this unit

// Hitting TAB cycles through weakpoints

// confirm target: give the main unit state object ID, but store which weakpoint was selected


function DirectSetTarget(int TargetIndex)
{
	local Actor NewTargetActor;
	local bool ShouldUseMidpointCamera;
	local array<TTile> Tiles;
	local XComDestructibleActor Destructible;
	local Vector TilePosition;
	local TTile CurrentTile;
	local XComWorldData World;
	local array<Actor> CurrentlyMarkedTargets;

	World = `XWORLD;
	
	NotifyTargetTargeted(false);

	// make sure our target is in bounds (wrap around out of bounds values)
	LastTarget = TargetIndex;
	LastTarget = LastTarget % Action.AvailableTargets.Length;
	if (LastTarget < 0) LastTarget = Action.AvailableTargets.Length + LastTarget;

	ShouldUseMidpointCamera = ShouldUseMidpointCameraForTarget(Action.AvailableTargets[LastTarget].PrimaryTarget.ObjectID) || !`Battle.ProfileSettingsGlamCam();

	NewTargetActor = GetTargetedActor();

	// FOXCOM
	AddWeakpointTargetingCamera(NewTargetActor, ShouldUseMidpointCamera);

	// put the targeting reticle on the new target
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

private function AddWeakpointTargetingCamera(Actor NewTargetActor, bool ShouldUseMidpointCamera)
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


final function bool GetWeakpointLocation(out vector Location)
{
	local XGUnit TargetedUnit;
	local XComUnitPawn UnitPawn;

	TargetedUnit = XGUnit(GetTargetedActor());
	if (TargetedUnit == none)
	{
		`AMLOG("Target not a unit.");
		return false;
	}

	UnitPawn = TargetedUnit.GetPawn();
	if (UnitPawn == none)
	{
		`AMLOG("No target pawn.");
		return false;
	}

	if (UnitPawn.Mesh.GetSocketWorldLocationAndRotation('CIN_Root', Location))
	{
		`AMLOG("Got the following coordinates for CIN_Root:" @ Location.X  @ Location.Y @ Location.Z);
		return true;
	}
	return false;
}
/*
function Canceled()
{
	super.Canceled();
	TacticalHud.m_kAbilityHUD.Show();
}

function Committed()
{
	super.Committed();
	TacticalHud.m_kAbilityHUD.Show();
}*/