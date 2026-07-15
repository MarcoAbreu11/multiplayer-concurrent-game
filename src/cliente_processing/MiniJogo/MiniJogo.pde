/**
 * MiniJogo.pde — Sketch Principal (Membro 3)
 *
 * Integração final com o servidor Erlang:
 *   - O cliente liga-se à porta 12345.
 *   - Após login_ok username, o ServerConnection guarda myId.
 *   - Quando myId != null e pendingJoinQueue == true, o sketch envia join_queue.
 *   - Se o jogador sair da sala de espera, primeiro envia leave_queue;
 *     quando voltar ao MENU, envia logout para limpar a sessão no servidor.
 */

import main.GameClient;
import state.GameState;
import state.GamePhase;
import state.PlayerData;
import state.ObjectData;
import input.InputHandler;
import java.util.List;

// ---------------------------------------------------------------
//  CONFIGURAÇÃO GLOBAL
// ---------------------------------------------------------------

static final String SERVER_HOST = "localhost";
static final int    SERVER_PORT = 12345;

// Dimensões do espaço de jogo no servidor (para mapear coordenadas)
static final float SERVER_W = 800.0;
static final float SERVER_H = 600.0;

// ---------------------------------------------------------------
//  VARIÁVEIS GLOBAIS
// ---------------------------------------------------------------

GameClient   client;
GameState    gameState;
InputHandler inputHandler;

GamePhase currentPhase = GamePhase.MENU;
GamePhase lastPhase    = GamePhase.MENU;

// Quando true, assim que o servidor confirmar o login (myId fica definido)
// o sketch envia join_queue automaticamente.
boolean pendingJoinQueue = false;

// Quando true, o jogador carregou em "Voltar ao Menu" na sala de espera.
// Primeiro enviamos leave_queue; quando o servidor responder e voltar ao MENU,
// enviamos logout para limpar a sessão autenticada.
boolean pendingLogoutAfterLeaveQueue = false;

// Username/password guardados para poder chamar unregister mais tarde
String loggedUsername = "";
String loggedPassword = "";

// ---------------------------------------------------------------
//  SETUP — corre uma vez
// ---------------------------------------------------------------

void setup() {
  size(800, 600);
  frameRate(60);
  smooth(4);

  client       = new GameClient(SERVER_HOST, SERVER_PORT);
  gameState    = client.getGameState();
  inputHandler = client.getInputHandler();

  try {
    client.connect();
    println("[MiniJogo] Ligado a " + SERVER_HOST + ":" + SERVER_PORT);
  } catch (Exception e) {
    println("[MiniJogo] Erro ao ligar: " + e.getMessage());
  }

  initLogin();
}

// ---------------------------------------------------------------
//  DRAW — corre a 60fps
// ---------------------------------------------------------------

void draw() {
  currentPhase = gameState.getPhase();

  // ── Transição automática login → fila ────────────────────────
  // O servidor responde login_ok username.
  // O ServerConnection faz gameState.setMyId(username).
  // Quando detetamos esse sinal, enviamos join_queue.
  if (currentPhase == GamePhase.MENU
      && gameState.getMyId() != null
      && pendingJoinQueue) {
    pendingJoinQueue = false;
    joinedQueue      = true;
    feedbackMsg      = "";
    client.joinQueue();
    // O servidor responde join_queue_ok e a fase passa para WAITING.
  }

  // ── Limpeza ao regressar ao menu ─────────────────────────────
  if (lastPhase != GamePhase.MENU && currentPhase == GamePhase.MENU) {
    joinedQueue      = false;
    pendingJoinQueue = false;
    resetLogin();
  }

  // ── Logout após sair da fila ─────────────────────────────────
  // leave_queue só é válido enquanto estamos em WAITING.
  // Por isso, primeiro enviamos leave_queue no ecrã de espera.
  // Quando o servidor responde leave_queue_ok, o cliente volta ao MENU.
  // Só aqui é seguro enviar logout, porque a sessão voltou a authenticated.
  if (currentPhase == GamePhase.MENU && pendingLogoutAfterLeaveQueue) {
    pendingLogoutAfterLeaveQueue = false;

    if (gameState.getMyId() != null) {
      // A limpeza de myId fica a cargo do ServerConnection quando chegar logout_ok.
      client.logout();
    }
  }

  // ── Inicializa animação do game over ─────────────────────────
  if (lastPhase != GamePhase.GAME_OVER && currentPhase == GamePhase.GAME_OVER) {
    gameOverStartFrame = -1;
  }

  lastPhase = currentPhase;

  // ── Ecrã activo ──────────────────────────────────────────────
  switch (currentPhase) {
    case MENU:      drawLogin();    break;
    case WAITING:   drawWaiting();  break;
    case PLAYING:   drawGame();     break;
    case GAME_OVER: drawGameOver(); break;
    default:        drawLogin();    break;
  }
}

// ---------------------------------------------------------------
//  INPUT DE TECLADO
// ---------------------------------------------------------------

void keyPressed() {
  if (currentPhase == GamePhase.PLAYING) {
    inputHandler.onKeyPressed(key, keyCode);
  }
  if (currentPhase == GamePhase.MENU) {
    handleLoginKeyPressed();
  }
}

void keyReleased() {
  if (currentPhase == GamePhase.PLAYING) {
    inputHandler.onKeyReleased(key, keyCode);
  }
}

// ---------------------------------------------------------------
//  RATO
// ---------------------------------------------------------------

void mousePressed() {
  switch (currentPhase) {
    case MENU:      handleLoginClick();    break;
    case WAITING:   handleWaitingClick();  break;
    case GAME_OVER: handleGameOverClick(); break;
  }
}

// ---------------------------------------------------------------
//  EXIT
// ---------------------------------------------------------------

void exit() {
  if (client != null) client.disconnect();
  super.exit();
}
