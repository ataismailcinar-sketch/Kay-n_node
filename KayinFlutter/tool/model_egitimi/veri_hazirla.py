"""Ham veri setlerinden eğitim kümesini hazırlar.

- Her fotoğraf uzun kenarı 512 px olacak şekilde küçültülüp JPEG olarak
  %USERPROFILE%/KayinModelVeri/hazir/<etiket>/ altına yazılır (6000 px'lik
  fotoğrafları her turda yeniden çözmemek için).
- hazir/liste.csv: yol, etiket, bolum (egitim / dogrulama / test).
- Bölme sabit tohumla, sınıf başına %70 / %15 / %15. Mercimek ve PlantDoc'ta
  yazarların kendi test bölümü korunur.

Kullanım: venv\\Scripts\\python veri_hazirla.py
"""
import csv
import os
import random
import re
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageOps

KOK = Path(os.environ["USERPROFILE"]) / "KayinModelVeri"
ACIK = KOK / "acik"
HAZIR = KOK / "hazir"
UZUN_KENAR = 512
UZANTILAR = {".jpg", ".jpeg", ".png", ".bmp"}

PD = "plantdoc/PlantDoc-Dataset-master"
MER = "mercimek_etiketli/Lentil Plant Disease Image Dataset (4 Class)/Lentil Disease Dataset"

# (klasör, etiket, dosya adı deseni ya da None). PlantDoc/mercimek klasörleri {bolum} ile.
KAYNAKLAR = [
    ("bugday_jic", "Bugday___Sari_Pas", r"^YellowRust"),
    ("bugday_jic", "Bugday___Kahverengi_Pas", r"^BrownRust"),
    ("bugday_jic", "Bugday___Kulleme", r"^Mildew"),
    ("bugday_jic", "Bugday___Septorya", r"^Septoria"),
    ("bugday_jic", "Bugday___Saglikli", r"^Healthy"),
    ("bugday_mendeley/wheat_leaf/stripe_rust", "Bugday___Sari_Pas", None),
    ("bugday_mendeley/wheat_leaf/septoria", "Bugday___Septorya", None),
    ("bugday_mendeley/wheat_leaf/Healthy", "Bugday___Saglikli", None),
    ("arpa/Experiment/Net Blotch", "Arpa___Ag_Leke", None),
    ("arpa/Experiment/Scald", "Arpa___Rinkosporyum", None),
    ("arpa/Experiment/Healthy", "Arpa___Saglikli", None),
    ("aycicegi_yaprak/Sunflower Leaf Original/Downy Mildew", "Aycicegi___Mildiyo", None),
    ("aycicegi_meyve/Original Image/Downy mildew", "Aycicegi___Mildiyo", None),
    ("aycicegi_yaprak/Sunflower Leaf Original/Powdery Mildew", "Aycicegi___Kulleme", None),
    ("aycicegi_yaprak/Sunflower Leaf Original/Alternaria Leaf Spot", "Aycicegi___Alternarya", None),
    ("aycicegi_yaprak/Sunflower Leaf Original/Wilted Leaves", "Aycicegi___Solgunluk", None),
    ("aycicegi_meyve/Original Image/Gray mold", "Aycicegi___Kursuni_Kuf", None),
    ("aycicegi_yaprak/Sunflower Leaf Original/Healthy", "Aycicegi___Saglikli", None),
    ("aycicegi_meyve/Original Image/Fresh Leaf", "Aycicegi___Saglikli", None),
    ("pamuk/Cotton_Original_Dataset/Fusarium Wilt", "Pamuk___Fusarium", None),
    ("pamuk/Cotton_Original_Dataset/Verticillium Wilt", "Pamuk___Verticillium", None),
    ("pamuk/Cotton_Original_Dataset/Bacterial Blight", "Pamuk___Bakteriyel_Yaniklik", None),
    ("pamuk/Cotton_Original_Dataset/Alternaria Leaf Spot", "Pamuk___Alternarya", None),
    ("pamuk/Cotton_Original_Dataset/Healthy Leaf", "Pamuk___Saglikli", None),
    ("pancar_cavdar/dataset/beet/cercospora", "Seker_Pancari___Serkospora", None),
    ("pancar_cavdar/dataset/beet/unaffected", "Seker_Pancari___Saglikli", None),
    (MER + "/{bolum}/Ascochyta blight", "Mercimek___Askohita", None),
    (MER + "/{bolum}/Lentil Rust", "Mercimek___Pas", None),
    (MER + "/{bolum}/Powdery Mildew", "Mercimek___Kulleme", None),
    (MER + "/{bolum}/Normal", "Mercimek___Saglikli", None),
    (PD + "/{bolum}/Corn leaf blight", "Misir___Yaprak_Yanikligi", None),
    (PD + "/{bolum}/Corn rust leaf", "Misir___Pas", None),
    (PD + "/{bolum}/Corn Gray leaf spot", "Misir___Gri_Yaprak_Lekesi", None),
    (PD + "/{bolum}/Tomato Early blight leaf", "Domates___Erken_Yaniklik", None),
    (PD + "/{bolum}/Tomato leaf late blight", "Domates___Gec_Yaniklik", None),
    (PD + "/{bolum}/Tomato leaf bacterial spot", "Domates___Bakteriyel_Leke", None),
    (PD + "/{bolum}/Tomato leaf mosaic virus", "Domates___Mozaik_Virusu", None),
    (PD + "/{bolum}/Tomato leaf yellow virus", "Domates___Sari_Kivircik_Virusu", None),
    (PD + "/{bolum}/Tomato mold leaf", "Domates___Yaprak_Kufu", None),
    (PD + "/{bolum}/Tomato Septoria leaf spot", "Domates___Septorya", None),
    (PD + "/{bolum}/Tomato leaf", "Domates___Saglikli", None),
    (PD + "/{bolum}/Potato leaf early blight", "Patates___Erken_Yaniklik", None),
    (PD + "/{bolum}/Potato leaf late blight", "Patates___Gec_Yaniklik", None),
    (PD + "/{bolum}/grape leaf black rot", "Uzum___Siyah_Curukluk", None),
    (PD + "/{bolum}/grape leaf", "Uzum___Saglikli", None),
]

# Kaynak bölüm adı → bizim bölüm adımız (yazarların ayırdığı test korunur).
YAZAR_BOLUMLERI = {
    PD: {"train": None, "test": "test"},
    MER: {"Train": None, "Validation": "dogrulama", "Test": "test"},
}


def dosyalar(klasor: Path, desen):
    if not klasor.is_dir():
        raise SystemExit(f"Klasör yok: {klasor}")
    r = re.compile(desen) if desen else None
    return sorted(f for f in klasor.iterdir()
                  if f.suffix.lower() in UZANTILAR and (r is None or r.search(f.name)))


def kayitlari_topla():
    """[(kaynak_yolu, etiket, sabit_bolum ya da None)]"""
    kayit = []
    for klasor, etiket, desen in KAYNAKLAR:
        onek = next((k for k in YAZAR_BOLUMLERI if klasor.startswith(k)), None)
        if onek:
            for kaynak_bolum, bizim in YAZAR_BOLUMLERI[onek].items():
                for f in dosyalar(ACIK / klasor.format(bolum=kaynak_bolum), desen):
                    kayit.append((f, etiket, bizim))
        else:
            kayit += [(f, etiket, None) for f in dosyalar(ACIK / klasor, desen)]
    return kayit


def bolumle(kayit):
    rnd = random.Random(42)
    sinif = {}
    for i, (_, etiket, sabit) in enumerate(kayit):
        if sabit is None:
            sinif.setdefault(etiket, []).append(i)
    bolum = [s for (_, _, s) in kayit]
    for idx in sinif.values():
        rnd.shuffle(idx)
        n = len(idx)
        # Yazar bölümü olan sınıflarda (PlantDoc) test zaten ayrı: kalanı %85 / %15.
        test_var = any(kayit[i][2] == "test" for i in range(len(kayit)) if kayit[i][1] == kayit[idx[0]][1])
        n_test = 0 if test_var else round(n * 0.15)
        n_dog = round(n * 0.15)
        for j, i in enumerate(idx):
            bolum[i] = "test" if j < n_test else "dogrulama" if j < n_test + n_dog else "egitim"
    return bolum


def kucult(args):
    kaynak, hedef = args
    if hedef.exists():
        return True
    try:
        im = Image.open(kaynak)
        im = ImageOps.exif_transpose(im).convert("RGB")
        im.thumbnail((UZUN_KENAR, UZUN_KENAR), Image.LANCZOS)
        hedef.parent.mkdir(parents=True, exist_ok=True)
        im.save(hedef, "JPEG", quality=92)
        return True
    except Exception as e:  # bozuk dosya atlanır
        print("atlandı:", kaynak, e)
        return False


def main():
    kayit = kayitlari_topla()
    bolum = bolumle(kayit)
    isler, satirlar = [], []
    for i, ((kaynak, etiket, _), b) in enumerate(zip(kayit, bolum)):
        hedef = HAZIR / etiket / f"{i:06d}.jpg"
        isler.append((kaynak, hedef))
        satirlar.append((hedef.relative_to(HAZIR).as_posix(), etiket, b))
    with ThreadPoolExecutor(os.cpu_count()) as ex:
        tamam = list(ex.map(kucult, isler))
    satirlar = [s for s, t in zip(satirlar, tamam) if t]
    with open(HAZIR / "liste.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["yol", "etiket", "bolum"])
        w.writerows(satirlar)
    sayim = {}
    for _, e, b in satirlar:
        sayim.setdefault(e, {"egitim": 0, "dogrulama": 0, "test": 0})[b] += 1
    for e in sorted(sayim):
        print(f"{e:34s} {sayim[e]}")
    print("toplam", len(satirlar), "sınıf", len(sayim))


if __name__ == "__main__":
    main()
