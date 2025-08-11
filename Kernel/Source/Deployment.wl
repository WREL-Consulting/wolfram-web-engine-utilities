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
(* ::Section:: *)(* DeployWebappRepository *)
(* Description:  Deploys a webapp repository to the Tomcat ROOT webapp directory
 * Return:       True | $Failed
 *)
DeployWebappRepository // Options = {
	"Initialize" -> False
};
DeployWebappRepository[repositoryAssoc_, OptionsPattern[]] := Module[{
		cloneRes, cloneCommand, buildCommand, buildCode, feLoc, cloneLink,
		deployWL, buildLoc, packageJson, wlDeployCommand, localDir,
		log = WWE`LogError["WWE", "DeployWebappRepository", Print[#];#]&,
		init = If[OptionValue["Initialize"],
			" --init",
			""
		]
	},
	Enclose[
		(* Clone in files *)
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
				log["[EXEC]: " <> cloneCommand];
				cloneRes = Run[cloneCommand];
				log["[OUT | git-clone]: " <> ToString[cloneRes]];
				ConfirmAssert[cloneRes === 0, "Clone failed."];
			,
			"paclet",
				localDir = Echo[
					PacletInstall[repositoryAssoc["name"],
						"Site" -> repositoryAssoc["site"],
						ForceVersionInstall -> True
					]["Location"]
				];
			,
			"sftp",
				$Failed (* WIP *)
			,
			_,
				$Failed
		];
		(* Build and deploy the frontend *)
		packageJson = Echo @ getFileAtTopLevel["package.json", localDir];
		feLoc = DirectoryName[packageJson];
		If[!FailureQ[packageJson],
			buildCommand =
				StringRiffle[{
						"cd "<> feLoc,
						"bun install",
						"bun build:wwe"
					},
					"&&"
				];
			log["[EXEC]: " <> buildCommand];
			buildCode = Run[buildCommand];
			log["[OUT | build:wwe] " <> ToString[buildCode]];
			ConfirmAssert[buildCode === 0, "Frontend build failed."];
			buildLoc =
				Cases[
					FileNames["build-wwe", feLoc, 5],
					_String?(Not @* StringContainsQ["node_modules"])
				];
			ConfirmAssert[
				Length[buildLoc] > 0,
				"Could not find build-wwe folder"
			];
			Confirm[
				DeployWebappFrontEnd[
					First[buildLoc],
					repositoryAssoc["prefix"]
				],
				"Frontend deployment failed"
			]
		];
		(* Build and deploy WL backend *)
		deployWL = getFileAtTopLevel["deploy.wwe.wls", localDir];
		If[!FailureQ[deployWL],
			wlDeployCommand = deployWL <> init;
			log["[EXEC]: " <> wlDeployCommand];
			ConfirmAssert[
				Run[ wlDeployCommand ] === 0,
				"Backend build and deploy script failed"
			]
		];
		True
		,(* OnError *)
		Function[e,
			log["[ERROR]: " <> ToString[e]];
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

End[];
EndPackage[];
