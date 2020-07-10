# Declare functions

# Check if GFX Experience is installed from 
# https://www.reich-consulting.net/support/lan-administration/check-if-a-program-is-installed-using-powershell-3/
function Test-ApplicationStatus($program) {
    
    $x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    return $x86 -or $x64;
}

function Install-GfeFix() {
    If (!(Test-ApplicationStatus("GeForce Experience")) ) {
        throw "GeForce Experience must be installed to run this script"
    }

    # Get root directory path 
    $gfxPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName((Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\GFExperience" -Name "FullPath")), "www")

    # Get file hashes for the two app.js files to compare them
    $targetGfxAppPath = [System.IO.Path]::Combine($gfxPath, "app.js")
    $patchedGfxAppPath = [System.IO.Path]::Combine($PSScriptRoot, "app.js")
    $oldHash = Get-FileHash -Path $targetGfxAppPath -Algorithm "MD5" -ErrorAction SilentlyContinue
    $newHash = Get-FileHash -Path $patchedGfxAppPath -Algorithm "MD5" -ErrorAction SilentlyContinue

    # If file in gfx dir is the same as the pending installation, skip installation
    If ($oldHash.Hash -eq $newHash.Hash) {
        Write-Host "Patched file had already been installed, skipping..." -BackgroundColor DarkYellow
    }
    else {
        # Copy the app.js file to the powershell script directory as a backup
        Copy-Item $targetGfxAppPath -Destination ([System.IO.Path]::Combine($PSScriptRoot, "backup_app.js")) -ErrorAction SilentlyContinue

        # Kill GFX if running
        Get-Process *nvidia* | ?{$_.Product -match "GeForce Experience"} | Stop-Process

        # Get rid of in-directory backup if it exists
        Remove-Item -Path $($gfxPath + "app.js.bak") -ErrorAction SilentlyContinue

        # backup js file within gfx directory
        Rename-Item -Path $targetGfxAppPath -NewName "app.js.bak" -Force -ErrorAction SilentlyContinue

        # Copy new app.js file into directory
        Copy-Item $patchedGfxAppPath -Destination $gfxPath

        Write-Host "Successfully installed the GeForce Experience patch!" -BackgroundColor Green
    }
}

# Check for admin rights
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

# We need admin rights to modify the Nvidia installation successfully
If (-Not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) ) {
    # If no admin rights found, elevate powershell and run this script from the elevated shell
    Start-Process powershell -ArgumentList $("-file" + $PSScriptRoot + "\Install-Fix.ps1") -Verb runAs
}
else { 
    # If admin rights exist, call the PS function which installs the app
    Install-GfeFix
}