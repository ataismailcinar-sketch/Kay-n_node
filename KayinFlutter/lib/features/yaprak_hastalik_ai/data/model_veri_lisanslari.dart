import 'package:flutter/foundation.dart';

/// Yaprak modelinin eğitildiği veri setleri CC BY 4.0: atıf zorunlu.
/// Hesap sayfasındaki "Lisanslar ve veri kaynakları" ekranında görünür.
/// Kaynak listesi: tool/model_egitimi/VERI_KAYNAKLARI.md (ikisi birlikte güncellenmeli).
class ModelVeriLisanslari {
  static const _kaynaklar = [
    'Long, M. ve ark. (2023), Plant Pathology — buğday hastalık fotoğrafları (John Innes Centre). doi:10.5281/zenodo.7573133',
    'Wheat Leaf Dataset (Mendeley Data). doi:10.17632/wgd66f8n6h.1',
    'Fantu, A. — Net Blotch, Leaf Scald and Healthy Malting Barley Leaves (Mendeley Data). doi:10.17632/8nzpnwkncp.1',
    'Sunflower Leaf Disease Image Dataset for Automated Plant Pathology (Mendeley Data). doi:10.17632/c5mxmfmprt.1',
    'Sun Flower Fruits and Leaves dataset (Mendeley Data). doi:10.17632/b83hmrzth8.1',
    'Cotton Leaf Image Dataset for Disease Classification (Mendeley Data). doi:10.17632/t9hgvk2h9p.1',
    'Mahamud, Assaduzzaman, Sharmin — Lentil Plant Disease Image Dataset, Data in Brief 58 (2025). doi:10.17632/7vb77bz2st.2',
    'PSNC & WODR — Plant image classification dataset (pancar serkospora). doi:10.5281/zenodo.15873360',
    'Singh, D. ve ark. (2020) — PlantDoc: A Dataset for Visual Plant Disease Detection. github.com/pratikkayal/PlantDoc-Dataset',
  ];

  static bool _kayitli = false;

  static void kaydet() {
    if (_kayitli) return;
    _kayitli = true;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(
        ['Yaprak hastalık modeli — eğitim verisi'],
        'Cihazdaki yaprak hastalık modeli aşağıdaki veri setleriyle eğitilmiştir. '
        'Hepsi Creative Commons Atıf 4.0 (CC BY 4.0) lisanslıdır: '
        'https://creativecommons.org/licenses/by/4.0/\n'
        'Model bu verilerden Kayın Tarım tarafından türetilmiştir; veri sahipleri uygulamayı onaylamış sayılmaz.\n\n'
        '${_kaynaklar.map((k) => '• $k').join('\n')}',
      );
    });
  }
}
