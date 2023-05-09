class X2AbilityToHitCalc_StandardAim_Override extends X2AbilityToHitCalc_StandardAim;

var config(Fox) float fMaxGoodAngleBonusMultiplier;

protected function int GetHitChance(XComGameState_Ability kAbility, AvailableTarget kTarget, optional out ShotBreakdown m_ShotBreakdown, optional bool bDebugLog = false)
{
	local XComGameState_Unit				SourceUnit;
	local XComGameState_Unit				TargetUnit;
	local XComGameState_Item				SourceWeapon;
	local XComGameStateHistory				History;
	local X2AbilityTemplate					AbilityTemplate;
	local ShotBreakdown						EmptyShotBreakdown;
	local GameRulesCache_VisibilityInfo		VisInfo;
	local bool								bFlanking;
	local bool								bSquadsight;
	local array<XComGameState_Effect>		StatMods;
	local array<float>						StatModValues;
	local int								Tiles;
	local int								iWeaponMod;
	local int								iRangeModifier;
	local array<X2WeaponUpgradeTemplate>	WeaponUpgrades;
	local array<ShotModifierInfo>			EffectModifiers;
	local StateObjectReference				EffectRef;
	local XComGameState_Effect				EffectState;
	local X2Effect_Persistent				PersistentEffect;
	local array<X2Effect_Persistent>		UniqueToHitEffects;
	local float								CoverValue;
	local float								CoverAngleBonus;
	local float								HeightAdvantageBonus;
	local float								FinalAdjust;
	local int i;

	//`AMLOG("Running");

	// --------------------------- INIT ------------------------

	if (kAbility == none)
		return 0;

	History = `XCOMHISTORY;
	SourceUnit = XComGameState_Unit(History.GetGameStateForObjectID(kAbility.OwnerStateObject.ObjectID));
	if (SourceUnit == none)
		return 0;

	AbilityTemplate = kAbility.GetMyTemplate();
	if (AbilityTemplate == none)
		return 0;

	TargetUnit = XComGameState_Unit(History.GetGameStateForObjectID(kTarget.PrimaryTarget.ObjectID));
	SourceWeapon = kAbility.GetSourceWeapon();		
	
	//  reset shot breakdown
	m_ShotBreakdown = EmptyShotBreakdown;	

	// --------------------------- GUARANTEED HITS ------------------------

	if (bGuaranteedHit)
	{
		AddModifier(100, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
		return 100;
	}
	
	if (bIndirectFire || TargetUnit == none)
	{
		m_ShotBreakdown.HideShotBreakdown = true;
		AddModifier(100, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
		return 100;
	}

	// --------------------------- TO HIT MODIFIERS ------------------------

	// Line of sight is required for this calc.
	if (!`TACTICALRULES.VisibilityMgr.GetVisibilityInfo(SourceUnit.ObjectID, TargetUnit.ObjectID, VisInfo))
		return 0;

	if (SourceUnit.CanFlank() && TargetUnit.GetMyTemplate().bCanTakeCover && VisInfo.TargetCover == CT_None)
		bFlanking = true;

	if (VisInfo.bClearLOS && !VisInfo.bVisibleGameplay)
		bSquadsight = true;

	// Built-in ability modifier.
	AddModifier(BuiltInHitMod, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);

	//  Source unit's Aim stat.
	AddModifier(SourceUnit.GetBaseStat(eStat_Offense), class'XLocalizedData'.default.OffenseStat, m_ShotBreakdown, eHit_Success, bDebugLog);
	SourceUnit.GetStatModifiersFixed(eStat_Offense, StatMods, StatModValues);
	for (i = 0; i < StatMods.Length; ++i)
	{
		AddModifier(int(StatModValues[i]), StatMods[i].GetX2Effect().FriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
	}

	//  Flanking bonus (do not apply to melee)
	if (bFlanking && !bMeleeAttack)
	{
		AddModifier(SourceUnit.GetCurrentStat(eStat_FlankingAimBonus), class'XLocalizedData'.default.FlankingAimBonus, m_ShotBreakdown, eHit_Success, bDebugLog);
	}

	//  Squadsight penalty
	if (bSquadsight)
	{
		Tiles = SourceUnit.TileDistanceBetween(TargetUnit);
		//  remove number of tiles within visible range (which is in meters, so convert to units, and divide that by tile size)
		Tiles -= SourceUnit.GetVisibilityRadius() * class'XComWorldData'.const.WORLD_METERS_TO_UNITS_MULTIPLIER / class'XComWorldData'.const.WORLD_StepSize;
		if (Tiles > 0)      //  pretty much should be since a squadsight target is by definition beyond sight range. but... 
			AddModifier(default.SQUADSIGHT_DISTANCE_MOD * Tiles, class'XLocalizedData'.default.SquadsightMod, m_ShotBreakdown, eHit_Success, bDebugLog);
		else if (Tiles == 0)	//	right at the boundary, but squadsight IS being used so treat it like one tile
			AddModifier(default.SQUADSIGHT_DISTANCE_MOD, class'XLocalizedData'.default.SquadsightMod, m_ShotBreakdown, eHit_Success, bDebugLog);
	}

	//  Check for modifiers from weapon 				
	if (SourceWeapon != none)
	{
		//  Weapon's range table.
		iRangeModifier = GetWeaponRangeModifier(SourceUnit, TargetUnit, SourceWeapon);
		AddModifier(iRangeModifier, class'XLocalizedData'.default.WeaponRange, m_ShotBreakdown, eHit_Success, bDebugLog);

		// Built-in weapon flat modifier.
		iWeaponMod = SourceWeapon.GetItemAimModifier();
		AddModifier(iWeaponMod, class'XLocalizedData'.default.WeaponAimBonus, m_ShotBreakdown, eHit_Success, bDebugLog);

		// Weapon Upgrades
		WeaponUpgrades = SourceWeapon.GetMyWeaponUpgradeTemplates();
		for (i = 0; i < WeaponUpgrades.Length; ++i)
		{
			if (WeaponUpgrades[i].AddHitChanceModifierFn != None)
			{
				if (WeaponUpgrades[i].AddHitChanceModifierFn(WeaponUpgrades[i], VisInfo, iWeaponMod))
				{
					AddModifier(iWeaponMod, WeaponUpgrades[i].GetItemFriendlyName(), m_ShotBreakdown, eHit_Success, bDebugLog);
				}
			}
		}
	}

	// --------------------------- TARGET STATS ------------------------

	AddModifier(-TargetUnit.GetCurrentStat(eStat_Defense), class'XLocalizedData'.default.DefenseStat, m_ShotBreakdown, eHit_Success, bDebugLog);
				
	if (!bMeleeAttack)
	{
		//  Add cover penalties
		if (TargetUnit.CanTakeCover())
		{
			// if any cover is being taken, factor in the angle to attack
			if (VisInfo.TargetCover != CT_None && !bIgnoreCoverBonus)
			{
				switch (VisInfo.TargetCover)
				{
				case CT_MidLevel:           //  half cover
					CoverValue = LOW_COVER_BONUS;
					AddModifier(-CoverValue, class'XLocalizedData'.default.TargetLowCover, m_ShotBreakdown, eHit_Success, bDebugLog);

					// Height Advantage reduces the effectiveness of Low Cover.
					if (SourceUnit.HasHeightAdvantageOver(TargetUnit, true))
					{
						HeightAdvantageBonus = GetHeightAdvantageBonus(SourceUnit, TargetUnit, CoverValue);
						AddModifier(HeightAdvantageBonus, class'XLocalizedData'.default.HeightAdvantage, m_ShotBreakdown, eHit_Success, bDebugLog);
					}

					break;

				case CT_Standing:           //  full cover
					CoverValue = HIGH_COVER_BONUS;
					AddModifier(-CoverValue, class'XLocalizedData'.default.TargetHighCover, m_ShotBreakdown, eHit_Success, bDebugLog);
					break;
				default:
					break;
				}

				// Aiming Angle
				CoverAngleBonus = GetCoverAngleBonus(SourceUnit, TargetUnit, VisInfo.TargetCoverAngle, CoverValue);
				if (CoverAngleBonus + HeightAdvantageBonus > CoverValue)
				{
					// Don't allow to compensate for more cover defense than there is cover defense.
					CoverAngleBonus = CoverValue - HeightAdvantageBonus;
				}
				AddModifier(CoverAngleBonus, class'XLocalizedData'.default.AngleToTargetCover, m_ShotBreakdown, eHit_Success, bDebugLog);
			}
		}

		// TODO: Add weapon-based height advantage or disadvantage.
		////  Height advantage
		//if (UnitState.HasHeightAdvantageOver(TargetState, true))
		//{
		//	AddModifier(class'X2TacticalGameRuleset'.default.UnitHeightAdvantageBonus, class'XLocalizedData'.default.HeightAdvantage, m_ShotBreakdown, eHit_Success, bDebugLog);
		//}
		//
		////  Check for height disadvantage
		//if (TargetState.HasHeightAdvantageOver(UnitState, false))
		//{
		//	AddModifier(class'X2TacticalGameRuleset'.default.UnitHeightDisadvantagePenalty, class'XLocalizedData'.default.HeightDisadvantage, m_ShotBreakdown, eHit_Success, bDebugLog);
		//}
	}

	// --------------------------- SHOOTER EFFECTS ------------------------

	foreach SourceUnit.AffectedByEffects(EffectRef)
	{
		EffectModifiers.Length = 0;
		EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
		if (EffectState == none)
			continue;

		PersistentEffect = EffectState.GetX2Effect();
		if (PersistentEffect == none)
			continue;

		if (UniqueToHitEffects.Find(PersistentEffect) != INDEX_NONE)
			continue;

		PersistentEffect.GetToHitModifiers(EffectState, SourceUnit, TargetUnit, kAbility, self.Class, bMeleeAttack, bFlanking, bIndirectFire, EffectModifiers);
		if (EffectModifiers.Length > 0)
		{
			if (PersistentEffect.UniqueToHitModifiers())
				UniqueToHitEffects.AddItem(PersistentEffect);

			for (i = 0; i < EffectModifiers.Length; ++i)
			{
				// Skip crit and dodge.
				if (EffectModifiers[i].ModType == eHit_Crit || EffectModifiers[i].ModType == eHit_Graze)
						continue;
				
				AddModifier(EffectModifiers[i].Value, EffectModifiers[i].Reason, m_ShotBreakdown, EffectModifiers[i].ModType, bDebugLog);
			}
		}
	}

	// --------------------------- TARGET EFFECTS ------------------------

	UniqueToHitEffects.Length = 0;
	foreach TargetUnit.AffectedByEffects(EffectRef)
	{
		EffectModifiers.Length = 0;
		EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
		if (EffectState == none)
			continue;

		PersistentEffect = EffectState.GetX2Effect();
		if (PersistentEffect == none)
			continue;

		if (UniqueToHitEffects.Find(PersistentEffect) != INDEX_NONE)
			continue;

		PersistentEffect.GetToHitAsTargetModifiers(EffectState, SourceUnit, TargetUnit, kAbility, self.Class, bMeleeAttack, bFlanking, bIndirectFire, EffectModifiers);
		if (EffectModifiers.Length > 0)
		{
			if (PersistentEffect.UniqueToHitAsTargetModifiers())
				UniqueToHitEffects.AddItem(PersistentEffect);

			for (i = 0; i < EffectModifiers.Length; ++i)
			{
				// Skip crit and dodge.
				if (EffectModifiers[i].ModType == eHit_Graze || EffectModifiers[i].ModType == eHit_Crit)
					continue;

				AddModifier(EffectModifiers[i].Value, EffectModifiers[i].Reason, m_ShotBreakdown, EffectModifiers[i].ModType, bDebugLog);
			}
		}
	}
	
	// --------------------------- FINALIZATION ------------------------

	if (bReactionFire)
	{
		FinalAdjust = m_ShotBreakdown.ResultTable[eHit_Success] * GetReactionAdjust(SourceUnit, TargetUnit);
		AddModifier(-int(FinalAdjust), AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
		AddReactionFlatModifier(SourceUnit, TargetUnit, m_ShotBreakdown, bDebugLog);
	}
	else if (FinalMultiplier != 1.0f)
	{
		FinalAdjust = m_ShotBreakdown.ResultTable[eHit_Success] * FinalMultiplier;
		AddModifier(-int(FinalAdjust), AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
	}

	FinalizeHitChance(m_ShotBreakdown, bDebugLog);
	return m_ShotBreakdown.FinalHitChance;

}

// Reduce the cover bonus based on height difference and distance between units.
private function float GetHeightAdvantageBonus(XComGameState_Unit SourceUnit, XComGameState_Unit TargetUnit, const float CoverBonus)
{	
	local TTile SourceUnitTileLocation;
	local TTile TargetUnitTileLocation;
	local float	TileDistance;
	local float	HeightDifference;
	local float VerticalAngle;
	local float VerticalAngleMult;

	// Should this use UnitState.TileLocation instead?
	SourceUnit.GetKeystoneVisibilityLocation(SourceUnitTileLocation);
	TargetUnit.GetKeystoneVisibilityLocation(TargetUnitTileLocation);

	SourceUnitTileLocation.Z += SourceUnit.GetHeightAdvantageBonusZ();
	TargetUnitTileLocation.Z += TargetUnit.GetHeightAdvantageBonusZ();

	TileDistance = SourceUnit.TileDistanceBetween(TargetUnit);

	// We're just solving this triangle, where "a" is the angle, shooter is standing at the top of the triangle, 
	// and the target is in the right corner.
	// The vertical line is height difference and horizontal line is distance.
	// |\
	// |a\
	// |  \
	// |   \
	// ------
	HeightDifference = SourceUnitTileLocation.Z - TargetUnitTileLocation.Z;
	if (HeightDifference >= class'X2TacticalGameRuleset'.default.UnitHeightAdvantage)
	{
		VerticalAngle = Atan(TileDistance / HeightDifference);

		// The narrower the angle, the more cover we ignore.
		// At 0 degrees we ignore 100% of cover, at 90 degrees we ignore 0%.
		VerticalAngleMult = 1.0f - VerticalAngle / (Pi / 2.0f);

		return Round(CoverBonus * VerticalAngleMult);
	}
}

// In this situation, most favorable to the shooter, angle is reported as 25.
// <enemy> <cover>   <tile>
// <tile>  <tile>    <tile>
// <tile>  <shooter> <tile>

// Here the angle is 62.
// <enemy> <cover> <shooter> 
// presumably because of stepout tiles:
// <tile>  <tile>  <stepout>
// <enemy> <cover> <shooter> 
// <tile>  <tile>  <stepout>

// While this is 90, as you would expect.
// <enemy> <cover> <tile> <shooter> 

private function float GetCoverAngleBonus(XComGameState_Unit SourceUnit, XComGameState_Unit TargetUnit, const float CoverAngle, const float CoverBonus)
{
	local TTile SourceUnitTileLocation;
	local TTile TargetUnitTileLocation;
	local ECoverType NextTileOverCoverType;
	local float GoodAngleMult;
	local float Alpha;

	SourceUnit.GetKeystoneVisibilityLocation(SourceUnitTileLocation);
	TargetUnit.GetKeystoneVisibilityLocation(TargetUnitTileLocation);
	NextTileOverCoverType = NextTileOverCoverInSameDirection(SourceUnitTileLocation, TargetUnitTileLocation);

	`AMLOG("CoverAngle:" @ CoverAngle @ "CoverBonus:" @ CoverBonus @ "NextTileOverCoverType:" @ NextTileOverCoverType);

	// Don't provide a good angle bonus if the target is covered from the side we're attacking.
	// Until we cross the threshold of ~45 degrees, the target will be considered covered, 
	// even if they're on a corner or behind a singular piece of cover. 
	// This essentially provides the minimum required angle to receive a good angle bonus.
	if (NextTileOverCoverType != CT_None)
		return 0;

	// At 90 degrees, cover is 100% strong, so GoodAngleMult = 0
	// At 25 degrees, cover is 25% strong, so GoodAngleMult = 0.75
	Alpha = ((90.0f - CoverAngle) / (90.0f - 25.0f));

	GoodAngleMult = Lerp(0.0f, fMaxGoodAngleBonusMultiplier, Alpha);

	`AMLOG(`ShowVar(GoodAngleMult) @ "Good angle bonus:" @ CoverBonus * GoodAngleMult);

	return Round(CoverBonus * GoodAngleMult);
}
/*
function ECoverType NextTileOverCoverInSameDirection(const out TTile SourceTile, const out TTile DestTile)
{
	local TTile TileDifference, AdjacentTile;
	local XComWorldData WorldData;
	local int AnyCoverDirectionToCheck, LowCoverDirectionToCheck, CornerCoverDirectionToCheck, CornerLowCoverDirectionToCheck;
	local TileData AdjacentTileData, DestTileData;
	local ECoverType BestCover;

	WorldData = `XWORLD;

	AdjacentTile = DestTile;

	TileDifference.X = SourceTile.X - DestTile.X;
	TileDifference.Y = SourceTile.Y - DestTile.Y;

	`AMLOG("SourceTile:    " @ SourceTile.X @ SourceTile.Y @ SourceTile.Z);
	`AMLOG("DestTile:      " @ DestTile.X @ DestTile.Y @ DestTile.Z);
	`AMLOG("TileDifference:" @ TileDifference.X @ TileDifference.Y @ TileDifference.Z);

	if( Abs(TileDifference.X) > Abs(TileDifference.Y) )
	{
		if( TileDifference.X > 0 )
		{
			++AdjacentTile.X;

			CornerCoverDirectionToCheck = WorldData.COVER_West;
			CornerLowCoverDirectionToCheck = WorldData.COVER_WLow;
		}
		else
		{
			--AdjacentTile.X;

			CornerCoverDirectionToCheck = WorldData.COVER_East;
			CornerLowCoverDirectionToCheck = WorldData.COVER_ELow;
		}

		if( TileDifference.Y > 0 )
		{
			AnyCoverDirectionToCheck = WorldData.COVER_North;
			LowCoverDirectionToCheck = WorldData.COVER_NLow;
		}
		else
		{
			AnyCoverDirectionToCheck = WorldData.COVER_South;
			LowCoverDirectionToCheck = WorldData.COVER_SLow;
		}
	}
	else
	{
		if( TileDifference.Y > 0 )
		{
			++AdjacentTile.Y;

			CornerCoverDirectionToCheck = WorldData.COVER_North;
			CornerLowCoverDirectionToCheck = WorldData.COVER_NLow;
		}
		else
		{
			--AdjacentTile.Y;

			CornerCoverDirectionToCheck = WorldData.COVER_South;
			CornerLowCoverDirectionToCheck = WorldData.COVER_SLow;
		}

		if( TileDifference.X > 0 )
		{
			AnyCoverDirectionToCheck = WorldData.COVER_West;
			LowCoverDirectionToCheck = WorldData.COVER_WLow;
		}
		else
		{
			AnyCoverDirectionToCheck = WorldData.COVER_East;
			LowCoverDirectionToCheck = WorldData.COVER_ELow;
		}
	}

	`AMLOG("AdjacentTile:" @ AdjacentTile.X @ AdjacentTile.Y @ AdjacentTile.Z);

	WorldData.GetTileData(DestTile, DestTileData);

	BestCover = CT_None;

	if( (DestTileData.CoverFlags & CornerCoverDirectionToCheck) != 0 )
	{
		if( (DestTileData.CoverFlags & CornerLowCoverDirectionToCheck) == 0 )
		{
			// high corner cover
			return CT_Standing;
		}
		else
		{
			// low corner cover - still need to check for high adjacent cover
			BestCover = CT_MidLevel;
		}
	}
	
	if( !WorldData.IsTileFullyOccupied(AdjacentTile) ) // if the tile is fully occupied, it won't have cover information - we need to check the corner cover value instead
	{
		WorldData.GetTileData(AdjacentTile, AdjacentTileData);

		// cover flags are valid - if they don't provide ANY cover in the specified direction, return CT_None
		if( (AdjacentTileData.CoverFlags & AnyCoverDirectionToCheck) != 0 )
		{
			// if the cover flags in the specified direction don't have the low cover flag, then it is high cover
			if( (AdjacentTileData.CoverFlags & LowCoverDirectionToCheck) == 0 )
			{
				// high adjacent cover
				BestCover = CT_Standing;
			}
			else
			{
				// low adjacent cover
				BestCover = CT_MidLevel;
			}
		}
	}
	else
	{
		// test if the adjacent tile is occupied because it is the base of a ramp
		++AdjacentTile.Z;
		if( WorldData.IsRampTile(AdjacentTile) )
		{
			BestCover = CT_Standing;
		}
	}

	return BestCover;
}*/
protected function int GetHitChance_Old(XComGameState_Ability kAbility, AvailableTarget kTarget, optional out ShotBreakdown m_ShotBreakdown, optional bool bDebugLog = false)
{
	local XComGameState_Unit UnitState, TargetState;
	local XComGameState_Item SourceWeapon;
	local GameRulesCache_VisibilityInfo VisInfo;
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local int i, iWeaponMod, iRangeModifier, Tiles;
	local ShotBreakdown EmptyShotBreakdown;
	local array<ShotModifierInfo> EffectModifiers;
	local StateObjectReference EffectRef;
	local XComGameState_Effect EffectState;
	local XComGameStateHistory History;
	local bool bFlanking, bIgnoreGraze, bSquadsight;
	local string IgnoreGrazeReason;
	local X2AbilityTemplate AbilityTemplate;
	local array<XComGameState_Effect> StatMods;
	local array<float> StatModValues;
	local X2Effect_Persistent PersistentEffect;
	local array<X2Effect_Persistent> UniqueToHitEffects;
	local float FinalAdjust, CoverValue, AngleToCoverModifier, Alpha;
	local bool bShouldAddAngleToCoverBonus;
	local TTile UnitTileLocation, TargetTileLocation;
	local ECoverType NextTileOverCoverType;
	local int TileDistance;

	/// HL-Docs: feature:GetHitChanceEvents; issue:1031; tags:tactical
	/// WARNING! Triggering events in `X2AbilityToHitCalc::GetHitChance()` and other functions called by this function
	/// may freeze (hard hang) the game under certain circumstances.
	///
	/// In our experiments, the game would hang when the player used a moving melee ability when an event was triggered
	/// in `UITacticalHUD_AbilityContainer::ConfirmAbility()`  right above the 
	/// `XComPresentationLayer(Owner.Owner).PopTargetingStates();` line or anywhere further down the script trace,
	/// while another event was also triggered in `GetHitChance()` or anywhere further down the script trace.
	///
	/// The game hangs while executing UI code, but it is the event in the To Hit Calculation logic that induces it.
	/// The speculation is that triggering events in `GetHitChance()` somehow corrupts the event manager, or it
	/// could be a threading issue.

	`log("=" $ GetFuncName() $ "=", bDebugLog, 'XCom_HitRolls');

	//  @TODO gameplay handle non-unit targets
	History = `XCOMHISTORY;
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID( kAbility.OwnerStateObject.ObjectID ));
	TargetState = XComGameState_Unit(History.GetGameStateForObjectID( kTarget.PrimaryTarget.ObjectID ));
	if (kAbility != none)
	{
		AbilityTemplate = kAbility.GetMyTemplate();
		SourceWeapon = kAbility.GetSourceWeapon();			
	}

	//  reset shot breakdown
	m_ShotBreakdown = EmptyShotBreakdown;

	//  check for a special guaranteed hit
	m_ShotBreakdown.SpecialGuaranteedHit = UnitState.CheckSpecialGuaranteedHit(kAbility, SourceWeapon, TargetState);
	m_ShotBreakdown.SpecialCritLabel = UnitState.CheckSpecialCritLabel(kAbility, SourceWeapon, TargetState);

	//  add all of the built-in modifiers
	if (bGuaranteedHit || m_ShotBreakdown.SpecialGuaranteedHit != '')
	{
		//  call the super version to bypass our check to ignore success mods for guaranteed hits
		super.AddModifier(100, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
	}
	else if (bIndirectFire)
	{
		m_ShotBreakdown.HideShotBreakdown = true;
		AddModifier(100, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
	}

	// Issue #346: AddModifier(BuiltIn...Mod) block moved later in method.
	/// HL-Docs: ref:Bugfixes; issue:346
	/// Prevent `X2AbilityToHitCalc_StandardAim` from applying BuiltInHitMod and BuiltInCritMod against non-units.

	if (UnitState != none && TargetState == none)
	{
		// when targeting non-units, we have a 100% chance to hit. They can't dodge or otherwise
		// mess up our shots
		m_ShotBreakdown.HideShotBreakdown = true;
		AddModifier(100, class'XLocalizedData'.default.OffenseStat, m_ShotBreakdown, eHit_Success, bDebugLog);
	}
	else if (UnitState != none && TargetState != none)
	{				
		// Start Issue #346: Block moved from earlier.
		AddModifier(BuiltInHitMod, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
		AddModifier(BuiltInCritMod, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Crit, bDebugLog);
		// End Issue #346

		if (!bIndirectFire)
		{
			// StandardAim (with direct fire) will require visibility info between source and target (to check cover). 
			if (`TACTICALRULES.VisibilityMgr.GetVisibilityInfo(UnitState.ObjectID, TargetState.ObjectID, VisInfo))
			{	
				if (UnitState.CanFlank() && TargetState.GetMyTemplate().bCanTakeCover && VisInfo.TargetCover == CT_None)
					bFlanking = true;
				if (VisInfo.bClearLOS && !VisInfo.bVisibleGameplay)
					bSquadsight = true;

				//  Add basic offense and defense values
				AddModifier(UnitState.GetBaseStat(eStat_Offense), class'XLocalizedData'.default.OffenseStat, m_ShotBreakdown, eHit_Success, bDebugLog);
				// Single Line Change for Issue #313
				/// HL-Docs: ref:GetStatModifiersFixed
				UnitState.GetStatModifiersFixed(eStat_Offense, StatMods, StatModValues);
				for (i = 0; i < StatMods.Length; ++i)
				{
					AddModifier(int(StatModValues[i]), StatMods[i].GetX2Effect().FriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
				}
				//  Flanking bonus (do not apply to overwatch shots)
				if (bFlanking && !bReactionFire && !bMeleeAttack)
				{
					AddModifier(UnitState.GetCurrentStat(eStat_FlankingAimBonus), class'XLocalizedData'.default.FlankingAimBonus, m_ShotBreakdown, eHit_Success, bDebugLog);
				}
				//  Squadsight penalty
				if (bSquadsight)
				{
					Tiles = UnitState.TileDistanceBetween(TargetState);
					//  remove number of tiles within visible range (which is in meters, so convert to units, and divide that by tile size)
					Tiles -= UnitState.GetVisibilityRadius() * class'XComWorldData'.const.WORLD_METERS_TO_UNITS_MULTIPLIER / class'XComWorldData'.const.WORLD_StepSize;
					if (Tiles > 0)      //  pretty much should be since a squadsight target is by definition beyond sight range. but... 
						AddModifier(default.SQUADSIGHT_DISTANCE_MOD * Tiles, class'XLocalizedData'.default.SquadsightMod, m_ShotBreakdown, eHit_Success, bDebugLog);
					else if (Tiles == 0)	//	right at the boundary, but squadsight IS being used so treat it like one tile
						AddModifier(default.SQUADSIGHT_DISTANCE_MOD, class'XLocalizedData'.default.SquadsightMod, m_ShotBreakdown, eHit_Success, bDebugLog);
				}

				//  Check for modifier from weapon 				
				if (SourceWeapon != none)
				{
					iWeaponMod = SourceWeapon.GetItemAimModifier();
					AddModifier(iWeaponMod, class'XLocalizedData'.default.WeaponAimBonus, m_ShotBreakdown, eHit_Success, bDebugLog);

					WeaponUpgrades = SourceWeapon.GetMyWeaponUpgradeTemplates();
					for (i = 0; i < WeaponUpgrades.Length; ++i)
					{
						if (WeaponUpgrades[i].AddHitChanceModifierFn != None)
						{
							if (WeaponUpgrades[i].AddHitChanceModifierFn(WeaponUpgrades[i], VisInfo, iWeaponMod))
							{
								AddModifier(iWeaponMod, WeaponUpgrades[i].GetItemFriendlyName(), m_ShotBreakdown, eHit_Success, bDebugLog);
							}
						}
					}
				}
				//  Target defense
				AddModifier(-TargetState.GetCurrentStat(eStat_Defense), class'XLocalizedData'.default.DefenseStat, m_ShotBreakdown, eHit_Success, bDebugLog);
				
				//  Add weapon range
				if (SourceWeapon != none)
				{
					iRangeModifier = GetWeaponRangeModifier(UnitState, TargetState, SourceWeapon);
					AddModifier(iRangeModifier, class'XLocalizedData'.default.WeaponRange, m_ShotBreakdown, eHit_Success, bDebugLog);
				}			
				//  Cover modifiers
				if (bMeleeAttack)
				{
					AddModifier(MELEE_HIT_BONUS, class'XLocalizedData'.default.MeleeBonus, m_ShotBreakdown, eHit_Success, bDebugLog);
				}
				else
				{
					//  Add cover penalties
					if (TargetState.CanTakeCover())
					{
						// if any cover is being taken, factor in the angle to attack
						if( VisInfo.TargetCover != CT_None && !bIgnoreCoverBonus )
						{
							switch( VisInfo.TargetCover )
							{
							case CT_MidLevel:           //  half cover
								AddModifier(-LOW_COVER_BONUS, class'XLocalizedData'.default.TargetLowCover, m_ShotBreakdown, eHit_Success, bDebugLog);
								CoverValue = LOW_COVER_BONUS;
								break;
							case CT_Standing:           //  full cover
								AddModifier(-HIGH_COVER_BONUS, class'XLocalizedData'.default.TargetHighCover, m_ShotBreakdown, eHit_Success, bDebugLog);
								CoverValue = HIGH_COVER_BONUS;
								break;
							}

							TileDistance = UnitState.TileDistanceBetween(TargetState);

							// from Angle 0 -> MIN_ANGLE_TO_COVER, receive full MAX_ANGLE_BONUS_MOD
							// As Angle increases from MIN_ANGLE_TO_COVER -> MAX_ANGLE_TO_COVER, reduce bonus received by lerping MAX_ANGLE_BONUS_MOD -> MIN_ANGLE_BONUS_MOD
							// Above MAX_ANGLE_TO_COVER, receive no bonus

							//`assert(VisInfo.TargetCoverAngle >= 0); // if the target has cover, the target cover angle should always be greater than 0
							if( VisInfo.TargetCoverAngle < MAX_ANGLE_TO_COVER && TileDistance <= MAX_TILE_DISTANCE_TO_COVER )
							{
								bShouldAddAngleToCoverBonus = (UnitState.GetTeam() == eTeam_XCom);

								// We have to avoid the weird visual situation of a unit standing behind low cover 
								// and that low cover extends at least 1 tile in the direction of the attacker.
								if( (SHOULD_DISABLE_BONUS_ON_ANGLE_TO_EXTENDED_LOW_COVER && VisInfo.TargetCover == CT_MidLevel) ||
									(SHOULD_ENABLE_PENALTY_ON_ANGLE_TO_EXTENDED_HIGH_COVER && VisInfo.TargetCover == CT_Standing) )
								{
									UnitState.GetKeystoneVisibilityLocation(UnitTileLocation);
									TargetState.GetKeystoneVisibilityLocation(TargetTileLocation);
									NextTileOverCoverType = NextTileOverCoverInSameDirection(UnitTileLocation, TargetTileLocation);

									if( SHOULD_DISABLE_BONUS_ON_ANGLE_TO_EXTENDED_LOW_COVER && VisInfo.TargetCover == CT_MidLevel && NextTileOverCoverType == CT_MidLevel )
									{
										bShouldAddAngleToCoverBonus = false;
									}
									else if( SHOULD_ENABLE_PENALTY_ON_ANGLE_TO_EXTENDED_HIGH_COVER && VisInfo.TargetCover == CT_Standing && NextTileOverCoverType == CT_Standing )
									{
										bShouldAddAngleToCoverBonus = false;

										Alpha = FClamp((VisInfo.TargetCoverAngle - MIN_ANGLE_TO_COVER) / (MAX_ANGLE_TO_COVER - MIN_ANGLE_TO_COVER), 0.0, 1.0);
										AngleToCoverModifier = Lerp(MAX_ANGLE_PENALTY,
											MIN_ANGLE_PENALTY,
											Alpha);
										AddModifier(Round(-1.0 * AngleToCoverModifier), class'XLocalizedData'.default.BadAngleToTargetCover, m_ShotBreakdown, eHit_Success, bDebugLog);
									}
								}

								if( bShouldAddAngleToCoverBonus )
								{
									Alpha = FClamp((VisInfo.TargetCoverAngle - MIN_ANGLE_TO_COVER) / (MAX_ANGLE_TO_COVER - MIN_ANGLE_TO_COVER), 0.0, 1.0);
									AngleToCoverModifier = Lerp(MAX_ANGLE_BONUS_MOD,
																MIN_ANGLE_BONUS_MOD,
																Alpha);
									AddModifier(Round(CoverValue * AngleToCoverModifier), class'XLocalizedData'.default.AngleToTargetCover, m_ShotBreakdown, eHit_Success, bDebugLog);
								}
							}
						}
					}
					//  Add height advantage
					if (UnitState.HasHeightAdvantageOver(TargetState, true))
					{
						AddModifier(class'X2TacticalGameRuleset'.default.UnitHeightAdvantageBonus, class'XLocalizedData'.default.HeightAdvantage, m_ShotBreakdown, eHit_Success, bDebugLog);
					}

					//  Check for height disadvantage
					if (TargetState.HasHeightAdvantageOver(UnitState, false))
					{
						AddModifier(class'X2TacticalGameRuleset'.default.UnitHeightDisadvantagePenalty, class'XLocalizedData'.default.HeightDisadvantage, m_ShotBreakdown, eHit_Success, bDebugLog);
					}
				}
			}

			if (UnitState.IsConcealed())
			{
				`log("Shooter is concealed, target cannot dodge.", bDebugLog, 'XCom_HitRolls');
			}
			else
			{
				if (SourceWeapon == none || SourceWeapon.CanWeaponBeDodged())
				{
					if (TargetState.CanDodge(UnitState, kAbility))
					{
						AddModifier(TargetState.GetCurrentStat(eStat_Dodge), class'XLocalizedData'.default.DodgeStat, m_ShotBreakdown, eHit_Graze, bDebugLog);
					}
					else
					{
						`log("Target cannot dodge due to some gameplay effect.", bDebugLog, 'XCom_HitRolls');
					}
				}					
			}
		}					

		//  Now check for critical chances.
		if (bAllowCrit)
		{
			AddModifier(UnitState.GetBaseStat(eStat_CritChance), class'XLocalizedData'.default.CharCritChance, m_ShotBreakdown, eHit_Crit, bDebugLog);
			// Single Line Change for Issue #313
			/// HL-Docs: ref:GetStatModifiersFixed
			UnitState.GetStatModifiersFixed(eStat_CritChance, StatMods, StatModValues);
			for (i = 0; i < StatMods.Length; ++i)
			{
				AddModifier(int(StatModValues[i]), StatMods[i].GetX2Effect().FriendlyName, m_ShotBreakdown, eHit_Crit, bDebugLog);
			}
			if (bSquadsight)
			{
				AddModifier(default.SQUADSIGHT_CRIT_MOD, class'XLocalizedData'.default.SquadsightMod, m_ShotBreakdown, eHit_Crit, bDebugLog);
			}

			if (SourceWeapon !=  none)
			{
				AddModifier(SourceWeapon.GetItemCritChance(), class'XLocalizedData'.default.WeaponCritBonus, m_ShotBreakdown, eHit_Crit, bDebugLog);

				// Issue #237 start, let upgrades modify the crit chance of the breakdown
				WeaponUpgrades = SourceWeapon.GetMyWeaponUpgradeTemplates();
				for (i = 0; i < WeaponUpgrades.Length; ++i)
				{
					// Make sure we check to only use anything from the ini that we've specified doesn't use an Effect to modify crit chance
					// Everything that does use an Effect, e.g. base game Laser Sights, get added in about 23 lines down from here
					if (WeaponUpgrades[i].AddCritChanceModifierFn != None && default.CritUpgradesThatDontUseEffects.Find(WeaponUpgrades[i].DataName) != INDEX_NONE)
					{
						if (WeaponUpgrades[i].AddCritChanceModifierFn(WeaponUpgrades[i], iWeaponMod))
						{
							AddModifier(iWeaponMod, WeaponUpgrades[i].GetItemFriendlyName(), m_ShotBreakdown, eHit_Crit, bDebugLog);
						}
					}
				}
				// Issue #237 end
			}
			if (bFlanking && !bMeleeAttack)
			{
				if (`XENGINE.IsMultiplayerGame())
				{
					AddModifier(default.MP_FLANKING_CRIT_BONUS, class'XLocalizedData'.default.FlankingCritBonus, m_ShotBreakdown, eHit_Crit, bDebugLog);
				}				
				else
				{
					AddModifier(UnitState.GetCurrentStat(eStat_FlankingCritChance), class'XLocalizedData'.default.FlankingCritBonus, m_ShotBreakdown, eHit_Crit, bDebugLog);
				}
			}
		}
		foreach UnitState.AffectedByEffects(EffectRef)
		{
			EffectModifiers.Length = 0;
			EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
			if (EffectState == none)
				continue;

			PersistentEffect = EffectState.GetX2Effect();
			if (PersistentEffect == none)
				continue;

			if (UniqueToHitEffects.Find(PersistentEffect) != INDEX_NONE)
				continue;

			PersistentEffect.GetToHitModifiers(EffectState, UnitState, TargetState, kAbility, self.Class, bMeleeAttack, bFlanking, bIndirectFire, EffectModifiers);
			if (EffectModifiers.Length > 0)
			{
				if (PersistentEffect.UniqueToHitModifiers())
					UniqueToHitEffects.AddItem(PersistentEffect);

				for (i = 0; i < EffectModifiers.Length; ++i)
				{
					if (!bAllowCrit && EffectModifiers[i].ModType == eHit_Crit)
					{
						if (!PersistentEffect.AllowCritOverride())
							continue;
					}
					AddModifier(EffectModifiers[i].Value, EffectModifiers[i].Reason, m_ShotBreakdown, EffectModifiers[i].ModType, bDebugLog);
				}
			}
			if (PersistentEffect.ShotsCannotGraze())
			{
				bIgnoreGraze = true;
				IgnoreGrazeReason = PersistentEffect.FriendlyName;
			}
		}
		UniqueToHitEffects.Length = 0;
		if (TargetState.AffectedByEffects.Length > 0)
		{
			foreach TargetState.AffectedByEffects(EffectRef)
			{
				EffectModifiers.Length = 0;
				EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
				if (EffectState == none)
					continue;

				PersistentEffect = EffectState.GetX2Effect();
				if (PersistentEffect == none)
					continue;

				if (UniqueToHitEffects.Find(PersistentEffect) != INDEX_NONE)
					continue;

				PersistentEffect.GetToHitAsTargetModifiers(EffectState, UnitState, TargetState, kAbility, self.Class, bMeleeAttack, bFlanking, bIndirectFire, EffectModifiers);
				if (EffectModifiers.Length > 0)
				{
					if (PersistentEffect.UniqueToHitAsTargetModifiers())
						UniqueToHitEffects.AddItem(PersistentEffect);

					for (i = 0; i < EffectModifiers.Length; ++i)
					{
						if (!bAllowCrit && EffectModifiers[i].ModType == eHit_Crit)
							continue;
						if (bIgnoreGraze && EffectModifiers[i].ModType == eHit_Graze)
							continue;
						AddModifier(EffectModifiers[i].Value, EffectModifiers[i].Reason, m_ShotBreakdown, EffectModifiers[i].ModType, bDebugLog);
					}
				}
			}
		}
		//  Remove graze if shooter ignores graze chance.
		if (bIgnoreGraze)
		{
			AddModifier(-m_ShotBreakdown.ResultTable[eHit_Graze], IgnoreGrazeReason, m_ShotBreakdown, eHit_Graze, bDebugLog);
		}
		//  Remove crit from reaction fire. Must be done last to remove all crit.
		if (bReactionFire)
		{
			AddReactionCritModifier(UnitState, TargetState, m_ShotBreakdown, bDebugLog);
		}
	}

	//  Final multiplier based on end Success chance
	if (bReactionFire && !bGuaranteedHit)
	{
		FinalAdjust = m_ShotBreakdown.ResultTable[eHit_Success] * GetReactionAdjust(UnitState, TargetState);
		AddModifier(-int(FinalAdjust), AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
		AddReactionFlatModifier(UnitState, TargetState, m_ShotBreakdown, bDebugLog);
	}
	else if (FinalMultiplier != 1.0f)
	{
		FinalAdjust = m_ShotBreakdown.ResultTable[eHit_Success] * FinalMultiplier;
		AddModifier(-int(FinalAdjust), AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
	}

	FinalizeHitChance(m_ShotBreakdown, bDebugLog);
	return m_ShotBreakdown.FinalHitChance;
}

function InternalRollForAbilityHit(XComGameState_Ability kAbility, AvailableTarget kTarget, bool bIsPrimaryTarget, const out AbilityResultContext ResultContext, out EAbilityHitResult Result, out ArmorMitigationResults ArmorMitigated, out int HitChance)
{
	local int i, RandRoll, Current, ModifiedHitChance;
	local EAbilityHitResult DebugResult, ChangeResult;
	local ArmorMitigationResults Armor;
	local XComGameState_Unit TargetState, UnitState;
	local XComGameState_Player PlayerState;
	local XComGameStateHistory History;
	local StateObjectReference EffectRef;
	local XComGameState_Effect EffectState;
	local bool bRolledResultIsAMiss, bModHitRoll;
	local bool HitsAreCrits;
	local string LogMsg;
	local ETeam CurrentPlayerTeam;
	local ShotBreakdown m_ShotBreakdown;

	History = `XCOMHISTORY;

	`log("===" $ GetFuncName() $ "===", true, 'XCom_HitRolls');
	`log("Attacker ID:" @ kAbility.OwnerStateObject.ObjectID, true, 'XCom_HitRolls');
	`log("Target ID:" @ kTarget.PrimaryTarget.ObjectID, true, 'XCom_HitRolls');
	`log("Ability:" @ kAbility.GetMyTemplate().LocFriendlyName @ "(" $ kAbility.GetMyTemplateName() $ ")", true, 'XCom_HitRolls');

	ArmorMitigated = Armor;     //  clear out fields just in case
	HitsAreCrits = bHitsAreCrits;
	if (`CHEATMGR != none)
	{
		if (`CHEATMGR.bForceCritHits)
			HitsAreCrits = true;

		if (`CHEATMGR.bNoLuck)
		{
			`log("NoLuck cheat forcing a miss.", true, 'XCom_HitRolls');
			Result = eHit_Miss;			
			return;
		}
		if (`CHEATMGR.bDeadEye)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(kAbility.OwnerStateObject.ObjectID));
			if( !`CHEATMGR.bXComOnlyDeadEye || !UnitState.ControllingPlayerIsAI() )
			{
				`log("DeadEye cheat forcing a hit.", true, 'XCom_HitRolls');
				Result = eHit_Success;
				if( HitsAreCrits )
					Result = eHit_Crit;
				return;
			}
		}
	}

	HitChance = GetHitChance(kAbility, kTarget, m_ShotBreakdown, true);
	RandRoll = `SYNC_RAND_TYPED(100, ESyncRandType_Generic);
	Result = eHit_Miss;

	`log("=" $ GetFuncName() $ "=", true, 'XCom_HitRolls');
	`log("Final hit chance:" @ HitChance, true, 'XCom_HitRolls');
	`log("Random roll:" @ RandRoll, true, 'XCom_HitRolls');
	//  GetHitChance fills out m_ShotBreakdown and its ResultTable
	for (i = 0; i < eHit_Miss; ++i)     //  If we don't match a result before miss, then it's a miss.
	{
		Current += m_ShotBreakdown.ResultTable[i];
		DebugResult = EAbilityHitResult(i);
		`log("Checking table" @ DebugResult @ "(" $ Current $ ")...", true, 'XCom_HitRolls');
		if (RandRoll < Current)
		{
			Result = EAbilityHitResult(i);
			`log("MATCH!", true, 'XCom_HitRolls');
			break;
		}
	}	
	if (HitsAreCrits && Result == eHit_Success)
		Result = eHit_Crit;

	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(kAbility.OwnerStateObject.ObjectID));
	TargetState = XComGameState_Unit(History.GetGameStateForObjectID(kTarget.PrimaryTarget.ObjectID));
	
	// Issue #426: ChangeHitResultForX() code block moved to later in method.
	/// HL-Docs: ref:Bugfixes; issue:426
	/// Fix `X2AbilityToHitCalc_StandardAim` discarding unfavorable (for XCOM) changes to hit results from effects
	// Due to how GetModifiedHitChanceForCurrentDifficulty() is implemented, it reverts attempts to change
	// XCom Hits to Misses, or enemy misses to hits.
	// The LW2 graze band issues are related to this phenomenon, since the graze band has the effect
	// of changing some what "should" be enemy misses to hits (specifically graze result)

	// Aim Assist (miss streak prevention)
	bRolledResultIsAMiss = class'XComGameStateContext_Ability'.static.IsHitResultMiss(Result);
	
	//  reaction  fire shots and guaranteed hits do not get adjusted for difficulty
	if( UnitState != None &&
		!bReactionFire &&
		!bGuaranteedHit && 
		m_ShotBreakdown.SpecialGuaranteedHit == '')
	{
		PlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.GetAssociatedPlayerID()));
		CurrentPlayerTeam = PlayerState.GetTeam();

		if( bRolledResultIsAMiss && CurrentPlayerTeam == eTeam_XCom )
		{
			ModifiedHitChance = GetModifiedHitChanceForCurrentDifficulty(PlayerState, TargetState, HitChance);

			if( RandRoll < ModifiedHitChance )
			{
				Result = eHit_Success;
				bModHitRoll = true;
				`log("*** AIM ASSIST forcing an XCom MISS to become a HIT!", true, 'XCom_HitRolls');
			}
		}
		else if( !bRolledResultIsAMiss && (CurrentPlayerTeam == eTeam_Alien || CurrentPlayerTeam == eTeam_TheLost) )
		{
			ModifiedHitChance = GetModifiedHitChanceForCurrentDifficulty(PlayerState, TargetState, HitChance);

			if( RandRoll >= ModifiedHitChance )
			{
				Result = eHit_Miss;
				bModHitRoll = true;
				`log("*** AIM ASSIST forcing an Alien HIT to become a MISS!", true, 'XCom_HitRolls');
			}
		}
	}

	`log("***HIT" @ Result, !bRolledResultIsAMiss, 'XCom_HitRolls');
	`log("***MISS" @ Result, bRolledResultIsAMiss, 'XCom_HitRolls');

	// Start Issue #426: Block moved from earlier. Only code change is for lightning reflexes,
	// because bRolledResultIsAMiss was used for both aim assist and reflexes
	if (UnitState != none && TargetState != none)
	{
		foreach UnitState.AffectedByEffects(EffectRef)
		{
			EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
			if (EffectState != none)
			{
				if (EffectState.GetX2Effect().ChangeHitResultForAttacker(UnitState, TargetState, kAbility, Result, ChangeResult))
				{
					`log("Effect" @ EffectState.GetX2Effect().FriendlyName @ "changing hit result for attacker:" @ ChangeResult,true,'XCom_HitRolls');
					Result = ChangeResult;
				}
			}
		}
		foreach TargetState.AffectedByEffects(EffectRef)
		{
			EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
			if (EffectState != none)
			{
				if (EffectState.GetX2Effect().ChangeHitResultForTarget(EffectState, UnitState, TargetState, kAbility, bIsPrimaryTarget, Result, ChangeResult))
				{
					`log("Effect" @ EffectState.GetX2Effect().FriendlyName @ "changing hit result for target:" @ ChangeResult, true, 'XCom_HitRolls');
					Result = ChangeResult;
				}
			}
		}
	}

	if (TargetState != none)
	{
		//  Check for Lightning Reflexes
		if (bReactionFire && TargetState.bLightningReflexes && !class'XComGameStateContext_Ability'.static.IsHitResultMiss(Result))
		{
			Result = eHit_LightningReflexes;
			`log("Lightning Reflexes triggered! Shot will miss.", true, 'XCom_HitRolls');
		}
	}	
	// End Issue #426

	if (UnitState != none && TargetState != none)
	{
		LogMsg = class'XLocalizedData'.default.StandardAimLogMsg;
		LogMsg = repl(LogMsg, "#Shooter", UnitState.GetName(eNameType_RankFull));
		LogMsg = repl(LogMsg, "#Target", TargetState.GetName(eNameType_RankFull));
		LogMsg = repl(LogMsg, "#Ability", kAbility.GetMyTemplate().LocFriendlyName);
		LogMsg = repl(LogMsg, "#Chance", bModHitRoll ? ModifiedHitChance : HitChance);
		LogMsg = repl(LogMsg, "#Roll", RandRoll);
		LogMsg = repl(LogMsg, "#Result", class'X2TacticalGameRulesetDataStructures'.default.m_aAbilityHitResultStrings[Result]);
		`COMBATLOG(LogMsg);
	}
}
/*
protected function int GetHitChance(XComGameState_Ability kAbility, AvailableTarget kTarget, optional out ShotBreakdown m_ShotBreakdown, optional bool bDebugLog = false)
{
	local XComGameState_Unit UnitState, TargetState;
	local XComGameState_Item SourceWeapon;
	local GameRulesCache_VisibilityInfo VisInfo;
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local int i, iWeaponMod, iRangeModifier, Tiles;
	local ShotBreakdown EmptyShotBreakdown;
	local array<ShotModifierInfo> EffectModifiers;
	local StateObjectReference EffectRef;
	local XComGameState_Effect EffectState;
	local XComGameStateHistory History;
	local bool bFlanking, bIgnoreGraze, bSquadsight;
	local string IgnoreGrazeReason;
	local X2AbilityTemplate AbilityTemplate;
	local array<XComGameState_Effect> StatMods;
	local array<float> StatModValues;
	local X2Effect_Persistent PersistentEffect;
	local array<X2Effect_Persistent> UniqueToHitEffects;
	local float FinalAdjust, CoverValue, AngleToCoverModifier, Alpha;
	local bool bShouldAddAngleToCoverBonus;
	local TTile UnitTileLocation, TargetTileLocation;
	local ECoverType NextTileOverCoverType;
	local int TileDistance;

	/// HL-Docs: feature:GetHitChanceEvents; issue:1031; tags:tactical
	/// WARNING! Triggering events in `X2AbilityToHitCalc::GetHitChance()` and other functions called by this function
	/// may freeze (hard hang) the game under certain circumstances.
	///
	/// In our experiments, the game would hang when the player used a moving melee ability when an event was triggered
	/// in `UITacticalHUD_AbilityContainer::ConfirmAbility()`  right above the 
	/// `XComPresentationLayer(Owner.Owner).PopTargetingStates();` line or anywhere further down the script trace,
	/// while another event was also triggered in `GetHitChance()` or anywhere further down the script trace.
	///
	/// The game hangs while executing UI code, but it is the event in the To Hit Calculation logic that induces it.
	/// The speculation is that triggering events in `GetHitChance()` somehow corrupts the event manager, or it
	/// could be a threading issue.

	`log("=" $ GetFuncName() $ "=", bDebugLog, 'XCom_HitRolls');

	//  @TODO gameplay handle non-unit targets // nice fucking job, Firaxis
	History = `XCOMHISTORY;
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID( kAbility.OwnerStateObject.ObjectID ));
	TargetState = XComGameState_Unit(History.GetGameStateForObjectID( kTarget.PrimaryTarget.ObjectID ));

	if (kAbility != none)
	{
		AbilityTemplate = kAbility.GetMyTemplate();
		SourceWeapon = kAbility.GetSourceWeapon();			
	}

	//  reset shot breakdown
	m_ShotBreakdown = EmptyShotBreakdown;

	// When targeting non-units, we have a 100% chance to hit. They can't dodge or otherwise mess up our shots.
	// Iridar: moved this earlier and added an early exit to guarantee hits.
	if (TargetState == none)
	{
		m_ShotBreakdown.HideShotBreakdown = true;
		AddModifier(100, class'XLocalizedData'.default.OffenseStat, m_ShotBreakdown, eHit_Success, bDebugLog);

		FinalizeHitChance(m_ShotBreakdown, bDebugLog);
		return 100;
	}

	//  check for a special guaranteed hit
	m_ShotBreakdown.SpecialGuaranteedHit = UnitState.CheckSpecialGuaranteedHit(kAbility, SourceWeapon, TargetState);
	m_ShotBreakdown.SpecialCritLabel = UnitState.CheckSpecialCritLabel(kAbility, SourceWeapon, TargetState);

	//  add all of the built-in modifiers
	if (bGuaranteedHit || m_ShotBreakdown.SpecialGuaranteedHit != '' || bIndirectFire)
	{
		//  call the super version to bypass our check to ignore success mods for guaranteed hits
		super(X2AbilityToHitCalc_StandardAim).AddModifier(100, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
	}
	if (bIndirectFire)
	{
		m_ShotBreakdown.HideShotBreakdown = true;
	}

	AddModifier(BuiltInHitMod, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
	AddModifier(BuiltInCritMod, AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Crit, bDebugLog);

	// Iridar: indirect fire abilities can now be dodged, as intended.
	if (UnitState != none)
	{				
		// StandardAim (with direct fire) will require visibility info between source and target (to check cover). 
		if (`TACTICALRULES.VisibilityMgr.GetVisibilityInfo(UnitState.ObjectID, TargetState.ObjectID, VisInfo))
		{	
			if (UnitState.CanFlank() && TargetState.GetMyTemplate().bCanTakeCover && VisInfo.TargetCover == CT_None)
				bFlanking = true;
			if (VisInfo.bClearLOS && !VisInfo.bVisibleGameplay)
				bSquadsight = true;

			//  Add basic offense and defense values
			AddModifier(UnitState.GetBaseStat(eStat_Offense), class'XLocalizedData'.default.OffenseStat, m_ShotBreakdown, eHit_Success, bDebugLog);
			// Single Line Change for Issue #313
			/// HL-Docs: ref:GetStatModifiersFixed
			UnitState.GetStatModifiersFixed(eStat_Offense, StatMods, StatModValues);
			for (i = 0; i < StatMods.Length; ++i)
			{
				AddModifier(int(StatModValues[i]), StatMods[i].GetX2Effect().FriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
			}
			//  Flanking bonus (do not apply to overwatch shots)
			if (bFlanking && !bReactionFire && !bMeleeAttack)
			{
				AddModifier(UnitState.GetCurrentStat(eStat_FlankingAimBonus), class'XLocalizedData'.default.FlankingAimBonus, m_ShotBreakdown, eHit_Success, bDebugLog);
			}
			//  Squadsight penalty
			if (bSquadsight)
			{
				Tiles = UnitState.TileDistanceBetween(TargetState);
				//  remove number of tiles within visible range (which is in meters, so convert to units, and divide that by tile size)
				Tiles -= UnitState.GetVisibilityRadius() * class'XComWorldData'.const.WORLD_METERS_TO_UNITS_MULTIPLIER / class'XComWorldData'.const.WORLD_StepSize;
				if (Tiles > 0)      //  pretty much should be since a squadsight target is by definition beyond sight range. but... 
					AddModifier(default.SQUADSIGHT_DISTANCE_MOD * Tiles, class'XLocalizedData'.default.SquadsightMod, m_ShotBreakdown, eHit_Success, bDebugLog);
				else if (Tiles == 0)	//	right at the boundary, but squadsight IS being used so treat it like one tile
					AddModifier(default.SQUADSIGHT_DISTANCE_MOD, class'XLocalizedData'.default.SquadsightMod, m_ShotBreakdown, eHit_Success, bDebugLog);
			}

			//  Check for modifier from weapon 				
			if (SourceWeapon != none)
			{
				iWeaponMod = SourceWeapon.GetItemAimModifier();
				AddModifier(iWeaponMod, class'XLocalizedData'.default.WeaponAimBonus, m_ShotBreakdown, eHit_Success, bDebugLog);

				WeaponUpgrades = SourceWeapon.GetMyWeaponUpgradeTemplates();
				for (i = 0; i < WeaponUpgrades.Length; ++i)
				{
					if (WeaponUpgrades[i].AddHitChanceModifierFn != None)
					{
						if (WeaponUpgrades[i].AddHitChanceModifierFn(WeaponUpgrades[i], VisInfo, iWeaponMod))
						{
							AddModifier(iWeaponMod, WeaponUpgrades[i].GetItemFriendlyName(), m_ShotBreakdown, eHit_Success, bDebugLog);
						}
					}
				}
			}
			//  Target defense
			AddModifier(-TargetState.GetCurrentStat(eStat_Defense), class'XLocalizedData'.default.DefenseStat, m_ShotBreakdown, eHit_Success, bDebugLog);
				
			//  Add weapon range
			if (SourceWeapon != none)
			{
				iRangeModifier = GetWeaponRangeModifier(UnitState, TargetState, SourceWeapon);
				AddModifier(iRangeModifier, class'XLocalizedData'.default.WeaponRange, m_ShotBreakdown, eHit_Success, bDebugLog);
			}			
			//  Cover modifiers
			if (bMeleeAttack)
			{
				AddModifier(MELEE_HIT_BONUS, class'XLocalizedData'.default.MeleeBonus, m_ShotBreakdown, eHit_Success, bDebugLog);
			}
			else
			{
				//  Add cover penalties
				if (TargetState.CanTakeCover())
				{
					// if any cover is being taken, factor in the angle to attack
					if( VisInfo.TargetCover != CT_None && !ShouldIgnoreCoverDefenseBonus(UnitState, TargetState, kAbility, SourceWeapon) ) // Iridar
					{
						switch( VisInfo.TargetCover )
						{
						case CT_MidLevel:           //  half cover
							AddModifier(-LOW_COVER_BONUS, class'XLocalizedData'.default.TargetLowCover, m_ShotBreakdown, eHit_Success, bDebugLog);
							CoverValue = LOW_COVER_BONUS;
							break;
						case CT_Standing:           //  full cover
							AddModifier(-HIGH_COVER_BONUS, class'XLocalizedData'.default.TargetHighCover, m_ShotBreakdown, eHit_Success, bDebugLog);
							CoverValue = HIGH_COVER_BONUS;
							break;
						}

						TileDistance = UnitState.TileDistanceBetween(TargetState);

						// from Angle 0 -> MIN_ANGLE_TO_COVER, receive full MAX_ANGLE_BONUS_MOD
						// As Angle increases from MIN_ANGLE_TO_COVER -> MAX_ANGLE_TO_COVER, reduce bonus received by lerping MAX_ANGLE_BONUS_MOD -> MIN_ANGLE_BONUS_MOD
						// Above MAX_ANGLE_TO_COVER, receive no bonus

						//`assert(VisInfo.TargetCoverAngle >= 0); // if the target has cover, the target cover angle should always be greater than 0
						if( VisInfo.TargetCoverAngle < MAX_ANGLE_TO_COVER && TileDistance <= MAX_TILE_DISTANCE_TO_COVER )
						{
							bShouldAddAngleToCoverBonus = (UnitState.GetTeam() == eTeam_XCom);

							// We have to avoid the weird visual situation of a unit standing behind low cover 
							// and that low cover extends at least 1 tile in the direction of the attacker.
							if( (SHOULD_DISABLE_BONUS_ON_ANGLE_TO_EXTENDED_LOW_COVER && VisInfo.TargetCover == CT_MidLevel) ||
								(SHOULD_ENABLE_PENALTY_ON_ANGLE_TO_EXTENDED_HIGH_COVER && VisInfo.TargetCover == CT_Standing) )
							{
								UnitState.GetKeystoneVisibilityLocation(UnitTileLocation);
								TargetState.GetKeystoneVisibilityLocation(TargetTileLocation);
								NextTileOverCoverType = NextTileOverCoverInSameDirection(UnitTileLocation, TargetTileLocation);

								if( SHOULD_DISABLE_BONUS_ON_ANGLE_TO_EXTENDED_LOW_COVER && VisInfo.TargetCover == CT_MidLevel && NextTileOverCoverType == CT_MidLevel )
								{
									bShouldAddAngleToCoverBonus = false;
								}
								else if( SHOULD_ENABLE_PENALTY_ON_ANGLE_TO_EXTENDED_HIGH_COVER && VisInfo.TargetCover == CT_Standing && NextTileOverCoverType == CT_Standing )
								{
									bShouldAddAngleToCoverBonus = false;

									Alpha = FClamp((VisInfo.TargetCoverAngle - MIN_ANGLE_TO_COVER) / (MAX_ANGLE_TO_COVER - MIN_ANGLE_TO_COVER), 0.0, 1.0);
									AngleToCoverModifier = Lerp(MAX_ANGLE_PENALTY,
										MIN_ANGLE_PENALTY,
										Alpha);
									AddModifier(Round(-1.0 * AngleToCoverModifier), class'XLocalizedData'.default.BadAngleToTargetCover, m_ShotBreakdown, eHit_Success, bDebugLog);
								}
							}

							if( bShouldAddAngleToCoverBonus )
							{
								Alpha = FClamp((VisInfo.TargetCoverAngle - MIN_ANGLE_TO_COVER) / (MAX_ANGLE_TO_COVER - MIN_ANGLE_TO_COVER), 0.0, 1.0);
								AngleToCoverModifier = Lerp(MAX_ANGLE_BONUS_MOD,
															MIN_ANGLE_BONUS_MOD,
															Alpha);
								AddModifier(Round(CoverValue * AngleToCoverModifier), class'XLocalizedData'.default.AngleToTargetCover, m_ShotBreakdown, eHit_Success, bDebugLog);
							}
						}
					}
				}
				//  Add height advantage
				if (UnitState.HasHeightAdvantageOver(TargetState, true))
				{
					AddModifier(class'X2TacticalGameRuleset'.default.UnitHeightAdvantageBonus, class'XLocalizedData'.default.HeightAdvantage, m_ShotBreakdown, eHit_Success, bDebugLog);
				}

				//  Check for height disadvantage
				if (TargetState.HasHeightAdvantageOver(UnitState, false))
				{
					AddModifier(class'X2TacticalGameRuleset'.default.UnitHeightDisadvantagePenalty, class'XLocalizedData'.default.HeightDisadvantage, m_ShotBreakdown, eHit_Success, bDebugLog);
				}
			}
		}

		if (UnitState.IsConcealed())
		{
			`log("Shooter is concealed, target cannot dodge.", bDebugLog, 'XCom_HitRolls');
		}
		else
		{
			if (SourceWeapon == none || SourceWeapon.CanWeaponBeDodged())
			{
				if (TargetState.CanDodge(UnitState, kAbility))
				{
					AddModifier(TargetState.GetCurrentStat(eStat_Dodge), class'XLocalizedData'.default.DodgeStat, m_ShotBreakdown, eHit_Graze, bDebugLog);
				}
				else
				{
					`log("Target cannot dodge due to some gameplay effect.", bDebugLog, 'XCom_HitRolls');
				}
			}					
		}
							

		//  Now check for critical chances.
		if (bAllowCrit)
		{
			AddModifier(UnitState.GetBaseStat(eStat_CritChance), class'XLocalizedData'.default.CharCritChance, m_ShotBreakdown, eHit_Crit, bDebugLog);
			// Single Line Change for Issue #313
			/// HL-Docs: ref:GetStatModifiersFixed
			UnitState.GetStatModifiersFixed(eStat_CritChance, StatMods, StatModValues);
			for (i = 0; i < StatMods.Length; ++i)
			{
				AddModifier(int(StatModValues[i]), StatMods[i].GetX2Effect().FriendlyName, m_ShotBreakdown, eHit_Crit, bDebugLog);
			}
			if (bSquadsight)
			{
				AddModifier(default.SQUADSIGHT_CRIT_MOD, class'XLocalizedData'.default.SquadsightMod, m_ShotBreakdown, eHit_Crit, bDebugLog);
			}

			if (SourceWeapon !=  none)
			{
				AddModifier(SourceWeapon.GetItemCritChance(), class'XLocalizedData'.default.WeaponCritBonus, m_ShotBreakdown, eHit_Crit, bDebugLog);

				// Issue #237 start, let upgrades modify the crit chance of the breakdown
				WeaponUpgrades = SourceWeapon.GetMyWeaponUpgradeTemplates();
				for (i = 0; i < WeaponUpgrades.Length; ++i)
				{
					// Make sure we check to only use anything from the ini that we've specified doesn't use an Effect to modify crit chance
					// Everything that does use an Effect, e.g. base game Laser Sights, get added in about 23 lines down from here
					if (WeaponUpgrades[i].AddCritChanceModifierFn != None && default.CritUpgradesThatDontUseEffects.Find(WeaponUpgrades[i].DataName) != INDEX_NONE)
					{
						if (WeaponUpgrades[i].AddCritChanceModifierFn(WeaponUpgrades[i], iWeaponMod))
						{
							AddModifier(iWeaponMod, WeaponUpgrades[i].GetItemFriendlyName(), m_ShotBreakdown, eHit_Crit, bDebugLog);
						}
					}
				}
				// Issue #237 end
			}
			if (bFlanking && !bMeleeAttack)
			{
				if (`XENGINE.IsMultiplayerGame())
				{
					AddModifier(default.MP_FLANKING_CRIT_BONUS, class'XLocalizedData'.default.FlankingCritBonus, m_ShotBreakdown, eHit_Crit, bDebugLog);
				}				
				else
				{
					AddModifier(UnitState.GetCurrentStat(eStat_FlankingCritChance), class'XLocalizedData'.default.FlankingCritBonus, m_ShotBreakdown, eHit_Crit, bDebugLog);
				}
			}
		}
		foreach UnitState.AffectedByEffects(EffectRef)
		{
			EffectModifiers.Length = 0;
			EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
			if (EffectState == none)
				continue;

			PersistentEffect = EffectState.GetX2Effect();
			if (PersistentEffect == none)
				continue;

			if (UniqueToHitEffects.Find(PersistentEffect) != INDEX_NONE)
				continue;

			PersistentEffect.GetToHitModifiers(EffectState, UnitState, TargetState, kAbility, self.Class, bMeleeAttack, bFlanking, bIndirectFire, EffectModifiers);
			if (EffectModifiers.Length > 0)
			{
				if (PersistentEffect.UniqueToHitModifiers())
					UniqueToHitEffects.AddItem(PersistentEffect);

				for (i = 0; i < EffectModifiers.Length; ++i)
				{
					if (!bAllowCrit && EffectModifiers[i].ModType == eHit_Crit)
					{
						if (!PersistentEffect.AllowCritOverride())
							continue;
					}
					AddModifier(EffectModifiers[i].Value, EffectModifiers[i].Reason, m_ShotBreakdown, EffectModifiers[i].ModType, bDebugLog);
				}
			}
			if (PersistentEffect.ShotsCannotGraze())
			{
				bIgnoreGraze = true;
				IgnoreGrazeReason = PersistentEffect.FriendlyName;
			}
		}
		UniqueToHitEffects.Length = 0;
		if (TargetState.AffectedByEffects.Length > 0)
		{
			foreach TargetState.AffectedByEffects(EffectRef)
			{
				EffectModifiers.Length = 0;
				EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
				if (EffectState == none)
					continue;

				PersistentEffect = EffectState.GetX2Effect();
				if (PersistentEffect == none)
					continue;

				if (UniqueToHitEffects.Find(PersistentEffect) != INDEX_NONE)
					continue;

				PersistentEffect.GetToHitAsTargetModifiers(EffectState, UnitState, TargetState, kAbility, self.Class, bMeleeAttack, bFlanking, bIndirectFire, EffectModifiers);
				if (EffectModifiers.Length > 0)
				{
					if (PersistentEffect.UniqueToHitAsTargetModifiers())
						UniqueToHitEffects.AddItem(PersistentEffect);

					for (i = 0; i < EffectModifiers.Length; ++i)
					{
						if (!bAllowCrit && EffectModifiers[i].ModType == eHit_Crit)
							continue;
						if (bIgnoreGraze && EffectModifiers[i].ModType == eHit_Graze)
							continue;
						AddModifier(EffectModifiers[i].Value, EffectModifiers[i].Reason, m_ShotBreakdown, EffectModifiers[i].ModType, bDebugLog);
					}
				}
			}
		}
		//  Remove graze if shooter ignores graze chance.
		if (bIgnoreGraze)
		{
			AddModifier(-m_ShotBreakdown.ResultTable[eHit_Graze], IgnoreGrazeReason, m_ShotBreakdown, eHit_Graze, bDebugLog);
		}
		//  Remove crit from reaction fire. Must be done last to remove all crit.
		if (bReactionFire)
		{
			AddReactionCritModifier(UnitState, TargetState, m_ShotBreakdown, bDebugLog);
		}
	}

	//  Final multiplier based on end Success chance
	if (bReactionFire && !bGuaranteedHit)
	{
		FinalAdjust = m_ShotBreakdown.ResultTable[eHit_Success] * GetReactionAdjust_Improved(UnitState, TargetState, kAbility, SourceWeapon);
		AddModifier(-int(FinalAdjust), AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
		AddReactionFlatModifier(UnitState, TargetState, m_ShotBreakdown, bDebugLog);
	}
	else if (FinalMultiplier != 1.0f)
	{
		FinalAdjust = m_ShotBreakdown.ResultTable[eHit_Success] * FinalMultiplier;
		AddModifier(-int(FinalAdjust), AbilityTemplate.LocFriendlyName, m_ShotBreakdown, eHit_Success, bDebugLog);
	}

	FinalizeHitChance(m_ShotBreakdown, bDebugLog);
	return m_ShotBreakdown.FinalHitChance;
}
*/
function float GetReactionAdjust_Improved(XComGameState_Unit Shooter, XComGameState_Unit Target, XComGameState_Ability AbilityState, XComGameState_Item SourceWeapon)
{
	local XComGameState_Effect EffectState;
	local StateObjectReference EffectRef;
	local XComGameStateHistory History;
	local X2Effect_CoveringFire	CoveringFire;
	local X2WeaponStatsTemplate	StatsTemplate;
	local UnitValue				ConcealedValue;

	if (Shooter.GetUnitValue(class'X2Ability_DefaultAbilitySet'.default.ConcealedOverwatchTurn, ConcealedValue))
	{
		if (ConcealedValue.fValue > 0)
			return 0;
	}

	if (SourceWeapon == none)
		return GetReactionAdjust(Shooter, Target);

	// If the weapon has Covering Fire effect applied to it, do not apply a reaction fire penalty.
	History = `XCOMHISTORY;
	foreach Shooter.AffectedByEffects(EffectRef)
	{
		EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
		if (EffectState == none || EffectState.bRemoved)
			continue;

		CoveringFire = X2Effect_CoveringFire(EffectState.GetX2Effect());
		if (CoveringFire == none)
			continue;

		if (EffectState.ApplyEffectParameters.ItemStateObjectRef.ObjectID != AbilityState.SourceWeapon.ObjectID)
			continue;

		return 0;
	}

	StatsTemplate = `GetWeaponStats(SourceWeapon.GetMyTemplateName());
	if (StatsTemplate != none)
		return StatsTemplate.fReactionFirePenalty;

	//return GetReactionAdjust(UnitState, TargetState);
	return default.REACTION_FINALMOD;
}

// FOXCOM: Disable aim assist.
function int GetModifiedHitChanceForCurrentDifficulty(XComGameState_Player Instigator, XComGameState_Unit TargetState, int BaseHitChance)
{
	return BaseHitChance;
}


final function bool ShouldIgnoreCoverDefenseBonus(XComGameState_Unit ShooterUnit, XComGameState_Unit TargetUnit, XComGameState_Ability AbilityState, XComGameState_Item SourceWeapon)
{
	local X2WeaponStatsTemplate	StatsTemplate;

	if (bIgnoreCoverBonus)
		return true;

	StatsTemplate = `GetWeaponStats(SourceWeapon.GetMyTemplateName());
	if (StatsTemplate != none)
		return StatsTemplate.bIgnoreCoverDefense;

	return false;
}

//  Inside of GetHitChance, m_ShotBreakdown should be initially reset, then all modifiers to the shot should be added via this function.
protected function AddModifier(const int ModValue, const string ModReason, out ShotBreakdown m_ShotBreakdown, EAbilityHitResult ModType=eHit_Success, bool bDebugLog = false)
{
	local ShotModifierInfo Mod;

	switch(ModType)
	{
	case eHit_Miss:
		//  Miss should never be modified, only Success
		`assert(false);
		return;
	}

	if (ModValue != 0)
	{
		Mod.ModType = ModType;
		Mod.Value = ModValue;
		Mod.Reason = ModReason;
		m_ShotBreakdown.Modifiers.AddItem(Mod);
		m_ShotBreakdown.ResultTable[ModType] += ModValue;
		m_ShotBreakdown.FinalHitChance = m_ShotBreakdown.ResultTable[eHit_Success];
	}
	`log("Modifying" @ ModType @ (ModValue >= 0 ? "+" : "") $ ModValue @ "(" $ ModReason $ "), New hit chance:" @ m_ShotBreakdown.FinalHitChance, bDebugLog, 'XCom_HitRolls');
}


protected function FinalizeHitChance(out ShotBreakdown m_ShotBreakdown, bool bDebugLog = false)
{
	local int i;
	local EAbilityHitResult HitResult;
	// Vars for Issue #555
	local bool OverrideHitChanceCalc;
	local delegate<OverrideFinalHitChance> OverrideFn;
	// End Issue #555

	// Start Issue #555
	OverrideHitChanceCalc = false;
	foreach OverrideFinalHitChanceFns(OverrideFn)
	{
		OverrideHitChanceCalc = OverrideHitChanceCalc || OverrideFn(self, m_ShotBreakdown);
	}

	// If any of the delegate functions returns true, then we skip the default
	// processing of the hit chance.
	if (OverrideHitChanceCalc)
	{
		return;
	}
	// End Issue #555

	`log("==" $ GetFuncName() $ "==\n", bDebugLog, 'XCom_HitRolls');
	`log("Starting values...", bDebugLog, 'XCom_HitRolls');
	for (i = 0; i < eHit_MAX; ++i)
	{
		HitResult = EAbilityHitResult(i);
		`log(HitResult $ ":" @ m_ShotBreakdown.ResultTable[i], bDebugLog, 'XCom_HitRolls');
	}

	m_ShotBreakdown.FinalHitChance = m_ShotBreakdown.ResultTable[eHit_Success];

	//  cap success at 100 so it can be fully overridden by crit
	m_ShotBreakdown.ResultTable[eHit_Success] = min(m_ShotBreakdown.ResultTable[eHit_Success], 100);

	// FOXCOM: Disable crit.
	////  if crit goes negative, hit would get a boost, so restrict it to 0
	//if (m_ShotBreakdown.ResultTable[eHit_Crit] < 0)
	//	m_ShotBreakdown.ResultTable[eHit_Crit] = 0;
	//
	////  Crit is folded into the chance to hit, so lower accordingly
	//m_ShotBreakdown.ResultTable[eHit_Success] -= m_ShotBreakdown.ResultTable[eHit_Crit];

	// FOXCOM: Disable Dodge. This math is very wrong anyway.
	//  Graze is scaled against Success - but ignored if success is 100%
	//if (m_ShotBreakdown.ResultTable[eHit_Graze] > 0) 
	//{
	//	if (m_ShotBreakdown.FinalHitChance < 100)
	//	{
	//		GrazeScale = float(m_ShotBreakdown.ResultTable[eHit_Graze]) / 100.0f;
	//		GrazeScale *= float(m_ShotBreakdown.FinalHitChance);
	//		FinalGraze = Round(GrazeScale);
	//		m_ShotBreakdown.ResultTable[eHit_Success] -= FinalGraze;
	//		m_ShotBreakdown.ResultTable[eHit_Graze] = FinalGraze;
	//	}
	//	else
	//	{
	//		m_ShotBreakdown.ResultTable[eHit_Graze] = 0;
	//	}
	//}

	if (m_ShotBreakdown.FinalHitChance >= 100)
	{
		m_ShotBreakdown.ResultTable[eHit_Miss] = 0;
	}
	else
	{
		m_ShotBreakdown.ResultTable[eHit_Miss] = 100 - m_ShotBreakdown.FinalHitChance;
	}
	
	`log("Calculated values...", bDebugLog, 'XCom_HitRolls');
	for (i = 0; i < eHit_MAX; ++i)
	{
		HitResult = EAbilityHitResult(i);
		`log(HitResult $ ":" @ m_ShotBreakdown.ResultTable[i], bDebugLog, 'XCom_HitRolls');
	}
	`log("Final hit chance (success + crit + graze) =" @ m_ShotBreakdown.FinalHitChance, bDebugLog, 'XCom_HitRolls');

	//"Negative chance to hit" is used as a token in UI code - don't ever report that.
	if (m_ShotBreakdown.FinalHitChance < 0)
	{
		`log("FinalHitChance was less than 0 (" $ m_ShotBreakdown.FinalHitChance $ ") and was clamped to avoid confusing the UI (@btopp).", bDebugLog, 'XCom_HitRolls');
		m_ShotBreakdown.FinalHitChance = 0;
	}
}

static final function PatchAbilityTemplates()
{
	local X2AbilityTemplateManager					AbilityMgr;
	local X2DataTemplate							DataTemplate;
	local X2AbilityTemplate							AbilityTemplate;
	local X2AbilityToHitCalc_StandardAim			OldCalc;
	local X2AbilityToHitCalc_StandardAim_Override	NewCalc;

	AbilityMgr = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	foreach AbilityMgr.IterateTemplates(DataTemplate)
	{
		AbilityTemplate = X2AbilityTemplate(DataTemplate);
		if (AbilityTemplate == none || AbilityTemplate.AbilityToHitCalc == none)
			continue;

		if (AbilityTemplate.AbilityToHitCalc.Class == class'X2AbilityToHitCalc_StandardAim')
		{
			OldCalc = X2AbilityToHitCalc_StandardAim(AbilityTemplate.AbilityToHitCalc);
			NewCalc = new class'X2AbilityToHitCalc_StandardAim_Override';

			NewCalc.bIndirectFire = OldCalc.bIndirectFire;
			NewCalc.bMeleeAttack = OldCalc.bMeleeAttack;
			NewCalc.bReactionFire = OldCalc.bReactionFire;
			NewCalc.bMultiTargetOnly = OldCalc.bMultiTargetOnly;
			NewCalc.bOnlyMultiHitWithSuccess = OldCalc.bOnlyMultiHitWithSuccess;
			NewCalc.bGuaranteedHit = OldCalc.bGuaranteedHit;
			NewCalc.bIgnoreCoverBonus = OldCalc.bIgnoreCoverBonus;
			NewCalc.FinalMultiplier = OldCalc.FinalMultiplier;
			NewCalc.BuiltInHitMod = OldCalc.BuiltInHitMod;
			NewCalc.HitModifiers = OldCalc.HitModifiers;

			AbilityTemplate.AbilityToHitCalc = NewCalc;
		}

		if (AbilityTemplate.AbilityTargetStyle != none && X2AbilityTarget_Self(AbilityTemplate.AbilityTargetStyle) == none)
		{	
			AbilityTemplate.AbilityTargetConditions.AddItem(new class'X2Condition_WeakpointTargeting');
		}
	}

	AbilityTemplate = AbilityMgr.FindAbilityTemplate('StandardShot');
	AbilityTemplate.AdditionalAbilities.AddItem('IRI_FM_WeakpointTargeting_Enable');
	AbilityTemplate.AdditionalAbilities.AddItem('IRI_FM_WeakpointTargeting_Disable');
}
