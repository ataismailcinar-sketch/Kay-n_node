import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/hava_durumu_servisi.dart';
import '../../veresiye/domain/veresiye.dart';

enum HatirlatmaTuru {
  cks('Cks', 'ÇKS', Icons.assignment_ind_rounded, Color(0xFF2563EB)),
  destek('Destek', 'Destek başvurusu', Icons.volunteer_activism_rounded, Color(0xFF16A34A)),
  tarsim('Tarsim', 'TARSİM', Icons.shield_rounded, Color(0xFF9333EA)),
  diger('Diger', 'Diğer', Icons.event_rounded, Color(0xFF64748B));

  final String kod;
  final String ad;
  final IconData ikon;
  final Color renk;
  const HatirlatmaTuru(this.kod, this.ad, this.ikon, this.renk);

  static HatirlatmaTuru koddan(String kod) =>
      HatirlatmaTuru.values.firstWhere((t) => t.kod == kod, orElse: () => HatirlatmaTuru.diger);
}

/// Hazır hatırlatma başlıkları. Tarihler her yıl tebliğle değiştiği için tarih önerilmez.
class HatirlatmaSablonu {
  final String baslik;
  final HatirlatmaTuru tur;
  final bool herYil;
  final int kacGunOnce;
  const HatirlatmaSablonu(this.baslik, this.tur, {this.herYil = true, this.kacGunOnce = 15});
}

const hatirlatmaSablonlari = [
  HatirlatmaSablonu('ÇKS kaydını güncelle', HatirlatmaTuru.cks),
  HatirlatmaSablonu('Mazot-gübre desteği başvurusu', HatirlatmaTuru.destek),
  HatirlatmaSablonu('Fark ödemesi desteği başvurusu', HatirlatmaTuru.destek),
  HatirlatmaSablonu('TARSİM poliçesi yenile', HatirlatmaTuru.tarsim, kacGunOnce: 30),
];

class HatirlatmaEntity {
  final String id;
  final String baslik;
  final HatirlatmaTuru tur;

  /// Yalnızca gün anlamlıdır (yerel takvim günü).
  final DateTime tarih;
  final int kacGunOnce;
  final bool herYil;
  final bool tamamlandi;
  final String not;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const HatirlatmaEntity({
    required this.id,
    required this.baslik,
    this.tur = HatirlatmaTuru.diger,
    required this.tarih,
    this.kacGunOnce = 7,
    this.herYil = false,
    this.tamamlandi = false,
    this.not = '',
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });

  DateTime get gun => DateTime(tarih.year, tarih.month, tarih.day);
}

/// "Yapıldı": her yıl tekrarlayan bir yıl ileri alınır, diğeri tamamlanır.
({DateTime tarih, bool tamamlandi}) yapildiSonrasi(HatirlatmaEntity h) {
  if (!h.herYil) return (tarih: h.gun, tamamlandi: true);
  final g = h.gun;
  // 29 Şubat → 28 Şubat (DateTime taşmasın)
  final gunSayisi = DateUtils.getDaysInMonth(g.year + 1, g.month);
  return (tarih: DateTime(g.year + 1, g.month, g.day > gunSayisi ? gunSayisi : g.day), tamamlandi: false);
}

enum UyariTuru {
  don('Don uyarısı'),
  vade('Veresiye vadesi'),
  hatirlatma('Hatırlatmalar');

  final String ad;
  const UyariTuru(this.ad);
}

/// Telefonda gösterilecek tek bir uyarı. [bildirimZamani] gelince bildirim çıkar ve
/// Bildirimler ekranında görünür.
class Uyari {
  /// Bildirimi tekilleştirir (aynı anahtar bir kez bildirilir).
  final String anahtar;

  /// Aynı konunun (ör. aynı vade) uyarıları; ekranda grubun en son başlayanı gösterilir.
  final String grup;
  final UyariTuru tur;
  final String baslik;
  final String metin;

  /// Olayın günü (don gecesi, vade, son gün).
  final DateTime gun;
  final DateTime bildirimZamani;

  /// Ekranda görünmeye başlama zamanı (verilmezse [bildirimZamani]).
  final DateTime? gosterim;

  /// 0: acil, 1: önemli, 2: bilgi.
  final int oncelik;

  /// Dokununca açılacak kayıt (hesap id, hatırlatma id).
  final String? hedefId;

  const Uyari({
    required this.anahtar,
    required this.grup,
    required this.tur,
    required this.baslik,
    required this.metin,
    required this.gun,
    required this.bildirimZamani,
    this.gosterim,
    required this.oncelik,
    this.hedefId,
  });
}

String _tarih(DateTime t) => '${t.day}.${t.month}.${t.year}';
String _isoGun(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
final _tl = NumberFormat.decimalPattern('tr');
String _para(double v) => '${_tl.format(v.round())} ₺';
DateTime _saat(DateTime gun, int saat) => DateTime(gun.year, gun.month, gun.day, saat);

/// 2 m'deki sıcaklık 2 °C'ye inince yerde kırağı/don olabilir.
const double donRiskiEsigi = 2.0;

/// Önümüzdeki 3 gecenin don uyarıları; tarlalar gün bazında birleştirilir.
/// Bildirim, don gecesinden önceki akşam 18:00'de çıkar.
List<Uyari> donUyarilari(Map<String, List<GunlukHavaVerisi>> tarlaTahminleri, DateTime simdi) {
  final bugun = DateUtils.dateOnly(simdi);
  final gunler = <DateTime, List<(String, double)>>{};
  tarlaTahminleri.forEach((tarla, tahmin) {
    for (final g in tahmin) {
      final gun = DateUtils.dateOnly(g.tarih);
      if (gun.isBefore(bugun) || gun.difference(bugun).inDays > 3) continue;
      if (g.minSicaklik <= donRiskiEsigi) (gunler[gun] ??= []).add((tarla, g.minSicaklik));
    }
  });

  final sonuc = <Uyari>[];
  for (final e in gunler.entries) {
    final enDusuk = e.value.map((t) => t.$2).reduce((a, b) => a < b ? a : b);
    final tarlalar = (e.value.toList()..sort((a, b) => a.$2.compareTo(b.$2))).map((t) => t.$1).toList();
    final derece = '${enDusuk.toStringAsFixed(0)} °C';
    final (baslik, oneri) = enDusuk <= -2
        ? ('Kuvvetli don bekleniyor ($derece)',
            'Fide, sebze ve çiçekteki ağaçlar zarar görebilir; örtün, mümkünse gece yağmurlama/sisleme yapın.')
        : enDusuk <= 0
            ? ('Don bekleniyor ($derece)', 'Hassas fide ve çiçekteki ağaçları örtün; sulama yapacaksanız akşamdan yapın.')
            : ('Don riski / kırağı ($derece)', 'Açık ve rüzgarsız gecede yer seviyesinde kırağı olabilir.');
    // Günlük en düşük sıcaklık sabaha karşı olur: D günü için don gecesi D-1'i D'ye bağlayan gecedir.
    final onceki = e.key.subtract(const Duration(days: 1));
    sonuc.add(Uyari(
      anahtar: 'don:${_isoGun(e.key)}',
      grup: 'don:${_isoGun(e.key)}',
      tur: UyariTuru.don,
      baslik: baslik,
      metin: '${onceki.day}.${onceki.month} gecesi (${_tarih(e.key)} sabahına karşı) • ${tarlalar.join(', ')}\n$oneri',
      gun: e.key,
      bildirimZamani: _saat(onceki, 18),
      // Ekranda tahmin gelir gelmez görünsün; bildirim önceki akşam.
      gosterim: simdi,
      oncelik: enDusuk <= 0 ? 0 : 1,
    ));
  }
  return sonuc;
}

/// Veresiye vadeleri: vade gününden 2 gün önce ve vade sabahı 09:00.
List<Uyari> vadeUyarilari(List<CariEntity> cariler, List<CariHareketEntity> hareketler, DateTime simdi) {
  final bugun = DateUtils.dateOnly(simdi);
  final sonuc = <Uyari>[];
  for (final c in cariler.where((c) => !c.isDeleted)) {
    for (final v in acikVadeler(hareketler.where((h) => h.cariId == c.id))) {
      final ne = v.borcum ? 'Ödenecek' : 'Tahsil edilecek';
      final grup = 'vade:${c.id}:${_isoGun(v.vade)}:${v.borcum ? 'b' : 'a'}';
      final gecti = v.vade.isBefore(bugun);
      final metin = '$ne: ${_para(v.acik)} • Vade ${_tarih(v.vade)}';
      sonuc.add(Uyari(
        anahtar: '$grup:once',
        grup: grup,
        tur: UyariTuru.vade,
        baslik: '${c.ad}: vade yaklaşıyor',
        metin: metin,
        gun: v.vade,
        bildirimZamani: _saat(v.vade.subtract(const Duration(days: 2)), 9),
        oncelik: 1,
        hedefId: c.id,
      ));
      sonuc.add(Uyari(
        anahtar: '$grup:gun',
        grup: grup,
        tur: UyariTuru.vade,
        baslik: gecti ? '${c.ad}: vadesi geçti' : '${c.ad}: bugün vade günü',
        metin: metin,
        gun: v.vade,
        bildirimZamani: _saat(v.vade, 9),
        oncelik: gecti ? 0 : 1,
        hedefId: c.id,
      ));
    }
  }
  return sonuc;
}

/// Hatırlatmalar: "kaç gün önce" sabahı ve son gün sabahı 09:00.
List<Uyari> hatirlatmaUyarilari(List<HatirlatmaEntity> hatirlatmalar, DateTime simdi) {
  final bugun = DateUtils.dateOnly(simdi);
  final sonuc = <Uyari>[];
  for (final h in hatirlatmalar.where((h) => !h.isDeleted && !h.tamamlandi)) {
    final grup = 'hat:${h.id}:${_isoGun(h.gun)}';
    final kalan = h.gun.difference(bugun).inDays;
    final metin = '${h.tur.ad} • Son gün ${_tarih(h.gun)}${h.not.isEmpty ? '\n${h.not}' : ''}';
    if (h.kacGunOnce > 0) {
      // İleriye kurulan bildirimde "kaç gün kaldı" o günün gözüyle yazılır.
      final onceGun = h.gun.subtract(Duration(days: h.kacGunOnce));
      final kalanO = onceGun.isAfter(bugun) ? h.kacGunOnce : kalan;
      sonuc.add(Uyari(
        anahtar: '$grup:once',
        grup: grup,
        tur: UyariTuru.hatirlatma,
        baslik: kalanO > 0 ? '${h.baslik} ($kalanO gün kaldı)' : h.baslik,
        metin: metin,
        gun: h.gun,
        bildirimZamani: _saat(onceGun, 9),
        oncelik: 1,
        hedefId: h.id,
      ));
    }
    sonuc.add(Uyari(
      anahtar: '$grup:gun',
      grup: grup,
      tur: UyariTuru.hatirlatma,
      baslik: kalan < 0 ? '${h.baslik} (tarihi geçti)' : '${h.baslik} (bugün son gün)',
      metin: metin,
      gun: h.gun,
      bildirimZamani: _saat(h.gun, 9),
      oncelik: kalan <= 0 ? 0 : 1,
      hedefId: h.id,
    ));
  }
  return sonuc;
}

/// Ekranda gösterilecekler: zamanı gelmiş uyarılardan her grubun en son başlayanı.
/// Geçmiş don geceleri gösterilmez. Önce acil olanlar, sonra güne göre.
List<Uyari> aktifUyarilar(List<Uyari> tumu, DateTime simdi) {
  final bugun = DateUtils.dateOnly(simdi);
  final gruplar = <String, Uyari>{};
  for (final u in tumu) {
    if ((u.gosterim ?? u.bildirimZamani).isAfter(simdi)) continue;
    if (u.tur == UyariTuru.don && u.gun.isBefore(bugun)) continue;
    final mevcut = gruplar[u.grup];
    if (mevcut == null || (u.bildirimZamani.isAfter(mevcut.bildirimZamani) && !u.bildirimZamani.isAfter(simdi))) {
      gruplar[u.grup] = u;
    }
  }
  return gruplar.values.toList()
    ..sort((a, b) {
      final o = a.oncelik.compareTo(b.oncelik);
      return o != 0 ? o : a.gun.compareTo(b.gun);
    });
}

/// Bildirim kimliği: anahtarın kararlı (çalıştırmalar arasında aynı) 31 bit özeti.
int bildirimKimligi(String anahtar) {
  var h = 0x811c9dc5;
  for (final c in anahtar.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}
