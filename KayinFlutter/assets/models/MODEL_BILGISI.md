# Yaprak hastalık modeli

- Dosya: `yaprak_model.tflite` (MobileNetV3-Large, ImageNet ön eğitimli, 35 sınıf, ağırlıklar float16, ~8.5 MB)
- Eğitim: 23.10.2026, `tool/model_egitimi/` (veri_indir.ps1 → veri_hazirla.py → egit.py → disa_aktar.py → karsilastir.py)
- Veri: açık lisanslı (CC BY 4.0) tarla ve yaprak fotoğrafları; kaynaklar ve atıflar `tool/model_egitimi/VERI_KAYNAKLARI.md`
- Girdi: 1x224x224x3 float32, RGB, 0-255 → `model_config.json` "normalizasyon": "0_255"
- Çıktı: 1x35 softmax, sıra `labels.txt` ile aynı. Etiket biçimi `Urun___Hastalik`; Türkçe karşılık
  `lib/features/yaprak_hastalik_ai/domain/yaprak_etiket_eslestirici.dart`.

## Tanıdığı ürünler
Buğday (sarı pas, kahverengi pas, külleme, septorya), Arpa (ağ leke, rinkosporyum), Ayçiçeği (mildiyö,
külleme, alternarya, kurşuni küf, solgunluk), Pamuk (fusarium, verticillium, bakteriyel yanıklık, alternarya),
Şeker Pancarı (serkospora), Mercimek (askohita, pas, külleme), Domates (7 hastalık), Üzüm (siyah çürüklük);
her ürünün sağlıklı sınıfı da var.

## Ölçüm (eğitimde kullanılmayan test fotoğrafları, ürün biliniyor, %80 eşik)
| Ürün | Teşhis konan | Konan teşhis doğru |
|---|---|---|
| Arpa | %98 | %100 |
| Ayçiçeği | %97 | %100 |
| Buğday | %86 | %97 |
| Pamuk | %96 | %96 |
| Şeker Pancarı | %94 | %98 |
| Mercimek | %74 | %92 |
| Domates | %39 | %89 (eski model %56) |
| Üzüm | %95 | %100 |

## Sınırlamalar
- Mısır, patates, nohut, fasulye, yonca, zeytin, soya: açık veride sağlıklı sınıfı ya da hiç veri yok → modelde
  yok, uygulama elle seçime geçer. (Eski PlantVillage modeli mısır/patatesi tanıyordu; `_kaldirilan/KayinFlutter/model_plantvillage/`.)
- Arpa ve pamuk fotoğrafları beyaz zeminde çekilmiş; tarlada doğruluk test sonucundan düşük olabilir.
- Mercimek verisi çoğaltılmış (döndürülmüş/gerilmiş) görüntüler; test sonucu iyimser olabilir.
- Domates test seti küçük (69 foto); sonuçlar oynak.
- Gerçek Türkiye tarla fotoğraflarıyla henüz denenmedi.
- Yaprak olmayan fotoğraflara da sınıf atar → uygulamada %80 güven eşiği ve tarla ürünü filtresi var.
