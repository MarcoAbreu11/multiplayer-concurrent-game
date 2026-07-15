package state;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.locks.ReentrantReadWriteLock;

/**
 * Estado partilhado entre:
 * - ReaderThread do ServerConnection, que escreve dados vindos do servidor.
 * - draw() do Processing, que lê dados para desenhar a interface.
 *
 * Usa ReentrantReadWriteLock para evitar corridas entre leitura e escrita.
 */
public class GameState {

    private final ReentrantReadWriteLock lock = new ReentrantReadWriteLock();

    private GamePhase phase = GamePhase.MENU;

    private List<PlayerData> players = new ArrayList<>();
    private List<ObjectData> objects = new ArrayList<>();

    private int myScore = 0;
    private int queuePosition = 0;

    private List<String[]> leaderboard = new ArrayList<>();

    private String myId = null;
    private String gameOverWinner = null;
    private int gameOverScore = 0;
    private String lastError = null;

    private int gameWidth  = 800;
    private int gameHeight = 600;
    private int timeRemainingMs = 120000;

    // ----------------------------------------------------------------
    //  Escritas
    // ----------------------------------------------------------------

    public void setPhase(GamePhase phase) {
        lock.writeLock().lock();
        try {
            this.phase = phase;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void setMyId(String id) {
        lock.writeLock().lock();
        try {
            this.myId = id;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void setLastError(String error) {
        lock.writeLock().lock();
        try {
            this.lastError = error;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void setQueuePosition(int pos) {
        lock.writeLock().lock();
        try {
            this.queuePosition = pos;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void setGameConfig(int width, int height) {
        lock.writeLock().lock();
        try {
            this.gameWidth = width;
            this.gameHeight = height;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void updateGameState(List<PlayerData> newPlayers, List<ObjectData> newObjects, int score) {
        lock.writeLock().lock();
        try {
            this.players = new ArrayList<>(newPlayers);
            this.objects = new ArrayList<>(newObjects);
            this.myScore = score;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void setTimeRemainingMs(int ms) {
        lock.writeLock().lock();
        try {
            this.timeRemainingMs = Math.max(0, ms);
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void setLeaderboard(List<String[]> board) {
        lock.writeLock().lock();
        try {
            this.leaderboard = new ArrayList<>(board);
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void setGameOver(String winner, int score) {
        lock.writeLock().lock();
        try {
            this.gameOverWinner = winner;
            this.gameOverScore = score;
            this.phase = GamePhase.GAME_OVER;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void clearGameData() {
        lock.writeLock().lock();
        try {
            this.players.clear();
            this.objects.clear();
            this.myScore = 0;
            this.queuePosition = 0;
            this.gameOverWinner = null;
            this.gameOverScore = 0;
            this.timeRemainingMs = 120000;
        } finally {
            lock.writeLock().unlock();
        }
    }

    // ----------------------------------------------------------------
    //  Leituras
    // ----------------------------------------------------------------

    public GamePhase getPhase() {
        lock.readLock().lock();
        try {
            return phase;
        } finally {
            lock.readLock().unlock();
        }
    }

    public String getMyId() {
        lock.readLock().lock();
        try {
            return myId;
        } finally {
            lock.readLock().unlock();
        }
    }

    public String getLastError() {
        lock.readLock().lock();
        try {
            return lastError;
        } finally {
            lock.readLock().unlock();
        }
    }

    public int getQueuePosition() {
        lock.readLock().lock();
        try {
            return queuePosition;
        } finally {
            lock.readLock().unlock();
        }
    }

    public List<PlayerData> getPlayers() {
        lock.readLock().lock();
        try {
            return Collections.unmodifiableList(new ArrayList<>(players));
        } finally {
            lock.readLock().unlock();
        }
    }

    public List<ObjectData> getObjects() {
        lock.readLock().lock();
        try {
            return Collections.unmodifiableList(new ArrayList<>(objects));
        } finally {
            lock.readLock().unlock();
        }
    }

    public int getMyScore() {
        lock.readLock().lock();
        try {
            return myScore;
        } finally {
            lock.readLock().unlock();
        }
    }

    public List<String[]> getLeaderboard() {
        lock.readLock().lock();
        try {
            return Collections.unmodifiableList(new ArrayList<>(leaderboard));
        } finally {
            lock.readLock().unlock();
        }
    }

    public String getGameOverWinner() {
        lock.readLock().lock();
        try {
            return gameOverWinner;
        } finally {
            lock.readLock().unlock();
        }
    }

    public int getGameOverScore() {
        lock.readLock().lock();
        try {
            return gameOverScore;
        } finally {
            lock.readLock().unlock();
        }
    }

    public int getGameWidth() {
        lock.readLock().lock();
        try {
            return gameWidth;
        } finally {
            lock.readLock().unlock();
        }
    }

    public int getGameHeight() {
        lock.readLock().lock();
        try {
            return gameHeight;
        } finally {
            lock.readLock().unlock();
        }
    }

    public int getTimeRemainingMs() {
        lock.readLock().lock();
        try {
            return timeRemainingMs;
        } finally {
            lock.readLock().unlock();
        }
    }
}
