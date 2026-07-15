-module(game_supervisor).
-export([start/0]).

start() ->
    InitialState = #{
        next_game_id => 1,
        active_games => #{},
        reserved_requests => #{},
        queue_manager => undefined,
        scoreboard_manager => undefined
    },
    spawn(fun() -> loop(InitialState) end).

loop(State) ->
    receive
        {init, QueueManagerPid, ScoreboardManagerPid} ->
            NewState = State#{
                queue_manager => QueueManagerPid,
                scoreboard_manager => ScoreboardManagerPid
            },
            loop(NewState);

        {create_game_request, RequestId, Players, From} ->
            ActiveGames = maps:get(active_games, State),
            ReservedRequests = maps:get(reserved_requests, State),
            UsedCapacity = maps:size(ActiveGames) + maps:size(ReservedRequests),

            case UsedCapacity < 4 of
                true ->
                    NewReservedRequests = ReservedRequests#{
                        RequestId => Players
                    },
                    NewState = State#{
                        reserved_requests => NewReservedRequests
                    },
                    From ! {create_game_result, RequestId, ok},
                    loop(NewState);

                false ->
                    From ! {create_game_result, RequestId, full},
                    loop(State)
            end;

        {confirm_game_creation, RequestId} ->
            ReservedRequests = maps:get(reserved_requests, State),

            case maps:find(RequestId, ReservedRequests) of
                {ok, Players} ->
                    GameId = maps:get(next_game_id, State),
                    ScoreboardManagerPid = maps:get(scoreboard_manager, State),
                    GameSessionPid = game_session:start(GameId, Players, self(), ScoreboardManagerPid),

                    lists:foreach(fun({_Username, SessionPid}) -> SessionPid ! {game_started, GameId, GameSessionPid} end, Players),

                    NewReservedRequests = maps:remove(RequestId, ReservedRequests),
                    ActiveGames = maps:get(active_games, State),
                    NewActiveGames = ActiveGames#{
                        GameId => GameSessionPid
                    },

                    NewState = State#{
                        next_game_id => GameId + 1,
                        reserved_requests => NewReservedRequests,
                        active_games => NewActiveGames
                    },
                    loop(NewState);

                error ->
                    loop(State)
            end;

        {cancel_game_request, RequestId} ->
            ReservedRequests = maps:get(reserved_requests, State),
            NewReservedRequests = maps:remove(RequestId, ReservedRequests),
            NewState = State#{
                reserved_requests => NewReservedRequests
            },
            loop(NewState);

        {game_finished, GameId} ->
            ActiveGames = maps:get(active_games, State),
            NewActiveGames = maps:remove(GameId, ActiveGames),
            NewState = State#{
                active_games => NewActiveGames
            },

            QueueManagerPid = maps:get(queue_manager, State),
            maybe_notify_slot_available(QueueManagerPid),

            loop(NewState);

        stop ->
            ok
    end.

maybe_notify_slot_available(undefined) ->
    ok;
maybe_notify_slot_available(QueueManagerPid) ->
    QueueManagerPid ! {slot_available},
    ok.