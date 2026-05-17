param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [string]$VsCodeUrl = "https://update.code.visualstudio.com/latest/linux-rpm-x64/stable",
    [string]$IntelliJUrl = "https://download.jetbrains.com/idea/ideaIC-latest.tar.gz",
    [string]$AnsibleVsixUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/redhat/vsextensions/ansible/latest/vspackage",
    [string]$PythonVsixUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/python/latest/vspackage",
    [switch]$UploadToTarget,
    [string]$ScpTargetHost,
    [string]$ScpTargetPath = "/opt/devmachine/packages",
    [string]$ScpUsername = "root",
    [SecureString]$ScpPassword,
    [switch]$ScpAcceptNewHostKey
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$vsCodeTarget = Join-Path $OutputDirectory "code-latest.x86_64.rpm"
$intelliJTarget = Join-Path $OutputDirectory "ideaIC-latest.tar.gz"
$ansibleVsixTarget = Join-Path $OutputDirectory "redhat.ansible.vsix"
$pythonVsixTarget = Join-Path $OutputDirectory "ms-python.python.vsix"

Write-Host "Downloading VS Code Linux RPM..."
Invoke-WebRequest -Uri $VsCodeUrl -OutFile $vsCodeTarget -ErrorAction Stop

Write-Host "Downloading IntelliJ IDEA Linux archive..."
Invoke-WebRequest -Uri $IntelliJUrl -OutFile $intelliJTarget -ErrorAction Stop

Write-Host "Downloading VS Code Ansible extension..."
Invoke-WebRequest -Uri $AnsibleVsixUrl -OutFile $ansibleVsixTarget -ErrorAction Stop

Write-Host "Downloading VS Code Python extension..."
Invoke-WebRequest -Uri $PythonVsixUrl -OutFile $pythonVsixTarget -ErrorAction Stop

if (-not (Test-Path $vsCodeTarget) -or (Get-Item $vsCodeTarget).Length -le 0) {
    throw "VS Code download failed: $vsCodeTarget"
}

if (-not (Test-Path $intelliJTarget) -or (Get-Item $intelliJTarget).Length -le 0) {
    throw "IntelliJ download failed: $intelliJTarget"
}

if (-not (Test-Path $ansibleVsixTarget) -or (Get-Item $ansibleVsixTarget).Length -le 0) {
    throw "Ansible VSIX download failed: $ansibleVsixTarget"
}

if (-not (Test-Path $pythonVsixTarget) -or (Get-Item $pythonVsixTarget).Length -le 0) {
    throw "Python VSIX download failed: $pythonVsixTarget"
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
    $scpArgs = @()
    if ($ScpAcceptNewHostKey) {
        $scpArgs += @("-o", "StrictHostKeyChecking=accept-new")
    }

    if ($ScpPassword) {
        if (-not (Get-Command sshpass -ErrorAction SilentlyContinue)) {
            throw "ScpPassword was provided but sshpass is not installed. Install sshpass or omit ScpPassword for interactive password entry."
        }

        $bstr = [IntPtr]::Zero
        try {
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ScpPassword)
            $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            $env:SSHPASS = $plainPassword
            & sshpass -e scp @scpArgs $vsCodeTarget $intelliJTarget $ansibleVsixTarget $pythonVsixTarget $remoteTarget
            if ($LASTEXITCODE -ne 0) {
                throw "scp upload failed with exit code $LASTEXITCODE"
            }
        }
        finally {
            Remove-Item Env:SSHPASS -ErrorAction SilentlyContinue
            if ($bstr -ne [IntPtr]::Zero) {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }
    }
    else {
        Write-Host "No ScpPassword provided. scp will prompt for the password interactively."
        & scp @scpArgs $vsCodeTarget $intelliJTarget $ansibleVsixTarget $pythonVsixTarget $remoteTarget
        if ($LASTEXITCODE -ne 0) {
            throw "scp upload failed with exit code $LASTEXITCODE"
        }
    }
}

Write-Host "Done. Files saved in $OutputDirectory"
