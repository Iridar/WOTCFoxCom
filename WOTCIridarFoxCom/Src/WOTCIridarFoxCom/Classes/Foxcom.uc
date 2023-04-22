class Foxcom extends Object abstract config(Fox);

var config array<name> AutomaticWeaponNames;

static final function bool IsAutomaticWeapon(const XComGameState_Item ItemState)
{
	return default.AutomaticWeaponNames.Find(ItemState.GetMyTemplateName()) != INDEX_NONE;
}
static final function bool IsAutomaticWeaponTemplate(const X2WeaponTemplate WeaponTemplate)
{
	return default.AutomaticWeaponNames.Find(WeaponTemplate.DataName) != INDEX_NONE;
}
