# Yaprak hastalık modeli için açık lisanslı (CC BY 4.0) veri setlerini indirir ve açar.
# Veri OneDrive dışında tutulur: %USERPROFILE%\KayinModelVeri\{ham,acik}
# Lisansı doğrulanamayan setler (PlantVillage GitHub deposu, Roboflow zeytin) bilerek yok.
# Kullanım: powershell -File veri_indir.ps1   (inmiş/açılmış olanlar atlanır)

$ErrorActionPreference = 'Stop'
$kok = Join-Path $env:USERPROFILE 'KayinModelVeri'
$ham = Join-Path $kok 'ham'
$acik = Join-Path $kok 'acik'
$7z = 'C:\Program Files\7-Zip\7z.exe'
New-Item -ItemType Directory -Force $ham, $acik | Out-Null

$mendeley = 'https://data.mendeley.com/public-files/datasets'
$setler = @(
    @{ ad = 'bugday_jic';      dosya = 'bugday_jic.zip';        url = 'https://zenodo.org/records/7573133/files/Long%202023%20Plant%20Path%20999%20photos.zip?download=1' }
    @{ ad = 'bugday_mendeley'; dosya = 'bugday_mendeley.rar';   url = "$mendeley/wgd66f8n6h/files/4ec9266d-d7c1-4fd5-85c9-e5624c09a847/file_downloaded" }
    @{ ad = 'aycicegi_yaprak'; dosya = 'aycicegi_yaprak.zip';   url = "$mendeley/c5mxmfmprt/files/fc044597-72fb-49c2-b3eb-c9eb78253f33/file_downloaded" }
    @{ ad = 'aycicegi_meyve';  dosya = 'aycicegi_meyve.rar';    url = "$mendeley/b83hmrzth8/files/f07d3003-475a-4694-93c1-66fa690cc7b6/file_downloaded" }
    @{ ad = 'pamuk';           dosya = 'pamuk.zip';             url = "$mendeley/t9hgvk2h9p/files/a3bc3269-5c19-4394-824b-50be764a27c4/file_downloaded" }
    @{ ad = 'mercimek';        dosya = 'mercimek.zip';          url = "$mendeley/7vb77bz2st/files/bab6ab18-36fc-4423-afc6-8d9495f2a37c/file_downloaded" }
    @{ ad = 'plantdoc';        dosya = 'plantdoc.zip';          url = 'https://codeload.github.com/pratikkayal/PlantDoc-Dataset/zip/refs/heads/master' }
    @{ ad = 'arpa';            dosya = 'arpa.rar';              url = "$mendeley/8nzpnwkncp/files/33f8a47e-ae14-44f2-9cc6-4e9cd1b16097/file_downloaded" }
    @{ ad = 'pancar_cavdar';   dosya = 'pancar_cavdar.zip';     url = 'https://zenodo.org/records/15873360/files/dataset.zip?download=1' }
)

foreach ($s in $setler) {
    $arsiv = Join-Path $ham $s.dosya
    $hedef = Join-Path $acik $s.ad
    if (-not (Test-Path $arsiv)) {
        Write-Host "[indir] $($s.ad)"
        # -C - : yarıda kalan indirme kaldığı yerden sürer
        & curl.exe -L --fail --retry 5 --retry-delay 10 -C - -o "$arsiv.part" $s.url
        if ($LASTEXITCODE -ne 0) { Write-Warning "$($s.ad) indirilemedi (curl $LASTEXITCODE)"; continue }
        Move-Item "$arsiv.part" $arsiv
    }
    if (-not (Test-Path $hedef)) {
        Write-Host "[ac] $($s.ad)"
        & $7z x $arsiv "-o$hedef.tmp" -y -bso0 -bsp0
        if ($LASTEXITCODE -ne 0) { Write-Warning "$($s.ad) açılamadı (7z $LASTEXITCODE)"; continue }
        Move-Item "$hedef.tmp" $hedef
    }
    Write-Host "[tamam] $($s.ad)"
}
