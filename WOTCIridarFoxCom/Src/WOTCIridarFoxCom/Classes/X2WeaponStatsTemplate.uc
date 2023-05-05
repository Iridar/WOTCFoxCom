class X2WeaponStatsTemplate extends X2DataTemplate PerObjectConfig config(TemplateEditor);

// For automatics and other multiple projectile weapons.
var config bool		bIgnoreCoverDefense;
var config int		iLowCoverDamagePenalty;
var config int		iHighCoverDamagePenalty;

var config float	fReactionFirePenalty;



static final function PatchWeaponTemplates()
{
	local X2ItemTemplateManager			ItemMgr;
	local X2WeaponStatsTemplateManager	StatsMgr;
	local X2WeaponStatsTemplate			StatsTemplate;
	local array<X2WeaponTemplate>		WeaponTemplates;
	local X2WeaponTemplate				WeaponTemplate;
	local UIStatMarkup					LowCoverMarkup;
	local UIStatMarkup					HighCoverMarkup;
	local UIStatMarkup					ReactionFireMarkup;

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	StatsMgr = class'X2WeaponStatsTemplateManager'.static.GetWeaponStatsTemplateManager();
	WeaponTemplates = ItemMgr.GetAllWeaponTemplates();

	HighCoverMarkup.StatLabel = `GetLocalizedString("HighCover_DamageReduction_StatLabel");
	LowCoverMarkup.StatLabel = `GetLocalizedString("LowCover_DamageReduction_StatLabel");
	ReactionFireMarkup.StatLabel = `GetLocalizedString("ReactionFirePenalty_StatLabel");
	ReactionFireMarkup.StatUnit = "%";

	foreach WeaponTemplates(WeaponTemplate)
	{
		StatsTemplate = StatsMgr.FindWeaponStatsTemplate(WeaponTemplate.DataName);
		if (StatsTemplate == none)
			continue;

		if (StatsTemplate.bIgnoreCoverDefense)
		{
			WeaponTemplate.Abilities.AddItem('IRI_FM_IgnoreCoverDefense');
		}

		if (StatsTemplate.iHighCoverDamagePenalty != 0)
		{
			HighCoverMarkup.StatModifier = StatsTemplate.iHighCoverDamagePenalty;
			WeaponTemplate.UIStatMarkups.AddItem(HighCoverMarkup);
		}
		if (StatsTemplate.iLowCoverDamagePenalty != 0)
		{
			LowCoverMarkup.StatModifier = StatsTemplate.iLowCoverDamagePenalty;
			WeaponTemplate.UIStatMarkups.AddItem(LowCoverMarkup);
		}
		if (StatsTemplate.fReactionFirePenalty != 0)
		{
			ReactionFireMarkup.StatModifier = int(StatsTemplate.fReactionFirePenalty * 100.0f);
			WeaponTemplate.UIStatMarkups.AddItem(ReactionFireMarkup);
		}

		
	}
}

function bool ValidateTemplate(out string strError)
{
	return true;
}

defaultproperties
{
	//bShouldCreateDifficultyVariants = true
}
