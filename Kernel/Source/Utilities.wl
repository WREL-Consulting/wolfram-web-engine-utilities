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

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* RestartKernelPool *)
(* Description:  Restart all active kernels in the pool
 * Return:       _Success | _Failure
 *)
RestartKernelPool[] := Enclose[
	ConfirmAssert[
		URLExecute["http://localhost/jsp/KillAll.jsp", "RawJSON"]["success"],
		"Failed to restart the kernel pool"
	];
	Success["kernel-pool-restart", <|
		"MessageTemplate" -> "Kernel pool restarted successfully"
	|>]
];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* LogError *)
(* Description:  Logs string into a log file
 * Return:       Null
 *)
LogError // Options = {
	"LogDirectory" -> "/var/log/"
};
LogError[appName_String, functionName_String, message_String, OptionsPattern[]] :=
	Module[{
			errStr,
			dir = FileNameJoin[{
				OptionValue["LogDirectory"], camelToSnakeCase[appName]
			}],
			fileName = ToLowerCase[
				StringTrim @ camelToSnakeCase @ functionName
			] <> "-error.log"
		},

		If[!DirectoryQ[dir],
			CreateDirectory[dir]
		];

		WithCleanup[
			errStr = OpenAppend @ FileNameJoin[{dir, fileName}],
			WriteString[ errStr, message, "\n" ],
			Close[ errStr ]
		]
	];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DefineSupervisorCommand *)
(* Description:  Defines a supervisor command
 * Return:       True | False | $Failed
 *)
DefineSupervisorCommand::noconf = "Could not find supervisord.conf file at /etc/supervisord.conf";
DefineSupervisorCommand::exists = "Program `1` already exists in supervisord.conf file";
DefineSupervisorCommand // Options = {
	"AutoStart" -> True,
	"AutoRestart" -> True,
	"StdErrLogFile" -> "/dev/stderr",
	"StdOutLogFile" -> "/dev/stdout"
};
DefineSupervisorCommand[command_String, name_String, OptionsPattern[]] := Module[{
		stream, rawFile
	},

	Enclose[

		If[FileExistsQ["/etc/supervisord.conf"],
			rawFile = StringDelete[
				Import["/etc/supervisord.conf", "String"],
				WhitespaceCharacter
			],
			Message[DefineSupervisorCommand::noconf];
			Return[$Failed]
		];

		(* Check if program already exists in supervisord.conf file *)
		If[StringContainsQ[rawFile, StringTemplate["[program:``]"][name] ],
			Message[DefineSupervisorCommand::exists, name];
			Return[False]
		];

		(* Append program definition to supervisord.conf file *)
		WithCleanup[
			stream = OpenAppend["/etc/supervisord.conf"],
			WriteString[stream,
				StringTemplate[
					StringRiffle[{
							"",
							"[program:`name`]",
							"command=`command`",
							"autostart=`autostart`",
							"autorestart=`autorestart`",
							"stderr_logfile=`stderr_logfile`",
							"stdout_logfile=`stdout_logfile`",
							""
						},
						"\n"
					]
				][<|
					"name" -> name,
					"command" -> command,
					"autostart" -> OptionValue["AutoStart"] /. {
						True -> "true",
						False -> "false"
					},
					"autorestart" -> OptionValue["AutoRestart"] /. {
						True -> "true",
						False -> "false"
					},
					"stderr_logfile" -> OptionValue["StdErrLogFile"],
					"stdout_logfile" -> OptionValue["StdOutLogFile"]
				|>]
			],
			Close[stream]
		];

		(* Reload supervisor config file *)
		ConfirmAssert[
			Run["supervisorctl reread && supervisorctl update"] === 0,
			"Failed to reload supervisor config"
		];

		True
	]
];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DefineCronJob *)
(* Description:  Defines a cron job in the crontab file
 * Return:       True | False | $Failed
 *)
DefineCronJob::exists = "Command `1` already exists in crontab file";
DefineCronJob::noconf = "Could not find crontab file at `1`";
DefineCronJob // Options = {
	"CrontabFile" -> "/etc/crontab",
	"User" -> "root"
};
DefineCronJob[command_String, cronSpec_String?crontabSpecValidQ, OptionsPattern[]] :=
	Module[
		{
			crontabFile = OptionValue["CrontabFile"],
			existingCrontab, crontabStr, stream, res
		},

		res = Enclose[

			If[!FileExistsQ[crontabFile],
				Message[DefineCronJob::noconf, crontabFile];
				Return[$Failed]
			];

			existingCrontab = Confirm @ Import[crontabFile,
				"Text"
			] // StringDelete[WhitespaceCharacter];

			If[StringContainsQ[existingCrontab, StringDelete[command, WhitespaceCharacter]],
				Message[DefineCronJob::exists, command];
				Return[False]
			];

			crontabStr = StringRiffle[{
				cronSpec, OptionValue["User"], command
			}];
			WithCleanup[
				stream = Confirm @ OpenAppend[crontabFile],
				Confirm @ WriteString[stream, crontabStr, "\n"],
				Close[stream]
			];
			True
		];
		res /. _?FailureQ -> $Failed
	];

End[];
EndPackage[];
