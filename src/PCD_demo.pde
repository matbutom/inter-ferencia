import processing.video.*;
import gab.opencv.*;
import processing.sound.*;

Capture cam;
OpenCV opencv;

// ── ASCII — DOS NIVELES ───────────────────────────────────────────
String asciiCuerpo = "@#W&8BOI1+:. ";
String asciiRuido  = ".,·`";

float UMBRAL_CUERPO = 55;
float UMBRAL_RUIDO  = 18;

int GRID_CUERPO = 20;
int GRID_RUIDO  = 6;

ArrayList<PVector>   puntosC = new ArrayList<PVector>();
ArrayList<Character> charsC  = new ArrayList<Character>();
ArrayList<Float>     brightC = new ArrayList<Float>();

ArrayList<PVector>   puntosR = new ArrayList<PVector>();
ArrayList<Character> charsR  = new ArrayList<Character>();

PFont fontCuerpo;
PFont fontRuido;

// ── 6 BARRAS FIJAS ────────────────────────────────────────────────
int     N_BARRAS = 6;
float[] barrasX;
float[] barraGlow;
float[] barraGlowTarget;
color[] barraCols = {
  color(255, 100, 180),
  color(100, 220, 255),
  color(180, 255, 100),
  color(255, 200, 80),
  color(200, 120, 255),
  color(255, 140, 100)
};

// ── SONIDO ────────────────────────────────────────────────────────
float[] barraFreqs = {
  196.00, // G3
  261.63, // C4
  311.13, // Eb4
  392.00, // G4
  466.16, // Bb4
  523.25   // C5
};

SinOsc[]  oscA       = new SinOsc[N_BARRAS];
SinOsc[]  oscB       = new SinOsc[N_BARRAS];
boolean[] vocActiva  = new boolean[N_BARRAS];
float[]   vocTimer   = new float[N_BARRAS];
float[]   vocAmp     = new float[N_BARRAS];
float     VOC_DUR    = 2.5;

float[]   barraCooldown        = new float[N_BARRAS];
float     BARRA_COOL           = 1.5;
boolean[] barraContactoAhora   = new boolean[N_BARRAS];
boolean[] barraContactoAntes   = new boolean[N_BARRAS];
boolean[] barraConfirmadaAntes = new boolean[N_BARRAS];
int[]     barraFramesContacto  = new int[N_BARRAS];
int       FRAMES_PARA_ACTIVAR  = 3;

// ── FONDO ─────────────────────────────────────────────────────────
PImage bgFrame;
boolean bgCaptured  = false;
int     bgCountdown = 60;

// ─────────────────────────────────────────────────────────────────
void setup() {
  pixelDensity(1);
  fullScreen();
  frameRate(30);


  fontCuerpo = createFont("Courier New", GRID_CUERPO, true);
  fontRuido  = createFont("Courier New", GRID_RUIDO, true);

  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    println("Sin cámara.");
    exit();
    return;
  }
  cam = new Capture(this, width, height, cameras[0]);
  cam.start();
  opencv = new OpenCV(this, width, height);

  barrasX         = new float[N_BARRAS];
  barraGlow       = new float[N_BARRAS];
  barraGlowTarget = new float[N_BARRAS];

  for (int i = 0; i < N_BARRAS; i++) {
    barrasX[i]             = map(i, 0, N_BARRAS-1, width*0.12, width*0.88);
    barraGlow[i]           = 0;
    barraGlowTarget[i]     = 0;
    barraFramesContacto[i] = 0;
    barraConfirmadaAntes[i] = false;
  }

  // Osciladores — NO play() en setup
  for (int i = 0; i < N_BARRAS; i++) {
    oscA[i] = new SinOsc(this);
    oscB[i] = new SinOsc(this);
    vocActiva[i]          = false;
    vocTimer[i]           = 0;
    vocAmp[i]             = 0;
    barraCooldown[i]      = 0;
    barraContactoAhora[i] = false;
    barraContactoAntes[i] = false;
  }
}

// ─────────────────────────────────────────────────────────────────
void draw() {
  background(0);
  if (cam.available()) cam.read();

  if (!bgCaptured) {
    bgCountdown--;
    fill(255, 220, 0);
    textFont(fontCuerpo);
    textSize(22);
    textAlign(CENTER);
    text("Alejate del encuadre... " + (bgCountdown/30+1) + "s", width/2, height/2);
    textAlign(LEFT);
    if (bgCountdown <= 0) capturarFondo();
    return;
  }

  detectarSilueta();
  checkCollisions();
  actualizarGlow();
  actualizarSintesis();

  dibujarRuido();
  dibujarBarrasFondo();
  dibujarCuerpo();
  dibujarBarrasGlow();

  updateTimers();
  dibujarHUD();
}

// ─────────────────────────────────────────────────────────────────
void capturarFondo() {
  if (bgCaptured) return;
  cam.loadPixels();
  bgFrame = createImage(width, height, RGB);
  bgFrame.loadPixels();
  for (int y = 0; y < height; y++)
    for (int x = 0; x < width; x++)
      bgFrame.pixels[y*width+x] = cam.pixels[y*width+(width-1-x)];
  bgFrame.updatePixels();
  bgCaptured = true;
  println("Fondo capturado.");
}

// ─────────────────────────────────────────────────────────────────
void detectarSilueta() {
  cam.loadPixels();
  bgFrame.loadPixels();

  puntosC.clear();
  charsC.clear();
  brightC.clear();
  puntosR.clear();
  charsR.clear();

  // Grilla CUERPO
  for (int y = GRID_CUERPO; y < height-GRID_CUERPO; y += GRID_CUERPO) {
    for (int x = GRID_CUERPO; x < width-GRID_CUERPO; x += GRID_CUERPO) {
      float suma = 0;
      int cnt = 0;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          int sx = x + dx*(GRID_CUERPO/3);
          int sy = y + dy*(GRID_CUERPO/3);
          if (sx < 0 || sx >= width || sy < 0 || sy >= height) continue;
          int idxFlip = sy*width + (width-1-sx);
          int idx     = sy*width + sx;
          color c1 = cam.pixels[idxFlip];
          color c2 = bgFrame.pixels[idx];
          suma += (abs(red(c1)-red(c2)) +
            abs(green(c1)-green(c2)) +
            abs(blue(c1)-blue(c2))) / 3.0;
          cnt++;
        }
      }
      float avg = suma / cnt;
      if (avg >= UMBRAL_CUERPO) {
        int ci = constrain((int)map(avg, UMBRAL_CUERPO, 200, 0, asciiCuerpo.length()-1),
          0, asciiCuerpo.length()-1);
        puntosC.add(new PVector(x, y));
        charsC.add(asciiCuerpo.charAt(ci));
        brightC.add(avg);
      }
    }
  }

  // Grilla RUIDO
  for (int y = GRID_RUIDO; y < height-GRID_RUIDO; y += GRID_RUIDO*2) {
    for (int x = GRID_RUIDO; x < width-GRID_RUIDO; x += GRID_RUIDO*2) {
      int sx = x, sy = y;
      int idxFlip = sy*width + (width-1-sx);
      int idx     = sy*width + sx;
      color c1 = cam.pixels[idxFlip];
      color c2 = bgFrame.pixels[idx];
      float diff = (abs(red(c1)-red(c2)) +
        abs(green(c1)-green(c2)) +
        abs(blue(c1)-blue(c2))) / 3.0;
      if (diff >= UMBRAL_RUIDO && diff < UMBRAL_CUERPO) {
        int ci = constrain((int)map(diff, UMBRAL_RUIDO, UMBRAL_CUERPO, 0, asciiRuido.length()-1),
          0, asciiRuido.length()-1);
        puntosR.add(new PVector(x, y));
        charsR.add(asciiRuido.charAt(ci));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────
void checkCollisions() {
  // Resetear contacto actual
  for (int b = 0; b < N_BARRAS; b++)
    barraContactoAhora[b] = false;

  // Solo puntos de CUERPO generan colisión
  for (int i = 0; i < puntosC.size(); i++) {
    PVector p = puntosC.get(i);
    for (int b = 0; b < N_BARRAS; b++) {
      if (abs(p.x - barrasX[b]) < GRID_CUERPO * 1.2) {
        barraContactoAhora[b] = true;
      }
    }
  }

  for (int b = 0; b < N_BARRAS; b++) {
    // Contar frames consecutivos de contacto
    if (barraContactoAhora[b]) {
      barraFramesContacto[b]++;
    } else {
      barraFramesContacto[b] = 0;
    }

    boolean confirmadoAhora = (barraFramesContacto[b] >= FRAMES_PARA_ACTIVAR);

    // Flanco: confirmado ahora, NO confirmado el frame anterior
    if (confirmadoAhora && !barraConfirmadaAntes[b] && barraCooldown[b] <= 0) {
      dispararBarra(b);
    }

    barraGlowTarget[b]       = confirmadoAhora ? 1.0 : 0.0;
    barraConfirmadaAntes[b]  = confirmadoAhora; // guardar para el próximo frame
  }
}

// ─────────────────────────────────────────────────────────────────
void dispararBarra(int b) {
  // Detener si estaba sonando
  if (vocActiva[b]) {
    oscA[b].stop();
    oscB[b].stop();
  }

  oscA[b].freq(barraFreqs[b]);
  oscB[b].freq(barraFreqs[b] * 1.003);
  oscA[b].amp(0.28);
  oscB[b].amp(0.14);
  oscA[b].play();
  oscB[b].play();

  vocTimer[b]      = VOC_DUR;
  vocAmp[b]        = 0.28;
  vocActiva[b]     = true;
  barraCooldown[b] = BARRA_COOL;

  println("Barra " + b + " disparada — " + barraFreqs[b] + " Hz");
}

// ─────────────────────────────────────────────────────────────────
void actualizarSintesis() {
  float dt = 1.0 / frameRate;
  for (int b = 0; b < N_BARRAS; b++) {
    if (vocActiva[b]) {
      vocTimer[b] -= dt;
      float t = constrain(vocTimer[b] / VOC_DUR, 0, 1);

      // Envelope arpa: attack rápido, decay logarítmico suave
      float env = (t > 0.95) ?
        map(t, 1.0, 0.95, 0.0, 1.0) :
        pow(t / 0.95, 0.5);
      env = max(0, env);

      oscA[b].amp(env * vocAmp[b]);
      oscB[b].amp(env * vocAmp[b] * 0.5);

      if (vocTimer[b] <= 0) {
        oscA[b].stop();
        oscB[b].stop();
        vocActiva[b] = false;
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────
void actualizarGlow() {
  for (int b = 0; b < N_BARRAS; b++) {
    float vel = (barraGlowTarget[b] > barraGlow[b]) ? 0.20 : 0.035;
    barraGlow[b] = lerp(barraGlow[b], barraGlowTarget[b], vel);
  }
}

// ─────────────────────────────────────────────────────────────────
void dibujarRuido() {
  textFont(fontRuido);
  textSize(GRID_RUIDO);
  noStroke();
  for (int i = 0; i < puntosR.size(); i++) {
    PVector p = puntosR.get(i);
    char c    = charsR.get(i);
    fill(255, 255, 255, 22);
    text(c, p.x, p.y);
  }
}

// ─────────────────────────────────────────────────────────────────
void dibujarCuerpo() {
  textFont(fontCuerpo);
  textSize(GRID_CUERPO);
  noStroke();

  for (int i = 0; i < puntosC.size(); i++) {
    PVector p    = puntosC.get(i);
    float bright = brightC.get(i);
    char c       = charsC.get(i);

    float t    = map(bright, UMBRAL_CUERPO, 220, 0, 1);
    color base = lerpColor(color(160, 160, 170), color(240, 240, 255), t);

    // Teñir si está cerca de barra activa
    float glowMax = 0;
    int   barMas  = -1;
    for (int b = 0; b < N_BARRAS; b++) {
      float dist = abs(p.x - barrasX[b]);
      if (dist < GRID_CUERPO * 5 && barraGlow[b] > glowMax) {
        glowMax = barraGlow[b];
        barMas  = b;
      }
    }

    color finalColor = (barMas >= 0 && glowMax > 0.05) ?
      lerpColor(base, barraCols[barMas], glowMax * 0.80) : base;

    float alfa = map(bright, UMBRAL_CUERPO, 220, 160, 255);
    fill(finalColor, alfa);
    text(c, p.x - GRID_CUERPO/2, p.y + GRID_CUERPO/2);
  }
}

// ─────────────────────────────────────────────────────────────────
void dibujarBarrasFondo() {
  for (int b = 0; b < N_BARRAS; b++) {
    stroke(255, 255, 255, 6);
    strokeWeight(1);
    line(barrasX[b], 0, barrasX[b], height);
  }
}

// ─────────────────────────────────────────────────────────────────
void dibujarBarrasGlow() {
  for (int b = 0; b < N_BARRAS; b++) {
    float g = barraGlow[b];
    if (g < 0.01) continue;
    float bx = barrasX[b];
    color c  = barraCols[b];
    float r  = red(c), gr = green(c), bl = blue(c);

    stroke(r, gr, bl, 10 * g);
    strokeWeight(50);
    line(bx, 0, bx, height);

    stroke(r, gr, bl, 25 * g);
    strokeWeight(20);
    line(bx, 0, bx, height);

    stroke(r, gr, bl, 60 * g);
    strokeWeight(8);
    line(bx, 0, bx, height);

    stroke(r, gr, bl, 200 * g);
    strokeWeight(1.5);
    line(bx, 0, bx, height);

    // Burst de impacto al disparar
    if (vocActiva[b]) {
      float t = vocTimer[b] / VOC_DUR;
      if (t > 0.88) {
        float burst = map(t, 1.0, 0.88, 0, 1);
        noStroke();
        for (int k = 0; k < 8; k++) {
          float py = random(height);
          float px = bx + random(-25, 25) * burst;
          float sz = random(3, 7) * burst;
          fill(r, gr, bl, 220 * burst * random(0.5, 1.0));
          ellipse(px, py, sz, sz);
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────
void updateTimers() {
  float dt = 1.0 / frameRate;
  for (int b = 0; b < N_BARRAS; b++)
    if (barraCooldown[b] > 0) barraCooldown[b] -= dt;
}

// ─────────────────────────────────────────────────────────────────
void dibujarHUD() {
  textFont(fontRuido);
  textSize(10);
  textAlign(LEFT);
  fill(255, 35);
  text("r=fondo  [/]=umbral cuerpo:" + (int)UMBRAL_CUERPO +
    "  1-6=test barras  puntos:" + puntosC.size(), 12, height-10);

  for (int b = 0; b < N_BARRAS; b++) {
    if (barraGlow[b] > 0.05) {
      color c = barraCols[b];
      fill(red(c), green(c), blue(c), 160 * barraGlow[b]);
      text("■ ", 12 + b*22, height-24);
    }
  }
}

// ─────────────────────────────────────────────────────────────────
void keyPressed() {

  if (key == ESC) {
    exit();
    println("Saliendo del modo pantalla completa...");
  }

  if (key == 'r' || key == 'R') {
    bgCaptured = false;
    bgCountdown = 60;
  }
  if (key == ']') UMBRAL_CUERPO = min(UMBRAL_CUERPO + 5, 120);
  if (key == '[') UMBRAL_CUERPO = max(UMBRAL_CUERPO - 5, 25);
  // Test manual de cada barra con teclas 1-6
  if (key >= '1' && key <= '6') {
    int b = key - '1';
    dispararBarra(b);
  }
}

void captureEvent(Capture c) {
  c.read();
}
