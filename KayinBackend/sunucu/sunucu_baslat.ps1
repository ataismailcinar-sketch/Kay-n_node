# Kayın Tarım sunucusunu test/sunum için bu bilgisayarda başlatır.
#   .\sunucu_baslat.ps1            → yalnız bu bilgisayar (http://localhost:5000)
#   .\sunucu_baslat.ps1 -Tunel     → internetten erişim: Cloudflare geçici tüneli (hesap gerekmez,
#                                     her başlatışta yeni https://….trycloudflare.com adresi verir)
# Veri OneDrive dışında tutulur (OneDrive açık veritabanı dosyasını eşitlerken bozabilir):
#   %USERPROFILE%\KayinTarimVeri\  kayin.db, fotograflar\, yedek\ (günlük, 14 gün), jwt-anahtar.txt
param([switch]$Tunel, [int]$Port = 5000)
$ErrorActionPreference = 'Stop'

$veri = Join-Path $env:USERPROFILE 'KayinTarimVeri'
$uygulama = Join-Path $veri 'uygulama'
New-Item -ItemType Directory -Force $veri, (Join-Path $veri 'fotograflar'), (Join-Path $veri 'yedek') | Out-Null

# İmza anahtarı bir kez üretilir; değişirse herkesin oturumu düşer.
$anahtarDosyasi = Join-Path $veri 'jwt-anahtar.txt'
if (-not (Test-Path $anahtarDosyasi)) {
    $b = New-Object byte[] 48; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    [IO.File]::WriteAllText($anahtarDosyasi, [Convert]::ToBase64String($b))
    Write-Host 'Yeni JWT anahtarı üretildi.'
}

# Güncel kodu OneDrive dışına derle (çalışan dosyalar senkronla çakışmasın).
$proje = Join-Path $PSScriptRoot '..\src\KayinBackend.WebApi\KayinBackend.WebApi.csproj'
Write-Host 'Sunucu derleniyor…'
dotnet publish $proje -c Release -o $uygulama --nologo -v quiet
if ($LASTEXITCODE -ne 0) { throw 'Derleme başarısız.' }

$env:ASPNETCORE_ENVIRONMENT = 'Production'
$env:ASPNETCORE_URLS = "http://localhost:$Port"
$env:Jwt__Anahtar = (Get-Content $anahtarDosyasi -Raw).Trim()
$env:ConnectionStrings__DefaultConnection = "Data Source=$(Join-Path $veri 'kayin.db')"
$env:Fotograflar__Klasor = Join-Path $veri 'fotograflar'
$env:Yedek__Klasor = Join-Path $veri 'yedek'

$sunucu = Start-Process -FilePath (Join-Path $uygulama 'KayinBackend.WebApi.exe') -WorkingDirectory $uygulama `
    -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $veri 'sunucu.log') -RedirectStandardError (Join-Path $veri 'sunucu-hata.log')
for ($i = 0; $i -lt 30; $i++) {
    try { Invoke-WebRequest "http://localhost:$Port/api/auth/ben" -UseBasicParsing -TimeoutSec 2 | Out-Null } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) { break }
    }
    Start-Sleep 1
}
Write-Host "Sunucu çalışıyor: http://localhost:$Port/api   (kayıt: $veri\sunucu.log)"

$tunelSureci = $null
if ($Tunel) {
    $cf = Get-Command cloudflared -ErrorAction SilentlyContinue
    $cfYol = if ($cf) { $cf.Source } else { Join-Path $veri 'cloudflared.exe' }
    if (-not (Test-Path $cfYol)) { throw "cloudflared bulunamadı: $cfYol (README'deki adıma bakın)" }
    $tunelLog = Join-Path $veri 'tunel.log'
    Remove-Item $tunelLog -ErrorAction SilentlyContinue
    $tunelSureci = Start-Process -FilePath $cfYol -ArgumentList @('tunnel', '--no-autoupdate', '--url', "http://localhost:$Port") `
        -PassThru -NoNewWindow -RedirectStandardError $tunelLog -RedirectStandardOutput (Join-Path $veri 'tunel-cikti.log')
    $adres = $null
    for ($i = 0; $i -lt 40 -and -not $adres; $i++) {
        Start-Sleep 1
        if (Test-Path $tunelLog) { $adres = (Select-String -Path $tunelLog -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1).Matches.Value }
    }
    if (-not $adres) { throw "Tünel adresi alınamadı; $tunelLog dosyasına bakın." }
    Set-Content -Path (Join-Path $veri 'adres.txt') -Value "$adres/api" -Encoding utf8
    Write-Host ''
    Write-Host "  Uygulamada sunucu adresi:  $adres/api" -ForegroundColor Green
    Write-Host '  (Giriş ekranındaki "Sunucu" bağlantısından girin. Adres her başlatışta değişir.)'
}

Write-Host ''
Write-Host 'Durdurmak için Enter''a basın.'
try {
    # Etkileşimsiz çalıştırılırsa (zamanlanmış görev vb.) sunucu kapanana kadar bekler.
    # Girdi yönlendirilmişse Read-Host hata vermeden hemen döner; o yüzden önce bakılır.
    if ([Console]::IsInputRedirected) { $sunucu.WaitForExit() }
    else { try { [void](Read-Host) } catch { $sunucu.WaitForExit() } }
} finally {
    if ($tunelSureci -and -not $tunelSureci.HasExited) { Stop-Process -Id $tunelSureci.Id -Force }
    if (-not $sunucu.HasExited) { Stop-Process -Id $sunucu.Id -Force }
    Write-Host 'Durduruldu.'
}