BeginPackage["WWE`FileScope`Deployment`", {
	"WWE`",
	"WWE`Private`"
}];
Begin["`Private`"];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployWebappFrontEnd *)
(* Description:  Deploys the webapp frontend to the specified location
 * Return:       _ServiceDeployment | $Failed
 *)
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

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* getFileAtTopLevel *)
(* Description:  Gets a file at the top level of a directory
 * Return:       _String | $Failed
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
(* ::Section:: *)(* DeployWebappRepository *)
(* Description:  Deploys a webapp repository to the Tomcat ROOT webapp directory
 * Return:       True | $Failed
 *)
DeployWebappRepository // Options = {
	"Initialize" -> False
};
DeployWebappRepository[repositoryAssoc_, OptionsPattern[]] := Module[{
		cloneRes, cloneCommand, buildCommand, buildCode, feLoc, outputLogLoc,
		ret, deployWL, errorlog, buildLoc, packageJson,
		cloneLink = repositoryAssoc["link"],
		localDir = repositoryAssoc["local"],
		log = WWE`LogError["WWE", "DeployWebappRepository", Print[#];#]&,
		init = If[OptionValue["Initialize"],
			" --init",
			""
		]
	},
	ret = Enclose[
		(* Clone in files *)
		Switch[repositoryAssoc["type"],
			"git",
				cloneCommand = StringRiffle[{
					"/scripts/git-clone.sh",
						cloneLink,
						localDir,
						repositoryAssoc["branch"],
					">> '"<>outputLogLoc<>"' 2>&1"
				}];
				log["[INFO]: Running " <> cloneCommand];
				cloneRes = Run[cloneCommand];
				log["[OUT | git-clone]: " <> ToString[cloneRes]];
				ConfirmAssert[cloneRes === 0, "Clone failed."];
			,
			"paclet",
				localDir = ParentDirectory @ Confirm[
					First[
						ExtractArchive[cloneLink, "/contents"],
						$Failed
					],
					"Failed to extract paclet archive"
				],
			"sftp",
				$Failed (* WIP *)
			,
			_,
				$Failed
		];
		(* Build and deploy the frontend *)
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
		(* Deploy backend using project's deploy.wwe.wls script *)
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

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployExpression *)
(* Description:  Deploys an expression to the Tomcat ROOT webapp directory
 * Return:       _ServiceDeployment | $Failed
 *)
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
		ServiceDeployment[<|
			"Name" -> "WolframWebEngine",
			"Resource" -> deployment,
			"URL" -> FileNameJoin[{"/",loc}]
		|>]
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

End[];
EndPackage[];
