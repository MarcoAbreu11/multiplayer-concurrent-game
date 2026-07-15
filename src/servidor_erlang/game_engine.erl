-module(game_engine).
-include("game_models.hrl").

-export([
    calculo_raio/1, aplicar_teclas/2, atualizar_fisicas/2, limitar_bordas/1, verificar_colisao_veneno/2, verificar_sobreposicao_comestivel/2,
    verificar_captura_jogador/2, spawn_objeto/1, povoar_espaco/1, garantir_objeto_menores/1, repor_objetos/2, iniciar_jogo/2,processar_tick/2, 
    encontrar_pelo_nome/2, adicionar_tecla/3, remover_tecla/3, terminar_jogo/2, loop/3
]).

calculo_raio(Massa) -> 
    math:sqrt(Massa / math:pi()).

limitar_valor(Valor, Min, Max) ->
    min(Max, max(Min, Valor)).

aplicar_teclas(Jogador, Dt) ->
    Teclas = Jogador#jogador.teclas,
    VelocidadeAngular = Jogador#jogador.vel_angular,
    Angulo = Jogador#jogador.angulo,
    Torque = Jogador#jogador.torque,
    Massa = Jogador#jogador.massa,
    Forca = Jogador#jogador.forca,
    VelX = Jogador#jogador.vel_x,
    VelY = Jogador#jogador.vel_y,

    AceleracaoLinear = Forca / Massa,
    AceleracaoAngular = Torque / Massa,


    %% As teclas esquerda/direita provocam aceleracao angular enquanto estao premidas.
    %% Quando deixam de estar premidas, aplicamos amortecimento para evitar deriva infinita.
    VelAngular0 = case {lists:member(esquerda, Teclas), lists:member(direita, Teclas)} of
        {true, false} -> VelocidadeAngular - AceleracaoAngular * Dt;
        {false, true} -> VelocidadeAngular + AceleracaoAngular * Dt;
        _             -> VelocidadeAngular * ?AMORTECIMENTO_ANGULAR
    end,
    NovaVelAngular = limitar_valor(
        VelAngular0,
        -?VELOCIDADE_ANGULAR_MAXIMA,
        ?VELOCIDADE_ANGULAR_MAXIMA
    ),

    %% A tecla frente provoca aceleracao linear. Sem frente, ha apenas um amortecimento leve.
    {VelX0, VelY0} = case lists:member(frente, Teclas) of
        true -> {
            VelX + AceleracaoLinear * math:cos(Angulo) * Dt,
            VelY + AceleracaoLinear * math:sin(Angulo) * Dt
        };
        false -> {
            VelX * ?AMORTECIMENTO_LINEAR,
            VelY * ?AMORTECIMENTO_LINEAR
        }
    end,

    %% Limite de velocidade para impedir aceleracao ilimitada.
    VelAtual = math:sqrt(VelX0 * VelX0 + VelY0 * VelY0),
    {NovaVelX, NovaVelY} = case VelAtual > ?VELOCIDADE_MAXIMA of
        true -> {
            VelX0 * ?VELOCIDADE_MAXIMA / VelAtual,
            VelY0 * ?VELOCIDADE_MAXIMA / VelAtual
        };
        false -> {VelX0, VelY0}
    end,

    Jogador#jogador{
        vel_angular = NovaVelAngular,
        vel_x = NovaVelX,
        vel_y = NovaVelY
    }.

atualizar_fisicas(Jogador, Dt) -> 
    Angulo = Jogador#jogador.angulo,
    Vel_Angular = Jogador#jogador.vel_angular,

    X_atual = Jogador#jogador.x,
    Y_atual = Jogador#jogador.y,
    Vel_x = Jogador#jogador.vel_x,
    Vel_y = Jogador#jogador.vel_y,

    Novo_Angulo_Raw = Angulo + Vel_Angular * Dt,
    Novo_Angulo_Norm = math:fmod(Novo_Angulo_Raw, 2 * math:pi()),
    Novo_Angulo = if Novo_Angulo_Norm < 0 -> Novo_Angulo_Norm + 2 * math:pi();
                    true -> Novo_Angulo_Norm
                 end,
    Novo_X = X_atual + Vel_x * Dt,
    Novo_Y = Y_atual + Vel_y * Dt,

    Jogador#jogador {
        x = Novo_X,
        y = Novo_Y,
        angulo = Novo_Angulo
    }.

limitar_bordas(Jogador) ->
    X = Jogador#jogador.x,
    Y = Jogador#jogador.y,
    Raio = calculo_raio(Jogador#jogador.massa),

    {NovoX , NovaVelX} = case X - Raio =< 0 of
        true -> {Raio , 0.0};
        false -> {X, Jogador#jogador.vel_x}
    end,

    {NovoX2 , NovaVelX2} = case NovoX + Raio >= ?LARGURA of
        true -> {?LARGURA - Raio , 0.0};
        false -> {NovoX , NovaVelX}
    end,

    {NovoY , NovaVelY} = case Y - Raio =< 0 of
        true -> {Raio , 0.0};
        false -> {Y , Jogador#jogador.vel_y}
    end,

    {NovoY2 , NovaVelY2} = case NovoY + Raio >= ?ALTURA of
        true -> {?ALTURA - Raio , 0.0};
        false -> {NovoY , NovaVelY}
    end,

    Jogador#jogador{
        x = NovoX2,
        y = NovoY2,
        vel_x = NovaVelX2,
        vel_y = NovaVelY2
    }.

verificar_colisao_veneno(Jogador, Venenoso) ->
    X_jogador = Jogador#jogador.x,
    Y_jogador = Jogador#jogador.y,
    Raio_jogador = calculo_raio(Jogador#jogador.massa),

    X_Venenoso = Venenoso#objeto.x,
    Y_Venenoso = Venenoso#objeto.y,
    Raio_Venenoso = calculo_raio(Venenoso#objeto.massa),

    DistQuad  = math:pow(X_Venenoso - X_jogador, 2) + math:pow(Y_Venenoso - Y_jogador, 2),
    SomaRaiosQuad = math:pow(Raio_Venenoso + Raio_jogador, 2),

    case DistQuad < SomaRaiosQuad of
        true -> {Jogador#jogador{ massa = max(?MASSA_MINIMA , Jogador#jogador.massa - Venenoso#objeto.massa)  }, remover};
        false -> {Jogador, manter}
    end.

verificar_sobreposicao_comestivel(Jogador, Comestivel) ->
    X_jogador = Jogador#jogador.x,
    Y_jogador = Jogador#jogador.y,
    Raio_jogador = calculo_raio(Jogador#jogador.massa),

    X_comestivel = Comestivel#objeto.x,
    Y_comestivel = Comestivel#objeto.y,
    Raio_comestivel = calculo_raio(Comestivel#objeto.massa),

    DistanciaPontos = math:sqrt( math:pow(X_jogador - X_comestivel , 2) + math:pow(Y_jogador - Y_comestivel , 2) ),

    case (DistanciaPontos + Raio_comestivel =< Raio_jogador)   of
        true -> {Jogador#jogador{ massa = Jogador#jogador.massa + Comestivel#objeto.massa} , remover};
        false -> {Jogador, manter}
    end.

verificar_captura_jogador(Jogador1, Jogador2) -> 
    XJ1 = Jogador1#jogador.x,
    YJ1 = Jogador1#jogador.y,
    RaioJ1 = calculo_raio(Jogador1#jogador.massa),
    MassaJ1 = Jogador1#jogador.massa,

    XJ2 = Jogador2#jogador.x,
    YJ2 = Jogador2#jogador.y,
    RaioJ2 = calculo_raio(Jogador2#jogador.massa),
    MassaJ2 = Jogador2#jogador.massa,

    Distancia = math:sqrt(math:pow(XJ1 - XJ2, 2) + math:pow(YJ1 - YJ2, 2)),
    SobreposicaoCompleta = Distancia =< max(RaioJ1, RaioJ2) - min(RaioJ1, RaioJ2)*0.99,

    case SobreposicaoCompleta of
        true when RaioJ1 < RaioJ2 ->
            %% Jogador2 captura Jogador1: ganha 1/4 da massa do Jogador1.
            PerdaJ1 = MassaJ1 / 4,
            NovaMassaJ1 = max(?MASSA_MINIMA, MassaJ1 - PerdaJ1),
            NovoRaioJ1 = calculo_raio(NovaMassaJ1),
            NovoXJ1 = NovoRaioJ1 + rand:uniform() * (?LARGURA - 2 * NovoRaioJ1),
            NovoYJ1 = NovoRaioJ1 + rand:uniform() * (?ALTURA - 2 * NovoRaioJ1),
            {
                Jogador1#jogador{massa = NovaMassaJ1, x = NovoXJ1, y = NovoYJ1, vel_x = 0.0, vel_y = 0.0},
                Jogador2#jogador{massa = MassaJ2 + PerdaJ1, capturas = Jogador2#jogador.capturas + 1}
            };

        true when RaioJ2 < RaioJ1 ->
            %% Jogador1 captura Jogador2: ganha 1/4 da massa do Jogador2.
            PerdaJ2 = MassaJ2 / 4,
            NovaMassaJ2 = max(?MASSA_MINIMA, MassaJ2 - PerdaJ2),
            NovoRaioJ2 = calculo_raio(NovaMassaJ2),
            NovoXJ2 = NovoRaioJ2 + rand:uniform() * (?LARGURA - 2 * NovoRaioJ2),
            NovoYJ2 = NovoRaioJ2 + rand:uniform() * (?ALTURA - 2 * NovoRaioJ2),
            {
                Jogador1#jogador{massa = MassaJ1 + PerdaJ2, capturas = Jogador1#jogador.capturas + 1},
                Jogador2#jogador{massa = NovaMassaJ2, x = NovoXJ2, y = NovoYJ2, vel_x = 0.0, vel_y = 0.0}
            };

        _ ->
            %% Sem captura se nao houver sobreposicao completa ou se tiverem exatamente o mesmo tamanho.
            {Jogador1, Jogador2}
    end.

spawn_objeto(Tipo) -> 
    Massa = ?MASSA_MINIMA_OBJETO + rand:uniform() * (?MASSA_MAXIMA_OBJETO - ?MASSA_MINIMA_OBJETO),
    RaioObjeto = calculo_raio(Massa),

    X = RaioObjeto + rand:uniform() * (?LARGURA - 2 * RaioObjeto),
    Y = RaioObjeto + rand:uniform() * (?ALTURA - 2 * RaioObjeto),

    ID = erlang:unique_integer([positive, monotonic]),

    #objeto{id = ID, x = X, y = Y, tipo = Tipo, massa = Massa}.

povoar_espaco(EstadoJogo) ->
    ObjetosComestiveis = lists:foldl(
        fun(_,Acc) -> Objeto = spawn_objeto(comestivel), Acc#{Objeto#objeto.id => Objeto} end,
        #{}, % segundo argumento
        lists:seq(1,?NUM_OBJETOS_COMESTIVEIS) % primeiro argumento
    ),

    ObjetosVenenosos = lists:foldl(
        fun(_,Acc) -> Objeto = spawn_objeto(venenoso), Acc#{Objeto#objeto.id => Objeto} end,
        #{},
        lists:seq(1,?NUM_OBJETOS_VENENOS)
    ),

    EstadoJogo#estado_jogo{comestivel = ObjetosComestiveis , venenoso = ObjetosVenenosos}.

garantir_objeto_menores(EstadoJogo) ->
    Jogadores = EstadoJogo#estado_jogo.jogadores,
    Comestiveis = EstadoJogo#estado_jogo.comestivel,

    ListaJogadores = maps:values(Jogadores),
    Massas = lists:foldl(fun(Jogador,Lista) -> [Jogador#jogador.massa | Lista] end, [], ListaJogadores),
    MassaMinimaJogador = lists:min(Massas),

    ExiteMenor = lists:any(fun(Objeto) -> Objeto#objeto.massa < MassaMinimaJogador end, maps:values(Comestiveis)),

    case ExiteMenor of
        true -> EstadoJogo;
        false ->
            ObjetosComestiveisNovos = lists:foldl(
                fun(_,Acc) -> Massa = ?MASSA_MINIMA_OBJETO + rand:uniform() * (MassaMinimaJogador - ?MASSA_MINIMA_OBJETO),
                    ID = erlang:unique_integer([positive, monotonic]),RaioObjeto = calculo_raio(Massa),X = RaioObjeto + rand:uniform() * (?LARGURA - 2 * RaioObjeto),
                    Y = RaioObjeto + rand:uniform() * (?ALTURA - 2 * RaioObjeto),
                    Acc#{ID => #objeto{id = ID, x = X, y = Y, tipo = comestivel, massa = Massa}}
                end,
                #{},
                lists:seq(1,5)
            ),
            ComestiveisAtuais = EstadoJogo#estado_jogo.comestivel,
            EstadoJogo#estado_jogo{comestivel = maps:merge(ComestiveisAtuais, ObjetosComestiveisNovos)}
    end.

repor_objetos(EstadoJogo, Tipo) ->
    case Tipo == venenoso of
        true -> 
            NovoObjeto = spawn_objeto(Tipo),
            ID = NovoObjeto#objeto.id,
            VenenosoAtuais = EstadoJogo#estado_jogo.venenoso,
            EstadoJogo#estado_jogo{venenoso = VenenosoAtuais#{ID => NovoObjeto}};
        false ->
            NovoObjeto = spawn_objeto(Tipo), 
            ID = NovoObjeto#objeto.id,
            ComestiveisAtuais = EstadoJogo#estado_jogo.comestivel,
            EstadoAtualizado = EstadoJogo#estado_jogo{comestivel = ComestiveisAtuais#{ID => NovoObjeto}},

            NovoEstadoJogo = garantir_objeto_menores(EstadoAtualizado),
            NovoEstadoJogo
    end.

%recebe uma lista de jogadores
iniciar_jogo(Jogadores, GameSessionPid) ->
    DicJogadores = lists:foldl(
        fun(Jogador, AccJogadores) -> 
            Raio = calculo_raio(Jogador#jogador.massa),
            X = Raio + rand:uniform() * (?LARGURA - 2*Raio),
            Y = Raio + rand:uniform() * (?ALTURA - 2*Raio),
            NovoJogador = Jogador#jogador{x = X, y = Y},
            AccJogadores#{Jogador#jogador.id => NovoJogador} 
        end, 
        #{}, 
        Jogadores
    ),
    Agora = erlang:monotonic_time(millisecond),
    TempoFim = Agora + ?DURACAO_JOGO,

    NovoEstadoJogo = #estado_jogo{jogadores = DicJogadores, tempo_fim = TempoFim, estado = running},
    EstadoJogo = povoar_espaco(NovoEstadoJogo),
    EstadoJogoInicial = EstadoJogo#estado_jogo{tick = 1},

    GameSessionPid ! {game_snapshot, 1, EstadoJogoInicial},

    PID = spawn_link(fun() -> loop(EstadoJogoInicial, Agora, GameSessionPid) end),
    PID.

processar_tick(EstadoJogo, Dt) ->
    Jogadores = EstadoJogo#estado_jogo.jogadores,
    Comestiveis = EstadoJogo#estado_jogo.comestivel,
    Venenosos = EstadoJogo#estado_jogo.venenoso,

    JogadorAtualizados0 = 
        maps:map(
            fun(_, Jogador) -> 
                aplicar_teclas(Jogador, Dt) 
            end, 
            Jogadores
        ),

    JogadorAtualizados1 = 
        maps:map(
            fun(_,Jogador) -> 
                atualizar_fisicas(Jogador, Dt) 
            end, 
            JogadorAtualizados0
    ),

    JogadorAtualizados2 = 
        maps:map(
            fun(_,Jogador) -> 
                limitar_bordas(Jogador) 
            end,
            JogadorAtualizados1
    ),

    {VenenosFinais, JogadorAtualizados3} = 
        maps:fold(
            fun(IdJogador, Jogador, {MapVenenos, AccJogadores}) -> 
                {VenenosAposJogador, JogadorAtualizado} = 
                    maps:fold(
                        fun(IdVenenoso, Venenoso, {DicionarioVenenoso, J}) ->
                            {NovoJ, Acao} = verificar_colisao_veneno(J, Venenoso),
                            case Acao of
                                remover -> {maps:remove(IdVenenoso, DicionarioVenenoso), NovoJ};
                                manter  -> {DicionarioVenenoso, NovoJ}
                            end
                        end,
                        {MapVenenos, Jogador},
                        MapVenenos
                    ),
                {VenenosAposJogador, AccJogadores#{IdJogador => JogadorAtualizado}}
            end, 
            {Venenosos, #{}},
            JogadorAtualizados2
    ),
    
    {ComestiveisFinais, JogadorAtualizados4} = 
        maps:fold(
            fun(IdJogador, Jogador, {MapComestivel, AccJogadores}) ->
                {ComestiveisAposJogador, NovoJogador} = 
                    maps:fold(
                        fun(IdComestivel, Comestivel, {DicionarioComestivel, J}) -> 
                            {NovoJ, Acao} = verificar_sobreposicao_comestivel(J, Comestivel),
                            case Acao of
                                remover -> {maps:remove(IdComestivel, DicionarioComestivel), NovoJ};
                                manter  -> {DicionarioComestivel, NovoJ}
                            end
                        end,
                        {MapComestivel, Jogador},
                        MapComestivel
                ),
                {ComestiveisAposJogador, AccJogadores#{IdJogador => NovoJogador}}
            end,
            {Comestiveis, #{}},
            JogadorAtualizados3
    ),
    
    VenenososRetirados = maps:size(Venenosos) - maps:size(VenenosFinais),
    ComestiveisRetirados = maps:size(Comestiveis) - maps:size(ComestiveisFinais),

    ParesIdsJogadores = [{Id1,Id2} || Id1 <- maps:keys(JogadorAtualizados4), Id2 <- maps:keys(JogadorAtualizados4), Id1 < Id2],

    JogadorAtualizados5 = 
        lists:foldl(
            fun({Id1, Id2}, AccJogadores) -> 
                Jogador1 = maps:get(Id1, AccJogadores),
                Jogador2 = maps:get(Id2, AccJogadores),
                {NovoJogador1, NovoJogador2} = verificar_captura_jogador(Jogador1, Jogador2),
                AccJogadores#{Id1 => NovoJogador1, Id2 => NovoJogador2}
            end, 
            JogadorAtualizados4, 
            ParesIdsJogadores
    ),

    EstadoJogoFinal = EstadoJogo#estado_jogo{jogadores = JogadorAtualizados5, comestivel = ComestiveisFinais, venenoso = VenenosFinais},

    EstadoComestivelJogo = lists:foldl(fun(_, AccJogo) -> repor_objetos(AccJogo, comestivel) end, EstadoJogoFinal, lists:seq(1, ComestiveisRetirados)),
    EstadoVenenosoJogo = lists:foldl(fun(_, AccJogo) -> repor_objetos(AccJogo, venenoso) end, EstadoComestivelJogo, lists:seq(1, VenenososRetirados)),
    EstadoVenenosoJogo.

encontrar_pelo_nome(Nome,Jogadores) ->
    io:format("Procurando: ~p nos jogadores: ~p~n", [Nome, maps:keys(Jogadores)]),
    maps:fold(
        fun(IdJogador, Jogador, Acc) ->
           io:format("Nome mapa bytes: ~w, Procurado bytes: ~w~n", [Jogador#jogador.nome, Nome]),
            case Jogador#jogador.nome == Nome of
                true -> {IdJogador, Jogador};
                false -> Acc
            end
        end,
        undefined,
        Jogadores
    ).

adicionar_tecla(EstadoJogo, Username, Tecla) ->
    io:format("Input recebido: ~p ~p~n", [Username, Tecla]),
    Jogadores = EstadoJogo#estado_jogo.jogadores,
    Resultado = encontrar_pelo_nome(Username, Jogadores),
    io:format("Resultado encontrar: ~p~n", [Resultado]),
    case encontrar_pelo_nome(Username, Jogadores) of
        undefined -> 
            EstadoJogo; 
        {IdJogador, Jogador} ->
            TeclasAtuais = Jogador#jogador.teclas,
            case lists:member(Tecla, TeclasAtuais) of
                true -> 
                    EstadoJogo;
                false ->
                    NovoJogador = Jogador#jogador{teclas = [Tecla | TeclasAtuais]},
                    EstadoJogo#estado_jogo{jogadores = Jogadores#{IdJogador => NovoJogador}}
            end
    end.

remover_tecla(EstadoJogo, Username, Tecla) ->
    Jogadores = EstadoJogo#estado_jogo.jogadores,
    case encontrar_pelo_nome(Username, Jogadores) of
        undefined -> 
            EstadoJogo; 
        {IdJogador, Jogador} ->
            TeclasAtuais = Jogador#jogador.teclas,
            case lists:member(Tecla, TeclasAtuais) of
                true ->
                    NovasTeclas = lists:delete(Tecla, TeclasAtuais),
                    NovoJogador = Jogador#jogador{teclas = NovasTeclas},
                    EstadoJogo#estado_jogo{jogadores = Jogadores#{IdJogador => NovoJogador}};
                false ->
                    EstadoJogo
            end
    end.

terminar_jogo(EstadoJogo, GameSessionPid) -> 
    Jogadores = maps:values(EstadoJogo#estado_jogo.jogadores),
    JogadoresOrdenados = lists:sort(fun(J1, J2) -> J1#jogador.capturas >= J2#jogador.capturas end, Jogadores),
    case JogadoresOrdenados of
        [] ->
            GameSessionPid ! {game_result, tie},
            {empate, EstadoJogo#estado_jogo{estado = finished}};

        [J] when J#jogador.capturas =:= 0 ->
            GameSessionPid ! {game_result, tie},
            {empate, EstadoJogo#estado_jogo{estado = finished}};

        [Vencedor] ->
            GameSessionPid ! {game_result, {winner, Vencedor#jogador.nome, Vencedor#jogador.capturas}},
            {vencedor, EstadoJogo#estado_jogo{estado = finished}};

        [J1, J2 | _] when J1#jogador.capturas =:= J2#jogador.capturas ->
            GameSessionPid ! {game_result, tie},
            {empate, EstadoJogo#estado_jogo{estado = finished}};

        [Vencedor | _] ->
            GameSessionPid ! {game_result, {winner, Vencedor#jogador.nome, Vencedor#jogador.capturas}},
            {vencedor, EstadoJogo#estado_jogo{estado = finished}}
    end.

loop(EstadoJogo, UltimoTick, GameSessionPid) ->
    Agora = erlang:monotonic_time(millisecond),
    TempoFim = EstadoJogo#estado_jogo.tempo_fim,

    case Agora >= TempoFim of 
        true -> terminar_jogo(EstadoJogo, GameSessionPid);
        false ->
            TempoDecorrido = Agora - UltimoTick,
            TempoEspera = max(0, ?TICK_MS - TempoDecorrido),

            receive 
                {player_input, Username, Tecla, down} ->
                    io:format("Engine recebeu: ~p ~p down~n", [Username, Tecla]),
                    NovoEstado = adicionar_tecla(EstadoJogo, Username, Tecla),
                    loop(NovoEstado, UltimoTick, GameSessionPid);

                {player_input, Username, Tecla, up} ->
                    NovoEstado = remover_tecla(EstadoJogo, Username, Tecla),
                    loop(NovoEstado, UltimoTick, GameSessionPid);
                {abort_game, player_disconnected, _Username} -> 
                    ok
            after TempoEspera ->
                io:format("Tick com teclas: ~p~n", [maps:map(fun(_,J) -> J#jogador.teclas end, EstadoJogo#estado_jogo.jogadores)]),
                NovoAgora = erlang:monotonic_time(millisecond),
                Dt = (NovoAgora - UltimoTick) / 1000.0,
                NovoEstadoJogo = processar_tick(EstadoJogo, Dt),
                NovoTick = NovoEstadoJogo#estado_jogo.tick + 1,
                EstadoComTick = NovoEstadoJogo#estado_jogo{tick = NovoTick},
                GameSessionPid ! {game_snapshot, NovoTick, EstadoComTick},
                loop(EstadoComTick, NovoAgora, GameSessionPid)
            end
    end.

