class X2Character_Weakpoints extends X2Character;

/*
struct native AttachedComponent 
{
	var() name SubsystemTemplateName; // Character Template name for component.
	var() name SocketName; // Where to attach this component.
};*/

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(IRI_FM_AdvTrooperM3_Weakpoint_Head());
	Templates.AddItem(IRI_FM_AdvTrooperM3_Weakpoint_Balaten());
	Templates.AddItem(IRI_FM_AdvTrooperM3_Weakpoint_Gun());

	return Templates;
}

static function X2CharacterTemplate IRI_FM_AdvTrooperM3_Weakpoint_Gun()
{
	local X2WeakpointTemplate CharTemplate;

	`CREATE_X2TEMPLATE(class'X2WeakpointTemplate', CharTemplate, 'IRI_FM_AdvTrooperM3_Weakpoint_Gun');

	CharTemplate.OwnerTemplate = 'AdvTrooperM3';
	CharTemplate.SocketName = 'R_Hand';
	//CharTemplate.bDisplayUIUnitFlag = false;
	CharTemplate.bNeverSelectable = true;

	CharTemplate.CharacterGroupName = 'AdventTrooper';
	CharTemplate.UnitSize = 1;

	//CharTemplate.strPawnArchetypes.AddItem("GameUnit_AdvTrooper.ARC_GameUnit_AdvTrooperM3_M");
	//CharTemplate.strPawnArchetypes.AddItem("GameUnit_AdvTrooper.ARC_GameUnit_AdvTrooperM3_F");

	// Traversal Rules
	CharTemplate.bCanUse_eTraversal_Normal = true;
	CharTemplate.bCanUse_eTraversal_ClimbOver = true;
	CharTemplate.bCanUse_eTraversal_ClimbOnto = true;
	CharTemplate.bCanUse_eTraversal_ClimbLadder = true;
	CharTemplate.bCanUse_eTraversal_DropDown = true;
	CharTemplate.bCanUse_eTraversal_Grapple = false;
	CharTemplate.bCanUse_eTraversal_Landing = true;
	CharTemplate.bCanUse_eTraversal_BreakWindow = true;
	CharTemplate.bCanUse_eTraversal_KickDoor = true;
	CharTemplate.bCanUse_eTraversal_JumpUp = false;
	CharTemplate.bCanUse_eTraversal_WallClimb = false;
	CharTemplate.bCanUse_eTraversal_BreakWall = false;
	CharTemplate.bAppearanceDefinesPawn = false;    
	CharTemplate.bSetGenderAlways = true;
	CharTemplate.bCanTakeCover = true;

	CharTemplate.bIsAlien = false;
	CharTemplate.bIsAdvent = true;
	CharTemplate.bIsCivilian = false;
	CharTemplate.bIsPsionic = false;
	CharTemplate.bIsRobotic = false;
	CharTemplate.bIsSoldier = false;

	CharTemplate.bCanBeTerrorist = false;
	CharTemplate.bCanBeCriticallyWounded = false;
	CharTemplate.bIsAfraidOfFire = true;

	CharTemplate.strHackIconImage = "UILibrary_Common.TargetIcons.Hack_captain_icon";
	CharTemplate.strTargetIconImage = class'UIUtilities_Image'.const.TargetIcon_Advent;

	return CharTemplate;
}

static function X2CharacterTemplate IRI_FM_AdvTrooperM3_Weakpoint_Balaten()
{
	local X2WeakpointTemplate CharTemplate;

	`CREATE_X2TEMPLATE(class'X2WeakpointTemplate', CharTemplate, 'IRI_FM_AdvTrooperM3_Weakpoint_Balaten');

	CharTemplate.OwnerTemplate = 'AdvTrooperM3';
	CharTemplate.SocketName = 'PistolHolster';
	//CharTemplate.bDisplayUIUnitFlag = false;
	CharTemplate.bNeverSelectable = true;

	CharTemplate.CharacterGroupName = 'AdventTrooper';
	CharTemplate.UnitSize = 1;

	//CharTemplate.strPawnArchetypes.AddItem("GameUnit_AdvTrooper.ARC_GameUnit_AdvTrooperM3_M");
	//CharTemplate.strPawnArchetypes.AddItem("GameUnit_AdvTrooper.ARC_GameUnit_AdvTrooperM3_F");

	// Traversal Rules
	CharTemplate.bCanUse_eTraversal_Normal = true;
	CharTemplate.bCanUse_eTraversal_ClimbOver = true;
	CharTemplate.bCanUse_eTraversal_ClimbOnto = true;
	CharTemplate.bCanUse_eTraversal_ClimbLadder = true;
	CharTemplate.bCanUse_eTraversal_DropDown = true;
	CharTemplate.bCanUse_eTraversal_Grapple = false;
	CharTemplate.bCanUse_eTraversal_Landing = true;
	CharTemplate.bCanUse_eTraversal_BreakWindow = true;
	CharTemplate.bCanUse_eTraversal_KickDoor = true;
	CharTemplate.bCanUse_eTraversal_JumpUp = false;
	CharTemplate.bCanUse_eTraversal_WallClimb = false;
	CharTemplate.bCanUse_eTraversal_BreakWall = false;
	CharTemplate.bAppearanceDefinesPawn = false;    
	CharTemplate.bSetGenderAlways = true;
	CharTemplate.bCanTakeCover = true;

	CharTemplate.bIsAlien = false;
	CharTemplate.bIsAdvent = true;
	CharTemplate.bIsCivilian = false;
	CharTemplate.bIsPsionic = false;
	CharTemplate.bIsRobotic = false;
	CharTemplate.bIsSoldier = false;

	CharTemplate.bCanBeTerrorist = false;
	CharTemplate.bCanBeCriticallyWounded = false;
	CharTemplate.bIsAfraidOfFire = true;

	CharTemplate.strHackIconImage = "UILibrary_Common.TargetIcons.Hack_captain_icon";
	CharTemplate.strTargetIconImage = class'UIUtilities_Image'.const.TargetIcon_Advent;

	return CharTemplate;
}

static function X2CharacterTemplate IRI_FM_AdvTrooperM3_Weakpoint_Head()
{
	local X2WeakpointTemplate CharTemplate;

	`CREATE_X2TEMPLATE(class'X2WeakpointTemplate', CharTemplate, 'IRI_FM_AdvTrooperM3_Weakpoint_Head');

	CharTemplate.OwnerTemplate = 'AdvTrooperM3';
	CharTemplate.SocketName = 'FX_Head';
	//CharTemplate.bDisplayUIUnitFlag = false;
	CharTemplate.bNeverSelectable = true;

	CharTemplate.CharacterGroupName = 'AdventTrooper';
	CharTemplate.UnitSize = 1;

	//CharTemplate.strPawnArchetypes.AddItem("GameUnit_AdvTrooper.ARC_GameUnit_AdvTrooperM3_M");
	//CharTemplate.strPawnArchetypes.AddItem("GameUnit_AdvTrooper.ARC_GameUnit_AdvTrooperM3_F");

	// Traversal Rules
	CharTemplate.bCanUse_eTraversal_Normal = true;
	CharTemplate.bCanUse_eTraversal_ClimbOver = true;
	CharTemplate.bCanUse_eTraversal_ClimbOnto = true;
	CharTemplate.bCanUse_eTraversal_ClimbLadder = true;
	CharTemplate.bCanUse_eTraversal_DropDown = true;
	CharTemplate.bCanUse_eTraversal_Grapple = false;
	CharTemplate.bCanUse_eTraversal_Landing = true;
	CharTemplate.bCanUse_eTraversal_BreakWindow = true;
	CharTemplate.bCanUse_eTraversal_KickDoor = true;
	CharTemplate.bCanUse_eTraversal_JumpUp = false;
	CharTemplate.bCanUse_eTraversal_WallClimb = false;
	CharTemplate.bCanUse_eTraversal_BreakWall = false;
	CharTemplate.bAppearanceDefinesPawn = false;    
	CharTemplate.bSetGenderAlways = true;
	CharTemplate.bCanTakeCover = true;

	CharTemplate.bIsAlien = false;
	CharTemplate.bIsAdvent = true;
	CharTemplate.bIsCivilian = false;
	CharTemplate.bIsPsionic = false;
	CharTemplate.bIsRobotic = false;
	CharTemplate.bIsSoldier = false;

	CharTemplate.bCanBeTerrorist = false;
	CharTemplate.bCanBeCriticallyWounded = false;
	CharTemplate.bIsAfraidOfFire = true;

	CharTemplate.strHackIconImage = "UILibrary_Common.TargetIcons.Hack_captain_icon";
	CharTemplate.strTargetIconImage = class'UIUtilities_Image'.const.TargetIcon_Advent;

	return CharTemplate;
}

static final function PatchCharacterTemplates()
{
	local X2CharacterTemplateManager	CharMgr;
	local X2CharacterTemplate			CharTemplate;
	local X2WeakpointTemplate			WeakpointTemplate;
	local X2DataTemplate				DataTemplate;
	local AttachedComponent				Component;

	CharMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();

	`AMLOG("Running");

	foreach CharMgr.IterateTemplates(DataTemplate)
	{
		WeakpointTemplate = X2WeakpointTemplate(DataTemplate);
		if (WeakpointTemplate == none)
			continue;

		`AMLOG("WeakpointTemplate:" @ WeakpointTemplate.DataName);

		CharTemplate = CharMgr.FindCharacterTemplate(WeakpointTemplate.OwnerTemplate);
		if (CharTemplate == none)
			continue;

		Component.SubsystemTemplateName = WeakpointTemplate.DataName;
		Component.SocketName = WeakpointTemplate.SocketName;

		CharTemplate.SubsystemComponents.AddItem(Component);

		`AMLOG("Adding weakpoint:" @ WeakpointTemplate.DataName @ WeakpointTemplate.SocketName @ "to:" @ CharTemplate.DataName);
	}
}

