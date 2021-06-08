Write-Output "Create deployment path"
$tempDir = "C:\Temp"
New-Item -Path $tempDir -ItemType directory -Force

Start-Transcript -Path C:\Temp\Bootstrap.log

$ErrorActionPreference = 'SilentlyContinue'

# Uninstall Internet Explorer
Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart

# Disabling IE Enhanced Security Configuration
Write-Host "Disabling IE Enhanced Security Configuration"
function Disable-ieESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
Disable-ieESC

# Installing tools
workflow ClientTools_01 
{
    $chocolateyAppList = "azure-cli,az.powershell,kubernetes-cli,vcredist140"
    Parallel {
        InlineScript {
            if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false)
            {
                try{
                    choco config get cacheLocation
                }catch{
                    Write-Output "Chocolatey not detected, trying to install now"
                    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                }
            }
        
            if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false){   
                Write-Output "Chocolatey Apps Specified"  
                
                $appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }
        
                foreach ($app in $appsToInstall)
                {
                    Write-Host "Installing $app"
                    & choco install $app /y | Write-Output
                }
            }
        }
        # Downloading Azure Data Studio and azdata CLI
        Write-Output "Downloading Azure Data Studio and azdata CLI"
        Write-Output "`n"
        Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile "C:\Temp\azuredatastudio.zip"
        Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "C:\Temp\AZDataCLI.msi"
        Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla_cx/terraform/scripts/DC_Cleanup.ps1" -OutFile "C:\Temp\DC_Cleanup.ps1"
        Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla_cx/terraform/scripts/DC_Deploy.ps1" -OutFile "C:\Temp\DC_Deploy.ps1"
        Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla_cx/terraform/scripts/dataController.json" -OutFile "C:\Temp\dataController.json"
        Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla_cx/terraform/scripts/dataController.parameters.json" -OutFile "C:\Temp\dataController.parameters.json"     
        Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/capi_data_sqlmi/img/jumpstart_wallpaper.png" -OutFile "C:\Temp\wallpaper.png"
    }
}

ClientTools_01 | Format-Table

workflow ClientTools_02
{
    #Run commands in parallel.
    Parallel
    {
        InlineScript {
            Expand-Archive C:\Temp\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
            Start-Process msiexec.exe -Wait -ArgumentList '/I C:\Temp\AZDataCLI.msi /quiet'
        }
    }
}

ClientTools_02 | Format-Table 

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# Creating DataServicesLogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\DataServicesLogonScript.ps1'
Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User "$env:adminUsername" -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

#Stopping log for Bootstrap.ps1
Stop-Transcript
