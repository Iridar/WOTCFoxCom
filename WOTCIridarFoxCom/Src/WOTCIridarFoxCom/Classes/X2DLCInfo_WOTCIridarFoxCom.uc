class X2DLCInfo_WOTCIridarFoxCom extends X2DownloadableContentInfo;

static function OnPreCreateTemplates()
{
	//class'X2EventListener_WoundTimers'.static.OnPreCreateTemplates();
}

static event OnPostTemplatesCreated()
{
	class'X2AbilityToHitCalc_StandardAim_Override'.static.PatchAbilityTemplates();
	class'X2WeaponStatsTemplate'.static.PatchWeaponTemplates();
	class'X2Character_Weakpoints'.static.PatchCharacterTemplates();
}

static function ModifyEarnedSoldierAbilities(out array<SoldierClassAbilityType> EarnedAbilities, XComGameState_Unit UnitState)
{
	class'X2Ability_BleedoutPenalty'.static.ModifyEarnedSoldierAbilities(EarnedAbilities, UnitState);
}

static function bool AbilityTagExpandHandler_CH(string InString, out string OutString, Object ParseObj, Object StrategyParseOb, XComGameState GameState)
{
	return class'X2EventListener_BleedoutPenalty'.static.AbilityTagExpandHandler_CH(InString, OutString, ParseObj, StrategyParseOb, GameState);
}

static event InstallNewCampaign(XComGameState StartState)
{
	StartState.CreateNewStateObject(class'X2CustomCardManager');
}
static event OnLoadedSavedGame()
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(default.DLCIdentifier $ " Creating Custom Card Manager");
	NewGameState.CreateNewStateObject(class'X2CustomCardManager');
	`XCOMHISTORY.AddGameStateToHistory(NewGameState);
}

/*
static function string DLCAppendSockets(XComUnitPawn Pawn)
{
	local XComGameState_Unit		UnitState;
	local array<SkeletalMeshSocket> NewSockets;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(Pawn.ObjectID));
	if (UnitState == none)
		return "";

	NewSockets.AddItem(CreateSocket('IRI_RShin', 'RShin'));

	Pawn.Mesh.AppendSockets(NewSockets, true);
	return "";
}
static private function SkeletalMeshSocket CreateSocket(const name SocketName, const name BoneName, optional const float X, optional const float Y, optional const float Z, optional const float dRoll, optional const float dPitch, optional const float dYaw, optional float ScaleX = 1.0f, optional float ScaleY = 1.0f, optional float ScaleZ = 1.0f)
{
	local SkeletalMeshSocket NewSocket;

	NewSocket = new class'SkeletalMeshSocket';
    NewSocket.SocketName = SocketName;
    NewSocket.BoneName = BoneName;

    NewSocket.RelativeLocation.X = X;
    NewSocket.RelativeLocation.Y = Y;
    NewSocket.RelativeLocation.Z = Z;

    NewSocket.RelativeRotation.Roll = dRoll * DegToUnrRot;
    NewSocket.RelativeRotation.Pitch = dPitch * DegToUnrRot;
    NewSocket.RelativeRotation.Yaw = dYaw * DegToUnrRot;

	NewSocket.RelativeScale.X = ScaleX;
	NewSocket.RelativeScale.Y = ScaleY;
	NewSocket.RelativeScale.Z = ScaleZ;
    
	return NewSocket;
}*/