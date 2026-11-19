/*
  Spot Clicker firmware — Seeed Studio XIAO ESP32-C6
  Arduino IDE: board package "esp32" by Espressif (3.x), board "XIAO_ESP32C6".

  What it does
    - Advertises over Bluetooth LE as "SpotClicker".
    - Reads the keychain switch and tells the phone what kind of press it was:
        1 = single click  -> phone saves the spot as "Liked"
        2 = double click  -> phone saves the spot as "Want to go"
        3 = long press    -> phone undoes the last save
    - Plays a feedback pattern when the phone writes back (blink the onboard LED,
      and buzz the optional vibration motor).

  Wiring
    - Keychain switch: one leg to D1, the other leg to GND (internal pull-up is used).
    - Battery: LiPo red wire to the BAT+ pad on the back, black wire to BAT-.
    - Optional buzz motor: D2 -> 1 kOhm -> 2N2222 base; motor between 3V3 and collector;
      emitter to GND; 1N4148 across the motor (stripe toward 3V3). Then set MOTOR_PIN to D2.

  Bluetooth protocol (must match ClickerProtocol.swift in the iPhone app)
    Service   7a1c0001-5b3e-4d2a-9f10-3c5d8e2b6a01
    Click     7a1c0002-...  notify  2 bytes: [click type, sequence number]
    Feedback  7a1c0003-...  write   1 byte:  1 saved, 2 saved to Want to go, 3 error, 4 undone
*/

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#if defined(CONFIG_BLUEDROID_ENABLED)
#include <BLE2902.h>  // older Bluetooth stack needs the notify descriptor added by hand
#endif

#define SERVICE_UUID  "7a1c0001-5b3e-4d2a-9f10-3c5d8e2b6a01"
#define CLICK_UUID    "7a1c0002-5b3e-4d2a-9f10-3c5d8e2b6a01"
#define FEEDBACK_UUID "7a1c0003-5b3e-4d2a-9f10-3c5d8e2b6a01"
#define DEVICE_NAME   "SpotClicker"

void setOutput(bool on);
void play(const uint16_t* steps, uint8_t len);
void updatePattern();
void sendClick(uint8_t type);
void readButton();
void startAdvertising();

// ---- Pins -----------------------------------------------------------------
const int  BUTTON_PIN     = D1;           // switch between D1 and GND
const int  LED_PIN        = LED_BUILTIN;  // onboard yellow LED
const bool LED_ACTIVE_LOW = true;         // XIAO ESP32-C6 LED lights when the pin is LOW
const int  MOTOR_PIN      = -1;           // set to D2 once the vibration motor is wired

// ---- Timing (milliseconds) --------------------------------------------------
const uint32_t DEBOUNCE_MS   = 25;   // ignore switch bounce shorter than this
const uint32_t DOUBLE_GAP_MS = 350;  // a second press within this time makes a double click
const uint32_t LONG_PRESS_MS = 800;  // holding this long makes a long press

// ---- Feedback patterns: on, off, on, off ... ----------------------------------
const uint16_t P_SAVED[] = {150};
const uint16_t P_WANT[]  = {90, 90, 90};
const uint16_t P_ERROR[] = {60, 60, 60, 60, 60};
const uint16_t P_UNDO[]  = {450};

// ---- State ---------------------------------------------------------------------
BLEServer*         server       = nullptr;
BLECharacteristic* clickChar    = nullptr;
volatile bool      connected    = false;
volatile bool      readvertise  = false;
volatile int       feedbackCode = 0;      // set by the phone, handled in loop()
uint8_t            sequence     = 0;

// Button
bool     rawLast       = HIGH;
bool     stable        = HIGH;
uint32_t rawChangedAt  = 0;
uint32_t pressedAt     = 0;
uint32_t lastReleaseAt = 0;
uint8_t  clickCount    = 0;
bool     longFired     = false;

// Pattern player
const uint16_t* pattern     = nullptr;
uint8_t         patternLen  = 0;
uint8_t         patternStep = 0;
uint32_t        stepStarted = 0;

// ---- Output helpers ------------------------------------------------------------
void setOutput(bool on) {
  digitalWrite(LED_PIN, (on != LED_ACTIVE_LOW) ? HIGH : LOW);
  if (MOTOR_PIN >= 0) digitalWrite(MOTOR_PIN, on ? HIGH : LOW);
}

void play(const uint16_t* steps, uint8_t len) {
  pattern = steps;
  patternLen = len;
  patternStep = 0;
  stepStarted = millis();
  setOutput(true);
}

void updatePattern() {
  if (!pattern) return;
  if (millis() - stepStarted < pattern[patternStep]) return;
  patternStep++;
  stepStarted = millis();
  if (patternStep >= patternLen) {
    pattern = nullptr;
    setOutput(false);
    return;
  }
  setOutput(patternStep % 2 == 0);  // even steps are "on", odd steps are "off"
}

// ---- Bluetooth callbacks ---------------------------------------------------------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override { connected = true; }
  void onDisconnect(BLEServer*) override { connected = false; readvertise = true; }
};

class FeedbackCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    auto value = c->getValue();
    if (value.length() > 0) feedbackCode = (uint8_t)value[0];
  }
};

// ---- Clicks ----------------------------------------------------------------------
void sendClick(uint8_t type) {
  Serial.printf("Click type %u (connected: %s)\n", type, connected ? "yes" : "no");
  if (!connected) {
    play(P_ERROR, sizeof(P_ERROR) / sizeof(P_ERROR[0]));  // phone not in range
    return;
  }
  uint8_t payload[2] = {type, sequence++};
  clickChar->setValue(payload, sizeof(payload));
  clickChar->notify();
}

void readButton() {
  uint32_t now = millis();
  bool raw = digitalRead(BUTTON_PIN);

  if (raw != rawLast) {
    rawLast = raw;
    rawChangedAt = now;
  }

  if (now - rawChangedAt > DEBOUNCE_MS && raw != stable) {
    stable = raw;
    if (stable == LOW) {               // pressed
      pressedAt = now;
      longFired = false;
    } else {                           // released
      if (!longFired) {
        clickCount++;
        lastReleaseAt = now;
      }
    }
  }

  // Long press fires while still held, so the person feels it without letting go.
  if (stable == LOW && !longFired && now - pressedAt >= LONG_PRESS_MS) {
    longFired = true;
    clickCount = 0;
    sendClick(3);
  }

  // Single or double click: wait until no second press arrives.
  if (stable == HIGH && clickCount > 0 && now - lastReleaseAt > DOUBLE_GAP_MS) {
    sendClick(clickCount >= 2 ? 2 : 1);
    clickCount = 0;
  }
}

// ---- Setup and loop --------------------------------------------------------------
void startAdvertising() {
  BLEAdvertising* adv = BLEDevice::getAdvertising();

  // Keep the 128-bit service UUID in the advertisement (the phone filters on it)
  // and put the name in the scan response, so neither packet goes over 31 bytes.
  BLEAdvertisementData advData;
  advData.setFlags(0x06);
  advData.setCompleteServices(BLEUUID(SERVICE_UUID));
  BLEAdvertisementData scanData;
  scanData.setName(DEVICE_NAME);
  adv->setAdvertisementData(advData);
  adv->setScanResponseData(scanData);
  BLEDevice::startAdvertising();
  Serial.println("Advertising");
}

void setup() {
  Serial.begin(115200);
  setCpuFrequencyMhz(80);  // enough for Bluetooth, saves battery

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  if (MOTOR_PIN >= 0) pinMode(MOTOR_PIN, OUTPUT);
  setOutput(false);

  BLEDevice::init(DEVICE_NAME);
  server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(SERVICE_UUID);

  clickChar = service->createCharacteristic(
      CLICK_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
#if defined(CONFIG_BLUEDROID_ENABLED)
  clickChar->addDescriptor(new BLE2902());
#endif

  BLECharacteristic* feedbackChar = service->createCharacteristic(
      FEEDBACK_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  feedbackChar->setCallbacks(new FeedbackCallbacks());

  service->start();
  startAdvertising();

  play(P_SAVED, 1);  // short blink: powered on
}

void loop() {
  readButton();
  updatePattern();

  int code = feedbackCode;
  if (code) {
    feedbackCode = 0;
    switch (code) {
      case 1: play(P_SAVED, sizeof(P_SAVED) / sizeof(P_SAVED[0])); break;
      case 2: play(P_WANT,  sizeof(P_WANT)  / sizeof(P_WANT[0]));  break;
      case 3: play(P_ERROR, sizeof(P_ERROR) / sizeof(P_ERROR[0])); break;
      case 4: play(P_UNDO,  sizeof(P_UNDO)  / sizeof(P_UNDO[0]));  break;
    }
  }

  if (readvertise) {
    readvertise = false;
    delay(200);
    startAdvertising();
  }

  delay(5);
}
