import 'dart:math' as math;
import '../entities/parsel_entity.dart';
import '../repositories/parsel_repository.dart';

// ── UseCase: Parselleri Listele ──────────────────────────────────────────────
class GetParsellerUseCase {
  final ParselRepository _repo;
  GetParsellerUseCase(this._repo);

  Future<List<ParselEntity>> call() => _repo.getAll();
}

// ── UseCase: Parsel Kaydet ───────────────────────────────────────────────────
class SaveParselUseCase {
  final ParselRepository _repo;
  SaveParselUseCase(this._repo);

  Future<void> call(ParselEntity parsel) => _repo.save(parsel);
}

// ── UseCase: Parsel Sil ──────────────────────────────────────────────────────
class DeleteParselUseCase {
  final ParselRepository _repo;
  DeleteParselUseCase(this._repo);

  Future<void> call(String id) => _repo.delete(id);
}

// ── UseCase: Poligon Alan Hesaplama ──────────────────────────────────────────
/// Shoelace (Gauss) + Haversine yöntemiyle WGS-84 koordinatlarından gerçek alan hesaplar.
/// Sonuç: dönüm cinsinden (1 dönüm = 1000 m²)
class PoligonAlanHesaplaUseCase {
  double call(List<LatLngPoint> noktalar) {
    if (noktalar.length < 3) return 0.0;

    const double earthRadius = 6371000.0; // metre
    double alan = 0.0;
    final n = noktalar.length;

    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;

      final lat1 = _toRad(noktalar[i].lat);
      final lat2 = _toRad(noktalar[j].lat);
      final lng1 = _toRad(noktalar[i].lng);
      final lng2 = _toRad(noktalar[j].lng);

      // Küresel poligon alanı (Shoelace formülünün küresel hali)
      alan += (lng2 - lng1) * (2 + math.sin(lat1) + math.sin(lat2));
    }

    // Mutlak değer, m² → dönüm
    final alanM2 = (alan * earthRadius * earthRadius / 2).abs();
    return alanM2 / 1000.0; // dönüm
  }

  double _toRad(double deg) => deg * math.pi / 180.0;
}

// ── UseCase: Poligon Merkez Hesaplama ────────────────────────────────────────
class PoligonMerkezHesaplaUseCase {
  LatLngPoint call(List<LatLngPoint> noktalar) {
    if (noktalar.isEmpty) return const LatLngPoint(0, 0);
    final lat = noktalar.map((p) => p.lat).reduce((a, b) => a + b) / noktalar.length;
    final lng = noktalar.map((p) => p.lng).reduce((a, b) => a + b) / noktalar.length;
    return LatLngPoint(lat, lng);
  }
}
