# ProGuard/R8 rules untuk Rehat App.
# Sebagian besar aturan Flutter & plugin sudah dibundel otomatis (consumer
# rules). Di sini hanya keep/suppress tambahan untuk komponen berbasis refleksi.

# --- Flutter ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# --- Firebase / Messaging (FCM) ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- Printer thermal Bluetooth + ESC/POS ---
-keep class com.example.print_bluetooth_thermal.** { *; }
-dontwarn com.example.print_bluetooth_thermal.**

# --- flutter_secure_storage (EncryptedSharedPreferences) ---
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Jaga anotasi & tanda tangan generik (dipakai deserialisasi JSON via refleksi).
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
