param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [string]$VsCodeUrl = "https://update.code.visualstudio.com/latest/linux-rpm-x64/stable",
    [string]$IntelliJUrl = "https://download.jetbrains.com/idea/ideaIC-latest.tar.gz",
    [switch]$UploadToTarget,
    [string]$ScpTargetHost,
    [string]$ScpTargetPath = "/opt/devmachine/packages",
    [string]$ScpUsername = "root",
    [SecureString]$ScpPassword
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

if ($UploadToTarget) {
    if ([string]::IsNullOrWhiteSpace($ScpTargetHost)) {
        throw "ScpTargetHost is required when -UploadToTarget is used."
    }

    if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
        throw "scp command not found. Install OpenSSH client first."
    }

    Write-Host "Uploading packages to ${ScpUsername}@${ScpTargetHost}:${ScpTargetPath} ..."
    $remoteTarget = "${ScpUsername}@${ScpTargetHost}:${ScpTargetPath}/"

    if ($ScpPassword) {
        if (-not (Get-Command sshpass -ErrorAction SilentlyContinue)) {
            throw "ScpPassword was provided but sshpass is not installed. Install sshpass or omit ScpPassword for interactive password entry."
        }

        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ScpPassword)
        try {
            $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            & sshpass -p $plainPassword scp -o StrictHostKeyChecking=accept-new $vsCodeTarget $intelliJTarget $remoteTarget
            if ($LASTEXITCODE -ne 0) {
                throw "scp upload failed with exit code $LASTEXITCODE"
            }
        }
        finally {
            if ($bstr -ne [IntPtr]::Zero) {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
            $plainPassword = $null
        }
    }
    else {
        Write-Host "No ScpPassword provided. scp will prompt for the password interactively."
        & scp -o StrictHostKeyChecking=accept-new $vsCodeTarget $intelliJTarget $remoteTarget
        if ($LASTEXITCODE -ne 0) {
            throw "scp upload failed with exit code $LASTEXITCODE"
        }
    }
}

Write-Host "Done. Files saved in $OutputDirectory"
