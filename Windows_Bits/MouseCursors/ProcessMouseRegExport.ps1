$x = @(get-content -path .\MouseInverted.txt) 
[array]$x = $x | where {$_ -like "`"*"} | sort-object
$result=@()
foreach ($xline in $x){
if($xline -like "*REG_EXPAND_SZ*"){$line = "`$RegCursors.SetValue($($xline.replace("=`[REG_EXPAND_SZ`] ",',"').trim())`");`r`n"}
else{
$line = "`$RegCursors.SetValue($($xline.replace('=[REG_DWORD] ',',').trim()));`r`n"
}
$result +=$line
}
$result = $result.replace('=',',')
write-Host $result
