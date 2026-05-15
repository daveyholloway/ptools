#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Finds AD computer accounts by name or description.

.DESCRIPTION
    Searches Active Directory for computers whose names or descriptions contain any
    of the provided comma-separated name or description values. Outputs a table
    with computer name and description. Supports standard metadata parameters
    (-Help, -Version, -Desc).

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
    [string[]]$Name,

    [Parameter(Position=1, Mandatory=$false)]
    [string[]]$Description
)

# --- Metadata handling ---
if ($Help) {
    Get-Help -Detailed $MyInvocation.MyCommand.Path
    exit 0
}

if ($Version) {
    "find-computers version 1.0.0"
    exit 0
}

if ($Desc) {
    "Finds AD computer accounts by name or description."
    exit 0
}

if (-not $Name -and -not $Description) {
    Write-Error "Please specify one or more names (-Name) or descriptions (-Description), comma- or space-separated."
    exit 1
}

function Expand-CommaSeparatedValues {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Values
    )

    $expanded = @()
    foreach ($entry in $Values) {
        $parts = $entry -split ',' | ForEach-Object { $_.Trim() }
        foreach ($part in $parts) {
            if ($part) { $expanded += $part }
        }
    }

    return $expanded
}

$NameList = if ($Name) { Expand-CommaSeparatedValues -Values $Name } else { @() }
$DescriptionList = if ($Description) { Expand-CommaSeparatedValues -Values $Description } else { @() }

if ($NameList.Count -eq 0 -and $DescriptionList.Count -eq 0) {
    Write-Error "No valid names or descriptions supplied after parsing."
    exit 1
}

$adModule = Get-Module -ListAvailable -Name ActiveDirectory
if (-not $adModule) {
    Write-Error "ActiveDirectory module is not available. Install RSAT/AD DS Tools or run on a domain-joined management host."
    exit 1
}

try {
    Import-Module ActiveDirectory -ErrorAction Stop | Out-Null
} catch {
    Write-Error "Failed to import ActiveDirectory module: $($_.Exception.Message)"
    exit 1
}

function Build-LikeFilter {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Values,

        [Parameter(Mandatory=$true)]
        [string]$PropertyName
    )

    $clauses = @()
    foreach ($value in $Values) {
        $escaped = $value.Replace("'", "''")
        $clauses += "$PropertyName -like '*$escaped*'"
    }

    return ($clauses -join ' -or ')
}

$results = @()

if ($NameList.Count -gt 0) {
    $nameFilter = Build-LikeFilter -Values $NameList -PropertyName 'Name'
    try {
        $results += Get-ADComputer -Filter $nameFilter -Properties Description -ErrorAction Stop
    } catch {
        Write-Error "Failed to search AD by computer name: $($_.Exception.Message)"
        exit 1
    }
}

if ($DescriptionList.Count -gt 0) {
    $descFilter = Build-LikeFilter -Values $DescriptionList -PropertyName 'Description'
    try {
        $results += Get-ADComputer -Filter $descFilter -Properties Description -ErrorAction Stop
    } catch {
        Write-Error "Failed to search AD by description: $($_.Exception.Message)"
        exit 1
    }
}

$results = $results | Sort-Object Name -Unique

$results | Select-Object @{Name='Name';Expression={$_.Name}}, @{Name='Description';Expression={ if ($_.Description) { $_.Description } else { '' } }} | Format-Table -AutoSize
