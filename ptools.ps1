<#
.SYNOPSIS
    Lists all toolkit scripts and their descriptions.

.DESCRIPTION
    Scans the current folder for .ps1 scripts and runs each with -Desc to
    display a summary of what they do.

.VERSION
    1.0.0
#>

param(
    [switch]$Help,
    [switch]$Version,
    [switch]$Desc
)

if ($Help) {
    Get-Help -Detailed $MyInvocation.MyCommand.Path
    exit
}

if ($Version) {
    "ptools version 1.0.0"
    exit
}

if ($Desc) {
    "Lists all toolkit scripts and their descriptions."
    exit
}

$folder = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = Get-ChildItem -Path $folder -Filter *.ps1 | Where-Object {
    $_.Name -ne "ptools.ps1"
}

Write-Host "Available tools:`n" -ForegroundColor Cyan

foreach ($script in $scripts) {
    $toolDesc = @(& $script -Desc 2>&1 | Select-Object -Skip 0) | Out-String
    $toolDesc = $toolDesc.Trim()
    if (-not $toolDesc) { $toolDesc = "(No description provided)" }

    "{0,-25} {1}" -f $script.BaseName, $toolDesc
    
}
