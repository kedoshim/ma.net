# Downloads the pinned cloudflared build used for "Play online" and checks
# its SHA-256. The binary is not committed (about 55 MB).
$ErrorActionPreference = 'Stop'

$Version = '2026.9.3'
$Sha256 = 'f096265ec2fcbe9bb6e2d64268db167ced3fcbb83d894bdb9e2fcdb26f2ea7e2'
$Url = "https://github.com/cloudflare/cloudflared/releases/download/$Version/cloudflared-windows-amd64.exe"
$Target = Join-Path $PSScriptRoot 'tools\cloudflared.exe'
$License = Join-Path $PSScriptRoot 'tools\cloudflared-LICENSE.txt'
$LicenseUrl = "https://raw.githubusercontent.com/cloudflare/cloudflared/$Version/LICENSE"

function Test-Binary {
    (Test-Path $Target) -and ((Get-FileHash $Target -Algorithm SHA256).Hash -eq $Sha256.ToUpper())
}

# Apache-2.0: the license text ships with the binary.
function Get-License {
    if (-not (Test-Path $License)) {
        Invoke-WebRequest -Uri $LicenseUrl -OutFile $License -UseBasicParsing
    }
}

if (Test-Binary) {
    Get-License
    Write-Host "cloudflared $Version already present"
    exit 0
}

New-Item -ItemType Directory -Force (Split-Path $Target) | Out-Null
Write-Host "Downloading cloudflared $Version..."
Invoke-WebRequest -Uri $Url -OutFile $Target -UseBasicParsing

if (-not (Test-Binary)) {
    Remove-Item $Target -Force
    throw "cloudflared checksum mismatch"
}
Get-License
Write-Host "cloudflared $Version saved to $Target"
