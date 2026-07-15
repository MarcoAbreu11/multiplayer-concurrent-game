package input;

import network.MessageProtocol;
import network.ServerConnection;

/**
 * Gere o estado das teclas e envia input left/right/forward down/up ao servidor.
 *
 * Modelo escolhido:
 * - Envia uma mensagem quando a tecla é premida.
 * - Envia outra mensagem quando a tecla é largada.
 * - Não envia continuamente a 60 FPS.
 *
 * O servidor Erlang mantém a lista de teclas ativas e aplica a física a cada tick.
 */
public class InputHandler {

    // Keycodes do Processing / java.awt.event.KeyEvent
    public static final int LEFT  = 37;
    public static final int RIGHT = 39;
    public static final int UP    = 38; // FORWARD

    private final ServerConnection connection;

    private volatile boolean leftDown    = false;
    private volatile boolean rightDown   = false;
    private volatile boolean forwardDown = false;

    public InputHandler(ServerConnection connection) {
        this.connection = connection;
    }

    /** Chamar no keyPressed() do Processing. */
    public void onKeyPressed(char key, int keyCode) {
        switch (keyCode) {
            case LEFT:
                if (!leftDown) {
                    leftDown = true;
                    connection.send(MessageProtocol.keyDown("left"));
                }
                break;

            case RIGHT:
                if (!rightDown) {
                    rightDown = true;
                    connection.send(MessageProtocol.keyDown("right"));
                }
                break;

            case UP:
                if (!forwardDown) {
                    forwardDown = true;
                    connection.send(MessageProtocol.keyDown("forward"));
                }
                break;

            default:
                // Ignora outras teclas.
                break;
        }
    }

    /** Chamar no keyReleased() do Processing. */
    public void onKeyReleased(char key, int keyCode) {
        switch (keyCode) {
            case LEFT:
                if (leftDown) {
                    leftDown = false;
                    connection.send(MessageProtocol.keyUp("left"));
                }
                break;

            case RIGHT:
                if (rightDown) {
                    rightDown = false;
                    connection.send(MessageProtocol.keyUp("right"));
                }
                break;

            case UP:
                if (forwardDown) {
                    forwardDown = false;
                    connection.send(MessageProtocol.keyUp("forward"));
                }
                break;

            default:
                // Ignora outras teclas.
                break;
        }
    }

    // Getters úteis para debug/indicadores visuais no Processing.
    public boolean isLeftDown()    { return leftDown; }
    public boolean isRightDown()   { return rightDown; }
    public boolean isForwardDown() { return forwardDown; }
}
