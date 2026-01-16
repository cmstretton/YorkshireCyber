# Cyber Essentials Plus Auditor & CSV Exporter
# Run as Administrator

$Report = @()
$InventoryPath = "$env:USERPROFILE\Desktop\CE_Software_Inventory.csv"

Write-Host "--- Starting CE+ Audit and CSV Export ---" -ForegroundColor Cyan

# 1. Core Controls Audit (OS, Firewall, Updates, Admins)
$OS = Get-CimInstance Win32_OperatingSystem
$IsEOL = ($OS.Caption -like "*Windows 10*" -or $OS.Version -lt "10.0.22000")
$LastUpdate = (New-Object -ComObject Microsoft.Update.AutoUpdate).Results.LastSearchSuccessDate
$DaysSinceUpdate = if ($LastUpdate) { ((Get-Date) - $LastUpdate).Days } else { 999 }

$Report += [PSCustomObject]@{
    Control     = "OS & Patching"
    Status      = if ($IsEOL -or $DaysSinceUpdate -gt 14) { "FAIL" } else { "Pass" }
    Details     = "OS: $($OS.Caption). Last Update: $DaysSinceUpdate days ago."
}

# 2. Comprehensive Software Inventory
Write-Host "Gathering full software inventory..." -ForegroundColor Yellow
$Keys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"

$FullInventory = Get-ItemProperty $Keys -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -ne $null } | 
    Select-Object @{N='Software_Name';E={$_.DisplayName}}, 
                  @{N='Version';E={$_.DisplayVersion}}, 
                  @{N='InstallDate';E={$_.InstallDate}},
                  @{N='Publisher';E={$_.Publisher}} |
    Sort-Object Software_Name

# Export to CSV
$FullInventory | Export-Csv -Path $InventoryPath -NoTypeInformation
Write-Host "Full software list exported to: $InventoryPath" -ForegroundColor Green

# 3. Check for specific "Audit Fail" software
$Blacklist = "Office 2010|Office 2013|Adobe Reader [0-9]|Java [0-7]|Internet Explorer"
$EOLApps = $FullInventory | Where-Object { $_.Software_Name -match $Blacklist }

$Report += [PSCustomObject]@{
    Control     = "Software EOL"
    Status      = if ($EOLApps) { "FAIL" } else { "Pass" }
    Details     = if ($EOLApps) { "Found $($EOLApps.Count) unsupported apps." } else { "No common EOL apps found." }
}

# Output Summary to Screen
Write-Host "`n--- CE+ Compliance Summary ---" -ForegroundColor Cyan
$Report | Format-Table -AutoSize
