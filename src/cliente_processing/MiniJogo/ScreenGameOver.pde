/**
 * ScreenGameOver.pde — Ecrã de Fim de Jogo
 */

int gameOverStartFrame = -1;

// ---------------------------------------------------------------
//  Desenho principal
// ---------------------------------------------------------------

void drawGameOver() {
  if (gameOverStartFrame < 0) gameOverStartFrame = frameCount;
  float t    = constrain(float(frameCount - gameOverStartFrame) / 60.0, 0, 1);
  float ease = 1 - pow(1 - t, 3);

  drawBackground();

  String winner = gameState.getGameOverWinner();
  int    score  = gameState.getGameOverScore();
  String myId   = gameState.getMyId();

  boolean iWon   = winner != null && myId != null && winner.equals(myId);
  boolean isDraw = winner == null || winner.isEmpty();

  float panelW = 420;
  float panelH = 300;
  float panelX = width / 2 - panelW / 2;
  float panelY = lerp(height, height / 2 - panelH / 2, ease);

  drawPanel(panelX, panelY, panelW, panelH);

  textAlign(CENTER, CENTER);

  if (isDraw) {
    fill(180, 180, 255);
    textSize(42);
    text("EMPATE", width / 2, panelY + 70);

    fill(150);
    textSize(13);
    text("Partida ignorada no top de pontuacoes.", width / 2, panelY + 108);
    text("Nenhum jogador ficou isolado no primeiro lugar.", width / 2, panelY + 128);

  } else if (iWon) {
    float glow    = 0.5 + 0.5 * sin(frameCount * 0.08);
    int   glowA1  = int(40 * glow);
    int   glowA2  = int(20 * glow);

    noStroke();
    fill(255, int(180 + 60 * glow), 0, glowA1);
    ellipse(width / 2, panelY + 75, 260, 80);
    fill(255, int(180 + 60 * glow), 0, glowA2);
    ellipse(width / 2, panelY + 75, 320, 100);

    fill(255, 210, 0);
    textSize(52);
    text("VITORIA!", width / 2, panelY + 72);

    fill(200, 255, 180);
    textSize(16);
    text("Parabens, " + (myId != null ? myId : "jogador") + "!", width / 2, panelY + 116);

  } else {
    fill(220, 70, 70);
    textSize(46);
    text("DERROTA", width / 2, panelY + 72);

    fill(170, 120, 120);
    textSize(15);
    text("Melhor sorte na proxima!", width / 2, panelY + 112);
  }

  stroke(60);
  strokeWeight(1);
  line(panelX + 30, panelY + 140, panelX + panelW - 30, panelY + 140);
  noStroke();

  if (!isDraw && winner != null) {
    textAlign(CENTER, CENTER);

    fill(150);
    textSize(13);
    text("Vencedor:", width / 2, panelY + 164);

    fill(255, 220, 60);
    textSize(20);
    text(winner, width / 2, panelY + 188);

    fill(150);
    textSize(13);
    text("Capturas: " + score, width / 2, panelY + 212);
  }

  float btnY = panelY + panelH - 34;
  drawButton("Jogar Novamente", width / 2 - 98, btnY, 160, 36, true);
  drawButton("Menu Principal",  width / 2 + 98, btnY, 160, 36, false);

  if (iWon && ease >= 1.0) {
    drawConfetti();
  }
}

// ---------------------------------------------------------------
//  Confetti animado
// ---------------------------------------------------------------

void drawConfetti() {
  int[] confColors = {
    color(255, 215, 0),
    color(255, 80,  80),
    color(80,  180, 255),
    color(100, 255, 120),
    color(255, 140, 255)
  };

  for (int i = 0; i < 60; i++) {
    float seed  = i * 137.5;
    float speed = 1.2 + (seed % 1.5);
    float py    = ((frameCount * speed + i * 40) % (height + 40)) - 20;
    float px    = (seed * 6.7) % width;
    float sz    = 4 + (seed % 6);
    float ang   = frameCount * 0.05 + i;

    fill(confColors[i % 5]);
    noStroke();
    pushMatrix();
    translate(px, py);
    rotate(ang);
    rect(-sz / 2, -sz / 4, sz, sz / 2, 2);
    popMatrix();
  }
}

// ---------------------------------------------------------------
//  Cliques
// ---------------------------------------------------------------

void handleGameOverClick() {
  float panelH = 300;
  float panelY = height / 2 - panelH / 2;
  float btnY   = panelY + panelH - 34;

  if (overButton(width / 2 - 98, btnY, 160, 36)) {
    gameOverStartFrame = -1;
    joinedQueue        = true;
    pendingJoinQueue   = false;

    // Depois de game_over, o servidor deixa a sessão em authenticated.
    // join_queue volta a ser válido.
    client.joinQueue();
    return;
  }

  if (overButton(width / 2 + 98, btnY, 160, 36)) {
    gameOverStartFrame = -1;
    joinedQueue        = false;
    pendingJoinQueue   = false;
    resetLogin();

    // Depois de game_over, o servidor deixa a sessão em authenticated.
    // Para voltar mesmo ao menu/login, fazemos logout.
    // A limpeza de myId fica a cargo do ServerConnection quando chegar logout_ok.
    client.logout();
    gameState.setPhase(state.GamePhase.MENU);

    return;
  }
}
