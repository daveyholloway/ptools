#!/usr/bin/env pwsh
param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Hosts,
    [Alias('h')][switch]$Help,
    [Alias('v')][switch]$Version,
    [Alias('i')][switch]$Info
)

# ------------------------------------------------------------
# Simple reachability checker
# ------------------------------------------------------------

# Version constant
Set-Variable -Name SCRIPT_VERSION -Option Constant -Value "0.3"

# Normalize Hosts and support GNU-style long options passed positionally.
# $Hosts is an array due to ValueFromRemainingArguments; strip any --help/--version
# tokens and build a unified host list that accepts comma-separated or
# space-separated host names.
$rawHosts = @()
if ($Hosts) { $rawHosts = @($Hosts) }

$filtered = @()
foreach ($h in $rawHosts) {
    if ($h -eq '--help' -or $h -eq '-h') { $Help = $true; continue }
    if ($h -eq '--version' -or $h -eq '-v') { $Version = $true; continue }
    if ($h -eq '--info' -or $h -eq '-i') { $Info = $true; continue }
    $filtered += $h
}

$rawHosts = $filtered

function Show-Help {
@"
Reachability Check Script
-------------------------

Description:
    Pings one or more hosts (comma-separated) and prints a single line
    per host showing whether it is reachable.

Usage:
    ./pingcheck.ps1 "host1,host2,8.8.8.8"
    ./pingcheck.ps1 -h
    ./pingcheck.ps1 -v
    ./pingcheck.ps1 -i

Options:
    [hosts]         Comma-separated list of hostnames or IP addresses (positional).
    -h, --help      Show this help text.
    -v, --version   Show script version.
    -i, --info      Print a one-line short description of what the script does.

Version: $SCRIPT_VERSION
"@
}

# Handle help/version
if ($Help) {
    Show-Help
    return
}

if ($Version) {
    Write-Output "Version: $SCRIPT_VERSION"
    return
}

# Handle info
if ($Info) {
    Write-Output "Pings one or more hosts and reports reachability."
    return
}

# Validate hosts
if (-not $rawHosts -or $rawHosts.Count -eq 0) {
    Write-Output "Error: No hosts supplied. Provide a comma-separated list as the first argument, or use -h for help."
    return
}

# Split and trim host list (accept space-separated args and comma-separated values)
$HostList = @()
foreach ($entry in $rawHosts) {
    $parts = $entry -split ',' | ForEach-Object { $_.Trim() }
    foreach ($p in $parts) { if ($p) { $HostList += $p } }
}

# Resolve IPs and test connectivity, storing results to format output columns
$results = @()
foreach ($H in $HostList) {
    $ipStr = 'N/A'
    try {
        $addrs = [System.Net.Dns]::GetHostAddresses($H) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
        if ($addrs -and $addrs.Count -gt 0) { $ipStr = $addrs[0].IPAddressToString }
    } catch {
        $ipStr = 'N/A'
    }

    $reachable = Test-Connection -ComputerName $H -Count 1 -Quiet
    $results += [PSCustomObject]@{ Host = $H; IP = $ipStr; Reachable = $reachable }
}

# Compute column widths (use maximum lengths)
$maxHost = ($results | ForEach-Object { $_.Host.Length } | Measure-Object -Maximum).Maximum
$maxIP = ($results | ForEach-Object { $_.IP.Length } | Measure-Object -Maximum).Maximum
if (-not $maxHost) { $maxHost = 0 }
if (-not $maxIP) { $maxIP = 0 }

$fmt = "{0,-$maxHost}  {1,-$maxIP} : {2}"

foreach ($r in $results) {
    $status = if ($r.Reachable) { 'Reachable' } else { 'Unreachable' }
    $color = if ($r.Reachable) { 'Green' } else { 'Red' }
    $line = [string]::Format($fmt, $r.Host, $r.IP, $status)
    Write-Host $line -ForegroundColor $color
}
