BeginPackage["WWE`FileScope`BuiltIn`", {
	"WWE`",
	"WWE`Private`",
	"DatabaseLink`"
}];
Begin["`Private`"];

(* Route stdout and messages to log-files *)
$stdoutLogFile = FileNameJoin[{"var", "log", "wwe-stdout.log"}];
$stderrLogFile = FileNameJoin[{"var", "log", "wwe-stderr.log"}];
If[ Not @ FileExistsQ[#], CreateFile[#]]& /@ {$stdoutLogFile, $stderrLogFile};
{$stdoutLogStream, $stderrLogStream} = OpenAppend /@ {$stdoutLogFile, $stderrLogFile};
AppendTo[System`$Output,  $stdoutLogFile];
AppendTo[System`$Messages, $stderrLogFile];

End[];
EndPackage[];
