1  (* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
BeginPackage["WWE`FileScope`Deployment`", {"WWE`", "WWE`Private`"}];
Begin["`Private`"];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* importWebappsManifest *)
(* Description:  Import the webapp manifest or attempt to find it
 *               automatically in the deployment directory
 * Return:       { ___Association } | _Failure
 *)
importWebappsManifest[manifest : (_String | Automatic) : Automatic] :=
	Module[{path},
		Enclose[
			path =
				If[manifest === Automatic,
					Confirm[
						First[
							FileNames[
								"webapps-manifest." ~~
								("m" | "wl" | "json" | "yaml" | "yml"),
								"/deployment"
							],
							$Failed
						],
						"Could not find manifest file in deployment directory"
					],
					manifest
				];
			ConfirmMatch[
				Replace[
					path,
					{
						p_String?(StringEndsQ[#, ".yml" | ".yaml"]&) :> Import[
							p,
							"YAML"
						][
							"webapps"
						],
						p_String?(StringEndsQ[#, ".json"]&)          :> Import[
							p,
							"RawJSON"
						][
							"webapps"
						],
						p_String?(StringEndsQ[#, ".m" | ".wl"]&)     :> Import[
							p,
							"WL"
						],
						Except[_String]                              :> (
							Return[
								Failure[
									"InvalidManifest",
									<|
										"Information" ->
											StringJoin[
												"Manifest file must be .json, ",
												".m, or .wl"
											]
									|>
								]
							]
						)
					}
				],
				{___Association},
				"Failed to parse WL manifest"
			]
		]
	];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployWebapps *)
(* Description:  Deploys webapps defined in a WWE webapp manifest file
 * Return:       _Success | _Failure
 *)
DeployWebapps // Options =
	{
		"Manifest"       -> Automatic,
		"LogLabel"       -> "[DeployWebapps]: ",
		"Initialize"     -> False,
		"DeployFrontend" -> True,
		"DeployBackend"  -> True
	};
DeployWebapps[OptionsPattern[]] :=
	Module[{
			repos,
			init = OptionValue["Initialize"],
			printInfo = WWE`Logger["INFO", "WWE", "DeployWebapps", #]&,
			printSucc = WWE`Logger["SUCC", "WWE", "DeployWebapps", #]&,
			printFail = WWE`Logger["FAIL", "WWE", "DeployWebapps", #]&,
			printMsg = WWE`Logger["MESG", "WWE", "DeployWebapps", #]&
		},
		Enclose[
			Print[
				WWE`ANSITools["Style", Bold, Green] @
				"\nWREL WWE Deployment Tools"
			];
			Print[
				StringJoin[
					WWE`ANSITools["Style", Bold, Green][" - Repo version:   "],
					WWE`ANSITools["Style", Underlined, LightBlue][
						StringDelete[
							StringJoin[
								RunProcess[
									{
										"git",
										"rev-parse",
										"--abbrev-ref",
										"HEAD"
									},
									"StandardOutput",
									ProcessDirectory -> PacletObject["WWE"][
										"Location"
									]
								],
								":",
								RunProcess[
									{
										"git",
										"show",
										"--pretty=format:%s",
										"-s",
										"HEAD"
									},
									"StandardOutput",
									ProcessDirectory -> PacletObject["WWE"][
										"Location"
									]
								]
							],
							"\n"
						]
					]
				]
			];
			Print[""];
			Pause[0.01];
			printInfo["Importing webapps manifest..."];
			repos = Confirm @ importWebappsManifest[OptionValue["Manifest"]];
			printInfo["Deploying repositories..."];
			Map[
				Function[
					Print[StringJoin[ "\n", Table["_", 80]]];
					Print[
						WWE`ANSITools["Style", Bold] @
						Which[
							StringQ @ #["name"],
								#["name"],
							StringQ @ #["remote"],
								#["remote"],
							StringQ @ #["local"],
								#["local"],
							True,
								"NAME NOT FOUND"
						]
					];
					Pause[0.01];
					ResourceFunction["WithMessageHandler"][
						Confirm @
						DeployWebappRepository[
							#,
							"Initialize"     -> init,
							"DeployFrontend" -> OptionValue["DeployFrontend"],
							"DeployBackend"  -> OptionValue["DeployBackend"]
						],
						printMsg[
							StringJoin[ #["Information"], " | ", #["Tag"]]
						]&
					]
				],
				repos
			];
			(* Print closer separator *)
			Print[StringJoin[ "\n", Table["_", 80]]];
			Pause[0.01];
			printInfo["Restarting kernel pool..."];
			RestartKernelPool[];
			printSucc["Deployment successful"];
			Success[
				"Deployment successful",
				<|"MessageTemplate" -> "Deployment successful"|>
			],
			(* OnError *)
			Function[
				e,
				printFail["Deployment failed"];
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
DeployWebappRepository // Options =
	{"Initialize" -> False, "DeployFrontend" -> True, "DeployBackend" -> True};
DeployWebappRepository[repositoryAssoc_, OptionsPattern[]] :=
	Module[{
			deployWL,
			packageJson,
			localDir,
			feLoc,
			init = If[OptionValue["Initialize"], " --init", ""]
		},
		Enclose[
			(* Clone in files *)
			Confirm[localDir = CloneWebappRepository[repositoryAssoc]];
			(* Build and deploy the frontend *)
			If[OptionValue["DeployFrontend"],
				packageJson = getFileAtTopLevel["package.json", localDir];
				feLoc =
					If[StringQ[packageJson],
						DirectoryName[packageJson],
						WWE`Logger[
							"WARN",
							"WWE",
							"DeployWebappRepository",
							"No package.json"
						]
					];
				Which[
					Not @ StringQ[packageJson],
						WWE`Logger[
							"WARN",
							"WWE",
							"DeployWebappRepository",
							"No package.json found"
						],
					MissingQ[
						Import[packageJson, "RawJSON"]["scripts", "build:wwe"]
					],
						WWE`Logger[
							"WARN",
							"WWE",
							"DeployWebappRepository",
							StringJoin[ "No build:wwe script in ", packageJson]
						],
					True,
						Confirm @
						DeployWebappFrontEnd[feLoc, repositoryAssoc["prefix"]]
				],
				WWE`Logger[
					"WARN",
					"WWE",
					"DeployWebappRepository",
					"Frontend deployment disabled"
				]
			];
			(* Build and deploy WL backend *)
			If[OptionValue["DeployBackend"],
				deployWL = getFileAtTopLevel["deploy.wwe.wls", localDir];
				If[StringQ[deployWL],
					Confirm @
					DeployWebappBackend[deployWL, "Initialize" -> init],
					WWE`Logger[
						"WARN",
						"WWE",
						"DeployWebappRepository",
						"No deploy.wwe.wls found"
					]
				],
				WWE`Logger[
					"WARN",
					"WWE",
					"DeployWebappRepository",
					"Backend deployment disabled"
				]
			];
			Success["repository-deploy-success", repositoryAssoc],
			(* OnError *)
			Function[
				e,
				WWE`Logger[
					"FAIL",
					"WWE",
					"DeployWebappRepository",
					ToString[e]
				];
				e
			]
		]
	];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployExpression *)
(* Description:  Deploys an expression to the Tomcat ROOT webapp directory
 * Return:       _ServiceDeployment | $Failed
 *)
DeployExpression // Options =
	{
		OverwriteTarget   -> True,
		"WebappLocation"  -> "/usr/local/tomcat/webapps/ROOT",
		"ActiveExtension" -> "wl"
	};
DeployExpression[expr_, location_String : Automatic, OptionsPattern[]] :=
	Module[{
			dir,
			deployment,
			loc = location /. Automatic -> CreateUUID[]
		},
		Enclose[
			dir =
				FileNameJoin[
					{
						OptionValue["WebappLocation"],
						OptionValue["ActiveExtension"],
						loc
					}
				];
			(* Create directory id it doesn't exist *)
			If[!DirectoryQ[dir],
				Confirm[
					CreateDirectory[dir, CreateIntermediateDirectories -> True],
					"Failed to create directory"
				]
			];
			(* Export main index file *)
			deployment =
				Confirm[
					Export[
						FileNameJoin[{dir, "index.wl"}],
						expr,
						"WL",
						OverwriteTarget -> OptionValue[OverwriteTarget]
					],
					"Failed to export index.wl"
				];
			ServiceDeployment[
				<|
					"Name"     -> "WolframWebEngine",
					"Resource" -> deployment,
					"URL"      -> FileNameJoin[{"/", loc}]
				|>
			]
		]
	];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployRouteMap *)
(* Description:  Deploys a route map assciation
 * Return:       _Success | _Failure
 *)
DeployRouteMap[apiMap_Association] := DeployRouteMap[apiMap, "", ""];
DeployRouteMap[apiMap_Association, base_String] :=
	DeployRouteMap[apiMap, base, ""];
DeployRouteMap[apiMap_Association, base_String, acc_String] :=
	KeyValueMap[
		Function[{k, v}, DeployRouteMap[v, base, URLBuild[{acc, k}]]],
		apiMap
	];
DeployRouteMap[expr : Except[_Association], base_String, acc_String] :=
	DeployExpression[expr, URLBuild[{base, acc}]];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployWebappFrontEnd *)
(* Description:  Deploys the webapp frontend to the specified location
 * Return:       True | False
 *)
DeployWebappFrontEnd // Options =
	{"WebappLocation" -> "/usr/local/tomcat/webapps/ROOT"};
DeployWebappFrontEnd[feLoc_, location_String : "", OptionsPattern[]] :=
	Enclose[
		Block[{
				buildCode,
				buildLoc,
				log = WWE`Logger["INFO", "WWE", "DeployWebappFrontEnd", #]&,
				buildCommand =
					StringRiffle[
						{
							StringJoin[ "cd ", feLoc],
							"bun install",
							"bun build:wwe"
						},
						"&&"
					],
				deployLoc =
					FileNameJoin[{OptionValue["WebappLocation"], location}]
			},
			Print["\n - Deploying Frontend - \n"];
			Pause[0.01];
			(* Run build command *)
			ConfirmAssert[
				WWE`Logger["EXEC", "WWE", "DeployWebappFrontend", buildCommand];
				buildCode = Run[buildCommand];
				WWE`Logger[
					"OUT",
					"WWE",
					"DeployWebappFrontend",
					ToString[buildCode]
				];
				buildCode === 0,
				"Frontend build failed."
			];
			(* Find built files *)
			ConfirmAssert[
				buildLoc =
					First[
						Cases[
							FileNames["build-wwe", feLoc, 5],
							_String?(Not @* StringContainsQ["node_modules"])
						],
						None
					];
				StringQ[buildLoc],
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
				With[{
						existingFile = FileNameJoin[{deployLoc, #}]
					},
					If[FileExistsQ[existingFile],
						If[DirectoryQ[existingFile],
							DeleteDirectory[#, DeleteContents -> True]&,
							DeleteFile
						][
							existingFile
						]
					]
				]& /@ StringDelete[
					(* Select all file names in the build folder *)
					FileNames[
						loc : (StartOfString ~~ __ ~~ EndOfString) /;
							(
								(* Ignore directories *)
								Not[DirectoryQ @ FileNameJoin[{buildLoc, loc}]]
							),
						buildLoc,
						Infinity
					],
					buildLoc
				]
			];
			(* Copy the contents of the build folder to the deploy location *)
			ConfirmAssert[
				Run[StringTemplate["cp -r `1`/* `2`"][buildLoc, deployLoc]] ===
				0,
				"Failed to copy build files"
			]
		]
	];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* DeployWebappBackend *)
(* Description:  Runs the wolfram deploy.wwe.wls script
 * Return:       True | False
 *)
DeployWebappBackend // Options = {"Initialize" -> False};
DeployWebappBackend[deployScriptLoc_String, OptionsPattern[]] :=
	Enclose[
		Print["\n - Deploying Backend - \n"];
		Pause[0.01];
		WWE`Logger["EXEC", "WWE", "DeployWebappBackend", deployScriptLoc];
		(* Execute using Get to run in same kernel for Message handling *)
		(*Block[{
				$EvaluationEnvironment = "Script",
				$ScriptCommandLine = {deployScriptLoc}
			},*)
		Confirm @ Get[deployScriptLoc]
		(*];*)
	];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* CloneWebappRepository *)
(* Description:  Clones the repositories from the repo assoc
 * Return:       _String | _Failure
 *)
CloneWebappRepository // Options = {};
CloneWebappRepository[repositoryAssoc_, OptionsPattern[]] :=
	Module[{log = WWE`Logger["INFO", "WWE", "CloneWebappRepository", #]&},
		Enclose[
			Print["\n - Cloning files -\n"];
			Pause[0.01];
			Switch[repositoryAssoc["type"],
				"git",
					log[
						StringJoin[
							"Cloning git repository '",
							repositoryAssoc["remote"],
							"' to '",
							repositoryAssoc["local"],
							"'"
						]
					];
					gitClone[
						repositoryAssoc["remote"],
						repositoryAssoc["local"],
						repositoryAssoc["branch"]
					],
				"site:paclet",
					log[
						StringJoin[
							"Cloning paclet '",
							repositoryAssoc["name"],
							"' from paclet site '",
							repositoryAssoc["site"],
							"'"
						]
					];
					siteClone[repositoryAssoc["name"], repositoryAssoc["site"]],
				"url:paclet",
					log[
						StringJoin[
							"Cloning paclet '",
							repositoryAssoc["name"],
							"' from URL '",
							repositoryAssoc["remote"],
							"'"
						]
					];
					pacletClone[
						repositoryAssoc["name"],
						repositoryAssoc["remote"]
					],
				"site:archive",
					log[
						StringJoin[
							"Cloning zip archive from '",
							repositoryAssoc["remote"],
							"' to '",
							repositoryAssoc["local"],
							"'"
						]
					];
					archiveSiteClone[
						repositoryAssoc["remote"],
						repositoryAssoc["local"]
					],
				"url:archive",
					log[
						StringJoin[
							"Cloning zip archive from '",
							repositoryAssoc["remote"],
							"' to '",
							repositoryAssoc["local"],
							"'"
						]
					];
					archiveClone[
						repositoryAssoc["remote"],
						repositoryAssoc["local"]
					],
				"file",
					log[
						StringJoin[
							"Files exists at '",
							repositoryAssoc["local"],
							"'"
						]
					];
					repositoryAssoc["local"],
				_,
					$Failed
			]
		]
	];

archiveSiteClone[url_String, localDir_String] :=
	Module[{
			versionMap,
			versions,
			files,
			latest,
			archiveFormats =
				{
					"*.zip",
					"*.tar",
					"*.gz",
					"*.tgz",
					"*.bz2",
					"*.tbz2",
					"*.zst",
					"*.7z",
					"*.rar",
					"*.iso"
				}
		},
		Enclose[
			files = FileNames[archiveFormats, url, 1];
			versions = StringExtract[FileNameTake[#], "__" -> 2]& /@ files;
			latest =
				Last @
				SortBy[
					versionMap,
					Function[
						With[{
								v = StringExtract[FileNameTake[#], "__" -> 2]
							},
							-Total[
								ResourceFunction["VersionOrder"][
									v,
									#
								]& /@ versions
							]
						]
					]
				];
			ConfirmMatch[
				ExtractArchive[url, localDir, OverwriteTarget -> True],
				_String,
				"Failed to extract archive"
			];
			localDir
		]
	]

archiveClone[url_String, localDir_String] :=
	Enclose[
		(* Create local directory if it doesn't exist *)
		If[!DirectoryQ[localDir],
			Confirm[
				CreateDirectory[
					localDir,
					CreateIntermediateDirectories -> True
				],
				"Failed to create directory"
			]
		];
		(* Download and unzip the file *)
		Confirm[
			ExtractArchive[URL[url], localDir],
			"Failed to download and extract archive"
		];
		localDir
	];

pacletClone[name_String, remote : (_String | _CloudObject)] :=
	Enclose[
		Quiet @ PacletUninstall[name];
		Confirm[
			PacletInstall[
				Replace[
					remote,
					s_String?(StringStartsQ["cloudobject://"]) :> CloudObject[
						s // StringDelete[StartOfString ~~ "cloudobject://"]
					]
				],
				ForceVersionInstall -> True
			],
			StringJoin[ "Failed to install paclet ", name, " remote ", remote]
		][
			"Location"
		]
	];

siteClone[name_String, site_String] :=
	Enclose[
		Quiet @ PacletUninstall[name];
		Confirm[
			PacletInstall[
				name,
				PacletSite          -> site,
				ForceVersionInstall -> True
			],
			StringJoin[ "Failed to install paclet ", name, " from site ", site]
		][
			"Location"
		]
	];

gitClone[link_String, localDir_String, branch_String] :=
	Block[{
			cloneRes,
			cloneCommand =
				StringRiffle[{"/scripts/git-clone", link, localDir, branch}]
		},
		Enclose[
			WWE`Logger["EXEC", "WWE", "gitClone", cloneCommand];
			cloneRes = Run[cloneCommand];
			WWE`Logger["OUT", "WWE", "gitClone", ToString[cloneRes]];
			ConfirmAssert[cloneRes === 0, "Clone failed."];
			localDir
		]
	];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* ContinuousDeploymentWebhookHandler *)
(* Description:  Handles incoming webhook requests from either Stash or GitHub
 *               redeploying the tracked branch inside webapps-manifest.m if a
 *               branch is merged into it
 * Return:       _HTTPResponse | _Failure
 *)
ContinuousDeploymentWebhookHandler[] :=
	Module[{
			ret,
			httpBodyIn,
			httpHeadersIn,
			log =
				WWE`Logger[
					"INFO",
					"WWE",
					"ContinuousDeploymentWebhookHandler",
					#
				]&
		},
		Enclose[
			(* Log incoming request *)
			log[ToString @ HTTPRequestData[]];
			(* Parse HTTP request *)
			ConfirmMatch[
				httpBodyIn =
					Association @
					ImportString[HTTPRequestData["Body"], "RawJSON"],
				_Association,
				StringJoin[
					"Body is not an association: ",
					ToString[httpBodyIn]
				]
			];
			ConfirmMatch[
				httpHeadersIn =
					Association @
					ImportString[HTTPRequestData["Headers"], "RawJSON"],
				_Association,
				StringJoin[
					"Headers are not an association: ",
					ToString[httpHeadersIn]
				]
			];
			(* Act on request *)
			log[StringJoin[ "Got pinged at ", DateString["ISODateTime"]]];
			ret = handleReq[httpHeadersIn, httpBodyIn];
			If[FailureQ[ret],
				HTTPResponse[ToString[ret], <|"StatusCode" -> 500|>],
				HTTPResponse["", <|"StatusCode" -> 200|>]
			]
		]
	];

handleStash[httpBody_] :=
	Module[{
			event,
			mergeDest,
			link,
			repoAssoc,
			log =
				WWE`Logger[
					"INFO",
					"WWE",
					"ContinuousDeploymentWebhookHandler",
					StringJoin[ "\t", #]
				]&
		},
		Enclose[
			log[" - handleStash - "];
			(* log event *)
			event = httpBody["eventKey"];
			log[StringJoin[ "Event: '", event, "'"]];
			ConfirmBy[
				event,
				StringQ,
				StringJoin[ "Event '", ToString[event], "' is not a string"]
			];
			(* If PR merge event, pull and redeploy project *)
			If[event === "pr:merged",
				ConfirmBy[
					mergeDest = httpBody["pullRequest", "toRef", "id"],
					StringQ,
					StringJoin[
						"Merge destination ",
						ToString[mergeDest],
						" is not a string"
					]
				];
				log[StringJoin[ "found a merge target of '", mergeDest, "'"]];
				ConfirmBy[
					link =
						SelectFirst[
							httpBody[
								"pullRequest",
								"toRef",
								"repository",
								"links",
								"clone"
							],
							#name === "ssh"&
						][
							"href"
						],
					StringQ,
					StringJoin[
						"Clone link ",
						ToString[link],
						" is not a string"
					]
				];
				log[StringJoin[ "Repository: '", link, "'"]];
				repoAssoc = importWebappsManifest[Automatic];
				If[
					And[
						repoAssoc =!= <||>,
						mergeDest ===
						(StringJoin[ "refs/heads/", repoAssoc["branch"]])
					],
					(*pull and deploy the repository*)
					log["Redeploying webapps"];
					WWE`DeployWebappRepository[repoAssoc]
				]
			]
		]
	];

handleGithub[httpBody_] :=
	Module[{
			event,
			mergeDest,
			link,
			repoAssoc,
			log =
				WWE`Logger[
					"INFO",
					"WWE",
					"ContinuousDeploymentWebhookHandler",
					StringJoin[ "\t", #]
				]&
		},
		Enclose[
			log[" - handleGithub - "];
			(* log event *)
			event = httpBody["action"];
			log[StringJoin[ "Event: '", event, "'"]];
			ConfirmBy[
				event,
				StringQ,
				StringJoin[ "Event '", ToString[event], "' is not a string"]
			];
			(* If PR merge event, pull and redeploy project *)
			If[event === "closed",
				ConfirmBy[
					mergeDest = httpBody["pull_request", "base", "ref"],
					StringQ,
					StringJoin[
						"Merge destination ",
						ToString[mergeDest],
						" is not a string"
					]
				];
				log[StringJoin[ "Found merge target: '", mergeDest, "'"]];
				ConfirmBy[
					link = httpBody["pull_request", "base", "repo", "ssh_url"],
					StringQ,
					StringJoin[
						"Clone link ",
						ToString[link],
						" is not a string"
					]
				];
				log[StringJoin[ "Repository: '", link, "'"]];
				repoAssoc = importWebappsManifest[Automatic];
				If[
					StringMatchQ[mergeDest, repoAssoc["branch"]],
					(*pull and deploy the repository*)
					log["Redeploying webapps"];
					WWE`DeployWebappRepository[repoAssoc]
				]
			]
		]
	];

handleReq[httpHeaders_, httpBody_] :=
	Module[{
			log =
				WWE`Logger[
					"INFO",
					"WWE",
					"ContinuousDeploymentWebhookHandler",
					StringJoin[ "\t", #]
				]&
		},
		log[" - handleReq - "];
		Which[
			StringContainsQ[httpHeaders["User-Agent"], "GitHub"],
			log["GitHub event"];
			handleGithub[httpBody],
			(* StringContainsQ[httpHeaders["User-Agent"], "Stash"], *)
			True,
			log["Non-GitHub event"];
			handleStash[httpBody]
		]
	];

End[];
EndPackage[]; (* :!CodeAnalysis::EndBlock:: *)