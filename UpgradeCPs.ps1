#This script uses the parameters below to determine which upgrade file to use to upgrade to the selected version
#It uses the CCP parameters to retrieve the credentials for the credential file, and uses this credential file to upgrade CPs on Windows machines
$Current_Version = "12.6"
$Pre_121_Upgrade_File = "silent_pre_121.iss"
$Post_121_Upgrade_File = "silent_post_121.iss"
 
$CCP_IP = "10.20.74.162"
$CCP_Query = "Safe=SafeMassUpg;Object=UserMassUpg"
$CCP_AppID = "AppMassUpg"
 
 
function InstallCP {
    try
    {
        $CPPath =  Get-ItemPropertyValue 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{718BA81E-A95C-4112-86A1-40F0FE8BDE9E}'  -name InstallLocation -ErrorAction Stop
        $CPPath = $CPPath + "\ApplicationPasswordProvider\AppProvider.exe"
     
       #Check that the CP exists and, if so, what the version number is
       if (Test-Path -Path $CPPath -PathType Leaf){
            $CP_Version = (Get-Command $CPPath).FileVersionInfo.FileVersion.split(".")
            #Create a short version of the CP_Version
            $CP_Version_Short = "$($CP_Version[0]).$($CP_Version[1])"
        }
        else {
            exit(1)
        }
    }
    catch
    {
        $CP_Version_Short = "0.0"
    }
 
     
    #Check if the CP version is later or ealier than CP version 12.1
    if ($CP_Version_Short -eq $Current_Version){
        exit(1)
    }
    elseif ($CP_Version_Short -lt "12.1" -and $CP_Version_Short -ne "0.0" ){
        $Upgrade_Iss = $Pre_121_Upgrade_File
    }
    elseif ($CP_Version_Short -ge "12.1") {
        $Upgrade_Iss = $Post_121_Upgrade_File
    }
    else {
        exit(1)
    }
 
 
    #Run the install command using the specified ISS file
    $arglist = "/s /f1$($PSScriptRoot)\$($Upgrade_Iss) $($PSScriptRoot)\user.cred"
    $installPath = "$($PSScriptRoot)\setup.exe"
    Start-Process -FilePath $installPath -ArgumentList $arglist -Wait
     
    #Delete the credential file when the installation is complete
    Del "$($PSScriptRoot)\user.cred*"
}
 
 
function CreateCredFile {
 
                  
    $response = Invoke-RestMethod "$($CCP_IP)/aimwebservice/api/accounts?$($CCP_Query)&appid=$($CCP_AppID)"
   
    # Run the CreateCredFile utility
    & $PSScriptRoot\CreateCredFile.exe $PSScriptRoot\user.cred Password /Username $response.username /Password $response.content /Hostname /EntropyFile
}
 
#Verify that the CP was installed successfully
function VerifyInstallation {
    $ServiceName = 'CyberArk Application Password Provider'
    $arrService = Get-Service -Name $ServiceName
    Start-Service $ServiceName
    Start-Sleep -seconds 60
    $arrService.Refresh()
    if ($arrService.Status -eq 'Running')
    {
       ni PSScriptRoot\CP_Running
    }
    elseif (Test-Path PSScriptRoot\CP_Running = True)
    {
        Remove-Item PSScriptRoot\CP_Running
    }
}
 
#Main Code
 
CreateCredFile
InstallCP
VerifyInstallation
