
function select-line{
param(
$xobject,
$title,
$text = "Select Value to Process"
)

Write-Host "`n$($title)`n"
$columns = $xobject | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name
$newcolumns = "index,$($columns -join ',')".split(',')
$xobject = $xobject | Select-Object -Property $newcolumns
for($i=0;$i -lt $xobject.count; $i++){$xobject[$i].index = $i+1}
$line = New-Object -TypeName pscustomobject
for($i=0;$i -lt $newcolumns.Count; $i++){

switch ($i) {
0 {$xvalue = 'x';break}
1 {$xvalue = 'Exit';break}
default {$xvalue=$null;break}
}
$line | Add-member -MemberType NoteProperty -Name $newcolumns[$i] -Value $xvalue 
}
$xobject += $line
do{
Write-Host "$((($xobject | ft -AutoSize) | out-string).trim())"
$response = read-Host "`n$($text)"
}until ($xobject.index -contains $response)
if($response -eq 'x'){Exit}

return $xobject[$response-1]

}

Clear-Host
Write-Host @"
Create Self Signed Certificate
------------------------------
"@ -ForegroundColor Green

do{
Write-Host @"
Select Certificate Location

1. Personal Store (cert:\LocalMachine\My)

2. Trusted Root Cert. Authorities (cert:\LocalMachine\root)

3. Create Certificate and export to c:\programdata

4. Remove a Certificate

9. Exit

"@

$response = Read-Host "Enter The desired Option"
}until(1,2,3,4,9 -contains $response)

if($response -eq 9){exit}

if($response -eq 4){


#region 'remove cert'
cls
Write-Host "Remove Certificate`n------------------" -ForegroundColor Green

#select the cert store
$certstring = "cert:\"
Write-Host "`nPath: $certstring"
$selectedline = select-line -xobject (get-childitem -Path $certstring | Select-Object -property Location | sort-object -property location) -title 'Select the Cert Store'

$certstring += "$($selectedline.Location)\"

Write-Host "`nPath: $certstring"

$selectedline = select-line -xobject (get-childitem -Path $certstring | Select-Object -property pschildname | sort-object -property pschildname ) -title 'Select the Cert Store'

$certstring += "$($selectedline.pschildname)\"

Write-Host "`nPath: $certstring"

$selectedline = select-line -xobject (get-childitem -Path $certstring | Select-Object -property thumbprint,subject ) -title 'Select the Cert Store'
$certstring += "$($selectedline.thumbprint)"
Write-Host "`nPath: $certstring"

do {
$response = read-host "Do you want to remove the certificate with the path:`n$($certstring)`n[y/n]"
}until('y','n' -contains $response)

if($response -eq 'y'){remove-item -Path $certstring;exit}else{exit}

#endregion



}

$addon=$null
if($($env:USERDNSDOMAIN)){$addon = '.'}
$newcert = New-SelfSignedCertificate -DnsName "$($env:computername)$($addon)$($env:USERDNSDOMAIN)" -CertStoreLocation "cert:\LocalMachine\My" -NotAfter (get-date).AddYears(12) -KeyAlgorithm RSA
if($response -eq 1){
Write-Host "Certificate Created in the Personal Store"
$newcert | Format-Table

exit
}

$xpassword = "$([GUID]::NewGuid().guid)"
$password = ConvertTo-SecureString $xpassword  -AsPlainText -Force
$exportedcertificate = Export-PfxCertificate -FilePath "$($env:ProgramData)\$($newcert.Thumbprint).pfx" -Password $password -Cert "cert:\LocalMachine\My\$($newcert.Thumbprint)"

if($response -eq 3){
Write-Host @"
pfx password: $xpassword"
pfx file:     $($env:ProgramData)\$($newcert.Thumbprint).pfx
"@
Remove-Item -Path "cert:\LocalMachine\My\$($newcert.Thumbprint)"
exit
}

$result = Import-PfxCertificate -Password $password -FilePath  "$($env:ProgramData)\$($newcert.Thumbprint).pfx" -CertStoreLocation "cert:\LocalMachine\root"
$mycheck = get-childitem -Path "cert:\LocalMachine\root" | Where-Object -FilterScript {$_.thumbprint -eq $newcert.Thumbprint}

if($mycheck){
Remove-Item -Path "cert:\LocalMachine\My\$($newcert.Thumbprint)"
Remove-Item -Path "$($env:ProgramData)\$($newcert.Thumbprint).pfx"
}
$mycheck | Format-Table -AutoSize