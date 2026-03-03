BeginPackage["WWE`FileScope`BuiltIn`", {
	"WWE`",
	"WWE`Private`",
	"DatabaseLink`"
}];
Begin["`Private`"];

$stdoutLogFile = FileNameJoin[{"/", "var", "log", "wwe-stdout.log"}];
$stderrLogFile = FileNameJoin[{"/", "var", "log", "wwe-stderr.log"}];
$headerBytes[] :=
	ToCharacterCode @
	StringTemplate["`datetime` - [`domain`]: "][<|
		"domain" -> If[ $EvaluationEnvironment === "WebAPI",
			HTTPRequestData["PathString"],
			$ProcessID
		],
		"datetime" -> DateString[{
			"Year", "-", "Month", "-", "Day",
			"T",
			"Hour", ":", "Minute", ":", "Second"
		}]
	|>];

DefineOutputStreamMethod[
	"WithHeader",
	{
		"ConstructorFunction" ->
			Function[{streamname, isAppend, caller, opts},
				With[{state = Unique["AddHeaderStream"]},
					state["stream"] =
						OpenWrite[streamname, BinaryFormat -> True];
					state["pos"] = 0;
					state["newline"] = True;
					{True, state}
				]
			],
		"CloseFunction" ->
			Function[state, Close[state["stream"]]; Remove[state]],
		"StreamPositionFunction" ->
			Function[state, {state["pos"], state}],
		"WriteFunction" ->
			Function[{state, bytes},
				Module[{
						result, nBytes,
						write =
							(* Don't add header to end of line characters *)
							If[ state["newline"] && !MatchQ[bytes, {Repeated[13 | 10, {1, 2}]}],
								Join[$headerBytes[], bytes],
								bytes
							]
					},
					result = BinaryWrite[state["stream"], write];
					nBytes =
						If[result === state["stream"],
							Length @ write,
							0
						];
					state["pos"] += nBytes;
					state["newline"] = MatchQ[Last[bytes, {}], 13 | 10];
					{nBytes, state}
				]
			]
	}
];

(* Create log files if they don't exist *)
If[ Not @ FileExistsQ[#], CreateFile[#]]& /@ {$stdoutLogFile, $stderrLogFile};

(* Open log streams *)
{$stdoutLogStream, $stderrLogStream} =
	Function[
		With[{stream = First[Streams[#], Missing[]]},
		If[ MissingQ[stream],
			OpenAppend[#, Method -> "WithHeader"],
			stream
		]]
	] /@ {$stdoutLogFile, $stderrLogFile};

(* Route stdout and messages to log streams *)
If[ Length[Select[ System`$Output, #[[1]] === $stdoutLogStream& ]] == 0,
	AppendTo[System`$Output, $stdoutLogStream]
];
If[ Length[Select[ System`$Messages, #[[1]] === $stderrLogStream& ]] == 0,
	AppendTo[System`$Messages, $stderrLogStream]
];

End[];
EndPackage[];
