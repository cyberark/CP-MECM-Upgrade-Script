# Script breakdown

## Define arguments
Before you run the script, define the basic arguments:

Add the names given to the upgrade (.iss) files, for example, silent_pre_121.iss and silent_post_121.iss

Define your CCP's IP address, AppID, and Query


```
Set-PSDebug -Trace 0
$Current_Version = "12.6"
$Pre_121_Upgrade_File = "silent_pre_121.iss"
$Post_121_Upgrade_File = "silent_post_121.iss"
 
$CCP_IP = "10.20.74.162"
$CCP_Query = "Safe=SafeMassUpg;Object=UserMassUpg"
$CCP_AppID = "AppMassUpg"
```

## Create the credential file
The CreateCredFile function creates a credential file using the CreateCredFile utility.
The function:

1. Invokes a request to the CCP to receive the credentials of the privileged user that will be used to perform the upgrade on each CP.

2. Uses the CreateCredFile utility to create an encrypted credential file that will be used in the upgrade process.

3. Removes the response variable value.



### Create credfile
```
function CreateCredFile {
 
                  
    $response = Invoke-RestMethod "$($CCP_IP)/aimwebservice/api/accounts?$($CCP_Query)&appid=$($CCP_AppID)"
   
    # Run CreateCredFile util
    & $PSScriptRoot\CreateCredFile.exe $PSScriptRoot\user.cred Password /Username $response.username /Password $response.content /Hostname /EntropyFile
 
    Remove-Variable $response
}
```

## Determine current installation and upgrade CP
Next, the script runs the installCP function. 

This function:
1. Detects the CP version currently installed on the server.

2. Chooses the relevant upgrade file based on the detected CP version and runs the upgrade.

3. Deletes the credential file from the server.

### Determine current installation
```
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
    catch {
        $CP_Version_Short = "0.0"
    }
 
     
    # Check if the CP version is later or ealier than CP version 12.1
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
```

## Verify installation
After the upgrade is finished, the script checks that the CP service (**CyberArk Application Password Provider**) is up and running.

If the service is running, the script creates a flag file for the MECM to verify that the upgrade was successful.

If the service is not running, no flag file is created.

### Verify installation
```
function VerifyInstallation {
    $ServiceName = 'CyberArk Application Password Provider'
    $arrService = Get-Service -Name $ServiceName
    Start-Service $ServiceName
    Start-Sleep -seconds 60
    $arrService.Refresh()
    if ($arrService.Status -eq 'Running')
    {
       ni $PSScriptRoot\CP_Running
    }
    elseif (Test-Path $PSScriptRoot\CP_Running = True)
    {
        Remove-Item $PSScriptRoot\CP_Running
    }
}
```
