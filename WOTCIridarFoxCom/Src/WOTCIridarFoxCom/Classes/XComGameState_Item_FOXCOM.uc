class XComGameState_Item_FOXCOM extends XComGameState_Item;

// --------------------------------------------
//			PERSONAL WEAPON UPGRADES

simulated function array<name> GetMyWeaponUpgradeTemplateNames()
{
	return m_arrWeaponUpgradeNames;
}




simulated function array<X2WeaponUpgradeTemplate> GetMyWeaponUpgradeTemplates()
{
	local X2ItemTemplateManager ItemMgr;
	local int i;

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	if (m_arrWeaponUpgradeTemplates.Length > m_arrWeaponUpgradeNames.Length)
		m_arrWeaponUpgradeTemplates.Length = 0;

	for (i = 0; i < m_arrWeaponUpgradeNames.Length; ++i)
	{
		if (m_arrWeaponUpgradeTemplates[i] == none || m_arrWeaponUpgradeTemplates[i].DataName != m_arrWeaponUpgradeNames[i])
			m_arrWeaponUpgradeTemplates[i] = X2WeaponUpgradeTemplate(ItemMgr.FindItemTemplate(m_arrWeaponUpgradeNames[i]));
	}

	return m_arrWeaponUpgradeTemplates;
}



//  Note: this should only be called after verifying the upgrade can be applied successfully, there is no error checking here.
simulated function ApplyWeaponUpgradeTemplate(X2WeaponUpgradeTemplate UpgradeTemplate, optional int SlotIndex = -1)
{
	// If a specific slot was not provided or the slot is past any equipped upgrades, add it to the end of the upgrade list
	if (SlotIndex == -1 || SlotIndex >= m_arrWeaponUpgradeNames.Length)
	{
		m_arrWeaponUpgradeNames.AddItem(UpgradeTemplate.DataName);
		m_arrWeaponUpgradeTemplates.AddItem(UpgradeTemplate);
	}
	else // Otherwise replace the specific slot index
	{
		m_arrWeaponUpgradeNames[SlotIndex] = UpgradeTemplate.DataName;
		m_arrWeaponUpgradeTemplates[SlotIndex] = UpgradeTemplate;
	}

	//  adjust anything upgrades could affect
	Ammo = GetClipSize();
}

simulated function X2WeaponUpgradeTemplate DeleteWeaponUpgradeTemplate(int SlotIndex)
{
	local X2WeaponUpgradeTemplate UpgradeTemplate;
	
	// If an upgrade template exists at the slot index, delete it
	if (SlotIndex < m_arrWeaponUpgradeNames.Length && m_arrWeaponUpgradeNames[SlotIndex] != '')
	{
		UpgradeTemplate = m_arrWeaponUpgradeTemplates[SlotIndex];
		
		m_arrWeaponUpgradeNames[SlotIndex] = '';
		m_arrWeaponUpgradeTemplates[SlotIndex] = none;
	}

	return UpgradeTemplate;
}

simulated function WipeUpgradeTemplates()
{
	m_arrWeaponUpgradeNames.Length = 0;
	m_arrWeaponUpgradeTemplates.Length = 0;

	//  adjust anything upgrades could affect
	Ammo = GetClipSize();
}