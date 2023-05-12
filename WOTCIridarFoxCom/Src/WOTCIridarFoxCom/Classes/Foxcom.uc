class Foxcom extends Object abstract config(Fox);

var const name WeakpointTargetingValue;
var const name WeakpointKilledValue;

var config array<name> AutomaticWeaponNames;

static final function bool IsUnitWeakpointTargeting(const XComGameState_Unit UnitState)
{
	local UnitValue UV;

	return UnitState.GetUnitValue(default.WeakpointTargetingValue, UV);
}

static final function bool IsAutomaticWeapon(const XComGameState_Item ItemState)
{
	return default.AutomaticWeaponNames.Find(ItemState.GetMyTemplateName()) != INDEX_NONE;
}
static final function bool IsAutomaticWeaponTemplate(const X2WeaponTemplate WeaponTemplate)
{
	return default.AutomaticWeaponNames.Find(WeaponTemplate.DataName) != INDEX_NONE;
}

defaultproperties
{
	WeakpointKilledValue = "IRI_FM_WeakpointKilled_Value"
	WeakpointTargetingValue = "IRI_FM_WeakpointTargeting_Value"
}