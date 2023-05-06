class X2TargetingMethod_Weakpoint extends X2TargetingMethod_OverTheShoulder;

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

	// FOXCOM
	AddWeakpointTargetingCamera(NewTargetActor, ShouldUseMidpointCamera);

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