param($filepath = 'c:\temp\MouseInverted.txt')
$x = @(get-content -path $filepath ) 
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

$header = @"
`$RegConnect = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"CurrentUser","`$env:COMPUTERNAME");
`$RegCursors = `$RegConnect.OpenSubKey("Control Panel\Cursors",`$true);

"@

$footer = @"

`$CSharpSig = @'
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")];
public static extern bool SystemParametersInfo(uint uiAction,uint uiParam,uint pvParam,uint fWinIni);
'@

`$CursorRefresh = Add-Type -MemberDefinition `$CSharpSig -Name WinAPICall -Namespace SystemParamInfo –PassThru;
`$CursorRefresh::SystemParametersInfo(0x0057,0,`$null,0);


"@

$mousescriptblock= "$($header)$($result)$($footer)"

$scriptblock = [scriptblock]::Create($mousescriptblock)

Invoke-Command -ScriptBlock $mousescriptblock