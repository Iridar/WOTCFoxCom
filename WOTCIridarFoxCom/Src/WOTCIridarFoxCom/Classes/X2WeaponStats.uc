class X2WeaponStats extends X2DataSet config(TemplateEditor);

var config array<name> TemplateNames;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate>	Templates;
	local X2WeaponStatsTemplate Template;
	local name					TemplateName;

	foreach default.TemplateNames(TemplateName)
	{
		`CREATE_X2TEMPLATE(class'X2WeaponStatsTemplate', Template, TemplateName);
		Templates.AddItem(Template);
	}

	return Templates;
}


