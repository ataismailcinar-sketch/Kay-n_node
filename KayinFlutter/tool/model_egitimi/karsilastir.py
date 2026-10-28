"""Yeni TFLite modeli ile uygulamadaki eski (PlantVillage) modeli aynı test
fotoğraflarında, uygulamanın karar kuralıyla karşılaştırır:
tarla ürünü biliniyor → yalnız o ürünün sınıfları; güven >= %80 ise teşhis.

Yalnız iki modelin de tanıdığı ürünler (Domates, Patates, Mısır, Üzüm) karşılaştırılır;
yeni modelin bütün ürünleri ayrıca listelenir.
Kullanım: venv\\Scripts\\python karsilastir.py [eski_model_klasoru]
"""
import csv
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image

KOK = Path(os.environ["USERPROFILE"]) / "KayinModelVeri"
HAZIR = KOK / "hazir"
YENI = KOK / "egitim" / "tflite"
ESKI = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "assets" / "models"
ESIK = 0.80


def anahtar(e):
    return re.sub(r"[^a-z0-9]", "", e.lower())


# Eski PlantVillage etiketi → yeni etiket (yeni modelde karşılığı olanlar).
ESKI_YENI = {anahtar(k): v for k, v in {
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": "Misir___Gri_Yaprak_Lekesi",
    "Corn_(maize)___Common_rust_": "Misir___Pas",
    "Corn_(maize)___Northern_Leaf_Blight": "Misir___Yaprak_Yanikligi",
    "Tomato___Bacterial_spot": "Domates___Bakteriyel_Leke",
    "Tomato___Early_blight": "Domates___Erken_Yaniklik",
    "Tomato___Late_blight": "Domates___Gec_Yaniklik",
    "Tomato___Leaf_Mold": "Domates___Yaprak_Kufu",
    "Tomato___Septoria_leaf_spot": "Domates___Septorya",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": "Domates___Sari_Kivircik_Virusu",
    "Tomato___Tomato_mosaic_virus": "Domates___Mozaik_Virusu",
    "Tomato___healthy": "Domates___Saglikli",
    "Potato___Early_blight": "Patates___Erken_Yaniklik",
    "Potato___Late_blight": "Patates___Gec_Yaniklik",
    "Grape___Black_rot": "Uzum___Siyah_Curukluk",
    "Grape___healthy": "Uzum___Saglikli",
}.items()}
ESKI_BITKI = {"Domates": "tomato", "Patates": "potato", "Misir": "corn", "Uzum": "grape"}


def girdi(yol):
    """Uygulamadaki gibi: kısa kenar 224, ortadan kare kırpma, 0-255 float."""
    im = Image.open(yol).convert("RGB")
    o = 224 / min(im.size)
    im = im.resize((max(224, round(im.width * o)), max(224, round(im.height * o))), Image.BILINEAR)
    x0, y0 = (im.width - 224) // 2, (im.height - 224) // 2
    return np.asarray(im.crop((x0, y0, x0 + 224, y0 + 224)), dtype=np.float32)[None]


class Model:
    def __init__(self, klasor):
        # Yol yerine bayt: TFLite Türkçe karakterli yolu ("Masaüstü") açamıyor.
        self.it = tf.lite.Interpreter(model_content=(klasor / "yaprak_model.tflite").read_bytes())
        self.it.allocate_tensors()
        self.g = self.it.get_input_details()[0]["index"]
        self.c = self.it.get_output_details()[0]["index"]
        self.etiket = [s.strip() for s in open(klasor / "labels.txt", encoding="utf-8") if s.strip()]

    def __call__(self, x):
        self.it.set_tensor(self.g, x)
        self.it.invoke()
        return self.it.get_tensor(self.c)[0]


def karar(p, maske):
    """Ürün sınıflarına göre normalize et → (en iyi indeks, güven)."""
    q = np.where(maske, p, 0)
    q = q / max(q.sum(), 1e-9)
    i = int(q.argmax())
    return i, float(q[i])


def main():
    yeni, eski = Model(YENI), Model(ESKI)
    test = [r for r in csv.DictReader(open(HAZIR / "liste.csv", encoding="utf-8")) if r["bolum"] == "test"]
    yeni_bitki = [e.split("___")[0] for e in yeni.etiket]
    s = defaultdict(lambda: defaultdict(int))
    for r in test:
        gercek = r["etiket"]
        b = gercek.split("___")[0]
        x = girdi(HAZIR / r["yol"])
        i, g = karar(yeni(x), np.array([yb == b for yb in yeni_bitki]))
        d = s[("yeni", b)]
        d["n"] += 1
        d["dogru"] += yeni.etiket[i] == gercek
        d["teshis"] += g >= ESIK
        d["teshis_dogru"] += g >= ESIK and yeni.etiket[i] == gercek
        if b in ESKI_BITKI and anahtar(gercek) != "":
            pv = eski(x)
            j, h = karar(pv, np.array([e.lower().startswith(ESKI_BITKI[b]) for e in eski.etiket]))
            tahmin = ESKI_YENI.get(anahtar(eski.etiket[j]))
            d = s[("eski", b)]
            d["n"] += 1
            d["dogru"] += tahmin == gercek
            d["teshis"] += h >= ESIK
            d["teshis_dogru"] += h >= ESIK and tahmin == gercek

    print(f"{'model':5s} {'ürün':14s} {'foto':>5s} {'doğru':>6s} {'teşhis kondu':>13s} {'konan teşhis doğru':>19s}")
    for (m, b), d in sorted(s.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        print(f"{m:5s} {b:14s} {d['n']:5d} {d['dogru'] / d['n']:6.0%} {d['teshis'] / d['n']:13.0%} "
              f"{d['teshis_dogru'] / max(d['teshis'], 1):19.0%}")


if __name__ == "__main__":
    main()
