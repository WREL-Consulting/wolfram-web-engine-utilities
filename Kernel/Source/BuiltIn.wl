BeginPackage["WWE`FileScope`BuiltIn`", {
	"WWE`",
	"WWE`Private`",
	"DatabaseLink`"
}];
Begin["`Private`"];


$streamRetryAttempts = 5;
$streamRetryIntervalSeconds = 0.2;

$stdoutLogFile = FileNameJoin[{"/", "var", "log", "wwe-stdout.log"}];
$stderrLogFile = FileNameJoin[{"/", "var", "log", "wwe-stderr.log"}];
$headerBytes[] :=
	ToCharacterCode @
	StringTemplate["[`datetime`][ `requester` |> `method` |> `domain` ]: "][<|
		"domain" -> HTTPRequestData["PathString"],
		"method" -> HTTPRequestData["Method"],
		"requester" -> HTTPRequestData["RequesterAddress"],
		"datetime" -> DateString[{
			"Year", "-", "Month", "-", "Day",
			"T",
			"Hour", ":", "Minute", ":", "Second"
		}]
	|>];

DefineOutputStreamMethod["WithHeader", {
	"ConstructorFunction" -> Function[{streamname, isAppend, caller, opts},
		With[{state = Unique["AddHeaderStream"]},
			state["streamname"] = streamname;
			state["pos"] = 0;
			state["newline"] = True;
			{True, state}
		]
	],
	"CloseFunction" -> Function[state, Remove[state]],
	"StreamPositionFunction" -> Function[state, {state["pos"], state}],
	"WriteFunction" -> Function[{state, bytes},
		If[$EvaluationEnvironment === "WebAPI",
			Module[{result, stream, nBytes, attempts = 0,
					write =
						(* Don't add header to end of line characters *)
						If[ state["newline"] && !MatchQ[bytes, {Repeated[13 | 10, {1, 2}]}],
							Join[$headerBytes[], bytes],
							bytes
						]
				},
				(* Attempt to open later in case file is already open *)
				While[ Not @ MatchQ[
						stream =
							Quiet @
							OpenAppend[state["streamname"], BinaryFormat -> True],
						_OutputStream
					] && attempts < $streamRetryAttempts
					,
					attempts++;
					Pause[$streamRetryIntervalSeconds * attempts]
				];
				If[ MatchQ[stream, _OutputStream],
					result = BinaryWrite[state["stream"], write];
					nBytes = If[result === state["stream"],
						Length @ write,
						0
					];
					state["pos"] += nBytes;
					state["newline"] = MatchQ[Last[bytes, {}], 13 | 10];
					state["stream"] = Close[state["stream"]];
					{nBytes, state}
					,
					{0, state}
				]
			]
		]
	]
}];

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
