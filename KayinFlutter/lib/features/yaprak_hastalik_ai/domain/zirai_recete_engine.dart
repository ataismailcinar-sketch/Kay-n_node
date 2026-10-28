/// Hastalık/zararlı bilgi rehberi: belirtiler, kültürel önlemler, mücadele zamanı ve
/// hangi etki gruplarının kullanıldığı.
///
/// BİLİNÇLİ OLARAK YOK: ticari ürün adı, doz ve hasat öncesi bekleme süresi.
/// Türkiye'de bitki koruma ürünleri ürün + bitki + hastalık bazında ruhsatlanır; aynı
/// etken madde her bitkide/hastalıkta ruhsatlı değildir, doz ve bekleme süresi ürüne
/// göre değişir ve ruhsatlar zamanla iptal edilir. Uygulamanın bunları sabit liste
/// olarak vermesi yanlış (hatta yasaklı) ürün kullanımına yol açabilir. Bu bilgiler
/// ürün etiketinden ve ziraat mühendisi reçetesinden alınmalıdır ([yasalUyari]).
class ZiraiReceteEngine {
  /// Her reçete ekranında gösterilen uyarı.
  static const String yasalUyari =
      'Hangi ürünün kullanılacağına, doza ve hasattan önce kaç gün beklenmesi gerektiğine '
      'ürün etiketi ve ziraat mühendisi reçetesi karar verir. Bitki koruma ürünleri bitki ve '
      'hastalık bazında ruhsatlıdır; ruhsatlı ürünü il/ilçe tarım müdürlüğünden veya Tarım ve '
      'Orman Bakanlığı\'nın bitki koruma ürünleri ruhsat sorgulamasından öğrenin.';

  /// Tüm ilaçlı reçetelerde geçerli genel kural.
  static const String direncNotu =
      'Aynı etki grubundan ürünü arka arkaya kullanmayın; gruplar sırayla değiştirilmezse '
      'hastalık/zararlı ilaca direnç kazanır.';

  static final List<ZiraiRecete> tumReceteler = [
    // ═══════════════════════════════════════════════════════════════════════════
    // 1. HUBUBAT (BUĞDAY, ARPA, ÇAVDAR, YULAF) HASTALIK VE ZARARLILARI
    // ═══════════════════════════════════════════════════════════════════════════
    const ZiraiRecete(
      hastalikAdi: 'Sarı Pas & Kahverengi Pas (Puccinia spp.)',
      anahtarKelimeler: ['Sarı Pas', 'Kahverengi Pas', 'Kara Pas', 'Pas Hastalığı', 'Puccinia'],
      latinceAdi: 'Puccinia striiformis / Puccinia recondita',
      hedefUrunler: 'Buğday, Arpa, Çavdar',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Yüksek (Epidemi Riski)',
      aciklama: 'Yapraklarda sarı-turuncu şerit püstüller oluşur. Fotosentezi durdurarak danenin cılız kalmasına ve %40-60 verim kaybına yol açar.',
      mucadeleGruplari: [
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
        'SDHI grubu fungisitler (çoğunlukla karışım ürünlerde)',
      ],
      uygulamaZamani: 'Kardeşlenme sonu - bayrak yaprak çıkışında yaprakta ilk pas püstülleri görüldüğünde, sabah serinliğinde veya akşamüstü rüzgarsız havada.',
      kulturelOnlemler: [
        'Aşırı azotlu gübrelemeden kaçının (aşırı azot yaprak dokusunu yumuşatarak pasa davetiye çıkarır).',
        'Sertifikalı ve pasa dayanıklı yerli tohum çeşitlerini tercih edin.',
        'Sık ekimden kaçınarak tarlanın havalanmasını sağlayın.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Hububat Küllemesi (Blumeria graminis)',
      anahtarKelimeler: ['Hububat Küllemesi', 'Buğday Küllemesi', 'Külleme Hastalığı', 'Erysiphe'],
      latinceAdi: 'Blumeria graminis f. sp. tritici',
      hedefUrunler: 'Buğday, Arpa',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek',
      aciklama: 'Sap ve yaprak altlarında un serpilmiş gibi beyaz-gri pamuksu mantar tabakası oluşur. Yaprakların erken kurumasına neden olur.',
      mucadeleGruplari: [
        'Kükürtlü preparatlar (koruyucu)',
        'Triazol grubu fungisitler (DMI)',
        'Küllemeye özgü sistemik fungisitler',
      ],
      uygulamaZamani: 'Sapa kalkma evresinde, hava 15-20°C iken alt yapraklarda ilk beyaz püstüller görüldüğünde.',
      kulturelOnlemler: [
        'Sık ekimden kaçının, dengeli fosfor ve potasyum gübrelemesi yapın.',
        'Ekim nöbetine özen gösterin.',
      ],
      dikkatNotu: 'Kükürtlü ürünler 30°C üzerinde yaprağı yakar; sıcak saatlerde uygulanmaz.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Septorya Yaprak Lekesi (Septoria tritici)',
      anahtarKelimeler: ['Septorya', 'Septoria', 'Yaprak Lekesi', 'Erken Yaprak Lekesi'],
      latinceAdi: 'Zymoseptoria tritici / Septoria nodorum',
      hedefUrunler: 'Buğday, Çavdar, Triticale',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Yüksek (Yağışlı Baharlarda)',
      aciklama: 'Damarlar arasında sınırlandırılmış sarı-kahverengi dikdörtgen lekeler ve içinde siyah piknit noktacıkları oluşur. Bayrak yaprağı sarartarak rekolteyi düşürür.',
      mucadeleGruplari: [
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
        'Çok yönlü etkili koruyucu fungisitler',
      ],
      uygulamaZamani: 'İlkbaharda yağışlı dönem sonrası, hastalık alt yapraklardan üst yapraklara geçmeden hemen önce.',
      kulturelOnlemler: [
        'Anız yakılmamalı, anız derin sürümle toprağa gömülmelidir.',
        'Hassas buğday çeşitlerinin yerine dirençli tohumlar ekilmelidir.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Kök ve Kök Boğazı Çürüklüğü (Fusarium / Rhizoctonia)',
      anahtarKelimeler: ['Kök Boğazı', 'Kök Çürüklüğü', 'Fusarium', 'Pseudocercosporella', 'Göz Lekesi'],
      latinceAdi: 'Fusarium culmorum / Pseudocercosporella herpotrichoides',
      hedefUrunler: 'Buğday, Arpa, Mısır',
      kategori: 'Toprak kökenli fungal hastalık',
      tehlikeSeviyesi: 'Yüksek (Yatmaya Neden Olur)',
      aciklama: 'Kök boğazında bal peteği veya göz şeklinde koyu kahve lekelenme yapar, iletim demetlerini tıkayarak beyaz başak ve erken yatma meydana getirir.',
      mucadeleGruplari: [
        'Fungisitli tohum ilaçları (ekim öncesi, en etkili yol)',
        'Triazol grubu fungisitler (yeşil aksam, kök boğazına)',
      ],
      uygulamaZamani: 'Esas mücadele ekimden önce tohum ilaçlamasıdır. Yeşil aksam uygulaması kardeşlenme sonu - sapa kalkma başında, ilacın kök boğazına ulaşacağı şekilde yapılır.',
      kulturelOnlemler: [
        'Ekimden önce tohum mutlaka sistemik tohum ilacı ile ilaçlanmalıdır.',
        'Ağır killi ve su tutan arazilerde drenaj kanalları açılmalıdır.',
        'Üst üste buğday ekiminden (monokültür) kaçınılmalıdır.',
      ],
      dikkatNotu: 'Sertifikalı (ilaçlı) tohum kullanmak sonradan ilaçlamaktan çok daha etkilidir.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Süne & Kımıl Zararlısı (Eurygaster / Aelia)',
      anahtarKelimeler: ['Süne', 'Kımıl', 'Eurygaster', 'Süne Zararlısı'],
      latinceAdi: 'Eurygaster integriceps / Aelia rostrata',
      hedefUrunler: 'Buğday, Arpa',
      kategori: 'Zararlı böcek',
      tehlikeSeviyesi: 'Kritik (Ekmeklik Kaliteyi Sıfırlar)',
      aciklama: 'Emgi yaparak başakta akbaşak oluşturur ve danede gluten yapısını bozarak unun kabarmasını (ekmeklik değerini) tamamen yok eder.',
      mucadeleGruplari: [
        'Piretroit grubu insektisitler',
      ],
      uygulamaZamani: 'Metrekarede ortalama 10 ve üzeri 1-3. dönem nimf tespit edildiğinde, ilçe tarım müdürlüğünün duyurusuyla.',
      kulturelOnlemler: [
        'Toplu köy/havza bazlı mücadele esastır.',
        'Doğal parazitoitlerin (Trissolcus spp.) korunması için faydalı böcek popülasyonu gözetilmelidir.',
      ],
      dikkatNotu: 'Süne mücadelesi eşik değere göre ve bölge genelinde yürütülür; ilçe tarım müdürlüğünün duyurusunu bekleyin.',
    ),

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. MISIR HASTALIK VE ZARARLILARI
    // ═══════════════════════════════════════════════════════════════════════════
    const ZiraiRecete(
      hastalikAdi: 'Mısır Koçan Kurdu & Çizgili Koçan Kurdu',
      anahtarKelimeler: ['Mısır Kurdu', 'Koçan Kurdu', 'Sesamia', 'Helicoverpa', 'Ostrinia'],
      latinceAdi: 'Helicoverpa armigera / Sesamia nonagrioides / Ostrinia nubilalis',
      hedefUrunler: 'Mısır (Dane ve Silajlık)',
      kategori: 'Zararlı böcek (tırtıl)',
      tehlikeSeviyesi: 'Çok Yüksek',
      aciklama: 'Gövde ve koçan içine girerek tünel açar, bitkiyi kırar ve daneleri yiyerek mikotoksin (aflatoksin) oluşumuna yol açar.',
      mucadeleGruplari: [
        'Diamid grubu insektisitler',
        'Avermektin türevi insektisitler',
        'Biyolojik: Bacillus thuringiensis (Bt) preparatları',
      ],
      uygulamaZamani: 'İlk yumurta açılımları görüldüğünde, tepe püskülü çıkmadan önce; larva gövdeye girdikten sonra ilaç etkisi düşer.',
      kulturelOnlemler: [
        'Hasat sonrası mısır sapları parçalanıp derine gömülmelidir.',
        'Erkenci çeşit ekimi zararlı popülasyonundan kaçınmayı sağlar.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Mısır Yaprak Yanıklığı (Helminthosporium / Turcicum)',
      anahtarKelimeler: ['Mısır Yaprak Yanıklığı', 'Helminthosporium', 'Exserohilum'],
      latinceAdi: 'Exserohilum turcicum / Bipolaris maydis',
      hedefUrunler: 'Mısır',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek',
      aciklama: 'Yapraklarda mekik / puro şeklinde büyük gri-kahverengi nekrotik lekeler oluşur, fotosentezi keserek erken kurumaya yol açar.',
      mucadeleGruplari: [
        'Strobilurin + Triazol karışımı fungisitler',
        'Strobilurin grubu fungisitler (QoI)',
      ],
      uygulamaZamani: 'İlk belirtiler alt yapraklarda görüldüğünde, 8-10 yaprak evresinde.',
      kulturelOnlemler: ['Dayanıklı hibrit tohum kullanımı en kesin çözümdür.'],
      dikkatNotu: 'Sıcak havalarda öğle saatlerinde ilaçlama yapılmamalıdır.',
    ),

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. AYÇİÇEĞİ HASTALIKLARI
    // ═══════════════════════════════════════════════════════════════════════════
    const ZiraiRecete(
      hastalikAdi: 'Ayçiçeği Mildiyösü & Köken Çürüklüğü (Plasmopara)',
      anahtarKelimeler: ['Ayçiçeği Mildiyö', 'Plasmopara halstedii', 'Ayçiçeği Hastalığı'],
      latinceAdi: 'Plasmopara halstedii / Sclerotinia sclerotiorum',
      hedefUrunler: 'Ayçiçeği',
      kategori: 'Oomiset (mildiyö) ve fungal hastalık',
      tehlikeSeviyesi: 'Kritik',
      aciklama: 'Bodurlaşma, yaprak damarları boyunca sararma ve yaprak altında beyaz küf tabakası oluşturur; tabla bağlamasını engeller.',
      mucadeleGruplari: [
        'Fenilamid grubu tohum ilaçları (ekim öncesi)',
        'Strobilurin grubu fungisitler (QoI)',
      ],
      uygulamaZamani: 'Esas mücadele ekim öncesi tohum ilaçlamasıdır; gerekirse 6-8 yaprak evresinde koruyucu uygulama.',
      kulturelOnlemler: [
        'Mildiyöye dayanıklı tohum çeşitleri tercih edilmelidir.',
        'Toprakta taban suyu birikmesi önlenmelidir.',
      ],
      dikkatNotu: 'Ot ilacıyla aynı tanka karıştırmadan önce iki ürünün etiketinde karışabilirlik bilgisine bakın.',
    ),

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. SEBZE (DOMATES, BİBER, PATLICAN, PATATES) HASTALIKLARI
    // ═══════════════════════════════════════════════════════════════════════════
    const ZiraiRecete(
      hastalikAdi: 'Domates Mildiyösü / Geç Yanıklık (Phytophthora infestans)',
      anahtarKelimeler: ['Mildiyö', 'Domates Mildiyö', 'Yaprak Yanıklığı', 'Phytophthora', 'Geç Yanıklık'],
      latinceAdi: 'Phytophthora infestans',
      hedefUrunler: 'Domates, Patates, Patlıcan',
      kategori: 'Oomiset (mildiyö) hastalığı',
      tehlikeSeviyesi: 'Acil / Yıkıcı (48 Saatte Tarlayı Kurutur)',
      aciklama: 'Yapraklarda yağ lekesi gibi sulu kahverengi lekeler başlar, yaprak altına beyaz küf örer ve meyveleri kahverengileştirip çürütür.',
      mucadeleGruplari: [
        'Fenilamid grubu sistemik fungisitler (karışım ürünlerde)',
        'Karboksilik asit amid (CAA) grubu fungisitler',
        'Koruyucu (kontakt) fungisitler',
        'Bakırlı preparatlar',
      ],
      uygulamaZamani: 'Hava 16-22°C ve oransal nem %80 üzerine çıktığında koruyucu olarak veya ilk lekede derhal.',
      kulturelOnlemler: [
        'Yağmurlama sulamayı kesin, damlama sulama kullanın.',
        'Hava sirkülasyonu için alt etek yapraklarını budayın (koltuk alma).',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Erken Yanıklık (Alternaria solani)',
      anahtarKelimeler: ['Alternaria', 'Erken Yanıklık', 'Hedef Lekesi', 'Erken Yaprak Lekesi'],
      latinceAdi: 'Alternaria solani',
      hedefUrunler: 'Domates, Patates, Biber',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek',
      aciklama: 'Yapraklarda konsantrik halkalı (hedef tahtası şeklinde) koyu kahve-siyah lekeler oluşur. Yaşlı yapraklardan başlayarak yaprak dökülmesine yol açar.',
      mucadeleGruplari: [
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
        'Koruyucu (kontakt) fungisitler',
      ],
      uygulamaZamani: 'Fidelikte veya tarlada ilk lekeler görüldüğünde başlanır; tekrar aralığı ürün etiketine göre belirlenir.',
      kulturelOnlemler: [
        'Ekim nöbeti uygulayın, patlıcangiller (domates, biber, patates) ardı ardına ekilmemelidir.',
        'Bitkiyi potasyumlu ve kalsiyumlu gübrelerle besleyerek dokuyu güçlendirin.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Domates Güvesi (Tuta Absoluta Zararlısı)',
      anahtarKelimeler: ['Tuta', 'Tuta Absoluta', 'Domates Güvesi', 'Yaprak Galeri Güvesi'],
      latinceAdi: 'Tuta absoluta',
      hedefUrunler: 'Domates, Biber, Patlıcan',
      kategori: 'Zararlı böcek (güve)',
      tehlikeSeviyesi: 'Kritik (%100 Ürün Kaybı Riski)',
      aciklama: 'Larvalar yaprak dokusunda geniş galeriler açar; sap, çiçek ve meyveye girerek ürünü pazarlanamaz hale getirir.',
      mucadeleGruplari: [
        'Diamid grubu insektisitler',
        'Spinosin grubu insektisitler',
        'Avermektin türevi insektisitler',
        'Biyolojik: Bacillus thuringiensis (Bt) preparatları',
      ],
      uygulamaZamani: 'Feromon tuzaklarında haftalık 20-30 ergin yakalandığında veya ilk galeri/yumurta görüldüğünde.',
      kulturelOnlemler: [
        'Seralarda tül (50 mesh) kullanımı ve feromon su tuzakları zorunludur.',
        'Bulaşık bitki artıkları derhal toplanıp yakılmalı veya gömülmelidir.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Kırmızı Örümcek & Akar Zararlısı (Tetranychus spp.)',
      anahtarKelimeler: ['Kırmızı Örümcek', 'Akar', 'Tetranychus', 'Sarı Leke'],
      latinceAdi: 'Tetranychus urticae / Tetranychus cinnabarinus',
      hedefUrunler: 'Pamuk, Domates, Biber, Hıyar, Çilek, Meyve',
      kategori: 'Zararlı akar',
      tehlikeSeviyesi: 'Yüksek (Sıcak/Kurak Dönemde Patlar)',
      aciklama: 'Yaprak altlarında bitki özsuyunu emer, yaprak üstünde gümüşi/sarı noktacıklar ve yoğun ağ örerek kurutur.',
      mucadeleGruplari: [
        'Akarisitler: ergin etkili gruplar',
        'Akarisitler: yumurta ve larva etkili gruplar',
      ],
      uygulamaZamani: 'Yaprak başına ortalama 3-5 canlı akar görüldüğünde, yaprak altlarını tamamen ıslatacak şekilde.',
      kulturelOnlemler: [
        'Tarla kenarındaki yabancı otlar temizlenmelidir.',
        'Aşırı tozlanma örümceği artırdığından tarla içi yollar ıslatılmalıdır.',
      ],
      dikkatNotu: 'Akarlar ilaca çok hızlı direnç kazanır; aynı gruptan ürünü sezonda bir kezden fazla kullanmamaya çalışın.',
    ),

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. ZEYTİN HASTALIK VE ZARARLILARI
    // ═══════════════════════════════════════════════════════════════════════════
    const ZiraiRecete(
      hastalikAdi: 'Zeytin Halkalı Leke (Spilocaea oleagina)',
      anahtarKelimeler: ['Halkalı Leke', 'Zeytin Lekesi', 'Spilocaea', 'Zeytin Halkalı Leke'],
      latinceAdi: 'Spilocaea oleagina (Venturia oleaginea)',
      hedefUrunler: 'Zeytin',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Yüksek (Yaprak Döker, Verim Sıfırlar)',
      aciklama: 'Yaprakların üst yüzeyinde iç içe geçmiş koyu gri-kahverengi halkalar oluşur. Yaprakların dökülmesine ve ağacın çıplak kalmasına yol açar.',
      mucadeleGruplari: [
        'Bakırlı preparatlar (bordo bulamacı dahil)',
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
      ],
      uygulamaZamani: 'Sonbaharda sürgünler dinlenmeye girmeden önce (Ekim-Kasım) ve ilkbaharda çiçek salkımları belirmeden önce (Şubat-Mart).',
      kulturelOnlemler: [
        'İç budama yapılarak ağaç tacının hava ve ışık alması sağlanmalıdır.',
        'Taban ve nemli arazilere dikimden kaçınılmalıdır.',
      ],
      dikkatNotu: 'Bakırlı ürünler bazı ürünlerle (ör. kükürtlü) karıştırılamaz; karıştırmadan önce etikete bakın.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Zeytin Sineği Zararlısı (Bactrocera oleae)',
      anahtarKelimeler: ['Zeytin Sineği', 'Bactrocera', 'Vuruk', 'Zeytin Kurdu'],
      latinceAdi: 'Bactrocera oleae',
      hedefUrunler: 'Zeytin (Sofralık ve Yağlık)',
      kategori: 'Zararlı böcek (sinek)',
      tehlikeSeviyesi: 'Çok Yüksek (Asitliği Yükseltir, Kurtlandırır)',
      aciklama: 'Dişi sinek yumurtasını zeytin meyvesi etine bırakır (vuruk). Çıkan larva meyve etini yer, meyve dökülmesine ve yağ asitliğinin yükselmesine neden olur.',
      mucadeleGruplari: [
        'Zehirli yem ile kısmi dal uygulaması (spinosin içerikli yemler)',
        'Kitle yakalama tuzakları',
        'Kaolin kili (fiziksel bariyer)',
        'Piretroit grubu insektisitler',
      ],
      uygulamaZamani: 'Meyveler yumurta koyma olgunluğuna eriştiğinde ve vuruk oranı eşiği aştığında (sofralıkta düşük, yağlıkta daha yüksek eşik).',
      kulturelOnlemler: [
        'Meyveler erken hasat edilerek sineğin zararından kurtarılmalıdır.',
        'Dökülen kurtlu zeytinler toplanıp yok edilmelidir.',
      ],
      dikkatNotu: 'Toplu (köy/bölge genelinde) mücadele başarıyı çok artırır.',
    ),

    // ═══════════════════════════════════════════════════════════════════════════
    // 6. BAĞ (ÜZÜM) HASTALIKLARI
    // ═══════════════════════════════════════════════════════════════════════════
    const ZiraiRecete(
      hastalikAdi: 'Bağ Küllemesi (Uncinula necator)',
      anahtarKelimeler: ['Bağ Küllemesi', 'Külleme', 'Uncinula', 'Bağ Mantarı'],
      latinceAdi: 'Uncinula necator (Erysiphe necator)',
      hedefUrunler: 'Bağ (Üzüm)',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Kritik (Tane Çatlatır, Şarabı Bozar)',
      aciklama: 'Sürgün, yaprak ve özellikle salkımlarda kül dökülmüş gibi beyaz toz tabakası yapar; taneleri çatlatır ve kurutur.',
      mucadeleGruplari: [
        'Kükürtlü preparatlar (koruyucu)',
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin / SDHI grubu fungisitler',
      ],
      uygulamaZamani: 'Sürgünler 25-30 cm olduğunda, çiçek taç yaprakları döküldüğünde (koruk evresi) ve tanelere ben düşme döneminde.',
      kulturelOnlemler: [
        'Yeşil budama (yaprak alma) ile salkımların havalanması sağlanmalıdır.',
        'Salkımların direkt güneş ışığı ve hava alması küllemeyi engeller.',
      ],
      dikkatNotu: 'Kükürtlü ürünler 30°C üzerinde kesinlikle uygulanmaz (yaprak ve tane yanığı).',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Bağ Mildiyösü (Plasmopara viticola)',
      anahtarKelimeler: ['Bağ Mildiyösü', 'Yağ Lekesi', 'Plasmopara'],
      latinceAdi: 'Plasmopara viticola',
      hedefUrunler: 'Bağ',
      kategori: 'Oomiset (mildiyö) hastalığı',
      tehlikeSeviyesi: 'Yüksek',
      aciklama: 'Yapraklarda şeffaf sarı "yağ lekesi" oluşur, nemli havada yaprak altında beyaz küf görülür; salkımları karartıp kurutur.',
      mucadeleGruplari: [
        'Bakırlı preparatlar',
        'Fenilamid grubu sistemik fungisitler (karışım ürünlerde)',
        'Koruyucu (kontakt) fungisitler',
      ],
      uygulamaZamani: 'İlkbaharda sürgünler 25-30 cm olunca ve 10-10-10 kuralı (10°C sıcaklık, 10 mm yağış, 10 cm sürgün) gerçekleştiğinde.',
      kulturelOnlemler: ['Toprağa değen alçak sürgünler budanmalıdır.'],
      dikkatNotu: 'Bakırlı ilaçlama çiçeklenme dönemine denk getirilmemelidir.',
    ),

    // ═══════════════════════════════════════════════════════════════════════════
    // 7. CİHAZDAKİ MODELİN TANIDIĞI DİĞER HASTALIKLAR (23.10.2026)
    //    Adlar YaprakEtiketEslestirici'deki teşhis adlarıyla aynıdır; değiştirilirse
    //    kayıtlı taramalar reçetesiz kalır.
    // ═══════════════════════════════════════════════════════════════════════════

    // ── Arpa ──
    const ZiraiRecete(
      hastalikAdi: 'Arpa Ağ Lekesi (Pyrenophora teres)',
      anahtarKelimeler: ['Ağ Leke', 'Ağ Lekesi', 'Pyrenophora', 'Helminthosporium teres'],
      latinceAdi: 'Pyrenophora teres (Drechslera teres)',
      hedefUrunler: 'Arpa',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek',
      aciklama: 'Yapraklarda kahverengi, içinde boyuna ve enine çizgilerle ağ görünümü veren lekeler ya da sarı haleli koyu noktalar oluşur. Üst yapraklara çıkarsa dane dolumunu zayıflatır.',
      mucadeleGruplari: [
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
        'SDHI grubu fungisitler (çoğunlukla karışım ürünlerde)',
        'Fungisitli tohum ilaçları (ekim öncesi)',
      ],
      uygulamaZamani: 'Sapa kalkma - bayrak yaprak evresinde lekeler üst yapraklara doğru ilerliyorsa. Hastalık tohum ve anızla taşındığı için esas korunma ekimden önce başlar.',
      kulturelOnlemler: [
        'Arpayı arpa üstüne ekmeyin; en az bir yıl başka ürünle ekim nöbeti yapın.',
        'Hastalıklı anızı derin sürümle toprağa gömün.',
        'Sertifikalı, ilaçlı tohum ve dayanıklı çeşit kullanın.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Arpa Yaprak Lekesi / Rinkosporyum (Rhynchosporium)',
      anahtarKelimeler: ['Rinkosporyum', 'Rhynchosporium', 'Yaprak Haşlanması', 'Arpa Yaprak Lekesi'],
      latinceAdi: 'Rhynchosporium commune (R. secalis)',
      hedefUrunler: 'Arpa, Çavdar',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek (Serin ve Yağışlı Baharlarda)',
      aciklama: 'Yaprak ve yaprak kınında önce gri-yeşil, sonra ortası açık renkli, kenarı koyu kahverengi çizgili haşlanmış görünümlü lekeler oluşur. Serin ve yağışlı havada hızla yayılır.',
      mucadeleGruplari: [
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
        'SDHI grubu fungisitler (çoğunlukla karışım ürünlerde)',
      ],
      uygulamaZamani: 'Kardeşlenme sonu - sapa kalkma döneminde, yağışlı serin günlerden sonra üst yapraklarda yeni lekeler görüldüğünde.',
      kulturelOnlemler: [
        'Anızı toprağa gömün ve gönüllü (kendiliğinden çıkan) arpaları temizleyin.',
        'Ekim nöbeti yapın; dayanıklı çeşit tercih edin.',
        'Çok erken ve sık ekimden kaçının.',
      ],
      dikkatNotu: direncNotu,
    ),

    // ── Ayçiçeği ──
    const ZiraiRecete(
      hastalikAdi: 'Ayçiçeği Küllemesi (Golovinomyces)',
      anahtarKelimeler: ['Ayçiçeği Küllemesi', 'Golovinomyces', 'Erysiphe cichoracearum'],
      latinceAdi: 'Golovinomyces cichoracearum',
      hedefUrunler: 'Ayçiçeği',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Düşük - Orta',
      aciklama: 'Yaprak üstünde beyaz-gri un serpilmiş gibi mantar tabakası oluşur, önce alt yapraklarda başlar. Genellikle sezon sonunda çıkar ve verime etkisi çoğu zaman sınırlıdır.',
      mucadeleGruplari: [
        'Kükürtlü preparatlar (koruyucu)',
        'Triazol grubu fungisitler (DMI)',
      ],
      uygulamaZamani: 'Yalnız tablalanma - çiçeklenme döneminde üst yapraklara hızla yayılıyorsa düşünülür; hasada yakın, alt yapraklarda kalan küllemede ilaçlama çoğu zaman ekonomik değildir.',
      kulturelOnlemler: [
        'Sık ekimden kaçının, dengeli gübreleyin (aşırı azot küllemeyi artırır).',
        'Hastalıklı bitki artıklarını hasattan sonra toprağa gömün.',
      ],
      dikkatNotu: 'Kükürtlü ürünler 30°C üzerinde yaprağı yakar; sıcak saatlerde uygulanmaz.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Ayçiçeği Alternarya Yaprak Lekesi',
      anahtarKelimeler: ['Ayçiçeği Alternarya', 'Alternaria helianthi'],
      latinceAdi: 'Alternaria helianthi / Alternaria spp.',
      hedefUrunler: 'Ayçiçeği',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta',
      aciklama: 'Yapraklarda sarı haleli, koyu kahverengi-siyah, bazen halkalı lekeler oluşur; lekeler birleşince yaprak kurur. Sıcak ve nemli havada sap ve tablaya da geçebilir.',
      mucadeleGruplari: [
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
      ],
      uygulamaZamani: 'Çiçeklenme öncesinde, sıcak-nemli havada lekeler alt yapraklardan orta yapraklara çıkmaya başladığında.',
      kulturelOnlemler: [
        'Ayçiçeğini aynı tarlaya üst üste ekmeyin (en az 3-4 yıl ara).',
        'Hastalıklı sap ve artıkları hasattan sonra toprağa gömün.',
        'Sertifikalı tohum kullanın.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Ayçiçeği Kurşuni Küf (Botrytis cinerea)',
      anahtarKelimeler: ['Kurşuni Küf', 'Botrytis', 'Gri Küf', 'Tabla Çürüklüğü'],
      latinceAdi: 'Botrytis cinerea',
      hedefUrunler: 'Ayçiçeği',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek (Yağışlı Hasat Döneminde)',
      aciklama: 'Yaprak, sap ve özellikle tablada kahverengi ıslak çürüklük ve üzerinde gri, tozlu küf tabakası oluşur. Tabla çürürse dane kaybı ve kalite düşüşü olur.',
      mucadeleGruplari: [
        'Kurşuni küfe etkili fungisitler (SDHI, anilinopirimidin grupları; ayçiçeğinde ruhsatlı olanlar)',
      ],
      uygulamaZamani: 'Çiçeklenme sonunda uzun süre nemli/yağışlı hava bekleniyorsa koruyucu olarak; tabla çürümeye başladıktan sonra ilacın etkisi azdır.',
      kulturelOnlemler: [
        'Sık ekimden kaçınarak tablaların havalanmasını sağlayın.',
        'Hasadı geciktirmeyin; yağışlı dönemde olgun tarlayı bekletmeyin.',
        'Hastalıklı tabla ve artıkları tarlada bırakmayın.',
      ],
      dikkatNotu: 'Ayçiçeğinde bu hastalığa ruhsatlı ürün sayısı azdır; ilaçlamadan önce mutlaka ruhsatı sorgulayın.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Solgun Yaprak (susuzluk, kök ya da solgunluk hastalığı olabilir)',
      anahtarKelimeler: ['Solgun Yaprak', 'Solgunluk', 'Pörsüme'],
      latinceAdi: 'Belirti — sebebi tarlada araştırılmalı',
      hedefUrunler: 'Ayçiçeği',
      kategori: 'Belirti (sebebi araştırılmalı)',
      tehlikeSeviyesi: 'Sebebe bağlı',
      aciklama: 'Yaprakların sarkması bir hastalık adı değil, belirtidir. Susuzluk, sıcak stresi, kök çürüklüğü, sap içinde kahverengileşme yapan solgunluk hastalıkları (Verticillium, Sclerotinia) veya köklerde canavar otu (Orobanş) olabilir.',
      mucadeleGruplari: [],
      ilaclaTedaviYok: true,
      uygulamaZamani: 'İlaç atmadan önce sebebi bulun: toprağın nemine bakın, bir bitkiyi söküp köklerini ve kök boğazını inceleyin, sapı boyuna kesip iletim demetlerinde kahverengileşme olup olmadığına bakın.',
      kulturelOnlemler: [
        'Toprak kuruysa ve sabah solgunluk düzeliyorsa sebep büyük ihtimalle susuzluk/sıcaktır.',
        'Köklerde beyaz-sarımsı canavar otu (Orobanş) sapları varsa dayanıklı çeşit ve ekim nöbeti gerekir.',
        'Sap içi kahverengiyse veya kök boğazında beyaz küf varsa ilçe tarım müdürlüğüne örnek götürün.',
      ],
      dikkatNotu: 'Sebebi belli olmadan yapılan ilaçlama hem masraftır hem de işe yaramaz.',
    ),

    // ── Pamuk ──
    const ZiraiRecete(
      hastalikAdi: 'Pamuk Fusarium Solgunluğu',
      anahtarKelimeler: ['Fusarium Solgunluğu', 'Pamuk Fusarium', 'vasinfectum'],
      latinceAdi: 'Fusarium oxysporum f. sp. vasinfectum',
      hedefUrunler: 'Pamuk',
      kategori: 'Toprak kökenli fungal hastalık',
      tehlikeSeviyesi: 'Yüksek (Bitkiyi Kurutur)',
      aciklama: 'Yapraklar kenarlardan sararıp solar ve dökülür; gövde boyuna kesilince iletim demetlerinde koyu kahverengi renk görülür. Mantar toprakta yıllarca yaşar.',
      mucadeleGruplari: [
        'Fungisitli tohum ilaçları (yalnız ekim öncesi, korunma için)',
      ],
      ilaclaTedaviYok: true,
      uygulamaZamani: 'Hastalanmış bitki ilaçla iyileşmez. Mücadele bir sonraki ekimde başlar: ilaçlı sertifikalı tohum ve dayanıklı çeşit.',
      kulturelOnlemler: [
        'Hastalığa dayanıklı/toleranslı pamuk çeşidi seçin.',
        'Hububat ile ekim nöbeti yapın; pamuğu pamuk üstüne ekmeyin.',
        'Kök-ur nematodu hastalığı ağırlaştırır; nematod sorunu varsa ayrıca inceletin.',
        'Hastalıklı sapları tarladan çıkarın, aletleri bulaşık tarladan temize geçmeden temizleyin.',
      ],
      dikkatNotu: 'Solgunluk belirtisi Verticillium ve susuzlukla karışır; kesin teşhis için gövde kesitine bakın veya laboratuvara örnek gönderin.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Pamuk Verticillium Solgunluğu (Verticillium dahliae)',
      anahtarKelimeler: ['Verticillium', 'Pamuk Solgunluğu', 'dahliae'],
      latinceAdi: 'Verticillium dahliae',
      hedefUrunler: 'Pamuk',
      kategori: 'Toprak kökenli fungal hastalık',
      tehlikeSeviyesi: 'Yüksek (Verim ve Lif Kalitesi Düşer)',
      aciklama: 'Yapraklarda damarlar arasında sarı, sonra kahverengi "kaplan postu" lekeler oluşur, yapraklar ve kozalar dökülür. Gövde kesitinde iletim demetleri açık kahverengidir. Serin yaz gecelerinde ve fazla sulamada artar.',
      mucadeleGruplari: [],
      ilaclaTedaviYok: true,
      uygulamaZamani: 'İlaçla tedavisi yoktur. Bu sezon sulama ve gübreyi düzenleyin; asıl mücadele çeşit seçimi ve ekim nöbetiyle sonraki yıllarda yapılır.',
      kulturelOnlemler: [
        'Dayanıklı/toleranslı çeşit seçin.',
        'Buğday, arpa, mısır gibi konukçu olmayan ürünlerle ekim nöbeti yapın; domates, patlıcan, patates de bu hastalığa konukçudur.',
        'Aşırı azotlu gübrelemeden ve fazla sulamadan kaçının.',
        'Hastalıklı sapları tarlada bırakmayın; bulaşık tarladan gelen alet ve suyla yayılır.',
      ],
      dikkatNotu: 'Mantar toprakta uzun yıllar canlı kalır; tarlanın bulaşık olduğunu kayıt altına alın ve ekim planını buna göre yapın.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Pamuk Bakteriyel Yanıklık (Xanthomonas)',
      anahtarKelimeler: ['Köşeli Yaprak Lekesi', 'Bakteriyel Yanıklık', 'Xanthomonas', 'malvacearum'],
      latinceAdi: 'Xanthomonas citri pv. malvacearum',
      hedefUrunler: 'Pamuk',
      kategori: 'Bakteriyel hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek',
      aciklama: 'Yapraklarda damarlarla sınırlanmış köşeli, önce yağlı-koyu yeşil sonra kahverengi-siyah lekeler oluşur; damar boyunca yayılır, kozalarda çürüklük yapabilir. Tohumla taşınır, yağmur ve yağmurlama ile yayılır.',
      mucadeleGruplari: [
        'Bakırlı preparatlar (koruyucu, yayılmayı yavaşlatır)',
        'Tohum ilaçlaması / asitle tüyü alınmış sertifikalı tohum (ekim öncesi)',
      ],
      uygulamaZamani: 'İlk köşeli lekeler görüldüğünde, özellikle yağışlı ya da yağmurlama sulamalı dönemlerde; bakteri hastalığına mantar ilacı (fungisit) etki etmez.',
      kulturelOnlemler: [
        'Sertifikalı, temiz tohum kullanın; hastalıklı tarladan tohum ayırmayın.',
        'Yağmurlama yerine damla veya karık sulamayı tercih edin.',
        'Hastalıklı artıkları toprağa gömün, ekim nöbeti yapın.',
      ],
      dikkatNotu: 'Bakırlı ürünler bazı ürünlerle karıştırılamaz; karıştırmadan önce etikete bakın.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Pamuk Alternarya Yaprak Lekesi',
      anahtarKelimeler: ['Pamuk Alternarya', 'Alternaria macrospora'],
      latinceAdi: 'Alternaria macrospora / Alternaria alternata',
      hedefUrunler: 'Pamuk',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta',
      aciklama: 'Yapraklarda küçük, kahverengi, halkalı (hedef tahtası gibi) lekeler oluşur; ağır durumda yaprak dökümü olur. Potasyum eksikliği ve kuraklık stresi yaşayan bitkilerde belirgin şekilde artar.',
      mucadeleGruplari: [
        'Strobilurin grubu fungisitler (QoI)',
        'Triazol grubu fungisitler (DMI)',
      ],
      uygulamaZamani: 'Koza bağlama döneminde lekeler hızla artıyor ve yaprak dökümü başlıyorsa; önce beslenme ve su durumunu kontrol edin.',
      kulturelOnlemler: [
        'Toprak analizine göre potasyumu yeterli verin; potasyum eksikliği hastalığı belirgin şekilde artırır.',
        'Su stresini azaltın, sulama aralığını düzenleyin.',
        'Hastalıklı artıkları toprağa gömün.',
      ],
      dikkatNotu: direncNotu,
    ),

    // ── Şeker pancarı ──
    const ZiraiRecete(
      hastalikAdi: 'Pancar Serkospora Yaprak Lekesi (Cercospora beticola)',
      anahtarKelimeler: ['Serkospora', 'Cercospora', 'Pancar Yaprak Lekesi'],
      latinceAdi: 'Cercospora beticola',
      hedefUrunler: 'Şeker Pancarı',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Yüksek (Şeker Oranını Düşürür)',
      aciklama: 'Yapraklarda ortası açık gri, kenarı kırmızı-kahverengi yuvarlak küçük lekeler oluşur; lekeler birleşince yapraklar kurur ve bitki yeni yaprak çıkararak şeker birikimini kaybeder. Sıcak ve nemli yaz aylarında hızla yayılır.',
      mucadeleGruplari: [
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
        'Çok yönlü etkili koruyucu fungisitler (bakırlı ürünler dahil)',
      ],
      uygulamaZamani: 'Yapraklarda ilk lekeler görüldüğünde (genellikle Haziran sonu - Temmuz); şeker fabrikasının ziraat ekibinin hastalık uyarıları takip edilmeli, tekrarlar etiketteki aralığa göre yapılmalı.',
      kulturelOnlemler: [
        'Pancarı aynı tarlaya en az 3-4 yıl arayla ekin.',
        'Serkosporaya toleranslı çeşit seçin.',
        'Hasattan sonra yaprak artıklarını derin sürümle gömün; geçen yılın pancar tarlasının yanına ekmeyin.',
      ],
      dikkatNotu: 'Serkospora ilaçlara çok hızlı direnç kazanır; etki gruplarını mutlaka sırayla değiştirin, aynı grubu sezonda tekrar tekrar kullanmayın.',
    ),

    // ── Mercimek ──
    const ZiraiRecete(
      hastalikAdi: 'Mercimek Antraknozu / Askohita (Ascochyta lentis)',
      anahtarKelimeler: ['Askohita', 'Ascochyta', 'Mercimek Antraknozu', 'Mercimek Yanıklığı'],
      latinceAdi: 'Ascochyta lentis',
      hedefUrunler: 'Mercimek',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Yüksek (Serin ve Yağışlı Baharlarda)',
      aciklama: 'Yaprak, sap ve baklalarda kenarı koyu, ortası açık renkli lekeler ve içinde siyah noktacıklar oluşur; sap kırılabilir, baklada dane lekelenir. Tohumla taşınır.',
      mucadeleGruplari: [
        'Fungisitli tohum ilaçları (ekim öncesi)',
        'Strobilurin grubu fungisitler (QoI)',
        'Triazol grubu fungisitler (DMI)',
      ],
      uygulamaZamani: 'Çiçeklenme öncesi - erken çiçeklenmede, serin ve yağışlı havada ilk lekeler görüldüğünde.',
      kulturelOnlemler: [
        'Hastalıksız, sertifikalı ve ilaçlı tohum kullanın.',
        'Mercimeği aynı tarlaya en az 3-4 yıl arayla ekin.',
        'Hastalıklı anız ve artıkları toprağa gömün.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Mercimek Pası (Uromyces viciae-fabae)',
      anahtarKelimeler: ['Mercimek Pası', 'Uromyces'],
      latinceAdi: 'Uromyces viciae-fabae',
      hedefUrunler: 'Mercimek',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek',
      aciklama: 'Yaprak ve saplarda önce sarımsı, sonra kahverengi-pas renkli toz halinde püstüller oluşur; ağır durumda bitki erken kurur ve dane küçük kalır.',
      mucadeleGruplari: [
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
      ],
      uygulamaZamani: 'Çiçeklenme döneminde ilk pas püstülleri görüldüğünde; bakla dolumu ilerledikten sonra ilaçlama çoğu zaman ekonomik değildir.',
      kulturelOnlemler: [
        'Dayanıklı çeşit tercih edin.',
        'Ekim nöbeti yapın, hastalıklı artıkları gömün.',
        'Sık ekimden kaçının.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Mercimek Küllemesi',
      anahtarKelimeler: ['Mercimek Küllemesi'],
      latinceAdi: 'Erysiphe pisi / Erysiphe spp.',
      hedefUrunler: 'Mercimek',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta',
      aciklama: 'Yaprak ve saplarda beyaz-gri un serpilmiş gibi tabaka oluşur; genellikle sezon sonunda, gündüz sıcak gece serin havada artar.',
      mucadeleGruplari: [
        'Kükürtlü preparatlar (koruyucu)',
        'Triazol grubu fungisitler (DMI)',
      ],
      uygulamaZamani: 'Çiçeklenme - bakla bağlama döneminde hızla yayılıyorsa; hasada yakın geç küllemede ilaçlama genellikle gerekmez.',
      kulturelOnlemler: [
        'Erken ekim ve uygun sıklıkla bitkilerin havalanmasını sağlayın.',
        'Hastalıklı artıkları toprağa gömün.',
      ],
      dikkatNotu: 'Kükürtlü ürünler 30°C üzerinde yaprağı yakar; sıcak saatlerde uygulanmaz.',
    ),

    // ── Domates ──
    const ZiraiRecete(
      hastalikAdi: 'Domates Bakteriyel Leke (Xanthomonas)',
      anahtarKelimeler: ['Domates Bakteriyel Leke', 'Bakteriyel Leke', 'Xanthomonas vesicatoria'],
      latinceAdi: 'Xanthomonas vesicatoria / X. euvesicatoria',
      hedefUrunler: 'Domates, Biber',
      kategori: 'Bakteriyel hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek',
      aciklama: 'Yapraklarda küçük, koyu kahverengi-siyah, bazen sarı haleli lekeler; meyvede kabuklu, kabarık lekeler oluşur. Tohum ve fideyle taşınır, yağmur ve yağmurlama ile yayılır.',
      mucadeleGruplari: [
        'Bakırlı preparatlar (koruyucu, yayılmayı yavaşlatır)',
      ],
      uygulamaZamani: 'İlk lekeler görüldüğünde ve yağışlı dönemlerden önce koruyucu olarak; bakteri hastalığına mantar ilacı (fungisit) etki etmez.',
      kulturelOnlemler: [
        'Sertifikalı tohum ve sağlıklı fide kullanın.',
        'Yağmurlama yerine damla sulama yapın; yapraklar ıslakken bitkiler arasında çalışmayın.',
        'Hastalıklı bitki artıklarını toplayıp imha edin, patlıcangillerle ekim nöbeti yapın.',
      ],
      dikkatNotu: 'Bakırlı ürünler bazı ürünlerle karıştırılamaz ve sık kullanımda bakteri bakıra da dayanıklılık kazanabilir; etiketteki uygulama sayısına uyun.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Domates Mozaik Virüsü (ToMV)',
      anahtarKelimeler: ['Mozaik Virüsü', 'ToMV', 'TMV', 'Domates Mozaik'],
      latinceAdi: 'Tomato mosaic virus (ToMV)',
      hedefUrunler: 'Domates, Biber',
      kategori: 'Virüs hastalığı',
      tehlikeSeviyesi: 'Yüksek (Tedavisi Yok)',
      aciklama: 'Yapraklarda açık-koyu yeşil mozaik desen, kıvrılma ve şekil bozukluğu; meyvede düzensiz olgunlaşma görülür. Tohum, el, alet ve bulaşık bitki artığıyla çok kolay bulaşır.',
      mucadeleGruplari: [],
      ilaclaTedaviYok: true,
      uygulamaZamani: 'Virüsün ilaçla tedavisi yoktur. Belirti gösteren bitkileri hemen söküp tarladan çıkarın ve yayılmayı önleyin.',
      kulturelOnlemler: [
        'Mozaik virüsüne dayanıklı (etiketinde ToMV/Tm-2 dayanıklılığı yazan) çeşit ve sertifikalı tohum kullanın.',
        'Hastalıklı bitkiye dokunduktan sonra ellerinizi sabunla yıkayın; budama makası ve aletleri dezenfekte edin.',
        'Sera ve tarlada sigara içmeyin; tütün virüsü taşıyabilir.',
        'Sezon sonunda bitki artıklarını tamamen temizleyin.',
      ],
      dikkatNotu: 'Virüs hastalığına "ilaç" diye satılan ürünlere itibar etmeyin; ruhsatlı tedavi yoktur.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Domates Sarı Yaprak Kıvırcıklık Virüsü (TYLCV)',
      anahtarKelimeler: ['TYLCV', 'Sarı Yaprak Kıvırcıklık', 'Kıvırcıklık Virüsü'],
      latinceAdi: 'Tomato yellow leaf curl virus (TYLCV)',
      hedefUrunler: 'Domates',
      kategori: 'Virüs hastalığı (beyaz sinekle taşınır)',
      tehlikeSeviyesi: 'Kritik (Erken Bulaşmada Ürün Alınamaz)',
      aciklama: 'Yaprak kenarları sararır ve yukarı doğru kaşık gibi kıvrılır, bitki bodurlaşır, çiçekler dökülür. Virüsü tütün beyaz sineği (Bemisia tabaci) taşır.',
      mucadeleGruplari: [
        'Beyaz sineğe karşı insektisitler (virüsü taşıyan böceğe karşı, etki grupları dönüşümlü)',
      ],
      ilaclaTedaviYok: true,
      uygulamaZamani: 'Hastalanmış bitki iyileşmez. İlaçlama yalnız beyaz sinek popülasyonunu düşürmek içindir; fide döneminden itibaren sarı yapışkan tuzaklarla beyaz sinek takip edilmelidir.',
      kulturelOnlemler: [
        'TYLCV\'ye dayanıklı (Ty genli) çeşit seçin.',
        'Fideleri tülle korunan ortamda yetiştirin; serada kapı ve havalandırmalara tül takın.',
        'Sarı yapışkan tuzak asın; belirti gösteren bitkileri söküp poşetleyerek imha edin.',
        'Tarla kenarındaki yabancı otları temizleyin, eski ürünün yanına yeni dikim yapmayın.',
      ],
      dikkatNotu: 'Beyaz sinek ilaçlara çok hızlı direnç kazanır; etki gruplarını sırayla değiştirin ve faydalı böcekleri koruyun.',
    ),

    const ZiraiRecete(
      hastalikAdi: 'Domates Yaprak Küfü (Passalora fulva)',
      anahtarKelimeler: ['Yaprak Küfü', 'Passalora', 'Cladosporium fulvum', 'Fulvia'],
      latinceAdi: 'Passalora fulva (Cladosporium fulvum)',
      hedefUrunler: 'Domates',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek (Serada)',
      aciklama: 'Yaprak üst yüzünde soluk sarı lekeler, alt yüzünde zeytin yeşili-kahverengi kadifemsi küf oluşur; yapraklar kuruyup dökülür. Özellikle nemi yüksek seralarda görülür.',
      mucadeleGruplari: [
        'Strobilurin grubu fungisitler (QoI)',
        'Triazol grubu fungisitler (DMI)',
        'Koruyucu (kontakt) fungisitler',
      ],
      uygulamaZamani: 'Alt yapraklarda ilk lekeler görüldüğünde; önce sera nemini düşürün, ilaç tek başına yetmez.',
      kulturelOnlemler: [
        'Serayı havalandırın, oransal nemi %85\'in altında tutun; akşam sulamasından kaçının.',
        'Alt yaprakları ayıklayıp seradan çıkarın.',
        'Yaprak küfüne dayanıklı çeşit seçin.',
      ],
      dikkatNotu: direncNotu,
    ),

    const ZiraiRecete(
      hastalikAdi: 'Domates Septorya Yaprak Lekesi (Septoria lycopersici)',
      anahtarKelimeler: ['Domates Septorya', 'Septoria lycopersici'],
      latinceAdi: 'Septoria lycopersici',
      hedefUrunler: 'Domates',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Orta - Yüksek',
      aciklama: 'Alt yapraklarda başlayan, ortası gri-beyaz, kenarı koyu kahverengi çok sayıda küçük yuvarlak leke ve ortasında siyah noktacıklar oluşur; yapraklar alttan yukarı doğru kurur.',
      mucadeleGruplari: [
        'Koruyucu (kontakt) fungisitler',
        'Strobilurin grubu fungisitler (QoI)',
        'Bakırlı preparatlar',
      ],
      uygulamaZamani: 'Alt yapraklarda ilk lekeler görüldüğünde, özellikle yağışlı ve ılık dönemlerde.',
      kulturelOnlemler: [
        'Lekeli alt yaprakları toplayıp tarladan çıkarın.',
        'Yağmurlama sulamadan kaçının; malç ile toprağın yaprağa sıçramasını önleyin.',
        'En az 2-3 yıl ekim nöbeti yapın, artıkları gömün.',
      ],
      dikkatNotu: direncNotu,
    ),

    // ── Bağ ──
    const ZiraiRecete(
      hastalikAdi: 'Bağ Siyah Çürüklüğü (Guignardia bidwellii)',
      anahtarKelimeler: ['Siyah Çürüklük', 'Guignardia', 'Black Rot'],
      latinceAdi: 'Guignardia bidwellii (Phyllosticta ampelicida)',
      hedefUrunler: 'Bağ (Üzüm)',
      kategori: 'Fungal hastalık',
      tehlikeSeviyesi: 'Yüksek (Salkımı Mumyalaştırır)',
      aciklama: 'Yapraklarda kenarı koyu, ortası kahverengi yuvarlak lekeler ve içinde siyah noktacıklar; tanelerde önce açık kahverengi leke, sonra buruşup siyahlaşan mumyalaşmış taneler oluşur.',
      mucadeleGruplari: [
        'Triazol grubu fungisitler (DMI)',
        'Strobilurin grubu fungisitler (QoI)',
        'Koruyucu (kontakt) fungisitler',
      ],
      uygulamaZamani: 'Sürgünler 10-15 cm olduktan sonra, özellikle çiçeklenme öncesi ve sonrasında yağışlı dönemlerde; taneler ben düşmeye başlayınca hassasiyet azalır.',
      kulturelOnlemler: [
        'Asmada ve yerde kalan mumyalaşmış taneleri toplayıp imha edin (hastalığın ana kaynağıdır).',
        'Budama artıklarını bağdan çıkarın.',
        'Yeşil budama ile salkımların havalanmasını sağlayın.',
      ],
      dikkatNotu: direncNotu,
    ),

    // ═══════════════════════════════════════════════════════════════════════════
    // 8. SAĞLIKLI BİTKİ
    // ═══════════════════════════════════════════════════════════════════════════
    const ZiraiRecete(
      hastalikAdi: 'Sağlıklı Bitki Dokusu',
      anahtarKelimeler: ['Sağlıklı', 'Sağlıklı Bitki', 'Normal', 'Temiz'],
      latinceAdi: 'Hastalık belirtisi yok',
      hedefUrunler: 'Tüm Tarım Ürünleri',
      kategori: 'Sağlıklı',
      tehlikeSeviyesi: 'Mükemmel (Hastalık Saptanmadı)',
      aciklama: 'Yaprak dokusunda fungal leke, bakteriyel yanıklık veya böcek zararı görülmedi. İlaçlama gerekmez.',
      mucadeleGruplari: [],
      uygulamaZamani: 'İlaç gerekmez. Besleme yapılacaksa toprak/yaprak analizine göre planlanmalıdır.',
      kulturelOnlemler: [
        'Toprak nemini dengede tutun, aşırı veya yetersiz sulamadan kaçının.',
        'Haftalık tarla kontrollerine devam edin.',
      ],
      dikkatNotu: 'Gereksiz ilaçlama hem masraftır hem de faydalı böcekleri öldürür.',
    ),
  ];

  /// Teşhis adına göre reçete arar; emin olunamazsa null döner (tahmin yürütmez).
  /// Varsayılan olarak yalnızca tam `hastalikAdi` eşleşmesi kabul edilir; çünkü
  /// anahtar kelime eşleşmesi "Mısır Pası (Puccinia sorghi)" gibi teşhisleri
  /// buğday pası reçetesine bağlayabilir. [anahtarKelimeIle] sadece serbest metin
  /// aramaları içindir.
  static ZiraiRecete? receteBul(String teshisAdi, {bool anahtarKelimeIle = false}) {
    final q = teshisAdi.toLowerCase().trim();
    if (q.isEmpty) return null;
    for (final r in tumReceteler) {
      if (r.hastalikAdi.toLowerCase() == q) return r;
    }
    if (!anahtarKelimeIle) return null;
    for (final r in tumReceteler) {
      for (final k in r.anahtarKelimeler) {
        if (q.contains(k.toLowerCase())) return r;
      }
    }
    return null;
  }

  /// Belirli bir ürün için geçerli reçeteler (manuel teşhis listesi için).
  /// "Sağlıklı" kaydı her zaman sona eklenir.
  static List<ZiraiRecete> urunIcinReceteler(String? urun) {
    final saglikli = tumReceteler.where((r) => r.hastalikAdi.contains('Sağlıklı'));
    final hastaliklar = tumReceteler.where((r) => !r.hastalikAdi.contains('Sağlıklı'));
    if (urun == null || urun.trim().isEmpty) return [...hastaliklar, ...saglikli];
    var u = urun.toLowerCase().trim();
    if (u == 'üzüm') u = 'bağ';
    final eslesen = hastaliklar.where((r) => r.hedefUrunler.toLowerCase().contains(u)).toList();
    return [...eslesen, ...saglikli];
  }

  /// Verilen teşhis adına veya ürün adına göre en doğru Zirai Reçeteyi bulur
  /// (eski API; yeni kod [receteBul] kullanmalı).
  static ZiraiRecete receteGetir(String teshisAdi, {String? ekilmisUrun}) {
    final String query = teshisAdi.toLowerCase().trim();
    final kesin = receteBul(teshisAdi, anahtarKelimeIle: true);
    if (kesin != null) return kesin;

    // 1. Doğrudan anahtar kelime eşleşmesi
    for (final r in tumReceteler) {
      for (final k in r.anahtarKelimeler) {
        if (query.contains(k.toLowerCase()) || k.toLowerCase().contains(query)) {
          return r;
        }
      }
    }

    // 2. Hastalık adında kısmi eşleşme
    for (final r in tumReceteler) {
      if (r.hastalikAdi.toLowerCase().contains(query) || query.contains(r.hastalikAdi.toLowerCase())) {
        return r;
      }
    }

    // 3. Ekili ürüne göre varsayılan hastalık reçetesi
    if (ekilmisUrun != null) {
      final u = ekilmisUrun.toLowerCase();
      if (u.contains('buğday') || u.contains('arpa')) {
        return tumReceteler.firstWhere((r) => r.hastalikAdi.contains('Pas'));
      } else if (u.contains('mısır')) {
        return tumReceteler.firstWhere((r) => r.hastalikAdi.contains('Mısır Koçan'));
      } else if (u.contains('ayçiçek')) {
        return tumReceteler.firstWhere((r) => r.hastalikAdi.contains('Ayçiçeği Mildiyösü'));
      } else if (u.contains('zeytin')) {
        return tumReceteler.firstWhere((r) => r.hastalikAdi.contains('Zeytin Halkalı'));
      } else if (u.contains('üzüm') || u.contains('bağ')) {
        return tumReceteler.firstWhere((r) => r.hastalikAdi.contains('Bağ Küllemesi'));
      } else if (u.contains('domates') || u.contains('biber')) {
        return tumReceteler.firstWhere((r) => r.hastalikAdi.contains('Domates Mildiyösü'));
      }
    }

    // 4. Genel güvenli reçete
    return tumReceteler.firstWhere((r) => r.hastalikAdi.contains('Septorya'));
  }
}

class ZiraiRecete {
  final String hastalikAdi;
  final List<String> anahtarKelimeler;
  final String latinceAdi;
  final String hedefUrunler;
  final String kategori;
  final String tehlikeSeviyesi;
  final String aciklama;

  /// Mücadelede kullanılan etki grupları (ürün adı ya da doz DEĞİL). Boşsa ilaç kullanılmaz.
  final List<String> mucadeleGruplari;
  final String uygulamaZamani;
  final List<String> kulturelOnlemler;
  final String dikkatNotu;

  /// Hastalanmış bitki ilaçla iyileşmez (virüs, solgunluk). [mucadeleGruplari] varsa
  /// yalnız korunma içindir (tohum ilacı, virüs taşıyan böcek).
  final bool ilaclaTedaviYok;

  const ZiraiRecete({
    required this.hastalikAdi,
    required this.anahtarKelimeler,
    required this.latinceAdi,
    required this.hedefUrunler,
    required this.kategori,
    required this.tehlikeSeviyesi,
    required this.aciklama,
    required this.mucadeleGruplari,
    required this.uygulamaZamani,
    required this.kulturelOnlemler,
    required this.dikkatNotu,
    this.ilaclaTedaviYok = false,
  });

  bool get ilacGerekir => mucadeleGruplari.isNotEmpty;
}
