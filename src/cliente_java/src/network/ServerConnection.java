package network;

import state.*;

import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.*;

/**
 * Gere a ligação TCP ao servidor Erlang.
 *
 * Responsabilidades:
 * - Abrir socket TCP.
 * - Enviar mensagens através de uma fila de escrita.
 * - Ler mensagens numa thread separada.
 * - Atualizar o GameState, que é lido pelo Processing.
 *
 * Nota importante:
 * O game_state do servidor Erlang é multi-linha:
 *   game_state_begin tick tempo_restante_ms
 *   player username x y radius angle captures mass me|other
 *   food ...
 *   poison ...
 *   game_state_end
 *
 * Por isso, este cliente acumula as linhas entre begin/end e só atualiza
 * o GameState quando recebe game_state_end.
 */
public class ServerConnection {

    private static final int CONNECT_TIMEOUT_MS     = 5_000;
    private static final int READ_TIMEOUT_MS = 300_000;
    private static final int MAX_RECONNECT_DELAY_MS = 16_000;
    private static final int MAX_RECONNECT_ATTEMPTS = 5;

    private final String host;
    private final int port;
    private final GameState gameState;

    private Socket socket;
    private BufferedReader reader;
    private PrintWriter writer;

    private final BlockingQueue<String> sendQueue = new LinkedBlockingQueue<>();

    private volatile boolean running   = false;
    private volatile boolean connected = false;

    private Thread readerThread;
    private Thread writerThread;
    private Thread reconnectThread;

    // Acumulador de estado de jogo entre game_state_begin e game_state_end.
    private final List<String> gameStateBuffer = new ArrayList<>();
    private boolean inGameState = false;

    public ServerConnection(String host, int port, GameState gameState) {
        this.host = host;
        this.port = port;
        this.gameState = gameState;
    }

    // ----------------------------------------------------------------
    //  Ligação
    // ----------------------------------------------------------------

    public void connect() throws IOException {
        running = true;
        doConnect();
        startWriterThread();
        startReaderThread();
    }

    private void doConnect() throws IOException {
        socket = new Socket();
        socket.connect(new InetSocketAddress(host, port), CONNECT_TIMEOUT_MS);
        socket.setSoTimeout(READ_TIMEOUT_MS);

        reader = new BufferedReader(new InputStreamReader(socket.getInputStream(), "UTF-8"));
        writer = new PrintWriter(new OutputStreamWriter(socket.getOutputStream(), "UTF-8"), true);

        connected = true;
        gameState.setLastError(null);
        System.out.println("[ServerConnection] Ligado a " + host + ":" + port);
    }

    /** Enfileira mensagem para envio. Não bloqueia a UI. */
    public void send(String message) {
        if (running && message != null) {
            sendQueue.offer(message);
        }
    }

    /** Fecha a ligação. O fecho do socket também é tratado pelo servidor como cleanup. */
    public void disconnect() {
        // Tenta enviar logout diretamente antes de fechar o socket.
        sendDirect(MessageProtocol.logout());

        running = false;
        connected = false;

        closeSocket();

        if (readerThread    != null) readerThread.interrupt();
        if (writerThread    != null) writerThread.interrupt();
        if (reconnectThread != null) reconnectThread.interrupt();

        System.out.println("[ServerConnection] Desligado.");
    }

    public boolean isConnected() {
        return connected;
    }

    private void sendDirect(String message) {
        try {
            if (connected && writer != null && message != null) {
                writer.print(message);
                writer.flush();
            }
        } catch (Exception ignored) {}
    }

    // ----------------------------------------------------------------
    //  Thread de leitura
    // ----------------------------------------------------------------

    private void startReaderThread() {
        readerThread = new Thread(() -> {
            while (running) {
                try {
                    String line;
                    while (running && connected && (line = reader.readLine()) != null) {
                        System.out.println("[RX] " + line);
                        handleLine(line);
                    }

                    if (running) {
                        handleConnectionLost("Servidor fechou a ligação.");
                    }

                } catch (SocketTimeoutException e) {
                    if (running) {
                        handleConnectionLost("Timeout: sem dados do servidor há 30s.");
                    }

                } catch (IOException e) {
                    if (running) {
                        handleConnectionLost("Erro de rede: " + e.getMessage());
                    }
                }

                if (running) {
                    waitForReconnect();
                }
            }
        }, "ReaderThread");

        readerThread.setDaemon(true);
        readerThread.start();
    }

    // ----------------------------------------------------------------
    //  Thread de escrita
    // ----------------------------------------------------------------

    private void startWriterThread() {
        writerThread = new Thread(() -> {
            while (running) {
                try {
                    String msg = sendQueue.take();

                    if (!connected || writer == null) {
                        continue;
                    }

                    writer.print(msg);
                    writer.flush();

                    if (writer.checkError()) {
                        handleConnectionLost("Erro ao escrever no socket.");
                    } else {
                        System.out.println("[TX] " + msg.trim());
                    }

                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }, "WriterThread");

        writerThread.setDaemon(true);
        writerThread.start();
    }

    // ----------------------------------------------------------------
    //  Reconexão automática
    // ----------------------------------------------------------------

    private void handleConnectionLost(String reason) {
        if (!connected) return;

        connected = false;
        closeSocket();

        System.err.println("[ServerConnection] Ligação perdida: " + reason);
        // Uma reconexao TCP cria uma nova connection_session no servidor Erlang.
        // Portanto, a sessao anterior deixa de ser valida: limpamos estado local
        // e obrigamos o utilizador a fazer login novamente.
        sendQueue.clear();
        gameState.setMyId(null);
        gameState.clearGameData();
        gameState.setLastError("Ligação perdida. A tentar reconectar...");
        gameState.setPhase(GamePhase.MENU);
        gameState.setQueuePosition(0);

        startReconnectThread();
    }

    private void startReconnectThread() {
        if (reconnectThread != null && reconnectThread.isAlive()) return;

        reconnectThread = new Thread(() -> {
            int delay = 1000;
            int attempt = 0;

            while (running && !connected && attempt < MAX_RECONNECT_ATTEMPTS) {
                attempt++;
                gameState.setLastError("A reconectar... (tentativa " + attempt + "/" + MAX_RECONNECT_ATTEMPTS + ")");

                try {
                    Thread.sleep(delay);
                } catch (InterruptedException e) {
                    return;
                }

                try {
                    doConnect();
                    gameState.setMyId(null);
                    gameState.clearGameData();
                    gameState.setPhase(GamePhase.MENU);
                    gameState.setLastError("Reconectado. Faz login novamente.");
                    System.out.println("[Reconnect] Reconectado com sucesso. Login necessario.");
                    return;

                } catch (IOException e) {
                    System.err.println("[Reconnect] Falhou: " + e.getMessage());
                    delay = Math.min(delay * 2, MAX_RECONNECT_DELAY_MS);
                }
            }

            if (!connected) {
                running = false;
                gameState.setLastError("Não foi possível reconectar. Reinicia o cliente.");
            }
        }, "ReconnectThread");

        reconnectThread.setDaemon(true);
        reconnectThread.start();
    }

    private void waitForReconnect() {
        while (running && !connected) {
            try {
                Thread.sleep(500);
            } catch (InterruptedException e) {
                return;
            }
        }
    }

    private void closeSocket() {
        try {
            if (socket != null && !socket.isClosed()) {
                socket.close();
            }
        } catch (IOException ignored) {}
    }

    // ----------------------------------------------------------------
    //  Dispatcher de linhas recebidas
    // ----------------------------------------------------------------

    private void handleLine(String raw) {
        MessageProtocol.Message msg = MessageProtocol.parse(raw);
        String[] p = msg.parts;

        // Início de snapshot multi-linha.
        if (msg.type == MessageProtocol.MessageType.GAME_STATE_BEGIN) {
            inGameState = true;
            gameStateBuffer.clear();
            // Formato novo: game_state_begin tick tempo_restante_ms
            if (p.length >= 3) {
                try {
                    gameState.setTimeRemainingMs(Integer.parseInt(p[2]));
                } catch (NumberFormatException ignored) {}
            }
            return;
        }

        // Durante snapshot: acumula linhas até game_state_end.
        if (inGameState) {
            if (msg.type == MessageProtocol.MessageType.GAME_STATE_END) {
                inGameState = false;
                flushGameState();
            } else {
                gameStateBuffer.add(raw.trim());
            }
            return;
        }

        // Mensagens normais fora do snapshot.
        switch (msg.type) {

            case CREATE_ACCOUNT_OK:
                gameState.setLastError(null);
                break;

            case CREATE_ACCOUNT_ERROR:
                gameState.setLastError("Erro de registo: " + arg(p, 1));
                break;

            case LOGIN_OK:
                // login_ok username
                if (p.length >= 2) {
                    gameState.setMyId(p[1]);
                }
                gameState.setLastError(null);
                gameState.setPhase(GamePhase.MENU);
                break;

            case LOGIN_ERROR:
                gameState.setLastError("Erro de login: " + arg(p, 1));
                break;

            case LOGOUT_OK:
                gameState.setMyId(null);
                gameState.setQueuePosition(0);
                gameState.setPhase(GamePhase.MENU);
                gameState.setLastError(null);
                break;

            case CLOSE_ACCOUNT_OK:
                gameState.setMyId(null);
                gameState.setQueuePosition(0);
                gameState.setPhase(GamePhase.MENU);
                gameState.setLastError(null);
                break;

            case CLOSE_ACCOUNT_ERROR:
                gameState.setLastError("Erro ao cancelar registo: " + arg(p, 1));
                break;

            case JOIN_QUEUE_OK:
                gameState.setQueuePosition(1);
                gameState.setPhase(GamePhase.WAITING);
                gameState.setLastError(null);
                send(MessageProtocol.topScores());
                break;

            case JOIN_QUEUE_ERROR:
                gameState.setLastError("Erro ao entrar na fila: " + arg(p, 1));
                break;

            case LEAVE_QUEUE_OK:
                gameState.setQueuePosition(0);
                gameState.setPhase(GamePhase.MENU);
                gameState.setLastError(null);
                break;

            case LEAVE_QUEUE_ERROR:
                gameState.setLastError("Erro ao sair da fila: " + arg(p, 1));
                break;

            case TOP_SCORES:
                parseTopScores(p);
                break;

            case GAME_STARTED:
                // game_started gameId
                // O próximo game_config/snapshot coloca a fase PLAYING.
                gameState.setQueuePosition(0);
                break;

            case GAME_CONFIG:
                // game_config width height tickMs
                parseGameConfig(p);
                gameState.setPhase(GamePhase.PLAYING);
                break;

            case GAME_OVER:
                parseGameOver(p);
                break;

            case GAME_ABORTED:
                gameState.setLastError("Jogo abortado: jogador desligou-se.");
                gameState.setQueuePosition(0);
                gameState.setPhase(GamePhase.MENU);
                break;

            case ERROR:
                // Evita mostrar erro visual quando um pedido de top_scores chega atrasado
                // depois de o jogador já ter saído da sala de espera.
                if (p.length >= 3 && p[1].equals("invalid_state") && p[2].equals("top_scores")) {
                    break;
                }
                gameState.setLastError("Erro do servidor: " + joinArgs(p, 1));
                break;

            default:
                System.err.println("[ServerConnection] Linha desconhecida: " + raw);
                break;
        }
    }

    private String arg(String[] p, int idx) {
        return p.length > idx ? p[idx] : "desconhecido";
    }

    private String joinArgs(String[] p, int start) {
        if (p.length <= start) return "desconhecido";
        StringBuilder sb = new StringBuilder();
        for (int i = start; i < p.length; i++) {
            if (i > start) sb.append(' ');
            sb.append(p[i]);
        }
        return sb.toString();
    }

    // ----------------------------------------------------------------
    //  Parsing de game_config
    // ----------------------------------------------------------------

    private void parseGameConfig(String[] p) {
        if (p.length < 3) return;

        try {
            int width = Integer.parseInt(p[1]);
            int height = Integer.parseInt(p[2]);
            gameState.setGameConfig(width, height);
        } catch (NumberFormatException ignored) {}
    }

    // ----------------------------------------------------------------
    //  Parsing do bloco game_state acumulado
    // ----------------------------------------------------------------

    private void flushGameState() {
        List<PlayerData> players = new ArrayList<>();
        List<ObjectData> objects = new ArrayList<>();
        int myScore = 0;

        for (String line : gameStateBuffer) {
            String[] p = line.trim().split("\\s+");
            if (p.length == 0) continue;

            switch (p[0]) {
                case "player":
                    // Formato novo: player username x y radius angle captures mass me|other
                    // Mantem compatibilidade com o formato antigo sem massa explicita.
                    if (p.length >= 8) {
                        try {
                            String id    = p[1];
                            float x      = Float.parseFloat(p[2]);
                            float y      = Float.parseFloat(p[3]);
                            float radius = Float.parseFloat(p[4]);
                            float angle  = Float.parseFloat(p[5]);
                            int captures = Integer.parseInt(p[6]);

                            float mass;
                            String tag;
                            if (p.length >= 9) {
                                mass = Float.parseFloat(p[7]);
                                tag  = p[8];
                            } else {
                                mass = (float) (Math.PI * radius * radius);
                                tag  = p[7];
                            }
                            boolean isMe = tag.equals("me");

                            players.add(new PlayerData(id, x, y, radius, angle, mass, isMe));

                            if (isMe) {
                                myScore = captures;
                                gameState.setMyId(id);
                            }

                        } catch (NumberFormatException ignored) {}
                    }
                    break;

                case "food":
                    // food id x y radius
                    parseObjectLine(p, ObjectData.Type.FOOD, objects);
                    break;

                case "poison":
                    // poison id x y radius
                    parseObjectLine(p, ObjectData.Type.POISON, objects);
                    break;

                default:
                    System.err.println("[flushGameState] Linha desconhecida: " + line);
                    break;
            }
        }

        gameState.updateGameState(players, objects, myScore);
        gameState.setPhase(GamePhase.PLAYING);
    }

    private void parseObjectLine(String[] p, ObjectData.Type type, List<ObjectData> objects) {
        if (p.length < 5) return;

        try {
            objects.add(new ObjectData(
                    p[1],
                    Float.parseFloat(p[2]),
                    Float.parseFloat(p[3]),
                    Float.parseFloat(p[4]),
                    type
            ));
        } catch (NumberFormatException ignored) {}
    }

    // ----------------------------------------------------------------
    //  Parsing do top de pontuações
    // ----------------------------------------------------------------

    private void parseTopScores(String[] p) {
        List<String[]> board = new ArrayList<>();

        if (p.length < 2 || p[1].equals("empty")) {
            gameState.setLeaderboard(board);
            return;
        }

        // p[1] = "nome1:pts1,nome2:pts2,..."
        String[] entries = p[1].split(",");
        for (String entry : entries) {
            String[] kv = entry.split(":");
            if (kv.length == 2) {
                board.add(new String[]{kv[0], kv[1]});
            }
        }

        gameState.setLeaderboard(board);
    }

    // ----------------------------------------------------------------
    //  Parsing do fim de jogo
    // ----------------------------------------------------------------

    private void parseGameOver(String[] p) {
        // game_over winner username captures
        if (p.length >= 4 && p[1].equals("winner")) {
            try {
                gameState.setGameOver(p[2], Integer.parseInt(p[3]));
            } catch (NumberFormatException e) {
                gameState.setGameOver(p[2], 0);
            }
            return;
        }

        // game_over tie
        // O ecrã do Membro 3 considera empate se winner == null ou empty.
        gameState.setGameOver("", 0);
    }
}
