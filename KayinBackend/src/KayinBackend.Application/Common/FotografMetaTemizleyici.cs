using System.Buffers.Binary;
using System.Text;

namespace KayinBackend.Application.Common;

/// <summary>
/// Fotoğraftaki gizli bilgileri (EXIF: GPS konumu, cihaz, çekim saati; XMP; IPTC; yorumlar) görüntüyü yeniden
/// sıkıştırmadan siler. Telefon zaten temizleyip gönderir; bu, eski uygulama sürümleri ve diskteki eski
/// dosyalar için ikinci savunmadır. Kurallar telefondaki <c>fotograf_meta_temizleyici.dart</c> ile aynı:
/// JPEG'de APP0/APP2/APP14 kalır, yalnız yön (Orientation) etiketi küçük bir EXIF'e yeniden yazılır;
/// PNG'de eXIf/tEXt/zTXt/iTXt/tIME atılır. Tanınmayan ya da bozuk dosya olduğu gibi döner.
/// </summary>
public static class FotografMetaTemizleyici
{
    public static byte[] Temizle(byte[] b)
    {
        try
        {
            if (b.Length > 3 && b[0] == 0xFF && b[1] == 0xD8) return Jpeg(b);
            if (b.Length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return Png(b);
        }
        catch (Exception ex) when (ex is IndexOutOfRangeException or ArgumentOutOfRangeException) { }
        return b;
    }

    private static byte[] Jpeg(byte[] b)
    {
        using var c = new MemoryStream(b.Length);
        c.Write([0xFF, 0xD8]);
        int? yon = null;
        var yonYazildi = false;
        var i = 2;
        while (i + 4 <= b.Length)
        {
            if (b[i] != 0xFF) return b;
            var m = b[i + 1];
            if (m == 0xFF) { i++; continue; }
            if (m == 0xD9 || m is >= 0xD0 and <= 0xD7 || m == 0x01)
            {
                c.Write([0xFF, m]);
                i += 2;
                continue;
            }
            var uzunluk = (b[i + 2] << 8) | b[i + 3];
            var son = i + 2 + uzunluk;
            if (uzunluk < 2 || son > b.Length) return b;

            var uygulama = m is >= 0xE0 and <= 0xEF;
            var atilir = m == 0xFE || (uygulama && m != 0xE0 && m != 0xE2 && m != 0xEE);
            if (m == 0xE1) yon ??= ExifYonu(b.AsSpan(i + 4, uzunluk - 2));
            if (!atilir)
            {
                if (!yonYazildi && m != 0xE0 && yon is int y && y != 1)
                {
                    c.Write(YonExifi(y));
                    yonYazildi = true;
                }
                c.Write(b, i, son - i);
            }
            i = son;
            if (m == 0xDA)
            {
                c.Write(b, i, b.Length - i);
                return c.ToArray();
            }
        }
        return b;
    }

    private static int? ExifYonu(ReadOnlySpan<byte> d)
    {
        if (d.Length < 14 || !d[..4].SequenceEqual("Exif"u8)) return null;
        var t = d[6..];
        bool kucuk;
        if (t[0] == 0x49 && t[1] == 0x49) kucuk = true;
        else if (t[0] == 0x4D && t[1] == 0x4D) kucuk = false;
        else return null;
        var ifd = (int)U32(t, 4, kucuk);
        if (ifd < 0 || ifd + 2 > t.Length) return null;
        var adet = U16(t, ifd, kucuk);
        for (var k = 0; k < adet; k++)
        {
            var o = ifd + 2 + k * 12;
            if (o + 12 > t.Length) return null;
            if (U16(t, o, kucuk) == 0x0112)
            {
                var v = U16(t, o + 8, kucuk);
                return v is >= 1 and <= 8 ? v : null;
            }
        }
        return null;
    }

    private static ushort U16(ReadOnlySpan<byte> t, int o, bool kucuk) =>
        kucuk ? BinaryPrimitives.ReadUInt16LittleEndian(t[o..]) : BinaryPrimitives.ReadUInt16BigEndian(t[o..]);

    private static uint U32(ReadOnlySpan<byte> t, int o, bool kucuk) =>
        kucuk ? BinaryPrimitives.ReadUInt32LittleEndian(t[o..]) : BinaryPrimitives.ReadUInt32BigEndian(t[o..]);

    private static byte[] YonExifi(int yon) =>
    [
        0xFF, 0xE1, 0x00, 34,
        0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
        0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,
        0x00, 0x01,
        0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, (byte)yon, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    ];

    private static readonly HashSet<string> PngAtilan = ["eXIf", "tEXt", "zTXt", "iTXt", "tIME"];

    private static byte[] Png(byte[] b)
    {
        using var c = new MemoryStream(b.Length);
        c.Write(b, 0, 8);
        var i = 8;
        while (i + 12 <= b.Length)
        {
            var uzunluk = (int)BinaryPrimitives.ReadUInt32BigEndian(b.AsSpan(i, 4));
            var tur = Encoding.ASCII.GetString(b, i + 4, 4);
            var son = i + 12 + uzunluk;
            if (uzunluk < 0 || son > b.Length) return b;
            if (!PngAtilan.Contains(tur)) c.Write(b, i, son - i);
            i = son;
            if (tur == "IEND") return c.ToArray();
        }
        return b;
    }
}
