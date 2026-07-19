BeginPackage["WWE`Private`"];

ContinuousDeploymentWebhookHandler::usage =
	StringJoin[
		"Handles incoming webhook requests from either Stash or GitHub ",
		"redeploying the tracked branch inside webapps-manifest.m if a branch ",
		"is merged into it"
	];

camelToSnakeCase;
crontabSpecValidQ;
getFileAtTopLevel;

EndPackage[];