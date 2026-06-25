%% Stdin FFI for the stdio MCP server. Reads one line at a time so the Gleam
%% serve loop can process JSON-RPC requests as they arrive.
-module(acr_ffi).
-export([read_line/0]).

read_line() ->
    case io:get_line("") of
        eof -> {error, nil};
        {error, _Reason} -> {error, nil};
        Data -> {ok, unicode:characters_to_binary(Data)}
    end.
