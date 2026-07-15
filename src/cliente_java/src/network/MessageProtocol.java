package network;

/**
 * Protocolo de comunicação adaptado ao servidor Erlang.
 *
 * Formato geral:
 * - Campos separados por espaços.
 * - Cada mensagem termina em \n.
 *
 * CLIENTE -> SERVIDOR:
 *   create_account username password
 *   login username password
 *   logout
 *   close_account username password
 *   join_queue
 *   leave_queue
 *   top_scores
 *   input left down
 *   input left up
 *   input right down
 *   input right up
 *   input forward down
 *   input forward up
 *
 * SERVIDOR -> CLIENTE:
 *   create_account_ok
 *   create_account_error motivo
 *   login_ok username
 *   login_error motivo
 *   logout_ok
 *   close_account_ok
 *   close_account_error motivo
 *   join_queue_ok
 *   join_queue_error motivo
 *   leave_queue_ok
 *   leave_queue_error motivo
 *   top_scores empty
 *   top_scores nome1:pontos1,nome2:pontos2,...
 *   game_started gameId
 *   game_config width height tickMs
 *   game_state_begin tick tempo_restante_ms
 *   player username x y radius angle captures mass me|other
 *   food id x y radius
 *   poison id x y radius
 *   game_state_end
 *   game_over winner username captures
 *   game_over tie
 *   game_aborted player_disconnected username
 *   error motivo
 */
public class MessageProtocol {

    public enum MessageType {
        LOGIN_OK, LOGIN_ERROR,
        CREATE_ACCOUNT_OK, CREATE_ACCOUNT_ERROR,
        CLOSE_ACCOUNT_OK, CLOSE_ACCOUNT_ERROR,
        LOGOUT_OK,
        JOIN_QUEUE_OK, JOIN_QUEUE_ERROR,
        LEAVE_QUEUE_OK, LEAVE_QUEUE_ERROR,
        TOP_SCORES,
        GAME_STARTED,
        GAME_CONFIG,
        GAME_STATE_BEGIN,
        PLAYER,
        FOOD,
        POISON,
        GAME_STATE_END,
        GAME_OVER,
        GAME_ABORTED,
        ERROR,
        UNKNOWN
    }

    public static class Message {
        public final MessageType type;
        public final String[] parts;

        public Message(MessageType type, String[] parts) {
            this.type = type;
            this.parts = parts;
        }
    }

    /** Recebe uma linha crua do servidor e devolve uma mensagem tipada. */
    public static Message parse(String raw) {
        if (raw == null || raw.isBlank()) {
            return new Message(MessageType.UNKNOWN, new String[0]);
        }

        String[] parts = raw.trim().split("\\s+");
        return new Message(detectType(parts), parts);
    }

    private static MessageType detectType(String[] parts) {
        if (parts.length == 0) return MessageType.UNKNOWN;

        switch (parts[0]) {
            case "login_ok":             return MessageType.LOGIN_OK;
            case "login_error":          return MessageType.LOGIN_ERROR;

            case "create_account_ok":    return MessageType.CREATE_ACCOUNT_OK;
            case "create_account_error": return MessageType.CREATE_ACCOUNT_ERROR;

            case "close_account_ok":     return MessageType.CLOSE_ACCOUNT_OK;
            case "close_account_error":  return MessageType.CLOSE_ACCOUNT_ERROR;

            case "logout_ok":            return MessageType.LOGOUT_OK;

            case "join_queue_ok":        return MessageType.JOIN_QUEUE_OK;
            case "join_queue_error":     return MessageType.JOIN_QUEUE_ERROR;

            case "leave_queue_ok":       return MessageType.LEAVE_QUEUE_OK;
            case "leave_queue_error":    return MessageType.LEAVE_QUEUE_ERROR;

            case "top_scores":           return MessageType.TOP_SCORES;

            case "game_started":         return MessageType.GAME_STARTED;
            case "game_config":          return MessageType.GAME_CONFIG;
            case "game_state_begin":     return MessageType.GAME_STATE_BEGIN;
            case "player":               return MessageType.PLAYER;
            case "food":                 return MessageType.FOOD;
            case "poison":               return MessageType.POISON;
            case "game_state_end":       return MessageType.GAME_STATE_END;
            case "game_over":            return MessageType.GAME_OVER;
            case "game_aborted":         return MessageType.GAME_ABORTED;

            case "error":                return MessageType.ERROR;
            default:                     return MessageType.UNKNOWN;
        }
    }

    // ----------------------------------------------------------------
    //  Serialização: cliente -> servidor
    // ----------------------------------------------------------------

    public static String createAccount(String username, String password) {
        return "create_account " + username + " " + password + "\n";
    }

    public static String login(String username, String password) {
        return "login " + username + " " + password + "\n";
    }

    public static String logout() {
        return "logout\n";
    }

    public static String closeAccount(String username, String password) {
        return "close_account " + username + " " + password + "\n";
    }

    public static String joinQueue() {
        return "join_queue\n";
    }

    public static String leaveQueue() {
        return "leave_queue\n";
    }

    public static String topScores() {
        return "top_scores\n";
    }

    public static String keyDown(String key) {
        return "input " + normalizeKey(key) + " down\n";
    }

    public static String keyUp(String key) {
        return "input " + normalizeKey(key) + " up\n";
    }

    private static String normalizeKey(String key) {
        if (key == null) return "";

        switch (key.toUpperCase()) {
            case "LEFT":    return "left";
            case "RIGHT":   return "right";
            case "FORWARD": return "forward";
            default:        return key.toLowerCase();
        }
    }
}
