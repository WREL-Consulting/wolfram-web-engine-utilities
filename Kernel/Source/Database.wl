BeginPackage[
	"WWE`FileScope`Database`",
	{"WWE`", "WWE`Private`", "DatabaseLink`"}
];
Begin["`Private`"];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* WebappDatabaseInitialize *)
(* Description:  Initializes the webapp database
 * Return:       _Success | _Failure
 *)
WebappDatabaseInitialize::nofile = "Could not find sql file at `1`";
WebappDatabaseInitialize // Options =
	{
		"RootPassword"       -> SystemCredential["db-pass"],
		"DatabasePassword"   -> SystemCredential["db-pass"],
		"Port"               -> 3306,
		"BaseURL"            -> "mariadb",
		"TemplateParameters" -> <||>
	};
WebappDatabaseInitialize[sqlFile_String, OptionsPattern[]] :=
	Enclose[
		Module[{con, sqlCommands},
			If[FileExistsQ[sqlFile] === False,
				Message[WebappDatabaseInitialize::nofile, sqlFile];
				Return[$Failed]
			];
			Needs["DatabaseLink`"];
			WithCleanup[
				con =
					Confirm[
						OpenSQLConnection[
							JDBC[
								"MySQL(Connector/J)",
								StringTemplate["`url`:`port`"][
									<|
										"url"  -> OptionValue["BaseURL"],
										"port" -> OptionValue["Port"]
									|>
								]
							],
							"Username"   -> "root",
							"Password"   -> OptionValue["RootPassword"],
							"Properties" -> {"useSSL" -> "false"}
						],
						"Failed to connect to database"
					],
				sqlCommands =
					StringTemplate[Import[sqlFile, "Text"]][
						<|
							"db-pass" -> OptionValue["DatabasePassword"],
							OptionValue["TemplateParameters"]
						|>
					] //
						StringSplit[#, ";"]&;
				Confirm[
					SQLExecute[con, #],
					StringJoin[ "Error while executing SQL command: ", #]
				]& /@ sqlCommands;
				Success[
					"webapp-database-initialized",
					<|"MessageTemplate" -> "Database initialized successfully"|>
				],
				CloseSQLConnection[con];
			]
		]
	];

(* -------------------------------------------------------------------------- *)
(* ::Section:: *)(* WebappDatabaseConnect *)
(* Description:  Connects to the webapp database
 * Return:       _SQLConnection | _Failure
 *)
WebappDatabaseConnect // Options =
	{
		"Port"              -> 3306,
		"Username"          -> "admin",
		"Password"          -> SystemCredential["db-pass"],
		"UseConnectionPool" -> False,
		"BaseURL"           -> "mariadb"
	};
WebappDatabaseConnect[dbName_String : "", OptionsPattern[]] :=
	Enclose[
		Needs["DatabaseLink`"];
		Confirm[
			OpenSQLConnection[
				JDBC[
					"MySQL(Connector/J)",
					URLBuild[
						{
							StringTemplate["`url`:`port`"][
								<|
									"url"  -> OptionValue["BaseURL"],
									"port" -> OptionValue["Port"]
								|>
							],
							dbName
						}
					]
				],
				"Username"          -> OptionValue["Username"],
				"Password"          -> OptionValue["Password"],
				"Properties"        -> {"useSSL" -> "false"},
				"UseConnectionPool" -> OptionValue["UseConnectionPool"]
			],
			"Failed to connect to database"
		]
	];

End[];
EndPackage[];