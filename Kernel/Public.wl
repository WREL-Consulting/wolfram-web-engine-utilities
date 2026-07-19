BeginPackage["WWE`"];

DeployWebapps::usage =
	StringJoin[
		"DeployWebapps[] deploys all repositories in the webapps-manifest.m ",
		"file.\nOptions: \n\"Manifest\" -> Location to the webapps-manifest.m ",
		"file.\n\"LogLabel\" -> Label to print to stdout.\n\"Initialize\" -> ",
		"True will initialize flag to DeployWebappRepository."
	];

RestartKernelPool::usage =
	StringJoin[
		"RestartKernelPool[] restarts the kernel pool by calling the ",
		"KillAll.jsp endpoint."
	];

DeployWebappFrontEnd::usage =
	StringJoin[
		"DeployWebappFrontEnd[buildDir_, location : \"\"] deploys the build ",
		"files inside `buildDir` to `location` in the Tomcat ROOT webapp ",
		"directory."
	];

DeployWebappRepository::usage =
	StringJoin[
		"DeployWebappRepository[repositoryAssoc_, OptionsPattern[]] deploys ",
		"the repository at `repositoryAssoc` to the Tomcat ROOT webapp ",
		"directory.\nOptions: \n\"InitializeDB\" -> True will initialize the ",
		"database."
	];

DeployRouteMap::usage =
	StringJoin[
		"DeployRouteMap[apiMap_Association] deploys the route map ",
		"`apiMap`.\nDeployRouteMap[apiMap_Association, acc_String] deploys ",
		"the route map `apiMap` with the base path `acc`."
	]

DeployExpression::usage =
	StringJoin[
		"DeployExpression[expr_, location_, OptionsPattern[]] deploys the ",
		"expression `expr` to the Tomcat ROOT webapp directory at ",
		"`location`.\nDeployExpression[expr_, OptionsPattern[]] deploys the ",
		"expression `expr` to the Tomcat ROOT webapp directory at a random ",
		"UUID endpoint."
	];

AddWolframInitCode::usage =
	StringJoin[
		"AddWolframInitCode[initCode_] adds the initialization code ",
		"`initCode` to the Wolfram Engine's init.m file."
	];

WebappDatabaseInitialize::usage =
	StringJoin[
		"WebappDatabaseInitialize[sqlFile_] initializes the database using ",
		"the SQL commands in `sqlFile`."
	];

WebappDatabaseConnect::usage =
	StringJoin[
		"WebappDatabaseConnect[dbName_ : \"\"] creates a connection to the ",
		"database `dbName`."
	];

AddSupervisorCommand::usage =
	StringJoin[
		"AddSupervisorCommand[command_String, name_String] adds a program to ",
		"the supervisord configuration file."
	];

AddCronJob::usage =
	StringJoin[
		"AddCronJob[command_String, cronSpec_String] adds a command to the ",
		"crontab file with the provided cronSpec."
	];

Logger::usage =
	StringJoin[
		"Logger[level_String, appName_String, functionName_String, ",
		"message_String] logs an event message to the log file ",
		"/var/log/appName/functionName-error.log."
	];

(* Aliases - For backwards compatibility *)
deployExpression = DeployExpression;

deployBuildFolder = DeployWebappFrontEnd;

initiliseDatabase = WebappDatabaseInitialize;

makeDBConnection = WebappDatabaseConnect;

addSupervisorCommand = AddSupervisorCommand;

DefineSupervisorCommand = AddSupervisorCommand;

addInitCode = AddWolframInitCode;

addCrontabCommand = AddCronJob;

DefineCronJob = AddCronJob;

logError = Function[Print["logError is obsolete. Use WWE`Logger instead."]];

LogError = Function[Print["LogError is obsolete. Use WWE`Logger instead."]];

CommandLineParse =
	Function[
		Print["CommandLineParse is obsolete. Use WWE`CLITools instead."];
		Exit[2]
	];

CL = CLTools = ResourceFunction["CommandLineTools"];

ANSI = ANSITools = ResourceFunction["ANSITools"];

EndPackage[];