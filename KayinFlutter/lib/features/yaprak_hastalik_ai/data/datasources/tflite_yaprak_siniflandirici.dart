import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Tek bir sınıf tahmini (model etiketi + olasılık 0..1).
class SinifTahmini {
  final String etiket;
  final double olasilik;
  const SinifTahmini(this.etiket, this.olasilik);
}

/// Yaprak sınıflandırıcı sözleşmesi (testlerde sahte uygulama verilebilsin diye).
abstract class YaprakSiniflandirici {
  Future<bool> hazirMi();
  String? get yuklemeHatasi;
  String get modelAdi;
  List<String> get etiketler;
  Future<List<SinifTahmini>> siniflandir(String fotoYolu);
}

/// Cihaz üzerinde çalışan gerçek TFLite yaprak sınıflandırıcısı.
///
/// Beklenen dosyalar (pubspec'te `assets/models/` zaten tanımlı):
///   assets/models/yaprak_model.tflite   → sınıflandırma modeli
///   assets/models/labels.txt            → her satıra bir etiket, model çıktı sırasıyla
///   assets/models/model_config.json     → (opsiyonel) {"normalizasyon": "0_255" | "0_1" | "eksi1_1"}
///
/// Model dosyası yoksa veya yüklenemezse [hazirMi] false döner ve
/// [yuklemeHatasi] nedenini içerir. Uygulama bu durumda sahte sonuç ÜRETMEZ.
class TfliteYaprakSiniflandirici implements YaprakSiniflandirici {
  TfliteYaprakSiniflandirici._();
  static final TfliteYaprakSiniflandirici instance = TfliteYaprakSiniflandirici._();

  static const String modelYolu = 'assets/models/yaprak_model.tflite';
  static const String etiketYolu = 'assets/models/labels.txt';
  static const String configYolu = 'assets/models/model_config.json';

  Interpreter? _interpreter;
  List<String> _etiketler = const [];
  String _normalizasyon = '0_1';
  String _modelAdi = 'yaprak_model.tflite';
  Future<bool>? _yukleme;
  @override
  String? yuklemeHatasi;

  @override
  String get modelAdi => _modelAdi;
  @override
  List<String> get etiketler => List.unmodifiable(_etiketler);

  /// Modeli bir kez yükler; sonraki çağrılarda önbellekteki sonucu döner.
  @override
  Future<bool> hazirMi() => _yukleme ??= _yukle();

  Future<bool> _yukle() async {
    try {
      final etiketMetni = await rootBundle.loadString(etiketYolu);
      _etiketler = const LineSplitter()
          .convert(etiketMetni)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (_etiketler.isEmpty) {
        yuklemeHatasi = 'labels.txt boş.';
        return false;
      }
    } catch (_) {
      yuklemeHatasi = 'Etiket dosyası bulunamadı ($etiketYolu).';
      return false;
    }

    try {
      final cfg = jsonDecode(await rootBundle.loadString(configYolu)) as Map<String, dynamic>;
      _normalizasyon = (cfg['normalizasyon'] as String?) ?? _normalizasyon;
      _modelAdi = (cfg['ad'] as String?) ?? _modelAdi;
    } catch (_) {
      // Config opsiyonel; varsayılanlar kullanılır.
    }

    try {
      _interpreter = await Interpreter.fromAsset(modelYolu);
    } catch (e) {
      yuklemeHatasi = 'Model yüklenemedi ($modelYolu): $e';
      return false;
    }

    final cikisBoyu = _interpreter!.getOutputTensor(0).shape.last;
    if (cikisBoyu != _etiketler.length) {
      yuklemeHatasi = 'Model $cikisBoyu sınıf veriyor ama labels.txt ${_etiketler.length} satır.';
      _interpreter!.close();
      _interpreter = null;
      return false;
    }
    return true;
  }

  /// Fotoğrafı sınıflandırır; olasılığa göre azalan sırada tüm sınıfları döner.
  @override
  Future<List<SinifTahmini>> siniflandir(String fotoYolu) async {
    if (!await hazirMi()) {
      throw StateError(yuklemeHatasi ?? 'Model hazır değil.');
    }
    final interpreter = _interpreter!;
    final girisTensoru = interpreter.getInputTensor(0);
    final girisSekli = girisTensoru.shape; // [1, H, W, 3]
    final h = girisSekli[1];
    final w = girisSekli[2];

    final rgba = await _yukleVeKirp(fotoYolu, w, h);
    final girisBaytlari = _girdiHazirla(rgba, w * h, girisTensoru.type, girisTensoru.params);

    final cikisTensoru = interpreter.getOutputTensor(0);
    final cikisElemanBoyu = _elemanBoyu(cikisTensoru.type);
    final cikisBaytlari = Uint8List(_etiketler.length * cikisElemanBoyu);
    interpreter.run(girisBaytlari, cikisBaytlari);

    var skorlar = _cikisCoz(cikisBaytlari, cikisTensoru.type, cikisTensoru.params);
    // Model softmax içermiyorsa (logit) olasılığa çevir.
    final toplam = skorlar.fold<double>(0, (a, b) => a + b);
    if (skorlar.any((s) => s < 0) || (toplam - 1).abs() > 0.05) {
      skorlar = _softmax(skorlar);
    }

    final sonuc = [
      for (var i = 0; i < _etiketler.length; i++) SinifTahmini(_etiketler[i], skorlar[i]),
    ]..sort((a, b) => b.olasilik.compareTo(a.olasilik));
    return sonuc;
  }

  /// Görüntüyü çözer, kısa kenara göre ölçekler, ortadan kare kırpar → RGBA baytları.
  Future<Uint8List> _yukleVeKirp(String yol, int w, int h) async {
    final bytes = await File(yol).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final desc = await ui.ImageDescriptor.encoded(buffer);

    final olcek = math.max(w / desc.width, h / desc.height);
    final hedefW = math.max(w, (desc.width * olcek).round());
    final hedefH = math.max(h, (desc.height * olcek).round());

    final codec = await desc.instantiateCodec(targetWidth: hedefW, targetHeight: hedefH);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final iw = img.width;
    final ih = img.height;
    img.dispose();
    codec.dispose();
    desc.dispose();
    buffer.dispose();
    if (bd == null) throw StateError('Fotoğraf çözümlenemedi.');

    final kaynak = bd.buffer.asUint8List();
    final x0 = ((iw - w) / 2).floor();
    final y0 = ((ih - h) / 2).floor();
    final hedef = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      final kaynakSatir = ((y0 + y) * iw + x0) * 4;
      hedef.setRange(y * w * 4, (y + 1) * w * 4, kaynak, kaynakSatir);
    }
    return hedef;
  }

  Uint8List _girdiHazirla(Uint8List rgba, int pikselSayisi, TensorType tip, QuantizationParams q) {
    switch (tip) {
      case TensorType.float32:
        final f = Float32List(pikselSayisi * 3);
        for (var i = 0, j = 0; i < pikselSayisi; i++) {
          for (var c = 0; c < 3; c++) {
            f[j++] = _normalize(rgba[i * 4 + c].toDouble());
          }
        }
        return f.buffer.asUint8List();
      case TensorType.uint8:
        final u = Uint8List(pikselSayisi * 3);
        for (var i = 0, j = 0; i < pikselSayisi; i++) {
          u[j++] = rgba[i * 4];
          u[j++] = rgba[i * 4 + 1];
          u[j++] = rgba[i * 4 + 2];
        }
        return u;
      case TensorType.int8:
        final s = Int8List(pikselSayisi * 3);
        for (var i = 0, j = 0; i < pikselSayisi; i++) {
          for (var c = 0; c < 3; c++) {
            s[j++] = rgba[i * 4 + c] - 128;
          }
        }
        return s.buffer.asUint8List();
      default:
        throw UnsupportedError('Desteklenmeyen model girdi tipi: $tip');
    }
  }

  double _normalize(double v) => switch (_normalizasyon) {
        '0_255' => v,
        'eksi1_1' => v / 127.5 - 1.0,
        _ => v / 255.0,
      };

  int _elemanBoyu(TensorType t) => switch (t) {
        TensorType.float32 => 4,
        TensorType.uint8 || TensorType.int8 => 1,
        _ => throw UnsupportedError('Desteklenmeyen model çıktı tipi: $t'),
      };

  List<double> _cikisCoz(Uint8List b, TensorType tip, QuantizationParams q) {
    final n = _etiketler.length;
    switch (tip) {
      case TensorType.float32:
        final bd = ByteData.sublistView(b);
        return [for (var i = 0; i < n; i++) bd.getFloat32(i * 4, Endian.little)];
      case TensorType.uint8:
        final olcek = q.scale == 0 ? 1 / 255 : q.scale;
        return [for (var i = 0; i < n; i++) (b[i] - q.zeroPoint) * olcek];
      case TensorType.int8:
        final s = Int8List.sublistView(b);
        final olcek = q.scale == 0 ? 1 / 255 : q.scale;
        return [for (var i = 0; i < n; i++) (s[i] - q.zeroPoint) * olcek];
      default:
        throw UnsupportedError('Desteklenmeyen model çıktı tipi: $tip');
    }
  }

  List<double> _softmax(List<double> x) {
    final mx = x.reduce(math.max);
    final e = x.map((v) => math.exp(v - mx)).toList();
    final t = e.fold<double>(0, (a, b) => a + b);
    return e.map((v) => v / t).toList();
  }
}
