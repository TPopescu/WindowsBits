function get-fileName {
param ($initialDirectory = "c:\",[switch]$savefile,$powerschemename)

 $checkAssembly = ([System.AppDomain]::CurrentDomain.GetAssemblies() | where {$_.location -like "*System.Windows.Forms*"}).Location
 if(!($checkAssembly)){[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null}

 $FileDialog = New-Object System.Windows.Forms.OpenFileDialog
 $Title="Importing Power Scheme"
 if($savefile.IsPresent){
 $Filedialog = New-Object System.Windows.Forms.SaveFileDialog
 $Title = "Exporting $powerschemename"
 }
 $filedialog.Title = $Title
 $FileDialog.initialDirectory = $initialDirectory
 $FileDialog.filter = "TextFiles (*.txt)| *.txt| All files (*.*)| *.*"
 $FileDialog.ShowDialog() | Out-Null
 $FileDialog.filename
}

function load-ips{
$ipfilepath = get-filename -initialDirectory "."
[array]$ipsx = @(get-content $ipfilepath)
[array]$ips=@($ipfilepath)
foreach($ip in $ipsx){$ips+=$ip.trim()}
return $ips
}

function process-VMs{
param($IPs,$volumebyte,$cred)

$sbstring=@"
`$stvolletter="`$([char]([int]$volumebyte))"
[array]`$disks = get-disk | where {`$_.partitionstyle -eq 'raw' -or `$_.OperationalStatus -eq "Offline"} | sort-object -property number ;
if(`$disks.count -ge 1){
   `$disks | ft -AutoSize;
    foreach(`$disk in `$disks){
      `$dlx = "`$([char]([int]$volumebyte+[int]`$disk.number -1))"
        Write-Host "Volume Letter `$dlx"
        `$disk | Set-Disk -IsOffline `$false -ErrorAction silentlycontinue;
         `$disk | initialize-disk -PartitionStyle GPT -ErrorAction silentlycontinue;
          start-sleep 5
         `$dlx = "`$([char]([int]$volumebyte+[int]`$disk.number -1))"
         `$mypart = New-Partition -DiskNumber `$disk.number -UseMaximumSize -ErrorAction SilentlyContinue -DriveLetter `$dlx
          Format-Volume -FileSystem NTFS -NewFileSystemLabel "dbdata" -AllocationUnitSize 65536 -Force -Confirm:`$false -DriveLetter `$dlx | out-null
 }}
 else
 {
 `$zx = Read-Host "`nNo Raw Disks Found; Hit Enter to Select Disks to format`nor any other key to return to the main menu"
if(!([string]::IsNullOrEmpty(`$zx))){break}
[array]`$zdisks = get-disk | sort-object -property number
`$zdisks | ft -auto
`$myzdisks = Read-Host "Enter disk numbers to process (i.e.:3,4,5)"
`$mydisks=`$myzdisks.split(',')
`$xdisks = `$zdisks | Where {`$mydisks -contains `$_.number}
Write-Host "`nSelected Disks:"
`$xdisks | ft -auto
foreach (`$xdisk in `$xdisks){
`$dlx = "`$([char]([int]$volumebyte+[int]`$xdisk.number -1))"
`$mypart = New-Partition -DiskNumber `$xdisk.number -UseMaximumSize -ErrorAction SilentlyContinue -DriveLetter `$dlx
 Format-Volume -FileSystem NTFS -NewFileSystemLabel "dbdata" -AllocationUnitSize 65536 -Force -Confirm:`$false -DriveLetter `$dlx | out-null
 }
} 
"@

$sb = [scriptblock]::Create($sbstring)

$sbstring9=@"
Write-Host "`n`$((Get-Volume | where {`$_.driveletter -ge `"$startingvolletter`"} | sort-object -Property DriveLetter | FT -auto | out-String).trim())"
"@
$sb9 = [scriptblock]::Create($sbstring9)

foreach ($ip in $ips){
Write-Host "Machine: $IP" -f yellow
Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock $sb
Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock $sb9
}
Read-Host "`nHit <Enter> to return to the main menu"

}

function clear-vmdisks{
param ($startingvolletter,$IPs,$cred)
if(!($startingvolletter)){Write-Host "You need to choose a Starting Volume Letter";return $null}

$sbstring5=@"
`$volumeletters = (get-volume | where{`$_.driveletter -ge `"$startingvolletter`"}).DriveLetter
[array]`$disknumbers=@()
foreach(`$volumeletter in `$volumeletters){
`$Disk = Get-WmiObject -Class Win32_logicaldisk -Filter "DeviceID = `'`$(`$volumeletter):`'"
`$dinfo = `$Disk.GetRelated('Win32_DiskPartition').name
`$disknumber=(`$dinfo.split(","))[0].replace("Disk `#",`$null)
`$disknumbers += `$disknumber
}
if(`$disknumbers.count -lt 1){
`$zx = Read-Host "`nNo Provisioned Volumes Found; Hit Enter to Select Disks to Process`nor any other key to return to the main menu"
if(!([string]::IsNullOrEmpty(`$zx))){break}
[array]`$zdisks = get-disk | sort-object -property number
`$zdisks | ft -auto
`$myzdisks = Read-Host "Enter disk numbers to process (i.e.:3,4,5)"
`$mydisks=`$myzdisks.split(',')
`$xdisks = `$zdisks | Where {`$mydisks -contains `$_.number}
Write-Host "`nSelected Disks:"
`$xdisks | ft -auto
`$disknumbers = `$xdisks.number
}
foreach(`$disknumber in `$disknumbers){
clear-Disk -Number `$disknumber -Confirm:`$false -RemoveData -errorAction silentlycontinue
Set-Disk -number `$disknumber -IsOffline `$true;
}
"@

$sb5 = [scriptblock]::Create($sbstring5)

$sbstring6=@"
get-disk | where {`$_.partitionstyle -eq 'raw'} | sort-object -property number| ft -auto
"@
$sb6 = [scriptblock]::Create($sbstring6)

foreach ($ip in $ips){
Write-Host "Machine: $IP" -f yellow
Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock $sb5
Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock $sb6
}
Read-Host "`nHit <Enter> to return to the main menu"
}

function deploy-zeroscript {
param($IPs,$cred)

  $zeroscript = @'
  function cloudistics-optimize-storage{
   param(
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [Alias("Name")]
    $drive,$file_name = "vdtest1.txt"
    )
   process
   {

    
    $drive_path = ($drive.Trim("\") -replace "\\","\\") + "\\"
    $path = Join-Path $drive $file_name
    
    if ( (Test-Path $path) ) 
    {
Write-Warning -Message "The file $path already exists, deleting"
Remove-Item -Path $path -Recurse -Force
    } 
  #  else 
  #  {
$vol = gwmi win32_volume -filter "name='$drive_path'"
if ($vol) 
{
  $buf_size = 1mb
  $file_size = $vol.FreeSpace - ($vol.Capacity * 0.05)
  $zeroes_buffer = new-object byte[]($buf_size)

  
  $tick_increment = $file_size/100

  #Open a file stream to our file 
  $file_stream = [io.File]::OpenWrite($path)
  #Start a try/finally block so we don't leak file handles if any exceptions occur
  try 
  {
    #Keep track of how much data we've written to the file
    $current_fsize = 0
    $next_tick = $tick_increment
    $current_percent = 0

    write-host "`n`nInitiating disk zeroing ..."
  $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0,($Host.UI.RawUI.CursorPosition.Y +1)
    write-host "Progress: 000%" -NoNewline
    while($current_fsize -lt $file_size) 
    {
$file_stream.Write($zeroes_buffer,0, $zeroes_buffer.Length)
$current_fsize += $zeroes_buffer.Length
if ($current_fsize -ge $next_tick) 
{
  $current_percent=$current_percent+1
  $display_percent = $current_percent.ToString("000")
  write-host -NoNewLine "`b`b`b`b$display_percent%"
  $next_tick += $tick_increment
}
    }
    write-host "`nDone."
  } 
  finally 
  {
    #always close our file stream, even if an exception occurred
    if($file_stream) 
    {
$file_stream.Close()
    }
    #always delete the file if we created it, even if an exception occurred
    if( (Test-Path $path) ) 
    {
del $path
    }
  }
} 
else 
{
  Write-Error "Unable to locate a volume mounted at $drive"
}
    #}
  }
  }

  (Get-WmiObject Win32_Volume -filter "drivetype=3") | where {$_.label -eq 'dbdata'} | Sort-Object -property driveletter | cloudistics-optimize-storage
'@



$Bytes = [System.Text.Encoding]::Unicode.GetBytes($zeroscript)
$EncodedScript =[Convert]::ToBase64String($Bytes)


foreach($ip in $ips){
Write-Host "`nProcessing $ip" -ForegroundColor Yellow
$sbstring11=@"
powershell.exe -EncodedCommand $encodedscript –ExecutionPolicy Bypass
"@
$sb11 = [scriptblock]::Create($sbstring11)
Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock $sb11 -AsJob
}
$starttime=get-date
do{
start-sleep 5
cls
$duration= "Elapsed: $(New-TimeSpan -Start $starttime -End (get-date))"
Write-Host $duration
[array]$myjobs = get-job
write-Host "$($myjobs | ft -property Id,Name,PSJobTypeName,State,HasMoreData,Location -AutoSize|out-string)"

foreach($myjob in $myjobs){if($myjob.state -eq "completed"){Remove-Job -Job $myjob | out-null}
}
}until($myjobs.count -lt 1)
$myjobs=$null
return $duration
}

function get-volresult{
param ($IPs,$startingvolletter,$cred)
$sbstringx = "(get-volume | where {`$_.driveletter -ge `"$startingvolletter`"}).driveletter -join ', '"
$sbx = [scriptblock]::Create($sbstringx)
$opresult = @()
foreach ($ip in $ips){

$opresult += "$($ip) created volumes: $(Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock $sbx)"

}
return ($opresult | ft |out-string).trim()

}

function get-diskresult{
param($ips,$pstyle='raw',$cred)
$opresulty = @()
foreach ($ip in $ips){
$sbstringy = @"
Get-Disk | where {`$_.partitionstyle -eq `'$pstyle`'} | sort-object -property number | select-object @{n='info';e={"computer: $($ip): disk `$(`$_.number), size:`$([int]((`$_.size)/1gb))GB, partition: `$(`$_.partitionstyle)"}}
"@
$sby = [scriptblock]::Create($sbstringy)

$opresulty += Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock $sby | Select-Object -Property info
$opresulty += "--------------------"
}
return ($opresulty.info | ft | out-string).trim()
}

function remove-partition {
param($IPs,$cred,$startingvolletter)
$sbstringz = @"
`$volumes = (get-volume | where {`$_.DriveLetter -ge `"$startingvolletter`"}).driveletter
foreach(`$volume in `$volumes){
Write-Host "Removing volume `$volume" -f yellow
Remove-Partition -DriveLetter `$volume -Confirm:`$false -ErrorAction SilentlyContinue
}
"@
$sbz = [scriptblock]::Create($sbstringz)
foreach ($ip in $ips){
Write-Host "Machine: $IP" -f yellow
Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock $sbz
}


}

$Title="`nZeroing Out Volumes on Remote VMs`n================================="
if((Get-Item -path "WSMan:\localhost\Client\TrustedHosts").Value -ne "*"){Set-Item -Path "WSMan:\localhost\Client\TrustedHosts" -Value "*" -Force -PassThru}

do{
$menu = @"

0. Enter credentials:
$(($cred | ft | out-string).trim())

1. Select file with machine names /IP addresses:
$($IPfilepath) $($ipcount)

2. Enter Starting Volume Letter:
$($startvolLetter)

3. Clear Disks (revert to raw disks):
$($selectedPartitions)

4. Provision Volumes (set on line, disk type, partitioning):
$($provisionedVMs)

5. Perform Zeroing: 
$($res)

6. Remove Partitions on Data Volumes for Raw Disks Tests:
$($pres)

x. Exit


"@
cls
Write-Host $title -ForegroundColor Green
Write-Host $menu
$response = Read-Host "Select a choice"


switch ($response) {

"0" {$cred = get-credential;break}

"1" {$ips = load-ips; $IPfilepath=$ips[0];$ips=$ips[1..($ips.count-1)];$ipcount="`[$($ips.count) machines to process`]";break}

"2" {$VolumeLetter = Read-Host "Enter volume leter [default Q]";if([string]::IsNullOrEmpty($volumeletter)){$volumeletter="Q"};if($volumeletter.length -gt 1 -or $volumeletter -notmatch '[a-zA-Z]'){Read-Host "`nTry again!<hit Enter>";break};$startingvolletter=($VolumeLetter.replace(":",$null)).toUpper();$startvolletter="Data Volumes start with $($startingvolletter):";$volumebyte= [byte]([char]$startingvolletter) ;break}

"3" {clear-vmdisks -IPs $IPs -startingvolletter $startingvolletter -cred $cred; $selectedPartitions=get-diskresult -ips $ips -pstyle 'raw' -cred $cred;break}

"4" {process-VMs -IPs $IPs -volumebyte "$volumebyte".tostring() -cred $cred;$provisionedVMs= get-volresult -IPs $ips -startingvolletter $startingvolletter -cred $cred ;break}

"5" {$elapsedtime = deploy-zeroscript -IPs $ips -cred $cred ;$res="Done. $(($elapsedtime | sort-object)[0])" ;break}

"6" {remove-partition -ips $ips -startingvolletter $startingvolletter -cred $cred;Read-Host "`n`Hit Enter to return to the main menu";$pres=get-volresult -IPs $ips -startingvolletter $startingvolletter -cred $cred;break}
}

}until($response -eq 'x')