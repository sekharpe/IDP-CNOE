$ErrorActionPreference='Stop'

$found = Get-Command kubectl -ErrorAction SilentlyContinue
if ($found) {
    Write-Host "kubectl already on PATH at: $($found.Path)"
    & kubectl version --client --short
    exit 0
}

$searchPaths = @('C:\Program Files\Docker','C:\Program Files\Docker\Docker','C:\Program Files\Docker Desktop','C:\Program Files (x86)\Docker')
$foundFile = $null
foreach ($p in $searchPaths) {
    if (Test-Path $p) {
        $f = Get-ChildItem -Path $p -Filter kubectl.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { $foundFile = $f.FullName; break }
    }
}

if ($foundFile) {
    $dir = Split-Path $foundFile -Parent
    Write-Host "Found kubectl at: $foundFile"
    setx PATH ("$env:PATH;" + $dir) | Out-Null
    Write-Host "Added to user PATH. Restart shell to use."
    & "$foundFile" version --client --short
    exit 0
}

if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Installing kubectl via Chocolatey..."
    choco install kubernetes-cli -y
    & kubectl version --client --short
    exit 0
}

# Fallback: download latest stable kubectl.exe to %USERPROFILE%\bin
$ver = (Invoke-RestMethod -Uri 'https://dl.k8s.io/release/stable.txt').Trim()
$dest = Join-Path $env:USERPROFILE 'bin'
New-Item -ItemType Directory -Path $dest -Force | Out-Null
$url = "https://dl.k8s.io/release/$ver/bin/windows/amd64/kubectl.exe"
Write-Host "Downloading $url to $dest..."
Invoke-WebRequest -Uri $url -OutFile (Join-Path $dest 'kubectl.exe')
setx PATH ("$env:PATH;" + $dest) | Out-Null
Write-Host "kubectl installed to $dest and added to user PATH. Open a new shell to use it."
& (Join-Path $dest 'kubectl.exe') version --client --short
