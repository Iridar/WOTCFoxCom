class X2WeaponStatsTemplateManager extends X2DataTemplateManager;

static function X2WeaponStatsTemplateManager GetWeaponStatsTemplateManager()
{
	return X2WeaponStatsTemplateManager(class'Engine'.static.GetTemplateManager(class'X2WeaponStatsTemplateManager'));
}

final function X2WeaponStatsTemplate FindWeaponStatsTemplate(const name DataName)
{
	local X2DataTemplate kTemplate;

	kTemplate = FindDataTemplate(DataName);
	if (kTemplate != none)
		return X2WeaponStatsTemplate(kTemplate);
	return none;
}


final function array<X2WeaponStatsTemplate> GetAllWeaponStatsTemplates()
{
	local array<X2WeaponStatsTemplate> arrWeaponStatsTemplates;
	local X2DataTemplate Template;
	local X2WeaponStatsTemplate WeaponStatsTemplate;

	foreach IterateTemplates(Template, none)
	{
		WeaponStatsTemplate = X2WeaponStatsTemplate(Template);

		if (WeaponStatsTemplate != none)
		{
			arrWeaponStatsTemplates.AddItem(WeaponStatsTemplate);
		}
	}

	return arrWeaponStatsTemplates;
}

DefaultProperties
{
	TemplateDefinitionClass=class'X2WeaponStats'
	ManagedTemplateClass=class'X2WeaponStatsTemplate'
}
