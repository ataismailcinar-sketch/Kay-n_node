class HastalikTaramaEntity {
  final String id;
  final String? parselId;
  final DateTime taramaTarihi;
  final String teshisAdi;
  final double guvenYuzdesi;
  final String tumSinifOlasiliklariJson;
  final String fotografYerelYolu;

  /// Fotoğraf sunucuya yüklendi (başka cihazda oradan gösterilir).
  final bool fotografSunucuda;
  final String modelVersionu;
  final String aciliyetSeviyesi;
  final bool cevrimdisiAnalizYapildi;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const HastalikTaramaEntity({
    required this.id,
    this.parselId,
    required this.taramaTarihi,
    required this.teshisAdi,
    required this.guvenYuzdesi,
    required this.tumSinifOlasiliklariJson,
    required this.fotografYerelYolu,
    this.fotografSunucuda = false,
    required this.modelVersionu,
    required this.aciliyetSeviyesi,
    this.cevrimdisiAnalizYapildi = true,
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });

  static const String manuelModelVersiyonu = 'manuel_secim';

  /// Teşhis model yerine kullanıcı tarafından seçildiyse true.
  bool get manuelMi => modelVersionu == manuelModelVersiyonu;

  static const String demoModelVersiyonu = 'demo_ornek_veri';

  /// Gerçek bir analiz sonucu olmayan kayıtlar: eski sürümdeki rastgele motorun
  /// ürettikleri ve "Örnek Çiftlik Verisi" ile yüklenenler.
  bool get eskiDemoKaydiMi =>
      modelVersionu.startsWith('ZeroInput_') ||
      modelVersionu == demoModelVersiyonu ||
      modelVersionu == 'plant_disease_v2.tflite';

  String get formatliTeshis => eskiDemoKaydiMi
      ? '$teshisAdi (örnek / doğrulanmamış)'
      : manuelMi ? '$teshisAdi (manuel)' : '%${guvenYuzdesi.toStringAsFixed(0)} $teshisAdi';
}
