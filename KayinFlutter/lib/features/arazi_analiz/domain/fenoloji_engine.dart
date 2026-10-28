/// BBCH Skalası & Fenolojik Bitki Gelişim Takvimi Motoru.
///
/// Ekilen ürün ve ekim tarihine göre tarladaki bitkinin hangi gelişim evresinde
/// olduğunu, tahmini hasada kalan günü ve bu evrede yapılması gereken
/// kritik tarımsal müdahaleleri (gübreleme, ilaçlama, sulama) hesaplar.
class FenolojiEngine {
  /// Çok yıllık ürünlerde (zeytin, bağ) evre takvim ayından hesaplanır; ekim tarihi gerekmez.
  static bool cokYillik(String urun) => const {'Zeytin', 'Üzüm', 'Uzum', 'Bağ', 'Yonca'}.contains(urun);

  /// Tek yıllık ürünlerde evre için ekim tarihi gerekir. Girilmemişse [hesapla]
  /// 60 gün önce ekilmiş varsayar; arayüz bunu "varsayım" olarak göstermelidir.
  static bool ekimTarihiGerekli(String urun) => !cokYillik(urun);

  static FenolojikEvreSonuc hesapla({
    required String ekilmisUrun,
    DateTime? ekimTarihi,
  }) {
    final now = DateTime.now();
    // Ekim tarihi belirtilmemişse varsayılan sezon başlangıcı baz alınır (ör: 60 gün önce)
    final gercekEkim = ekimTarihi ?? now.subtract(const Duration(days: 60));
    final gecenGun = now.difference(gercekEkim).inDays.clamp(0, 365);

    return switch (ekilmisUrun) {
      'Buğday' || 'Bugday' || 'Arpa' => _hesaplaBugday(gecenGun),
      'Mısır' || 'Misir'             => _hesaplaMisir(gecenGun),
      'Ayçiçeği' || 'Aycicegi'       => _hesaplaAycicegi(gecenGun),
      'Pamuk'                        => _hesaplaPamuk(gecenGun),
      'Domates'                      => _hesaplaDomates(gecenGun),
      'Zeytin'                       => _hesaplaZeytin(now),
      'Üzüm' || 'Uzum' || 'Bağ'      => _hesaplaUzum(now),
      'Soya'                         => _hesaplaSoya(gecenGun),
      'Şeker Pancarı'                => _hesaplaPancar(gecenGun),
      'Nohut'                        => _hesaplaNohut(gecenGun),
      'Mercimek'                     => _hesaplaMercimek(gecenGun),
      'Patates'                      => _hesaplaPatates(gecenGun),
      'Fasulye'                      => _hesaplaFasulye(gecenGun),
      'Yonca'                        => _hesaplaYonca(now),
      _                              => _hesaplaGenel(gecenGun),
    };
  }

  static FenolojikEvreSonuc _hesaplaBugday(int gun) {
    if (gun <= 15) {
      return FenolojikEvreSonuc(
        evreAdi: 'Çimlenme & Çıkış (BBCH 00-09)',
        evreAciklama: 'Tohum çimlenip ilk yeşil yapraklar toprak yüzeyine çıkıyor.',
        ilerlemeYuzdesi: (gun / 15).clamp(0.0, 1.0) * 0.2,
        gecenGun: gun,
        tahminiHasatGunu: 210,
        yapilacakIsler: [
          const TarimsalIslem(
            baslik: 'Çıkış Kontrolü & Kaymak Tabakası',
            aciklama: 'Aşırı yağmur sonrası toprakta kaymak oluştuysa merdane/tırmıkla kırılmalı.',
            oncelik: 'Yüksek',
            ikon: '🌱',
          ),
        ],
      );
    } else if (gun <= 60) {
      return FenolojikEvreSonuc(
        evreAdi: 'Kardeşlenme Evresi (BBCH 20-29)',
        evreAciklama: 'Kök boğazından yan sürgünler oluşuyor. Verim potansiyeli bu evrede belirlenir.',
        ilerlemeYuzdesi: 0.2 + ((gun - 15) / 45).clamp(0.0, 1.0) * 0.25,
        gecenGun: gun,
        tahminiHasatGunu: 210,
        yapilacakIsler: [
          const TarimsalIslem(
            baslik: '1. Azotlu Üst Gübreleme (Üre)',
            aciklama: 'Dönüme 10-15 kg Üre (%46 N) gübresi yağış öncesinde toprağa atılmalı.',
            oncelik: 'Acil',
            ikon: '🌿',
          ),
          const TarimsalIslem(
            baslik: 'Geniş & Dar Yapraklı Yabancı Ot İlacı',
            aciklama: 'Kardeşlenme sonuna kadar herbisit uygulaması tamamlanmalıdır.',
            oncelik: 'Önemli',
            ikon: '🧪',
          ),
        ],
      );
    } else if (gun <= 120) {
      return FenolojikEvreSonuc(
        evreAdi: 'Sapa Kalkma Evresi (BBCH 30-39)',
        evreAciklama: 'Boğumlar uzuyor, başak taslağı gövde içinde yükseliyor. Su ve besin ihtiyacı zirvede.',
        ilerlemeYuzdesi: 0.45 + ((gun - 60) / 60).clamp(0.0, 1.0) * 0.25,
        gecenGun: gun,
        tahminiHasatGunu: 210,
        yapilacakIsler: [
          const TarimsalIslem(
            baslik: '2. Azotlu Üst Gübreleme (Nitrat / CAN)',
            aciklama: 'Dönüme 12-18 kg %26 CAN veya %33 AN gübresi atılmalı.',
            oncelik: 'Acil',
            ikon: '⚡',
          ),
          const TarimsalIslem(
            baslik: 'Pas & Külleme Fungusit Koruması',
            aciklama: 'Hava ılık ve nemliyse sarı pas ve septorya lekesine karşı yaprak ilacı atılmalı.',
            oncelik: 'Yüksek',
            ikon: '🛡️',
          ),
        ],
      );
    } else if (gun <= 170) {
      return FenolojikEvreSonuc(
        evreAdi: 'Başaklanma & Dane Dolum (BBCH 50-75)',
        evreAciklama: 'Başaklar kından çıktı, çiçeklenme bitti ve daneler süt/sarı olum evresinde.',
        ilerlemeYuzdesi: 0.70 + ((gun - 120) / 50).clamp(0.0, 1.0) * 0.20,
        gecenGun: gun,
        tahminiHasatGunu: 210,
        yapilacakIsler: [
          const TarimsalIslem(
            baslik: 'Süne & Kımıl Mücadelesi',
            aciklama: 'Metrekarede 10 adet nimf görüldüğünde süne ilacı uygulanmalı.',
            oncelik: 'Kritik',
            ikon: '🦗',
          ),
          const TarimsalIslem(
            baslik: 'Kritik Dane Doldurma Sulaması',
            aciklama: 'İmkan varsa danelerin dolgun ve hektolitre ağırlığının yüksek olması için sulanmalı.',
            oncelik: 'Yüksek',
            ikon: '💧',
          ),
        ],
      );
    } else {
      return FenolojikEvreSonuc(
        evreAdi: 'Tam Olgunlaşma & Hasat (BBCH 89-99)',
        evreAciklama: 'Dane nem oranı %13-14 seviyesine indi. Tarla hasada hazır.',
        ilerlemeYuzdesi: 1.0,
        gecenGun: gun,
        tahminiHasatGunu: 210,
        yapilacakIsler: [
          const TarimsalIslem(
            baslik: 'Biçerdöver & Nem Kontrolü',
            aciklama: 'Dane nemi %14 altına indiğinde dökülmeyi önlemek için sabah serinliğinde hasat yapılmalı.',
            oncelik: 'Acil',
            ikon: '🚜',
          ),
        ],
      );
    }
  }

  static FenolojikEvreSonuc _hesaplaMisir(int gun) {
    if (gun <= 30) {
      return FenolojikEvreSonuc(
        evreAdi: 'Çıkış & 4-6 Yaprak Evresi (V4-V6)',
        evreAciklama: 'Kök sistemi gelişiyor. Yabancı ot rekabetine en açık dönem.',
        ilerlemeYuzdesi: (gun / 30).clamp(0.0, 1.0) * 0.25,
        gecenGun: gun,
        tahminiHasatGunu: 130,
        yapilacakIsler: [
          const TarimsalIslem(
            baslik: 'Çıkış Sonrası Ot İlacı & Çapalama',
            aciklama: 'Mısır 6 yaprak olmadan dar/geniş yapraklı ot mücadelesi tamamlanmalı.',
            oncelik: 'Acil',
            ikon: '🧪',
          ),
          const TarimsalIslem(
            baslik: 'Çinko & Fosfor Yaprak Gübresi',
            aciklama: 'Kök gelişimini ve koçan taslağını güçlendirmek için çinko takviyesi.',
            oncelik: 'Önemli',
            ikon: '🌿',
          ),
        ],
      );
    } else if (gun <= 75) {
      return FenolojikEvreSonuc(
        evreAdi: 'Hızlı Büyüme & Tepe Püskülü (V12-VT)',
        evreAciklama: 'Gövde kalınlaşıyor, tepe ve koçan püskülleri çıkıyor.',
        ilerlemeYuzdesi: 0.25 + ((gun - 30) / 45).clamp(0.0, 1.0) * 0.40,
        gecenGun: gun,
        tahminiHasatGunu: 130,
        yapilacakIsler: [
          const TarimsalIslem(
            baslik: 'Boğaz Doldurma & Azot Gübrelemesi',
            aciklama: 'Ara çapa ile boğaz doldurulup damlamadan veya yağmurlamadan Üre/UAN verilmeli.',
            oncelik: 'Acil',
            ikon: '⚡',
          ),
          const TarimsalIslem(
            baslik: 'Koçan Kurdu & Çizgili Kurdu Takibi',
            aciklama: 'Püskül döneminde yumurta ve kurt zararına karşı insektisit uygulaması.',
            oncelik: 'Yüksek',
            ikon: '🐛',
          ),
        ],
      );
    } else {
      return FenolojikEvreSonuc(
        evreAdi: 'Koçan Dane Doldurma & Olgunlaşma (R3-R6)',
        evreAciklama: 'Süt olumdan diş olum evresine geçiş, siyah nokta tabakası oluşumu.',
        ilerlemeYuzdesi: 0.65 + ((gun - 75) / 55).clamp(0.0, 1.0) * 0.35,
        gecenGun: gun,
        tahminiHasatGunu: 130,
        yapilacakIsler: [
          const TarimsalIslem(
            baslik: 'Son Dane Dolum Sulaması',
            aciklama: 'Koçan uçlarının dolgun kalması için siyah nokta görülene kadar su kesilmemeli.',
            oncelik: 'Önemli',
            ikon: '💧',
          ),
        ],
      );
    }
  }

  static FenolojikEvreSonuc _hesaplaAycicegi(int gun) {
    return FenolojikEvreSonuc(
      evreAdi: gun < 45 ? 'Vejetatif Büyüme (Yıldız Tabla Öncesi)' : (gun < 80 ? 'Çiçeklenme & Döllenme' : 'Dane Dolumu & Hasat'),
      evreAciklama: 'Günebakan tablası güneşi takip ediyor, tohumlar yağ biriktiriyor.',
      ilerlemeYuzdesi: (gun / 115).clamp(0.0, 1.0),
      gecenGun: gun,
      tahminiHasatGunu: 115,
      yapilacakIsler: [
        const TarimsalIslem(
          baslik: 'Bor & Çinko Yaprak Beslemesi',
          aciklama: 'Tabla ortasında boş dane kalmaması ve döllenme için Bor gübrelemesi.',
          oncelik: 'Önemli',
          ikon: '🌻',
        ),
        const TarimsalIslem(
          baslik: 'Çayır Tırtılı & Kuş Zararı Kontrolü',
          aciklama: 'Tablalar dolarken zararlı takibi yapılmalı.',
          oncelik: 'Orta',
          ikon: '🛡️',
        ),
      ],
    );
  }

  static FenolojikEvreSonuc _hesaplaPamuk(int gun) {
    return FenolojikEvreSonuc(
      evreAdi: gun < 50 ? 'Taraklanma Evresi' : (gun < 100 ? 'Çiçeklenme & Koza Tutumu' : 'Koza Açımı & Hasat'),
      evreAciklama: 'Beyaz altın koza oluşturma ve lif uzama periyodu.',
      ilerlemeYuzdesi: (gun / 155).clamp(0.0, 1.0),
      gecenGun: gun,
      tahminiHasatGunu: 155,
      yapilacakIsler: [
        const TarimsalIslem(
          baslik: 'Boy Kesici (Pix / Mepiquat Chloride)',
          aciklama: 'Aşırı vejetatif boylanmayı durdurup enerjiyi kozaya yönlendirmek için büyüme düzenleyici.',
          oncelik: 'Yüksek',
          ikon: '✂️',
        ),
        const TarimsalIslem(
          baslik: 'Yeşilkurt & Kırmızı Örümcek Sayımı',
          aciklama: 'Tarak dökümünü önlemek için koza kurdu ilaçlaması.',
          oncelik: 'Kritik',
          ikon: '🐛',
        ),
      ],
    );
  }

  static FenolojikEvreSonuc _hesaplaDomates(int gun) {
    return FenolojikEvreSonuc(
      evreAdi: gun < 30 ? 'Fide Gelişimi' : (gun < 65 ? 'Çiçeklenme & Meyve Tutumu' : 'Hasat & Toplama'),
      evreAciklama: 'Kök ve salkım gelişimi, kızarma periyodu.',
      ilerlemeYuzdesi: (gun / 90).clamp(0.0, 1.0),
      gecenGun: gun,
      tahminiHasatGunu: 90,
      yapilacakIsler: [
        const TarimsalIslem(
          baslik: 'Kalsiyum Nitrat Takviyesi',
          aciklama: 'Meyvede dip çürüklüğünü (çiçek burnu çürüklüğü) önlemek için damlamadan kalsiyum.',
          oncelik: 'Acil',
          ikon: '🍅',
        ),
        const TarimsalIslem(
          baslik: 'Tuta Absoluta (Domates Güvesi) Tuzağı',
          aciklama: 'Feromon tuzakları kurulmalı ve biyolojik/kimyasal mücadele yapılmalı.',
          oncelik: 'Kritik',
          ikon: '🦋',
        ),
      ],
    );
  }

  /// Yılın kaçıncı günü (1 Ocak = 0).
  static int _yilinGunu(DateTime t) => t.difference(DateTime(t.year)).inDays;

  /// Çok yıllıklarda: bugünden bir sonraki hasat başlangıcına kalan gün için
  /// (gecenGun, tahminiHasatGunu) çifti. kalanGun = hasat - gecen.
  static (int, int) _hasataGore(DateTime now, int hasatAyi, int hasatBitisAyi) {
    final gecenBugun = _yilinGunu(now);
    if (now.month >= hasatAyi && now.month <= hasatBitisAyi) return (gecenBugun, gecenBugun); // hasat dönemindeyiz
    final buYil = DateTime(now.year, hasatAyi, 1);
    final hedef = now.isAfter(buYil) ? DateTime(now.year + 1, hasatAyi, 1) : buYil;
    final gecen = _yilinGunu(now);
    return (gecen, gecen + hedef.difference(DateTime(now.year, now.month, now.day)).inDays);
  }

  static FenolojikEvreSonuc _hesaplaZeytin(DateTime now) {
    final ay = now.month;
    final (gecen, hasat) = _hasataGore(now, 10, 12);
    final evre = ay <= 3 ? 'Kış Dinlenmesi & Budama' : (ay <= 5 ? 'Sürgün & Çiçeklenme' : (ay <= 9 ? 'Meyve İrileşmesi & Yağlanma' : 'Hasat'));
    return FenolojikEvreSonuc(
      evreAdi: evre,
      evreAciklama: 'Çok yıllık zeytin ağacı mevsimsel fenolojik döngüsü (hasat Ekim-Aralık).',
      ilerlemeYuzdesi: (ay / 12).clamp(0.0, 1.0),
      gecenGun: gecen,
      tahminiHasatGunu: hasat,
      yapilacakIsler: [
        const TarimsalIslem(
          baslik: 'Zeytin Sineği & Halkalı Leke İlacı',
          aciklama: 'Tuzaklarda sinek popülasyonu arttığında vuruk önleyici ilaçlama.',
          oncelik: 'Yüksek',
          ikon: '🫒',
        ),
        const TarimsalIslem(
          baslik: 'Bordo Bulamacı (Bakır) Koruması',
          aciklama: 'Hasat sonrası ve ilkbahar öncesi mantari hastalıklara karşı koruyucu bakır uygulaması.',
          oncelik: 'Önemli',
          ikon: '🛡️',
        ),
      ],
    );
  }

  static FenolojikEvreSonuc _hesaplaUzum(DateTime now) {
    final ay = now.month;
    final (gecen, hasat) = _hasataGore(now, 8, 10);
    return FenolojikEvreSonuc(
      evreAdi: ay <= 3 ? 'Kış Budaması' : (ay <= 6 ? 'Sürgün & Koruk' : (ay <= 9 ? 'Ben Düşme & Olgunlaşma' : 'Bağ Bozumu')),
      evreAciklama: 'Asma omcalarının yıllık meyve ve şeker bağlama periyodu (bağ bozumu Ağustos-Ekim).',
      ilerlemeYuzdesi: (ay / 12).clamp(0.0, 1.0),
      gecenGun: gecen,
      tahminiHasatGunu: hasat,
      yapilacakIsler: [
        const TarimsalIslem(
          baslik: 'Külleme & Mildiyö Mücadelesi',
          aciklama: 'Salkımlara kükürt ve sistemik fungusit koruması.',
          oncelik: 'Acil',
          ikon: '🍇',
        ),
      ],
    );
  }

  /// Evre sınırlarına göre (gün) basit tek yıllık takvim.
  static FenolojikEvreSonuc _evreler(
    int gun,
    int hasatGunu,
    List<(int bitisGunu, String ad, String aciklama, List<TarimsalIslem> isler)> evreler,
  ) {
    final e = evreler.firstWhere((e) => gun <= e.$1, orElse: () => evreler.last);
    return FenolojikEvreSonuc(
      evreAdi: e.$2,
      evreAciklama: e.$3,
      ilerlemeYuzdesi: (gun / hasatGunu).clamp(0.0, 1.0),
      gecenGun: gun,
      tahminiHasatGunu: hasatGunu,
      yapilacakIsler: e.$4,
    );
  }

  static FenolojikEvreSonuc _hesaplaSoya(int gun) => _evreler(gun, 125, [
        (35, 'Çıkış & Vejetatif Gelişme (V)', 'Yapraklar açılıyor; köklerde azot bağlayan nodüller oluşuyor.', const [
          TarimsalIslem(baslik: 'Yabancı Ot Mücadelesi', aciklama: 'Sıralar kapanana kadar çapa ya da çıkış sonrası herbisit.', oncelik: 'Acil', ikon: '🧪'),
          TarimsalIslem(baslik: 'Nodül Kontrolü', aciklama: 'Birkaç bitki söküp köklerde pembe içli nodül var mı bakın; yoksa azot eksikliği sararması görülür.', oncelik: 'Önemli', ikon: '🌱'),
        ]),
        (80, 'Çiçeklenme & Bakla Bağlama (R1-R4)', 'Verimin belirlendiği dönem; su ve sıcak stresine hassas.', const [
          TarimsalIslem(baslik: 'Düzenli Sulama', aciklama: 'Çiçek ve bakla döneminde susuzluk çiçek ve bakla dökümü yapar.', oncelik: 'Acil', ikon: '💧'),
          TarimsalIslem(baslik: 'Kırmızı Örümcek Takibi', aciklama: 'Sıcak-kuru havada yaprak altlarında örümcek ağı ve sararma görülürse akarisit.', oncelik: 'Yüksek', ikon: '🕷️'),
        ]),
        (125, 'Dane Dolumu & Hasat (R5-R8)', 'Baklalar doluyor, yapraklar sararıp dökülüyor.', const [
          TarimsalIslem(baslik: 'Hasat Zamanı', aciklama: 'Baklaların %95\'i kahverengileşince, dane nemi %13-14 civarında biçerdöverle hasat edin.', oncelik: 'Acil', ikon: '🚜'),
        ]),
      ]);

  static FenolojikEvreSonuc _hesaplaPancar(int gun) => _evreler(gun, 180, [
        (40, 'Çıkış & Seyreltme', 'Fideler 4-6 yapraklı; tarla boşluğu ve ot rekabeti verimi belirler.', const [
          TarimsalIslem(baslik: 'Çapa & Yabancı Ot', aciklama: 'Pancar ota karşı çok zayıftır; çıkış sonrası herbisit ve ara çapa zamanında yapılmalı.', oncelik: 'Acil', ikon: '🧪'),
          TarimsalIslem(baslik: 'Pancar Piresi Takibi', aciklama: 'Kotiledon döneminde yapraklarda delikler görülürse ilaçlama.', oncelik: 'Yüksek', ikon: '🐛'),
        ]),
        (110, 'Yaprak Gelişimi & Kök Büyümesi', 'Yapraklar sıraları kapatıyor, kök hızla kalınlaşıyor; su ihtiyacı en yüksek dönem.', const [
          TarimsalIslem(baslik: 'Düzenli Sulama', aciklama: 'Yaz sıcağında su stresi kök verimini düşürür; yağmurlama/damla ile düzenli sulayın.', oncelik: 'Acil', ikon: '💧'),
          TarimsalIslem(baslik: 'Cercospora Yaprak Lekesi', aciklama: 'Sıcak-nemli havada yapraklarda kahverengi lekeler çıkarsa fungusit uygulayın.', oncelik: 'Yüksek', ikon: '🛡️'),
          TarimsalIslem(baslik: 'Geç Azottan Kaçının', aciklama: 'Haziran ortasından sonra verilen azot şeker oranını düşürür.', oncelik: 'Önemli', ikon: '⚠️'),
        ]),
        (180, 'Şeker Birikimi & Söküm', 'Kökte şeker birikiyor; söküm fabrikanın programına göre yapılır.', const [
          TarimsalIslem(baslik: 'Sulamayı Kesin', aciklama: 'Sökümden 3-4 hafta önce sulamayı keserek şeker oranını artırın.', oncelik: 'Önemli', ikon: '🚱'),
          TarimsalIslem(baslik: 'Söküm & Teslim', aciklama: 'Sökülen pancarı güneşte bekletmeden, toprağı silkelenmiş olarak teslim edin.', oncelik: 'Acil', ikon: '🚜'),
        ]),
      ]);

  static FenolojikEvreSonuc _hesaplaNohut(int gun) => _evreler(gun, 100, [
        (35, 'Çıkış & Dallanma', 'Bitki yan dallar oluşturuyor; yavaş geliştiği için ot rekabetine açık.', const [
          TarimsalIslem(baslik: 'Yabancı Ot Mücadelesi', aciklama: 'Nohut ota karşı zayıftır; çıkış öncesi herbisit ya da erken çapa.', oncelik: 'Acil', ikon: '🧪'),
        ]),
        (70, 'Çiçeklenme & Bakla Bağlama', 'Verim bu dönemde belirlenir; yağışlı-serin hava hastalık riskini artırır.', const [
          TarimsalIslem(baslik: 'Antraknoz (Ascochyta) Kontrolü', aciklama: 'Yaprak, sap ve baklada halkalı lekeler görülürse hemen fungusit; dayanıklı çeşit tercih edin.', oncelik: 'Kritik', ikon: '🛡️'),
          TarimsalIslem(baslik: 'Bakla Kurdu Takibi', aciklama: 'Baklalarda delik ve kurt görülürse insektisit uygulayın.', oncelik: 'Yüksek', ikon: '🐛'),
        ]),
        (100, 'Dane Dolumu & Hasat', 'Bitki sararıp kuruyor; daneler sertleşiyor.', const [
          TarimsalIslem(baslik: 'Zamanında Hasat', aciklama: 'Bitkilerin çoğu sarardığında, dane dökülmesini önlemek için sabah serinliğinde hasat edin.', oncelik: 'Acil', ikon: '🚜'),
        ]),
      ]);

  static FenolojikEvreSonuc _hesaplaMercimek(int gun) => _evreler(gun, 110, [
        (40, 'Çıkış & Vejetatif Gelişme', 'Kısa boylu bitki toprağı geç kapatır; ot rekabeti verimi ciddi düşürür.', const [
          TarimsalIslem(baslik: 'Yabancı Ot Kontrolü', aciklama: 'Erken dönemde herbisit ya da çapa ile tarlayı temiz tutun.', oncelik: 'Acil', ikon: '🧪'),
          TarimsalIslem(baslik: 'Sitona & Yaprak Biti Takibi', aciklama: 'Yaprak kenarlarında yarım ay şeklinde yenikler ya da yoğun bit görülürse ilaçlama.', oncelik: 'Önemli', ikon: '🐞'),
        ]),
        (80, 'Çiçeklenme & Bakla Bağlama', 'Çiçek ve bakla oluşumu; kuraklık bu dönemde verimi en çok etkiler.', const [
          TarimsalIslem(baslik: 'Bakla Dökümüne Dikkat', aciklama: 'Sulama imkânı varsa çiçeklenmede bir can suyu verimi belirgin artırır.', oncelik: 'Yüksek', ikon: '💧'),
        ]),
        (110, 'Olgunlaşma & Hasat', 'Alt baklalar kahverengileşiyor.', const [
          TarimsalIslem(baslik: 'Erken Sabah Hasadı', aciklama: 'Baklaların çoğu kahverengileşince, dökülme kaybını azaltmak için çiyli sabah saatlerinde hasat edin.', oncelik: 'Acil', ikon: '🚜'),
        ]),
      ]);

  static FenolojikEvreSonuc _hesaplaPatates(int gun) => _evreler(gun, 120, [
        (30, 'Çıkış & Boğaz Doldurma', 'Sürgünler çıktı; yumrular toprak altında oluşmaya başlayacak.', const [
          TarimsalIslem(baslik: 'Boğaz Doldurma', aciklama: 'Yumruların güneşte yeşillenmemesi için sıraların dibine toprak çekin.', oncelik: 'Acil', ikon: '⛏️'),
          TarimsalIslem(baslik: 'Patates Böceği Takibi', aciklama: 'Yapraklarda turuncu larvalar görülünce erken dönemde ilaçlayın.', oncelik: 'Yüksek', ikon: '🐞'),
        ]),
        (70, 'Yumru Bağlama & Çiçeklenme', 'Yumru sayısı bu dönemde belirlenir; suya en hassas evre.', const [
          TarimsalIslem(baslik: 'Düzenli Sulama', aciklama: 'Su stresi yumru bağlamayı ve iriliği düşürür; toprağı sürekli nemli tutun.', oncelik: 'Acil', ikon: '💧'),
          TarimsalIslem(baslik: 'Mildiyö (Geç Yanıklık)', aciklama: 'Serin ve nemli havada yapraklarda yağlı lekeler: koruyucu fungusiti aksatmayın.', oncelik: 'Kritik', ikon: '🛡️'),
        ]),
        (120, 'Yumru İrileşmesi & Hasat', 'Yapraklar sararıyor; yumru kabuğu sertleşiyor.', const [
          TarimsalIslem(baslik: 'Sap Kurutma & Hasat', aciklama: 'Hasattan 2-3 hafta önce sapları kurutun (kabuk sertleşir); sökümde yumruları yaralamayın.', oncelik: 'Önemli', ikon: '🚜'),
        ]),
      ]);

  static FenolojikEvreSonuc _hesaplaFasulye(int gun) => _evreler(gun, 100, [
        (30, 'Çıkış & Fide', 'Fideler dona ve kaymak tabakasına hassas.', const [
          TarimsalIslem(baslik: 'Kaymak Kırma & Çapa', aciklama: 'Yağmur sonrası oluşan kaymak tabakası çıkışı engeller; hafifçe kırın, otları çapalayın.', oncelik: 'Yüksek', ikon: '⛏️'),
        ]),
        (60, 'Çiçeklenme & Bakla', 'Çiçek ve bakla tutumu; sıcak ve su stresine en hassas dönem.', const [
          TarimsalIslem(baslik: 'Çiçeklenmede Sulama', aciklama: 'Su stresi ve 30°C üstü sıcak çiçek döktürür; sulamayı aksatmayın.', oncelik: 'Acil', ikon: '💧'),
          TarimsalIslem(baslik: 'Kırmızı Örümcek & Yaprak Biti', aciklama: 'Yaprak altlarını kontrol edin; yoğunlukta akarisit/insektisit.', oncelik: 'Yüksek', ikon: '🕷️'),
        ]),
        (100, 'Dane Dolumu & Hasat', 'Baklalar sararıp kuruyor.', const [
          TarimsalIslem(baslik: 'Söküm & Harman', aciklama: 'Baklaların çoğu kuruyunca sabah serinliğinde sökün, dökülmeden harman yapın.', oncelik: 'Acil', ikon: '🚜'),
        ]),
      ]);

  static FenolojikEvreSonuc _hesaplaYonca(DateTime now) {
    final ay = now.month;
    final (gecen, hasat) = _hasataGore(now, 5, 9);
    final (evre, isler) = ay <= 2 || ay >= 11
        ? ('Kış Dinlenmesi', const [
            TarimsalIslem(baslik: 'Fosfor & Potas Gübrelemesi', aciklama: 'Kış başı ya da erken ilkbaharda fosforlu-potaslı gübre verin; yonca azotu kendisi bağlar.', oncelik: 'Önemli', ikon: '🌿'),
            TarimsalIslem(baslik: 'Kışın Otlatmayın', aciklama: 'Kışın tarlaya hayvan sokmak kök boğazına zarar verir.', oncelik: 'Önemli', ikon: '🚫'),
          ])
        : ay <= 4
            ? ('İlkbahar Sürgünü', const [
                TarimsalIslem(baslik: 'Yonca Hortumlu Böceği', aciklama: 'Sürgün uçlarında larva yenikleri görülürse ilk biçimden önce ilaçlayın.', oncelik: 'Kritik', ikon: '🐛'),
              ])
            : ay <= 9
                ? ('Biçim Dönemi', const [
                    TarimsalIslem(baslik: '%10 Çiçekte Biçin', aciklama: 'Verim ve kalite dengesi için tarlada ilk çiçekler görülünce biçin; biçimler arası ~30-35 gün.', oncelik: 'Acil', ikon: '🚜'),
                    TarimsalIslem(baslik: 'Biçim Sonrası Sulama', aciklama: 'Her biçimden sonra sulayarak yeni sürgünü hızlandırın.', oncelik: 'Yüksek', ikon: '💧'),
                  ])
                : ('Son Biçim & Kışa Hazırlık', const [
                    TarimsalIslem(baslik: 'Geç Biçimden Kaçının', aciklama: 'Kökte kış rezervi birikmesi için son biçimi ilk dondan 4-6 hafta önce bitirin.', oncelik: 'Önemli', ikon: '⚠️'),
                  ]);
    return FenolojikEvreSonuc(
      evreAdi: evre,
      evreAciklama: 'Çok yıllık yonca; sulu şartlarda Mayıs-Eylül arası yılda 4-6 biçim.',
      ilerlemeYuzdesi: (ay / 12).clamp(0.0, 1.0),
      gecenGun: gecen,
      tahminiHasatGunu: hasat,
      yapilacakIsler: isler,
    );
  }

  static FenolojikEvreSonuc _hesaplaGenel(int gun) {
    return FenolojikEvreSonuc(
      evreAdi: gun < 40 ? 'Erken Vejetatif Dönem' : (gun < 90 ? 'Gelişme & Çiçeklenme' : 'Olgunlaşma & Hasat'),
      evreAciklama: 'Standart ürün gelişim takvimi.',
      ilerlemeYuzdesi: (gun / 120).clamp(0.0, 1.0),
      gecenGun: gun,
      tahminiHasatGunu: 120,
      yapilacakIsler: [
        const TarimsalIslem(
          baslik: 'Periyodik Tarla Gözlemi & Nem Takibi',
          aciklama: 'Toprak nemini ve yaprak altı zararlılarını düzenli kontrol edin.',
          oncelik: 'Önemli',
          ikon: '🌾',
        ),
      ],
    );
  }
}

class FenolojikEvreSonuc {
  final String evreAdi;
  final String evreAciklama;
  final double ilerlemeYuzdesi; // 0.0 .. 1.0
  final int gecenGun;
  final int tahminiHasatGunu;
  final List<TarimsalIslem> yapilacakIsler;

  const FenolojikEvreSonuc({
    required this.evreAdi,
    required this.evreAciklama,
    required this.ilerlemeYuzdesi,
    required this.gecenGun,
    required this.tahminiHasatGunu,
    required this.yapilacakIsler,
  });

  int get kalanGun => (tahminiHasatGunu - gecenGun).clamp(0, 365);
}

class TarimsalIslem {
  final String baslik;
  final String aciklama;
  final String oncelik; // 'Kritik', 'Acil', 'Yüksek', 'Önemli', 'Orta'
  final String ikon;

  const TarimsalIslem({
    required this.baslik,
    required this.aciklama,
    required this.oncelik,
    required this.ikon,
  });
}
