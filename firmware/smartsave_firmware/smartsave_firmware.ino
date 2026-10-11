/*
 * SmartSave firmware - protocol v1 (real hardware)
 * ------------------------------------------------
 * The stub's protocol, PIN, EEPROM and sync code is UNCHANGED, so the Flutter
 * app and backend see exactly the same lines (COIN, TOTAL, LOCK, SEQ, ...).
 * What is new: real IR coin sensors, I2C LCD, servo lock and buzzer.
 * Not compiled/tested by the author: verify on your board.
 *
 * Libraries (Library Manager): "hd44780" by Bill Perry.
 * (Servo, Wire, EEPROM and SoftwareSerial come with the Arduino IDE.)
 *
 * Pins:
 *   D2  <- HM-10 TXD            D3  -> HM-10 RXD (1k/2k divider)
 *   D4..D7  IR sensors OUT (1, 5, 10, 20 peso)
 *   D8  buzzer + (active)       D9  servo signal
 *   A4/A5  LCD SDA/SCL          (D0/D1 stay free: USB)
 *
 * Things to adjust after your bench tests are marked "TUNE" below.
 *
 * Serial Monitor (115200, newline) works as in the stub:
 *   protocol lines, SIM:<1|5|10|20> fake coin, FACTORY wipe state.
 *
 * NOTE: SoftwareSerial disables interrupts while it transmits (~1 ms/byte at
 * 9600), so a very fast coin could be missed during a send. Test 50 drops per
 * slot. The loop never uses delay().
 */
#include <SoftwareSerial.h>
#include <EEPROM.h>
#include <Servo.h>
#include <Wire.h>
#include <hd44780.h>
#include <hd44780ioClass/hd44780_I2Cexp.h>
#include <stdarg.h>

// ---------------- Protocol configuration (same as the stub) ----------------
#define PROTO_VERSION    1
#define PIN_BLE_RX       2
#define PIN_BLE_TX       3
#define BLE_BAUD         9600
#define LINE_MAX         24
#define PIN_LEN          4
#define MAX_TOTAL        99999UL
#define PENDING_SIZE     32
#define MAX_FAILS        3
#define LOCKOUT_MS       30000UL
#define AUTO_RELOCK_MS   30000UL
#define EEPROM_MAGIC     0x5A

// ---------------- Hardware configuration ----------------
const uint8_t PIN_IR[4] = {4, 5, 6, 7};        // sensors for 1, 5, 10, 20 peso
const uint8_t DENOM[4]  = {1, 5, 10, 20};
#define PIN_BUZZER       8
#define PIN_SERVO        9

#define IR_ACTIVE        LOW     // TUNE: level the sensor outputs when a coin is detected
#define COIN_GAP_MS      300UL   // TUNE: ignore re-triggers of the same sensor (one coin)
#define ANGLE_LOCKED     0       // TUNE: servo angle, locked
#define ANGLE_UNLOCKED   90      // TUNE: servo angle, unlocked
#define SERVO_MOVE_MS    600UL   // time the servo stays powered after a move
#define BEEP_MS          40UL    // buzzer beep per coin (active buzzer)
#define SIMULATE_COINS   0       // 1 = fake coin every 10 s (testing only)
#define SIM_INTERVAL_MS  10000UL

// ---------------- State (Persist layout identical to the stub) ----------------
struct Persist {
  uint8_t  magic;
  uint8_t  pinSet;
  char     pin[PIN_LEN + 1];
  uint32_t total;
  uint16_t seq;
  uint16_t acked;
  uint8_t  pending[PENDING_SIZE];
};

struct LineReader {
  char    buf[LINE_MAX];
  uint8_t len;
  bool    overflow;
};

SoftwareSerial ble(PIN_BLE_RX, PIN_BLE_TX);
hd44780_I2Cexp lcd;
Servo lockServo;
Persist  st;
LineReader bleRx = {{0}, 0, false};
LineReader usbRx = {{0}, 0, false};

bool          locked      = true;
uint32_t      unlockedAt  = 0;
uint8_t       failCount   = 0;
uint32_t      lockoutAt   = 0;
uint32_t      lastSim     = 0;

bool          lcdOk       = false;
bool          lcdDirty    = true;
bool          servoOn     = false;
uint32_t      servoOffAt  = 0;
bool          buzzerOn    = false;
uint32_t      buzzerOffAt = 0;
bool          irPrev[4]   = {false, false, false, false};
uint32_t      irLast[4]   = {0, 0, 0, 0};

enum PinResult { PIN_OK, PIN_FAIL, PIN_WAIT };

// ---------------- Output ----------------
void emit(const char* fmt, ...) {
  char buf[24];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(buf, sizeof(buf), fmt, ap);
  va_end(ap);
  ble.print(buf);
  ble.print('\n');
  Serial.print(F("TX> "));
  Serial.println(buf);
}

// ---------------- Hardware layer ----------------
void hwSetLock(bool lock) {
  if (!servoOn) {
    lockServo.attach(PIN_SERVO);
    servoOn = true;
  }
  lockServo.write(lock ? ANGLE_LOCKED : ANGLE_UNLOCKED);
  servoOffAt = millis() + SERVO_MOVE_MS;    // detached later in servoService()
  lcdDirty = true;
  Serial.print(F("[SERVO] "));
  Serial.println(lock ? F("LOCKED") : F("UNLOCKED"));
}

void hwShowTotal() {
  lcdDirty = true;                          // drawn in lcdService(), after sensors are polled
  Serial.print(F("[LCD] Total: P"));
  Serial.println(st.total);
}

void beep(uint32_t ms) {
  digitalWrite(PIN_BUZZER, HIGH);
  buzzerOn = true;
  buzzerOffAt = millis() + ms;
}

void servoService() {
  if (servoOn && (long)(millis() - servoOffAt) >= 0) {
    lockServo.detach();                     // no jitter, no idle current
    servoOn = false;
  }
}

void buzzerService() {
  if (buzzerOn && (long)(millis() - buzzerOffAt) >= 0) {
    digitalWrite(PIN_BUZZER, LOW);
    buzzerOn = false;
  }
}

void lcdService() {
  if (!lcdDirty) return;
  lcdDirty = false;
  if (!lcdOk) return;
  lcd.setCursor(0, 0);
  lcd.print(locked ? F("SmartSave:LOCKED") : F("SmartSave:OPEN  "));
  char line[17];
  snprintf(line, sizeof(line), "Total: P%-8lu", (unsigned long)st.total);
  lcd.setCursor(0, 1);
  lcd.print(line);
}

// ---------------- Persistence ----------------
void saveState() { EEPROM.put(0, st); }

void factoryReset() {
  memset(&st, 0, sizeof(st));
  st.magic = EEPROM_MAGIC;
  saveState();
}

void loadState() {
  EEPROM.get(0, st);
  if (st.magic != EEPROM_MAGIC) factoryReset();
}

// ---------------- Helpers ----------------
bool parseU32(const char* s, uint32_t* out) {
  if (!s || !*s) return false;
  uint32_t v = 0;
  for (; *s; s++) {
    if (*s < '0' || *s > '9') return false;
    v = v * 10 + (uint32_t)(*s - '0');
    if (v > 999999UL) return false;
  }
  *out = v;
  return true;
}

bool splitPin(const char* arg, char* pinOut, const char** rest) {
  uint8_t n = 0;
  while (arg[n] && arg[n] != ',') n++;
  if (n != PIN_LEN) return false;
  for (uint8_t i = 0; i < n; i++) {
    if (arg[i] < '0' || arg[i] > '9') return false;
    pinOut[i] = arg[i];
  }
  pinOut[n] = '\0';
  *rest = (arg[n] == ',') ? arg + n + 1 : NULL;
  return true;
}

PinResult checkPin(const char* given) {
  if (failCount >= MAX_FAILS) {
    if ((long)(millis() - lockoutAt) < 0) return PIN_WAIT;
    failCount = 0;
  }
  if (st.pinSet && strcmp(given, st.pin) == 0) {
    failCount = 0;
    return PIN_OK;
  }
  if (++failCount >= MAX_FAILS) lockoutAt = millis() + LOCKOUT_MS;
  return PIN_FAIL;
}

bool authorize(const char* arg, const char** rest) {
  char pin[PIN_LEN + 1];
  if (!st.pinSet)                   { emit("AUTH:NEW"); return false; }
  if (!splitPin(arg, pin, rest))    { emit("ERR:FMT");  return false; }
  PinResult r = checkPin(pin);
  if (r == PIN_WAIT)                { emit("AUTH:WAIT"); return false; }
  if (r == PIN_FAIL)                { emit("AUTH:FAIL"); return false; }
  return true;
}

void setLock(bool lock) {
  locked = lock;
  if (!lock) unlockedAt = millis();
  hwSetLock(lock);
}

// ---------------- Coins ----------------
void onCoin(uint8_t denom) {
  if (denom != 1 && denom != 5 && denom != 10 && denom != 20) return;
  st.seq++;
  st.pending[st.seq % PENDING_SIZE] = denom;
  st.total += denom;
  if (st.total > MAX_TOTAL) st.total = MAX_TOTAL;
  saveState();
  hwShowTotal();
  beep(BEEP_MS);
  emit("COIN:%u,%u", (unsigned)denom, (unsigned)st.seq);
  emit("TOTAL:%lu", (unsigned long)st.total);
}

// Edge-detect each IR sensor; one coin = one inactive-to-active transition.
void pollSensors() {
  uint32_t now = millis();
  for (uint8_t i = 0; i < 4; i++) {
    bool hit = (digitalRead(PIN_IR[i]) == IR_ACTIVE);
    if (hit && !irPrev[i] && (now - irLast[i]) >= COIN_GAP_MS) {
      irLast[i] = now;
      onCoin(DENOM[i]);
    }
    irPrev[i] = hit;
  }
}

void replayPending() {
  uint16_t unacked = (uint16_t)(st.seq - st.acked);
  if (unacked > PENDING_SIZE) unacked = PENDING_SIZE;
  for (uint16_t i = unacked; i > 0; i--) {
    uint16_t s = (uint16_t)(st.seq - i + 1);
    emit("COIN:%u,%u", (unsigned)st.pending[s % PENDING_SIZE], (unsigned)s);
  }
}

void handleAck(uint32_t s) {
  if (s > 65535UL) return;
  uint16_t newly       = (uint16_t)((uint16_t)s - st.acked);
  uint16_t outstanding = (uint16_t)(st.seq - st.acked);
  if (newly > 0 && newly <= outstanding) {
    st.acked = (uint16_t)s;
    saveState();
  }
}

// ---------------- Command handling (same as the stub) ----------------
void handleLine(char* line, bool fromUsb) {
  Serial.print(F("RX< "));
  Serial.println(line);

  const char* arg = "";
  char* colon = strchr(line, ':');
  if (colon) { *colon = '\0'; arg = colon + 1; }
  const char* cmd = line;
  const char* rest = NULL;
  uint32_t n = 0;

  if (strcmp(cmd, "HELLO") == 0) {
    emit("PROTO:%d", PROTO_VERSION);
    emit(st.pinSet ? "AUTH:REQ" : "AUTH:NEW");

  } else if (strcmp(cmd, "AUTH") == 0) {
    if (authorize(arg, &rest)) emit("AUTH:OK");

  } else if (strcmp(cmd, "SETPIN") == 0) {
    char pin[PIN_LEN + 1];
    if (!st.pinSet) {
      if (!splitPin(arg, pin, &rest) || rest != NULL) { emit("ERR:FMT"); return; }
      strcpy(st.pin, pin);
      st.pinSet = 1;
      saveState();
      emit("AUTH:OK");
    } else {
      if (!authorize(arg, &rest)) return;
      char newPin[PIN_LEN + 1];
      const char* tail = NULL;
      if (!rest || !splitPin(rest, newPin, &tail) || tail != NULL) { emit("ERR:FMT"); return; }
      strcpy(st.pin, newPin);
      saveState();
      emit("AUTH:OK");
    }

  } else if (strcmp(cmd, "SYNC") == 0) {
    emit("TOTAL:%lu", (unsigned long)st.total);
    emit("LOCK:%d", locked ? 1 : 0);
    emit("SEQ:%u", (unsigned)st.seq);
    replayPending();
    emit("SYNC:END");

  } else if (strcmp(cmd, "ACK") == 0) {
    if (parseU32(arg, &n)) handleAck(n);

  } else if (strcmp(cmd, "LOCK") == 0) {
    setLock(true);
    emit("LOCK:1");

  } else if (strcmp(cmd, "UNLOCK") == 0) {              // UNLOCK:<pin>,<amount>
    if (!authorize(arg, &rest)) return;
    if (!parseU32(rest, &n) || n == 0 || n > st.total) { emit("ERR:AMT"); return; }
    st.total -= n;
    saveState();
    hwShowTotal();
    setLock(false);
    emit("TOTAL:%lu", (unsigned long)st.total);
    emit("LOCK:0");

  } else if (strcmp(cmd, "ADJ") == 0) {                 // ADJ:<pin>,<newTotal>
    if (!authorize(arg, &rest)) return;
    if (!parseU32(rest, &n) || n > MAX_TOTAL) { emit("ERR:AMT"); return; }
    st.total = n;
    saveState();
    hwShowTotal();
    emit("TOTAL:%lu", (unsigned long)st.total);

  } else if (strcmp(cmd, "PING") == 0) {
    emit("PONG");

  } else if (fromUsb && strcmp(cmd, "SIM") == 0) {
    if (parseU32(arg, &n)) onCoin((uint8_t)n);

  } else if (fromUsb && strcmp(cmd, "FACTORY") == 0) {
    factoryReset();
    locked = true;
    failCount = 0;
    hwShowTotal();
    Serial.println(F("State wiped."));

  } else {
    emit("ERR:CMD");
  }
}

// ---------------- Line reading ----------------
void pollReader(Stream& s, LineReader& r, bool fromUsb) {
  while (s.available()) {
    char c = (char)s.read();
    if (c == '\r') continue;
    if (c == '\n') {
      if (!r.overflow && r.len > 0) {
        r.buf[r.len] = '\0';
        handleLine(r.buf, fromUsb);
      }
      r.len = 0;
      r.overflow = false;
    } else if (r.len < LINE_MAX - 1) {
      r.buf[r.len++] = c;
    } else {
      r.overflow = true;
    }
  }
}

// ---------------- Arduino entry points ----------------
void setup() {
  Serial.begin(115200);
  ble.begin(BLE_BAUD);
  loadState();

  for (uint8_t i = 0; i < 4; i++) {
    pinMode(PIN_IR[i], IR_ACTIVE == LOW ? INPUT_PULLUP : INPUT);
    irPrev[i] = (digitalRead(PIN_IR[i]) == IR_ACTIVE);   // no false coin at power-up
  }
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);

  int status = lcd.begin(16, 2);
  lcdOk = (status == 0);
  if (lcdOk) lcd.backlight();
  Serial.print(F("LCD status: "));
  Serial.println(status);

  setLock(true);                    // always start locked after power-up
  hwShowTotal();
  beep(BEEP_MS * 2);
  Serial.println(F("SmartSave firmware ready (protocol v1)"));
}

void loop() {
  pollSensors();                    // sensors first: coins are time-critical
  pollReader(ble, bleRx, false);
  pollReader(Serial, usbRx, true);

#if SIMULATE_COINS
  if (millis() - lastSim >= SIM_INTERVAL_MS) {
    lastSim = millis();
    static const uint8_t coins[] = {1, 5, 10, 20};
    onCoin(coins[random(0, 4)]);
  }
#endif

  if (!locked && millis() - unlockedAt >= AUTO_RELOCK_MS) {
    setLock(true);
    emit("LOCK:1");
  }

  servoService();
  buzzerService();
  lcdService();                     // slowest job goes last
}
