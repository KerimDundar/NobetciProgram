param(
    [string]$Version = "1.0",
    [switch]$InstallInnoSetup,
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SpecFile = Join-Path $ProjectRoot "main.spec"
$IssFile = Join-Path $ProjectRoot "installer\NobetCizelgesi.iss"
$ReqFile = Join-Path $ProjectRoot "requirements.txt"
$VenvDir = Join-Path $ProjectRoot ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$RootStateFile = Join-Path $ProjectRoot "app_state.json"
$DistStateFile = Join-Path $ProjectRoot "dist\app_state.json"

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

function Resolve-PythonPath {
    param([string]$CommandName)

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        return $pyLauncher.Source
    }

    throw "Python bulunamadi. Python 3.11+ kurup tekrar deneyin."
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

$IsccPath = Find-IsccPath
if (-not $IsccPath -and $InstallInnoSetup) {
    Write-Host "[0/4] Inno Setup bulunamadi, winget ile kuruluyor..."
    winget install --id JRSoftware.InnoSetup -e --accept-source-agreements --accept-package-agreements
    $IsccPath = Find-IsccPath
}
if (-not $IsccPath) {
    throw "ISCC.exe bulunamadi. Kurulum icin: winget install --id JRSoftware.InnoSetup -e"
}

$PythonPath = Resolve-PythonPath $Python

Write-Host "[1/5] Runtime state dosyalari temizleniyor..."
foreach ($stateFile in @($RootStateFile, $DistStateFile)) {
    if (Test-Path $stateFile) {
        Remove-Item -LiteralPath $stateFile -Force
    }
}

Write-Host "[2/5] Sanal ortam temiz kuruluyor..."
& $PythonPath -m venv --clear $VenvDir
if ($LASTEXITCODE -ne 0) {
    throw "venv olusturma basarisiz oldu."
}
if (-not (Test-Path $VenvPython)) {
    throw "Sanal ortam python bulunamadi: $VenvPython"
}

& $VenvPython -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    throw "pip guncelleme basarisiz oldu."
}
& $VenvPython -m pip install -r $ReqFile pyinstaller
if ($LASTEXITCODE -ne 0) {
    throw "requirements veya pyinstaller kurulumu basarisiz oldu."
}

Write-Host "[3/5] PyInstaller ile exe uretiliyor..."
& $VenvPython -m PyInstaller --noconfirm --clean $SpecFile
if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller exe uretimi basarisiz oldu."
}

$BuiltExe = Join-Path $ProjectRoot "dist\main.exe"
if (-not (Test-Path $BuiltExe)) {
    throw "Exe olusmadi: $BuiltExe"
}

Write-Host "[4/5] Inno Setup ile kurulum paketi uretiliyor..."
& $IsccPath "/DMyAppVersion=$Version" $IssFile
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup derlemesi basarisiz oldu."
}

$SetupDir = Join-Path $ProjectRoot "dist\installer"
$SetupFile = Join-Path $SetupDir ("NobetCizelgesi-Setup-{0}.exe" -f $Version)
if (-not (Test-Path $SetupFile)) {
    throw "Setup dosyasi bulunamadi: $SetupFile"
}

Write-Host "[5/5] Tamamlandi"
Write-Host "EXE: $BuiltExe"
Write-Host "SETUP: $SetupFile"
