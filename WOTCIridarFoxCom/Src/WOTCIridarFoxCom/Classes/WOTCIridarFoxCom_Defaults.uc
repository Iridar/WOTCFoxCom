class WOTCIridarFoxCom_Defaults extends object config(WOTCIridarFoxCom_DEFAULT);

var config int VERSION_CFG;

/*
enum XComLWTValueKind
{
    XComLWTVBool,
    XComLWTVInt,
    XComLWTVFloat,
    XComLWTVString,
    XComLWTVName,
    XComLWTVObject,
    XComLWTVVector,
    XComLWTVRotator,
    XComLWTVTile,
    XComLWTVArrayObjects,
    XComLWTVArrayInts,
    XComLWTVArrayFloats,
    XComLWTVArrayStrings,
    XComLWTVArrayNames,
    XComLWTVArrayVectors,
    XComLWTVArrayRotators,
    XComLWTVArrayTiles
};
*/
struct MCMSettingStruct
{
	var string				SettingName;
	var array<string>		Data;
	var string				Group;
	var XComLWTValueKind	Kind;
};
var config array<MCMSettingStruct> MCMSettings;
