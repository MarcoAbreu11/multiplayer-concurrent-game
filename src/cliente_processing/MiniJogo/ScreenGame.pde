/**
 * ScreenGame.pde — Ecrã de Jogo (Renderização 2D)
 *
 * Responsabilidade do Membro 3:
 *   - Desenhar o espaço de jogo retangular
 *   - Renderizar jogadores como círculos com borda colorida e indicador de direção
 *   - Renderizar objetos comestíveis (verde) e venenosos (vermelho)
 *   - Mostrar HUD com pontuação e massa do jogador local
 *
 * Lê estado via gameState.getPlayers() e gameState.getObjects(),
 * atualizados pelo Membro 4 em background.
 */

import java.util.List;

// ---------------------------------------------------------------
//  Coordenadas — escala servidor → ecrã
// ---------------------------------------------------------------

float mapX(float sx) { return map(sx, 0, SERVER_W, 0, width); }
float mapY(float sy) { return map(sy, 0, SERVER_H, 0, height); }
float mapR(float sr) { return sr * (width / SERVER_W); }

// ---------------------------------------------------------------
//  Desenho principal do jogo
// ---------------------------------------------------------------

void drawGame() {
  drawGameBackground();

  List<ObjectData> objects = gameState.getObjects();
  if (objects != null) {
    for (ObjectData obj : objects) {
      drawObject(obj);
    }
  }

  List<PlayerData> players = gameState.getPlayers();
  if (players != null) {
    for (PlayerData p : players) {
      drawPlayer(p);
    }
  }

  drawHUD(players);
}

// ---------------------------------------------------------------
//  Fundo do espaço de jogo
// ---------------------------------------------------------------

void drawGameBackground() {
  background(18, 20, 28);

  stroke(255, 255, 255, 12);
  strokeWeight(1);
  int gridSize = 50;
  for (int gx = 0; gx <= width; gx += gridSize) {
    line(gx, 0, gx, height);
  }
  for (int gy = 0; gy <= height; gy += gridSize) {
    line(0, gy, width, gy);
  }
  noStroke();

  noFill();
  stroke(80, 120, 200, 180);
  strokeWeight(3);
  rect(1, 1, width - 2, height - 2);
  noStroke();
}

// ---------------------------------------------------------------
//  Renderização de objectos
// ---------------------------------------------------------------

void drawObject(ObjectData obj) {
  float px = mapX(obj.x);
  float py = mapY(obj.y);
  float pr = mapR(obj.radius);

  if (obj.type == ObjectData.Type.FOOD) {
    noStroke();
    fill(0, 180, 60, 40);
    ellipse(px, py, (pr + 6) * 2, (pr + 6) * 2);

    fill(20, 200, 70);
    ellipse(px, py, pr * 2, pr * 2);

    fill(120, 255, 140, 80);
    ellipse(px - pr * 0.25, py - pr * 0.25, pr * 0.5, pr * 0.5);

  } else {
    float pulse = 1.0 + 0.08 * sin(frameCount * 0.1);

    noStroke();
    fill(200, 40, 40, 35);
    ellipse(px, py, (pr + 8) * 2 * pulse, (pr + 8) * 2 * pulse);

    fill(210, 45, 45);
    ellipse(px, py, pr * 2, pr * 2);

    stroke(255, 100, 100, 180);
    strokeWeight(max(1.5, pr * 0.18));
    float m = pr * 0.4;
    line(px - m, py - m, px + m, py + m);
    line(px + m, py - m, px - m, py + m);
    noStroke();
  }
}

// ---------------------------------------------------------------
//  Renderização de jogadores
// ---------------------------------------------------------------

void drawPlayer(PlayerData p) {
  float px = mapX(p.x);
  float py = mapY(p.y);
  float pr = mapR(p.radius);

  if (p.isMe) {
    noStroke();
    fill(0, 100, 255, 25);
    ellipse(px, py, (pr + 14) * 2, (pr + 14) * 2);
    fill(0, 100, 255, 15);
    ellipse(px, py, (pr + 20) * 2, (pr + 20) * 2);
  } else {
    noStroke();
    fill(200, 40, 40, 18);
    ellipse(px, py, (pr + 10) * 2, (pr + 10) * 2);
  }

  fill(10, 12, 18);
  noStroke();
  ellipse(px, py, pr * 2, pr * 2);

  int borderCol = p.isMe ? color(30, 120, 255) : color(220, 50, 50);
  stroke(borderCol);
  strokeWeight(max(2.5, pr * 0.12));
  noFill();
  ellipse(px, py, pr * 2, pr * 2);
  noStroke();

  float dirEndX = px + cos(p.angle) * pr;
  float dirEndY = py + sin(p.angle) * pr;

  stroke(p.isMe ? color(80, 170, 255) : color(255, 120, 120));
  strokeWeight(max(2, pr * 0.1));
  line(px, py, dirEndX, dirEndY);

  fill(p.isMe ? color(150, 210, 255) : color(255, 160, 160));
  noStroke();
  float dotR = max(3, pr * 0.15);
  ellipse(dirEndX, dirEndY, dotR * 2, dotR * 2);

  textAlign(CENTER, BOTTOM);
  textSize(max(10, min(14, pr * 0.55)));

  fill(0, 0, 0, 160);
  text(p.id, px + 1, py - pr - 5);

  fill(p.isMe ? color(150, 200, 255) : color(220, 150, 150));
  text(p.id, px, py - pr - 6);

  if (p.isMe && pr > 20) {
    fill(255, 255, 255, 60);
    textAlign(CENTER, CENTER);
    textSize(max(9, pr * 0.28));
    text(nf(p.mass, 0, 0), px, py);
  }
}

// ---------------------------------------------------------------
//  HUD
// ---------------------------------------------------------------

void drawHUD(List<PlayerData> players) {
  PlayerData me = null;
  if (players != null) {
    for (PlayerData p : players) {
      if (p.isMe) {
        me = p;
        break;
      }
    }
  }

  noStroke();
  fill(0, 0, 0, 160);
  rect(8, 8, 170, 84, 8);

  textAlign(LEFT, CENTER);
  fill(255);

  if (me != null) {
    textSize(13);

    fill(160, 200, 255);
    text("Jogador:  ", 18, 26);
    fill(255);
    text(me.id, 90, 26);

    fill(160, 200, 255);
    text("Massa:    ", 18, 46);
    fill(255);
    text(nf(me.mass, 0, 0), 90, 46);

    fill(160, 200, 255);
    text("Capturas: ", 18, 64);
    fill(255, 220, 60);
    text(str(gameState.getMyScore()), 90, 64);

    fill(160, 200, 255);
    text("Angulo:   ", 18, 82);
    fill(255);
    text(nf(me.angle, 0, 2) + "  radianos", 90, 82);

    
  } else {
    fill(120);
    textSize(12);
    text("À espera de dados...", 18, 36);
  }

  int numPlayers = (players != null) ? players.size() : 0;
  noStroke();
  fill(0, 0, 0, 160);
  rect(width - 120, 8, 112, 36, 8);

  fill(200);
  textAlign(CENTER, CENTER);
  textSize(12);
  text("Jogadores: " + numPlayers, width - 64, 26);

  drawTimerHUD();
  drawKeyIndicators();
}

String formatTimeMs(int ms) {
  int totalSeconds = max(0, ms / 1000);
  int minutes = totalSeconds / 60;
  int seconds = totalSeconds % 60;
  return nf(minutes, 1) + ":" + nf(seconds, 2);
}

void drawTimerHUD() {
  int timeMs = gameState.getTimeRemainingMs();
  noStroke();
  fill(0, 0, 0, 170);
  rect(width / 2 - 65, 8, 130, 36, 8);

  textAlign(CENTER, CENTER);
  textSize(12);
  fill(160, 200, 255);
  text("Tempo: ", width / 2 - 18, 26);
  fill(255);
  text(formatTimeMs(timeMs), width / 2 + 28, 26);
}

// ---------------------------------------------------------------
//  Indicador visual das teclas premidas
// ---------------------------------------------------------------

void drawKeyIndicators() {
  float bx = 20, by = height - 56;
  float bw = 34, bh = 30;
  float gap = 6;

  noStroke();
  fill(0, 0, 0, 140);
  rect(bx - 6, by - 6, bw * 3 + gap * 2 + 12, bh + 12, 6);

  boolean lDown = inputHandler.isLeftDown();
  fill(lDown ? color(60, 140, 255) : color(50));
  rect(bx, by, bw, bh, 5);
  fill(lDown ? color(255) : color(140));
  textAlign(CENTER, CENTER);
  textSize(14);
  text("◄", bx + bw / 2, by + bh / 2);

  boolean fDown = inputHandler.isForwardDown();
  fill(fDown ? color(60, 200, 80) : color(50));
  rect(bx + bw + gap, by, bw, bh, 5);
  fill(fDown ? color(255) : color(140));
  text("▲", bx + bw + gap + bw / 2, by + bh / 2);

  boolean rDown = inputHandler.isRightDown();
  fill(rDown ? color(60, 140, 255) : color(50));
  rect(bx + (bw + gap) * 2, by, bw, bh, 5);
  fill(rDown ? color(255) : color(140));
  text("►", bx + (bw + gap) * 2 + bw / 2, by + bh / 2);
}
