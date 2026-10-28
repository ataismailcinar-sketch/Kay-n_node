using KayinBackend.Domain.Common;

namespace KayinBackend.Domain.Entities;

/// <summary>
/// Yaprak hastalık tarama kaydı entity'si.
/// Çevrimdışı TensorFlow Lite modelinin ürettiği teşhis sonuçlarını saklar.
/// Analiz tamamen cihaz üzerinde yapılır; fotoğraf yalnızca yedek ve başka cihazda
/// görüntüleme için, kayıt senkronize edildikten sonra ayrıca yüklenir (FotografVar).
/// </summary>
public class HastalikTarama : BaseEntity
{
    /// <summary>
    /// Taramanın yapıldığı parsel — isteğe bağlı.
    /// </summary>
    public Guid? ParselId { get; set; }

    /// <summary>
    /// Navigation property.
    /// </summary>
    public Parsel? Parsel { get; set; }

    /// <summary>
    /// Tarama tarihi ve saati (UTC).
    /// </summary>
    public DateTime TaramaTarihi { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// TFLite modelinin birincil tanısı.
    /// Örn: "Yaprak Yanıklığı", "Külleme", "Pas Hastalığı", "Sağlıklı"
    /// </summary>
    public string TeshisAdi { get; set; } = string.Empty;

    /// <summary>
    /// Modelin tanıya olan güveni — yüzde (0–100).
    /// Örn: 85.4 → "%85 Yaprak Yanıklığı"
    /// </summary>
    public double GüvenYüzdesi { get; set; } = 0.0;

    /// <summary>
    /// Modelin döndürdüğü tüm sınıf olasılıkları — JSON formatında.
    /// Örn: [{"label":"Yanıklık","score":0.85},{"label":"Sağlıklı","score":0.12}]
    /// </summary>
    public string TumSinifOlasiliklariJson { get; set; } = "[]";

    /// <summary>
    /// Analiz edilen fotoğrafın çekildiği cihazdaki yerel yolu (yalnızca o cihazda anlamlı).
    /// </summary>
    public string FotografYerelYolu { get; set; } = string.Empty;

    /// <summary>
    /// Fotoğraf sunucuya yüklendi mi? Yalnızca sunucu değiştirir (fotoğraf uç noktası);
    /// sync ile istemciden gelen değer yok sayılır.
    /// </summary>
    public bool FotografVar { get; set; }

    /// <summary>
    /// Kullanılan TFLite model versiyonu.
    /// Örn: "plant_disease_v2.tflite"
    /// Model güncellemelerinde sonuçların karşılaştırılabilmesi için.
    /// </summary>
    public string ModelVersionu { get; set; } = string.Empty;

    /// <summary>
    /// Aciliyet seviyesi — modelin güven eşiğine göre atanır.
    /// "Kritik" (>80%), "Dikkat" (50–80%), "Düşük" (<50%), "Sağlıklı"
    /// </summary>
    public string AciliyetSeviyesi { get; set; } = "Düşük";

    /// <summary>
    /// İnternet bağlantısı olmadan analiz yapıldığını doğrulayan bayrak.
    /// Her zaman true olmalıdır — edge-AI prensibi.
    /// </summary>
    public bool CevrimdisiAnalizYapildi { get; set; } = true;
}
