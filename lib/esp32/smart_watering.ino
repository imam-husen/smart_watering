// ===============================================================
// SMART WATERING SYSTEM
// Dengan koneksi ke Firebase Realtime Database + Blynk
// ===============================================================

#define BLYNK_TEMPLATE_ID "TMPL6qaH6dgCC"
#define BLYNK_TEMPLATE_NAME "Watering System"
#define BLYNK_AUTH_TOKEN "5F_PN5P21xqv58PWjQALeBVQV4P914qA"
#define BLYNK_PRINT Serial

// ------------------- Library -------------------
#include <WiFi.h>
#include <WiFiClient.h>
#include <BlynkSimpleEsp32.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "time.h"
#include <LiquidCrystal_I2C.h>

// ------------------- Pin dan Variabel -------------------
#define SENSOR_PIN 33
#define RELAY_PIN  32

LiquidCrystal_I2C lcd(0x27, 16, 2);
BlynkTimer timer;

// ------------------- Konfigurasi WiFi -------------------
const char* WIFI_SSID = "Ikan Kayang";
const char* WIFI_PASSWORD = "hitodddd";

// ------------------- Konfigurasi Firebase -------------------
const String API_KEY = "AIzaSyBJYDqhP8IuoCXUlv3j14VdObhNc7U_ByE";
const String DATABASE_URL = "https://smart-water-45150-default-rtdb.asia-southeast1.firebasedatabase.app/";
const String USER_EMAIL = "imam.digidreams@gmail.com";
const String USER_PASSWORD = "imam123";

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
bool firebaseReady = false;

// ------------------- Auto logic state -------------------
bool autoModeLocal = false;
int autoThresholdLocal = 65; // default
int autoCooldownLocal = 300; // seconds default
unsigned long lastAutoMillis = 0;
bool autoRunning = false;
unsigned long autoEndTime = 0;
int lastMoisture = 0;

// ------------------- Fungsi Waktu -------------------
// Ganti fungsi getFormattedTime dengan yang ini
String getFormattedTime() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "Unknown";
  char buffer[40];
  // ISO8601 local time (example: 2025-12-16T14:30:05+07:00)
  // strftime tidak mudah menambahkan offset, gunakan 'Z' jika ingin sederhana,
  // tapi format berikut cukup baik: YYYY-MM-DDTHH:MM:SS
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &timeinfo);
  return String(buffer);
}

void setupTime() {
  configTime(25200, 0, "pool.ntp.org", "time.nist.gov"); // UTC+7
}

// ------------------- Setup Firebase -------------------
void setupFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;

  Firebase.reconnectWiFi(true);
  Firebase.begin(&config, &auth);

  int attempts = 0;
  while (!Firebase.ready() && attempts < 10) {
    delay(1000);
    Serial.print(".");
    attempts++;
  }

  firebaseReady = Firebase.ready();
  if (firebaseReady) Serial.println("\n✅ Firebase Connected!");
  else Serial.println("\n❌ Firebase Not Connected!");
}

// ------------------- Simpan Status Terbaru -------------------
// Menulis moisture, motorState, updatedAt ke /smart_watering/status
// Ganti fungsi saveCurrentStatus dengan versi ini
// source contoh: "device", "blynk", "auto"
void saveCurrentStatus(int moisture, bool motorState, const char* source = "device") {
  if (!firebaseReady) return;
  FirebaseJson statusUpdate;
  statusUpdate.set("moisture", moisture);
  statusUpdate.set("motorState", motorState);
  statusUpdate.set("updatedAt", getFormattedTime());
  statusUpdate.set("controlSource", source);

  // Gunakan updateNode agar tidak menimpa field lain (mis. lastAutoWateredAt)
  if (Firebase.RTDB.updateNode(&fbdo, "/smart_watering/status", &statusUpdate)) {
    Serial.println("✅ Status updated to Firebase (merged)");
  } else {
    Serial.println("❌ Failed update status: " + fbdo.errorReason());
  }
}

// ------------------- Simpan History (dengan source/type optional) -------------------
void saveHistory(int moisture, bool motorState, const char* source = "device", const char* type = "status", int durationSeconds = -1) {
  if (!firebaseReady) return;
  FirebaseJson data;
  data.set("moisture", moisture);
  data.set("motorState", motorState);
  data.set("timestamp", getFormattedTime());
  data.set("source", source);
  data.set("type", type);
  if (durationSeconds >= 0) data.set("duration", durationSeconds);

  String path = "/smart_watering/history/" + getFormattedTime();

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &data)) {
    Serial.println("✅ History saved to Firebase");
  } else {
    Serial.println("❌ Failed to save history: " + fbdo.errorReason());
  }
}

// ------------------- Simpan Auto Watering (history + update status.lastAuto*) -------------------
void saveAutoWatering(int durationSeconds) {
  if (!firebaseReady) return;
  String iso = getFormattedTime();

  // push history entry marked as auto
  FirebaseJson hist;
  hist.set("timestamp", iso);
  hist.set("duration", durationSeconds);
  hist.set("source", "auto");
  hist.set("type", "auto_watering");
  hist.set("motorState", true);

  String historyPath = "/smart_watering/history/" + iso;
  if (Firebase.RTDB.setJSON(&fbdo, historyPath.c_str(), &hist)) {
    Serial.println("✅ Auto watering history saved");
  } else {
    Serial.println("❌ Failed saving auto history: " + fbdo.errorReason());
  }

  // update status node with lastAutoWateredAt & lastAutoDuration
  FirebaseJson statusData;
  statusData.set("lastAutoWateredAt", iso);
  statusData.set("lastAutoDuration", durationSeconds);
  statusData.set("updatedAt", iso);

  if (Firebase.RTDB.updateNode(&fbdo, "/smart_watering/status", &statusData)) {
    Serial.println("✅ lastAutoWateredAt/Duration updated in status");
  } else {
    Serial.println("❌ Failed updating status lastAuto*: " + fbdo.errorReason());
  }
}

// ------------------- Baca konfigurasi auto dari RTDB (jika tersedia) -------------------
void fetchAutoConfigFromDB() {
  if (!firebaseReady) return;

  // autoMode
  if (Firebase.RTDB.getBool(&fbdo, "/smart_watering/status/autoMode")) {
    autoModeLocal = fbdo.boolData();
  }

  // autoThreshold
  if (Firebase.RTDB.getInt(&fbdo, "/smart_watering/status/autoThreshold")) {
    autoThresholdLocal = fbdo.intData();
  }

  // autoCooldownSeconds
  if (Firebase.RTDB.getInt(&fbdo, "/smart_watering/status/autoCooldownSeconds")) {
    autoCooldownLocal = fbdo.intData();
  }
}

// ------------------- Mapping kelembapan -> durasi siram (detik) -------------------
int getDurationForMoisture(int moisture) {
  if (moisture <= 20) return 20;
  if (moisture <= 40) return 15;
  if (moisture <= 59) return 7; // pilih nilai tengah 5-10
  // 60-70 and >70 => 0 detik (tidak siram otomatis)
  return 0;
}

// ------------------- Baca Sensor -------------------
void readSoilMoisture() {
  int value = analogRead(SENSOR_PIN);
  value = map(value, 0, 4095, 0, 100);
  value = (value - 100) * -1;  // ubah ke persen
  lastMoisture = value;

  bool motorState = (digitalRead(RELAY_PIN) == LOW);

  // Tampilkan di LCD & Blynk
  lcd.setCursor(0, 0);
  lcd.print("Moisture: ");
  lcd.print(value);
  lcd.print("   ");
  Blynk.virtualWrite(V0, value);

  // Ambil konfigurasi auto dari DB (so that we respond to changes)
  fetchAutoConfigFromDB();

  // Cek apakah kita harus memicu auto-watering
  if (!autoRunning && autoModeLocal) {
    unsigned long now = millis();
    if (value <= autoThresholdLocal && (now - lastAutoMillis) > ((unsigned long)autoCooldownLocal * 1000UL)) {
      int dur = getDurationForMoisture(value);
      if (dur > 0) {
        // mulai auto watering (non-blocking)
        digitalWrite(RELAY_PIN, LOW); // nyalakan motor (aktif LOW)
        lcd.setCursor(0, 1);
        lcd.print("Motor is ON ");
        autoRunning = true;
        autoEndTime = millis() + ((unsigned long)dur * 1000UL);
        lastAutoMillis = millis();

        // Simpan ke DB: history dan status.lastAuto*
        saveAutoWatering(dur);
        // Simpan status/histori umum juga
        saveCurrentStatus(value, true);
      }
      // jika dur == 0, berarti tidak perlu siram otomatis untuk range ini
    }
  }

  // Jika sedang autoRunning, cek apakah waktunya berhenti
  if (autoRunning) {
    if (millis() >= autoEndTime) {
      autoRunning = false;
      digitalWrite(RELAY_PIN, HIGH); // matikan motor
      lcd.setCursor(0, 1);
      lcd.print("Motor is OFF");
      // simpan status selesai
      saveCurrentStatus(value, false);
      saveHistory(value, false, "auto", "auto_watering", 0);
    }
  } else {
    // Simpan status & history default periodik
    saveCurrentStatus(value, motorState);
    saveHistory(value, motorState);
  }
}

// ------------------- Kontrol dari Blynk -------------------
// Ganti BLYNK_WRITE(V1) dengan versi ini
BLYNK_WRITE(V1) {
  bool relayState = param.asInt();
  if (relayState == 1) {
    digitalWrite(RELAY_PIN, LOW);
    lcd.setCursor(0, 1);
    lcd.print("Motor is ON ");
  } else {
    digitalWrite(RELAY_PIN, HIGH);
    lcd.setCursor(0, 1);
    lcd.print("Motor is OFF");
  }

  int moisture = analogRead(SENSOR_PIN);
  moisture = map(moisture, 0, 4095, 0, 100);
  moisture = (moisture - 100) * -1;

  // Simpan status dan histori saat tombol Blynk ditekan. Tandai sumber sebagai "blynk".
  saveCurrentStatus(moisture, relayState, "blynk");
  saveHistory(moisture, relayState, "blynk", "manual_control");
}

// ------------------- Sinkronisasi dari Firebase (polling) -------------------
// Function ini akan membaca /smart_watering/status/motorState dari RTDB
// dan mengubah relay jika nilai remote berbeda dari state lokal.
// Poling sederhana — interval dapat disesuaikan.
void checkRemoteMotorState() {
  if (!firebaseReady) return;

  // Baca nilai motorState dari path status/motorState
  if (Firebase.RTDB.getBool(&fbdo, "/smart_watering/status/motorState")) {
    bool remoteState = fbdo.boolData(); // true => ON, false => OFF
    bool localState = (digitalRead(RELAY_PIN) == LOW); // aktif LOW

    if (remoteState != localState) {
      if (remoteState) {
        digitalWrite(RELAY_PIN, LOW); // nyalakan motor
        lcd.setCursor(0, 1);
        lcd.print("Motor is ON ");
      } else {
        digitalWrite(RELAY_PIN, HIGH); // matikan motor
        lcd.setCursor(0, 1);
        lcd.print("Motor is OFF");
      }
      Serial.println(String("🔁 Motor state updated from DB: ") + (remoteState ? "ON" : "OFF"));
      // update local variables
    }
  } else {
    // Gagal membaca (mis. path tidak ada atau error)
    Serial.println("❌ Failed to read motorState: " + fbdo.errorReason());
  }
}

// ------------------- Setup -------------------
void setup() {
  Serial.begin(115200);
  lcd.init();
  lcd.backlight();

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH); // Motor OFF by default

  Serial.print("Connecting to WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ WiFi Connected!");

  setupTime();
  setupFirebase();

  Blynk.begin(BLYNK_AUTH_TOKEN, WIFI_SSID, WIFI_PASSWORD, "blynk.cloud", 80);

  timer.setInterval(10000L, readSoilMoisture); // kirim data tiap 10 detik
  timer.setInterval(3000L, checkRemoteMotorState); // cek DB untuk perintah ON/OFF tiap 3 detik

  // Sinkron awal dari DB (jika tersedia)
  fetchAutoConfigFromDB();
  checkRemoteMotorState();
}

// ------------------- Loop -------------------
void loop() {
  Blynk.run();
  timer.run();
}