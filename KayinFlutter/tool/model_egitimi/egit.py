"""Yaprak hastalık sınıflandırıcısını eğitir (MobileNetV3-Large, ImageNet ön eğitimli).

Girdi: %USERPROFILE%/KayinModelVeri/hazir/liste.csv (veri_hazirla.py üretir)
Çıktı: %USERPROFILE%/KayinModelVeri/egitim/{model.pt, etiketler.txt, rapor.json}

Ön işleme uygulamayla aynıdır: kısa kenar 224'e ölçeklenir, ortadan 224x224 kırpılır.
Kullanım: venv\\Scripts\\python egit.py [--tur 30]
"""
import argparse
import csv
import json
import math
import os
import time
from collections import Counter
from pathlib import Path

import timm
import torch
import torch.nn as nn
from PIL import Image
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler
from torchvision import transforms as T

KOK = Path(os.environ["USERPROFILE"]) / "KayinModelVeri"
HAZIR = KOK / "hazir"
CIKTI = KOK / "egitim"
BOYUT = 224
ESIK = 0.80  # uygulamadaki TfliteLeafAnalyzerUseCase.minGuven

ORT = (0.485, 0.456, 0.406)
SAP = (0.229, 0.224, 0.225)


class Kume(Dataset):
    def __init__(self, satirlar, siniflar, donusum):
        self.s = satirlar
        self.idx = {e: i for i, e in enumerate(siniflar)}
        self.d = donusum

    def __len__(self):
        return len(self.s)

    def __getitem__(self, i):
        yol, etiket = self.s[i]
        return self.d(Image.open(HAZIR / yol).convert("RGB")), self.idx[etiket]


def bitki(etiket):
    return etiket.split("___")[0]


@torch.no_grad()
def tahminler(model, yukleyici, cihaz):
    model.eval()
    olas, gercek = [], []
    for x, y in yukleyici:
        with torch.autocast("cuda", dtype=torch.float16):
            p = model(x.to(cihaz, non_blocking=True)).float().softmax(1)
        olas.append(p.cpu())
        gercek.append(y)
    return torch.cat(olas), torch.cat(gercek)


def olc(olas, gercek, siniflar):
    """Genel doğruluk, sınıf ortalaması ve uygulamadaki gibi 'tarla ürünü biliniyor' doğruluğu."""
    n = len(siniflar)
    tahmin = olas.argmax(1)
    sinif_dogru = Counter()
    sinif_say = Counter()
    for t, g in zip(tahmin.tolist(), gercek.tolist()):
        sinif_say[g] += 1
        sinif_dogru[g] += int(t == g)
    # Ürün biliniyorsa yalnız o ürünün sınıfları arasında karar (uygulama böyle yapar).
    bitkiler = [bitki(s) for s in siniflar]
    urun_dogru = 0
    esik_ustu = esik_ustu_dogru = 0
    for p, g in zip(olas, gercek.tolist()):
        maske = torch.tensor([b == bitkiler[g] for b in bitkiler])
        q = torch.where(maske, p, torch.zeros_like(p))
        q = q / q.sum().clamp_min(1e-9)
        t = int(q.argmax())
        urun_dogru += int(t == g)
        if q[t] >= ESIK:
            esik_ustu += 1
            esik_ustu_dogru += int(t == g)
    toplam = len(gercek)
    return {
        "dogruluk": (tahmin == gercek).float().mean().item(),
        "sinif_ortalamasi": sum(sinif_dogru[i] / sinif_say[i] for i in sinif_say) / len(sinif_say),
        "urun_bilinirken": urun_dogru / toplam,
        "esik_ustu_oran": esik_ustu / toplam,
        "esik_ustu_dogruluk": esik_ustu_dogru / max(esik_ustu, 1),
        "sinif": {siniflar[i]: [sinif_dogru[i], sinif_say[i]] for i in range(n) if sinif_say[i]},
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tur", type=int, default=30)
    ap.add_argument("--parti", type=int, default=64)
    ap.add_argument("--model", default="mobilenetv3_large_100")
    a = ap.parse_args()

    torch.manual_seed(0)
    cihaz = "cuda" if torch.cuda.is_available() else "cpu"
    satirlar = list(csv.DictReader(open(HAZIR / "liste.csv", encoding="utf-8")))
    # Sağlıklı sınıfı olmayan ürün (PlantDoc'ta mısır, patates) sağlıklı yaprağa da hastalık der → alınmaz.
    saglikli_var = {bitki(s["etiket"]) for s in satirlar if s["etiket"].endswith("___Saglikli")}
    atilan = sorted({bitki(s["etiket"]) for s in satirlar} - saglikli_var)
    if atilan:
        print("sağlıklı sınıfı olmadığı için alınmadı:", ", ".join(atilan))
    satirlar = [s for s in satirlar if bitki(s["etiket"]) in saglikli_var]
    siniflar = sorted({s["etiket"] for s in satirlar})
    bol = {b: [(s["yol"], s["etiket"]) for s in satirlar if s["bolum"] == b]
           for b in ("egitim", "dogrulama", "test")}

    egitim_d = T.Compose([
        T.RandomResizedCrop(BOYUT, scale=(0.25, 1.0), ratio=(0.75, 1.33)),
        T.RandomHorizontalFlip(), T.RandomVerticalFlip(), T.RandomRotation(20),
        T.ColorJitter(0.35, 0.35, 0.35, 0.04), T.RandomGrayscale(0.05),
        T.ToTensor(), T.Normalize(ORT, SAP),
    ])
    test_d = T.Compose([T.Resize(BOYUT), T.CenterCrop(BOYUT), T.ToTensor(), T.Normalize(ORT, SAP)])

    # Az fotoğraflı sınıflar daha sık görülsün (1/√n ağırlık: tam dengeleme küçük sınıfı ezberletir).
    say = Counter(e for _, e in bol["egitim"])
    agirlik = [1 / math.sqrt(say[e]) for _, e in bol["egitim"]]
    ornekleyici = WeightedRandomSampler(agirlik, num_samples=len(agirlik), replacement=True)
    yuk = dict(num_workers=6, pin_memory=True, persistent_workers=True)
    egitim_y = DataLoader(Kume(bol["egitim"], siniflar, egitim_d), a.parti, sampler=ornekleyici, drop_last=True, **yuk)
    dog_y = DataLoader(Kume(bol["dogrulama"], siniflar, test_d), 128, **yuk)
    test_y = DataLoader(Kume(bol["test"], siniflar, test_d), 128, **yuk)

    model = timm.create_model(a.model, pretrained=True, num_classes=len(siniflar), drop_rate=0.2).to(cihaz)
    opt = torch.optim.AdamW(model.parameters(), lr=6e-4, weight_decay=0.02)
    adim = a.tur * len(egitim_y)
    plan = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=6e-4, total_steps=adim, pct_start=0.05)
    kayip_f = nn.CrossEntropyLoss(label_smoothing=0.1)
    olcek = torch.amp.GradScaler()

    CIKTI.mkdir(parents=True, exist_ok=True)
    (CIKTI / "etiketler.txt").write_text("\n".join(siniflar) + "\n", encoding="utf-8")
    en_iyi = -1.0
    for tur in range(1, a.tur + 1):
        model.train()
        t0, toplam = time.time(), 0.0
        for x, y in egitim_y:
            x, y = x.to(cihaz, non_blocking=True), y.to(cihaz, non_blocking=True)
            with torch.autocast("cuda", dtype=torch.float16):
                kayip = kayip_f(model(x), y)
            opt.zero_grad(set_to_none=True)
            olcek.scale(kayip).backward()
            olcek.step(opt)
            olcek.update()
            plan.step()
            toplam += kayip.item()
        m = olc(*tahminler(model, dog_y, cihaz), siniflar)
        print(f"tur {tur:2d}  kayıp {toplam / len(egitim_y):.3f}  doğrulama: doğruluk {m['dogruluk']:.3f}  "
              f"sınıf ort. {m['sinif_ortalamasi']:.3f}  ürün bilinirken {m['urun_bilinirken']:.3f}  "
              f"({time.time() - t0:.0f} sn)", flush=True)
        if m["sinif_ortalamasi"] > en_iyi:
            en_iyi = m["sinif_ortalamasi"]
            torch.save({"model": a.model, "siniflar": siniflar, "agirlik": model.state_dict()}, CIKTI / "model.pt")

    model.load_state_dict(torch.load(CIKTI / "model.pt")["agirlik"])
    rapor = {"model": a.model, "dogrulama": olc(*tahminler(model, dog_y, cihaz), siniflar),
             "test": olc(*tahminler(model, test_y, cihaz), siniflar)}
    (CIKTI / "rapor.json").write_text(json.dumps(rapor, ensure_ascii=False, indent=1), encoding="utf-8")
    t = rapor["test"]
    print(f"TEST  doğruluk {t['dogruluk']:.3f}  sınıf ort. {t['sinif_ortalamasi']:.3f}  "
          f"ürün bilinirken {t['urun_bilinirken']:.3f}  eşik üstü %{100 * t['esik_ustu_oran']:.0f} "
          f"(bunların doğruluğu {t['esik_ustu_dogruluk']:.3f})")
    for s, (d, n) in t["sinif"].items():
        print(f"  {s:34s} {d:4d}/{n:<4d} {d / n:.2f}")


if __name__ == "__main__":
    main()
