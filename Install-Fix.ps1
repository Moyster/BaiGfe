# Declare functions

# Check if GFX Experience is installed from 
# https://www.reich-consulting.net/support/lan-administration/check-if-a-program-is-installed-using-powershell-3/
function Is-Installed( $program ) {
    
    $x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    return $x86 -or $x64;
}

function Install-GFE-Fix() {
    If (-Not (Is-Installed("GeForce Experience")) ) {
        "GeForce Experience must be installed to run this script"
        Exit
    }

    # Get root directory path 
    $gfxPath = (Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\GFExperience" -Name "FullPath").Replace("NVIDIA GeForce Experience.exe","") + "www\"

    # Get file hashes for the two app.js files to compare them
    $oldHash = Get-FileHash -Path $($gfxPath + "app.js") -Algorithm "MD5"
    $newHash = Get-FileHash -Path $($PSScriptRoot + "\app.js") -Algorithm "MD5"

    # If file in gfx dir is the same as the pending installation, skip installation
    If ($oldHash.Hash -eq $newHash.Hash) {
        "Skipping Installation, fixed file already installed"
    } else {
        # Copy the app.js file to the powershell script directory as a backup
        Copy-Item $($gfxPath + "app.js") -Destination $($PSScriptRoot + "\backup_app.js")

        # Kill GFX if running
        Stop-Process -Name "NVIDIA GeForce Experience" -Force

        # Get rid of in-directory backup if it exists
        Remove-Item -Path $($gfxPath + "app.js.bak")

        # backup js file within gfx directory
        Rename-Item -Path $($gfxPath + "app.js") -NewName "app.js.bak" -Force

        # Copy new app.js file into directory
        Copy-Item $($PSScriptRoot + "\app.js") -Destination $gfxPath

        "Successfully Replaced"
    }
}

# Check for admin rights
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

# We need admin rights to modify the Nvidia installation successfully
If (-Not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) ) {
    # If no admin rights found, elevate powershell and run this script from the elevated shell
    Start-Process powershell -ArgumentList $("-file" + $PSScriptRoot + "\Install-Fix.ps1") -Verb runAs
} else { 
    # If admin rights exist, call the PS function which installs the app
    Install-GFE-Fix
}