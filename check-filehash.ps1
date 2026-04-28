<#
.SYNOPSIS
    Calculates a file hash and optionally compares it to an expected value.

.DESCRIPTION
    Extends Get-FileHash by adding a --Compare parameter and standard metadata
    parameters (-Help, -Version, -Desc).

.VERSION
    1.0.0

#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Help,

    [Parameter(Mandatory=$false)]
    [switch]$Version,

    [Parameter(Mandatory=$false)]
    [switch]$Desc,

    [Parameter(Mandatory=$false, Position=0)]
    [string]$Path,

    [Parameter(Mandatory=$false)]
    [ValidateSet("SHA1","SHA256","SHA384","SHA512","MD5")]
    [string]$Algorithm = "SHA256",

    [Parameter(Mandatory=$false)]
    [string]$Compare
)

# --- Metadata handling ---
if ($Help) {
    Get-Help -Detailed $MyInvocation.MyCommand.Path
    exit
}

if ($Version) {
    "check-filehash version 1.0.0"
    exit
}

if ($Desc) {
    "Calculates a file hash and optionally compares it to an expected value."
    exit
}

# --- Script logic ---
if ([string]::IsNullOrEmpty($Path)) {
    Write-Error "Please specify a file path to check."
    exit 1
}

if (-not (Test-Path $Path)) {
    Write-Error "File not found: $Path"
    exit 1
}

$hashObj = Get-FileHash -Path $Path -Algorithm $Algorithm

if ($Compare) {
    $expected = $Compare.ToUpper().Replace(" ", "")
    $actual   = $hashObj.Hash.ToUpper().Replace(" ", "")

    if ($expected -eq $actual) {
        Write-Host "✔ Hash matches ($Algorithm)" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "✘ Hash does NOT match ($Algorithm)" -ForegroundColor Red
        Write-Host "Expected: $expected"
        Write-Host "Actual:   $actual"
        exit 2
    }
}

# Default behaviour: output the hash object
$hashObj
