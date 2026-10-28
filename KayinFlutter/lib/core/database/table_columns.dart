/// SQLite tablo sütun isimlerini merkezi olarak tanımlar.
/// ORM yoktur — ham SQL kullanılır; bu dosya typo hataları önler.
class TableColumns {
  TableColumns._();

  // ── Ortak sütunlar (tüm tablolarda) ──────────────────────────────────
  static const String id = 'id';
  static const String createdAtUtc = 'created_at_utc';
  static const String lastModifiedUtc = 'last_modified_utc';
  static const String isDeleted = 'is_deleted';
  static const String isSynced = 'is_synced';

  // ── Parseller tablosu ─────────────────────────────────────────────────
  static const String parselAd           = 'ad';
  static const String parselEkilmisUrun  = 'ekilmis_urun';
  static const String parselToprakTuru   = 'toprak_turu';
  static const String parselSulu         = 'sulu'; // 1 sulu, 0 kuru, NULL belirtilmedi
  static const String parselSulamaYontemi = 'sulama_yontemi'; // Damla / Yagmurlama / Salma
  static const String parselSuKaynagi    = 'su_kaynagi';      // Kuyu / Kanal / Dere / Golet
  static const String parselSuEc         = 'su_ec';           // sulama suyu ECw, dS/m
  static const String parselEkimTarihi   = 'ekim_tarihi';
  static const String parselKonum        = 'konum';
  static const String parselPoligonJson = 'poligon_koordinatlari_json';
  static const String parselAlanDonum = 'alan_donum_cinsinden';
  static const String parselMerkezLat = 'merkez_lat';
  static const String parselMerkezLng = 'merkez_lng';

  // ── YagisSulama tablosu ───────────────────────────────────────────────
  static const String sulamaParselId = 'parsel_id';
  static const String sulamaKayitTarihi = 'kayit_tarihi';
  static const String sulamaYagisMm = 'yagis_milimetre';
  static const String sulamaToprakNemi = 'toprak_nemi_yuzde';
  static const String sulamaKayitTuru = 'kayit_turu';
  static const String sulamaManuelLitre = 'manuel_sulama_litre';
  static const String sulamaAciliyetSeviyesi = 'aciliyet_seviyesi';
  static const String sulamaHavaApiJson = 'hava_api_ham_veri_json';

  // ── MuhasebeGider tablosu ─────────────────────────────────────────────
  static const String giderParselId = 'parsel_id';
  static const String giderIslemTuru = 'islem_turu';
  static const String giderKategori = 'kategori';
  static const String giderAltKategori = 'alt_kategori';
  static const String giderTutar = 'tutar';
  static const String giderParaBirimi = 'para_birimi';
  static const String giderTarihi = 'gider_tarihi';
  static const String giderNot = 'not_metni';

  // ── HastalikTarama tablosu ────────────────────────────────────────────
  // ── IsKayitlari (iş günlüğü) tablosu ──────────────────────────────────
  static const String isParselId = 'parsel_id';
  static const String isTarihi = 'islem_tarihi';
  static const String isTuru = 'islem_turu';
  static const String isUrunAdi = 'urun_adi';
  static const String isMiktar = 'miktar';
  static const String isHasatBeklemeGun = 'hasat_bekleme_gun';
  static const String isHasatKg = 'hasat_kg';
  static const String isNot = 'not_metni';

  /// Fotoğrafın sunucudaki durumu: 0 = yüklenmedi, 1 = sunucuda, -1 = yüklenemez
  /// (dosya yok/geçersiz; tekrar denenmez). Senkronizasyon durumundan (is_synced) bağımsızdır.
  static const String taramaFotografSunucuda = 'fotograf_sunucuda';
  static const String taramaParselId = 'parsel_id';
  static const String taramaTarihi = 'tarama_tarihi';
  static const String taramaTeshisAdi = 'teshis_adi';
  static const String taramaGuvenYuzdesi = 'guven_yuzdesi';
  static const String taramaSinifJson = 'tum_sinif_olasiliklari_json';
  static const String taramaFotografYolu = 'fotograf_yerel_yolu';
  static const String taramaModelVersiyon = 'model_versiyonu';
  static const String taramaAciliyetSeviyesi = 'aciliyet_seviyesi';
  static const String taramaCevrimdisi = 'cevrimdisi_analiz_yapildi';
}
