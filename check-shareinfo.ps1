<#
.SYNOPSIS
    Retrieves filesystem shares from a remote server and displays NTFS permissions.

.DESCRIPTION
    Connects to a remote Windows server via CIM, enumerates filesystem shares,
    and displays effective NTFS permissions for each share. Highlights shares
    where Everyone has FullControl access.
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
    [string]$Server,

    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential
)

# --- Metadata handling (exit early, before any other operations) ---
if ($Help) {
    Get-Help -Detailed $MyInvocation.MyCommand.Path
    exit 0
}

if ($Version) {
    "check-shareinfo version 1.0.0"
    exit 0
}

if ($Desc) {
    "Retrieves filesystem shares from a remote server and displays NTFS permissions."
    exit 0
}

# Prompt for credentials if server specified but credentials not supplied
if ($Server -and -not $Credential) {
    $Credential = Get-Credential -Message "Enter credentials for $Server"
}

Write-Host "`nConnecting to $Server..." -ForegroundColor Cyan

# Create CIM session with credentials
$cimSession = New-CimSession -ComputerName $Server -Credential $Credential

# Get shares via CIM (works remotely) - only filesystem shares
$shares = Get-CimInstance -CimSession $cimSession -ClassName Win32_Share | Where-Object { $_.Type -eq 0 }

foreach ($share in $shares) {

    $highlight = $false

    try {
        # Pull NTFS ACL from remote machine
        $acl = Invoke-Command -ComputerName $Server -Credential $Credential -ScriptBlock {
            param($path)
            $aclObj = Get-Acl -Path $path
            $aclObj.Access | Select-Object @{Name='Identity';Expression={$_.IdentityReference.ToString()}}, @{Name='Rights';Expression={$_.FileSystemRights.ToString()}}, @{Name='Type';Expression={$_.AccessControlType.ToString()}}
        } -ArgumentList $share.Path

        # Check for Everyone with FullControl
        foreach ($ace in $acl) {
            if ($ace.Identity -eq "Everyone" -and $ace.Rights -like "*FullControl*") {
                $highlight = $true
                break
            }
        }

        Write-Host "`n===============================" -ForegroundColor $(if ($highlight) { "Red" } else { "White" })
        Write-Host "Share Name : $($share.Name)" -ForegroundColor $(if ($highlight) { "Red" } else { "White" })
        Write-Host "Path       : $($share.Path)" -ForegroundColor $(if ($highlight) { "Red" } else { "White" })
        Write-Host "===============================" -ForegroundColor $(if ($highlight) { "Red" } else { "White" })

        Write-Host "Effective Permissions:" -ForegroundColor Yellow

        foreach ($ace in $acl) {
            Write-Host "$($ace.Identity) : $($ace.Rights) ($($ace.Type))"
        }
    }
    catch {
        Write-Host "`n==============================="
        Write-Host "Share Name : $($share.Name)"
        Write-Host "Path       : $($share.Path)"
        Write-Host "==============================="
        Write-Host "Unable to read NTFS permissions for $($share.Path)" -ForegroundColor Red
    }
}

# Clean up CIM session
Remove-CimSession -CimSession $cimSession
