<#
.SYNOPSIS
    Checks for pending Windows updates on remote servers.

.DESCRIPTION
    Connects to remote Windows servers via PowerShell remoting and checks:
    - Whether pending Windows updates exist
    - Days since last update
    - Server uptime in days
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

    [Parameter(Mandatory=$false)]
    [string]$Servers,

    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential = $null
)

# --- Metadata handling ---
if ($Help) {
    Get-Help -Detailed $MyInvocation.MyCommand.Path
    exit
}

if ($Version) {
    "check-updates version 1.0.0"
    exit
}

if ($Desc) {
    "Checks for pending Windows updates on remote servers."
    exit
}

# Prompt for credentials if servers specified but credentials not supplied
if ($Servers -and -not $Credential) {
    $Credential = Get-Credential -Message "Enter credentials for remote servers"
}

# Split comma-separated list
$ServerList = $Servers -split "," | ForEach-Object { $_.Trim() }

foreach ($Server in $ServerList) {

    # Test remote connectivity first
    if (-not (Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
        Write-Output "$Server : unable to connect"
        continue
    }

    try {
        $Result = Invoke-Command -ComputerName $Server -Credential $Credential -ScriptBlock {

            # --- Windows Update Check ---
            try {
                $Session  = New-Object -ComObject Microsoft.Update.Session
                $Searcher = $Session.CreateUpdateSearcher()
                $Results  = $Searcher.Search("IsInstalled=0 and IsHidden=0")

                if ($Results.Updates.Count -gt 0) {
                    $UpdateStatus = "updates outstanding"
                } else {
                    $UpdateStatus = "up to date"
                }
            }
            catch {
                $UpdateStatus = "unable to connect"
            }

            # --- Days Since Last Update ---
            try {
                $HotFixes = Get-HotFix | Where-Object { $_.InstalledOn -ne $null }
                if ($HotFixes) {
                    $LastUpdate = ($HotFixes | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn
                    $DaysSinceUpdate = (New-TimeSpan -Start $LastUpdate -End (Get-Date)).Days
                } else {
                    $DaysSinceUpdate = "unknown"
                }
            }
            catch {
                $DaysSinceUpdate = "unknown"
            }

            # --- Uptime ---
            try {
                $OS = Get-WmiObject Win32_OperatingSystem
                $Boot = $OS.LastBootUpTime
                $BootTime = [Management.ManagementDateTimeConverter]::ToDateTime($Boot)
                $UptimeDays = (New-TimeSpan -Start $BootTime -End (Get-Date)).Days
            }
            catch {
                $UptimeDays = "unknown"
            }

            return [PSCustomObject]@{
                UpdateStatus    = $UpdateStatus
                DaysSinceUpdate = $DaysSinceUpdate
                UptimeDays      = $UptimeDays
            }

        } -ErrorAction Stop

        Write-Output ("{0} : {1} | last update: {2} days | uptime: {3} days" -f `
            $Server, $Result.UpdateStatus, $Result.DaysSinceUpdate, $Result.UptimeDays)

    }
    
catch {
    Write-Output "$Server : unable to connect"
    Write-Output "Error: $($_.Exception.Message)"
    }
}
