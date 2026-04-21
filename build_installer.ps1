param(
    [string]$Version = "1.0.0",
    [switch]$InstallInnoSetup
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SpecFile = Join-Path $ProjectRoot "main.spec"
$IssFile = Join-Path $ProjectRoot "installer\NobetCizelgesi.iss"
$ReqFile = Join-Path $ProjectRoot "requirements.txt"
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"

function Find-IsccPath {
    $candidates = @(
        (Get-Command ISCC.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    ) | Where-Object { $_ }

    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

if (-not (Test-Path $SpecFile)) {
    throw "main.spec bulunamadi: $SpecFile"
}
if (-not (Test-Path $IssFile)) {
    throw "Installer script bulunamadi: $IssFile"
}
if (-not (Test-Path $ReqFile)) {
    throw "requirements.txt bulunamadi: $ReqFile"
}
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv bulunamadi. Kurulum icin: winget install --id Astral-sh.uv -e"
}

$IsccPath = Find-IsccPath
if (-not $IsccPath -and $InstallInnoSetup) {
    Write-Host "[0/4] Inno Setup bulunamadi, winget ile kuruluyor..."
    winget install --id JRSoftware.InnoSetup -e --accept-source-agreements --accept-package-agreements
    $IsccPath = Find-IsccPath
}
if (-not $IsccPath) {
    throw "ISCC.exe bulunamadi. Kurulum icin: winget install --id JRSoftware.InnoSetup -e"
}

Write-Host "[1/4] Sanal ortam temiz kuruluyor..."
uv venv --clear --python 3.11
if ($LASTEXITCODE -ne 0) {
    throw "uv venv basarisiz oldu."
}
uv pip install -r $ReqFile
if ($LASTEXITCODE -ne 0) {
    throw "requirements kurulumu basarisiz oldu."
}
uv pip install pyinstaller
if ($LASTEXITCODE -ne 0) {
    throw "pyinstaller kurulumu basarisiz oldu."
}

if (-not (Test-Path $VenvPython)) {
    throw "Sanal ortam python bulunamadi: $VenvPython"
}

Write-Host "[2/4] PyInstaller ile exe uretiliyor..."
& $VenvPython -m PyInstaller --noconfirm --clean $SpecFile
if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller exe uretimi basarisiz oldu."
}

$BuiltExe = Join-Path $ProjectRoot "dist\NobetCizelgesi.exe"
if (-not (Test-Path $BuiltExe)) {
    throw "Exe olusmadi: $BuiltExe"
}

Write-Host "[3/4] Inno Setup ile kurulum paketi uretiliyor..."
& $IsccPath "/DMyAppVersion=$Version" $IssFile
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup derlemesi basarisiz oldu."
}

$SetupDir = Join-Path $ProjectRoot "dist\installer"
$SetupFile = Join-Path $SetupDir ("NobetCizelgesi-Setup-{0}.exe" -f $Version)
if (-not (Test-Path $SetupFile)) {
    throw "Setup dosyasi bulunamadi: $SetupFile"
}

Write-Host "[4/4] Tamamlandi"
Write-Host "EXE: $BuiltExe"
Write-Host "SETUP: $SetupFile"
