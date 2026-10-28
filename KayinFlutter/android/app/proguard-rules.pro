# ML Kit yazı tanıma: yalnız Latin alfabesi modeli pakete giriyor. Eklenti diğer alfabelerin
# (Çince, Devanagari, Japonca, Korece) sınıflarına başvuruyor ama onlar bilerek eklenmedi.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit bileşenleri yansımayla (reflection) yüklenir; küçültülünce sürüm derlemesinde
# metin tanıma NullPointerException ile çöküyordu.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }
