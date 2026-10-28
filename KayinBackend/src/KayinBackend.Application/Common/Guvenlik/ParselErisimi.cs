using KayinBackend.Application.Common.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Common.Guvenlik;

public static class ParselErisimi
{
    /// <summary>
    /// Kayıt bir tarlaya bağlanacaksa tarla giriş yapan kullanıcıya ait olmalı.
    /// Sorgu filtresi başka kullanıcının tarlasını gizlediği için "bulunamadı" ile aynı sonuç verir.
    /// </summary>
    public static async Task KontrolEt(IApplicationDbContext db, Guid? parselId, CancellationToken ct)
    {
        if (parselId is null) return;
        if (!await db.Parseller.AnyAsync(p => p.Id == parselId, ct))
            throw new KeyNotFoundException("Tarla bulunamadı.");
    }
}
