BeginPackage["WWE`FileScope`Utilities`", {
	"WWE`",
	"WWE`Private`"
}];
Begin["`Private`"];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* camelToSnakeCase *)
(* Description:  Converts a camelCase string to snake_case
 * Return:       String
 *)
camelToSnakeCase = (
	StringReplace[{
		PunctuationCharacter -> "",
		" " -> "-"
	}] /* StringReplace[{
		(StartOfString~~a_?(Not@*LowerCaseQ)):>ToLowerCase[a],
		a_?(LowerCaseQ) ~~b_?(Not@*LowerCaseQ) :> (a<>"-"<>ToLowerCase[b]),
		b_?(Not@*LowerCaseQ)~~a_?(LowerCaseQ)  :> ("-"<>ToLowerCase[b]<>a)
	}] /* ToLowerCase
);

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* crontabSpecValidQ *)
(* Description:  Validates a crontab specification
 * Return:       True | False
 *)
crontabSpecValidQ = StringMatchQ[
	(
		("\\*" | (ToString /@ Range[0, 59])) ~~
		("," ~~ ("\\*" | (ToString /@ Range[0, 59])))...
	) ~~ " " ~~ (
		("\\*" | (ToString /@ Range[0, 23])) ~~
		("," ~~ ("\\*" | (ToString /@ Range[0, 23])))...
	) ~~ " " ~~ (
		("\\*" | (ToString /@ Range[1, 31])) ~~
		("," ~~ ("\\*" | (ToString /@ Range[1, 31])))...
	) ~~ " " ~~ (
		("\\*" | (ToString /@ Range[1, 12]) | {
			"jan","feb","mar","apr","may","jun",
			"jul","aug","sep","oct","nov","dec"
		}) ~~
		("," ~~ ("\\*" | (ToString /@ Range[1, 12]) | {
			"jan","feb","mar","apr","may","jun",
			"jul","aug","sep","oct","nov","dec"
		}))...
	) ~~ " " ~~ (
		("\\*" | (ToString /@ Range[0, 6]) | {
			"mon","tue","wed","thu","fri","sat","sun"
		}) ~~
		("," ~~ ("\\*" | (ToString /@ Range[0, 6]) | {
			"mon","tue","wed","thu","fri","sat","sun"
		}))...
	)
];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* getFileAtTopLevel *)
(* Description:  Retrieves the file at the top level of the specified location
 * Return:       FileName | $Failed
 *)
getFileAtTopLevel // Options = {
	"Level" -> 100
};
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
