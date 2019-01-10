$RegConnect = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"CurrentUser","$env:COMPUTERNAME")
$RegCursors = $RegConnect.OpenSubKey("Control Panel\Cursors",$true)

$RegCursors.SetValue("","Magnified");
 $RegCursors.SetValue("AppStarting","%SystemRoot%\cursors\lappstrt.cur");
 $RegCursors.SetValue("Arrow","%SystemRoot%\cursors\larrow.cur");
 $RegCursors.SetValue("ContactVisualization",1);
 $RegCursors.SetValue("Crosshair","%SystemRoot%\cursors\lcross.cur");
 $RegCursors.SetValue("GestureVisualization",31);
 $RegCursors.SetValue("Hand","");
 $RegCursors.SetValue("Help","");
 $RegCursors.SetValue("IBeam","%SystemRoot%\cursors\libeam.cur");
 $RegCursors.SetValue("No","%SystemRoot%\cursors\lnodrop.cur");
 $RegCursors.SetValue("NWPen","");
 $RegCursors.SetValue("Person","%SystemRoot%\cursors\lperson.cur");
 $RegCursors.SetValue("Pin","%SystemRoot%\cursors\lpin.cur");
 $RegCursors.SetValue("Scheme Source",2);
 $RegCursors.SetValue("SizeAll","%SystemRoot%\cursors\lmove.cur");
 $RegCursors.SetValue("SizeNESW","%SystemRoot%\cursors\lnesw.cur");
 $RegCursors.SetValue("SizeNS","%SystemRoot%\cursors\lns.cur");
 $RegCursors.SetValue("SizeNWSE","%SystemRoot%\cursors\lnwse.cur");
 $RegCursors.SetValue("SizeWE","%SystemRoot%\cursors\lwe.cur");
 $RegCursors.SetValue("UpArrow","");
 $RegCursors.SetValue("Wait","%SystemRoot%\cursors\lwait.cur");

 $CSharpSig = @'
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfo(uint uiAction,uint uiParam,uint pvParam,uint fWinIni);
'@

$CursorRefresh = Add-Type -MemberDefinition $CSharpSig -Name WinAPICall -Namespace SystemParamInfo –PassThru
$CursorRefresh::SystemParametersInfo(0x0057,0,$null,0)