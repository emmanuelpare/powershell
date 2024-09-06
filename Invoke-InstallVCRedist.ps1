#visual c-plus-plus redistributable installer :: build 6/seagull
write-host "Microsoft Visual C++ 2015-2022 Redistributable x86 & x64"
write-host "========================================================"

[int]$varKernel = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Windows\system32\kernel32.dll")).FileBuildPart
if ($varKernel -eq 7600) {
    write-host "- NOTICE: The Visual C++ Installer may behave erratically on some Windows 7 SP0 machines."
    write-host "  To resolve these issues, please update this Endpoint to Windows 7 SP1 as soon as possible."
}

$varScriptDir = split-path -parent $MyInvocation.MyCommand.Definition

###################################################################################################################################################

function downloadFile ($url, $whitelist) {
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    $varFilename = $url.split('/')[-1]
    (New-Object System.Net.WebClient).DownloadFile("$url", "$varFilename")
    if (!(test-path $varFilename)) {
        write-host "- ERROR: File $varFilename could not be downloaded."
        write-host "  Please ensure you are whitelisting $whitelist."
        write-host "- Operations cannot continue; exiting."
        exit 1
    }
    else {
        write-host "- Downloaded $varFilename"
    }
}

function verifyPackage ($file, $certificate, $thumbprint, $name, $url) {
    $varChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try {
        $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | out-null
    }
    catch [System.Management.Automation.MethodInvocationException] {
        write-host "- ERROR: $name installer did not contain a valid digital certificate."
        write-host "  This could suggest a change in the way $name is packaged; it could"
        write-host "  also suggest tampering in the connection chain."
        write-host "- Please ensure $url is whitelisted and try again."
        write-host "  If this issue persists across different devices, please file a support ticket."
    }

    $varIntermediate = ($varChain.ChainElements | ForEach-Object { $_.Certificate } | Where-Object { $_.Subject -match "$certificate" }).Thumbprint

    if ($varIntermediate -ne $thumbprint) {
        write-host "- ERROR: $file did not pass verification checks for its digital signature."
        write-host "  This could suggest that the certificate used to sign the $name installer"
        write-host "  has changed; it could also suggest tampering in the connection chain."
        write-host `r
        if ($varIntermediate) {
            write-host ": We received: $varIntermediate"
            write-host "  We expected: $thumbprint"
            write-host "  Please report this issue."
        }
        write-host "- Installation cannot continue. Exiting."
        exit 1
    }
    else {
        write-host "- Digital Signature verification passed."
    }
}

###################################################################################################################################################

$osDetails = Get-CimInstance -ClassName Win32_OperatingSystem

downloadFile https://aka.ms/vs/17/release/vc_redist.x86.exe "https://aka.ms and https://download.visualstudio.microsoft.com"
verifyPackage "vc_redist.x86.exe" "Microsoft Code Signing PCA 2011" "F252E794FE438E35ACE6E53762C0A234A2C52135" "32-bit VC++ Redist" "https://download.visualstudio.microsoft.com"
$varVCVer = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo("$varScriptDir\vc_redist.x86.exe")).ProductVersion
cmd /c vc_redist.x86.exe /q /install /passive /norestart
$varLastExit = $LASTEXITCODE
write-host "- Installed vc_redist.x86.exe"

if ($varLastExit -eq 3010) {
    write-host "- ALERT: The 32-bit Visual C++ redistributable on this device has been updated successfully."
    write-host "  The installer has signalled that the device must be rebooted before proceeding."
    write-host "  Please restart this system as soon as possible."
    if ([intptr]::Size -eq 8) { write-host "  (You will need to re-run the Component after rebooting to install the 64-bit binary)" }
    exit 0
}

if ($osDetails.OsArchitecture -eq "64-bit") {
    write-host ": 64-bit device detected. Installing 64-bit redistributable binary..."
    downloadFile https://aka.ms/vs/17/release/vc_redist.x64.exe "https://aka.ms and https://download.visualstudio.microsoft.com"
    verifyPackage "vc_redist.x64.exe" "Microsoft Code Signing PCA 2011" "F252E794FE438E35ACE6E53762C0A234A2C52135" "64-bit VC++ Redist" "https://download.visualstudio.microsoft.com"
    cmd /c vc_redist.x64.exe /q /install /passive /norestart
    $varLastExit = $LASTEXITCODE
    write-host "- Installed vc_redist.x64.exe"
    if ($varLastExit -eq 3010) {
        write-host "- ALERT: The 64-bit Visual C++ redistributable on this device has been updated successfully."
        write-host "  The installer has signalled that the device must be rebooted before proceeding."
        write-host "  Please restart this system as soon as possible."
    }
}
elseif ($osDetails.OsArchitecture.StartsWith("ARM")) {
    write-host ": arm64-bit device detected. Installing 64-bit redistributable binary..."
    downloadFile https://aka.ms/vs/17/release/vc_redist.arm64.exe "https://aka.ms and https://download.visualstudio.microsoft.com"
    verifyPackage "vc_redist.x64.exe" "Microsoft Code Signing PCA 2011" "F252E794FE438E35ACE6E53762C0A234A2C52135" "arm64-bit VC++ Redist" "https://download.visualstudio.microsoft.com"
    cmd /c vc_redist.arm64.exe /q /install /passive /norestart
    $varLastExit = $LASTEXITCODE
    write-host "- Installed vc_redist.arm64.exe"
    if ($varLastExit -eq 3010) {
        write-host "- ALERT: The arm4-bit Visual C++ redistributable on this device has been updated successfully."
        write-host "  The installer has signalled that the device must be rebooted before proceeding."
        write-host "  Please restart this system as soon as possible."
    }
}
else {
    write-host "- 32-bit device detected. Not installing 64-bit redistributable binary."
}

write-host "- Microsoft Visual C++ Redistributable version $varVCVer installed."
