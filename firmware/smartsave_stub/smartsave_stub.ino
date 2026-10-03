/*
 * SmartSave firmware STUB - protocol v1
 * -------------------------------------
 * Behaves like the finished coin bank as seen from the phone, but has NO
 * sensors, LCD, servo or buzzer. Purpose: let the Flutter team develop the
 * real BLE layer on actual phones before the hardware is finished.
 *
 * Wiring (only the HM-10 is needed):
 *   HM-10 VCC -> 5V        HM-10 GND  -> GND
 *   HM-10 TXD -> D2        (Arduino receives)
 *   HM-10 RXD <- D3        THROUGH A VOLTAGE DIVIDER (D3 --1k--+--2k-- GND,
 *                          HM-10 RXD at the junction). HM-10 pins are 3.3V.
 *
 * Testing without the HM-10: open the Serial Monitor (115200 baud, newline
 * line ending) and type protocol lines, e.g.  HELLO  or  SETPIN:1234
 * Extra USB-only commands:  SIM:<1|5|10|20>  fake a coin,  FACTORY  wipe state.
 *
 * Real firmware seams (replace later): hwSetLock(), hwShowTotal(), and the
 * coin sensor code that calls onCoin().
 *
 * NOTE for the real firmware: SoftwareSerial disables interrupts while it
 * transmits (~1 ms/byte at 9600). Keep coin-sensor polling short, and do not
 * block the loop with delay().
 */
#include <SoftwareSerial.h>
#include <EEPROM.h>
#include <stdarg.h>

// ---------------- Configuration ----------------
#define PROTO_VERSION    1
#define PIN_BLE_RX       2          // Arduino RX  <- HM-10 TXD
#define PIN_BLE_TX       3          // Arduino TX  -> HM-10 RXD (divider!)
#define BLE_BAUD         9600
#define LINE_MAX         24         // longest accepted incoming line
#define PIN_LEN          4
#define MAX_TOTAL        99999UL    // keeps every message under 20 bytes
#define PENDING_SIZE     32         // unacknowledged coins we can replay
#define MAX_FAILS        3
#define LOCKOUT_MS       30000UL
#define AUTO_RELOCK_MS   30000UL    // design choice: no door sensor
#define SIMULATE_COINS   1          // 1 = drop a fake coin periodically
#define SIM_INTERVAL_MS  10000UL
#define EEPROM_MAGIC     0x5A

// ---------------- State ----------------
struct Persist {
  uint8_t  magic;
  uint8_t  pinSet;
  char     pin[PIN_LEN + 1];
  uint32_t total;                   // authoritative balance (pesos)
  uint16_t seq;                     // sequence number of the latest coin
  uint16_t acked;                   // highest seq the app has acknowledged
  uint8_t  pending[PENDING_SIZE];   // denomination, indexed by seq % size
};

struct LineReader {
  char    buf[LINE_MAX];
  uint8_t len;
  bool    overflow;
};

SoftwareSerial ble(PIN_BLE_RX, PIN_BLE_TX);
Persist  st;
LineReader bleRx = {{0}, 0, false};
LineReader usbRx = {{0}, 0, false};

bool          locked      = true;
uint32_t      unlockedAt  = 0;
uint8_t       failCount   = 0;
uint32_t      lockoutAt   = 0;      // millis() when lockout ends
uint32_t      lastSim     = 0;

enum PinResult { PIN_OK, PIN_FAIL, PIN_WAIT };

// ---------------- Output ----------------
// One protocol line to the phone (and mirrored to USB for debugging).
// Every line must stay <= 19 chars + '\n' (BLE default packet = 20 bytes).
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

// ---------------- Hardware seams (stubs) ----------------
void hwSetLock(bool lock) {
  Serial.print(F("[SERVO] "));
  Serial.println(lock ? F("LOCKED") : F("UNLOCKED"));
}

void hwShowTotal() {
  Serial.print(F("[LCD] Total: P"));
  Serial.println(st.total);
}

// ---------------- Persistence ----------------
void saveState() { EEPROM.put(0, st); }   // put() only rewrites changed bytes

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
    if (v > 999999UL) return false;          // overflow guard
  }
  *out = v;
  return true;
}

// "1234,5000" -> pinOut="1234", *rest="5000" (rest=NULL when no comma).
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
    failCount = 0;                           // lockout expired
  }
  if (st.pinSet && strcmp(given, st.pin) == 0) {
    failCount = 0;
    return PIN_OK;
  }
  if (++failCount >= MAX_FAILS) lockoutAt = millis() + LOCKOUT_MS;
  return PIN_FAIL;
}

// Verifies the PIN at the start of `arg`. On failure the reply is already sent.
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
  st.seq++;                                  // uint16_t wraps naturally
  st.pending[st.seq % PENDING_SIZE] = denom;
  st.total += denom;
  if (st.total > MAX_TOTAL) st.total = MAX_TOTAL;
  saveState();
  hwShowTotal();
  emit("COIN:%u,%u", (unsigned)denom, (unsigned)st.seq);
  emit("TOTAL:%lu", (unsigned long)st.total);
}

void replayPending() {
  uint16_t unacked = (uint16_t)(st.seq - st.acked);
  if (unacked > PENDING_SIZE) unacked = PENDING_SIZE;   // older ones are lost
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

// ---------------- Command handling ----------------
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
    if (!st.pinSet) {                                   // first-time setup
      if (!splitPin(arg, pin, &rest) || rest != NULL) { emit("ERR:FMT"); return; }
      strcpy(st.pin, pin);
      st.pinSet = 1;
      saveState();
      emit("AUTH:OK");
    } else {                                            // change: old,new
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

  } else if (fromUsb && strcmp(cmd, "SIM") == 0) {      // USB-only test helper
    if (parseU32(arg, &n)) onCoin((uint8_t)n);

  } else if (fromUsb && strcmp(cmd, "FACTORY") == 0) {  // USB-only test helper
    factoryReset();
    locked = true;
    failCount = 0;
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
  setLock(true);                    // always start locked after power-up
  hwShowTotal();
  Serial.println(F("SmartSave stub ready (protocol v1)"));
}

void loop() {
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
}
