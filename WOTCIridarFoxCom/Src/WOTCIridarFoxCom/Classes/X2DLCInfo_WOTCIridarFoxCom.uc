class X2DLCInfo_WOTCIridarFoxCom extends X2DownloadableContentInfo;

static function OnPreCreateTemplates()
{
	class'X2EventListener_WoundTimers'.static.OnPreCreateTemplates();
}