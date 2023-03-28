//-----------------------------------------------------------
//	Class:	WOTCIridarFoxCom_MCMScreenListener
//	Author: Iridar
//	
//-----------------------------------------------------------

class WOTCIridarFoxCom_MCMScreenListener extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local WOTCIridarFoxCom_MCMScreen MCMScreen;

	if (ScreenClass==none)
	{
		if (MCM_API(Screen) != none)
			ScreenClass=Screen.Class;
		else return;
	}

	MCMScreen = new class'WOTCIridarFoxCom_MCMScreen';
	MCMScreen.OnInit(Screen);
}

defaultproperties
{
    ScreenClass = none;
}
