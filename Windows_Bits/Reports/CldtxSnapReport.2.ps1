param(
$apitokenpath=$null,
$reportpath=$null,
[ValidateSet('all','DRSnap','userSelected')]$xfilter='userSelected', 
$columns=6,
[ValidateSet('local','utc','choose')]$timezone='choose',
$modulename = 'cloudisticsapimodule',
[switch]$setupmail,
[switch]$mail=$true


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

</style>
<script type="text/javascript">
<!--
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
//-->
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
$zelement = $zelement.replace("<table",'<table class="agenttable"')
if($xelement.count -gt 0){
$test=$null
$test = $xelement | Where-Object -FilterScript {($_.DRStatus -ne 'Completed') <#-and ($xtitle -ne 'Local Snapshots')#>}
if($test){$warning = "<strong><font color=red>In Progress!</font></strong>"}else{$warning =$null}
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
return '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'
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
return [pscustomobject]@{correctedtime=[System.TimeZoneInfo]::ConvertTimeFromUTC((Get-Date($timestamp)), $timezone) ;timezone=$timezone}
}
else{
return [pscustomobject]@{correctedtime=[System.TimeZoneInfo]::ConvertTime((Get-Date($timestamp)), $timezone) ;timezone=$timezone}
}
}
function get-xfileName {
param ($initialDirectory = "c:\",[switch]$savefile,$titleroot='Cloudistics Portal and API Key')

 $checkAssembly = ([System.AppDomain]::CurrentDomain.GetAssemblies() | where {$_.location -like "*System.Windows.Forms*"}).Location
 if(!($checkAssembly)){[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null}

 $FileDialog = New-Object System.Windows.Forms.OpenFileDialog
 $Title="Import $($titleroot)"
 if($savefile.IsPresent){
 $Filedialog = New-Object System.Windows.Forms.SaveFileDialog
 $Title = "Export $($titleroot)"
 }
 $filedialog.Title = $Title
 $FileDialog.initialDirectory = $initialDirectory
 $FileDialog.filter = "PowerShellModule (*.psd1)| *.psd1| All files (*.*)| *.*"
 $FileDialog.ShowDialog() | Out-Null
 return $FileDialog.filename
}
function decode-password {
param($encodedpassword)
$password =@([System.Text.Encoding]::UNICODE.GetString([System.Convert]::FromBase64String($encodedpassword)))
return $password
}
#------------------------------

Clear-Host
Write-Host "Preparing Snapshot Report Prerequisites...`n`n" -ForegroundColor Yellow



Write-Host "`nChecking module $modulename `n" -ForegroundColor Yellow
if(!(get-module -name $modulename)){
Write-Host "select the module to import..."
$modulepath = get-xfileName -initialDirectory c:\ -titleroot "Cloudistics Module"
if([System.String]::IsNullOrEmpty($modulepath)){Write-Host "`nNo Module selected. Exiting...`n"}
try{
if ((Split-path -Path $modulename -Leaf) -ne "$($modulename).psd1"){Write-Host "`nWARNING. This is not the expected module name! Expected '$modulename' and got '$((Split-path -Path $modulename -Leaf))' instead" }
import-module $modulepath -ErrorAction stop
}catch{Write-Host "Error. Could not import selcted module. Exiting..."; exit}
get-module -name $modulename
}

if(!($apitokenpath)){$zinfo = get-apitoken; $apitoken=$zinfo.apitoken; $portal = $zinfo.portal; $orgname = $zinfo.organization}
if(!($apitoken)){Write-Host "`nNo API Token Present. Exiting..." -ForegroundColor Yellow; exit}
if($setupmail.IsPresent){new-mailinfo -organization $orgname ; Write-Host "Done! Please run the script again without the '-setupmail' parameter";exit }
$cldxtimezones = get-cldtxtimezone -timezone $timezone
$cldxtimezones | Format-List
$adjustedlocaltime = set-correcttime -timestamp "$(get-date)" -timezoneid $cldxtimezones.localtimezone.id

if(!($reportpath)){$reportpath = "$($env:userprofile)\Downloads\$($orgname)-Snapshot_Report_$((get-date($adjustedlocaltime.correctedtime)).tostring('yyyy-MM_dd-HH-mm-ss')).html"}
$idx = @{apitoken=$apitoken;portal=$portal}

$list =@()
[array]$applications = get-resources @idx -resource applications
$totalapplicationscount = $applications.count
if($totalapplicationscount -lt 1){Write-Host "`nNo Applications to process. Exiting..." -ForegroundColor Yellow; exit}
#if(!($all.ispresent))

switch ($xfilter){
'all'          {<#$applications = $applications | select-object -property name,uuid;write-Host "xfilter = $xfilter";#>break;}
'userselected' {$applications = $applications | select-object -property name,uuid | Out-GridView -Title "Select the VMs to process" -PassThru;break}
'drSnap'       {
                Write-Host 'Please Wait...';
                $selectedObjects=$null;$selectedObjects = $applications | ForEach-Object {  (get-resources @idx -resource applications -uuid $_.uuid | select-object name,uuid,@{n='DR_Enabled';e={$_.disasterRecoveryPolicy.Enabled}})}
                $applications = $selectedObjects | where {$_.DR_Enabled -eq 'True'} | select-object -property name,uuid;break
               }
default        {Write-Host 'The -xfilter parameter is missing.`nTry again (use the TAB key to rotate through available options.';exit}

}

$selectedApplicationscount=$applications.count
if($selectedapplicationscount -lt 1){Write-Host "`nNo Applications to process. Exiting..." -ForegroundColor Yellow; exit}

$page        = pageheader
$title      = "Snapshot Report: $orgname Organization<br/>`nSelected Applications Count: $($selectedApplicationscount) out of $($totalapplicationscount)<br/>`n`[generated on $((get-date($adjustedlocaltime.correctedtime))) ($($cldxtimezones.localtimezone.id))`]"
$uline      = '-'*($title.Length)
Clear-Host
$alltitle   = "Cloudistics $($title.replace('<br/>',''))`n$uline`n`n"
$htmltitle  = "<table><tr><td valign=bottom><a id=xTop><a href=http://www.cloudistics.com ><img src=`"data:image/png;base64,$(get-logo)`" alt=`"logo`"/></a></td></tr><tr><td td style=`"color:darkorange;font-size:20px;font-weight:bold`">$($title)</td></tr></table><br/>"
Write-Host $alltitle -ForegroundColor Green

$page += $htmltitle

$xsummary = @()
$summary=$null

$applications | ForEach-Object {$xsummary += "<a href=#id_$($_.uuid)>$($_.name)</a>" }
for($i=0 ;$i -lt $xsummary.count; $i++){
$summary += "<td>$($xsummary[$i])</td>"
if(($i -gt 0) -and ($i % $columns -eq 0)){$summary += "</tr><tr>"}
}


$summary = "<table class=agenttable><tr>$($summary)</tr></table>"

$page += "<table ><tr><td>Jump To:</a></td><td>$($summary)</td></tr></table><br/>"

$page += "<table class=agenttable><tr><th>Application</th><th>Info</th><th>VDC/App-Group</th><th>Local [$($cldxtimezones.localtimezone.displayname)]</th><th>DR [$($cldxtimezones.DRtimezone.displayname)]</th</tr>"
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


  $segmentA = collapse-element -xelement $snapinfox -xtitle "Local Snapshots"
  $segmentB = collapse-element -xelement $snapinfoy -xtitle "DR Snapshots"

$color0 = 'Green'
if($secondaryinfo.status -ne 'Running'){$color0='Red'}

$segmentC = @"
<table class=emptytable>
<tr><td width=50px><strong>Status:</strong></td><td width=150px><strong><font color=$($color0)>$($secondaryinfo.status)</font></strong></td></tr>
<tr><td width=50px><strong>vCPU-s:</strong></td><td width=150px>$($secondaryinfo.vcpus)</td></tr>
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
  }else{$message="Not Set Up"}
  if($secondaryinfo.autoSnapshotPolicy.intervalInMinutes)
  {
  $interval="Interval:$(New-Timespan -minutes $secondaryinfo.autoSnapshotPolicy.intervalInMinutes -ErrorAction Silentlycontinue)"
  }

  $segmentA = $segmentA.replace('*****',"Policy: `[$($count)$($interval)$($message)`]")
  $policyheader = 'Not Enabled'
  if(($secondaryinfo.DRPolicy.all) -and ($SegmentB -eq '*****')){
  $xjavabutton = "<input type='button' value='Expand' disabled />"
  $xjavaprintbutton = "<input type='button' value='Print'  disabled />"
  $policyheader = htmlsectiontitle -t "DR SnapShots (0) <font color=Blue>Policy: `[All:$($secondaryinfo.DRPolicy.all); Daily:$($secondaryinfo.DRPolicy.daily); Monthly:$($secondaryinfo.DRPolicy.monthly); Yearly:$($secondaryinfo.DRPolicy.yearly)`]</font> $xjavabutton $xjavaprintbutton"
  }
  if($segmentB -ne '*****'){
  $policyheader = "`[All:$($secondaryinfo.DRPolicy.all); Daily:$($secondaryinfo.DRPolicy.daily); Monthly:$($secondaryinfo.DRPolicy.monthly); Yearly:$($secondaryinfo.DRPolicy.yearly)`]"
  }
 
  $segmentB = $segmentB.replace('*****',$policyheader)
 
 $page +="<tr><td><strong><a id=id_$($application.uuid)><a href=#xTop>$($application.name)</a></a><strong></td><td>$($segmentC)</td><td>$($vdc)$($appgrp)</td><td>$($segmentA)</td><td>$($SegmentB)</td></tr>" 


}
$page += "</table></body>"
$page | out-file -FilePath $reportpath

if($mail.IsPresent){

$mailvars = @{
mailattachment=$reportpath;
mailsubject="Cloudistics: $($orgname) Snapshot Report generated on $($adjustedlocaltime.correctedtime) [$($adjustedlocaltime.timezone)]";
mailbody= "Please find attached the Cloudistics Snap Report generated on $($adjustedlocaltime.correctedtime) [$($adjustedlocaltime.timezone)]";
organization = $orgname;
}

send-mail @mailvars

}
else{
Invoke-Item -Path $reportpath
}

