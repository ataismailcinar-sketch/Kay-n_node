/// Laboratuvar raporu fotoğrafından (OCR metni) toprak / su analizi değerlerini çıkarır.
///
/// Raporlar çoğunlukla tablo: her satırda parametre adı, değer, birim ve çoğu zaman sınır değerler.
/// Kural: parametre adının geçtiği satırda, addan sonraki ilk "bağımsız" sayı değerdir. Kimyasal
/// formüllerdeki rakamlar (P2O5, K2O, CaCO3), oran yazımları (1:2,5) ve aralıklar (6,5-7,5) atlanır.
/// Sonuç her zaman kullanıcıya gösterilip onaylatılır; okunan değer doğrudan kaydedilmez.
library;

enum RaporAlani {
  saturasyon('Saturasyon', 5, 150),
  ph('pH', 3, 11),
  ec('EC', 0, 100000),
  tuzYuzde('Toplam tuz', 0, 10),
  kirec('Kireç', 0, 90),
  organikMadde('Organik madde', 0, 30),
  fosfor('Fosfor', 0, 200),
  potasyum('Potasyum', 0, 500),
  cinko('Çinko', 0, 100);

  final String ad;
  final double min, max;
  const RaporAlani(this.ad, this.min, this.max);
}

class RaporOkumaSonucu {
  final Map<RaporAlani, double> degerler;

  /// Okunup kullanılmayan ya da dikkat isteyen durumlar (ör. fosfor ppm yazılmış).
  final List<String> notlar;
  const RaporOkumaSonucu(this.degerler, this.notlar);

  double? operator [](RaporAlani a) => degerler[a];
}

/// Türkçe harfleri ASCII'ye indirip küçük harfe çevirir (OCR çoğu zaman şapka/noktaları kaçırır).
String _sade(String s) => s
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ç', 'c')
    .replaceAll('ğ', 'g')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('µ', 'u')
    .replaceAll('μ', 'u');

/// Sıra önemli: EC satırı "tuzluluk" da içerebilir, önce EC aranır; tuz yalnız EC olmayan satırda.
final _etiketler = <RaporAlani, RegExp>{
  RaporAlani.saturasyon: RegExp(r'satur|doymus'),
  RaporAlani.ph: RegExp(r'\bph\b'),
  RaporAlani.ec: RegExp(r'\bece?\b|\bec\d|iletkenl'),
  RaporAlani.tuzYuzde: RegExp(r'tuz'),
  RaporAlani.kirec: RegExp(r'kirec|caco'),
  RaporAlani.organikMadde: RegExp(r'organik'),
  RaporAlani.fosfor: RegExp(r'fosfor|p2o5'),
  RaporAlani.potasyum: RegExp(r'potasyum|k2o'),
  RaporAlani.cinko: RegExp(r'cinko|\bzn\b'),
};

/// Harf/rakam/iki nokta/aralık işaretine bitişik olmayan sayı.
final _sayi = RegExp(r'(?<![a-z0-9:.,\-–])(\d+(?:[.,]\d+)?)(?![a-z0-9:\-–]|[.,]\d)');

double? _oku(String s) => double.tryParse(s.replaceAll(',', '.'));

/// Satırda, [bas] konumundan sonra gelen ve alanın aralığına uyan ilk sayı.
double? _ilkSayi(String satir, int bas, RaporAlani alan) {
  for (final m in _sayi.allMatches(satir, bas)) {
    final v = _oku(m.group(1)!);
    if (v != null && v >= alan.min && v <= alan.max) return v;
  }
  return null;
}

bool _baskaEtiketVar(String satir) => _etiketler.values.any((r) => r.hasMatch(satir));

RaporOkumaSonucu raporuOku(List<String> satirlar) {
  final sade = satirlar.map(_sade).toList();
  final degerler = <RaporAlani, double>{};
  final notlar = <String>[];

  for (final alan in RaporAlani.values) {
    final etiket = _etiketler[alan]!;
    for (var i = 0; i < sade.length; i++) {
      final satir = sade[i];
      final m = etiket.firstMatch(satir);
      if (m == null) continue;
      if (alan == RaporAlani.tuzYuzde && _etiketler[RaporAlani.ec]!.hasMatch(satir)) continue;
      if ((alan == RaporAlani.fosfor || alan == RaporAlani.potasyum) &&
          RegExp(r'ppm|mg\s*/\s*kg').hasMatch(satir)) {
        notlar.add('${alan.ad} raporda ppm (mg/kg) yazılmış; kg/da değerini elle girin.');
        break;
      }
      // Değer aynı satırda yoksa (dikey tablo) bir alt satırın başındaki sayıya bakılır.
      var v = _ilkSayi(satir, m.end, alan);
      if (v == null && i + 1 < sade.length && !_baskaEtiketVar(sade[i + 1])) {
        v = _ilkSayi(sade[i + 1], 0, alan);
      }
      if (v != null) {
        degerler[alan] = v;
        break;
      }
    }
  }
  return RaporOkumaSonucu(degerler, notlar);
}

/// OCR'nin verdiği metin parçalarını (konumlarıyla) satırlara dizer: dikey merkezleri yakın olanlar
/// aynı satırdır, soldan sağa birleştirilir. Tablo sütunları ayrı parça olarak gelir.
class MetinParcasi {
  final double ust, alt, sol;
  final String metin;
  const MetinParcasi(this.ust, this.alt, this.sol, this.metin);
  double get orta => (ust + alt) / 2;
  double get yukseklik => alt - ust;
}

List<String> satirlaraDiz(List<MetinParcasi> parcalar) {
  final sirali = [...parcalar]..sort((a, b) => a.orta.compareTo(b.orta));
  final satirlar = <List<MetinParcasi>>[];
  for (final p in sirali) {
    final son = satirlar.isEmpty ? null : satirlar.last;
    if (son != null) {
      final ort = son.map((e) => e.orta).reduce((a, b) => a + b) / son.length;
      final yuk = son.map((e) => e.yukseklik).reduce((a, b) => a + b) / son.length;
      if ((p.orta - ort).abs() <= yuk * 0.5) {
        son.add(p);
        continue;
      }
    }
    satirlar.add([p]);
  }
  return [
    for (final s in satirlar) (s..sort((a, b) => a.sol.compareTo(b.sol))).map((e) => e.metin).join('  '),
  ];
}
