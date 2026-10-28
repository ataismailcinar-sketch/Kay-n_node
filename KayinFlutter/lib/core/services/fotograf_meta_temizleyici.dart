import 'dart:typed_data';

/// Fotoğraftaki gizli bilgileri (EXIF: GPS konumu, telefon modeli, çekim saati; XMP; IPTC; yorumlar)
/// görüntüyü yeniden sıkıştırmadan, dosya parçalarını ayıklayarak siler.
///
/// JPEG: APP1 (EXIF/XMP), APP13 (IPTC), COM ve diğer APPn atılır; APP0 (JFIF), APP2 (renk profili) ve
/// APP14 (Adobe) kalır. Fotoğrafın yönü (EXIF Orientation) silinirse resim yan görünür; bu yüzden
/// yalnız yön etiketini içeren küçük bir EXIF yeniden yazılır.
/// PNG: eXIf, tEXt, zTXt, iTXt, tIME parçaları atılır.
/// Tanınmayan / bozuk dosya olduğu gibi döner (fotoğraf kaybolmasın).
/// Sunucudaki karşılığı: KayinBackend `FotografMetaTemizleyici` (aynı kurallar).
Uint8List fotografMetaTemizle(Uint8List b) {
  try {
    if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) return _jpeg(b);
    if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return _png(b);
  } catch (_) {}
  return b;
}

Uint8List _jpeg(Uint8List b) {
  final c = BytesBuilder(copy: false)..add([0xFF, 0xD8]);
  int? yon;
  var i = 2;
  var yonYazildi = false;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF) return b; // beklenmeyen yapı
    final m = b[i + 1];
    if (m == 0xFF) {
      i++; // dolgu baytı
      continue;
    }
    if (m == 0xD9 || (m >= 0xD0 && m <= 0xD7) || m == 0x01) {
      c.add([0xFF, m]);
      i += 2;
      continue;
    }
    final uzunluk = (b[i + 2] << 8) | b[i + 3];
    final son = i + 2 + uzunluk;
    if (uzunluk < 2 || son > b.length) return b;
    final veri = Uint8List.sublistView(b, i + 4, son);

    final uygulamaParcasi = m >= 0xE0 && m <= 0xEF;
    final atilir = m == 0xFE || (uygulamaParcasi && m != 0xE0 && m != 0xE2 && m != 0xEE);
    if (m == 0xE1) yon ??= _exifYonu(veri);
    if (!atilir) {
      // Yön, APP0'dan (JFIF) sonra ilk tutulan parçadan önce yazılır (EXIF dosyanın başındadır).
      if (!yonYazildi && m != 0xE0 && yon != null && yon != 1) {
        c.add(_yonExifi(yon));
        yonYazildi = true;
      }
      c.add(Uint8List.sublistView(b, i, son));
    }
    i = son;
    if (m == 0xDA) {
      c.add(Uint8List.sublistView(b, i)); // sıkıştırılmış görüntü verisi + sonrası olduğu gibi
      return c.toBytes();
    }
  }
  return b;
}

/// EXIF IFD0'daki Orientation (0x0112) değeri; yoksa null.
int? _exifYonu(Uint8List d) {
  if (d.length < 14 || String.fromCharCodes(d.sublist(0, 4)) != 'Exif') return null;
  final t = ByteData.sublistView(d, 6);
  final Endian e;
  if (t.getUint8(0) == 0x49 && t.getUint8(1) == 0x49) {
    e = Endian.little;
  } else if (t.getUint8(0) == 0x4D && t.getUint8(1) == 0x4D) {
    e = Endian.big;
  } else {
    return null;
  }
  final ifd = t.getUint32(4, e);
  if (ifd + 2 > t.lengthInBytes) return null;
  final adet = t.getUint16(ifd, e);
  for (var k = 0; k < adet; k++) {
    final o = ifd + 2 + k * 12;
    if (o + 12 > t.lengthInBytes) return null;
    if (t.getUint16(o, e) == 0x0112) {
      final v = t.getUint16(o + 8, e);
      return v >= 1 && v <= 8 ? v : null;
    }
  }
  return null;
}

/// Yalnız Orientation etiketini taşıyan APP1 parçası (büyük endian TIFF).
Uint8List _yonExifi(int yon) => Uint8List.fromList([
      0xFF, 0xE1, 0x00, 34, //
      0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
      0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // MM, 42, IFD0 @8
      0x00, 0x01, // 1 etiket
      0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, yon, 0x00, 0x00, // Orientation SHORT
      0x00, 0x00, 0x00, 0x00, // sonraki IFD yok
    ]);

const _pngAtilan = {'eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME'};

Uint8List _png(Uint8List b) {
  final c = BytesBuilder(copy: false)..add(Uint8List.sublistView(b, 0, 8));
  var i = 8;
  while (i + 12 <= b.length) {
    final uzunluk = ByteData.sublistView(b, i, i + 4).getUint32(0);
    final tur = String.fromCharCodes(b.sublist(i + 4, i + 8));
    final son = i + 12 + uzunluk;
    if (son > b.length) return b;
    if (!_pngAtilan.contains(tur)) c.add(Uint8List.sublistView(b, i, son));
    i = son;
    if (tur == 'IEND') return c.toBytes();
  }
  return b;
}
