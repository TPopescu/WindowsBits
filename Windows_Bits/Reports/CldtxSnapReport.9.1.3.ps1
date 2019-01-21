<#
.SYNOPSIS
Script to generate Organization Wide Application Reports

.DESCRIPTION
This script collects data for an organization including the application names, state, configuration, local and DR snapshots 
Additionally it provides navigation and allows filtering the report content.
The general setup was streamlined for generating the report in conjunction with Windows Task Scheduler.
Most parameters can be set up via GUI elements.
The script needs the CloudisticsAPIPowershell module and preferable PowerShell 5.0 or later.

.PARAMETER commonrootpath
Path to the location where the supporting data is stored (API Key file, E-Mail Settings and possibly the Cloudistics Module). By default it is C:\ProgramData\Cloudistics\ScriptData

.PARAMETER apitokenfilename
The name of the json file containing the API token and other organization information. If not in the commonrootpath, the user is prompted to select it.

.PARAMETER modulename
The name of the Cloudistics Module, by default cloudisticsapimodule

.PARAMETER reportpath
The path where the report is saved. By default $($env:userprofile)\Downloads
The report name is automatically calculated as: $($orgname)-Snapshot_Report_$((get-date($adjustedlocaltime.correctedtime)).tostring('yyyy-MM_dd-HH-mm-ss')).html


.PARAMETER apiPropertyList
Do NOT change. The list of the Json API file entries. Possible values: 'portal','organization','apitoken'; 
Use TAB to cycle through the list to select

.PARAMETER newapitokenfile
Parameter used to generate the ApiToken File. Do not mix it with other parameters as the script exits after executing the operation.

.PARAMETER logpath
Path to the log folder. Recommended to be a subfolder of the commonrootpath

.PARAMETER xfilter
The applications to process. Acceptable values: all, DRSnap (only the applications with DR snapshots) and userSelected (via a GUI element)

.PARAMETER timezone
The time zone where the source and DR stacks are located. Makes sense to use when runninbg the script manuallyat a location 
in a different time zone or when the Local and DR stacks are located in different time zones.
For normal usage local or utc time is recommended

.PARAMETER columns
The number of columns containing the list of Applications. Default value = 6

.PARAMETER setscheduledtask
Possibly the most important parameter as it sets the script and all the auxiliary files in a separate folder and creates the task that runs the script.

.PARAMETER setupemail
Used to generate the Mail Configuration File. Do not mix it with other parameters as the script exits after executing the operation.

.PARAMETER mail
Switch Parameter. When present it indicates that the report will be delivered via e-mail

.EXAMPLE
CldtxSnapReport.9.ps1
Runs the script with the default options. Good to get used with how it works

.EXAMPLE
CldtxSnapReport.9.ps1 -newapitokenfile
Opens a GUI element allowing setting up the API configuration file

.EXAMPLE
CldtxSnapReport.9.ps1 -setupemail
Opens a GUI element allowing to collect the e-mail settings

.EXAMPLE
CldtxSnapReport.9.ps1 -setscheduledtask
Probably the most useful option. Opens a GUI element allowing configuring the script and all its auxiliary files to run as a daily scheduled task.

.Example
C:\zScript\CldtxSnapReport.9.ps1 -commonrootpath C:\zScript\Extras -timezone utc -reportpath C:\zScript\Reports -mail
Running the script and delivering the report through e-mail while all the auxiliary elements have been previously copied to c:\zScript
#>


param(
#region Prerequisites Location
$commonrootpath= "$($env:Programdata)\cloudistics\scriptData",
$apitokenfilename=$null,
$modulename = 'cloudisticsapimodule',
$reportpath = "$($env:userprofile)\Downloads", #default report path is userprofile\downloads\calculatedreportname
$apiPropertyList = @('portal','organization','apitoken','location'),
[switch]$newapitokenfile,
$logpath="$($commonrootpath)\Log",
#endregion

#region report generation options
[ValidateSet('all','DRSnap','userSelected')]$xfilter='all', 
[ValidateSet('local','utc','choose')]$timezone='choose',
[int]$columns=6,
[switch]$setscheduledtask,
#endregion

#region report delivery options

[switch]$setupmail,
[switch]$mail
#endregion

)

function pageheader {
  $htmlhead = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<style>
body{
background: lightgrey;
text-align: left;
font: 13px Arial, Helvetica, sans-serif;
}
table {
	border-width: 2px;
	border-spacing: 0px;
	border-style: solid;
	border-collapse: collapse;
border-color:ligrey;
width:100%;
}
table th {
	font: 13px Arialbold, Helvetica, sans-serif,;
	text-align:left; 
	border-width: 2px;
	border-spacing: 0px;
	border-style: solid;
background-color:#ffedd6;
border-color:#ffedd6;
}
table td {
	font: 12px Arial, Helvetica, sans-serif;
	border-width: 2px;
	text-align:left; 
	border-spacing: 0px;
	border-style: solid;
vertical-align:top;
border-color:white;

}

table tr {
background-color: White;

}


.agenttable tr:nth-child(odd) {
  background-color: #dfe7f2;
  color: #000000;
}
.emptytable th {
	font: 8px Arialbold, Helvetica, sans-serif,;
	text-align:left; 
	border-width: 2px;
	border-spacing: 0px;
	border-style: solid;
background-color: rgba(0, 0, 0, 0);
border-color:White;
}
.emptytable td{
font: 8px Arialbold, Helvetica, sans-serif,;
background-color: rgba(0, 0, 0, 0);
border-color:rgba(0, 0, 0, 0);
}

.emptytable tr:nth-child(odd){
background-color: rgba(0, 0, 0, 0);
}

.emptytable tr:nth-child(even){
background-color: rgba(0, 0, 0, 0);
}

.minitable table {
border-width: 1px;
border-color:lightgrey;
}

.minitable tr {
border-color:lightgrey;
border-width: 1px;
}
.minitable th {
border-color:lightgrey;
border-width: 1px;
background-color: rgba(0, 0, 0, 0);
}

.minitable td {
border-color:lightgrey;
border-width: 1px;
background-color: rgba(0, 0, 0, 0);
}

.sorttable td {border-width: 0px;}

a{font-weight:bold;}

.baseimage {border-width: 0px;border-collapse: collapse;width:100%;margin: 0 0 0 0;font-family:Arial, Helvetica, sans-serif;font-size:10px;padding:0px}


/* unvisited link */
a:link {color: black;}

/* visited link */
a:visited {color: black;}

/* mouse over link */
a:hover {color: hotpink;}

/* selected link */
a:active {color: darkgrey;}

input[type=button], input[type=submit], input[type=reset] {
    background-color: white;
    color: black;
    border: 2px solid grey;
    padding: 4px 8px;
    text-decoration: none;
    margin: 2px 1px;
    cursor: pointer;
    border-radius: 12px;
}

input[type=button]:hover {
    background-color: grey; 
    color: white;
}

.inputsize[type=text] {
            width: 98%;
}

</style>
<script type="text/javascript">

    function toggle_visibility(id) {
       var e = document.getElementById(id);
       id0=id+"-button"
       var q = document.getElementById(id0);
       if(e.style.display == 'block'){
          e.style.display = 'none';
          if(q){q.value = "Expand";}
          }
       else{
          e.style.display = 'block';
         if(q){ q.value = "Collapse";}
         }
    };
     function composite(id,id1) {
     var b = document.getElementById(id1);
     if(b.style.display == 'none'){
     var idc = id1+"-button"
     b.style.display = 'block'
     var btn = document.getElementById(idc);
      if(btn){ btn.value = "Collapse";}
     }
     toggle_visibility(id);
       
    }
    function printPageArea(areaID,title){
    var header = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> \
<html xmlns="http://www.w3.org/1999/xhtml"> \
<head><style>BODY{background-color:lightgray;margin:10px 10px 0 10px;font-family:verdana,arial,sans-serif;font-size:12px} \
TABLE{border-width: 1px;border-style: solid;border-color: grey;border-collapse: collapse;width:100%;margin: 0 0 0 0;} \
TH{border-width: 1px;padding: 10px;border-style: solid;border-color: black;background-color:#ffedd6} \
TR{vertical-align:top;} \
TD{border-width: 1px;padding: 10px;border-style: solid;border-color: black;background-color:white; vertical-align:top;}a{font-weight:bold;}</style>'
    var printContent = document.getElementById(areaID);
    var WinPrint = window.open('', '', 'scrollbars=yes,resizable=yes,top=50,left=50,width=900,height=600');
    fulltitle = '<table><tr><th>'+title+'</th></tr></table>'
    WinPrint.document.write(header);
    WinPrint.document.write(fulltitle);
    WinPrint.document.write(printContent.innerHTML);
    WinPrint.document.close();
    WinPrint.focus();
    WinPrint.print();
    WinPrint.close();
}

function clearinput(xinput) {
  var myinput, i;
  myinput = document.getElementsByClassName("inputsize")
  for (i = 0; i < myinput.length; i++) {
  if (myinput[i].id != xinput) {
     myinput[i].value = null
                }
            }

        }

function filterFunction(xinput, xtable, xclass) {
  var input, filter, table, tr, td, i;
  clearinput(xinput)
  input = document.getElementById(xinput);
  filter = input.value.toUpperCase();
  table = document.getElementById(xtable);
  tr = table.getElementsByTagName("tr");
            for (i = 0; i < tr.length; i++) {
                td = tr[i].getElementsByClassName(xclass)[0];
                if (td) {
                    if (td.innerHTML.toUpperCase().indexOf(filter) > -1) {
                        tr[i].style.display = "";
                    } else {
                        tr[i].style.display = "none";
                    }
                }
            }
        }

</script>

</head><body>

"@
  return $htmlhead
}
function javaelement{
  param($javaid, $title)
  $javabutton = "<input type='button' id=`"id0-$($javaid)-button`" onclick=`"toggle_visibility(`'id0-$($javaid)`')`" value='Expand'/>"
  $javaprintbutton = "<input type='button' id=`"id0-$($javaid)-printbutton`" onclick=`"printPageArea(`'id0-$($javaid)`',`'$title`')`" value='Print'/>"
  $spanid="id0-$($javaid)"
  $spanstart=@"
<a id=`"$spanid`" style="display:none;">
"@
  $spanend='</a>'
  return [pscustomobject]@{javabutton=$javabutton;spanstart=$spanstart;spanend=$spanend;id1=$spanid;javaprintbutton=$javaprintbutton;javatitle=$title}
}
function htmlsectiontitle{
  param ($t)
  return "<br><table class=agenttable><tr><th align=`"left`">$($t)</th></tr></table>"
}
function collapse-element{
param ([array]$xelement,$xtitle)
$zelement = $xelement | ConvertTo-Html -Fragment -As Table | out-string
$zelement = $zelement.replace('<table','<table class="agenttable"')
if($xelement.count -gt 0){
$test=$null
$test = $xelement | Where-Object -FilterScript {($null,'','Completed' -notcontains $_.DRStatus) <#-and ($xtitle -ne 'Local Snapshots')#>}
if($test){$warning = '<strong><font color=red>In Progress!</font></strong>'}else{$warning =$null}
$javaid = ([GUID]::NewGuid()).guid
$je=javaelement -javaid $javaid -title "$($warning) $($xtitle) ($($xelement.count)) <font color=Blue>*****</font>"
$segmentx = htmlsectiontitle -t "$($je.javatitle) $($je.javabutton) $($je.javaprintbutton)"
$segmentx +=$je.spanstart
$segmentx +=$zelement
$segmentx +=$je.spanend
}else{$segmentx = '*****'}
return $segmentx
}
function get-logo{
return 'iVBORw0KGgoAAAANSUhEUgAAAIQAAAAgCAYAAADTydBfAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAr2SURBVHhe7ZqJV1XXFcb9Q5pmbJrUpk2HtE3TZDW1WV1ts+yYpk3aldS2ZqXpkKQrgwM4IBJARSwqDiAKKoqCkajFAQfQKIoajYoojgRncQLnvft995wLl8u9Dx4+uh72/dZi6T3vTufc73x773NvPw3iQpPKR0kqlRNUtxar1leqNu1RuXhC9cZVu1OCu5FgQZSPUB13v2r6febvA/yNvld12D2qo76kOvEHqvkvq5a+q7pukur2RaoN1aqnD6i2nFW9fcueKEFfo5Mg5Ool1TH9VT54QvWTpaqbC1RXZZqHXzhIdcrzEMh3VEd+0Qhk5OexP8TCP/6fbaP7q+b9SpWOkqBP0dkhts5z3EFWjbMNIdxoUbl0WvXMQZWjW1X3rlStmatamaX64VDV7KdVc39md07QV+gsiOwfqY7ATD/bYBt6SOsFnOdBuEsXwkoQV3QUxNFtqqmw/lzYfQyQujXIOXC+Y7W2JUG800EQUvx31QyEi9oS2xIDlryvOvbx/9/q5NYN1fPH7EYM4Tlv37QbsaNNEHLpJJLCh0wVcfWibY0Bt3DTGd9SXQCxxQIOQt6LKlXTbEMcwSprBpLuI8ipXMreM1XafpTusWJvhan+ypNtQ+xoF8S6yaqZcIeSt21L7JDGXRAa8pLdH9mWO4ACG36fStkQ2xBHHNsON0SI5AOzOOOaO0D1+A7b0j1k7yrVRW8ah/HD0D4N59w40zbEDiMIzDrJeEo1BZ05tNFpijVSmQ1RoFS9csa29BAKAmWtcK0k3mj8xJTezJ3ulNpFyOfgAueP2ob/DUYQ+6BGJpOZKBV7IS45XDmrmvyAmUXd4TJK2qbdsOF6lZvXbSPojiAufKb6GR4OKyW5bRv9iP23hzDENsH5cH/q3l/TnugEcaHRjAf7yfHxsnMJxstb7UV5v+cOO2Mg54/bho44KUIjXKtxp+mLxQgi//eI81Djmixns1dgEjTyYdwABjESjRic2bif4XbRi3/pX1E9/LH5PZIg6tfBnn+KgbTHsnzORP6yeZbdwUPNXJWpA1XCkt2KNNVZL9mNdoT5Qd4Lqknt9yepX1atysUD+NRc0yuI3eWqOT80AndphhBm/87s6/aRf2Xv2B1wnV0Ir/x9zFdV076pOgF/202yL80Q/JTnMJHbQ1Mb24pVsr7X8dzTf4GkvtX8zvxwwetGbO7v2Fdm/tZZYe7nKDwZYmBCefaQOag34LmTH4wsCMZN5hrp31Bdl6N6YIMK846S11V2lpl9QgQhVdMxcOhHDgZq82zVg9WYZTim8FUnAZOSf9g9LWsQwvhQuV4SxNzX8DAgRC+ctVyRHf8kBICk9kCVyYsW/A33dK9KNuL6MPxe50kgN0GM7BPdgNCBJ0O0qY+a+2yA0CnktZiMS4diB+MEwlViPrRinPtD5EvLh8FJIDjCsUzBb3j4HeB+nNizILYd9nXCljmqBZhgVpAyD2KgCNYjt+EYHUQfNmLsit9Qvd4CQSxLMRlr7i+dA3qNMwfxAO7HLIIDBHEOsTIFgil4UfXaFdvoQez7kSBBNCDvQSYvS961DT44cOzj6gm2ASDZkyEYmNaQimohBJT+bbsBTtXhuth/3iC4yjXb6KEOYnZdgw/YZUuhcTuGMUJ34Hlq5pttP2JDgxsy/KGEnDtirmUdw2FTvrNkoJvybIMPvl9iaBtyj8rSsOpEIIgNUx3VS0p/81B6i1NwIs6eMEEs/hcGCi4VNmNdggSR8xPVrGfsRjCyCOdPgihazpmGaAVR9BdUEAgNkdZTKidhH1wjgiAEYpeUx2DjA80kCaMthwhwbb8gMLOdd0tFfzbbYTCfyvkxHA5h9HhwLtdPr11CJ2DRLJc4aL3FScywoehgkCB4o2O/jtn3V9sQAb8gLmMGccDXI4ZHghUA39jWrTbb0QiCs2sEBnwJLT0CnP1JnmsQv0MQOhrzIoaZ+YNVWEb6iUYQzGsYQmj/XUGn43smPu9ZcGN+2uDBJJWMv4yNybCcSKq9A4QZOOyqLQ56gZVJEsJFRbptiIBfEMzCmUDtQsyNRDOybQ7wtgVmOxpBXEcIG/I5iA5uGgnul/QF86LPJUgQQK6cx7hPwTW+Zlyl8A/I/E/ZX0EUghCueyBUyYl9znaXwOWkpgiuiuSTwpj2PISy3/nJCIIdSXvC/Ljwn05TrHEWp4aGCAKxS5BJy5w/2e0I+AXRgoHlK3fadSSOYBZynaV+vdl2BcHX/UGUYBw8DiFcwS3pwkEZcvkQ93XhEF5uIh+pRY4z5iGn6mn7liQah2DpSoeIdv2D+cqeFcg94M7j0FdUIEYQpHqGM2AyHIPGyiPGCG+aDy5QEKA8CSrH9ZubbEMIQTnE9F+jUxA0fwtj7mCcH7PXCoALZULHCkoQSclbptxzKXkTDw1lc0uzbeiMrEg1sz1SUhkGy0wKlk4KZPtiIwiW6378gqCoxjyG0vE3ZjtKhKU+I8SnyzyCcFwCAwCXcEqTWHO4xgyM7XAnaJdjMQtZswd9WHPTJnNBguDiCjs0H4mfW297qYLVoxyTas9SL9cHWKZ6lpnbQJImnDEUmgtXDFOQ9M74eWDmL7UIRSwvGb4iCYL3H5Q486szCoK5FqlfaxYLD20x2178ggDC41lyrkyzLR6Yo7HcpSO0wlF9OGsrHD+MRbsggLS5BDp1IuTB9RRatiOIEIcgEI2kPoKBxcCXJ2OQF6p+XKCah5KYdTXhgKJakdL3zLbLzlKnU5L2uMlFOFgbkGhOQQXCgVrmERC5hRJs5gvmGOYLjKkYVKnIUOE6yCjkU/5kbz8edMoDOOZRnG80rB7XYLmXh+QMD09mQEAUBVd+Xfg7B5s5DKGwJz6Luv81Fa5RbEX5uRylP8vV/JfMwyOsHMY/BdEi+eQ7i5rZKofs4hzDCMXCj5k8yOrxCHPo66QBKmv/bcZgJcZiMioLrkNAEMI+z3kZkwTPmuU4v1dJeVhl4vcdU+ggCH4F5bgEL1bYRQkTLbAjxwLDyk4XWmTp27hJDDpnAUVE13CTXcbYwkEqFIqf43CKoj+q8MMcHosQJVMhCF47CLpJBWyeIuJ1cIxzLBI851xBnMZ9lHAhClWHe3+TnjUOQbGWvaNy2DOrIQ7Jh2C8rsJFrQlPmhDK43ku9tmfz7DP+XZVlKLiF2lALp50KgTxOpELK5zpcDGGfh43Cv1huHPXcXZg4uTgfpnP8foj8fs85G5WsB0FAaQaFQetizfKUu0OEToNl2RHYGZx9riW2AXCmYQyzvlML1quXzbHBi3qBIHBcr4o56AwdHYHign79+j+XPiiz/mSPSDMeeHs5nK1m3B2h1bkOuwPlxWCYDLOr+t9v3cShGNV/MCWFljwim3sAfzOshi5CIWVCfvlev/6HMyigNe5CeKGzoIgtGMu4tByjkb5+VtDFSz3VZNc8eur0Y+orEIc877cSRC3BAuCZUzGd00ukdf5jV8QUrcS8Q6xkskRkziWeCtGdV1uJYgrggUBhBksXQKJoHCpNYx9/0EphiqA+QE/FeP7gqXvBy+oJIh7QgXh1K3jnzEuMRVZq589y817djoChTAM/5a+pXKym8unCeKScEGQHYvNzOdD32+XRbmgM22gaefCDpPGhW+o8KufBH2eyILgIknWACd0yLinIQSEBoqD7zyYcM4fHPoaNUHfJLIgCN8iUgR0AoYPfp5WNAjVR43dIcHdRNeCoEtkP2eWeAtQcfCzrAR3Kar/BYRd3oIZAJwIAAAAAElFTkSuQmCC'
}

function get-cldtxtimezone{
param (
[ValidateSet('local','utc','choose')]$timezone
)

if($timezone -eq 'choose'){


#region XAML window definition
$xaml = @'
<Window
   xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
   xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
   MinWidth="200"
   Width ="475"
   SizeToContent="Height"
   Title="Time Zone Selection"
   Topmost="True">
  <Window.Resources>
        <Style x:Key="alternativeStyle" TargetType="{x:Type ComboBoxItem}">
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="true">
                    <Setter Property="BorderThickness" Value="2" />
                    <Setter Property="Foreground" Value="Green" />
                </Trigger>
            </Style.Triggers>
            <Setter Property="Background" Value="#FF2981D8" />
        </Style>
   </Window.Resources>
   <Grid Margin="10,40,10,10">
      <Grid.ColumnDefinitions>
         <ColumnDefinition Width="Auto"/>
         <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Grid.RowDefinitions>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <TextBlock Grid.Column="0" Grid.Row="0" Grid.ColumnSpan="2" Margin="5">Please Select Time Zones:</TextBlock>

      <TextBlock Grid.Column="0" Grid.Row="1" Margin="5">Local Snap Time Zone</TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="2" Margin="5">DR Snap Time Zone</TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="3" Margin="5">Same Location</TextBlock>
      <ComboBox Name="cmbLocal" Grid.Column="1" Grid.Row="1" Margin="5"  ItemsSource="{Binding displayname}"></ComboBox>
      <ComboBox Name="cmbDR" Grid.Column="1" Grid.Row="2" Margin="5" ItemsSource="{Binding displayname}"></ComboBox>
      <CheckBox Name="chkSame" Grid.Column="1" Grid.Row="3" Margin="5"></CheckBox>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,10,0,0" Grid.Row="4" Grid.ColumnSpan="2">
        <Button Name="ButOk" MinWidth="80" Height="22" Margin="5">OK</Button>
        <Button Name="ButCancel" MinWidth="80" Height="22" Margin="5">Cancel</Button>
      </StackPanel>
   </Grid>
</Window>
'@
#endregion

#region Convert XAML to Window
$window = Convert-XAMLtoWindow -XAML $xaml 
#endregion

#region Define Event Handlers

$window.ButCancel.add_Click(
  {
    $window.DialogResult = $false
  }
)

$window.ButOk.add_Click(
  {
    $window.DialogResult = $true
  }
)

$window.add_Loaded(
{
$timezones = get-timezone -listAvailable
$window.cmbLocal.ItemsSource = $timezones.displayname
$window.cmbLocal.SelectedItem = (Get-TimeZone).displayname
$window.cmbDR.ItemsSource = $timezones.displayname
$window.cmbDR.SelectedItem = (Get-TimeZone).displayname
$window.chkSame.IsChecked = $true

}
)

$window.cmbLocal.add_SelectionChanged(
{

$window.chkSame.IsChecked = $false

}
)
$window.cmbDR.add_SelectionChanged(
{

$window.chkSame.IsChecked = $false

}
)
$window.chkSame.add_Checked(
{
$window.cmbDR.SelectedItem = $window.cmbLocal.SelectedItem
$window.chkSame.IsChecked = $true
}
)

#endregion Event Handlers

#region Manipulate Window Content

$null = $window.cmbLocal.Focus()
#endregion


# Show Window
$result = Show-WPFWindow -Window $window

#region Process results
if ($result -eq $true)
{
  $timezones = Get-TimeZone -ListAvailable
  $localtimezone = $timezones | where {$_.displayname -eq $window.cmbLocal.SelectedItem} | select-object -property id,displayname
  $drtimezone = $timezones | where {$_.displayname -eq $window.cmbDR.SelectedItem} | select-object -property id,displayname
return  [PSCustomObject]@{LocalTimeZone = $localtimezone ;DRTimeZone = $drtimezone}

}

#endregion Process results
}
if($timezone -eq 'utc'){

$utctimezone = get-timezone -Id 'UTC'| select-object -property id,displayname
return [PSCustomObject]@{LocalTimeZone =  $utctimezone ;DRTimeZone =  $utctimezone}
}

$localtimezone = (Get-TimeZone) | select-object -property id,displayname
return [PSCustomObject]@{LocalTimeZone =  $localtimezone ;DRTimeZone =  $localtimezone}


#endregion Process results

}
function set-correcttime{
param($timestamp,$timezoneid=$null,[switch]$utc)
if(!($timezoneid)){
$timezone = get-timezone
}else{ $timezone = get-timezone -Id $timezoneid}
if($utc.IsPresent){
return [pscustomobject]@{correctedtime=[System.TimeZoneInfo]::ConvertTimeFromUTC((Get-Date -Date ($timestamp)), $timezone) ;timezone=$timezone}
}
else{
return [pscustomobject]@{correctedtime=[System.TimeZoneInfo]::ConvertTime((Get-Date -Date ($timestamp)), $timezone) ;timezone=$timezone}
}
}
function import-cldtxmodule{
param(
$commonrootpath="$($env:Programdata)\Cloudistics\ScriptData",
$modulename = 'cloudisticsapimodule'
)
function get-xfileName {
param ($initialDirectory = (get-location),[switch]$savefile,$titleroot='Cloudistics Portal and API Key')

 $checkAssembly = ([System.AppDomain]::CurrentDomain.GetAssemblies() | where {$_.location -like "*System.Windows.Forms*"}).Location
 if(!($checkAssembly)){[System.Reflection.Assembly]::LoadWithPartialName('System.windows.forms') | Out-Null}

 $FileDialog = New-Object -TypeName System.Windows.Forms.OpenFileDialog
 $Title="Import $($titleroot)"
 if($savefile.IsPresent){
 $Filedialog = New-Object -TypeName System.Windows.Forms.SaveFileDialog
 $Title = "Export $($titleroot)"
 }
 $filedialog.Title = $Title
 $FileDialog.initialDirectory = $initialDirectory
 $FileDialog.filter = "PowerShellModule (*.psd1)| *.psd1| All files (*.*)| *.*"
 $FileDialog.ShowDialog() | Out-Null
 return $FileDialog.filename
}

if(!(get-module -name $modulename)){
      Write-Host 'Attempting to load module from the Windows Default Location' -ForegroundColor Yellow
     try{import-module $modulename -erroraction stop 3>&1 | Out-Null;
     Write-Host 'Success!' -ForegroundColor Green
     }
     catch{
     Write-Host "Failed!`nAttempting to load module from $($commonrootpath)" -ForegroundColor Yellow
     try{import-module "$($commonrootpath)\$($modulename)\$($modulename).psd1" -ErrorAction Stop 3>&1 | Out-Null;
     Write-Host 'Success!' -ForegroundColor Green
     }
     catch{
     Write-Host "Failed!`nSelect the module to import..." -ForegroundColor Yellow
     $modulepath = get-xfileName -initialDirectory (Get-Location) -titleroot 'Cloudistics Module'     
     if([System.String]::IsNullOrEmpty($modulepath)){Write-Host "`nNo Module selected. Exiting...`n"}
     try{
          if ((Split-path -Path $modulepath -Leaf) -ne "$($modulename).psd1"){Write-Host "`nWARNING. This is not the expected module name! Expected '$modulename' and got '$((Split-path -Path $modulepath -Leaf))' instead" -ForegroundColor Red }
          import-module $modulepath -ErrorAction stop 3>&1 | Out-Null;
          Write-Host 'Success!' -ForegroundColor Green
         }catch{
         Write-Host "`nError! Could not import selected module. Exiting..." -ForegroundColor Yellow; exit}
         }
}
}
return (get-module $modulename)
}
function decode-password {
param($encodedpassword)
$password =@([System.Text.Encoding]::UNICODE.GetString([System.Convert]::FromBase64String($encodedpassword)))
return $password
}
function get-powershellversion1 {
<#
.Synopsis
Gets powershell version and displays a message. Exists script if major version is lower than 3
#>
Write-Host "`nChecking PowerShell... " -NoNewline
$pvs = ($PSVersionTable).psversion.Major
$pvsfull = ($PSVersionTable).psversion.tostring()
$color=$null
Switch ($pvs){
{$_ -ge 5} {$addon = 'is supported!'; $color='Green';break}
{$_ -in (3..4)} {$addon = 'not supported but worth a try!';$color = 'Yellow';break}
{$_ -lt 3} {$addon = 'is not supported'; $color='Red';break}
}

Write-Host "Powershell version $pvsfull $addon " -ForegroundColor $color
Write-Host '----------------------'
if($color -eq 'Red'){exit}
else {return $null}
}
function set-summary{
param($applications,$class='agenttable',$columns=6)
$applications = $applications | Sort-Object -Property name
[array]$xapplications = @()
for($l=0;$l -lt $applications.count; $l++){
if($l -eq 0){$xapplications +=[pscustomobject]@{uuid=[GUID]::NewGuid().guid;name="$($applications[0].name.Substring(0,1).toUpper())"}}
else{
if($applications[$l-1].name.Substring(0,1).toUpper() -ne $applications[$l].name.Substring(0,1).toUpper()){$xapplications +=[pscustomobject]@{uuid=[GUID]::NewGuid().guid;name="$($applications[$l].name.Substring(0,1).toUpper())"}}
}
$xapplications += $applications[$l]
}


$xapplications = $xapplications | Sort-Object -Property name


[array]$xsummary=@()
$xapplications | ForEach-Object {$xsummary += "<a href=#id_$($_.uuid)>$($_.name)</a>" }
#create summary object
$summarycolumncount = [math]::ceiling($xapplications.count/$columns)
$summary="<table class=$($class)>"

for($k=0; $k -lt $summarycolumncount;$k++){
   $summary +='<tr>'
   for($i=0; $i -lt $columns; $i++){
   $j = ($k + $i*($summarycolumncount))
   #Write-Host $j

       if(($j) -le $xapplications.count){     
       $summary += "<td>$($xsummary[$j])</td>"
   }else{$summary +='<td></td>' }
}
$summary += '</tr>'
}
$summary +='</table>'



return $summary
}
function use-runAs {    
<#
.Synpsis
Check if script is running as Adminstrator and if not use RunAs. Use Check Switch to check if admin

.Description
Check if the parent script runs in elevated mode (using the 'check' switch). If it does not, it attempts restarting the script in elevated mode. 
Note: This works well for scripts without arguments. Still working to include the command line parameters when restarting the script in elevated mode

#>
    param([Switch]$Check) 
     if(Test-Path variable:global:psISE){return}

    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')        
    if ($Check) { return $IsAdmin }     
 
    if ($MyInvocation.ScriptName -ne ''){  
        if (-not $IsAdmin){  
            try {  
                $zarg = "-file `"$($MyInvocation.ScriptName)`"" 
                Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $zarg -ErrorAction 'stop'
            }catch{Write-Warning 'Error - Failed to restart script with runas';break } 
            exit # Quit this session of powershell 
        }  
    }else {Write-Warning 'Error - Script must be saved as a .ps1 file first';break;}  
}
#------------------------------

Clear-Host
$scriptversion = 'Cloudistics Snapshot Report 0.9.1.3'
#region check if script can run

Write-Host "`nPreparing environment...`nFound: $scriptversion`n" -ForegroundColor Green
get-powershellversion1
if(!($psise)){
Write-Host "`nRunning from a PowerShell Console" -ForegroundColor Green
if(use-runAs -Check){Write-Host "Checking Elevated Mode... OK`n" -ForegroundColor Green }else{Write-Host "This script requires running in elevated mode... please run from an Administrator console.`nExiting...`n`n" -f yellow ;exit}
}else{Write-Host "`nRunning from ISE. Some functionality may not be available`n" -ForegroundColor Yellow}
if(!(test-path($logpath))){
New-Item -Path $logpath -ItemType Directory | Out-Null
Write-Host "Log Path Created ($logpath)"
}
#endregion

Start-Transcript -Path "$($logpath)\Executionlog-$((get-date).tostring('yyyy-MM-dd-HH-mm-ss')).log"

#region prerequisites
Write-Host "`n`nPreparing Snapshot Report Prerequisites...`n`n" -ForegroundColor Yellow
Write-Host "`nChecking module $modulename `n" -ForegroundColor Yellow

import-cldtxmodule -commonrootpath $commonrootpath -modulename $modulename

#region Scheduled Task
if($setscheduledtask.IsPresent){

$CommandName = $null
$CommandName = $MyInvocation.InvocationName;

#region XAML window definition
$xaml = @'

<Window
   xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
   xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
   
   Width="Auto"
   Height="500"
   SizeToContent="WidthAndHeight"
   Title="Cloudistics Task Scheduling Setup">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto" />
            <ColumnDefinition Width="Auto" />
            <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>
        <StackPanel HorizontalAlignment="Left" Grid.Column="0" Grid.Row="0" Margin="10,10,10,10" VerticalAlignment="Top" Grid.RowSpan="2">
            <GroupBox Header="Script and Pre-Requisites Info" HorizontalAlignment="Left" Margin="10,10,0,10" VerticalAlignment="Top" MinWidth="379">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto" />
                        <ColumnDefinition Width="*" />
                        <ColumnDefinition Width="Auto" />
                        <ColumnDefinition Width="Auto" />
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="*" />
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Column="0" Grid.Row="0" Margin="5">Script Name:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="1" Margin="5">Script Folder:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="2" Margin="5">Root Folder:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="3" Margin="5">Cloudistics PS Module to use:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="4" Margin="5">Config File:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="5" Margin="5">Mail Config File:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="6" Margin="5">Report Path:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="7" Margin="5">Time Zone:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="8" Margin="5">E-mail Delivery:</TextBlock>
                    
                    <TextBox Name="txt_scriptName"              Grid.Column="1" Grid.Row="0" Margin="5" Grid.ColumnSpan="3"></TextBox>
                    <TextBox Name="txt_scriptFolder"            Grid.Column="1" Grid.Row="1" Margin="5" Grid.ColumnSpan="1"></TextBox>
                    <TextBox Name="txt_rootFolder" MaxLines="5" Grid.Column="1" Grid.Row="2" Margin="5"></TextBox>
                    <TextBox Name="txt_module"                  Grid.Column="1" Grid.Row="3" Margin="5"></TextBox>
                    <TextBox Name="txt_configFile"              Grid.Column="1" Grid.Row="4" Margin="5"></TextBox>
                    <TextBox Name="txt_mailFile"                Grid.Column="1" Grid.Row="5" Margin="5"></TextBox>
                    <TextBox Name="txt_reportPath"              Grid.Column="1" Grid.Row="6" Margin="5"></TextBox>

                    <Button Name="button_scriptFolder"           Grid.Column="2" Grid.Row="1" MinWidth="80" Height="22" Margin="5" Grid.ColumnSpan="2">Change</Button>
                    <Button Name="button_rootFolder"             Grid.Column="2" Grid.Row="2" MinWidth="80" Height="22" Margin="5" Grid.ColumnSpan="2">Change</Button>
                    <Button Name="button_psModule"               Grid.Column="2" Grid.Row="3" MinWidth="80" Height="22" Margin="5" Grid.ColumnSpan="2">Move</Button>
                    <Button Name="button_configFile"             Grid.Column="2" Grid.Row="4" MinWidth="40" Height="22" Margin="5">Get</Button>
                    <Button Name="button_mailConfigFile"         Grid.Column="2" Grid.Row="5" MinWidth="40" Height="22" Margin="5">Get</Button>
                    <Button Name="button_reportPath"             Grid.Column="2" Grid.Row="6" MinWidth="80" Height="22" Margin="5" Grid.ColumnSpan="2">Change</Button>

                    <Button Name="button_createConfig"           Grid.Column="3" Grid.Row="4" MinWidth="40" Height="22" Margin="5">Create</Button>
                    <Button Name="button_createMail"             Grid.Column="3" Grid.Row="5" MinWidth="40" Height="22" Margin="5">Create</Button>
                    
                    <ComboBox Name="cmb_timezone"                Grid.Column="1" Grid.Row="7" Grid.ColumnSpan="3" SelectedIndex="0"  Margin="5">
                        <ComboBoxItem>local</ComboBoxItem>
                        <ComboBoxItem>utc</ComboBoxItem>
                    </ComboBox>
     <CheckBox Name="chx_mail"  Grid.Column="1" Grid.Row="8" Margin="5"></CheckBox> 

                </Grid>
            </GroupBox>
        </StackPanel>
        <StackPanel HorizontalAlignment="Right" Grid.Column="1" Grid.Row="0" Margin="10,10,10,10"  VerticalAlignment="Top">
            <GroupBox Header="Task Info" HorizontalAlignment="Left" Margin="0,10,10,10" MinWidth="350">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto" />
                        <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="*" />
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Column="0" Grid.Row="0" Margin="5">Task Name:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="1" Margin="5">Task Description:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="2" Margin="5" VerticalAlignment="Center">Scheduled Run Time:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="3" Margin="5">Task Uri:</TextBlock>
                    <TextBlock Grid.Column="0" Grid.Row="4" Margin="5">Task Command:</TextBlock>

                    <TextBox Name="txt_taskName" Grid.Column="1" Grid.Row="0" Margin="5"></TextBox>
                    <TextBox Name="txt_description" MaxLines="5" Grid.Column="1" Grid.Row="1" Margin="5"></TextBox>
                    <StackPanel Grid.Column="1" Grid.Row="2" Margin="5" Orientation="Horizontal">
                    <TextBlock VerticalAlignment="Center" Margin="1">Daily at </TextBlock>
                    <ComboBox Name="cmb_HH" Margin="5" />
                    <TextBlock VerticalAlignment="Center" Margin="1">:</TextBlock>
                    <ComboBox Name="cmb_mm" Margin="5" />
                    <ComboBox Name="cmb_ampm" Margin="5" />                      
                    </StackPanel>
                    <TextBox Name="txt_uri" Grid.Column="1" Grid.Row="3" Margin="5"></TextBox>
                    <TextBox Name="txt_command" Grid.Column="1" Grid.Row="4" Margin="5"></TextBox>
                </Grid>
            </GroupBox>
        </StackPanel>
        <StackPanel Grid.Column="1" Grid.Row="1" Margin="10,0,10,10" HorizontalAlignment="Left">
            <GroupBox Header="How To Info:" HorizontalAlignment="Left" Margin="0,0,10,10" Width="350">
                <TextBlock TextWrapping="WrapWithOverflow" FontFamily="Consolas" FontSize="10">
                    For production purposes, keep everything in one location, ie:<LineBreak/><LineBreak/>

                    C:\CldtxReport<LineBreak/>
                     ├───Extras<LineBreak/>
                     │   ├───CloudisticsApiModule<LineBreak/>
                     │   └───Log<LineBreak/>
                     └───Reports
                    
                </TextBlock>
            </GroupBox>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="10,10,10,10" Grid.Column="0" Grid.Row="2" Grid.ColumnSpan="2">
            <Button Name="button_Ok" MinWidth="80" Height="22" Margin="5">OK</Button>
            <Button Name="button_Cancel" MinWidth="80" Height="22" Margin="5">Cancel</Button>
        </StackPanel>
    </Grid>
</Window>

'@
function Convert-XAMLtoWindow
{
  param
  (
    [Parameter(Mandatory=$true)]
    [string]
    $XAML
  )
  
  Add-Type -AssemblyName PresentationFramework
  
  $reader = [XML.XMLReader]::Create([IO.StringReader]$XAML)
  $result = [Windows.Markup.XAMLReader]::Load($reader)
  $reader.Close()
  $reader = [XML.XMLReader]::Create([IO.StringReader]$XAML)
  while ($reader.Read())
  {
    $name=$reader.GetAttribute('Name')
    if (!$name) {$name=$reader.GetAttribute('x:Name')}
    if($name)
    {$result | Add-Member NoteProperty -Name $name -Value $result.FindName($name) -Force}
  }
  $reader.Close()
  $result
}


function Show-WPFWindow
{
  param
  (
    [Parameter(Mandatory)]
    [Windows.Window]
    $Window
  )
  
  $result = $null
  $null = $window.Dispatcher.InvokeAsync{
    $result = $window.ShowDialog()
    Set-Variable -Name result -Value $result -Scope 1
  }.Wait()
  $result
}


#endregion

#region Convert XAML to Window
$window = Convert-XAMLtoWindow -XAML $xaml 
#endregion

#region Define Event Handlers

$window.add_Loaded(
{
$starttime = (Get-Date) #.tostring('HH:mm:ss')
$defaulttaskname = 'myTask'
$description = 'Cloudistics Script'
$uri = "Cloudistics\$($defaultTaskName)"


$window.txt_taskname.Text = $defaultTaskName
$window.txt_uri.Text = $uri
$window.txt_description.Text = $description

[array]$hours = [array](0..12)
[array]$minutes =for($i=0;$i -lt 12;$i++){$i*5}
[array]$ampm = 'AM','PM'

$window.cmb_HH.ItemsSource =$hours
$window.cmb_mm.ItemsSource = $minutes
$window.cmb_ampm.ItemsSource = $ampm

$minutesIndex = $minutes.IndexOf([int](5*[int]((([int]$starttime.ToString('mm')))/5))) 
if($minutesindex -eq -1){$minutesIndex = 0}
$window.cmb_HH.SelectedIndex = $hours.IndexOf([int]($starttime.ToString('h tt').split(' ')[0]))
$window.cmb_mm.SelectedIndex = $minutesIndex
$window.cmb_ampm.SelectedIndex = $ampm.indexof($starttime.ToString('hh tt').split(' ')[1])


$window.txt_scriptName.Text = Split-Path -Path $CommandName -Leaf
$localpath = Split-Path -Path $CommandName -Parent
if($localpath -eq '.'){$localpath = (Get-Location).Path}
$window.txt_scriptFolder.Text = $localpath
$window.txt_command.Text = "$($window.txt_scriptFolder.Text)\$($defaultTaskName)_task.bat"

[array]$ParameterList = (Get-Command -Name $CommandName).Parameters.Keys;
$paramworklist = @()
foreach ($Parameter in $ParameterList) {
Switch($parameter){
'commonrootpath' {$window.txt_rootFolder.Text = (Get-Variable -Name $Parameter -ErrorAction SilentlyContinue).Value;break}
'modulename'     {$window.txt_module.Text = Split-path -path (get-module -Name (Get-Variable -Name $Parameter -ErrorAction SilentlyContinue).Value | Select-Object -Property path).path -Parent;break}   
'reportpath'     {$window.txt_reportPath.Text = Split-Path -Path (Get-Variable -Name $Parameter -ErrorAction SilentlyContinue).Value -Parent;break }
default          {$null}
}
}
}
)

$window.button_Cancel.add_Click(
  {
    $window.DialogResult = $false
  }
)

$window.button_Ok.add_Click(
  {

$message = @"
Hit 'yes' to perform the following operations:

0. Copy the Script to the new location (if changed)

1. Copy the Cloudistics API Module in the Root Folder (if not already there)

2. Copy the Config file in the Root Folder (if not already there)

3. Copy the Mail Config file in the Root Folder (if not already there)

4. Use the new Report Path when running with task Scheduler 

5. Use the Time Zone of choice when running with task Scheduler

6. Set the Report delivery by E-mail

7. Create a scheduled task using the info above


"@

  if((set-message -message $message -buttons YesNo -title 'Next Step' -icon Hand) -eq 'No'){set-message -message 'Exiting' -title 'NO Chosen' ;exit}

  
  if(!(Test-path $window.txt_scriptFolder.Text)){
  try{  new-item -Path $window.txt_scriptFolder.Text -ItemType Directory -ErrorAction stop | out-Null; set-message -message "Success: New Directory $($window.txt_scriptFolder.Text)"}catch{set-message -message "$($_.exception.message)";return}
  }
  
  
  
  if((split-path $CommandName -parent) -ne $window.txt_scriptFolder.Text){Copy-Item -Path $CommandName -Destination $window.txt_scriptFolder.Text -ErrorAction SilentlyContinue}

  $rootpath = $window.txt_rootFolder.Text
  #$modulepath = 1
  $rpath = $window.txt_reportPath.Text



  if(!(Test-path $rootpath)){
  try{  new-item -Path $rootpath -ItemType Directory -ErrorAction stop | out-Null; set-message -message "Success: New Directory $rootpath"}catch{set-message -message "$($_.exception.message)";return}
  }

  if(!(Test-Path $rpath)){
    try{  new-item -Path $rpath -ItemType Directory -ErrorAction stop | out-Null; set-message -message "Success: New Directory $rpath"}catch{set-message -message "$($_.exception.message)";return}
  }

  try{
  $cldtxModuleCurrent = $window.txt_module.Text
  $cldtxModuleFolder = $cldtxModuleCurrent | split-path -leaf -ErrorAction Stop
  $configfile = $window.txt_configFile.Text | Split-Path -leaf -ErrorAction Stop
  $mailfile=$window.txt_MailFile.Text | Split-Path -leaf -ErrorAction Stop

  }catch{set-message -message "No Empty Fields are permitted!.`n$($_.exception.message)" -icon Warning;return}
  
  try{
  copy-item -Path $cldtxModuleCurrent -Destination $rootpath -Recurse -ErrorAction Stop -Force; set-Message -message "$cldtxModuleFolder copied to $rootpath"
  }catch{set-message -message "$($_.exception.message)";return}

  try{
  if(test-path "$($rootpath)\$($configfile)"){set-message -message "$($configfile) already present in $rootpath; Skipping"}else{
  copy-item -Path $window.txt_configFile.Text -Destination $rootpath -ErrorAction Stop ; set-Message -message "$configfile copied to $rootpath"
  }}catch{set-message -message "$($_.exception.message)";return}

  try{
if(test-path "$($rootpath)\$($mailfile)"){set-message -message "$($mailfile) already present in $rootpath; Skipping"}else{
  copy-item -Path $window.txt_MailFile.Text -Destination $rootpath -ErrorAction Stop ; set-Message -message "Config File copied to $rootpath"
  }}catch{set-message -message "$($_.exception.message)";return}

#build the bat file
$sendmail=$null
if($window.chx_mail.IsChecked){$sendmail = '-mail'}
$powershellpath = 'C:\windows\system32\windowspowershell\v1.0\powershell.exe  -Executionpolicy Bypass -File '
$batcontent = "$powershellpath $($window.txt_scriptFolder.Text)\$($window.txt_scriptname.Text) -commonrootpath $rootpath -timezone $($window.cmb_timezone.Text) -reportpath $($window.txt_reportPath.Text) $sendmail".trim()
$batpath = "$($window.txt_scriptFolder.Text)\$($window.txt_taskName.Text).bat"
$batcontent | out-file $batpath -Encoding oem

#prepare the xml for the task

#$starttime = (get-Date("$($window.cmb_HH.Text):$($window.cmb_mm.Text) $($window.cmb_ampm.Text)")).ToString("HH:mm:ss")
$starttime = (get-Date("$($window.cmb_HH.selectedItem):$($window.cmb_mm.selectedItem) $($window.cmb_ampm.selectedItem)")).ToString("HH:mm:ss")
$description = $window.txt_description.Text
$uri = $window.txt_uri.Text
$command = $window.txt_command.Text


$taskxml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2019-01-03T$($starttime)</Date>
    <Author>CLOUDISTICS</Author>
    <Description>$($description)</Description>
    <URI>$($uri)</URI>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2019-01-03T$($starttime)</StartBoundary>
      <ExecutionTimeLimit>PT30M</ExecutionTimeLimit>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>true</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$($command)</Command>
    </Exec>
  </Actions>
</Task>
"@

$taskpath = "$($window.txt_scriptFolder.Text)\$($window.txt_taskName.Text).xml"

$taskxml | Out-File -FilePath $taskpath
start-sleep 2
start-process -FilePath 'C:\Windows\System32\schtasks.exe' -ArgumentList "/Create /XML $($taskpath) /tn $($window.txt_uri.Text)" -Verb runas -Wait
start-process -FilePath taskschd

    $window.DialogResult = $true 
  }
)
$window.txt_taskName.add_TextChanged({
 
$window.txt_command.Text = "$($window.txt_scriptFolder.Text)\$($window.txt_taskName.Text).bat"
$taskfolder=($window.txt_uri.Text).split('\')[0]
$window.txt_uri.Text = "$($taskfolder)\$($window.txt_taskName.Text)"
})

$window.button_scriptFolder.add_Click(
{
$x7 = get-folderName -title 'New Script Path'
if($x7){
$window.txt_scriptFolder.Text = $x7
}
}
)

$window.button_createConfig.add_Click(
{
$x6 = (new-apitokenfile).location
if($x6){$window.txt_configFile.Text = $x6}

}
)

$window.button_createMail.add_Click(
{
$x5=(new-mailinfo -key (get-key)).location
if($x5){$window.txt_mailFile.Text = $x5}

}
)

$window.button_configFile.add_Click(
{
$x4=get-fileName -titleroot 'Organization Configuration file'
if($x4){$window.txt_configFile.Text = $x4}
}
)

$window.button_mailConfigFile.add_Click(
{
$x3=get-fileName -titleroot 'Email Configuration file'
if($x3){$window.txt_mailFile.Text = $x3}
}
)

$window.button_rootFolder.add_Click(
{
$x2=get-folderName -title 'Select New Root Folder Location'
if($x2){$window.txt_rootFolder.Text = $x2}

}
)

$window.button_psModule.add_Click(
{
$x1=get-folderName -title 'Select New Module Folder Location'
if($x1){
$window.txt_module.Text =  $x1
}
}
)

$window.button_reportPath.add_Click(
{
$x0 = get-folderName -title 'New Report Path'
if($x0){
$window.txt_reportPath.Text = $x0
}
}
)

#endregion Event Handlers

#region Manipulate Window Content
$null = $window.txt_rootFolder.Focus()
#endregion

# Show Window
$result = Show-WPFWindow -Window $window

#region Process results
if ($result -eq $true)
{

}
else
{
  Write-Warning 'User aborted dialog.'
}
#endregion Process results
exit
}
#endregion Scheduled Task

#region prerequisites main stuff
if($newapitokenfile.IsPresent){$result = new-apitokenfile;if($result -ne 'Canceled'){Write-Host "Exiting... Use the file you created either by pointing to it when prompted or copy it to $commonrootpath"}else{Write-Host 'Exiting...'};exit }
if($setupmail.IsPresent){new-mailinfo ; Write-Host "Done! Please run the script again without the '-setupmail' parameter";exit }

$zinfo = get-cldtxJsonInfo -commonrootpath $commonrootpath -apitokenfilename $apitokenfilename -propertylist $ApiPropertyList
$apitoken=$zinfo.apitoken; $portal = $zinfo.portal; $orgname = $zinfo.organization
Write-Host "`nOrganization Config File Location: $($zinfo.location)" -ForegroundColor Yellow
Write-Host "`nTime Zones:" -ForegroundColor Yellow
$cldxtimezones = get-cldtxtimezone -timezone $timezone
$cldxtimezones | Format-List
$adjustedlocaltime = set-correcttime -timestamp "$(get-date)" -timezoneid $cldxtimezones.localtimezone.id

if(!($reportpath)){$reportpath = "$($env:userprofile)\Downloads\$($orgname)-Snapshot_Report_$((get-date($adjustedlocaltime.correctedtime)).tostring('yyyy-MM_dd-HH-mm-ss')).html"}else{
$reportpath = "$($reportpath)\$($orgname)-Snapshot_Report_$((get-date($adjustedlocaltime.correctedtime)).tostring('yyyy-MM_dd-HH-mm-ss')).html"}
$idx = @{apitoken=$apitoken;portal=$portal}

$list =@()
[array]$applications = get-resources @idx -resource applications
$totalapplicationscount = $applications.count
if($totalapplicationscount -lt 1){Write-Host "`nNo Applications to process. Exiting..." -ForegroundColor Yellow; exit}
#if(!($all.ispresent))

switch ($xfilter){
'all'          {<#$applications = $applications | select-object -property name,uuid;write-Host "xfilter = $xfilter";#>break;}
'userselected' {$applications = $applications | select-object -property name,uuid | Out-GridView -Title 'Select the VMs to process' -PassThru;break}
'drSnap'       {
                Write-Host 'Please Wait...';
                $selectedObjects=$null;$selectedObjects = $applications | ForEach-Object {  (get-resources @idx -resource applications -uuid $_.uuid | select-object name,uuid,@{n='DR_Enabled';e={$_.disasterRecoveryPolicy.Enabled}})}
                #$applications = $selectedObjects | where {$_.DR_Enabled -eq 'True'} | select-object -property name,uuid;break
                $applications = $selectedObjects | where {-not [System.string]::IsNullOrEmpty($_.DR_Enabled) } | select-object -property name,uuid;break
               }
default        {Write-Host "The -xfilter parameter is missing.`nTry again (use the TAB key to rotate through available options.";exit}

}

$selectedApplicationscount=$applications.count
if($selectedapplicationscount -lt 1){Write-Host "`nNo Applications to process. Exiting..." -ForegroundColor Yellow; exit}

$page        = pageheader
$title      = "Snapshot Report: $orgname Organization<br/>`nSelected Applications Count: $($selectedApplicationscount) out of $($totalapplicationscount)<br/>`n`[generated on $((get-date($adjustedlocaltime.correctedtime))) ($($cldxtimezones.localtimezone.id))`]"
$uline      = '-'*(($title.split('<')[2]).Length)
#endregion main stuff

#endregion

Clear-Host
#region create report
$alltitle   = "Cloudistics $($title.replace('<br/>',''))`n$uline`n`n"
$htmltitle  = "<table><tr><td valign=bottom><a id=xTop><a href=http://www.cloudistics.com ><img src=`"data:image/png;base64,$(get-logo)`" alt=`"logo`"/></a></td></tr><tr><td td style=`"color:darkorange;font-size:20px;font-weight:bold`">$($title)</td></tr></table><br/>"
Write-Host $alltitle -ForegroundColor Green
#region get-currentparameter values
$CommandName = $MyInvocation.InvocationName;
$parametervalues=@()
$ParameterList = (Get-Command -Name $CommandName).Parameters;
    foreach ($Parameter in $ParameterList) {
    $parametervalues += Get-Variable -Name $Parameter.Values.Name -ErrorAction SilentlyContinue;
    }
($parametervalues | where {$_.name -eq 'apitokenfilename'}).value = $zinfo.location   
"PARAMETERS: $(($parametervalues | sort-object -property name|Format-Table -AutoSize | out-string))"
#endregion


$page += $htmltitle

$summary = set-summary -applications $applications -columns $columns

$page += @"
<table ><tr><td>Jump To:</a></td><td>$($summary)</td></tr></table><br/>
"@

$page += @"
<table id=mainTable class=agenttable>
<tr>
<th>Application</br>
<input type="text" id="vmInput" onkeyup="filterFunction('vmInput','mainTable','apptable')" placeholder="Search for Application names.." title="Type in a VM name" class="inputsize">
</th>
<th>Info<br/>
<input type="text" id="infoInput" onkeyup="filterFunction('infoInput','mainTable','infotable')" placeholder="Search for info items.." title="Type in an Info Item name" class="inputsize">
</th>
<th>VDC/App-Group<br/>
<input type="text" id="vdcInput" onkeyup="filterFunction('vdcInput','mainTable','vdctable')" placeholder="Search for VDC/App-Group names.." title="Type in a VDC/App-Group name" class="inputsize">
</th>
<th>Local [$($cldxtimezones.localtimezone.displayname)]<br/>
<input type="text" id="localInput" onkeyup="filterFunction('localInput','mainTable','localtable')" placeholder="Search for Local Info.." title="Type in Local Info" class="inputsize">
</th><th>DR [$($cldxtimezones.DRtimezone.displayname)]<br/>
<input type="text" id="drInput" onkeyup="filterFunction('drInput','mainTable','drtable')" placeholder="Search for DR Info.." title="Type in DR Info" class="inputsize">
</th
</tr>
"@
$alltags = get-resources -resource tags @idx

#applications table


Write-Host "`nProcessing:`n-----------"
foreach($application in $applications){
Write-Host $application.name -ForegroundColor Yellow
$secondaryinfo = get-resources @idx -resource applications -uuid $application.uuid | Select-Object -Property datacenteruuid,applicationgroupuuid,autoSnapshotPolicy,@{n='DRPolicy';e={$_.disasterRecoveryPolicy.retentioncount}},status,vcpus,memory,disks,vnics,@{n='tags';e={($alltags | where { $_.uuid -contains $secondaryinfo.tags.uuid}).name -join ', '}}
if($secondaryinfo.datacenteruuid){$vdc = (get-resources @idx -resource datacenters -uuid $secondaryinfo.datacenteruuid).name} else {$vdc = 'N/A'}
if($secondaryinfo.applicationgroupuuid){$appgrp ="`/$((get-resources @idx -resource application-groups -uuid $secondaryinfo.applicationgroupuuid).name)"} else {$appgrp = ''}


$snapinfo = @()
[array]$snaps = submit-snapshotaction @idx -machineUuid $application.uuid -action getSnapshots
foreach($snap in $snaps){
#$snapInfo += submit-snapshotaction @idx -machineUuid $application.uuid -action getSnapshotInfo -snapshotUuid $snap.uuid | Select-Object name,@{n='Timestamp'; e={ $(get-Date("$($_.createdTimestamp)"))}},@{n='size';e={"{0:N2}GB" -f (($_.size)/1GB)}},type,generated,@{n='DRStatus';e={$_.disasterrecovery.transferstatus}},@{n='Progress';e={"$(100*($_.disasterrecovery.transferPercentage))%"}}
$snapInfo += submit-snapshotaction @idx -machineUuid $application.uuid -action getSnapshotInfo -snapshotUuid $snap.uuid | Select-Object name,@{n='Timestamp'; e={ $_.createdTimestamp }},@{n='size';e={"{0:N2}GB" -f (($_.size)/1GB)}},type,generated,@{n='DRStatus';e={$_.disasterrecovery.transferstatus}},@{n='Progress';e={"$(100*($_.disasterrecovery.transferPercentage))%"}}
}

$snapinfox = $snapinfo | Where-Object -FilterScript {$_.type -eq 'Local'}
$snapinfox = $snapinfox| select-object -property name,@{n='Timestamp'; e={"$((set-correcttime -utc -timezoneid $cldxtimezones.LocalTimeZone.Id -timestamp (get-date($_.timestamp)).tostring()).correctedtime.tostring())" }},@{n='UTC';e={(get-date($_.timestamp)).toString()}},size,generated,DRStatus,Progress
$snapinfoy = $snapinfo | Where-Object -FilterScript {$_.type -eq 'Disaster Recovery'}
$snapinfoy = $snapinfoy| select-object -property name,@{n='Timestamp'; e={"$((set-correcttime -utc -timezoneid $cldxtimezones.DRTimeZone.Id -timestamp (get-date($_.timestamp)).tostring()).correctedtime.tostring())" }},@{n='UTC';e={(get-date($_.timestamp)).toString()}},size,generated,DRStatus,Progress


  $segmentA = collapse-element -xelement $snapinfox -xtitle 'Local Snapshots'
  $segmentB = collapse-element -xelement $snapinfoy -xtitle 'DR Snapshots'

$color0 = 'Green'
if($secondaryinfo.status -ne 'Running'){$color0='Red'}

$segmentC = @"
<table class=emptytable>
<tr><td width=50px><strong>Status:</strong></td><td width=150px><strong><font color=$($color0)>$($secondaryinfo.status)</font></strong></td></tr>
<tr><td width=50px><strong>vCPU-s:</strong></td><td width=150px>$($secondaryinfo.vcpus)vCPU-s</td></tr>
<tr><td width=50px><strong>Memory:</strong></td><td width=150px>$(($secondaryinfo.Memory)/1GB)GB</td></tr>
<tr><td width=50px><strong>Tags:</strong></td><td width=150px>$($secondaryinfo.tags -join ', ')</td></tr>
<tr><td width=50px><strong>Disks:</strong></td><td width=150px>$(($secondaryinfo.disks | select-Object -Property Name,@{n='size';e={"{0:N1}GB" -f (($_.size)/1GB)}} | ConvertTo-Html -As Table -Fragment ).Replace('<table','<table class=minitable'))</td></tr>
<tr><td width=50px><strong>Network(s):</strong></td><td width=150px>$($secondaryinfo.vnics.networks.networkname -join ', ')</td></tr>
<tr><td width=50px><strong>vNics:</strong></td><td width=150px>$(($secondaryinfo.vnics | select-Object -Property Type,ipAddress | ConvertTo-Html -As Table -Fragment).Replace('<table','<table class=minitable'))</td></tr>
</table>
"@

  $count=$null;$interval=$null;$message=$null
  if($secondaryinfo.autoSnapshotPolicy.localRetentionCount){
  $count="Count:$($secondaryinfo.autoSnapshotPolicy.localRetentionCount); "
  }else{$message='Not Set Up'}
  if($secondaryinfo.autoSnapshotPolicy.intervalInMinutes)
  {
  $interval="Interval:$(New-Timespan -minutes $secondaryinfo.autoSnapshotPolicy.intervalInMinutes -ErrorAction Silentlycontinue)"
  }

  $segmentA = $segmentA.replace('*****',"Policy: `[$($count)$($interval)$($message)`]")
  $policyheader = 'Not Enabled'
  if(($secondaryinfo.DRPolicy.all) -and ($SegmentB -eq '*****')){
  $xjavabutton = "<input type='button' value='Expand' disabled />"
  $xjavaprintbutton = "<input type='button' value='Print'  disabled />"
  $policyheader = htmlsectiontitle -t "<font color=Red>DR SnapShots (0)</font> <font color=Blue>Policy: `[All:$($secondaryinfo.DRPolicy.all); Daily:$($secondaryinfo.DRPolicy.daily); Monthly:$($secondaryinfo.DRPolicy.monthly); Yearly:$($secondaryinfo.DRPolicy.yearly)`]</font>"
  }
  if($segmentB -ne '*****'){
  $policyheader = "`[All:$($secondaryinfo.DRPolicy.all); Daily:$($secondaryinfo.DRPolicy.daily); Monthly:$($secondaryinfo.DRPolicy.monthly); Yearly:$($secondaryinfo.DRPolicy.yearly)`]"
  }
 
  $segmentB = $segmentB.replace('*****',$policyheader)
 
 $page +=@"
 <tr>
 <td class=apptable ><strong><a id=id_$($application.uuid)><a href=#xTop>$($application.name)</a></a><strong></td>
 <td class=infotable>$($segmentC)</td>
 <td class=vdctable >$($vdc)$($appgrp)</td>
 <td class=localtable>$($segmentA)</td>
 <td class=drtable>$($SegmentB)</td>
 </tr>
"@ 


}
$page += '</table></body>'
$page=$page.replace('&#39',"'").replace('&gt;','>').replace('&lt;','<')
$page | out-file -FilePath $reportpath
Write-Host "`nReport completed. Path: $reportpath`n" -ForegroundColor Green
#endregion

#region report delivery
if($mail.IsPresent){
Write-Host "`nPreparing Mail Delivery`n" -ForegroundColor Green
$mailpropertylist = 'mailfrom','mailto','smtpserver','smtpport','enableSSL','usecredentials','smtpusername','smtppassword','location'
$mailpath = (get-cldtxJsonInfo -commonrootpath $commonrootpath -propertylist $mailpropertylist).location
$mailfolderlocation = $mailpath | split-path -parent
$mailfile = $mailpath | split-path -leaf
$mailvars = @{
mailattachment=$reportpath;
mailsubject="Cloudistics: $($orgname) Snapshot Report generated on $($adjustedlocaltime.correctedtime) [$($adjustedlocaltime.timezone)]";
mailbody= "Please find attached the Cloudistics Snap Report generated on $($adjustedlocaltime.correctedtime) [$($adjustedlocaltime.timezone)]";
organization = $orgname;
key=(get-key)
}

if($mailfile){$mailvars.Add('mailfile',$mailfile)}
if($mailfolderlocation){$mailvars.Add('mailfolderlocation',$mailfolderlocation)}

$mailvars

send-mail @mailvars

}
else{
Invoke-Item -Path $reportpath
}
#endregion

Stop-Transcript

# SIG # Begin signature block
# MIID5wYJKoZIhvcNAQcCoIID2DCCA9QCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHTeoPfU+Q0nSZ9tcJ/MXbU9D
# //ygggIDMIIB/zCCAWigAwIBAgIQZXsLzuTF+b1PPg61Cp25RzANBgkqhkiG9w0B
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUYguHIVkyPFdn56r0Q5f1yAy8rJQwDQYJKoZI
# hvcNAQEBBQAEgYCa2H2zSDeCY070v0/J5yOpLdMXTL60viUu6xQ4zFLwyn8jGzOP
# MEhx12pgShGJRCDlg76m1xnuMfXyFFVPBEOVkNbyzu+3kI+YJW8vMnmjr8xZ8X6t
# DB5RTBkjHYKIw3BAqTPhnl87rDPxgZGpOLfjT86ACVuRdfj/6EukTpNdfg==
# SIG # End signature block
