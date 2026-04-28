<#
.SYNOPSIS
    Adds the current ptools folder to the user's PATH.

.DESCRIPTION
    Detects the folder this script is running from and appends it to the
    user's PATH environment variable if it is not already present.

.VERSION
    1.0.0
#>

param(
    [switch]$Help,
    [switch]$Version,
    [switch]$Desc
)

# --- Metadata handling ---
if ($Help) {
    Get-Help -Detailed $MyInvocation.MyCommand.Path
    exit
}

if ($Version) {
    "add-ptools version 1.0.0"
    exit
}

if ($Desc) {
    "Adds the current ptools folder to the user's PATH."
    exit
}

# --- Determine script folder ---
$folder = $PSScriptRoot
if (-not $folder) {
    # Fallback for older hosts
    $folder = Split-Path -Parent $MyInvocation.MyCommand.Path
}

Write-Host "Detected ptools folder: $folder"

# --- Read existing PATH ---
$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
$parts = $oldPath -split ";" | Where-Object { $_ -ne "" }

# --- Check for duplicates ---
if ($parts -contains $folder) {
    Write-Host "Already in PATH. No changes made." -ForegroundColor Yellow
    exit 0
}

# --- Append and save ---
$newPath = ($parts + $folder) -join ";"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

Write-Host "Added to PATH successfully." -ForegroundColor Green
Write-Host "Restart PowerShell to apply the change."
