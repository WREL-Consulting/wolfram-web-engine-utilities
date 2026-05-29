BeginPackage[
  "WWE`FileScope`BuiltIn`",
  {"WWE`", "WWE`Private`", "DatabaseLink`"}
];
Begin["`Private`"];

$streamRetryAttempts = 5;

$streamRetryIntervalSeconds = 0.2;

$stdoutLogFile = "/proc/1/fd/1";

$stderrLogFile = "/proc/1/fd/2";

$headerBytes[] :=
  With[{method = HTTPRequestData["Method"]},
    {
      m =
        ResourceFunction["ANSITools"][
          "Style",
          StringJoin[ " ", method, " "],
          FontColor -> White,
          Background -> Switch[method,
            "GET",
              Green,
            "POST",
              Blue,
            "PUT",
              Yellow,
            "DELETE",
              Red,
            _,
              Gray
          ]
        ]
    },
    ToCharacterCode @
    StringTemplate["`datetime` OUT   `method` [`domain`]: "][
      <|
        "domain" -> HTTPRequestData["PathString"],
        "method" -> m,
        "requester" -> HTTPRequestData["RequesterAddress"],
        "datetime" -> DateString[
          {
            "Year",
            "-",
            "Month",
            "-",
            "Day",
            " ",
            "Hour",
            ":",
            "Minute",
            ":",
            "Second"
          }
        ]
      |>
    ]
  ];

DefineOutputStreamMethod[
  "PipedWithHeader",
  {
    "ConstructorFunction" -> Function[
      {streamname, isAppend, caller, opts},
      With[{state = Unique["AddHeaderStream"]},
        state["stream"] =
          OpenWrite[StringJoin[ "!cat >> ", streamname], BinaryFormat -> True];
        state["pos"] = 0;
        state["newline"] = True;
        {True, state}
      ]
    ],
    "CloseFunction" -> Function[state, Close[state["stream"]]; Remove[state]],
    "StreamPositionFunction" -> Function[state, {state["pos"], state}],
    "WriteFunction" -> Function[
      {state, bytes},
      (* Capture output to avoid recursion *)
      Block[{
          $Output = {$StandardOutputStream},
          $Messages = {$StandardErrorStream}
        },
        If[StringMatchQ[$EvaluationEnvironment, "WebAPI" | "Script"],
          Module[
            {
              result,
              nBytes,
              write =
				(* Don't add header to end of line characters *)
				If[ state["newline"] && !MatchQ[bytes, {Repeated[13 | 10, {1, 2}]}],
					Join[$headerBytes[], bytes],
					bytes
				]
            },
            result = BinaryWrite[state["stream"], write];
            nBytes = If[result === state["stream"], Length @ write, 0];
            state["pos"] += nBytes;
            state["newline"] = MatchQ[Last[bytes, {}], 13 | 10];
            {nBytes, state}
          ],
          {0, state}
        ]
      ]
    ]
  }
];

(* Create log files if they don't exist *)
If[Not @ FileExistsQ[#], CreateFile[#]]& /@ {$stdoutLogFile, $stderrLogFile};

(* Open log streams *)
{$stdoutLogStream, $stderrLogStream} =
  Function[
    With[{stream = First[Streams[#], Missing[]]},
      If[MissingQ[stream], OpenAppend[#, Method -> "PipedWithHeader"], stream]
    ]
  ] /@ {$stdoutLogFile, $stderrLogFile};

(* Route stdout and messages to log streams *)
If[Length[Select[System`$Output, #[[1]] === $stdoutLogStream&]] == 0,
  AppendTo[System`$Output, $stdoutLogStream]
];
If[Length[Select[System`$Messages, #[[1]] === $stderrLogStream&]] == 0,
  AppendTo[System`$Messages, $stderrLogStream]
];

End[];
EndPackage[];
