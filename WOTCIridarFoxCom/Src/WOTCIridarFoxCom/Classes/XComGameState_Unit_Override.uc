class XComGameState_Unit_Override extends XComGameState_Unit;


event TakeDamage( XComGameState NewGameState, const int DamageAmount, const int MitigationAmount, const int ShredAmount, optional EffectAppliedData EffectData, 
						optional Object CauseOfDeath, optional StateObjectReference DamageSource, optional bool bExplosiveDamage = false, optional array<name> DamageTypes,
						optional bool bForceBleedOut = false, optional bool bAllowBleedout = true, optional bool bIgnoreShields = false, optional array<DamageModifierInfo> SpecialDamageMessages)
{
	local int ShieldHP, DamageAmountBeforeArmor, DamageAmountBeforeArmorMinusShield, 
		      PostShield_MitigationAmount, PostShield_DamageAmount, PostShield_ShredAmount, 
		      DamageAbsorbedByShield;
	local DamageResult DmgResult;
	local string LogMsg;
	local Object ThisObj;
	local X2EventManager EventManager;
	local int OverkillDamage;
	local StateObjectReference EffectRef;
	local XComGameState_Effect EffectState;
	local XComGameStateHistory History;
	local X2Effect_Persistent PersistentEffect;
	local UnitValue DamageThisTurnValue;
	local XComGameState_Unit DamageSourceUnit;
	local name PreCheckName;
	local X2Effect_ApplyWeaponDamage DamageEffect;

	//  Cosmetic units should not take damage
	if (GetMyTemplate( ).bIsCosmetic)
		return;

	// already dead units should not take additional damage
	if (IsDead( ))
	{
		return;
	}

	if (`CHEATMGR != none && `CHEATMGR.bInvincible == true && GetTeam( ) == eTeam_XCom)
	{
		LogMsg = class'XLocalizedData'.default.UnitInvincibleLogMsg;
		LogMsg = repl( LogMsg, "#Unit", GetName( eNameType_RankFull ) );
		`COMBATLOG(LogMsg);
		return;
	}
	if (`CHEATMGR != none && `CHEATMGR.bAlwaysBleedOut)
	{
		bForceBleedOut = true;
	}

	History = `XCOMHISTORY;

	// Loop over persistent effects to see if one forces the unit to bleed out
	if (!bForceBleedOut && CanBleedOut())
	{
		foreach AffectedByEffects(EffectRef)
		{
			EffectState = XComGameState_Effect(NewGameState.GetGameStateForObjectID(EffectRef.ObjectID));
			if (EffectState == none)
				EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
			if (EffectState == none || EffectState.bRemoved)
				continue;
			PersistentEffect = EffectState.GetX2Effect();
			if (PersistentEffect == none)
				continue;
			if (PersistentEffect.ForcesBleedout(NewGameState, self, EffectState))
			{
				bForceBleedOut = true;
				break;
			}
		}

		if (!bForceBleedOut)
		{
			DamageSourceUnit = XComGameState_Unit(History.GetGameStateForObjectID(DamageSource.ObjectID));

			if (DamageSourceUnit != none)
			{
				foreach DamageSourceUnit.AffectedByEffects(EffectRef)
				{
					EffectState = XComGameState_Effect(NewGameState.GetGameStateForObjectID(EffectRef.ObjectID));
					if (EffectState == none)
						EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
					if (EffectState == none || EffectState.bRemoved)
						continue;
					PersistentEffect = EffectState.GetX2Effect();
					if (PersistentEffect == none)
						continue;
					if (PersistentEffect.ForcesBleedoutWhenDamageSource(NewGameState, self, EffectState))
					{
						bForceBleedOut = true;
						break;
					}
				}
			}
		}
	}

	ShieldHP = GetCurrentStat( eStat_ShieldHP );
	PostShield_MitigationAmount = MitigationAmount;
	PostShield_DamageAmount = DamageAmount;
	PostShield_ShredAmount = ShredAmount;
	DamageAbsorbedByShield = 0;
	if ((ShieldHP > 0) && !bIgnoreShields) //If there is a shield, then shield should take all damage from both armor and hp, before spilling back to armor and hp
	{
		DamageAmountBeforeArmor = DamageAmount + MitigationAmount;
		DamageAmountBeforeArmorMinusShield = DamageAmountBeforeArmor - ShieldHP;

		if (DamageAmountBeforeArmorMinusShield > 0) //partial shield, needs to recompute armor
		{
			DamageAbsorbedByShield = ShieldHP;  //The shield took as much damage as possible
			PostShield_MitigationAmount = DamageAmountBeforeArmorMinusShield;
			if (PostShield_MitigationAmount > MitigationAmount) //damage is more than what armor can take
			{
				PostShield_DamageAmount = (DamageAmountBeforeArmorMinusShield - MitigationAmount);
				PostShield_MitigationAmount = MitigationAmount;
			}
			else //Armor takes the rest of the damage
			{
				PostShield_DamageAmount = 0;
			}

			// Armor is taking damage, which might cause shred. We shouldn't shred more than the
			// amount of armor used.
			PostShield_ShredAmount = min(PostShield_ShredAmount, PostShield_MitigationAmount);
		}
		else //shield took all, armor doesn't need to take any
		{
			PostShield_MitigationAmount = 0;
			PostShield_DamageAmount = 0;
			DamageAbsorbedByShield = DamageAmountBeforeArmor;  //The shield took a partial hit from the damage
			PostShield_ShredAmount = 0;
		}
	}

	AddShreddedValue(PostShield_ShredAmount);  // Add the new PostShield_ShredAmount

	DmgResult.Shred = PostShield_ShredAmount;
	DmgResult.DamageAmount = PostShield_DamageAmount;
	DmgResult.MitigationAmount = PostShield_MitigationAmount;
	DmgResult.ShieldHP = DamageAbsorbedByShield;
	DmgResult.SourceEffect = EffectData;
	DmgResult.Context = NewGameState.GetContext( );
	DmgResult.SpecialDamageFactors = SpecialDamageMessages;
	DmgResult.DamageTypes = DamageTypes;
	DamageResults.AddItem( DmgResult );

	if (DmgResult.MitigationAmount > 0)
		LogMsg = class'XLocalizedData'.default.MitigatedDamageLogMsg;
	else
		LogMsg = class'XLocalizedData'.default.UnmitigatedDamageLogMsg;

	LogMsg = repl( LogMsg, "#Unit", GetName( eNameType_RankFull ) );
	LogMsg = repl( LogMsg, "#Damage", DmgResult.DamageAmount );
	LogMsg = repl( LogMsg, "#Mitigated", DmgResult.MitigationAmount );
	`COMBATLOG(LogMsg);

	//Damage removes ReserveActionPoints(Overwatch)
	if ((DamageAmount + MitigationAmount) > 0)
	{
		ReserveActionPoints.Length = 0;
	}

	SetUnitFloatValue( 'LastEffectDamage', DmgResult.DamageAmount, eCleanup_BeginTactical );
	GetUnitValue('DamageThisTurn', DamageThisTurnValue);
	DamageThisTurnValue.fValue += DmgResult.DamageAmount;
	SetUnitFloatValue('DamageThisTurn', DamageThisTurnValue.fValue, eCleanup_BeginTurn);

	if (DmgResult.SourceEffect.SourceStateObjectRef.ObjectID != 0)
	{
		LastDamagedByUnitID = DmgResult.SourceEffect.SourceStateObjectRef.ObjectID;
	}
	
	ThisObj = self;
	EventManager = `XEVENTMGR;
	EventManager.TriggerEvent( 'UnitTakeEffectDamage', ThisObj, ThisObj, NewGameState );

	// Apply damage to the shielding
	if (DamageAbsorbedByShield > 0)
	{
		ModifyCurrentStat( eStat_ShieldHP, -DamageAbsorbedByShield );

		if( GetCurrentStat(eStat_ShieldHP) <= 0 )
		{
			// The shields have been expended, remove the shields
			EventManager.TriggerEvent('ShieldsExpended', ThisObj, ThisObj, NewGameState);
		}
	}

	OverkillDamage = (GetCurrentStat( eStat_HP )) - DmgResult.DamageAmount;
	if (OverkillDamage <= 0)
	{
		bKilledByExplosion = bExplosiveDamage;
		KilledByDamageTypes = DamageTypes;

		DamageEffect = X2Effect_ApplyWeaponDamage(CauseOfDeath);

		if (bForceBleedOut || (bAllowBleedout && ShouldBleedOut( -OverkillDamage )))
		{
			if( DamageEffect == None || !DamageEffect.bBypassSustainEffects )
			{
				if( `CHEATMGR == none || !`CHEATMGR.bSkipPreDeathCheckEffects )
				{
					foreach class'X2AbilityTemplateManager'.default.PreDeathCheckEffects(PreCheckName)
					{
						EffectState = GetUnitAffectedByEffectState(PreCheckName);
						if( EffectState != None )
						{
							PersistentEffect = EffectState.GetX2Effect();
							if( PersistentEffect != None )
							{
								if( PersistentEffect.PreBleedoutCheck(NewGameState, self, EffectState) )
								{
									`COMBATLOG("Effect" @ PersistentEffect.FriendlyName @ "is handling the PreBleedoutCheck - unit should bleed out but the effect is handling it");
									return;
								}
							}
						}
					}
				}
			}

			if (ApplyBleedingOut( NewGameState ))
			{
				return;
			}
			else
			{
				`RedScreenOnce("Unit" @ GetName(eNameType_Full) @ "should have bled out but ApplyBleedingOut failed. Killing it instead. -jbouscher @gameplay");
			}
		}

		if( DamageEffect == None || !DamageEffect.bBypassSustainEffects )
		{
			if( `CHEATMGR == none || !`CHEATMGR.bSkipPreDeathCheckEffects )
			{
				foreach class'X2AbilityTemplateManager'.default.PreDeathCheckEffects(PreCheckName)
				{
					EffectState = GetUnitAffectedByEffectState(PreCheckName);
					if( EffectState != None )
					{
						PersistentEffect = EffectState.GetX2Effect();
						if( PersistentEffect != None )
						{
							if( PersistentEffect.PreDeathCheck(NewGameState, self, EffectState) )
							{
								`COMBATLOG("Effect" @ PersistentEffect.FriendlyName @ "is handling the PreDeathCheck - unit should be dead but the effect is handling it");
								return;
							}
						}
					}
				}
			}
		}

		// FOXCOM: Do not allow subsystems to actually die, as it breaks visualization to all hell.
		// Just set them to 999 HP and apply a unit value to prevent them from being targeted again.
		if (m_bSubsystem)
		{
			SetCurrentStat( eStat_HP, 999 );
			SetUnitFloatValue(class'Foxcom'.default.WeakpointKilledValue, 1.0f, eCleanup_BeginTactical);
			return;
		}
		else
		{
			SetCurrentStat( eStat_HP, 0 );
			OnUnitDied( NewGameState, CauseOfDeath, DamageSource, , EffectData );
			return;
		}
	}

	// Apply damage to the HP
	ModifyCurrentStat( eStat_HP, -DmgResult.DamageAmount );

	if (CanEarnXp( ))
	{
		if (GetCurrentStat( eStat_HP ) < (GetMaxStat( eStat_HP ) * 0.5f))
		{
			`TRIGGERXP('XpLowHealth', GetReference( ), GetReference( ), NewGameState);
		}
	}
	if (GetCurrentStat( eStat_HP ) < LowestHP)
		LowestHP = GetCurrentStat( eStat_HP );
}

/*
protected function OnUnitDied(XComGameState NewGameState, Object CauseOfDeath, const out StateObjectReference SourceStateObjectRef, bool ApplyToOwnerAndComponents = true, optional const out EffectAppliedData EffectData)
{
	local XComGameState_Unit Killer, Owner, Comp, KillAssistant, Iter, NewUnitState;
	local XComGameStateHistory History;
	local int iComponentID;
	local X2EventManager EventManager;
	local string LogMsg;
	local XComGameState_Ability AbilityStateObject;
	local UnitValue RankUpValue;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersXCom XComHQ;
	local Name CharacterGroupName, CharacterDeathEvent;
	local XComGameState_Destructible DestructibleKiller;
	local X2Effect EffectCause;
	local XComGameState_Effect EffectState;

	local StateObjectReference objRef;
	local X2CharacterTemplate myTemplate;

	objRef = GetReference();
	myTemplate = GetMyTemplate();


	LogMsg = class'XLocalizedData'.default.UnitDiedLogMsg;
	LogMsg = repl(LogMsg, "#Unit", GetName(eNameType_RankFull));
	`COMBATLOG(LogMsg);

	History = `XCOMHISTORY;

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	m_strKIAOp = BattleData.m_strOpName;
	m_KIADate = BattleData.LocalTime;

	EffectCause = X2Effect(CauseOfDeath);
	if (EffectCause != none && EffectCause.bHideDeathWorldMessage)
		NewGameState.GetContext().PostBuildVisualizationFn.AddItem(UnitDeathVisualizationWithoutWorldMessage);
	else
		NewGameState.GetContext().PostBuildVisualizationFn.AddItem(UnitDeathVisualizationWorldMessage);

	NewGameState.GetContext().SetVisualizerUpdatesState(true); //This unit will be rag-dolling, which will move it, so notify the history system

	EventManager = `XEVENTMGR;
	EventManager.TriggerEvent('UnitDied', self, self, NewGameState);
	
	`XACHIEVEMENT_TRACKER.OnUnitDied(self, NewGameState, CauseOfDeath, SourceStateObjectRef, ApplyToOwnerAndComponents, EffectData, bKilledByExplosion);

	// Golden Path special triggers
	CharacterDeathEvent = GetMyTemplate().DeathEvent;
	if (CharacterDeathEvent != '')
	{
		CharacterGroupName = GetMyTemplate().CharacterGroupName;
		if (CharacterGroupName != 'Cyberus' || AreAllCodexInLineageDead(NewGameState))
		{
			EventManager.TriggerEvent(CharacterDeathEvent, self, self, NewGameState);
		}
	}

	Killer = XComGameState_Unit( History.GetGameStateForObjectID( SourceStateObjectRef.ObjectID ) );

	//	special handling for claymore kills - credit the reaper that placed the claymore, regardless of what blew it up
	//	also special handling for remote start kills
	if (Killer == none)
	{
		DestructibleKiller = XComGameState_Destructible(History.GetGameStateForObjectID(SourceStateObjectRef.ObjectID));
		if (DestructibleKiller != none)
		{
			if (DestructibleKiller.DestroyedByRemoteStartShooter.ObjectID > 0)
			{
				Killer = XComGameState_Unit(History.GetGameStateForObjectID(DestructibleKiller.DestroyedByRemoteStartShooter.ObjectID));
			}
			else
			{
				foreach History.IterateByClassType(class'XcomGameState_Effect', EffectState)
				{
					if (EffectState.CreatedObjectReference.ObjectID == DestructibleKiller.ObjectID)
					{
						if (X2Effect_Claymore(EffectState.GetX2Effect()) != none)
						{
							Killer = XComGameState_Unit(History.GetGameStateForObjectID(EffectState.ApplyEffectParameters.SourceStateObjectRef.ObjectID));
						}

						break;
					}
				}
			}
		}
	}

	if (Killer == None && LastDamagedByUnitID != 0)
	{
		Killer = XComGameState_Unit(History.GetGameStateForObjectID(LastDamagedByUnitID));
	}

	//	special handling for templar ghosts - credit the creator of the ghost with any kills by the ghost
	if (Killer != none && Killer.GhostSourceUnit.ObjectID > 0)
	{
		Killer = XComGameState_Unit(History.GetGameStateForObjectID(Killer.GhostSourceUnit.ObjectID));
	}

	if( GetTeam() == eTeam_Alien || GetTeam() == eTeam_TheLost )
	{
		if( SourceStateObjectRef.ObjectID != 0 )
		{	
			if (Killer != none && Killer.CanEarnXp())
			{
				Killer = XComGameState_Unit(NewGameState.ModifyStateObject(Killer.Class, Killer.ObjectID));
				Killer.KilledUnits.AddItem(GetReference());
				Killer.KillCount += GetMyTemplate().KillContribution; // Allows specific units to contribute different amounts to the kill total

				// If the Wet Work GTS bonus is active, increment the Wet Work kill counter
				XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom', true));
				if(XComHQ != none)
				{
					if(XComHQ.SoldierUnlockTemplates.Find('WetWorkUnlock') != INDEX_NONE)
					{
						Killer.WetWorkKills++;
					}
					
					Killer.BonusKills += (XComHQ.BonusKillXP);
				}

				if (Killer.bIsShaken)
				{
					Killer.UnitsKilledWhileShaken++; //confidence boost towards recovering from being Shaken
				}

				CheckForFlankingEnemyKill(NewGameState, Killer);

				//  Check for and trigger event to display rank up message if applicable
				if (Killer.IsSoldier() && Killer.CanRankUpSoldier() && !class'X2TacticalGameRulesetDataStructures'.static.TacticalOnlyGameMode())
				{
					Killer.GetUnitValue('RankUpMessage', RankUpValue);
					if (RankUpValue.fValue == 0)
					{
						EventManager.TriggerEvent('RankUpMessage', Killer, Killer, NewGameState);
						Killer.SetUnitFloatValue('RankUpMessage', 1, eCleanup_BeginTactical);
					}
				}

				//  All team mates that are alive and able to earn XP will be credited with a kill assist (regardless of their actions)
				foreach History.IterateByClassType(class'XComGameState_Unit', Iter)
				{
					if (Iter != Killer && Iter.ControllingPlayer.ObjectID == Killer.ControllingPlayer.ObjectID && Iter.CanEarnXp() && Iter.IsAlive())
					{
						KillAssistant = XComGameState_Unit(NewGameState.ModifyStateObject(Iter.Class, Iter.ObjectID));
						KillAssistant.KillAssists.AddItem(objRef);
						KillAssistant.KillAssistsCount += myTemplate.KillContribution;

						//  jbouscher: current desire is to only display the rank up message based on a full kill, commenting this out for now.
						//  Check for and trigger event to display rank up message if applicable
						//if (KillAssistant.IsSoldier() && KillAssistant.CanRankUpSoldier())
						//{
						//	RankUpValue.fValue = 0;
						//	KillAssistant.GetUnitValue('RankUpMessage', RankUpValue);
						//	if (RankUpValue.fValue == 0)
						//	{
						//		EventManager.TriggerEvent('RankUpMessage', KillAssistant, KillAssistant, NewGameState);
						//		KillAssistant.SetUnitFloatValue('RankUpMessage', 1, eCleanup_BeginTactical);
						//	}
						//}		
					}
				}

				`TRIGGERXP('XpKillShot', Killer.GetReference(), GetReference(), NewGameState);
			}

			if (Killer != none && Killer.GetMyTemplate().bIsTurret && Killer.GetTeam() == eTeam_XCom && Killer.IsMindControlled())
			{
				`ONLINEEVENTMGR.UnlockAchievement(AT_KillWithHackedTurret);
			}
		}

		// when enemies are killed with pending loot, start the loot expiration timer
		if( IsLootable(NewGameState) )
		{
			// no loot drops in Challenge Mode
			// This would really be done in the AI spawn manager, just don't roll loot for enemies,
			// but that would require fixing up all the existing start states.  Doing it here at runtime is way easier.
			// Also we do it before RollForSpecialLoot so that Templar Focus drops will still occur.
			if (class'X2TacticalGameRulesetDataStructures'.static.TacticalOnlyGameMode( ))
			{
				PendingLoot.LootToBeCreated.Length = 0;
			}

			RollForSpecialLoot();

			if( HasAvailableLoot() )
			{
				MakeAvailableLoot(NewGameState);
			}
			// do the tactical check again so that the 'Loot Destroyed' message isn't added for Psionic drops in Ladder and such
			else if( (PendingLoot.LootToBeCreated.Length > 0) && !class'X2TacticalGameRulesetDataStructures'.static.TacticalOnlyGameMode( ) )
			{
				NewGameState.GetContext().PostBuildVisualizationFn.AddItem(VisualizeLootDestroyedByExplosives);
			}

			// no loot drops in Challenge Mode
			if (!class'X2TacticalGameRulesetDataStructures'.static.TacticalOnlyGameMode( ))
			{
				RollForAutoLoot(NewGameState);
			}
		}
		else
		{
			NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', ObjectID));
			NewUnitState.PendingLoot.LootToBeCreated.Length = 0;
		}
	}
	else if( GetTeam() == eTeam_XCom )
	{
		if( IsLootable(NewGameState) )
		{
			DropCarriedLoot(NewGameState);
		}
	}

	m_strCauseOfDeath = class'UIBarMemorial_Details'.static.FormatCauseOfDeath( self, Killer, NewGameState.GetContext() );

	if (ApplyToOwnerAndComponents)
	{
		// If is component, attempt to apply to owner.
		if ( m_bSubsystem && OwningObjectId > 0)
		{
			// FOXCOM: Don't kill everything the moment one of the subsystem dies.
			
			Owner = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', OwningObjectId));
			Owner.RemoveComponentObject(self);

			`AMLOG("Component killed" @ XGUnit(GetVisualizer()).ObjectID @ XGUnit(Owner.GetVisualizer()).ObjectID);
		}
		else
		{
			// If we are the owner, and we're dead, set all the components as dead.
			foreach ComponentObjectIds(iComponentID)
			{
				Comp = XComGameState_Unit(History.GetGameStateForObjectID(iComponentID));
				if (Comp != None && Comp.IsAlive())
				{
					Comp = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', iComponentID));
					Comp.SetCurrentStat(eStat_HP, 0);
					Comp.OnUnitDied(NewGameState, CauseOfDeath, SourceStateObjectRef, false, EffectData);
				}
			}
		}
	}

	LowestHP = 0;

	// finally send a kill mail: soldier/alien and alien/soldier
	Killer = none;
	if( SourceStateObjectRef.ObjectID != 0 )
	{
		Killer = XComGameState_Unit(History.GetGameStateForObjectID(SourceStateObjectRef.ObjectID));
	}
	EventManager.TriggerEvent('KillMail', self, Killer, NewGameState);

	if (Killer == none)
	{
		if (DestructibleKiller != none)
		{
			EventManager.TriggerEvent('KilledByDestructible', self, DestructibleKiller, NewGameState);
		}
	}

	// send weapon ability that did the killing
	AbilityStateObject = XComGameState_Ability(NewGameState.GetGameStateForObjectID(EffectData.AbilityStateObjectRef.ObjectID));
	if (AbilityStateObject == none)
	{
		AbilityStateObject = XComGameState_Ability(History.GetGameStateForObjectID(EffectData.AbilityStateObjectRef.ObjectID));
	}

	if (AbilityStateObject != none)
	{
		EventManager.TriggerEvent('WeaponKillType', AbilityStateObject, Killer);
	}

}*/