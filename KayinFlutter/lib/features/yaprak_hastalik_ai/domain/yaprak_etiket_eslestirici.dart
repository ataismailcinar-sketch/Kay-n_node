import 'zirai_recete_engine.dart';

/// Model etiketinin (PlantVillage sınıf adı) Türkçe karşılığı ve varsa reçetesi.
class EtiketBilgisi {
  /// Uygulamadaki ürün adı (parsel `ekilmisUrun` değerleriyle uyumlu).
  final String bitki;

  /// Kullanıcıya gösterilecek teşhis adı.
  final String teshis;

  /// Reçete veritabanındaki tam `hastalikAdi`; reçete yoksa null.
  final String? receteAdi;

  final bool saglikli;

  const EtiketBilgisi(this.bitki, this.teshis, {this.receteAdi, this.saglikli = false});

  /// Teşhis adı reçete adıyla aynı olan hastalık.
  const EtiketBilgisi.receteli(this.bitki, this.teshis)
      : receteAdi = teshis,
        saglikli = false;
}

/// Model etiketlerini Türkçe teşhislere ve mevcut reçetelere bağlar.
/// İki etiket ailesi var: Kayın tarla modeli (`Bugday___Sari_Pas` …, tool/model_egitimi)
/// ve eski PlantVillage modeli (38 sınıf; modeli geri almak gerekirse diye duruyor).
/// Reçetesi olmayan hastalıklar için uydurma reçete EŞLENMEZ.
class YaprakEtiketEslestirici {
  static const _saglikli = 'Sağlıklı Bitki Dokusu';
  static const _gecYaniklik = 'Domates Mildiyösü / Geç Yanıklık (Phytophthora infestans)';
  static const _erkenYaniklik = 'Erken Yanıklık (Alternaria solani)';
  static const _kirmiziOrumcek = 'Kırmızı Örümcek & Akar Zararlısı (Tetranychus spp.)';
  static const _misirYaniklik = 'Mısır Yaprak Yanıklığı (Helminthosporium / Turcicum)';
  static const _pas = 'Sarı Pas & Kahverengi Pas (Puccinia spp.)';
  static const _hububatKulleme = 'Hububat Küllemesi (Blumeria graminis)';
  static const _septorya = 'Septorya Yaprak Lekesi (Septoria tritici)';
  static const _aycicegiMildiyo = 'Ayçiçeği Mildiyösü & Köken Çürüklüğü (Plasmopara)';

  /// Anahtar: etiketin sadece harf/rakamlardan oluşan küçük harfli hali.
  static final Map<String, EtiketBilgisi> _tablo = {
    // ── Kayın tarla modeli ──
    'bugdaysaripas': const EtiketBilgisi('Buğday', 'Buğday Sarı Pası (Puccinia striiformis)', receteAdi: _pas),
    'bugdaykahverengipas': const EtiketBilgisi('Buğday', 'Buğday Kahverengi Pası (Puccinia triticina)', receteAdi: _pas),
    'bugdaykulleme': const EtiketBilgisi('Buğday', _hububatKulleme, receteAdi: _hububatKulleme),
    'bugdayseptorya': const EtiketBilgisi('Buğday', _septorya, receteAdi: _septorya),
    'bugdaysaglikli': const EtiketBilgisi('Buğday', _saglikli, receteAdi: _saglikli, saglikli: true),
    'arpaagleke': const EtiketBilgisi.receteli('Arpa', 'Arpa Ağ Lekesi (Pyrenophora teres)'),
    'arparinkosporyum': const EtiketBilgisi.receteli('Arpa', 'Arpa Yaprak Lekesi / Rinkosporyum (Rhynchosporium)'),
    'arpasaglikli': const EtiketBilgisi('Arpa', _saglikli, receteAdi: _saglikli, saglikli: true),
    'aycicegimildiyo': const EtiketBilgisi('Ayçiçeği', 'Ayçiçeği Mildiyösü (Plasmopara halstedii)', receteAdi: _aycicegiMildiyo),
    'aycicegikulleme': const EtiketBilgisi.receteli('Ayçiçeği', 'Ayçiçeği Küllemesi (Golovinomyces)'),
    'aycicegialternarya': const EtiketBilgisi.receteli('Ayçiçeği', 'Ayçiçeği Alternarya Yaprak Lekesi'),
    'aycicegisolgunluk': const EtiketBilgisi.receteli('Ayçiçeği', 'Solgun Yaprak (susuzluk, kök ya da solgunluk hastalığı olabilir)'),
    'aycicegikursunikuf': const EtiketBilgisi.receteli('Ayçiçeği', 'Ayçiçeği Kurşuni Küf (Botrytis cinerea)'),
    'aycicegisaglikli': const EtiketBilgisi('Ayçiçeği', _saglikli, receteAdi: _saglikli, saglikli: true),
    'pamukfusarium': const EtiketBilgisi.receteli('Pamuk', 'Pamuk Fusarium Solgunluğu'),
    'pamukverticillium': const EtiketBilgisi.receteli('Pamuk', 'Pamuk Verticillium Solgunluğu (Verticillium dahliae)'),
    'pamukbakteriyelyaniklik': const EtiketBilgisi.receteli('Pamuk', 'Pamuk Bakteriyel Yanıklık (Xanthomonas)'),
    'pamukalternarya': const EtiketBilgisi.receteli('Pamuk', 'Pamuk Alternarya Yaprak Lekesi'),
    'pamuksaglikli': const EtiketBilgisi('Pamuk', _saglikli, receteAdi: _saglikli, saglikli: true),
    'sekerpancariserkospora': const EtiketBilgisi.receteli('Şeker Pancarı', 'Pancar Serkospora Yaprak Lekesi (Cercospora beticola)'),
    'sekerpancarisaglikli': const EtiketBilgisi('Şeker Pancarı', _saglikli, receteAdi: _saglikli, saglikli: true),
    'mercimekaskohita': const EtiketBilgisi.receteli('Mercimek', 'Mercimek Antraknozu / Askohita (Ascochyta lentis)'),
    'mercimekpas': const EtiketBilgisi.receteli('Mercimek', 'Mercimek Pası (Uromyces viciae-fabae)'),
    'mercimekkulleme': const EtiketBilgisi.receteli('Mercimek', 'Mercimek Küllemesi'),
    'mercimeksaglikli': const EtiketBilgisi('Mercimek', _saglikli, receteAdi: _saglikli, saglikli: true),
    'domateserkenyaniklik': const EtiketBilgisi('Domates', _erkenYaniklik, receteAdi: _erkenYaniklik),
    'domatesgecyaniklik': const EtiketBilgisi('Domates', _gecYaniklik, receteAdi: _gecYaniklik),
    'domatesbakteriyelleke': const EtiketBilgisi.receteli('Domates', 'Domates Bakteriyel Leke (Xanthomonas)'),
    'domatesmozaikvirusu': const EtiketBilgisi.receteli('Domates', 'Domates Mozaik Virüsü (ToMV)'),
    'domatessarikivircikvirusu': const EtiketBilgisi.receteli('Domates', 'Domates Sarı Yaprak Kıvırcıklık Virüsü (TYLCV)'),
    'domatesyaprakkufu': const EtiketBilgisi.receteli('Domates', 'Domates Yaprak Küfü (Passalora fulva)'),
    'domatesseptorya': const EtiketBilgisi.receteli('Domates', 'Domates Septorya Yaprak Lekesi (Septoria lycopersici)'),
    'domatessaglikli': const EtiketBilgisi('Domates', _saglikli, receteAdi: _saglikli, saglikli: true),
    'uzumsiyahcurukluk': const EtiketBilgisi.receteli('Üzüm', 'Bağ Siyah Çürüklüğü (Guignardia bidwellii)'),
    'uzumsaglikli': const EtiketBilgisi('Üzüm', _saglikli, receteAdi: _saglikli, saglikli: true),
    // ── Eski PlantVillage modeli ──
    'appleapplescab': const EtiketBilgisi('Elma', 'Elma Karalekesi (Venturia inaequalis)'),
    'appleblackrot': const EtiketBilgisi('Elma', 'Elma Siyah Çürüklüğü (Botryosphaeria obtusa)'),
    'applecedarapplerust': const EtiketBilgisi('Elma', 'Elma Sedir Pası (Gymnosporangium)'),
    'applehealthy': const EtiketBilgisi('Elma', _saglikli, receteAdi: _saglikli, saglikli: true),
    'blueberryhealthy': const EtiketBilgisi('Yaban Mersini', _saglikli, receteAdi: _saglikli, saglikli: true),
    'cherryincludingsourpowderymildew': const EtiketBilgisi('Kiraz', 'Kiraz Küllemesi (Podosphaera clandestina)'),
    'cherryincludingsourhealthy': const EtiketBilgisi('Kiraz', _saglikli, receteAdi: _saglikli, saglikli: true),
    'cornmaizecercosporaleafspotgrayleafspot': const EtiketBilgisi('Mısır', 'Mısır Gri Yaprak Lekesi (Cercospora zeae-maydis)'),
    'cornmaizecommonrust': const EtiketBilgisi('Mısır', 'Mısır Pası (Puccinia sorghi)'),
    'cornmaizenorthernleafblight': const EtiketBilgisi('Mısır', _misirYaniklik, receteAdi: _misirYaniklik),
    'cornmaizehealthy': const EtiketBilgisi('Mısır', _saglikli, receteAdi: _saglikli, saglikli: true),
    'grapeblackrot': const EtiketBilgisi('Üzüm', 'Bağ Siyah Çürüklüğü (Guignardia bidwellii)'),
    'grapeescablackmeasles': const EtiketBilgisi('Üzüm', 'Bağ Kav Hastalığı / Esca'),
    'grapeleafblightisariopsisleafspot': const EtiketBilgisi('Üzüm', 'Bağ Yaprak Lekesi (Isariopsis)'),
    'grapehealthy': const EtiketBilgisi('Üzüm', _saglikli, receteAdi: _saglikli, saglikli: true),
    'orangehaunglongbingcitrusgreening': const EtiketBilgisi('Portakal', 'Turunçgil Yeşillenme Hastalığı (HLB)'),
    'peachbacterialspot': const EtiketBilgisi('Şeftali', 'Şeftali Bakteriyel Leke (Xanthomonas)'),
    'peachhealthy': const EtiketBilgisi('Şeftali', _saglikli, receteAdi: _saglikli, saglikli: true),
    'pepperbellbacterialspot': const EtiketBilgisi('Biber', 'Biber Bakteriyel Leke (Xanthomonas)'),
    'pepperbellhealthy': const EtiketBilgisi('Biber', _saglikli, receteAdi: _saglikli, saglikli: true),
    'potatoearlyblight': const EtiketBilgisi('Patates', _erkenYaniklik, receteAdi: _erkenYaniklik),
    'potatolateblight': const EtiketBilgisi('Patates', _gecYaniklik, receteAdi: _gecYaniklik),
    'potatohealthy': const EtiketBilgisi('Patates', _saglikli, receteAdi: _saglikli, saglikli: true),
    'raspberryhealthy': const EtiketBilgisi('Ahududu', _saglikli, receteAdi: _saglikli, saglikli: true),
    'soybeanhealthy': const EtiketBilgisi('Soya', _saglikli, receteAdi: _saglikli, saglikli: true),
    'squashpowderymildew': const EtiketBilgisi('Kabak', 'Kabak Küllemesi'),
    'strawberryleafscorch': const EtiketBilgisi('Çilek', 'Çilek Yaprak Yanıklığı (Diplocarpon earlianum)'),
    'strawberryhealthy': const EtiketBilgisi('Çilek', _saglikli, receteAdi: _saglikli, saglikli: true),
    'tomatobacterialspot': const EtiketBilgisi('Domates', 'Domates Bakteriyel Leke (Xanthomonas)'),
    'tomatoearlyblight': const EtiketBilgisi('Domates', _erkenYaniklik, receteAdi: _erkenYaniklik),
    'tomatolateblight': const EtiketBilgisi('Domates', _gecYaniklik, receteAdi: _gecYaniklik),
    'tomatoleafmold': const EtiketBilgisi('Domates', 'Domates Yaprak Küfü (Passalora fulva)'),
    'tomatoseptorialeafspot': const EtiketBilgisi('Domates', 'Domates Septorya Yaprak Lekesi (Septoria lycopersici)'),
    'tomatospidermitestwospottedspidermite': const EtiketBilgisi('Domates', _kirmiziOrumcek, receteAdi: _kirmiziOrumcek),
    'tomatotargetspot': const EtiketBilgisi('Domates', 'Domates Hedef Leke (Corynespora cassiicola)'),
    'tomatotomatoyellowleafcurlvirus': const EtiketBilgisi('Domates', 'Domates Sarı Yaprak Kıvırcıklık Virüsü (TYLCV)'),
    'tomatotomatomosaicvirus': const EtiketBilgisi('Domates', 'Domates Mozaik Virüsü (ToMV)'),
    'tomatohealthy': const EtiketBilgisi('Domates', _saglikli, receteAdi: _saglikli, saglikli: true),
  };

  static String _anahtar(String etiket) =>
      etiket.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Bilinmeyen etiketler için etiketi olduğu gibi gösteren yedek bilgi döner.
  static EtiketBilgisi coz(String etiket) {
    final bilgi = _tablo[_anahtar(etiket)];
    if (bilgi != null) return bilgi;
    final parcalar = etiket.split(RegExp(r'_{2,}'));
    final bitki = parcalar.first.replaceAll('_', ' ').trim();
    final teshis = (parcalar.length > 1 ? parcalar.last : etiket).replaceAll('_', ' ').trim();
    final saglikli = teshis.toLowerCase().contains('healthy');
    return EtiketBilgisi(bitki, saglikli ? _saglikli : teshis,
        receteAdi: saglikli ? _saglikli : null, saglikli: saglikli);
  }

  static ZiraiRecete? receteBul(EtiketBilgisi b) =>
      b.receteAdi == null ? null : ZiraiReceteEngine.receteBul(b.receteAdi!);

  /// Kayıtlı teşhis adından reçete. Teşhis adı reçete adı olabilir (manuel seçim, eski model)
  /// ya da modelin daha özgül adı ("Buğday Sarı Pası …" → "Sarı Pas & Kahverengi Pas …").
  static ZiraiRecete? teshisReceti(String teshisAdi) {
    final dogrudan = ZiraiReceteEngine.receteBul(teshisAdi);
    if (dogrudan != null) return dogrudan;
    for (final b in _tablo.values) {
      if (b.receteAdi != null && b.teshis == teshisAdi) return receteBul(b);
    }
    return null;
  }

  /// Parseldeki ürün adını modelin bitki adlarıyla karşılaştırır ("Bağ" = "Üzüm").
  static bool ayniBitki(String parselUrunu, String modelBitkisi) {
    String n(String s) {
      final k = s.toLowerCase().trim();
      return k.startsWith('bağ') ? 'üzüm' : k;
    }
    return n(parselUrunu) == n(modelBitkisi);
  }

  /// Modelin tanıyabildiği ürün adları (etiket listesinden türetilir).
  static Set<String> destekliBitkiler(Iterable<String> etiketler) =>
      etiketler.map((e) => coz(e).bitki).toSet();
}
