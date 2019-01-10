cls
Write-Host @"
Cloudistics Agent and Drivers Installation
------------------------------------------


"@ -ForegroundColor Green

$cdroms = get-volume | where {$_.drivetype -eq 'CD-Rom'} | select-object -Property DriveLetter
$driverroot=$null
foreach ($cdrom in $cdroms){
$test= (get-childitem -Path "$($cdrom.driveletter):\" -ErrorAction SilentlyContinue).BaseName
if ($test){foreach($elem in $test){if($elem -like "cloudistics-guest-agent*"){$driverroot="$($cdrom.driveletter):\";break}}}
}
if($driverroot -eq $null){exit}
Write-Host "Agent `& Drivers Detected on cdrom drive $($driverroot)"
$xos = Get-WmiObject -Class win32_operatingsystem | select-object caption,osarchitecture 
$os = "$($xos.caption) $($xos.osarchitecture)"
Write-Host "Operating System found: $($os)"
$agent = (get-childitem -Path $driverroot -File -ErrorAction SilentlyContinue).FullName 
if ($os -like "*Server 201*64*"){$specfolder='2k16'; $agentpath = $agent | where {$_ -like "cloudistics64*"}}
if ($os -like "*Server Standard*64*"){$specfolder='2k16'; $agentpath = $agent | where {$_ -like "cloudistics64*"}}
if ($os -like "*Windows 10*64*"){$specfolder='w10'; $agentpath = $agent | where {$_ -like "cloudistics64*"}}
if(!($specfolder)){Write-Host "Could not determine the driver set to install. Exiting...";exit}
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


