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
		printInfo = WWE`Logger["INFO", "WWE", "DeployWebapps", #]&,
		printSucc = WWE`Logger["SUCC", "WWE", "DeployWebapps", #]&,
		printFail = WWE`Logger["ERROR","WWE", "DeployWebapps", #]&
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
		deployWL, packageJson, localDir, feLoc,
		init = If[OptionValue["Initialize"],
			" --init",
			""
		]
	},
	Enclose[
		(* Clone in files *)
		Confirm[
			localDir = CloneWebappRepository[repositoryAssoc]
		];

		(* Build and deploy the frontend *)
		If[ OptionValue["DeployFrontend"],
			packageJson = getFileAtTopLevel["package.json", localDir];
			feLoc = If[ StringQ[packageJson],
				DirectoryName[packageJson],
				WWE`Logger["WARN", "WWE", "DeployWebappRepository",
					"No package.json"
				]
			];
			If[ And[
					StringQ[packageJson],
					!MissingQ[Import[packageJson, "RawJSON"]["scripts"]]
				],
				Confirm @
				DeployWebappFrontEnd[
					feLoc,
					repositoryAssoc["prefix"]
				]

			]
		];

		(* Build and deploy WL backend *)
		If[ OptionValue["DeployBackend"],
			deployWL = getFileAtTopLevel["deploy.wwe.wls", localDir];
			If[ StringQ[deployWL],
				Confirm @
				DeployWebappBackend[deployWL, "Initialize" -> init],
				WWE`Logger["WARN", "WWE", "DeployWebappRepository",
					"No deploy.wwe.wls"
				]
			]
		];
		Success["repository-deploy-success", repositoryAssoc]
		,(* OnError *)
		Function[e,
			WWE`Logger["ERROR", "WWE", "DeployWebappRepository", ToString[e]];
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
			log = WWE`Logger["IFNO", "WWE", "DeployWebappFrontEnd", #]&,
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
			}]
		},
		(* Run build command *)
		ConfirmAssert[
			WWE`Logger["EXEC", "WWE", "DeployWebappFrontend", buildCommand];
			buildCode = Run[buildCommand];
			WWE`Logger["OUT", "WWE", "DeployWebappFrontend", ToString[buildCode]];
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
				log["Creating directory '", deployLoc, "'"];
				CreateDirectory[deployLoc],
				"Failed to create directory"
			]
		];
		(* Delete any existing duplicate files *)
		If[DirectoryQ[deployLoc],
			log["Deleting existing deployment files at ", deployLoc];
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
					loc: (StartOfString ~~ __ ~~ EndOfString) /; (
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
		init = OptionValue["Initialize"]
	},
	Enclose[
		wlDeployCommand = deployScriptLoc <> init;
		WWE`Logger["EXEC", "WWE", "DeployWebappBackend", wlDeployCommand];
		(* Execute through wolframscript to avoid permission issues *)
		buildCode = Run["wolframscript -script " <> wlDeployCommand];
		WWE`Logger["OUT", "WWE", "DeployWebappBackend", ToString[buildCode]];
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
		log = WWE`Logger["INFO", "WWE", "CloneWebappRepository", #]&
	},
	Switch[repositoryAssoc["type"],
		"git",
			log[
				"Cloning git repository '" <>
				repositoryAssoc["remote"] <>
				"' to '" <>
				repositoryAssoc["local"] <>
				"'"
			];
			gitClone[
				repositoryAssoc["remote"],
				repositoryAssoc["local"],
				repositoryAssoc["branch"]
			]
		,
		"site:paclet",
			log[
				"Cloning paclet '" <>
				repositoryAssoc["name"] <>
				"' from paclet site '" <>
				repositoryAssoc["site"] <>
				"'"
			];
			siteClone[
				repositoryAssoc["name"],
				repositoryAssoc["site"]
			]
		,
		"url:paclet",
			log[
				"Cloning paclet '" <>
				repositoryAssoc["name"] <>
				"' from URL '" <>
				repositoryAssoc["remote"] <>
				"'"
			];
		,
		"sftp",
			$Failed (* WIP *)
		,
		_,
			$Failed
	]
];

pacletClone[name_String, remote_String] :=
	Enclose[
		Quiet @ PacletUninstall[ name ];
		Confirm[
			PacletInstall[
				Replace[remote,
					s_String?(StringStartsQ["cloudobject://"]) :>
						CloudObject[s // StringDelete[StartOfString ~~ "cloudobject://"]]
				]
			],
			"Failed to install paclet " <> name <> " remote " <> remote
		]["Location"]
	];

siteClone[name_String, site_String] :=
	Enclose[
		Quiet @ PacletUninstall[ name ];
		Confirm[
			PacletInstall[name,
				PacletSite -> site,
				ForceVersionInstall -> True
			],
			"Failed to install paclet " <> name <> " from site " <> site
		]["Location"]
	];

gitClone[link_String, localDir_String, branch_String] :=
	Block[{
			cloneRes,
			cloneCommand = StringRiffle[{
				"/scripts/git-clone",
					link,
					localDir,
					branch
			}]
		},
		Enclose[
			WWE`Logger["EXEC", "WWE", "gitClone", cloneCommand];
			cloneRes = Run[cloneCommand];
			WWE`Logger["OUT", "WWE", "gitClone", ToString[cloneRes]];
			ConfirmAssert[cloneRes === 0, "Clone failed."];
			localDir
		]
	];

End[];
EndPackage[];
