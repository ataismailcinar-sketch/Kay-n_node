import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../features/toprak_analizi/domain/rapor_okuyucu.dart';

/// Analiz raporunun fotoğrafındaki yazıyı telefonda (internetsiz, ML Kit) okur.
/// Yalnız Android; Windows'ta düğme gösterilmez.
class RaporOcrServisi {
  static bool get destekleniyor => !kIsWeb && Platform.isAndroid;

  /// Kamera ya da galeriden fotoğraf seçtirip satırlara dizilmiş metni döndürür. Vazgeçilirse null.
  static Future<List<String>?> fotograftanSatirlar(ImageSource kaynak) async {
    // Küçük yazılar için yüksek çözünürlük; kalite kaybı OCR'yi bozar.
    final foto = await ImagePicker().pickImage(source: kaynak, maxWidth: 2600, maxHeight: 2600, imageQuality: 95);
    if (foto == null) return null;
    final okuyucu = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final metin = await okuyucu.processImage(InputImage.fromFilePath(foto.path));
      return satirlaraDiz([
        for (final blok in metin.blocks)
          for (final satir in blok.lines)
            MetinParcasi(satir.boundingBox.top, satir.boundingBox.bottom, satir.boundingBox.left, satir.text),
      ]);
    } finally {
      await okuyucu.close();
    }
  }

  /// "Kamera / Galeri" sorup raporu okur ve ayrıştırır. Vazgeçilirse null.
  static Future<RaporOkumaSonucu?> raporOku(BuildContext context) async {
    final kaynak = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Raporu düz bir yüzeye koyun, gölge düşürmeden ve tablonun tamamı görünecek şekilde çekin.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (kaynak == null) return null;
    final satirlar = await fotograftanSatirlar(kaynak);
    return satirlar == null ? null : raporuOku(satirlar);
  }
}
