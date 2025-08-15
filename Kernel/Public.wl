BeginPackage["WWE`"];

RestartKernelPool::usage =
	"RestartKernelPool[] " <>
		"restarts the kernel pool by calling the KillAll.jsp endpoint.";

DeployWebappFrontEnd::usage =
	"DeployWebappFrontEnd[buildDir_, location : \"\"] " <>
		"deploys the build files inside `buildDir` to `location` in the " <>
		"Tomcat ROOT webapp directory.";

DeployWebappRepository::usage =
	"DeployWebappRepository[repositoryAssoc_, OptionsPattern[]] " <>
		"deploys the repository at `repositoryAssoc` to the Tomcat ROOT " <>
		"webapp directory.\n" <>
	"Options: \n"<>
		"\"InitializeDB\" -> True will initialize the database.";

DeployExpression::usage =
	"DeployExpression[expr_, location_, OptionsPattern[]] " <>
		"deploys the expression `expr` to the Tomcat ROOT webapp directory " <>
		"at `location`.\n" <>
	"DeployExpression[expr_, OptionsPattern[]] deploys " <>
		"the expression `expr` to the Tomcat ROOT webapp directory at a random " <>
		"UUID endpoint.";

AddWolframInitCode::usage =
	"AddWolframInitCode[initCode_] "<>
		"adds the initialization code `initCode` to the Wolfram Engine's " <>
		"init.m file.";

WebappDatabaseInitialize::usage =
	"WebappDatabaseInitialize[sqlFile_] "<>
		"initializes the database using the SQL commands in `sqlFile`.";

WebappDatabaseConnect::usage =
	"WebappDatabaseConnect[dbName_ : \"\"] " <>
		"creates a connection to the database `dbName`.";

DefineSupervisorCommand::usage =
	"DefineSupervisorCommand[command_String, name_String] "<>
		"adds a program to the supervisord configuration file.";

DefineCronJob::usage =
	"DefineCronJob[command_String, cronSpec_String] " <>
		"adds a command to the crontab file with the provided cronSpec.";

LogError::usage =
	"LogError[appName_String, functionName_String, message_String] " <>
		"logs an event message to the log file "<>
		"/var/log/appName/functionName-error.log.";

(* Aliases - For backwards compatibility *)
deployExpression     = DeployExpression;
deployBuildFolder    = DeployWebappFrontEnd;
initiliseDatabase    = WebappDatabaseInitialize;
makeDBConnection     = WebappDatabaseConnect;
addSupervisorCommand = DefineSupervisorCommand;
addInitCode          = AddWolframInitCode;
addCrontabCommand    = DefineCronJob;
logError             = LogError;
CommandLineParse     = ResourceFunction["CommandLineParse"];
ANSITools            = ResourceFunction["ANSITools"];

EndPackage[];
