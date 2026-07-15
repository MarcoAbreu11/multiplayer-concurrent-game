/**
 * ScreenWaiting.pde — Sala de Espera + Top de Pontuações
 */

import java.util.List;

boolean joinedQueue = false;

// Dimensões fixas do painel
static final float WAIT_PANEL_W = 480;
static final float WAIT_PANEL_H = 460;

// ---------------------------------------------------------------
//  Desenho principal
// ---------------------------------------------------------------

void drawWaiting() {
  drawBackground();

  float pX = width / 2 - WAIT_PANEL_W / 2;
  float pY = height / 2 - WAIT_PANEL_H / 2;
  drawPanel(pX, pY, WAIT_PANEL_W, WAIT_PANEL_H);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(22);
  text("Sala de Espera", width / 2, pY + 35);

  stroke(55);
  strokeWeight(1);
  line(pX + 20, pY + 55, pX + WAIT_PANEL_W - 20, pY + 55);
  noStroke();

  int pos = gameState.getQueuePosition();

  if (!joinedQueue) {
    drawJoinPrompt(pY);
  } else {
    drawQueueStatus(pos, pY);
  }

  // Atualiza o top periodicamente enquanto está em espera.
  // O servidor aceita top_scores no estado waiting.
  if (joinedQueue && frameCount % 60 == 0) {
    client.topScores();
  }

  drawLeaderboard(pX, pY + 155, WAIT_PANEL_W, 240);

  drawButton("Voltar ao Menu", width / 2, pY + WAIT_PANEL_H - 28, 160, 34, false);
}

// ---------------------------------------------------------------
//  Sub-secções
// ---------------------------------------------------------------

void drawJoinPrompt(float pY) {
  fill(190);
  textAlign(CENTER, CENTER);
  textSize(15);
  text("Pronto para jogar?", width / 2, pY + 95);
  drawButton("Entrar na Fila", width / 2, pY + 133, 160, 36, true);
}

void drawQueueStatus(int pos, float pY) {
  int dots = (frameCount / 20) % 4;
  String anim = "";
  for (int i = 0; i < dots; i++) anim += ".";

  textAlign(CENTER, CENTER);

  if (pos <= 0) {
    fill(90, 220, 110);
    textSize(17);
    text("A iniciar partida" + anim, width / 2, pY + 90);
  } else {
    fill(190);
    textSize(14);
    text("À espera de jogadores" + anim, width / 2, pY + 78);
  }
}

void drawLeaderboard(float lx, float ly, float lw, float lh) {
  fill(255, 200, 60);
  textAlign(CENTER, CENTER);
  textSize(15);
  text("Top de Pontuacoes", lx + lw / 2, ly + 16);

  stroke(50);
  strokeWeight(1);
  line(lx + 20, ly + 30, lx + lw - 20, ly + 30);
  noStroke();

  List board = gameState.getLeaderboard();

  if (board == null || board.size() == 0) {
    fill(100);
    textSize(13);
    textAlign(CENTER, CENTER);
    text("(ainda sem pontuacoes registadas)", lx + lw / 2, ly + 60);
    return;
  }

  float colRank  = lx + 36;
  float colName  = lx + 80;
  float colScore = lx + lw - 36;
  float rowH     = 30;
  float startY   = ly + 46;

  fill(100);
  textSize(11);
  textAlign(LEFT, CENTER);
  text("#",       colRank, startY - 12);
  text("Jogador", colName, startY - 12);
  textAlign(RIGHT, CENTER);

  // O servidor guarda a melhor pontuacao vencedora de cada jogador.
  text("Pontuacao", colScore, startY - 12);

  int maxRows = int((lh - 60) / rowH);

  for (int i = 0; i < min(board.size(), maxRows); i++) {
    String[] entry = (String[]) board.get(i);
    String nome = entry[0];
    String pts  = entry[1];
    float rowY  = startY + i * rowH;

    if (i % 2 == 0) {
      fill(255, 255, 255, 8);
      noStroke();
      rect(lx + 12, rowY - rowH / 2 + 2, lw - 24, rowH - 4, 4);
    }

    if      (i == 0) fill(255, 215, 0);
    else if (i == 1) fill(192, 192, 192);
    else if (i == 2) fill(205, 127, 50);
    else             fill(160);

    textSize(13);
    textAlign(LEFT, CENTER);
    text((i + 1) + ".", colRank, rowY);

    fill(220);
    text(nome, colName, rowY);

    fill(255, 200, 60);
    textAlign(RIGHT, CENTER);
    text(pts, colScore, rowY);
  }
}

// ---------------------------------------------------------------
//  Cliques
// ---------------------------------------------------------------

void handleWaitingClick() {
  float pY = height / 2 - WAIT_PANEL_H / 2;

  if (!joinedQueue && overButton(width / 2, pY + 133, 160, 36)) {
    joinedQueue = true;
    client.joinQueue();
    return;
  }

  if (overButton(width / 2, pY + WAIT_PANEL_H - 28, 160, 34)) {
    joinedQueue      = false;
    pendingJoinQueue = false;
    resetLogin();

    // Enquanto estamos em waiting, logout ainda não é válido no servidor.
    // Primeiro saímos da fila.
    // Quando o servidor responder leave_queue_ok, o Membro 4 volta ao MENU.
    // No draw() principal, pendingLogoutAfterLeaveQueue dispara o logout.
    pendingLogoutAfterLeaveQueue = true;
    client.leaveQueue();

    return;
  }
}
