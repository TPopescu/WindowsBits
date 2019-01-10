$RegConnect = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"CurrentUser","$env:COMPUTERNAME")
$RegCursors = $RegConnect.OpenSubKey("Control Panel\Cursors",$true)

$RegCursors.SetValue("","Windows Default (extra large)");
$RegCursors.SetValue("AppStarting","%SystemRoot%\cursors\aero_working_xl.ani");
$RegCursors.SetValue("Arrow","%SystemRoot%\cursors\aero_arrow_xl.cur");
$RegCursors.SetValue("ContactVisualization",1);
$RegCursors.SetValue("Crosshair","");
$RegCursors.SetValue("GestureVisualization",31);
$RegCursors.SetValue("Hand","%SystemRoot%\cursors\aero_link_xl.cur");
$RegCursors.SetValue("Help","%SystemRoot%\cursors\aero_helpsel_xl.cur");
$RegCursors.SetValue("IBeam","");
$RegCursors.SetValue("No","%SystemRoot%\cursors\aero_unavail_xl.cur");
$RegCursors.SetValue("NWPen","%SystemRoot%\cursors\aero_pen_xl.cur");
$RegCursors.SetValue("Person","%SystemRoot%\cursors\aero_person_xl.cur");
$RegCursors.SetValue("Pin","%SystemRoot%\cursors\aero_pin_xl.cur" );
$RegCursors.SetValue("Scheme Source",2);
$RegCursors.SetValue("SizeAll","%SystemRoot%\cursors\aero_move_xl.cur");
$RegCursors.SetValue("SizeNESW","%SystemRoot%\cursors\aero_nesw_xl.cur" );
$RegCursors.SetValue("SizeNS","%SystemRoot%\cursors\aero_ns_xl.cur");
$RegCursors.SetValue("SizeNWSE","%SystemRoot%\cursors\aero_nwse_xl.cur" );
$RegCursors.SetValue("SizeWE","%SystemRoot%\cursors\aero_ew_xl.cur");
$RegCursors.SetValue("UpArrow","%SystemRoot%\cursors\aero_up_xl.cur" );
$RegCursors.SetValue("Wait","%SystemRoot%\cursors\aero_busy_xl.ani");

$CSharpSig = @'
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfo(uint uiAction,uint uiParam,uint pvParam,uint fWinIni);
'@

$CursorRefresh = Add-Type -MemberDefinition $CSharpSig -Name WinAPICall -Namespace SystemParamInfo –PassThru
$CursorRefresh::SystemParametersInfo(0x0057,0,$null,0)