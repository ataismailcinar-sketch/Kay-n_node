import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/services/fotograf_meta_temizleyici.dart';

/// Baytlarda bir ASCII metin geçiyor mu?
bool _iceriyor(Uint8List b, String s) {
  final a = s.codeUnits;
  outer:
  for (var i = 0; i + a.length <= b.length; i++) {
    for (var j = 0; j < a.length; j++) {
      if (b[i + j] != a[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// JPEG'deki APP1 parçalarının sayısı ve Orientation değeri (yalnız test için kaba okuma).
({int app1, int? yon}) _app1(Uint8List b) {
  var i = 2, app1 = 0;
  int? yon;
  while (i + 4 <= b.length && b[i] == 0xFF) {
    final m = b[i + 1];
    final u = (b[i + 2] << 8) | b[i + 3];
    if (m == 0xE1) {
      app1++;
      for (var k = i + 4; k + 10 < i + 2 + u; k++) {
        if (b[k] == 0x01 && b[k + 1] == 0x12 && b[k + 2] == 0x00 && b[k + 3] == 0x03) yon = b[k + 9];
      }
    }
    if (m == 0xDA) break;
    i += 2 + u;
  }
  return (app1: app1, yon: yon);
}

void main() {
  // Windows'ta GDI+ ile üretildi: GPS (37°52'N 32°29'E), telefon markası, Orientation=6.
  final ornek = File('test/veri/gps_foto.jpg').readAsBytesSync();

  test('GPS ve cihaz bilgisi silinir, yön (Orientation) korunur', () {
    expect(_iceriyor(ornek, 'TestTelefonMarka'), isTrue);
    final t = fotografMetaTemizle(ornek);
    expect(_iceriyor(t, 'TestTelefonMarka'), isFalse);
    // GPS enlem rasyonelleri (37/1, 52/1) artık yok
    expect(_iceriyor(t, String.fromCharCodes([37, 0, 0, 0, 1, 0, 0, 0, 52, 0, 0, 0])), isFalse);
    expect(_iceriyor(ornek, String.fromCharCodes([37, 0, 0, 0, 1, 0, 0, 0, 52, 0, 0, 0])), isTrue);
    final a = _app1(t);
    expect(a.app1, 1);
    expect(a.yon, 6);
    expect(t.length, lessThan(ornek.length));
  });

  test('Temizlenen dosya hâlâ geçerli bir resim', () async {
    final kodek = await ui.instantiateImageCodec(fotografMetaTemizle(ornek));
    final kare = await kodek.getNextFrame();
    // Yön 6 (90° döndür) uygulandığı için genişlik/yükseklik yer değiştirir: 320x200 → 200x320.
    expect({kare.image.width, kare.image.height}, {320, 200});
  });

  test('Yön 1 ya da yoksa EXIF hiç yazılmaz; iki kez temizlemek aynı sonucu verir', () {
    final yonsuz = Uint8List.fromList([
      0xFF, 0xD8, //
      0xFF, 0xE1, 0x00, 0x08, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // bozuk/kısa EXIF
      0xFF, 0xFE, 0x00, 0x05, 0x61, 0x62, 0x63, // yorum "abc"
      0xFF, 0xDB, 0x00, 0x03, 0x00, // DQT (kısa)
      0xFF, 0xDA, 0x00, 0x02, 0x11, 0x22, 0xFF, 0xD9,
    ]);
    final t = fotografMetaTemizle(yonsuz);
    expect(_app1(t).app1, 0);
    expect(_iceriyor(t, 'abc'), isFalse);
    expect(t.sublist(t.length - 4), [0x11, 0x22, 0xFF, 0xD9]);
    final once = fotografMetaTemizle(ornek);
    expect(fotografMetaTemizle(once), once);
  });

  test('PNG: metin ve eXIf parçaları atılır; bozuk dosya olduğu gibi döner', () {
    List<int> parca(String tur, List<int> veri) =>
        [0, 0, 0, veri.length, ...tur.codeUnits, ...veri, 0, 0, 0, 0];
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ...parca('IHDR', List.filled(13, 1)),
      ...parca('tEXt', 'GPS=37.8'.codeUnits),
      ...parca('eXIf', [1, 2, 3]),
      ...parca('IDAT', [9, 9]),
      ...parca('IEND', []),
    ]);
    final t = fotografMetaTemizle(png);
    expect(_iceriyor(t, 'GPS'), isFalse);
    expect(_iceriyor(t, 'eXIf'), isFalse);
    expect(_iceriyor(t, 'IDAT'), isTrue);
    final bozuk = Uint8List.fromList([0xFF, 0xD8, 0x00, 0x01, 0x02]);
    expect(fotografMetaTemizle(bozuk), bozuk);
  });
}
