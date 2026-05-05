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

function Write-Rainbow {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [ValidateSet("Left", "Right", "Center")]
        [string]$Justify = "Left",

        [int]$Width = $Host.UI.RawUI.WindowSize.Width

    )

    $colors = @(
        'Red',
        'Yellow',
        'Green',
        'Cyan',
        'Blue',
        'Magenta'
    )

    # Calculate padding based on justification
    $padding = switch ($Justify) {
        "Left"   { 0 }
        "Right"  { $Width - $Text.Length }
        "Center" { [math]::Floor(($Width - $Text.Length) / 2) }
    }

    # Print padding first (invisible, no colour)
    if ($padding -gt 0) {
        Write-Host (" " * $padding) -NoNewline
    }

    # Print rainbow characters
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $color = $colors[$i % $colors.Count]
        Write-Host $Text[$i] -NoNewline -ForegroundColor $color
    }

    Write-Host
}


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

Clear-Host
Write-Rainbow "Daves PowerShell Toolkit" Center
Write-Host

Write-Host "Available tools:`n" -ForegroundColor Cyan

foreach ($script in $scripts) {
    $toolDesc = @(& $script -Desc 2>&1 | Select-Object -Skip 0) | Out-String
    $toolDesc = $toolDesc.Trim()
    if (-not $toolDesc) { $toolDesc = "(No description provided)" }

    "{0,-25} {1}" -f $script.BaseName, $toolDesc
    
}
