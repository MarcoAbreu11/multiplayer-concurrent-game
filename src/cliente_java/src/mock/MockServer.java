package mock;

import java.io.*;
import java.net.*;
import java.util.Locale;

/**
 * Servidor TCP falso atualizado para o protocolo do servidor Erlang.
 *
 * Este ficheiro é apenas para smoke tests do cliente Java sem arrancar o Erlang.
 * Para a integração final, devem testar com o servidor Erlang real.
 */
public class MockServer {

    private static final int PORT = 12345;

    public static void main(String[] args) throws Exception {
        System.out.println("[MockServer] A escutar na porta " + PORT + "...");

        try (ServerSocket server = new ServerSocket(PORT)) {
            while (true) {
                Socket client = server.accept();
                System.out.println("[MockServer] Cliente ligado: " + client.getRemoteSocketAddress());
                new Thread(() -> handle(client), "MockClientHandler").start();
            }
        }
    }

    private static void handle(Socket client) {
        try (
                BufferedReader in = new BufferedReader(new InputStreamReader(client.getInputStream(), "UTF-8"));
                PrintWriter out = new PrintWriter(new OutputStreamWriter(client.getOutputStream(), "UTF-8"), true)
        ) {
            String line;
            while ((line = in.readLine()) != null) {
                System.out.println("[MockServer RX] " + line);
                handleCommand(line.trim(), out);
            }
        } catch (IOException e) {
            System.out.println("[MockServer] Cliente desligado: " + e.getMessage());
        }
    }

    private static void handleCommand(String line, PrintWriter out) {
        String[] p = line.split("\\s+");
        if (p.length == 0) return;

        switch (p[0]) {
            case "create_account":
                send(out, "create_account_ok");
                break;

            case "login":
                if (p.length >= 2) send(out, "login_ok " + p[1]);
                else send(out, "login_error bad_request");
                break;

            case "logout":
                send(out, "logout_ok");
                break;

            case "close_account":
                send(out, "close_account_ok");
                break;

            case "join_queue":
                send(out, "join_queue_ok");
                send(out, "top_scores Alice:3,Bob:2,Carlos:1");

                new Thread(() -> {
                    try {
                        Thread.sleep(1500);
                        send(out, "game_started 1");
                        send(out, "game_config 800 600 50");
                        sendGameLoop(out);
                    } catch (InterruptedException ignored) {}
                }, "MockGameLoop").start();
                break;

            case "leave_queue":
                send(out, "leave_queue_ok");
                break;

            case "top_scores":
                send(out, "top_scores Alice:3,Bob:2,Carlos:1");
                break;

            case "input":
                // input left down / input forward up, etc.
                // Não responde; apenas simula que o servidor recebeu.
                break;

            default:
                send(out, "error unknown_command");
                break;
        }
    }

    private static void sendGameLoop(PrintWriter out) throws InterruptedException {
        float x = 300.0f;
        float y = 300.0f;
        float angle = 0.0f;

        for (int tick = 1; tick <= 100; tick++) {
            x += 1.5f;
            angle += 0.03f;

            send(out, "game_state_begin " + tick + " " + Math.max(0, 120000 - tick * 50));

            send(out, String.format(Locale.US,
                    "player teste %.1f %.1f 18.0 %.2f %d 100.0 me",
                    x, y, angle, tick / 20));

            send(out, String.format(Locale.US,
                    "player bot 500.0 220.0 15.0 0.50 %d 80.0 other",
                    tick / 30));

            send(out, "food f1 100.0 150.0 10.0");
            send(out, "food f2 250.0 400.0 12.0");
            send(out, "poison p1 400.0 350.0 8.0");

            send(out, "game_state_end");

            Thread.sleep(50);
        }

        send(out, "game_over winner teste 5");
    }

    private static void send(PrintWriter out, String line) {
        synchronized (out) {
            System.out.println("[MockServer TX] " + line);
            out.println(line);
            out.flush();
        }
    }
}
