<#
.Synopsis
install automatically Cloudistics Agent and Windows Drivers

.Description
The script finds the virtualCD that hosts the agent and drivers.
It either identifies automatically the OS on the agent and selects the appropriate agent and drivers or, if this
is not possible, allows the users to do the selection manually (and validates it automatically).
It continues by installing the agent and drivers corresponding to users input. 



#>


function Load-Assembly {
<#
.Synopsis
Avoids loading the same assembly multiple times

.Description
Check if an Assembly is loaded (and load it if it is missing)
The report switch results in displaying a message re the assembly status. The assembly is still loaded if not present already.
#>
     [CmdletBinding()]
     param(
          [Parameter(Mandatory = $true,ValueFromPipeline = $true)][ValidateNotNullOrEmpty()][String]$AssemblyName,
          [Switch]$Report = $false
     )

     if(([appdomain]::currentdomain.getassemblies() | Where {$_ -match $AssemblyName}) -eq $null){
          if($Report) {Write-Output "Loading $AssemblyName assembly.";}
          [Void] [System.Reflection.Assembly]::LoadWithPartialName($AssemblyName);
          return 1
     }
     else {
          if($Report) {Write-Output "$AssemblyName is already loaded.";}
          return -1
     }
}
function set-message{
<#
.synopsis
display message GUI element

.Description
Allows displaying a message (and make yes/no/cancel decisions) using Windows messageBox and customizing it via validation lists as needed

Note: do set-message .... | Out-Null if no output is needed, otherwise it will be returned in addition to the function using it :)
#>
param(
[Parameter(Mandatory=$true)]
$message,
$title=$null,
[ValidateSet("OKCancel","YesNo","OK","RetryCancel","AbortRetryIgnore","YesNoCancel")][string]
$buttons="OK",
[ValidateSet("Asterisk","Error","Exclamation","Hand","Information","Question","Stop","Warning")][string]
$icon="None",
$defaultButton="Button1"
)
Load-Assembly -Assemblyname "System.Windows.Forms"|out-null

return [System.Windows.Forms.MessageBox]::Show($message,$title,$buttons,$icon,$defaultButton)
}
#-----------------------------
Clear-Host
Write-Host @"
Cloudistics Windows Agent and Drivers Installation
--------------------------------------------------


"@ -ForegroundColor Green

$LinuxInstallInfo = @"
We thought that this may help...

How to install the Cloudistics Agent on Linux Applications 

1. Log into the instance

2. Mount the guest agent tools:
   # mkdir /mnt/cdrom
   # mount /dev/sr0 /mnt/cdrom

3. CentOS or RHEL:
   # yum localinstall /mnt/cdrom/cloudistics-guest-agent-{version}-1.x86_64.rpm -y

   where {version} is the guest agent version number

4. Ubuntu or other compatible Debian distros:
   # dpkg -i /mnt/cdrom/cloudistics-guest-agent_{version}.deb

   where {version} is the guest agent version number

Do you want to go ahead and install the Windows Cloudistics Agent and Drivers on this machine?
"@

$response = set-message -message $LinuxInstallInfo -title "Linux Installation Info" -buttons YesNo
if($response -eq 'No'){exit}

#region find cdrom with drivers
$cdroms = get-volume | where {$_.drivetype -eq 'CD-Rom'} | select-object -Property DriveLetter
$driverroot=$null
foreach ($cdrom in $cdroms){
$test= (get-childitem -Path "$($cdrom.driveletter):\" -ErrorAction SilentlyContinue).BaseName
if ($test){foreach($elem in $test){if($elem -like "cloudistics-guest-agent*"){$driverroot="$($cdrom.driveletter):\";break}}}
}
if($driverroot -eq $null){exit}
Write-Host "Agent `& Drivers Detected on cdrom drive $($driverroot)"
#endregion

#region select the operating system

$xos = Get-WmiObject -Class win32_operatingsystem | select-object caption,osarchitecture 
$os = "$($xos.caption) $($xos.osarchitecture)"
Write-Host "`n`nOperating System found: $($os)`nAttempting to identify drivers on $($driverroot)"

$agent = (get-childitem -Path $driverroot -File -ErrorAction SilentlyContinue).FullName 
$specfolder=$null
switch ($os){

{$_ -like "Microsoft Windows Server 2016*64*"}   {$specfolder='2k16'; $agentpath = $agent | where {$_ -like "cloudistics64*"};break}
{$_ -like "Microsoft Windows Server 2012 R2*64*"}{$specfolder='2k12R2'; $agentpath = $agent | where {$_ -like "cloudistics64*"};break}
{$_ -like "*Windows 10*64*"}                     {$specfolder='w10'; $agentpath = $agent | where {$_ -like "cloudistics64*"};break}

}

if(!($specfolder)){Write-Host "Could not determine the driver set to install.`n`nSelect an OS from the list"

#insert logic for manual selection

 $allos = @(
'cloudistics32',
'cloudistics64',
'2k12',
'2k12R2',
'2k16',
'2k3',
'2k8',
'2k8R2',
'w10',
'w7',
'w8',
'w8.1',
'xp'
)

$response = set-message -message "Could not identify the correct combination`n'Cloudistics agent'/'Windows Operating System'`nTry manually?" -buttons YesNo
if ($response -eq 'No'){Write-Host "`nExiting...";exit}

do{
[array]$choices = $allos | Out-GridView -Title "Select the correct Cloudistics agent and the OS of your VM; use <CTRL>/<Left Click> to select both" -PassThru -Verbose
if(!($choices)){exit}
$xmessage=''
$test = 0
if($choices.count -eq 2){$test++}else{$xmessage += "You have to choose one agent and one OS`n`r"}
[array]$xagent = $choices | where {$_ -like "cloudistics*"}
if($xagent.count -eq 1){$test++}else{$xmessage +="Select one agent only`n"}
if($xagent[0].IndexOf('32') -ge 0){$ostype='\x86';$osy=@('2k3','2k8','w10','w7','w8','w8.1','xp')} else{$ostype='\amd64';$osy=$allos}
[array]$xos    = $choices | where {$_ -notlike "cloudistics*"}
if($xos.count -eq 1){$test++}else{$xmessage +="Select one OS only`n"}
if($osy -contains $xos[0]){$test++}else{$xmessage += "Windows $($xos[0]) is 64 bit only`n"}
if(!([System.string]::IsNullOrEmpty($xmessage))){set-message -message $xmessage -icon Information}
}until($test -eq 4)

 $agentpath = $agent | where {$_ -like "*$($xagent[0])*"}
 $specfolder = "$($xos[0])$($ostype)"
 
 }

#endregion

#list infs
Write-Host "`n`nInstalling Cloudistics Agent:`n" -ForegroundColor Yellow
start-process -FilePath 'C:\windows\system32\msiexec.exe' -ArgumentList "/package $agentpath /passive" -Verb runas -Wait -WindowStyle Hidden
Write-Host "Done!"

$driversinf = (Get-childitem -Path $driverroot -Recurse -Filter *.inf).FullName
Write-Host "`n`nBeginning Driver Installation:`n" -ForegroundColor Yellow
$location = (Get-Location).path
$i=1
foreach ($xdrinf in $driversinf){
if($xdrinf -like "*$specfolder*"){
$drpath = Split-Path $xdrinf -Parent
$drinf =  Split-Path $xdrinf -leaf
Set-Location $drpath
Write-Host "$(($i++).tostring()): $drinf | $drpath ..." -NoNewline 

Start-Process -FilePath 'C:\windows\system32\pnputil.exe' -ArgumentList "/add-driver $drinf /install" -Verb runas -PassThru -Wait -WindowStyle Hidden |out-null
Write-Host "Done!"
}
}

Set-Location -Path $location

@"
How to install the Cloudistics Agent on Linux Applications 

1. Log into the instance

2. Mount the guest agent tools:
   # mkdir /mnt/cdrom
   # mount /dev/sr0 /mnt/cdrom

3. CentOS or RHEL:
   # yum localinstall /mnt/cdrom/cloudistics-guest-agent-{version}-1.x86_64.rpm -y
   where {version} is the guest agent version number

4. Ubuntu or other compatible Debian distros:
   # dpkg -i /mnt/cdrom/cloudistics-guest-agent_{version}.deb
   where {version} is the guest agent version number
"@

# SIG # Begin signature block
# MIID5wYJKoZIhvcNAQcCoIID2DCCA9QCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUSD5+TIW3mtiFK8TkOHupqsS9
# q9WgggIDMIIB/zCCAWigAwIBAgIQZXsLzuTF+b1PPg61Cp25RzANBgkqhkiG9w0B
# AQUFADAaMRgwFgYDVQQDDA9UdWRvciBTIFBvcGVzY3UwHhcNMTkwMTAyMjA0NDQ2
# WhcNMjMwMTAyMDAwMDAwWjAaMRgwFgYDVQQDDA9UdWRvciBTIFBvcGVzY3UwgZ8w
# DQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBALjpypo1UQY105CGk5zvG9HSc43PhQc7
# FNea/DcI38pFmp7NchlrU0xNUZ/h1nhGeq/NMJSw5Fn4o+qd8SLxXwyVkJ7AcjnK
# HjOI5oLhMxjB3qRfac8l6X1pPgEuastvaCzoApZujffETa4efUBwAFQ2dNvQXzSl
# F2Gj8RQ4TR/NAgMBAAGjRjBEMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQW
# BBTFffIWLCgxXQcJsO8nBrA0Pu8T2zAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcN
# AQEFBQADgYEAlzK6MAMn6k7kcB1a7q0a5y2bizV5msLGJUEZRMjq3oFcMMy40bYC
# yF9LkzaeT95t/CJ/jtNl/hwDLhOiyWOZPuW6FGHIr6oUV9klaQSH1Ch5b6YokcDo
# Qc0srcko00O+Xgoi5OLRxdQKld8jIwR4UsuImzuTM806O+VNEtz5kegxggFOMIIB
# SgIBATAuMBoxGDAWBgNVBAMMD1R1ZG9yIFMgUG9wZXNjdQIQZXsLzuTF+b1PPg61
# Cp25RzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGC
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUVKQwD4QaJOEpNkNhJ8Zfnib70gowDQYJKoZI
# hvcNAQEBBQAEgYBt+ky+X09jR/7tucqJXgphF6V/DWCheIXx8L2b6XHywrc0QWyC
# eOJoyBCz4ST5fPfTyW81ItQOeEzDm7dH+qBH1GfURtnxx0LiQ+r1sPBGidLJrzmS
# 8mYQE3QtHP6t6FO5pk9d1/JKpr5wsHNbwWUSXjGbon8hyXZ8C7AZpaZKCQ==
# SIG # End signature block
