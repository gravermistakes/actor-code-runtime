%% Erlang FFI for the execution substrate.
%%
%%  * read_line/0     — stdin reader for the stdio MCP server loop.
%%  * run_command/2   — run untrusted code as an OS subprocess under `/bin/sh -c`
%%                      with a hard wall-clock deadline, capturing combined
%%                      stdout+stderr and the exit status.
%%
%% Isolation here is a timeout-bounded subprocess. Stronger sandboxing
%% (cgroups / seccomp / container per run) is tracked in docs/ROADMAP.md Phase 2.
-module(acr_ffi).
-export([read_line/0, run_command/2]).

read_line() ->
    case io:get_line("") of
        eof -> {error, nil};
        {error, _Reason} -> {error, nil};
        Data -> {ok, unicode:characters_to_binary(Data)}
    end.

%% Returns {ok, {ExitCode, Output, DurationMs}} on completion,
%% or {error, DurationMs} if the wall-clock deadline was exceeded.
run_command(Command, TimeoutMs) when is_binary(Command), is_integer(TimeoutMs) ->
    Cmd = binary_to_list(Command),
    Start = erlang:monotonic_time(millisecond),
    Deadline = Start + TimeoutMs,
    Port = erlang:open_port(
        {spawn_executable, "/bin/sh"},
        [stream, exit_status, stderr_to_stdout, binary, hide, {args, ["-c", Cmd]}]
    ),
    Result = collect(Port, Deadline, <<>>),
    Duration = erlang:monotonic_time(millisecond) - Start,
    case Result of
        {ok, ExitCode, Output} -> {ok, {ExitCode, Output, Duration}};
        timeout -> {error, Duration}
    end.

collect(Port, Deadline, Acc) ->
    Now = erlang:monotonic_time(millisecond),
    Remaining = max(0, Deadline - Now),
    receive
        {Port, {data, Data}} ->
            collect(Port, Deadline, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, Status}} ->
            {ok, Status, Acc}
    after Remaining ->
        (catch erlang:port_close(Port)),
        timeout
    end.
