#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks whether one or more hosts are reachable.

.DESCRIPTION
    Pings one or more hosts (comma- or space-separated) and prints a line
    per host showing hostname, resolved IPv4 address, and reachability.
    Supports standard metadata parameters (-Help, -Version, -Desc).

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

    [Parameter(Position=0, Mandatory=$false)]
    [string[]]$Hosts
)

# --- Metadata handling ---
if ($Help) {
    Get-Help -Detailed $MyInvocation.MyCommand.Path
    exit
}

if ($Version) {
    "check-reachable version 1.0.0"
    exit
}

if ($Desc) {
    "Checks whether one or more hosts are reachable on the network."
    exit
}

# --- Script logic ---
if (-not $Hosts -or $Hosts.Count -eq 0) {
    Write-Error "Please specify one or more hosts (comma- or space-separated)."
    exit 1
}

# Expand comma-separated entries into a flat list
$HostList = @()
foreach ($entry in $Hosts) {
    $parts = $entry -split ',' | ForEach-Object { $_.Trim() }
    foreach ($p in $parts) {
        if ($p) { $HostList += $p }
    }
}

if ($HostList.Count -eq 0) {
    Write-Error "No valid hosts supplied after parsing."
    exit 1
}

# Resolve IPs and test connectivity
$results = foreach ($H in $HostList) {
    $ipStr = 'N/A'
    try {
        $addrs = [System.Net.Dns]::GetHostAddresses($H) |
                 Where-Object { $_.AddressFamily -eq 'InterNetwork' }
        if ($addrs -and $addrs.Count -gt 0) {
            $ipStr = $addrs[0].IPAddressToString
        }
    } catch {
        $ipStr = 'N/A'
    }

    $reachable = Test-Connection -ComputerName $H -Count 1 -Quiet -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        Host      = $H
        IP        = $ipStr
        Reachable = $reachable
    }
}

# Compute column widths
$maxHost = ($results.Host | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
$maxIP   = ($results.IP   | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

$fmt = "{0,-$maxHost}  {1,-$maxIP} : {2}"

# Output results
foreach ($r in $results) {
    $status = if ($r.Reachable) { 'Reachable' } else { 'Unreachable' }
    $color  = if ($r.Reachable) { 'Green' } else { 'Red' }
    $line   = [string]::Format($fmt, $r.Host, $r.IP, $status)
    Write-Host $line -ForegroundColor $color
}
