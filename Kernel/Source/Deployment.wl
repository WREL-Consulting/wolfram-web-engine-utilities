BeginPackage["WWE`FileScope`Deployment`", {
	"WWE`",
	"WWE`Private`"
}];
Begin["`Private`"];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployWebapps *)
(* Description:  Deploys webapps defined in a WWE webapp manifest file
 * Return:       _Success | _Failure
 *)
DeployWebapps // Options = {
	"Manifest" -> "/deployment/webapps-manifest.m",
	"LogLabel" -> "[DeployWebapps]: ",
	"Initialize" -> False,
	"DeployFrontend" -> True,
	"DeployBackend" -> True
};
DeployWebapps[OptionsPattern[]] := Module[{
		repos,
		init = OptionValue["Initialize"],
		printInfo = Print[
			ANSITools["Style", OptionValue["LogLabel"],
				Gray
			] <>
			#
		]&,
		printSucc = Print[
			ANSITools["Style", OptionValue["LogLabel"],
				Gray
			] <>
			ANSITools["Style", #, Green]
		]&,
		printFail = Print[
			ANSITools["Style", OptionValue["LogLabel"], Red] <>
			ANSITools["Style", #, Red]
		]&
	},
	Enclose[
		printInfo[ "Importing repositories association..." ];
		repos = Confirm @ Import[ OptionValue["Manifest"] ];

		printInfo[ "Deploying repositories..." ];
		Confirm[#, #["Information"]]& @ Map[
			DeployWebappRepository[#,
				"Initialize" -> init,
				"DeployFrontend" -> OptionValue["DeployFrontend"],
				"DeployBackend"  -> OptionValue["DeployBackend"]
			]&,
			repos
		];

		printInfo[ "Restarting kernel pool..." ];
		RestartKernelPool[];

		printSucc["Deployment successful"];
		Success["Deployment successful", <|
			"MessageTemplate" -> "Deployment successful"
		|>]
		,(* OnError *)
		Function[e,
			printFail[ "Deployment failed" ];
			WriteString["stderr", e["Information"], "\n"];
			Exit[1]
		]
	]
];


(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployWebappRepository *)
(* Description:  Deploys a webapp repository to the Tomcat ROOT webapp directory
 * Return:       _Success | _Failure
 *)
DeployWebappRepository // Options = {
	"Initialize" -> False,
	"DeployFrontend" -> True,
	"DeployBackend" -> True
};
DeployWebappRepository[repositoryAssoc_, OptionsPattern[]] := Module[{
		deployWL, buildLoc, packageJson, localDir, feLoc,
		log = WWE`LogError["WWE", "DeployWebappRepository", Print[#];#]&,
		init = If[OptionValue["Initialize"],
			" --init",
			""
		]
	},
	Enclose[
		(* Clone in files *)
		localDir = Confirm[
			CloneWebappRepository[repositoryAssoc]
		];
		(* Build and deploy the frontend *)
		packageJson = getFileAtTopLevel["package.json", localDir];
		feLoc = DirectoryName[packageJson];
		If[ And[
				!FailureQ[packageJson],
				!MissingQ[Import[packageJson, "RawJSON"]["scripts"]],
				OptionValue["DeployFrontend"]
			],
			Confirm @
			DeployWebappFrontEnd[
				feLoc,
				repositoryAssoc["prefix"]
			]

		];
		(* Build and deploy WL backend *)
		deployWL = getFileAtTopLevel["deploy.wwe.wls", localDir];
		If[ And[
				!FailureQ[deployWL],
				OptionValue["DeployBackend"]
			],
			Confirm @
			DeployWebappBackend[deployWL, "Initialize" -> init]
		];
		Success["repository-deploy-success", repositoryAssoc]
		,(* OnError *)
		Function[e,
			log[WWE`ANSITools["Style", "[ERROR]: ", Red] <> ToString[e]];
			e
		]
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
(* ::Section:: *)(* DeployWebappFrontEnd *)
(* Description:  Deploys the webapp frontend to the specified location
 * Return:       True | False
 *)
DeployWebappFrontEnd // Options = {
	"WebappLocation" -> "/usr/local/tomcat/webapps/ROOT"
};
DeployWebappFrontEnd[feLoc_, location_String : "", OptionsPattern[]] :=
	Enclose[
		Block[{ buildCode, buildLoc,
			log = WWE`LogError["WWE", "DeployWebappFrontEnd", Print[#];#]&,
			buildCommand =
				StringRiffle[{
						"cd "<> feLoc,
						"bun install",
						"bun build:wwe"
					},
					"&&"
				],
			deployLoc = FileNameJoin[{
				OptionValue["WebappLocation"], location
			}],
			printInfo = Print[
				WWE`ANSITools["Style", "[DeployWebaapFrontEnd]: ", Gray]<>
				##
			]&
		},
		(* Run build command *)
		ConfirmAssert[
			log[WWE`ANSITools["Style", "[EXEC]: ", Blue] <> buildCommand];
			buildCode = Run[buildCommand];
			log[WWE`ANSITools["Style", "[OUT | build:wwe]: ", Magenta] <> ToString[buildCode]];
			buildCode === 0
			,
			"Frontend build failed."
		];
		(* Find built files *)
		ConfirmAssert[
			buildLoc = First[
				Cases[
					FileNames["build-wwe", feLoc, 5],
					_String?(Not @* StringContainsQ["node_modules"])
				],
				None
			];
			StringQ[buildLoc]
			,
			"Could not find build-wwe folder"
		];
		(* If deploy location doesn't exist, create it *)
		If[Not @ DirectoryQ[deployLoc],
			Confirm[
				printInfo["Creating directory '", deployLoc, "'"];
				CreateDirectory[deployLoc],
				"Failed to create directory"
			]
		];
		(* Delete any existing duplicate files *)
		If[DirectoryQ[deployLoc],
			printInfo["Deleting existing deployment files at ", deployLoc];
			With[{ existingFile = FileNameJoin[{ deployLoc, # }] },
				If[FileExistsQ[existingFile],
					If[DirectoryQ[existingFile],
						DeleteDirectory[#, DeleteContents -> True]&,
						DeleteFile
					][existingFile]
				]
			]& /@ StringDelete[
				(* Select all file names in the build folder *)
				FileNames[
					loc: (StartOfString~~__~~EndOfString) /; (
						(* Ignore directories *)
						Not[ DirectoryQ @ FileNameJoin[{buildLoc, loc}] ]
					),
					buildLoc,
					Infinity
				],
				buildLoc
			]
		];
		(* Copy the contents of the build folder to the deploy location *)
		ConfirmAssert[
			Run[
				StringTemplate["cp -r `1`/* `2`"][buildLoc, deployLoc]
			] === 0,
			"Failed to copy build files"
		]
	]
];


(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployWebappBackend *)
(* Description:  Runs the wolfram deploy.wwe.wls script
 * Return:       True | False
 *)
DeployWebappBackend // Options = {
	"Initialize" -> False
};
DeployWebappBackend[deployScriptLoc_String, OptionsPattern[]] := Module[{
		buildCode, wlDeployCommand,
		init = OptionValue["Initialize"],
		log = WWE`LogError["WWE", "DeployWebappBackend", Print[#];#]&
	},
	Enclose[
		wlDeployCommand = deployScriptLoc <> init;
		log[WWE`ANSITools["Style", "[EXEC]: ", Blue] <> wlDeployCommand];
		(* Execute through wolframscript to avoid permission issues *)
		buildCode = Run["wolframscript -script " <> wlDeployCommand];
		log[WWE`ANSITools["Style", "[OUT | build:wwe]: ", Magenta] <> ToString[buildCode]];
		ConfirmAssert[
			buildCode === 0,
			"Backend build and deploy script failed"
		]
	]
]


(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* CloneWebappRepository *)
(* Description:  Clones the repositories from the repo assoc
 * Return:       _String | _Failure
 *)
CloneWebappRepository // Options = {

};
CloneWebappRepository[repositoryAssoc_, OptionsPattern[]] := Module[{
		log = WWE`LogError["WWE", "CloneWebappRepository", Print[#];#]&,
		cloneLink, localDir,
		cloneCommand, cloneRes
	},
	Enclose[
		Switch[repositoryAssoc["type"],
			"git",
				cloneLink = repositoryAssoc["remote"];
				localDir = repositoryAssoc["local"];
				cloneCommand = StringRiffle[{
					"/scripts/git-clone",
						cloneLink,
						localDir,
						repositoryAssoc["branch"]
				}];
				log[WWE`ANSITools["Style", "[EXEC]: ", Blue] <> cloneCommand];
				cloneRes = Run[cloneCommand];
				log[WWE`ANSITools["Style", "[OUT | git-clone]: ", Magenta] <> ToString[cloneRes]];
				ConfirmAssert[cloneRes === 0, "Clone failed."];
			,
			"site:paclet",
				PacletUninstall[ repositoryAssoc["name"] ];
				localDir =
					PacletInstall[repositoryAssoc["name"],
						PacletSite -> repositoryAssoc["site"],
						ForceVersionInstall -> True
					]["Location"];
			,
			"url:paclet",
				PacletUninstall[ repositoryAssoc["name"] ];
				localDir =
					PacletInstall[ repositoryAssoc["remote"] ]["Location"];
			,
			"sftp",
				$Failed (* WIP *)
			,
			_,
				$Failed
		];
		localDir
	]
];


End[];
EndPackage[];
