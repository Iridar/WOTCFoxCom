class WOTCIridarFoxCom_MCMScreen extends Object config(WOTCIridarFoxCom);

var config int VERSION_CFG;

var private localized string ModName;
var private localized string PageTitle;
var private localized string GroupHeader_Combat;
var private localized string GroupHeader_Weapons;

var private config array<MCMSettingStruct> MCMSettings;

`include(WOTCIridarFoxCom\Src\ModConfigMenuAPI\MCM_API_Includes.uci)

/***************************************
Insert `MCM_API_Auto????Vars macros here
***************************************/

`include(WOTCIridarFoxCom\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

/********************************************************************
Insert `MCM_API_Auto????Fns and MCM_API_AutoButtonHandler macros here
********************************************************************/

event OnInit(UIScreen Screen)
{
	`MCM_API_Register(Screen, ClientModCallback);
}

//Simple one group framework code
simulated function ClientModCallback(MCM_API_Instance ConfigAPI, int GameMode)
{
	local MCM_API_SettingsPage	Page;
	local MCM_API_SettingsGroup	Group;
	

	LoadSavedSettings();
	Page = ConfigAPI.NewSettingsPage(ModName);
	Page.SetPageTitle(PageTitle);
	Page.SetSaveHandler(SaveButtonClicked);
	Page.EnableResetButton(ResetButtonClicked);

	Group = Page.AddGroup('Group_Combat', GroupHeader_Combat);
	FillMCMGroup(Group);

	Group = Page.AddGroup('Group_Weapons', GroupHeader_Weapons);
	FillMCMGroup(Group);
	


	Page.ShowSettings();
}

private function FillMCMGroup(MCM_API_SettingsGroup Group)
{
	local MCMSettingStruct MCMSetting;
	local string GroupName;

	GroupName = string(Group.GetName());

	foreach MCMSettings(MCMSetting)
	{
		if (MCMSetting.Group == GroupName)
		{
			switch (MCMSetting.Kind)
			{
				case XComLWTVBool:
					Group.AddCheckbox(name(MCMSetting.SettingName), `GetLocalizedString(MCMSetting.SettingName $ "_Label"), `GetLocalizedString(MCMSetting.SettingName $ "_Tip"), bool(MCMSetting.Data[0]), CheckboxSaveHandler);
					break;
				default:
					`AMLOG("WARNING :: MCM Setting:" @ MCMSetting.SettingName @ "kind:" @ MCMSetting.Kind @ "is not handled!");
					break;
			}
		}
	}
}



simulated function LoadSavedSettings()
{
	MCMSettings = GetMCMSettings();
}

simulated function ResetButtonClicked(MCM_API_SettingsPage Page)
{
	MCMSettings = class'WOTCIridarFoxCom_Defaults'.default.MCMSettings;
}


simulated function SaveButtonClicked(MCM_API_SettingsPage Page)
{
	VERSION_CFG = `MCM_CH_GetCompositeVersion();
	SaveConfig();
}

// --------- MCM Builder API ---------

static final function bool GetMCMSettingBool(const string SettingName)
{
	local MCMSettingStruct MCMSetting;

	MCMSetting = GetMCMSetting(SettingName);

	if (MCMSetting.Data.Length > 0)
	{
		return bool(MCMSetting.Data[0]);
	}
	return false;
}

static private function MCMSettingStruct GetMCMSetting(const string SettingName)
{
	local MCMSettingStruct MCMSetting;
	local MCMSettingStruct EmptySetting;
	local array<MCMSettingStruct> locMCMSettings;

	locMCMSettings = GetMCMSettings();

	foreach locMCMSettings(MCMSetting)
	{
		if (MCMSetting.SettingName == SettingName)
		{
			return MCMSetting;
		}
	}
	return EmptySetting;
}

static private function array<MCMSettingStruct> GetMCMSettings()
{
	if (class'WOTCIridarFoxCom_Defaults'.default.VERSION_CFG > default.VERSION_CFG)
	{
		return class'WOTCIridarFoxCom_Defaults'.default.MCMSettings;
	}
	return default.MCMSettings;
}

// --------- SAVE HANDLERS ---------

private function CheckboxSaveHandler(MCM_API_Setting _Setting, bool _SettingValue)
{
	local string SettingName;
	local int i;

	SettingName = string(_Setting.GetName());

	for (i = 0; i < MCMSettings.Length; i++)
	{
		if (MCMSettings[i].SettingName == SettingName)
		{
			MCMSettings[i].Data[0] = string(_SettingValue);
			break;
		}
	}
}