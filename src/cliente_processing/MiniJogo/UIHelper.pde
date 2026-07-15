/**
 * UIHelper.pde — Utilitários de UI partilhados
 */

// ---------------------------------------------------------------
//  Fundo degradê comum a todos os ecrãs de menu
// ---------------------------------------------------------------

void drawBackground() {
  for (int yy = 0; yy <= height; yy++) {
    float t = float(yy) / float(height);
    stroke(
      lerp(13, 26, t),
      lerp(15, 30, t),
      lerp(26, 48, t)
    );
    line(0, yy, width, yy);
  }

  noStroke();

  randomSeed(99);
  for (int i = 0; i < 80; i++) {
    float sx  = random(width);
    float sy  = random(height);
    float bri = random(60, 180);
    float sz  = random(1, 2.5);

    noStroke();
    fill(bri, bri, bri + 40, random(80, 200));
    ellipse(sx, sy, sz, sz);
  }

  randomSeed(int(millis()));
  noStroke();
}

// ---------------------------------------------------------------
//  Painel semi-transparente com borda subtil
// ---------------------------------------------------------------

void drawPanel(float x, float y, float w, float h) {
  noStroke();
  fill(0, 0, 0, 80);
  rect(x + 6, y + 8, w, h, 14);

  fill(22, 26, 40, 235);
  rect(x, y, w, h, 12);

  stroke(60, 80, 120, 180);
  strokeWeight(1.5);
  noFill();
  rect(x, y, w, h, 12);
  noStroke();
}

// ---------------------------------------------------------------
//  Botão com hover
//  cx, cy = CENTRO do botão
// ---------------------------------------------------------------

void drawButton(String label, float cx, float cy, float w, float h, boolean primary) {
  float bx = cx - w / 2;
  float by = cy - h / 2;
  boolean hover = overRect(bx, by, w, h);

  int baseCol, hoverCol, textCol;

  if (primary) {
    baseCol  = color(30, 90, 200);
    hoverCol = color(50, 130, 255);
    textCol  = color(255);
  } else {
    baseCol  = color(45, 50, 70);
    hoverCol = color(65, 75, 110);
    textCol  = color(200);
  }

  noStroke();
  fill(0, 0, 0, 60);
  rect(bx + 2, by + 3, w, h, 8);

  fill(hover ? hoverCol : baseCol);
  rect(bx, by, w, h, 8);

  if (hover) {
    fill(255, 255, 255, 30);
    rect(bx + 2, by + 1, w - 4, h / 2 - 1, 8);
  }

  fill(textCol);
  textAlign(CENTER, CENTER);
  textSize(13);
  text(label, cx, cy);
}

// ---------------------------------------------------------------
//  Campo de texto
// ---------------------------------------------------------------

void drawTextField(String label, String value, float x, float y, boolean active, boolean mask) {
  float fh = 40;
  float fx = x + 70;
  float fw = 210;

  textAlign(RIGHT, CENTER);
  textSize(13);
  fill(active ? color(160, 200, 255) : color(130));
  text(label, x + 64, y + fh / 2);

  fill(active ? color(20, 30, 60) : color(28, 32, 50));
  stroke(active ? color(60, 130, 255) : color(55, 60, 90));
  strokeWeight(active ? 2 : 1.5);
  rect(fx, y, fw, fh, 7);
  noStroke();

  String display = mask ? repeatChar(value.length()) : value;
  if (active && (frameCount / 30) % 2 == 0) display += "|";

  fill(active ? color(220, 235, 255) : color(160));
  textAlign(LEFT, CENTER);
  textSize(14);
  text(clipText(display, fw - 16), fx + 8, y + fh / 2);
}

String clipText(String s, float maxW) {
  textSize(14);
  while (s.length() > 0 && textWidth(s) > maxW) {
    s = s.substring(1);
  }
  return s;
}

String repeatChar(int n) {
  String out = "";
  for (int i = 0; i < n; i++) out += "\u25CF";
  return out;
}

// ---------------------------------------------------------------
//  Indicador de ligação TCP
// ---------------------------------------------------------------

void drawConnectionStatus() {
  boolean connected = client.isConnected();
  String  err       = gameState.getLastError();

  float ix = width - 16;
  float iy = height - 14;

  noStroke();
  fill(connected ? color(60, 200, 80) : color(200, 60, 60));
  ellipse(ix, iy, 9, 9);

  textAlign(RIGHT, CENTER);
  textSize(11);
  fill(connected ? color(100, 180, 110) : color(180, 100, 100));

  if (!connected && err != null && err.length() > 0) {
    String msg = err.length() > 40 ? err.substring(0, 40) + "..." : err;
    text(msg, ix - 14, iy);
  } else {
    text(connected ? "Ligado" : "Desligado", ix - 14, iy);
  }
}

// ---------------------------------------------------------------
//  Detecção de colisão do rato
// ---------------------------------------------------------------

boolean overRect(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

boolean overButton(float cx, float cy, float w, float h) {
  return overRect(cx - w / 2, cy - h / 2, w, h);
}
