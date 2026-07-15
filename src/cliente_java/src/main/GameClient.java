package main;

import input.InputHandler;
import network.MessageProtocol;
import network.ServerConnection;
import state.GameState;

import java.io.IOException;

/**
 * Fachada usada pelo sketch Processing.
 *
 * O Membro 3 deve instanciar esta classe no setup(), chamar connect(),
 * usar getGameState() para desenhar e getInputHandler() para encaminhar teclas.
 */
public class GameClient {

    private final GameState gameState;
    private final ServerConnection connection;
    private final InputHandler inputHandler;

    public GameClient(String host, int port) {
        this.gameState    = new GameState();
        this.connection   = new ServerConnection(host, port, gameState);
        this.inputHandler = new InputHandler(connection);
    }

    public void connect() throws IOException {
        connection.connect();
    }

    public void disconnect() {
        connection.disconnect();
    }

    // ----------------------------------------------------------------
    //  Ações de alto nível chamadas pela UI Processing
    // ----------------------------------------------------------------

    public void register(String username, String password) {
        connection.send(MessageProtocol.createAccount(username, password));
    }

    public void login(String username, String password) {
        connection.send(MessageProtocol.login(username, password));
    }

    public void unregister(String username, String password) {
        connection.send(MessageProtocol.closeAccount(username, password));
    }

    public void logout() {
        connection.send(MessageProtocol.logout());
    }

    public void joinQueue() {
        connection.send(MessageProtocol.joinQueue());
    }

    public void leaveQueue() {
        connection.send(MessageProtocol.leaveQueue());
    }

    public void topScores() {
        connection.send(MessageProtocol.topScores());
    }

    // ----------------------------------------------------------------
    //  Getters para o Membro 3
    // ----------------------------------------------------------------

    public GameState getGameState()       { return gameState; }
    public InputHandler getInputHandler() { return inputHandler; }
    public boolean isConnected()          { return connection.isConnected(); }

    // ----------------------------------------------------------------
    //  main() simples para smoke test sem Processing
    // ----------------------------------------------------------------

    public static void main(String[] args) throws Exception {
        String host = args.length > 0 ? args[0] : "localhost";
        int port    = args.length > 1 ? Integer.parseInt(args[1]) : 12345;
        String user = args.length > 2 ? args[2] : "jogador1";
        String pass = "1234";

        System.out.println("[GameClient] A ligar a " + host + ":" + port + "...");
        GameClient client = new GameClient(host, port);
        client.connect();

        Thread.sleep(500);
        client.register(user, pass);
        Thread.sleep(500);
        client.login(user, pass);
        Thread.sleep(500);
        client.joinQueue();

        // Fica na fila durante 3 minutos (tempo suficiente para o jogo acabar)
        Thread.sleep(200_000);
        client.disconnect();
    }
}
