-define(LARGURA, 800).
-define(ALTURA, 600).

-define(MASSA_MINIMA, 200).
-define(MASSA_INICIAL, 500).
-define(MAXIMO_JOGOS, 4).
-define(TICK_MS, 50).
-define(DURACAO_JOGO, 120000). % milisegundos

%% Limites simples para manter a simulacao estavel e jogavel.
-define(VELOCIDADE_MAXIMA, 200.0).          % reduz velocidade máxima
-define(VELOCIDADE_ANGULAR_MAXIMA, 4.0).    % reduz velocidade angular máxima
-define(AMORTECIMENTO_LINEAR, 0.10).        % era 0.98 — para mais rápido
-define(AMORTECIMENTO_ANGULAR, 0.15).

-define(MASSA_MINIMA_OBJETO, 100).
-define(MASSA_MAXIMA_OBJETO, 300).

-define(NUM_OBJETOS_COMESTIVEIS, 20).
-define(NUM_OBJETOS_VENENOS, 15).

-record(jogador, {
    id,
    pid,
    nome,
    x = 0.0,
    y = 0.0,
    vel_x = 0.0,
    vel_y = 0.0,
    angulo = 0.0,
    vel_angular = 0.0,
    massa = ?MASSA_INICIAL,
    torque = 3000000000000000.0,    % era 2.13
    forca = 10000000000000000.0,     % era 4.23
    capturas = 0,
    teclas = []
}).

-record(objeto, {
    id,
    x = 0.0,
    y = 0.0,
    tipo,
    massa = 0.0
}).

-record(estado_jogo , {
    id,
    jogadores = #{}, % id_jogador -> jogador
    comestivel = #{}, % id_comestivel -> comestivel
    venenoso = #{},  % id_venenoso -> venenoso
    estado = waiting, % waiting | running | finished
    tempo_fim,
    tick = 0
}).