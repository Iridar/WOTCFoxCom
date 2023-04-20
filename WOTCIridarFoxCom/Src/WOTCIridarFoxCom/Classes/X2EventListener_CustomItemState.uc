class X2EventListener_CustomItemState extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	if (`GetMCMSettingBool("PERSONAL_WEAPON_UPGRADES"))
	{
		Templates.AddItem(Create_ListenerTemplate());
	}

	return Templates;
}

static private function CHEventListenerTemplate Create_ListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_FOXCOM_X2EventListener_PersonalWeaponUpgrades');

	if (`GetMCMSettingBool("PERSONAL_WEAPON_UPGRADES"))
	{
		Template.RegisterInCampaignStart = true; // just in case
		Template.RegisterInTactical = true; // just in case
		Template.RegisterInStrategy = true;

		Template.AddCHEvent('ItemAddedToSlot', OnItemAddedToSlot, ELD_Immediate);
	}

	return Template;
}

// There's no way to assign custom XCGS_Item to particular weapons, so as a hack, 
// have to replace the created Item State once the weapon is equipped.
// See this CHL issue for more relevant info: https://github.com/X2CommunityCore/X2WOTCCommunityHighlander/issues/1058.
static private function EventListenerReturn OnItemAddedToSlot(Object EventData, Object EventSource, XComGameState NewGameState, Name EventID, Object CallbackObject)
{
    local XComGameState_Item ItemState;
	local XComGameState_Item NewItemState;
    local XComGameState_Unit UnitState;
	local EInventorySlot	 Slot;

	if (!`GetMCMSettingBool("PERSONAL_WEAPON_UPGRADES"))
		return ELR_NoInterrupt;

    ItemState = XComGameState_Item(EventData);
	if (ItemState == none)
		 return ELR_NoInterrupt;

	ItemState = XComGameState_Item(NewGameState.GetGameStateForObjectID(ItemState.ObjectID));
	if (ItemState == none )
		 return ELR_NoInterrupt;
	
	Slot = ItemState.InventorySlot;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none )
		 return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	if (UnitState != none && UnitState.RemoveItemFromInventory(ItemState, NewGameState))
	{
		NewItemState = XComGameState_Item(NewGameState.CreateNewStateObject(class'XComGameState_Item_FOXCOM', ItemState.GetMyTemplate()));
		UnitState.AddItemToInventory(NewItemState, Slot, NewGameState);
		NewGameState.RemoveStateObject(ItemState.ObjectID);
	}
	
    return ELR_NoInterrupt;
}