<#
.Synopsis
Version: 1.0
Created on:   27/03/2024
Created by:   Louis Hoorens
Filename:     LocalUsers.ps1

Simple script to add domain users as administrators on the device as well as removing administrator permissions for the end user. For this the whoami command is used in conjunction with an exclusion list.

#### Win32 app Commands ####

Install: (uninstall is the same, just haven't gotten around to creating one)
powershell.exe -executionpolicy bypass -file .\LocalUsers.ps1

Detection:
File/Folder Exists
Path : C:\TempIntune
File : AdminManagementLog.txt
#>

########################################################################################################
#                       Change the variables at the start of the script                                #
########################################################################################################
# User Principal Names (UPNs) of AzureAD users to be added to the local administrators group
$userUPNs = @(
    'WhoTookMyName6@contoso.com',
    'funny.guy@contoso.be',
    'admin@contoso.be'
)

# Define the required group (Open CMD "net localgroup" to list all of them)
$newGroup = 'gebruikers'

# Specify the accounts to exclude from removal
$excludedAccounts = @("WhoTookMyName6", "funny.guy", "admin", "Administrator")

# Define the directory and file path for logging  
$directoryPath = "C:\tempIntune"
$logFilePath = Join-Path -Path $directoryPath -ChildPath "AdminManagementLog.txt"

# Create the directory if it doesn't exist
if (-not (Test-Path -Path $directoryPath)) {
    New-Item -Path $directoryPath -ItemType Directory
}

# Initialize the log file
"" | Out-File -FilePath $logFilePath

# Function to append output to the log file
function Write-Log {
    Param ([string]$logEntry)
    Add-Content -Path $logFilePath -Value $logEntry
}

# Function to run a command in an elevated CMD prompt
function Run-InElevatedCMD {
    param (
        [Parameter(Mandatory)]
        [string]$Command
    )

    Start-Process cmd.exe -ArgumentList "/c $Command" -Verb RunAs -WindowStyle Hidden -Wait
}

# Run command in an elevated CMD prompt to add users to the administrators group dynamically
foreach ($userUPN in $userUPNs) {
    $domainUser = "AzureAD\" + $userUPN
    $commandToAddUser = "net localgroup administrators `"$domainUser`" /add"
    Run-InElevatedCMD -Command $commandToAddUser
    # Extract username from UPN for logging
    $username = $userUPN -replace '.*@', ''
    Write-Log "Added $username to administrators group."
}

# Function to manage user group memberships based on exclusion list
function Manage-UserGroups {
    $currentUser = whoami
    $excluded = $False

    # Check if current user is in the excludedAccounts list
    foreach ($account in $excludedAccounts) {
        if ($currentUser -like "*\$account") {
            $excluded = $True
            Write-Log "User $currentUser is excluded from group management."
            break
        }
    }

    # If not excluded, modify user group memberships
    if (-not $excluded) {
        try {
            # Add to "gebruikers" group
            $cmdAddToGebruikers = "net localgroup $newGroup $currentUser /add"
            Run-InElevatedCMD -Command $cmdAddToGebruikers
            Write-Log "Added $currentUser to $newGroup group."

            # Remove from "administrators" group
            $cmdRemoveFromAdmins = "net localgroup administrators $currentUser /delete"
            Run-InElevatedCMD -Command $cmdRemoveFromAdmins
            Write-Log "Removed $currentUser from administrators group."
        } catch {
            Write-Log "Error managing groups for $currentUser."
        }
    }
}

# Invoke the Manage-UserGroups function to check and modify the current user's group memberships
Manage-UserGroups

# Finalize script execution with logging
Write-Log "Admin group management script completed."
