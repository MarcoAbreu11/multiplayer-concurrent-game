-module(scoreboard_manager).
-export([start/0]).

start() ->
    InitialState = #{
        scores => #{}
    },
    spawn(fun() -> loop(InitialState) end).

loop(State) ->
    receive
        {record_win, WinnerUsername} ->
            Scores = maps:get(scores, State),
            CurrentWins = maps:get(WinnerUsername, Scores, 0),
            NewScores = Scores#{
                WinnerUsername => CurrentWins + 1
            },
            NewState = State#{
                scores => NewScores
            },
            loop(NewState);

        {get_top_scores, From} ->
            Scores = maps:get(scores, State),
            SortedScores = lists:sort(
                fun({_, Wins1}, {_, Wins2}) -> Wins1 >= Wins2 end,
                maps:to_list(Scores)
            ),
            From ! {top_scores, SortedScores},
            loop(State);

        stop ->
            ok
    end.
