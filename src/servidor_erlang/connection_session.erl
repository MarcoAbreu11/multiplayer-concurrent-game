-module(connection_session).
-export([start/5]).

-define(GAME_WIDTH, 800).
-define(GAME_HEIGHT, 600).
-define(GAME_TICK_MS, 50).


start(Socket, AuthManagerPid, QueueManagerPid, GameSupervisorPid, ScoreboardManagerPid) ->
    InitialState = #{
        socket => Socket,
        auth_manager => AuthManagerPid,
        queue_manager => QueueManagerPid,
        game_supervisor => GameSupervisorPid,
        scoreboard_manager => ScoreboardManagerPid,
        username => undefined,
        pending_login => undefined,
        status => connected,
        game_id => undefined,
        game_session => undefined
    },
    spawn(fun() -> loop(InitialState) end).



loop(State) ->
    Socket = maps:get(socket, State),
    receive
        activate_socket ->
            ok = inet:setopts(Socket, [{active, true}]),
            loop(State);

        {tcp, Socket, Data} ->
            handle_tcp_data(Data, Socket, State);

        {tcp_closed, Socket} ->
            handle_disconnect(State);

        {tcp_error, Socket, _Reason} ->
            handle_disconnect(State);

        {create_account_result, ok} ->
            send_line(Socket, "create_account_ok"),
            loop(State);

        {create_account_result, username_taken} ->
            send_line(Socket, "create_account_error username_taken"),
            loop(State);

        {login_result, ok} ->
            Username = maps:get(pending_login, State),
            send_line(Socket, "login_ok " ++ Username),
            NewState = State#{
                username => Username,
                pending_login => undefined,
                status => authenticated
            },
            loop(NewState);

        {login_result, user_not_found} ->
            send_line(Socket, "login_error user_not_found"),
            NewState = State#{pending_login => undefined},
            loop(NewState);

        {login_result, wrong_password} ->
            send_line(Socket, "login_error wrong_password"),
            NewState = State#{pending_login => undefined},
            loop(NewState);

        {login_result, already_online} ->
            send_line(Socket, "login_error already_online"),
            NewState = State#{pending_login => undefined},
            loop(NewState);

        {logout_result, ok} ->
            send_line(Socket, "logout_ok"),
            NewState = State#{
                username => undefined,
                pending_login => undefined,
                status => connected,
                game_id => undefined,
                game_session => undefined
            },
            loop(NewState);

        {close_account_result, ok} ->
            send_line(Socket, "close_account_ok"),
            NewState = State#{
                username => undefined,
                pending_login => undefined,
                status => connected,
                game_id => undefined,
                game_session => undefined
            },
            loop(NewState);

        {close_account_result, invalid} ->
            send_line(Socket, "close_account_error invalid"),
            loop(State);

        {join_queue_result, ok} ->
            send_line(Socket, "join_queue_ok"),
            NewState = State#{status => waiting},
            loop(NewState);

        {join_queue_result, already_waiting} ->
            send_line(Socket, "join_queue_error already_waiting"),
            loop(State);

        {leave_queue_result, ok} ->
            send_line(Socket, "leave_queue_ok"),
            NewState = State#{status => authenticated},
            loop(NewState);

        {leave_queue_result, not_in_queue} ->
            send_line(Socket, "leave_queue_error not_in_queue"),
            loop(State);

        {top_scores, []} ->
            send_line(Socket, "top_scores empty"),
            loop(State);

        {top_scores, Scores} ->
            FormattedScores = format_top_scores(Scores),
            send_line(Socket, "top_scores " ++ FormattedScores),
            loop(State);

        {game_started, GameId, GameSessionPid} ->
            send_line(Socket, "game_started " ++ integer_to_list(GameId)),
            send_line(
                Socket,
                "game_config " ++
                integer_to_list(?GAME_WIDTH) ++ " " ++
                integer_to_list(?GAME_HEIGHT) ++ " " ++
                integer_to_list(?GAME_TICK_MS)
            ),
            NewState = State#{
                status => in_game,
                game_id => GameId,
                game_session => GameSessionPid
            },
            loop(NewState);

        {game_state, Tick, RemainingMs, PlayersData, FoodsData, PoisonsData} ->
            MyUsername = maps:get(username, State),
            send_game_state(
                Socket,
                MyUsername,
                Tick,
                RemainingMs,
                PlayersData,
                FoodsData,
                PoisonsData
            ),
            loop(State);

        {game_over, {winner, WinnerUsername, Captures}} ->
            send_line(
                Socket,
                "game_over winner " ++ WinnerUsername ++ " " ++ integer_to_list(Captures)
            ),
            NewState = State#{
                status => authenticated,
                game_id => undefined,
                game_session => undefined
            },
            loop(NewState);

        {game_over, tie} ->
            send_line(Socket, "game_over tie"),
            NewState = State#{
                status => authenticated,
                game_id => undefined,
                game_session => undefined
            },
            loop(NewState);

        {game_aborted, player_disconnected, Username} ->
            send_line(Socket, "game_aborted player_disconnected " ++ Username),
            NewState = State#{
                status => authenticated,
                game_id => undefined,
                game_session => undefined
            },
            loop(NewState)

    end.



send_line(Socket, Line) ->
    gen_tcp:send(Socket, Line ++ "\n").

handle_tcp_data(Data, Socket, State) ->
    case parse_tcp_command(Data) of
        error ->
            send_line(Socket, "error bad_request"),
            loop(State);

        {ok, Command} ->
            Status = maps:get(status, State),
            case validate_command(Status, Command) of
                ok ->
                    dispatch_command(Command, State);

                {error, invalid_state, CmdName} ->
                    send_line(Socket, "error invalid_state " ++ atom_to_list(CmdName)),
                    loop(State)
            end
    end.



parse_tcp_command(Data) ->
    Line = string:trim(binary_to_list(Data)),
    Tokens = string:tokens(Line, " "),
    parse_tokens(Tokens).

parse_tokens(["create_account", Username, Password]) ->
    {ok, {create_account, Username, Password}};
parse_tokens(["login", Username, Password]) ->
    {ok, {login, Username, Password}};
parse_tokens(["logout"]) ->
    {ok, logout};
parse_tokens(["close_account", Username, Password]) ->
    {ok, {close_account, Username, Password}};
parse_tokens(["join_queue"]) ->
    {ok, join_queue};
parse_tokens(["leave_queue"]) ->
    {ok, leave_queue};
parse_tokens(["top_scores"]) ->
    {ok, top_scores};
parse_tokens(["input", "left", "down"]) ->
    {ok, {input, esquerda, down}};
parse_tokens(["input", "left", "up"]) ->
    {ok, {input, esquerda, up}};
parse_tokens(["input", "right", "down"]) ->
    {ok, {input, direita, down}};
parse_tokens(["input", "right", "up"]) ->
    {ok, {input, direita, up}};
parse_tokens(["input", "forward", "down"]) ->
    {ok, {input, frente, down}};
parse_tokens(["input", "forward", "up"]) ->
    {ok, {input, frente, up}};
parse_tokens(_) ->
    error.


command_name({create_account, _, _}) ->
    create_account;
command_name({login, _, _}) ->
    login;
command_name(logout) ->
    logout;
command_name({close_account, _, _}) ->
    close_account;
command_name(join_queue) ->
    join_queue;
command_name(leave_queue) ->
    leave_queue;
command_name(top_scores) ->
    top_scores;
command_name({input, _, _}) ->
    input.

validate_command(connected, {create_account, _, _}) ->
    ok;
validate_command(connected, {login, _, _}) ->
    ok;
validate_command(connected, {close_account, _, _}) ->
    ok;
validate_command(connected, Command) ->
    {error, invalid_state, command_name(Command)};

validate_command(authenticated, join_queue) ->
    ok;
validate_command(authenticated, logout) ->
    ok;
validate_command(authenticated, {close_account, _, _}) ->
    ok;
validate_command(authenticated, Command) ->
    {error, invalid_state, command_name(Command)};

validate_command(waiting, leave_queue) ->
    ok;
validate_command(waiting, top_scores) ->
    ok;
validate_command(waiting, Command) ->
    {error, invalid_state, command_name(Command)};

validate_command(in_game, {input, _, _}) ->
    ok;
validate_command(in_game, Command) ->
    {error, invalid_state, command_name(Command)}.


dispatch_command({create_account, Username, Password}, State) ->
    AuthManagerPid = maps:get(auth_manager, State),
    AuthManagerPid ! {create_account, Username, Password, self()},
    loop(State);

dispatch_command({login, Username, Password}, State) ->
    AuthManagerPid = maps:get(auth_manager, State),
    AuthManagerPid ! {login, Username, Password, self()},
    NewState = State#{pending_login => Username},
    loop(NewState);

dispatch_command(logout, State) ->
    AuthManagerPid = maps:get(auth_manager, State),
    Username = maps:get(username, State),
    AuthManagerPid ! {logout, Username, self()},
    loop(State);

dispatch_command({close_account, Username, Password}, State) ->
    AuthManagerPid = maps:get(auth_manager, State),
    AuthManagerPid ! {close_account, Username, Password, self()},
    loop(State);

dispatch_command(join_queue, State) ->
    QueueManagerPid = maps:get(queue_manager, State),
    Username = maps:get(username, State),
    QueueManagerPid ! {join_queue, Username, self(), self()},
    loop(State);

dispatch_command(leave_queue, State) ->
    QueueManagerPid = maps:get(queue_manager, State),
    Username = maps:get(username, State),
    QueueManagerPid ! {leave_queue, Username, self()},
    loop(State);

dispatch_command(top_scores, State) ->
    ScoreboardManagerPid = maps:get(scoreboard_manager, State),
    ScoreboardManagerPid ! {get_top_scores, self()},
    loop(State);

dispatch_command({input, Key, Action}, State) ->
    GameSessionPid = maps:get(game_session, State),
    Username = maps:get(username, State),
    GameSessionPid ! {player_input, Username, Key, Action},
    loop(State).


format_top_scores(Scores) ->
    FormattedList =
        lists:map(
            fun({Username, Wins}) ->
                Username ++ ":" ++ integer_to_list(Wins)
            end,
            Scores
        ),
    string:join(FormattedList, ",").


handle_disconnect(State) ->
    Status = maps:get(status, State),
    Username = maps:get(username, State),
    AuthManagerPid = maps:get(auth_manager, State),
    QueueManagerPid = maps:get(queue_manager, State),
    GameSessionPid = maps:get(game_session, State),

    case Status of
        connected ->
            ok;

        authenticated ->
            AuthManagerPid ! {logout, Username, self()};

        waiting ->
            QueueManagerPid ! {leave_queue, Username, self()},
            AuthManagerPid ! {logout, Username, self()};

        in_game ->
            GameSessionPid ! {player_disconnected, Username},
            AuthManagerPid ! {logout, Username, self()}
    end.

number_to_string(N) when is_integer(N) ->
    integer_to_list(N);
number_to_string(N) when is_float(N) ->
    float_to_list(N, [{decimals, 4}, compact]).

serialize_player_line(MyUsername, {Username, X, Y, Radius, Angle, Captures, Mass}) ->
    Tag = case Username =:= MyUsername of
        true -> "me";
        false -> "other"
    end,
    "player " ++ Username ++
    " " ++ number_to_string(X) ++
    " " ++ number_to_string(Y) ++
    " " ++ number_to_string(Radius) ++
    " " ++ number_to_string(Angle) ++
    " " ++ number_to_string(Captures) ++
    " " ++ number_to_string(Mass) ++
    " " ++ Tag.

serialize_food_line({Id, X, Y, Radius}) ->
    "food " ++ number_to_string(Id) ++
    " " ++ number_to_string(X) ++
    " " ++ number_to_string(Y) ++
    " " ++ number_to_string(Radius).

serialize_poison_line({Id, X, Y, Radius}) ->
    "poison " ++ number_to_string(Id) ++
    " " ++ number_to_string(X) ++
    " " ++ number_to_string(Y) ++
    " " ++ number_to_string(Radius).

send_game_state(Socket, MyUsername, Tick, RemainingMs, PlayersData, FoodsData, PoisonsData) ->
    send_line(Socket, "game_state_begin " ++ number_to_string(Tick) ++ " " ++ number_to_string(RemainingMs)),

    lists:foreach(
        fun(PlayerData) ->
            send_line(Socket, serialize_player_line(MyUsername, PlayerData))
        end,
        PlayersData
    ),

    lists:foreach(
        fun(FoodData) ->
            send_line(Socket, serialize_food_line(FoodData))
        end,
        FoodsData
    ),

    lists:foreach(
        fun(PoisonData) ->
            send_line(Socket, serialize_poison_line(PoisonData))
        end,
        PoisonsData
    ),

    send_line(Socket, "game_state_end").