#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Displays group memberships for one or more users.

.DESCRIPTION
    Expands comma-separated user names and enumerates group memberships
    for each user. Outputs one line per user/group membership sorted by
    user then group. Supports standard metadata parameters (-Help, -Version, -Desc).

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
    [string[]]$Users
)

# --- Metadata handling ---
if ($Help) {
    Get-Help -Detailed $MyInvocation.MyCommand.Path
    exit 0
}

if ($Version) {
    "check-membership version 1.0.0"
    exit 0
}

if ($Desc) {
    "Displays group memberships for one or more users."
    exit 0
}

if (-not $Users -or $Users.Count -eq 0) {
    Write-Error "Please specify one or more users (comma- or space-separated)."
    exit 1
}

# Expand comma-separated entries into a flat list
$UserList = @()
foreach ($entry in $Users) {
    $parts = $entry -split ',' | ForEach-Object { $_.Trim() }
    foreach ($p in $parts) {
        if ($p) { $UserList += $p }
    }
}

if ($UserList.Count -eq 0) {
    Write-Error "No valid users supplied after parsing."
    exit 1
}

$adModule = Get-Module -ListAvailable -Name ActiveDirectory
if ($adModule) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop | Out-Null
    } catch {
        $adModule = $null
    }
}

$results = @()

foreach ($user in $UserList) {
    $groups = @()
    $errorMessage = $null

    if ($adModule) {
        try {
            $groups = Get-ADPrincipalGroupMembership -Identity $user -ErrorAction Stop |
                      Select-Object -ExpandProperty Name
        } catch {
            $errorMessage = $_.Exception.Message
        }
    } else {
        try {
            $localUser = Get-LocalUser -Name $user -ErrorAction Stop
            $groups = Get-LocalGroup |
                Where-Object {
                    try {
                        Get-LocalGroupMember -Group $_.Name -ErrorAction Stop |
                            Where-Object { $_.Name -eq $user -or $_.SID -eq $user }
                    } catch {
                        $false
                    }
                } |
                Select-Object -ExpandProperty Name
        } catch {
            $errorMessage = $_.Exception.Message
        }
    }

    if ($errorMessage) {
        $results += [PSCustomObject]@{
            User   = $user
            Group  = '<error>'
            Detail = $errorMessage
        }
        continue
    }

    if (-not $groups -or $groups.Count -eq 0) {
        $results += [PSCustomObject]@{
            User   = $user
            Group  = '<none>'
            Detail = ''
        }
        continue
    }

    foreach ($group in $groups | Sort-Object) {
        $results += [PSCustomObject]@{
            User   = $user
            Group  = $group
            Detail = ''
        }
    }
}

$results | Sort-Object User, Group | Format-Table -AutoSize
