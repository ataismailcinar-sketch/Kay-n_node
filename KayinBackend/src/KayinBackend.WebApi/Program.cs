using System.Threading.RateLimiting;
using KayinBackend.Application;
using KayinBackend.Application.Common;
using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Infrastructure;
using KayinBackend.Infrastructure.Persistence;
using KayinBackend.WebApi.Guvenlik;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// ── Katman Servisleri ──────────────────────────────────────────────────────
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

// ── Kimlik Doğrulama (JWT) ─────────────────────────────────────────────────
var jwt = builder.Configuration.GetSection(JwtAyarlari.Bolum).Get<JwtAyarlari>() ?? new JwtAyarlari();
jwt.Dogrula(); // anahtar yoksa sunucu hiç başlamaz
builder.Services.AddSingleton(jwt);
builder.Services.AddSingleton<TokenUretici>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IAktifKullanici, HttpAktifKullanici>();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidIssuer = jwt.Yayinci,
        ValidAudience = jwt.Hedef,
        IssuerSigningKey = jwt.ImzaAnahtari(),
        ValidateIssuerSigningKey = true,
        ClockSkew = TimeSpan.FromMinutes(5),
    });

// Varsayılan: her uç nokta giriş ister. Girişsiz olanlar [AllowAnonymous] ile açıkça işaretlenir.
builder.Services.AddAuthorizationBuilder()
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

// ── Kaba kuvvet koruması: IP başına dakikada 10 giriş/kayıt denemesi ─────────
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy(Program.GirisSinirPolitikasi, http => RateLimitPartition.GetFixedWindowLimiter(
        http.Connection.RemoteIpAddress?.ToString() ?? "bilinmiyor",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) }));
});

// ── API Servisleri ─────────────────────────────────────────────────────────
builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new()
    {
        Title = "Kayın Tarım API",
        Version = "v1",
        Description = "Offline-First Tarım Yönetim Sistemi — Senkronizasyon ve CRUD API"
    });
});

// ── Tünel / ters vekil arkasında çalışma (Cloudflare Tunnel, nginx) ─────────
// Vekil aynı makinede (localhost) çalışır; yalnız ondan gelen X-Forwarded-* başlıklarına güvenilir.
// Gerçek istemci IP'si giriş sınırlamasında kullanılır (yoksa herkes 127.0.0.1 sayılıp birbirini kilitler),
// X-Forwarded-Proto=https ise HTTPS yönlendirmesi döngüye girmez.
builder.Services.Configure<ForwardedHeadersOptions>(o =>
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto);

// ── Günlük yedek (Yedek:Klasor verilirse) ──────────────────────────────────
builder.Services.AddHostedService<GunlukYedek>();

// CORS bilerek yok: istemci mobil/masaüstü uygulaması, tarayıcı değil. Tarayıcıdan
// erişim gerekirse yalnızca o alan adına izin veren bir politika eklenmeli.

var app = builder.Build();

// ── Veritabanı: bekleyen migration'ları uygula ─────────────────────────────
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await dbContext.Database.MigrateAsync();

    // Konum temizliğinden önce yüklenmiş fotoğraflar (tek seferlik).
    if (scope.ServiceProvider.GetRequiredService<IFotografDeposu>() is KayinBackend.Infrastructure.Depolama.DiskFotografDeposu disk)
    {
        var n = disk.EskileriTemizle();
        if (n > 0) app.Logger.LogInformation("{Sayi} eski fotoğrafın EXIF bilgisi temizlendi", n);
    }
}

app.UseForwardedHeaders();

// ── Hata → HTTP kodu ───────────────────────────────────────────────────────
app.UseExceptionHandler(hata => hata.Run(async http =>
{
    var ex = http.Features.Get<IExceptionHandlerFeature>()?.Error;
    var (kod, baslik) = ex switch
    {
        IstekHatasi a => (StatusCodes.Status400BadRequest, a.Message),
        KeyNotFoundException k => (StatusCodes.Status404NotFound, k.Message),
        UnauthorizedAccessException => (StatusCodes.Status401Unauthorized, "Giriş gerekli."),
        // İç hata ayrıntısı istemciye gönderilmez; sunucu logunda görülür.
        _ => (StatusCodes.Status500InternalServerError, "Sunucu hatası."),
    };
    http.Response.StatusCode = kod;
    await Results.Problem(statusCode: kod, title: baslik).ExecuteAsync(http);
}));

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    // Geliştirmede emülatör/telefon http ile bağlanır; üretimde yalnızca HTTPS.
    // Tünel/vekil arkasında TLS'i vekil sonlandırır ve sunucu yalnız localhost'ta http dinler:
    // o durumda yönlendirme yapılacak bir https portu yoktur (her istekte uyarı yazıyordu).
    app.UseHsts();
    if (!string.IsNullOrEmpty(app.Configuration["https_port"]) ||
        (app.Configuration["ASPNETCORE_URLS"] ?? app.Configuration["urls"] ?? "").Contains("https://"))
    {
        app.UseHttpsRedirection();
    }
}

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapControllers();

app.Run();

public partial class Program
{
    public const string GirisSinirPolitikasi = "giris";
}
