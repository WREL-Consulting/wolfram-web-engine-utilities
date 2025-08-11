BeginPackage["WWE`FileScope`ServerTools`", {
	"WWE`",
	"WWE`Private`"
}];
Begin["`Private`"];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* RestartKernelPool *)
(* Description:  Restart all active kernels in the pool
 * Return:       _Success | _Failure
 *)
RestartKernelPool[] := Enclose[
	ConfirmAssert[
		URLExecute["http://localhost:8080/jsp/KillAll.jsp", "RawJSON"]["success"],
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
(* ::Section:: *)(* AddWolframInitCode *)
(* Description:  Adds initialization code to the Wolfram Engine's init.m file
 * Return:       True | False | $Failed
 *)
AddWolframInitCode::noconf = "Could not find init.m file at `1`";
AddWolframInitCode::exists = "Code `1` already exists in init.m file";
AddWolframInitCode // Attributes = {
	HoldFirst
};
AddWolframInitCode // Options = {
	"InitFile" -> "/usr/share/Wolfram/Kernel/init.m"
};
AddWolframInitCode[initCode_, OptionsPattern[]] := Enclose @ Module[{
		stream,
		initFileDir = OptionValue["InitFile"],
		initFileStr,
		codeStr = ToString[Hold[initCode], FormatType->InputForm] // StringReplace[
			StartOfString~~"Hold["~~code:___~~"]"~~EndOfString :> code<>";"
		]
	},

	(* Check that the init file exists *)
	If[!FileExistsQ[initFileDir],
		Message[AddWolframInitCode::noconf, initFileDir];
		Return[$Failed]
	];

	(* Import the init file and remove all whitespace *)
	initFileStr = Confirm[
		Import[initFileDir, "String"],
		"init.m import failed"
	] // StringDelete[WhitespaceCharacter];

	(* Check if the code is already present in the init file *)
	If[ StringContainsQ[
			initFileStr,
			StringDelete[codeStr, WhitespaceCharacter]
		],
		Message[AddWolframInitCode::exists, codeStr];
		Return[False]
	];

	(* Append the code to the init file *)
	WithCleanup[
		stream = Confirm @ OpenAppend[initFileDir],
		Confirm @ WriteLine[stream, codeStr],
		Close[stream]
	];

	True
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
