"""Eğitilmiş modeli telefonun okuyacağı TFLite'a çevirir.

Model girdisi uygulamanın verdiği gibidir: [1,224,224,3] float32, RGB, 0-255
(model_config.json "normalizasyon": "0_255"); ImageNet normalizasyonu ve softmax
modelin içindedir. Ağırlıklar float16 (boyut yarıya iner, girdi/çıktı float32 kalır).

Çıktı: %USERPROFILE%/KayinModelVeri/egitim/tflite/yaprak_model.tflite
Kullanım: venv\\Scripts\\python disa_aktar.py
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import timm
import torch

KOK = Path(os.environ["USERPROFILE"]) / "KayinModelVeri"
EGITIM = KOK / "egitim"
CIKIS = EGITIM / "tflite"


class TelefonModeli(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m
        self.register_buffer("ort", torch.tensor([0.485, 0.456, 0.406]).view(1, 3, 1, 1) * 255)
        self.register_buffer("sap", torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1) * 255)

    def forward(self, x):  # x: NHWC, 0-255
        x = x.permute(0, 3, 1, 2)
        return torch.softmax(self.m((x - self.ort) / self.sap), dim=1)


def main():
    kayit = torch.load(EGITIM / "model.pt", map_location="cpu")
    m = timm.create_model(kayit["model"], pretrained=False, num_classes=len(kayit["siniflar"]))
    m.load_state_dict(kayit["agirlik"])
    model = TelefonModeli(m).eval()

    if CIKIS.exists():
        shutil.rmtree(CIKIS)
    CIKIS.mkdir(parents=True)
    onnx_yol = CIKIS / "model.onnx"
    ornek = torch.rand(1, 224, 224, 3) * 255
    torch.onnx.export(model, ornek, onnx_yol, input_names=["girdi"], output_names=["olasilik"], opset_version=17)

    # onnx2tf deneme verisini internetten indirmeye çalışır; yerelde verilir (yalnız iç doğrulamada kullanılır).
    np.save(CIKIS / "calibration_image_sample_data_20x128x128x3_float32.npy",
            np.random.rand(20, 128, 128, 3).astype("float32"))
    subprocess.check_call([sys.executable, "-m", "onnx2tf", "-i", str(onnx_yol), "-o", str(CIKIS / "tf"),
                           "-kat", "girdi", "-n"], cwd=CIKIS)
    f16 = next((CIKIS / "tf").glob("*_float16.tflite"))
    hedef = CIKIS / "yaprak_model.tflite"
    shutil.copy(f16, hedef)

    # PyTorch ile TFLite aynı sonucu veriyor mu?
    import tensorflow as tf
    it = tf.lite.Interpreter(str(hedef))
    it.allocate_tensors()
    gi, ci = it.get_input_details()[0], it.get_output_details()[0]
    assert list(gi["shape"]) == [1, 224, 224, 3] and gi["dtype"] == np.float32, gi
    fark = 0.0
    for _ in range(5):
        x = torch.rand(1, 224, 224, 3) * 255
        it.set_tensor(gi["index"], x.numpy())
        it.invoke()
        fark = max(fark, float(np.abs(it.get_tensor(ci["index"]) - model(x).detach().numpy()).max()))
    (CIKIS / "labels.txt").write_text("\n".join(kayit["siniflar"]) + "\n", encoding="utf-8")
    print(f"{hedef}  {hedef.stat().st_size / 1e6:.1f} MB  sınıf {len(kayit['siniflar'])}  en büyük fark {fark:.5f}")


if __name__ == "__main__":
    main()
