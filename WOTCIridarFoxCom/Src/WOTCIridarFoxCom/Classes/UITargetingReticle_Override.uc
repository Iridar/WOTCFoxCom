class UITargetingReticle_Override extends UITargetingReticle;

var X2WeakpointTemplate	WeakpointTemplate;

simulated public function UpdateLocation()
{
	local vector2D				vScreenLocation; 
	local vector				AimingLocation;
	local vector				WeakpointLocation;
	local XComGameState_Unit	TargetUnit;
	local XGUnit				TargetVisualizer;
		
	if( m_kTarget != none )
	{
		AimingLocation = m_kTarget.GetTargetingFocusLocation();

		if (WeakpointTemplate != none)
		{
			TargetUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(m_kTarget.GetVisualizedStateReference().ObjectID));
			if (TargetUnit != none)
			{				
				TargetVisualizer = XGUnit(TargetUnit.GetVisualizer());
				if (TargetVisualizer != none)
				{
					`AMLOG("Looking for socket:" @ WeakpointTemplate.SocketName);
					if (GetWeakpointLocation(TargetVisualizer, WeakpointTemplate.SocketName, WeakpointLocation))
					{
						AimingLocation = WeakpointLocation;
						`AMLOG("have weakpoint location" @ AimingLocation.X @ AimingLocation.Y @ AimingLocation.Z);
					}
				}
			}
		}
		

		//Get the current screen coords
		if(class'UIUtilities'.static.IsOnscreen( AimingLocation, vScreenLocation))
		{
			Show();
			SetLoc( vScreenLocation.X, vScreenLocation.Y );
		}
		else
			Hide();
	}
	
	if (m_bUpdateShotWithLoc)
		UpdateShotData();
}

final function bool GetWeakpointLocation(XGUnit TargetedUnit, const name SocketName, out vector WeakpointLocation)
{	
	local XComUnitPawn UnitPawn;

	UnitPawn = TargetedUnit.GetPawn();
	if (UnitPawn == none)
	{
		`AMLOG("No target pawn.");
		return false;
	}

	if (UnitPawn.Mesh.GetSocketWorldLocationAndRotation(SocketName, WeakpointLocation))
	{
		`AMLOG("Got the following coordinates for CIN_Root:" @ WeakpointLocation.X  @ WeakpointLocation.Y @ WeakpointLocation.Z);
		return true;
	}
	return false;
}