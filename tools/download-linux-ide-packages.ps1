param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [string]$VsCodeUrl = "https://update.code.visualstudio.com/latest/linux-rpm-x64/stable",
    [string]$IntelliJUrl = "https://download.jetbrains.com/idea/ideaIC-latest.tar.gz"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$vsCodeTarget = Join-Path $OutputDirectory "code-latest.x86_64.rpm"
$intelliJTarget = Join-Path $OutputDirectory "ideaIC-latest.tar.gz"

Write-Host "Downloading VS Code Linux RPM..."
Invoke-WebRequest -Uri $VsCodeUrl -OutFile $vsCodeTarget -ErrorAction Stop

Write-Host "Downloading IntelliJ IDEA Linux archive..."
Invoke-WebRequest -Uri $IntelliJUrl -OutFile $intelliJTarget -ErrorAction Stop

if (-not (Test-Path $vsCodeTarget) -or (Get-Item $vsCodeTarget).Length -le 0) {
    throw "VS Code download failed: $vsCodeTarget"
}

if (-not (Test-Path $intelliJTarget) -or (Get-Item $intelliJTarget).Length -le 0) {
    throw "IntelliJ download failed: $intelliJTarget"
}

Write-Host "Done. Files saved in $OutputDirectory"
