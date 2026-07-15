-module(server).
-export([start/0]).

start() ->
    Port = 12345,

    AuthPid = auth_manager:start(),
    QueuePid = queue_manager:start(),
    GameSupervisorPid = game_supervisor:start(),
    ScoreboardPid = scoreboard_manager:start(),

    QueuePid ! {init, GameSupervisorPid},
    GameSupervisorPid ! {init, QueuePid, ScoreboardPid},

    {ok, ListenSocket} = gen_tcp:listen(Port, [binary, {packet, line}, {reuseaddr, true}, {active, false}]),
    accept_loop(ListenSocket, AuthPid, QueuePid, GameSupervisorPid, ScoreboardPid).

accept_loop(ListenSocket, AuthPid, QueuePid, GameSupervisorPid, ScoreboardPid) ->
    {ok, Socket} = gen_tcp:accept(ListenSocket),
    SessionPid = connection_session:start(Socket, AuthPid, QueuePid, GameSupervisorPid, ScoreboardPid),
    ok = gen_tcp:controlling_process(Socket, SessionPid),
    SessionPid ! activate_socket,
    accept_loop(ListenSocket, AuthPid, QueuePid, GameSupervisorPid, ScoreboardPid).