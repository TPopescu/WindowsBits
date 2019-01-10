#function execute-process captures the stdout result, stderror and exit code
param(
$processpath='c:\windows\system32\netsh.exe',
$servicename = 'ServerManagementGateway'
)

function execute-process{
param ($cmdPath, $cmdArgs)

#set process info
$processinfo = New-Object System.Diagnostics.ProcessStartInfo($cmdPath)
#$processinfo.FileName = 
$processinfo.Arguments = $cmdArgs
$processinfo.RedirectStandardError = $true
$processinfo.RedirectStandardOutput = $true
$processinfo.UseShellExecute = $false
$processinfo.WindowStyle = 'Hidden'
$processinfo.CreateNoWindow = $true
$processinfo.Verb = 'runas'
#build and run process
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processinfo
$process.Start() | Out-Null
$result = [pscustomobject]@{exitcode = $null; output=$process.StandardOutput.ReadToEnd();error=$process.StandardError.ReadToEnd();}
$process.WaitForExit()
$result.exitcode = $process.ExitCode
return $result
}
cls
Write-Host @"
SSL Certificate Replacement
---------------------------

"@ -ForegroundColor Green

#get ssl cert bindings
$output = execute-process -cmdPath $processpath -cmdArgs 'http show sslcert'
#$output.output
$bindings = ($output.output.trim()).split("`n")

$ipportparts = ($bindings | where {$_ -match 'IP:port'}).split(':').trim()

$ipport= "$($ipportparts[0])$($ipportparts[1])=$($ipportparts[2]):$($ipportparts[3])"
$extracts = [pscustomobject]@{thumbprint=($bindings | where {$_ -match 'Certificate Hash'}).split(':').Trim()[1];AppId = ($bindings | where {$_ -match 'Application ID'}).split(':').Trim()[1];ipport=$ipport }

Write-Host "Current Certificate:" -ForegroundColor Yellow
$extracts | ft -AutoSize
Write-Host "`n`nAvailable Certificates:" -ForegroundColor Yellow
$availablecerts = Get-ChildItem -path cert:\LocalMachine\my | select-object -property index,Thumbprint,Subject
for($i=0;$i -lt $availablecerts.count; $i++){$availablecerts[$i].index = $i+1}
$availablecerts += [pscustomobject]@{index='x';Thumbprint='Exit';Subject=''}
do{
do{
$availablecerts | ft -autosize
$response = read-Host "select the certificate to enable"
}until ($availablecerts.index -contains $response)
if($response -eq 'x'){Exit}

$newcert = $availablecerts[$response-1]

Write-Host "`nSelected certificate:" -ForegroundColor Yellow
$newcert | ft -AutoSize

$responsex = Read-Host "Ready to continue `[y/n`] (x to exit)"
if($responsex -eq 'x'){exit}

}until($responsex -eq 'y')
Write-Host "`nStopping Service '$($servicename)'..." -ForegroundColor Yellow -NoNewline
try{
stop-service -name $servicename -ErrorAction stop 
}catch {Write-Host "Could not stop $servicename, exiting..."; exit}
Write-Host "Done!`n" -ForegroundColor Yellow
$results = @()
#remove current cert and reservation
$results += execute-process -cmdPath $processpath -cmdArgs "http delete sslcert $($ipport)"
$results += execute-process -cmdPath $processpath -cmdArgs " http delete urlacl url=https://+:443/"

#add selected cert and reservation
$results += execute-process -cmdPath $processpath -cmdArgs "http add sslcert $($ipport) certhash=$($newcert.Thumbprint) appid=$($extracts.AppId)"
$results += execute-process -cmdPath $processpath -cmdArgs "http add urlacl url=https://+:443/ user=`"NT Authority\Network Service`""

$results.output

$output = execute-process -cmdPath $processpath -cmdArgs 'http show sslcert'
$output.output

Write-Host "Starting Service '$($servicename)'..." -ForegroundColor Yellow -NoNewline
try{
start-service -name $servicename -ErrorAction stop 
}catch {Write-Host "Could not start $servicename, exiting..."; exit}
Write-Host "Done!`n" -ForegroundColor Yellow





