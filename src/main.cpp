#include <WiFi.h>
#include <TFT_eSPI.h>
#include <XPT2046_Touchscreen.h>
#include <WiFiManager.h>
#include "time.h"
#include "sprite_frames.h"

// --- CYD PIN CONFIGURATION ---
#define XPT2046_IRQ  36
#define XPT2046_MOSI 32
#define XPT2046_MISO 39
#define XPT2046_CLK  25
#define XPT2046_CS   33
#define BACKLIGHT_PIN 21 

TFT_eSPI tft = TFT_eSPI();
SPIClass touchSPI = SPIClass(VSPI);
XPT2046_Touchscreen ts(XPT2046_CS, XPT2046_IRQ);

int currentMode = 0; 
bool isAutoCycle = true; 
unsigned long modeTimer = 0;
const unsigned long interval = 60000; 
bool modeChanged = true;

uint8_t spriteFrame = 0;
uint8_t spriteAnim = 0;
unsigned long lastSpriteFrame = 0;

void nextMode();
void runSprite();
void runClock();

void setup() {
  tft.init();
  tft.invertDisplay(true);
  tft.setRotation(0); 
  pinMode(BACKLIGHT_PIN, OUTPUT); digitalWrite(BACKLIGHT_PIN, HIGH);
  touchSPI.begin(XPT2046_CLK, XPT2046_MISO, XPT2046_MOSI, XPT2046_CS);
  ts.begin(touchSPI); ts.setRotation(0);

  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(0x07FF);
  tft.setTextSize(2); tft.drawCentreString("STARTING WIFI...", 120, 140, 1);
  tft.drawCentreString("Connect to AP:", 120, 165, 1);
  tft.setTextColor(TFT_ORANGE);
  tft.setTextSize(3); tft.drawCentreString("Clawdeck", 120, 200, 1);
  tft.setTextColor(0x07FF);
  tft.setTextSize(1); tft.drawCentreString("then open 192.168.4.1", 120, 240, 1);

  WiFiManager wm;
  wm.setConfigPortalTimeout(300);
  if (!wm.autoConnect("Clawdeck")) {
    tft.fillScreen(TFT_BLACK);
    tft.setTextColor(TFT_RED);
    tft.setTextSize(3); tft.drawCentreString("WIFI FAILED", 120, 150, 1);
    tft.setTextSize(2); tft.drawCentreString("Restarting...", 120, 190, 1);
    delay(3000);
    ESP.restart();
  }
  
  tft.fillScreen(0x07E0); tft.setTextColor(TFT_BLACK);
  tft.setTextSize(3); tft.drawCentreString("CONNECTED!", 120, 160, 1);
  configTime(3600, 3600, "pool.ntp.org");
  delay(1000); tft.fillScreen(TFT_BLACK);
  modeTimer = millis();
}

void loop() {
  if (ts.touched()) { isAutoCycle = false; nextMode(); delay(400); }
  if (isAutoCycle && (millis() - modeTimer > interval)) nextMode();

  switch (currentMode) {
    case 0: runClock(); break;
    case 1: runSprite(); break;
  }
}

void nextMode() { currentMode = (currentMode + 1) % 2; modeChanged = true; modeTimer = millis(); tft.fillScreen(TFT_BLACK); }

void runSprite() {
  if (modeChanged) { tft.fillScreen(TFT_BLACK); spriteAnim = random(SPRITE_ANIM_COUNT); spriteFrame = 0; modeChanged = false; }
  uint16_t offset = pgm_read_word(&sprite_anim_offset[spriteAnim]);
  uint8_t count = pgm_read_byte(&sprite_anim_count[spriteAnim]);
  if (millis() - lastSpriteFrame < pgm_read_word(&sprite_hold[offset + spriteFrame])) return;
  lastSpriteFrame = millis();
  static const uint16_t colors[] = {TFT_BLACK, TFT_ORANGE, TFT_BLACK, TFT_CYAN, TFT_DARKGREY, TFT_WHITE};
  const int cell = 8;
  const int px = 7;
  const int xOff = (240 - SPRITE_W * cell) / 2;
  const int yOff = (320 - SPRITE_H * cell) / 2;
  for (int y = 0; y < SPRITE_H; y++) {
    for (int x = 0; x < SPRITE_W; x++) {
      uint8_t v = pgm_read_byte(&sprite_data[offset + spriteFrame][y * SPRITE_W + x]);
      tft.fillRect(xOff + x * cell, yOff + y * cell, px, px, colors[v]);
    }
  }
  spriteFrame = (spriteFrame + 1) % count;
}

void runClock() {
  if (modeChanged) {
    tft.drawRoundRect(5, 5, 230, 95, 10, 0xF81F);
    tft.drawRoundRect(5, 105, 230, 55, 10, 0x07FF);
    tft.drawRoundRect(5, 165, 230, 150, 10, 0xFFE0);
    modeChanged = false;
  }
  struct tm ti; if(!getLocalTime(&ti)) return;
  static int lsec = -1;
  if (ti.tm_sec != lsec) {
    tft.setTextDatum(MC_DATUM); tft.setTextColor(0xFFFF, TFT_BLACK);
    char tB[10]; sprintf(tB, (ti.tm_sec % 2 == 0) ? "%02d:%02d" : "%02d %02d", ti.tm_hour, ti.tm_min);
    tft.setTextSize(4); tft.drawString(tB, 120, 50, 1); 
    char dB[20], dyB[20]; strftime(dB, 20, "%b %d, %Y", &ti); strftime(dyB, 20, "%A", &ti);
    tft.setTextSize(2); tft.drawString(dyB, 120, 200, 1); tft.setTextColor(0xFFE0, TFT_BLACK); tft.drawString(dB, 120, 240, 1);
    if (ti.tm_sec == 0) tft.fillRect(10, 115, 220, 35, TFT_BLACK);
    for (int i = 0; i < 60; i++) {
      int xP = 10 + (i * 3.6);
      if (i <= ti.tm_sec) {
        uint8_t h = i * 4.25; uint8_t r,g,b;
        if(h<85){r=255-h*3;g=h*3;b=0;} else if(h<170){h-=85;r=0;g=255-h*3;b=h*3;} else {h-=170;r=h*3;g=0;b=255-h*3;}
        tft.fillRect(xP, 115, 2, 35, tft.color565(r,g,b));
      } else tft.fillRect(xP, 115, 2, 35, 0x2104);
    }
    int32_t rssi = WiFi.RSSI(); int bars = (rssi > -50) ? 4 : (rssi > -70) ? 3 : (rssi > -85) ? 2 : 1;
    for (int i = 0; i < 4; i++) { tft.fillRect(100 + (i * 8), 305 - ((i + 1) * 5), 6, (i + 1) * 5, (i < bars) ? 0x07E0 : 0x3186); }
    lsec = ti.tm_sec;
  }
}
