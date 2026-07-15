-module(game_session).
-include("game_models.hrl").

-export([start/4]).

start(GameId, Players, GameSupervisorPid, ScoreboardManagerPid) ->
    spawn(fun() ->
        EnginePlayers = build_engine_players(Players),
        EnginePid = game_engine:iniciar_jogo(EnginePlayers, self()),

        State = #{
            game_id => GameId,
            players => Players,
            game_supervisor => GameSupervisorPid,
            scoreboard_manager => ScoreboardManagerPid,
            engine_pid => EnginePid
        },

        loop(State)
    end).

build_engine_players(Players) ->
    IndexedPlayers = lists:zip(lists:seq(1, length(Players)), Players),
    lists:map(
        fun({Id, {Username, SessionPid}}) ->
            #jogador{
                id = Id,
                pid = SessionPid,
                nome = Username
            }
        end,
        IndexedPlayers
    ).

loop(State) ->
    receive
        {player_input, Username, Key, Action} ->
            EnginePid = maps:get(engine_pid, State),
            EnginePid ! {player_input, Username, Key, Action},
            loop(State);

        {game_snapshot, Tick, EstadoJogo} ->
            SnapshotMsg = build_snapshot(Tick, EstadoJogo),
            Players = maps:get(players, State),
            broadcast_to_players(SnapshotMsg, Players),
            loop(State);

        {game_result, Result} ->
            Players = maps:get(players, State),
            GameId = maps:get(game_id, State),
            GameSupervisorPid = maps:get(game_supervisor, State),
            ScoreboardManagerPid = maps:get(scoreboard_manager, State),

            case Result of
                tie ->
                    broadcast_to_players({game_over, tie}, Players),
                    GameSupervisorPid ! {game_finished, GameId},
                    ok;

                {winner, WinnerUsername, Captures} ->
                    ScoreboardManagerPid ! {record_win, WinnerUsername},
                    broadcast_to_players(
                        {game_over, {winner, WinnerUsername, Captures}},
                        Players
                    ),
                    GameSupervisorPid ! {game_finished, GameId},
                    ok
            end;

        {player_disconnected, Username} ->
            EnginePid = maps:get(engine_pid, State),
            Players = maps:get(players, State),
            GameId = maps:get(game_id, State),
            GameSupervisorPid = maps:get(game_supervisor, State),

            RemainingPlayers = remove_player(Username, Players),

            EnginePid ! {abort_game, player_disconnected, Username},
            broadcast_to_players(
                {game_aborted, player_disconnected, Username},
                RemainingPlayers
            ),
            GameSupervisorPid ! {game_finished, GameId},
            ok
    end.


extract_players(EstadoJogo) ->
    JogadoresMap = EstadoJogo#estado_jogo.jogadores,
    Jogadores = maps:values(JogadoresMap),
    lists:map(
        fun(Jogador) ->
            Username = Jogador#jogador.nome,
            X = Jogador#jogador.x,
            Y = Jogador#jogador.y,
            Mass = Jogador#jogador.massa,
            Radius = game_engine:calculo_raio(Mass),
            Angle = Jogador#jogador.angulo,
            Captures = Jogador#jogador.capturas,
            {Username, X, Y, Radius, Angle, Captures, Mass}
        end,
        Jogadores
    ).

extract_foods(EstadoJogo) ->
    FoodsMap = EstadoJogo#estado_jogo.comestivel,
    Foods = maps:values(FoodsMap),
    lists:map(
        fun(Objeto) ->
            Id = Objeto#objeto.id,
            X = Objeto#objeto.x,
            Y = Objeto#objeto.y,
            Radius = game_engine:calculo_raio(Objeto#objeto.massa),
            {Id, X, Y, Radius}
        end,
        Foods
    ).

extract_poisons(EstadoJogo) ->
    PoisonsMap = EstadoJogo#estado_jogo.venenoso,
    Poisons = maps:values(PoisonsMap),
    lists:map(
        fun(Objeto) ->
            Id = Objeto#objeto.id,
            X = Objeto#objeto.x,
            Y = Objeto#objeto.y,
            Radius = game_engine:calculo_raio(Objeto#objeto.massa),
            {Id, X, Y, Radius}
        end,
        Poisons
    ).

build_snapshot(Tick, EstadoJogo) ->
    PlayersData = extract_players(EstadoJogo),
    FoodsData = extract_foods(EstadoJogo),
    PoisonsData = extract_poisons(EstadoJogo),
    RemainingMs = max(0, EstadoJogo#estado_jogo.tempo_fim - erlang:monotonic_time(millisecond)),
    {game_state, Tick, RemainingMs, PlayersData, FoodsData, PoisonsData}.

broadcast_to_players(Message, Players) ->
    lists:foreach(
        fun({_Username, SessionPid}) ->
            SessionPid ! Message
        end,
        Players
    ).

remove_player(DisconnectedUsername, Players) ->
    lists:filter(
        fun({Username, _SessionPid}) ->
            Username =/= DisconnectedUsername
        end,
        Players
    ).