﻿# Check for admin rights
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

# We need admin rights to modify the Nvidia installation successfully
If (-Not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) ) {
    "This script must be run as Administrator"
    Exit-PSSession
}

# Check if GFX Experience is installed from 
# https://www.reich-consulting.net/support/lan-administration/check-if-a-program-is-installed-using-powershell-3/
function Is-Installed( $program ) {
    
    $x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    return $x86 -or $x64;
}

If (-Not (Is-Installed("GeForce Experience")) ) {
    "GeForce Experience must be installed to run this script"
    Exit-PSSession
}

# Get root directory path 
$gfxPath = (Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\GFExperience" -Name "FullPath").Replace("NVIDIA GeForce Experience.exe","") + "www\"

# Copy the app.js file to the powershell script directory as a backup
Copy-Item $($gfxPath + "app.js") -Destination $($PSScriptRoot + "\backup_app.js")

# Kill GFX if running
Stop-Process -Name "NVIDIA GeForce Experience" -Force

# Get rid of backup if it exists
Remove-Item -Path $($gfxPath + "app.js.bak")

# backup js file within gfx directory
Rename-Item -Path $($gfxPath + "app.js") -NewName "app.js.bak" -Force

# Copy new app.js file into directory
Copy-Item $($PSScriptRoot + "\app.js") -Destination $gfxPath

"Successfully Replaced"