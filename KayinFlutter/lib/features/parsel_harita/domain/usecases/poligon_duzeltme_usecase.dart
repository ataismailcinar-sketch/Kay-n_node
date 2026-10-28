import '../entities/parsel_entity.dart';

/// 🪄 Chaikin Poligon Düzeltme & Yumuşatma Algoritması (Polygon Boundary Refinement)
///
/// Çiftçinin haritada elle koyduğu pürüzlü/girintili-çıkıntılı noktaları
/// gerçek tarla/traktör sürüm sınırına göre pürüzsüzleştirip düzeltir.
class PoligonDuzeltmeUseCase {
  /// Nokta listesini Chaikin Corner-Cutting algoritması ile pürüzsüzleştirir.
  /// [iterations]: Yumuşatma kat sayısı (varsayılan: 1 veya 2 iterasyon)
  List<LatLngPoint> execute(List<LatLngPoint> noktalar, {int iterations = 1}) {
    if (noktalar.length < 3) return noktalar;

    List<LatLngPoint> result = List.from(noktalar);

    for (int iter = 0; iter < iterations; iter++) {
      final List<LatLngPoint> smoothed = [];
      final int count = result.length;

      for (int i = 0; i < count; i++) {
        final LatLngPoint p0 = result[i];
        final LatLngPoint p1 = result[(i + 1) % count];

        // Chaikin's 1/4 ve 3/4 oranlı yeni köşe noktaları hesapla
        final double qLat = 0.75 * p0.lat + 0.25 * p1.lat;
        final double qLng = 0.75 * p0.lng + 0.25 * p1.lng;

        final double rLat = 0.25 * p0.lat + 0.75 * p1.lat;
        final double rLng = 0.25 * p0.lng + 0.75 * p1.lng;

        smoothed.add(LatLngPoint(qLat, qLng));
        smoothed.add(LatLngPoint(rLat, rLng));
      }

      result = smoothed;
    }

    return result;
  }
}
