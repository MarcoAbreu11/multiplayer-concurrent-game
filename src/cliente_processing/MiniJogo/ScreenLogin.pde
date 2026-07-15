/**
 * ScreenLogin.pde — Ecrã de Login e Registo
 *
 * Integração final:
 *   - doRegister() envia create_account username password.
 *   - doLogin() envia login username password e ativa pendingJoinQueue.
 *   - Quando o servidor responder login_ok username, MiniJogo.pde envia join_queue.
 */

// ---------------------------------------------------------------
//  Estado
// ---------------------------------------------------------------

String  loginUser       = "";
String  loginPass       = "";
int     activeField     = 0;      // 0 = username, 1 = password
String  feedbackMsg     = "";
boolean feedbackIsError = false;

// Geometria
float fieldX, fieldY_user, fieldY_pass;
float fieldW = 360;
float fieldH = 40;

// ---------------------------------------------------------------
//  Inicialização
// ---------------------------------------------------------------

void initLogin() {
  fieldX      = width / 2 - fieldW / 2 + 30;
  fieldY_user = height / 2 - 50;
  fieldY_pass = height / 2 + 10;
}

// ---------------------------------------------------------------
//  Desenho
// ---------------------------------------------------------------

void drawLogin() {
  drawBackground();

  float panelW = 400;
  float panelH = 330;
  float pX     = width / 2 - panelW / 2;
  float pY     = height / 2 - panelH / 2;
  drawPanel(pX, pY, panelW, panelH);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(28);
  text("Mini-Jogo", width / 2, pY + 38);

  textSize(12);
  fill(140);
  text("Programação Concorrente — UMinho", width / 2, pY + 62);

  stroke(55);
  strokeWeight(1);
  line(pX + 20, pY + 78, pX + panelW - 20, pY + 78);
  noStroke();

  drawTextField("Username", loginUser, fieldX, fieldY_user, activeField == 0, false);
  drawTextField("Password", loginPass, fieldX, fieldY_pass, activeField == 1, true);

  float bY = pY + 260;
  drawButton("Entrar",   width / 2 - 70, bY, 110, 38, true);
  drawButton("Registar", width / 2 + 70, bY, 110, 38, false);

  fill(110);
  textSize(12);
  textAlign(CENTER, CENTER);
  text("Cancelar registo", width / 2, pY + panelH - 30);
  float tw = textWidth("Cancelar registo");
  stroke(90);
  strokeWeight(1);
  line(width / 2 - tw / 2, pY + panelH - 22, width / 2 + tw / 2, pY + panelH - 22);
  noStroke();

  String serverError  = gameState.getLastError();
  boolean showErr     = serverError != null && !serverError.isEmpty();
  String displayMsg   = showErr ? serverError : feedbackMsg;
  boolean isErr       = showErr || feedbackIsError;

  if (displayMsg != null && !displayMsg.isEmpty()) {
    fill(isErr ? color(255, 90, 90) : color(90, 210, 110));
    textSize(13);
    textAlign(CENTER, CENTER);
    text(displayMsg, width / 2, pY + panelH - 55);
  }

  drawConnectionStatus();
}

// ---------------------------------------------------------------
//  Cliques
// ---------------------------------------------------------------

void handleLoginClick() {
  float pY     = height / 2 - 330.0 / 2;
  float bY     = pY + 260;
  float panelH = 330;

  float textFieldX = fieldX + 70;
  float textFieldW = 210;

  if (overRect(textFieldX, fieldY_user, textFieldW, fieldH)) {
    activeField = 0;
    return;
  }

  if (overRect(textFieldX, fieldY_pass, textFieldW, fieldH)) {
    activeField = 1;
    return;
  }

  if (overButton(width / 2 - 70, bY, 110, 38)) {
    doLogin();
    return;
  }

  if (overButton(width / 2 + 70, bY, 110, 38)) {
    doRegister();
    return;
  }

  if (overRect(width / 2 - 60, pY + panelH - 38, 120, 20)) {
    doUnregister();
    return;
  }
}

// ---------------------------------------------------------------
//  Teclado no login
// ---------------------------------------------------------------

void handleLoginKeyPressed() {
  if (key == TAB) {
    activeField = (activeField == 0) ? 1 : 0;
    return;
  }

  if (key == ENTER || key == RETURN) {
    doLogin();
    return;
  }

  if (key == BACKSPACE) {
    if (activeField == 0 && loginUser.length() > 0) {
      loginUser = loginUser.substring(0, loginUser.length() - 1);
    } else if (activeField == 1 && loginPass.length() > 0) {
      loginPass = loginPass.substring(0, loginPass.length() - 1);
    }
    return;
  }

  if (key != CODED) {
    if (activeField == 0 && loginUser.length() < 30) {
      loginUser += key;
    } else if (activeField == 1 && loginPass.length() < 30) {
      loginPass += key;
    }
  }
}

// ---------------------------------------------------------------
//  Ações
// ---------------------------------------------------------------

void doLogin() {
  if (loginUser.isEmpty() || loginPass.isEmpty()) {
    feedbackMsg     = "Preenche username e password.";
    feedbackIsError = true;
    return;
  }

  loggedUsername   = loginUser;
  loggedPassword   = loginPass;
  feedbackMsg      = "A autenticar...";
  feedbackIsError  = false;

  pendingJoinQueue = true;
  client.login(loginUser, loginPass);
}

void doRegister() {
  if (loginUser.isEmpty() || loginPass.isEmpty()) {
    feedbackMsg     = "Preenche username e password.";
    feedbackIsError = true;
    return;
  }

  feedbackMsg      = "Registado";
  feedbackIsError  = false;
  client.register(loginUser, loginPass);
}

void doUnregister() {
  String userToRemove = loggedUsername.isEmpty() ? loginUser : loggedUsername;
  String passToRemove = loggedPassword.isEmpty() ? loginPass : loggedPassword;

  if (userToRemove.isEmpty() || passToRemove.isEmpty()) {
    feedbackMsg     = "Indica username e password.";
    feedbackIsError = true;
    return;
  }

  client.unregister(userToRemove, passToRemove);

  feedbackMsg      = "Pedido de cancelamento enviado.";
  feedbackIsError  = false;
  loginUser        = "";
  loginPass        = "";
  loggedUsername   = "";
  loggedPassword   = "";
}

void resetLogin() {
  feedbackMsg      = "";
  feedbackIsError  = false;
  pendingJoinQueue = false;
  activeField      = 0;
}
