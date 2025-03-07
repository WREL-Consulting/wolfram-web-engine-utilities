(* ::Section:: *)(* Dependencies *)
BeginPackage["WWE`", {
	"DatabaseLink`"
}];

(* ::Section:: *)(* Public Symbols *)
deployBuildFolder::usage = "deployBuildFolder[buildDir_, location_ : \"\"] deploys the build files inside `buildDir` to `location` in the Tomcat ROOT webapp directory.";
deployRepository::usage = "deployRepository[repositoryAssoc_, OptionsPattern[]] deploys the repository at `repositoryAssoc` to the Tomcat ROOT webapp directory. \nOptions: \n\"InitializeDB\" -> True will initialize the database.";
deployExpression::usage = "deployExpression[expr_, location_, OptionsPattern[]] deploys the expression `expr` to the Tomcat ROOT webapp directory at `location`.\ndeployExpression[expr_, OptionsPattern[]] deploys the expression `expr` to the Tomcat ROOT webapp directory at a random UUID endpoint.";
addInitCode::usage = "addInitCode[initCode_] adds the initialization code `initCode` to the Wolfram Engine's init.m file.";
initialiseDatabase::usage = "initialiseDatabase[sqlFile_] initializes the database using the SQL commands in `sqlFile`.";
makeDBConnection::usage = "makeDBConnection[dbName_ : \"\"] creates a connection to the database `dbName`.";
addSupervisorProgram::usage = "addSupervisorProgram[command_String, name_String] adds a program to the supervisord configuration file.";
addCrontabCommand::usage = "addCrontabCommand[command_String, cronSpec_String] adds a command to the crontab file with the provided cronSpec.";
logError::usage = "logError[functionName_String, message_String] logs an error message to the log file.";

CommandLineParse = ResourceFunction["CommandLineParse"];

Begin["`Private`"];

camelToSnakeCase = StringReplace[
	(StartOfString~~a_?(Not@*LowerCaseQ)):>ToLowerCase[a],
	a_?(Not@*LowerCaseQ) :> ("-"<>ToLowerCase[a])
];

Options[logError] = {
	"LogDirectory" -> "/var/log/"
};
logError[ appName_String, functionName_String, message_String, OptionsPattern[] ] := Module[{
		errStr,
		dir = FileNameJoin[{
			OptionValue["LogDirectory"], camelToSnakeCase[appName]
		}],
		fileName = camelToSnakeCase[
				ToLowerCase[StringTrim @ functionName]
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

(* ::Section:: *)(* Deployment helper functions *)
Options[deployBuildFolder] = {
	"WebappLocation" -> "/usr/local/tomcat/webapps/ROOT"
};
deployBuildFolder[buildDir_, location_String : "", OptionsPattern[]] :=
	Enclose[
		With[{
			deployLoc = FileNameJoin[{
				OptionValue["WebappLocation"], location
			}]
		},
		(* If location doesn't exist, create it *)
		If[!DirectoryQ[deployLoc],
			Print["\033[2m[deployBuildFolder]:\033[22m Creating directory:", deployLoc];
			Confirm[
				CreateDirectory[deployLoc],
				"Failed to create directory"
			]
		];

		(* Delete any existing duplicate files *)
		If[DirectoryQ[deployLoc],
			Print["\033[2m[deployBuildFolder]:\033[22m Deleting existing deployment files at ", deployLoc];

			With[{ existingFile = FileNameJoin[{ deployLoc, # }] },
				If[FileExistsQ[existingFile],
					If[DirectoryQ[existingFile],
						DeleteDirectory[#, DeleteContents->True]&,
						DeleteFile
					][existingFile]
				]
			]& /@ StringDelete[
				(* Select all file names in the build folder *)
				FileNames[
					loc: (StartOfString~~__~~EndOfString) /; (
						(* Ignore directories *)
						Not[ DirectoryQ @ FileNameJoin[{buildDir, loc}] ]
					),
					buildDir,
					Infinity
				],
				buildDir
			]
		];

		(* Copy the contents of the build folder to the deploy location *)
		ConfirmAssert[
			Run[
				StringTemplate["cp -r `1`/* `2`"][buildDir, deployLoc]
			] === 0,
			"Failed to copy build files"
		]
	]
];

Options[deployRepository] = {
	"Initialize" -> False
};
deployRepository[repositoryAssoc_, OptionsPattern[]] := Module[{
		cloneCommand, cloneCode, buildCommand, buildCode, feLoc, outputLogLoc,
		outputLog, ret, deployWL, errorlog, log, logDir, buildLoc,
		cloneLink = repositoryAssoc["link"],
		localDir = repositoryAssoc["local"],
		init = If[OptionValue["Initialize"],
			" --init",
			""
		]
	},

	(* Define logging function *)
	log = Function[
		BinaryWrite[outputLog, Print["\033[2m[deployRepository]:\033[22m ", #]; ToString[#] <> "\n"];
		#
	];

	(* Create output log *)
	logDir = "/opt/app/logs";
	outputLogLoc = FileNameJoin[{logDir, DateString["ISODateTime"]<>".log"}];
	If[!DirectoryQ[logDir],
		CreateDirectory[logDir]
	];
	Run["touch "<>outputLogLoc];

	(* Define clone command *)
	cloneCommand = StringRiffle[{
		"/scripts/git-clone.sh",
			cloneLink,
			localDir,
			repositoryAssoc["branch"],
		">> '"<>outputLogLoc<>"' 2>&1"
	}];

	WithCleanup[
		outputLog = OpenAppend[outputLogLoc, BinaryFormat -> True];
		,
		ret = Enclose[

			(* Clone the git repository *)
			log["running " <> cloneCommand];
			cloneCode = Run[cloneCommand];
			log["git-clone returned exit code " <> ToString[cloneCode]];
			ConfirmAssert[cloneCode === 0, "Clone failed."];

			(* If package.json exists, build and deploy the frontend *)
			If[FileExistsQ[FileNameJoin[{localDir, "package.json"}]],
				(* Define frontend build command *)
				buildCommand = StringRiffle[{
						"cd "<> localDir,
						"bun install",
						"bun build:wwe >> '"<> outputLogLoc <>"' 2>&1"
					},
					"&&"
				];

				(* Run frontend build command *)
				log["Running " <> buildCommand];
				buildCode = Run[buildCommand];
				log["Build command returned code " <> ToString[buildCode]];
				ConfirmAssert[cloneCode === 0, "Frontend build failed."];

				(* Deploy frontend build files *)
				buildLoc = FileNames[
					"build-wwe",
					localDir,
					10
				] /. _String?(StringContainsQ["node_modules"]) -> Nothing;
				ConfirmAssert[
					Length[buildLoc] > 0,
					"Could not find build-wwe folder"
				];
				Confirm[#, "Frontend deployment failed"]& @
					deployBuildFolder[
						First[buildLoc],
						repositoryAssoc["prefix"]
					];
			];

			(* Deploy WL backend using project's deploy.wwe.wls script *)
			deployWL = FileNames["deploy.wwe.wls", {localDir}, 4];
			If[Length[deployWL] =!= 0,
				ConfirmAssert[
					log["Running 'wolframscript -script "<> # <>init<>"'"];
					Run[
						"wolframscript -script "<> # <>init<>" >> '"<>outputLogLoc<>"' 2>&1"
					] === 0,
					"'" <> # <> "' returned a nonzero code"
				]& /@ deployWL
			]
		]
		,
		Close[outputLog];
	];


	If[FailureQ[ret],
		errorlog = OpenAppend["/opt/app/logs/wrel-deployment-errors",
			BinaryFormat -> True
		];
		BinaryWrite[errorlog, "build failed with Information '"<>
			ret["Information"] <> "' - check '" <> outputLogLoc <> "'\n\n"
		];
		Close[errorlog];
		$Failed
		,
		True
	]
];

Options[deployExpression] = {
	OverwriteTarget -> True,
	"WebappLocation" -> "/usr/local/tomcat/webapps/ROOT",
	"ActiveExtension" -> "wl"
};
deployExpression[expr_, location_String : Automatic, OptionsPattern[]] :=
	Module[{
		loc = location /. Automatic -> CreateUUID[],
		dir = FileNameJoin[{
			OptionValue["WebappLocation"],
			OptionValue["ActiveExtension"],
			location
		}],
		deployment
	},

	Enclose[

		(* Create directory id it doesn't exist *)
		If[!DirectoryQ[dir],
			Confirm[
				CreateDirectory[dir, CreateIntermediateDirectories -> True],
				"Failed to create directory"
			]
		];

		(* Export main index file *)
		deployment = Confirm[
			Export[
				FileNameJoin[{
					dir,
					"index.wl"
				}],
				expr,
				"WL",
				OverwriteTarget -> OptionValue[OverwriteTarget]
			],
			"Failed to export index.wl"
		];

		(* Return 'fake' service deployment object *)
		ServiceDeployment[<|
			"Name" -> "WolframWebEngine",
			"Resource" -> deployment,
			"URL" -> FileNameJoin[{"/",loc}]
		|>]

	]
];

Attributes[addInitCode] = {
	HoldFirst
};
Options[addInitCode] = {
	"InitFile" -> "/usr/share/Wolfram/Kernel/init.m"
};
addInitCode[initCode_, OptionsPattern[]] := Enclose @ Module[{
		stream,
		initFileDir = OptionValue["InitFile"],
		initFileStr,
		codeStr = ToString[Hold[initCode], FormatType->InputForm] // StringReplace[
			StartOfString~~"Hold["~~code:___~~"]"~~EndOfString :> code<>";"
		]
	},

	(* Check that the init file exists *)
	If[!FileExistsQ[initFileDir],
		Message[addInitCode::noconf, initFileDir];
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
		Message[addInitCode::exists, codeStr];
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

Options[addSupervisorProgram] = {
	"AutoStart" -> True,
	"AutoRestart" -> True,
	"StdErrLogFile" -> "/dev/stderr",
	"StdOutLogFile" -> "/dev/stdout"
};
addSupervisorProgram[command_String, name_String, OptionsPattern[]] := Module[{
		stream, rawFile
	},

	Enclose[

		If[FileExistsQ["/etc/supervisord.conf"],
			rawFile = StringDelete[
				Import["/etc/supervisord.conf", "String"],
				WhitespaceCharacter
			],
			Message[addSupervisorProgram::noconf];
			Return[$Failed]
		];

		(* Check if program already exists in supervisord.conf file *)
		If[StringContainsQ[rawFile, StringTemplate["[program:``]"][name] ],
			Message[addSupervisorProgram::exists, name];
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

Options[addCrontabCommand] = {
	"CrontabFile" -> "/etc/crontab",
	"User" -> "root"
};
addCrontabCommand[
	command_String,
	cronSpec_String?(
		StringMatchQ[
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
		]
	),
	OptionsPattern[]
] := Module[
	{
		crontabFile = OptionValue["CrontabFile"],
		existingCrontab, crontabStr, stream, res
	},

	res = Enclose[

		If[!FileExistsQ[crontabFile],
			Message[addCrontabCommand::noconf, crontabFile];
			Return[$Failed]
		];

		existingCrontab = Confirm @ Import[crontabFile,
			"Text"
		] // StringDelete[WhitespaceCharacter];

		If[StringContainsQ[existingCrontab, StringDelete[command, WhitespaceCharacter]],
			Message[addCrontabCommand::exists, command];
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

(* ::Section:: *)(* Database Helper Functions *)
Options[initialiseDatabase] = {
	"RootPassword" -> SystemCredential["db-pass"],
	"DatabasePassword" -> SystemCredential["db-pass"],
	"Port" -> 3306
};
initialiseDatabase[sqlFile_String, OptionsPattern[]]:= Enclose[
	Module[{con, sqlCommands},

		If[FileExistsQ[sqlFile] === False,
			Message[initialiseDatabase::nofile, sqlFile];
			Return[$Failed]
		];

		Needs["DatabaseLink`"];

		WithCleanup[
			con = Confirm[
					OpenSQLConnection[
					JDBC["MySQL(Connector/J)",
						StringTemplate["localhost:``"][
							OptionValue["Port"]
						]
					],
					"Username" -> "root",
					"Password" -> OptionValue["RootPassword"],
					"Properties" -> {
						"useSSL" -> "false"
					}
				],
				"Failed to connect to database"
			]
			,
			sqlCommands = StringTemplate[
				Import[sqlFile, "Text"]
			][<|
				"db-pass" -> OptionValue["DatabasePassword"]
			|>] // StringSplit[#, ";"]&;

			Confirm[
				SQLExecute[con, #]
			]& /@ Prepend[
				"DROP DATABASE IF EXISTS COREDatabase"
			][
				sqlCommands
			]
			,
			CloseSQLConnection[con];
		]

	]
];

Options[makeDBConnection] = {
	"Port" -> 3306,
	"Username" -> "admin",
		"Password" -> SystemCredential["db-pass"],
	"UseConnectionPool" -> True,
	"BaseURL" -> "localhost"
};
makeDBConnection[dbName_String : "", OptionsPattern[]]:= Enclose[
	Needs["DatabaseLink`"];
	Confirm[
		OpenSQLConnection[
			JDBC["MySQL(Connector/J)",
				URLBuild[{
					StringTemplate["`url`:`port`"][
						<|
							"url" -> OptionValue["BaseURL"],
							"port" -> OptionValue["Port"]
						|>
					],
					dbName
				}]
			],
			"Username" -> OptionValue["Username"],
			"Password" -> OptionValue["Password"],
			"Properties" -> {
				"useSSL" -> "false"
			},
			"UseConnectionPool" -> OptionValue["UseConnectionPool"]
		],
		"Failed to connect to database"
	]
];

(* ::Section:: *)(* Messages *)
addSupervisorProgram::noconf = "Could not find supervisord.conf file at /etc/supervisord.conf";
addSupervisorProgram::exists = "Program `1` already exists in supervisord.conf file";
addCrontabCommand::exists = "Command `1` already exists in crontab file";
addCrontabCommand::noconf = "Could not find crontab file at `1`";
addInitCode::noconf = "Could not find init.m file at `1`";
addInitCode::exists = "Code `1` already exists in init.m file";
initialiseDatabase::nofile = "Could not find sql file at `1`";

(* ::Section:: *)(* End *)
End[];
EndPackage[];
