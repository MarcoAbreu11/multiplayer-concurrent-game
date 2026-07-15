-module(auth_manager).
-export([start/0]).

start() ->
    InitialState = #{
        users => #{},
        online => #{}
    },
    spawn(fun() -> loop(InitialState) end).

loop(State) ->
    receive
        {create_account, Username, Password, From} ->
            Users = maps:get(users, State),

            case maps:is_key(Username, Users) of
                true ->
                    From ! {create_account_result, username_taken},
                    loop(State);

                false ->
                    NewUsers = Users#{
                        Username => Password
                    },
                    NewState = State#{
                        users => NewUsers
                    },
                    From ! {create_account_result, ok},
                    loop(NewState)
            end;

        {login, Username, Password, From} ->
            Users = maps:get(users, State),
            Online = maps:get(online, State),

            case maps:find(Username, Users) of
                error ->
                    From ! {login_result, user_not_found},
                    loop(State);

                {ok, StoredPassword} ->
                    case Password =:= StoredPassword of
                        false ->
                            From ! {login_result, wrong_password},
                            loop(State);

                        true ->
                            case maps:is_key(Username, Online) of
                                true ->
                                    From ! {login_result, already_online},
                                    loop(State);

                                false ->
                                    NewOnline = Online#{
                                        Username => From
                                    },
                                    NewState = State#{
                                        online => NewOnline
                                    },
                                    From ! {login_result, ok},
                                    loop(NewState)
                            end
                    end
            end;

        {logout, Username, From} ->
            Online = maps:get(online, State),
            NewOnline = maps:remove(Username, Online),
            NewState = State#{
                online => NewOnline
            },
            From ! {logout_result, ok},
            loop(NewState);


        {close_account, Username, Password, From} ->
            Users = maps:get(users, State),
            Online = maps:get(online, State),

            case maps:find(Username, Users) of
                error ->
                    From ! {close_account_result, invalid},
                    loop(State);

                {ok, StoredPassword} ->
                    case Password =:= StoredPassword of
                        false ->
                            From ! {close_account_result, invalid},
                            loop(State);

                        true ->
                            NewUsers = maps:remove(Username, Users),
                            NewOnline = maps:remove(Username, Online),
                            NewState = State#{
                                users => NewUsers,
                                online => NewOnline
                            },
                            From ! {close_account_result, ok},
                            loop(NewState)
                    end
            end;
        
        stop ->
            ok
    end.