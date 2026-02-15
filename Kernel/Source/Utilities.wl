BeginPackage["WWE`FileScope`Utilities`", {
	"WWE`",
	"WWE`Private`"
}];
Begin["`Private`"];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* crontabSpecValidQ *)
(* Description:  Validates a crontab specification
 * Return:       True | False
 *)
cronMacrosP = Alternatives[
	"annually","yearly","monthly","weekly",
	"daily","midnight","hourly","reboot"
];
minuteStringP = ("\\*" | (ToString /@ Range[0, 59]));
hourStringP = ("\\*" | (ToString /@ Range[0, 23]));
daysStringP = ("\\*" |( ToString /@ Range[1, 31]));
monthStringP = Alternatives[
	"\\*",
	ToString /@ Range[1, 12],
	{
		"jan","feb","mar","apr","may","jun",
		"jul","aug","sep","oct","nov","dec"
	}
];
weekdayStringP = Alternatives[
	"\\*",
	ToString /@ Range[0, 7],
	{
		"mon","tue","wed","thu","fri","sat","sun"
	}
];
crontabSpecValidQ = StringMatchQ[
	Alternatives[
		StringExpression[ "@", cronMacrosP ],
		StringExpression[
			StringExpression[minuteStringP, ( "," ~~ minuteStringP)...],
			WhitespaceCharacter..,
			StringExpression[hourStringP, ("," ~~ hourStringP)...],
			WhitespaceCharacter..,
			StringExpression[daysStringP, ("," ~~ daysStringP)...],
			WhitespaceCharacter..,
			StringExpression[monthStringP, ("," ~~ monthStringP)...],
			WhitespaceCharacter..,
			StringExpression[weekdayStringP, ("," ~~ weekdayStringP)...]
		]
	]
];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* getFileAtTopLevel *)
(* Description:  Retrieves the file at the top level of the specified location
 * Return:       FileName | $Failed
 *)
getFileAtTopLevel // Options = {
	"Level" -> 100
};
getFileAtTopLevel[___] := $Failed;
getFileAtTopLevel[fileName_String, location_String, OptionsPattern[]] :=
	First[
		SortBy[
			FileNames[fileName, { location }, OptionValue["Level"]],
			StringCount[#, "/"]&
		],
		$Failed
	];

End[];
EndPackage[];
