(* ::Section:: *)(* Dependencies *)
BeginPackage["WWE`", {
	"DatabaseLink`"
}];
(* ========================================================================== *)
(* ::Section:: *)(* Public Symbols *)
RestartKernelPool::usage = "RestartKernelPool[] restarts the kernel pool by calling the KillAll.jsp endpoint.";
DeployWebappFrontEnd::usage = "DeployWebappFrontEnd[buildDir_, location_ : \"\"] deploys the build files inside `buildDir` to `location` in the Tomcat ROOT webapp directory.";
DeployWebappRepository::usage = "DeployWebappRepository[repositoryAssoc_, OptionsPattern[]] deploys the repository at `repositoryAssoc` to the Tomcat ROOT webapp directory. \nOptions: \n\"InitializeDB\" -> True will initialize the database.";
DeployExpression::usage = "DeployExpression[expr_, location_, OptionsPattern[]] deploys the expression `expr` to the Tomcat ROOT webapp directory at `location`.\nDeployExpression[expr_, OptionsPattern[]] deploys the expression `expr` to the Tomcat ROOT webapp directory at a random UUID endpoint.";
AddWolframInitCode::usage = "AddWolframInitCode[initCode_] adds the initialization code `initCode` to the Wolfram Engine's init.m file.";
WebappDatabaseInitialize::usage = "WebappDatabaseInitialize[sqlFile_] initializes the database using the SQL commands in `sqlFile`.";
WebappDatabaseConnect::usage = "WebappDatabaseConnect[dbName_ : \"\"] creates a connection to the database `dbName`.";
DefineSupervisorCommand::usage = "DefineSupervisorCommand[command_String, name_String] adds a program to the supervisord configuration file.";
DefineCronJob::usage = "DefineCronJob[command_String, cronSpec_String] adds a command to the crontab file with the provided cronSpec.";
LogError::usage = "LogError[appName_String, functionName_String, message_String] logs an event message to the log file /var/log/appName/functionName-error.log.";

(* ::Subsection:: *)(* Aliases *)(* For backwards compatibility *)
deployRepository = DeployWebappRepository;
deployExpression = DeployExpression;
deployBuildFolder = DeployWebappFrontEnd;
initiliseDatabase = WebappDatabaseInitialize;
makeDBConnection = WebappDatabaseConnect;
addSupervisorCommand = DefineSupervisorCommand;
addInitCode = AddWolframInitCode;
addCrontabCommand = DefineCronJob;
logError = LogError;
CommandLineParse = ResourceFunction["CommandLineParse"];
ANSITools = ResourceFunction["ANSITools"];

Begin["`Private`"];
(* ========================================================================== *)
(* ::Section:: *)(* Utility functions *)
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

(* ========================================================================== *)
(* ::Section:: *)(* Main Helper Functions *)
RestartKernelPool[] := Enclose[
	ConfirmAssert[
		URLExecute["http://localhost:8080/jsp/KillAll.jsp", "RawJSON"]["success"],
		"Failed to restart the kernel pool"
	];
	Success["kernel-pool-restart", <|
		"MessageTemplate" -> "Kernel pool restarted successfully"
	|>]
];

logError // Options = {
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

DeployWebappFrontEnd // Options = {
	"WebappLocation" -> "/usr/local/tomcat/webapps/ROOT"
};
DeployWebappFrontEnd[buildDir_, location_String : "", OptionsPattern[]] :=
	Enclose[
		With[{
			deployLoc = FileNameJoin[{
				OptionValue["WebappLocation"], location
			}]
		},
		(* If location doesn't exist, create it *)
		If[!DirectoryQ[deployLoc],
			Print["\033[2m[DeployWebappFrontEnd]:\033[22m Creating directory:", deployLoc];
			Confirm[
				CreateDirectory[deployLoc],
				"Failed to create directory"
			]
		];

		(* Delete any existing duplicate files *)
		If[DirectoryQ[deployLoc],
			Print["\033[2m[DeployWebappFrontEnd]:\033[22m Deleting existing deployment files at ", deployLoc];

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

DeployWebappRepository // Options = {
	"Initialize" -> False
};
DeployWebappRepository[repositoryAssoc_, OptionsPattern[]] := Module[{
		cloneCommand, cloneCode, buildCommand, buildCode, feLoc, outputLogLoc,
		outputLog, ret, deployWL, errorlog, log, logDir, buildLoc, packageJson,
		cloneLink = repositoryAssoc["link"],
		localDir = repositoryAssoc["local"],
		init = If[OptionValue["Initialize"],
			" --init",
			""
		]
	},

	(* Define logging function *)
	log = Function[
		BinaryWrite[outputLog, Print["\033[2m[DeployWebappRepository]:\033[22m ", #]; ToString[#] <> "\n"];
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
			packageJson = getFileAtTopLevel["package.json", localDir];
			feLoc = DirectoryName[packageJson];
			If[!FailureQ[packageJson],
				(* Define frontend build command *)

				buildCommand = StringRiffle[{
						"cd "<> feLoc,
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
				buildLoc = Cases[
					FileNames["build-wwe", feLoc, 5],
					_String?(Not @* StringContainsQ["node_modules"])
				];
				ConfirmAssert[
					Length[buildLoc] > 0,
					"Could not find build-wwe folder"
				];
				Confirm[#, "Frontend deployment failed"]& @
					DeployWebappFrontEnd[
						First[buildLoc],
						repositoryAssoc["prefix"]
					];
			];

			(* Deploy WL backend using project's deploy.wwe.wls script *)
			deployWL = getFileAtTopLevel["deploy.wwe.wls", localDir];
			If[!FailureQ[deployWL],
				ConfirmAssert[
					log["Running 'wolframscript -script "<> deployWL <> init <> "'"];
					Run[
						"wolframscript -script "<> deployWL <>init<>" >> '"<>outputLogLoc<>"' 2>&1"
					] === 0,
					"'" <> deployWL <> "' returned a nonzero code"
				]
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

DeployExpression // Options = {
	OverwriteTarget -> True,
	"WebappLocation" -> "/usr/local/tomcat/webapps/ROOT",
	"ActiveExtension" -> "wl"
};
DeployExpression[expr_, location_String : Automatic, OptionsPattern[]] :=
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

(* ========================================================================== *)
(* ::Section:: *)(* Database Helper Functions *)
WebappDatabaseInitialize::nofile = "Could not find sql file at `1`";
WebappDatabaseInitialize // Options = {
	"RootPassword" -> SystemCredential["db-pass"],
	"DatabasePassword" -> SystemCredential["db-pass"],
	"Port" -> 3306,
	"BaseURL" -> "mariadb",
	"TemplateParameters" -> <||>
};
WebappDatabaseInitialize[sqlFile_String, OptionsPattern[]]:= Enclose[
	Module[{con, sqlCommands},

		If[FileExistsQ[sqlFile] === False,
			Message[WebappDatabaseInitialize::nofile, sqlFile];
			Return[$Failed]
		];

		Needs["DatabaseLink`"];

		WithCleanup[
			con = Confirm[
					OpenSQLConnection[
					JDBC["MySQL(Connector/J)",
						StringTemplate["`url`:`port`"][
						<|
							"url" -> OptionValue["BaseURL"],
							"port" -> OptionValue["Port"]
						|>
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
				"db-pass" -> OptionValue["DatabasePassword"],
				OptionValue["TemplateParameters"]
			|>] // StringSplit[#, ";"]&;

			Confirm[
				SQLExecute[con, #],
				"Error while executing SQL command: "<>#
			]& /@ sqlCommands
			,
			CloseSQLConnection[con];
		]

	]
];

WebappDatabaseConnect // Options = {
	"Port" -> 3306,
	"Username" -> "admin",
	"Password" -> SystemCredential["db-pass"],
	"UseConnectionPool" -> True,
	"BaseURL" -> "mariadb"
};
WebappDatabaseConnect[dbName_String : "", OptionsPattern[]]:= Enclose[
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

(* ========================================================================== *)
(* ::Section:: *)(* End *)
End[];
EndPackage[];
