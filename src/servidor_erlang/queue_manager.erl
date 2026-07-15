-module(queue_manager).
-export([start/0]).

start() ->
    InitialState = #{
        queue => [],
        game_supervisor => undefined,
        pending_match => none,
        next_request_id => 1
    },
    spawn(fun() -> loop(InitialState) end).

loop(State) ->
    receive
        {init, GameSupervisorPid} ->
            NewState = State#{
                game_supervisor => GameSupervisorPid
            },
            loop(NewState);

        {join_queue, Username, SessionPid, From} ->
            Queue = maps:get(queue, State),

            case user_in_queue(Username, Queue) of
                true ->
                    From ! {join_queue_result, already_waiting},
                    loop(State);

                false ->
                    NewQueue = Queue ++ [{Username, SessionPid}],
                    NewState = State#{
                        queue => NewQueue
                    },
                    From ! {join_queue_result, ok},
                    loop(try_matchmaking(NewState))
            end;

        {leave_queue, Username, From} ->
            Queue = maps:get(queue, State),

            case user_in_queue(Username, Queue) of
                false ->
                    From ! {leave_queue_result, not_in_queue},
                    loop(State);

                true ->
                    NewQueue = remove_user_from_queue(Username, Queue),
                    TempState = State#{
                        queue => NewQueue
                    },
                    NewState = invalidate_pending_if_needed(Username, TempState),
                    From ! {leave_queue_result, ok},
                    loop(try_matchmaking(NewState))
            end;

        {slot_available} ->
            loop(try_matchmaking(State));

        {create_game_result, RequestId, ok} ->
            case maps:get(pending_match, State) of
                {RequestId, Players} ->
                    GameSupervisorPid = maps:get(game_supervisor, State),
                    GameSupervisorPid ! {confirm_game_creation, RequestId},
                    
                    Queue = maps:get(queue, State),
                    NewQueue = remove_players_from_queue(Players, Queue),
                    TempState = State#{
                        queue => NewQueue,
                        pending_match => none
                    },
                    loop(try_matchmaking(TempState));

                _ ->
                    loop(State)
            end;

        {create_game_result, RequestId, full} ->
            case maps:get(pending_match, State) of
                {RequestId, _Players} ->
                    NewState = State#{
                        pending_match => none
                    },
                    loop(NewState);

                _ ->
                    loop(State)
            end;

        stop ->
            ok
    end.

try_matchmaking(State) ->
    PendingMatch = maps:get(pending_match, State),

    case PendingMatch of
        none ->
            GameSupervisorPid = maps:get(game_supervisor, State),
            Queue = maps:get(queue, State),

            case GameSupervisorPid of
                undefined ->
                    State;

                _ ->
                    case select_candidates(Queue) of
                        none ->
                            State;

                        Players ->
                            RequestId = maps:get(next_request_id, State),
                            GameSupervisorPid ! {create_game_request, RequestId, Players, self()},
                            State#{
                                pending_match => {RequestId, Players},
                                next_request_id => RequestId + 1
                            }
                    end
            end;

        _ ->
            State
    end.

select_candidates(Queue) ->
    case length(Queue) of
        N when N >= 4 ->
            lists:sublist(Queue, 4);
        3 ->
            lists:sublist(Queue, 3);
        _ ->
            none
    end.

invalidate_pending_if_needed(Username, State) ->
    case maps:get(pending_match, State) of
        none ->
            State;

        {RequestId, Players} ->
            case user_in_players(Username, Players) of
                true ->
                    GameSupervisorPid = maps:get(game_supervisor, State),
                    maybe_send_cancel(GameSupervisorPid, RequestId),
                    State#{
                        pending_match => none
                    };
                false ->
                    State
            end
    end.

maybe_send_cancel(undefined, _RequestId) ->
    ok;
maybe_send_cancel(GameSupervisorPid, RequestId) ->
    GameSupervisorPid ! {cancel_game_request, RequestId},
    ok.

user_in_queue(Username, Queue) ->
    lists:any(fun({U, _}) -> U =:= Username end, Queue).

remove_user_from_queue(Username, Queue) ->
    lists:filter(fun({U, _}) -> U =/= Username end, Queue).

user_in_players(Username, Players) ->
    lists:any(fun({U, _}) -> U =:= Username end, Players).

remove_players_from_queue(Players, Queue) ->
    lists:filter(fun({U, _}) -> not user_in_players(U, Players) end, Queue).