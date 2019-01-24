function get-cloudisticsApiModuleCodeVersion{
return '10.0.0.1'
}
#---------Module Use --------------------------
function import-cldtxmodule{
<#
.Synopsis
function to import a module
.Description 
Function that attempts importing a module (default module name: CloudisticsAPIModule) 
first from c:\Windows\System32\WindowsModules\v1.0\Modules, 
then from c:\programData\Cloudistics\SscriptData. 
If the module is not found, a GUI Dialog opens up allowing the user to select the 
location of the folder. Both the desired location of the module and its name
can be passed as parameters.
#>
param(
$commonrootpath="$($env:Programdata)\Cloudistics\ScriptData",
$modulename = 'cloudisticsapimodule'
)
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

if(!(get-module -name $modulename)){
      Write-Host "Attempting to load module from the Windows Default Location" -ForegroundColor Yellow
     try{import-module $modulename -erroraction stop 3>&1 | Out-Null;
     Write-Host "Success!" -ForegroundColor Green
     }
     catch{
     Write-Host "Failed!`nAttempting to load module from $($commonrootpath)" -ForegroundColor Yellow
     try{import-module "$($commonrootpath)\$($modulename)\$($modulename).psd1" -ErrorAction Stop 3>&1 | Out-Null;
     Write-Host "Success!" -ForegroundColor Green
     }
     catch{
     Write-Host "Failed!`nSelect the module to import..." -ForegroundColor Yellow
     $modulepath = get-xfileName -initialDirectory c:\ -titleroot "Cloudistics Module"     
     if([System.String]::IsNullOrEmpty($modulepath)){Write-Host "`nNo Module selected. Exiting...`n"}
     try{
          if ((Split-path -Path $modulepath -Leaf) -ne "$($modulename).psd1"){Write-Host "`nWARNING. This is not the expected module name! Expected '$modulename' and got '$((Split-path -Path $modulepath -Leaf))' instead" -ForegroundColor Red }
          import-module $modulepath -ErrorAction stop 3>&1 | Out-Null;
          Write-Host "Success!" -ForegroundColor Green
         }catch{
         Write-Host "`nError! Could not import selected module. Exiting..." -ForegroundColor Yellow; exit}
         }
}
}
return (get-module $modulename)
}
#----------------------------------------------

#---------REST API----------------
function submit-cldtxrestcall{
<#
.Synopsis
REST CALL primitive. Used by other functions

.Description
Function that attempts performing a REST CALL against the Cloudistics Engine. I is used in conjunction with other functions that process the parameters necessary to execute a successful REST CALL
Whenever possible, acceptable values are shown in validation lists.

.PARAMETER startindex
start-index=[positive integer] Defaults to 0

.PARAMETER limitcount
limit-count=[positive integer] Defaults to 1000

.PARAMETER datacenters
datacenters=[comma-delimited list of datacenter UUIDs]

.PARAMETER applicationgroups
application-groups  =[comma-delimited list of application group UUIDs]

.PARAMETER starttime
start‑timestamp ='yyyy-MM-dd'T'HH:mm:ss' i.e '2017-01-12'T'12:00:00'

.PARAMETER endtime
end‑timestamp ='yyyy-MM-dd'T'HH:mm:ss' i.e '2017-01-12'T'12:00:00'
#>
param (
[Parameter(Mandatory=$true)][ValidateSet('virtual-lab','prod','portal-rclab','beta')]$portal, 
[Parameter(Mandatory=$true)]$APIToken,
[Parameter(Mandatory=$true)]$uriaddon,
[Parameter(Mandatory=$true)][ValidateSet('GET','POST','PUT','DELETE')]$method, 
[Parameter(Mandatory=$false)]$body = $null,
[Parameter(Mandatory=$false)][ValidateSet('application/json','application/xml',$null)]$contenttype = $null,
[Parameter(Mandatory=$false)][ValidateSet('silentlycontinue','stop','inquire','ignore',$null)]$xerroraction='stop',
$startindex = $null,
$limitcount = $null,
$datacenters=$null,
$appgroups=$null,
$starttime=$null,
$endtime=$null
)
<#
start-index         =[positive integer]                                Defaults to 0
limit-count         =[positive integer]                                Defaults to 1000
datacenters         =[comma-delimited list of datacenter UUIDs]
application-groups  =[comma-delimited list of application group UUIDs]
start‑timestamp     ='yyyy-MM-dd'T'HH:mm:ss' i.e '2017-01-12'T'12:00:00'
end‑timestamp       ='yyyy-MM-dd'T'HH:mm:ss' i.e '2017-01-12'T'12:00:00'
#>


$tinyroot=$null
switch ($portal){
'virtual-lab'  {$tinyroot = 'virtual-lab';break}
'prod'         {$tinyroot = 'manage';break}
'portal-rclab' {$tinyroot = 'portal-rclab';break}
'beta'         {$tinyroot = 'beta';break}
}
$uriroot = "https://$($tinyroot).cloudistics.com/api/latest/"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization","Bearer $APIToken")
if('POST','PUT' -contains $method){$headers.Add("Content-Type",$contenttype)}

$urlparams=@{}
if($startindex){$urlparams.Add('startindex',$startindex)}
if($limitcount){$urlparams.Add('limitcount',$limitcount)}
if($datacenters){$urlparams.Add('datacenters',$datacenters)}
if($appgroups){$urlparams.Add('appgroups',$appgroups)}
if($starttime){$urlparams.Add('start-timestamp',"$((get-date($starttime.tostring())).tostring('yyyy-MM-ddTHH:mm:ss'))")}
if($endtime){$urlparams.Add('end-timestamp',"$((get-date($endtime.tostring())).tostring('yyyy-MM-ddTHH:mm:ss'))")}

if($urlparams.count -gt 0){
$urisign = "`?"
foreach($xitem in $urlparams.GetEnumerator()){
if($uriaddon  -match [regex]::Escape('?')){$urisign="`&"}
$uriaddon="$($uriaddon)$($urisign)$($xitem.Name)=$($xitem.value)"
}
}

<#
if($startindex){
if($uriaddon  -match [regex]::Escape('?')){$urisign="`&"}
$uriaddon="$($uriaddon)$($urisign)start-index=$($startindex)"
}
if($limitcount){
if($uriaddon  -match [regex]::Escape('?')){$urisign='&'}
$uriaddon="$($uriaddon)$($urisign)limit-count=$($limitcount)"
}
if($datacenters){
if($uriaddon  -match [regex]::Escape('?')){$urisign='&'}
$uriaddon="$($uriaddon)$($urisign)datacenters=$($datacenters)"
}
if($appgroups){
if($uriaddon  -match [regex]::Escape('?')){$urisign='&'}
$uriaddon="$($uriaddon)$($urisign)application-groups=$($appgroups)"
}
if($starttime){
if($uriaddon -match [regex]::Escape('?')){$urisign='&'}
$uriaddon="$($uriaddon)$($urisign)start-timestamp=$((get-date($starttime.tostring())).tostring('yyyy-MM-ddTHH:mm:ss'))"
}
if($endtime){
if($uriaddon  -match [regex]::Escape('?')){$urisign='&'}
$uriaddon="$($uriaddon)$($urisign)end-timestamp=$((get-date($starttime.tostring())).tostring('yyyy-MM-ddTHH:mm:ss'))"
}
#>
#Write-Host $uriaddon

$restcallargs = @{'headers'=$headers;'uri'="$($uriroot)$($uriaddon)";'method'=$method}

if($body){$restcallargs.add('body',$body)}
if($contenttype){$restcallargs.add('contenttype',$contenttype)}
if($xerroraction){$restcallargs.add('erroraction',$xerroraction)}
if($startindex){}

$response=$null
try{$response = Invoke-RestMethod @restcallargs}catch{$response = [pscustomobject]@{restcallargs=$restcallargs;error=$_;response=$_.error.Exception.Response;status=$_.error.Exception.Status} }

return $response


}
function submit-vmaction{
<#
.Synopsis
Basic actions pertaining to VMs

.Description
Performs the following operations (presented as a validation list) pertaining to VMs:
start VM
stop VM 
shutdown VM 
restart VM 
force-restart VM 
suspend VM 
resume VM 
delete VM

#>
param (
[Parameter(Mandatory=$true)][ValidateSet('start','stop','shutdown','restart','force-restart','suspend','resume','delete')]$action,
[Parameter(Mandatory=$true)]$machineUUID,
[Parameter(Mandatory=$true)][ValidateSet('virtual-lab','prod','portal-rclab')]$portal, 
[Parameter(Mandatory=$true)]$apitoken
)
switch ($action){
'delete' {$xmethod = 'DELETE'; $addon = "applications/$($machineUUID)";break}

default  {$xmethod = 'PUT'; $addon = "applications/$($machineUUID)/$($action)";break}
}

$response = submit-cldtxrestcall -portal $portal -APIToken $apitoken -uriaddon $addon -method $xmethod 
return $response

}
function get-resources{
<#
.Synopsis
Retrieves organization resources and details for a specific resource identified by UUID

.Description
Retrieves the information regarding the following resources (presented as a validation list):
 applications
 application-groups 
 tags
 categories 
 datacenters 
 migration-zones 
 vlans 
 vnets 
 flash-pools 
 templates 
 locations 
 compute-nodes 
 storage-blocks 
 storage-controllers
 allocations
When using the uuid parameter to point to a specific resource, the detailed info of that resource is retrieved.


#>
param(
[Parameter(Mandatory=$true)][ValidateSet('applications','application-groups','tags','categories','datacenters','migration-zones','vlans','vnets','flash-pools','templates','locations','compute-nodes','storage-blocks','storage-controllers','allocations')]$resource,
[Parameter(Mandatory=$true)][ValidateSet('virtual-lab','prod','portal-rclab')]$portal, 
[Parameter(Mandatory=$true)]$apitoken,
[Parameter(Mandatory=$false)]$uuid=$null
)
$addon=$resource
if($uuid){$addon = "$($addon)/$($uuid)"}
$response = submit-cldtxrestcall -portal $portal -APIToken $apitoken -uriaddon $addon -method GET 
return $response

}
function submit-snapshotaction{
<#
.Synopsis
perform snapshot operations

.Description
Allows managing snapshots for a VM. The following actions, presented as a validation list, are available:
getSnapshots 
getSnapshotInfo 
createSnapshot
deleteSnapshot
renameSnapshot

When a snapshot UUID is provided as a parameter, the delete and rename snapshot actions can be performed.


#>
param(
[Parameter(Mandatory=$true)]$machineUuid,
[Parameter(Mandatory=$true)][ValidateSet('virtual-lab','prod','portal-rclab')]$portal, 
[Parameter(Mandatory=$true)]$apitoken,
[Parameter(Mandatory=$false)]$snapshotUuid,
[Parameter(Mandatory=$false)]$snapNewName,
[Parameter(Mandatory=$true)][ValidateSet('getSnapshots','getSnapshotInfo','createSnapshot','deleteSnapshot','renameSnapshot')]$action
)
<#
'GET','POST','PUT','DELETE'
Get Snapshots:    /api/latest/applications/[APPLICATION UUID]/snapshots                      Method Get
Get Snapshot Info:/api/latest/applications/[APPLICATION UUID]/snapshots/[SNAPSHOT UUID]      Method GET
Create Snapshot:  /api/latest/applications/[APPLICATION UUID]/snapshots                      Method POST
Delete Snapshot:  /api/latest/applications/[APPLICATION UUID]/snapshots/[SNAPSHOT UUID]      Method DELETE
Rename Snapshot:  /api/latest/applications/[APPLICATION UUID]/snapshots/[SNAPSHOT UUID]/name Method PUT
#>
$addon = "applications/$($machineUuid)/snapshots"
$xmethod=$null
$xbody=$null
switch ($action){
'getSnapshots'    {$xmethod = 'GET';break}
'getSnapshotInfo' {$xmethod = 'GET';$addon = "$($addon)/$($snapshotUuid)";break}
'createSnapshot'  {$xmethod = 'POST';if ($snapNewName){$sname = $snapnewname}else{$sname="Snapshot $(get-Date)"};$xbody="{`"name`": `"$($sname)`"}";break}
'deleteSnapshot'  {$xmethod = 'DELETE';$addon = "$($addon)/$($snapshotUuid)";break}
'renameSnapshot'  {$xmethod = 'PUT';$addon = "$($addon)/$($snapshotUuid)/name";if ($snapNewName){$sname = $snapnewname}else{$sname="Snapshot $(get-Date)"};$xbody="{`"name`": `"$($sname)`"}";break}
}

$snapargs=@{portal=$portal;apitoken=$apitoken;uriaddon=$addon;method=$xmethod}
if($xbody){$snapargs.Add('body',$xbody);$snapargs.Add('content','application/json')}

$response = submit-cldtxrestcall @snapargs
return $response
#return $snapargs
}
function wait-tocomplete{
<#
,Synopsis
Reports when a Cloudistics job previously triggered is completed

.Description
Since some REST operations are executed asynchronously it is important to know when the execution is 
actually finished. The Wait-tocomplete function takes the operation UUID as an argument and returns
the exit status when the operation finishes. 

When the showprogress switch is added, a simple text based progress bar is shown.
#>
param(
[Parameter(Mandatory=$true)]$actionUuid,
[Parameter(Mandatory=$true)][ValidateSet('virtual-lab','prod','portal-rclab')]$portal, 
[Parameter(Mandatory=$true)]$apitoken,
[Parameter(Mandatory=$false)][switch]$showprogress
)

$addon = "actions/$($actionUuid)"
do{
start-sleep 3

$response = submit-cldtxrestcall -portal $portal -APIToken $apitoken -uriaddon $addon -method GET 

if($showprogress.IsPresent){write-Host "." -NoNewline}

}while('pending','processing' -contains $response.status)
if($showprogress.IsPresent){write-Host "."}
return $response.status
}
function submit-diskaction{
<#
.Synopsis
Executes disk virtual related operations

.Description
Allows managing the virtual disks on a VM (machineUUID param). The following operations are available via a validation list:
addDisk 
deleteDisk 
renameDisk 
resizeDisk 
cloneAndAttachDisk 
getDiskStats

For some operations (deleteDisk, resize disk, cloneAndAttachDisk,getDiskStats), the diskUUID parameter is needed.

Additionally, if a disk size is needed for an operation,  the diskSize parameter needs to be used. The diskSize can be expressed in Bytes or in PowerShell Size convention (i.e. 10GB, 10MB etc)

#>
param(
[Parameter(Mandatory=$true)][ValidateSet('addDisk','deleteDisk','renameDisk','resizeDisk','cloneAndAttachDisk','getDiskStats')]$action,
[Parameter(Mandatory=$true)]$machineUUID,
[Parameter(Mandatory=$false)]$diskUUID,
[Parameter(Mandatory=$false)]$diskName,
[Parameter(Mandatory=$false)]$diskSize,
[Parameter(Mandatory=$true)][ValidateSet('virtual-lab','prod','portal-rclab')]$portal, 
[Parameter(Mandatory=$true)]$apitoken
)


$xparam = @{'apitoken'=$apitoken;'portal'=$portal}
$xaddon = "applications/$($machineUUID)"


switch ($action){
'addDisk'               {$xparam.Add('body',"{`"name`" : `"$diskname`",`"size`" : $($disksize)}");
                         $xparam.Add('method','POST');
                         $xparam.Add('contenttype','application/json');
                         $xparam.Add('uriaddon',"$($xaddon)/disks" );
                         break}
'deleteDisk'            {$xparam.Add('method','DELETE');
                         $xparam.Add('uriaddon',"$($xaddon)/disks/$($diskUUID)" );
                         break}
'renameDisk'            { $xparam.Add('body',"{`"name`" : `"$diskname`"}");
                          $xparam.Add('contenttype','application/json');
                          $xparam.Add('method','PUT');
                          $xparam.Add('uriaddon',"$($xaddon)/disks/$($diskUUID)/name");
                          break}
'resizeDisk'            { $xparam.Add('body',"{`"size`" : $disksize}");
                          $xparam.Add('contenttype','application/json');
                          $xparam.Add('method','PUT');
                          $xparam.Add('uriaddon',"$($xaddon)/disks/$($diskUUID)/size");
                          break}
'cloneAndAttachDisk'    { 
                          <#
                            diskUUID = the uuid of the disk from a snapshot. You need to take a snapshot first
                            machineuuid = the uuid of themachine to which the clone is attached to
                          #>

                          $xparam.Add('body',"{`"uuid`" : `"$diskuuid`"}");
                          $xparam.Add('contenttype','application/json');
                          $xparam.Add('method','PUT');
                          $xparam.Add('uriaddon',"$($xaddon)/clone-and-attach-disk");
                          break}
'getDiskStats'          { 
                          $xparam.Add('method','GET');
                          $xparam.Add('uriaddon',"$($xaddon)/disks/$($diskUUID)");
                          break}

default                 { return 'no match'}

}

$result = submit-cldtxrestcall @xparam

return $result


}
#--------------Not Properly Tested -------------
function submit-vnicaction{
<#
.Synopsis
Manage vNics on a VM

.Description
Allows managing the virtual network adapters of a VM (parameter machineUUID). The following operations are supported:
renameVnic 
editVnicNetworkingType 
editVnicFirewall 
editVnicMAC 
addVnic 
removeVnic

VNIC uuids can be retrieved using the get-resources function as they are a part of a VM info.
For specific actions, additional specific parameters may be needed. These are:
networkUUID
vnicType
vnicMac
vnicName 
firewallOverrideUuid


#>
  param(
    [Parameter(Mandatory=$true)][ValidateSet('renameVnic','editVnicNetworkingType','editVnicFirewall','editVnicMAC','addVnic','removeVnic')]$action,
    [Parameter(Mandatory=$true)]$machineUUID,
    [Parameter(Mandatory=$false)]$vnicUUID,
    [Parameter(Mandatory=$false)]$vnicName,
    [Parameter(Mandatory=$false)]$vnicMac=$null,
    [Parameter(Mandatory=$false)]$networkUUID,
    [Parameter(Mandatory=$false)]$firewallOverrideUuid=$null,
    [Parameter(Mandatory=$false)][ValidateSet('VNET','VLAN')]$vNicType,
    [Parameter(Mandatory=$true)][ValidateSet('virtual-lab','prod','portal-rclab')]$portal, 
    [Parameter(Mandatory=$true)]$apitoken
  )


  $xparam = @{'apitoken'=$apitoken;'portal'=$portal}
  $xaddon = "applications/$($machineUUID)/vnics/"


  switch ($action){
    'renameVnic'             { $xparam.Add('body',"{`"name`" : `"$vnicname`"}");
                               $xparam.Add('method','PUT');
                               $xparam.Add('uriaddon',"$($xaddon)$($vnicUUID)/name");
                             break}
                          
    'editVnicNetworkingType' { if($vnicType -eq 'VLAN'){$xparam.Add('body',"{`"type`" : `"VLAN`"}")};
                               if($vnicType -eq 'VNET'){$xparam.Add('body',"{`"type`" : `"VNET`",`"networkUUID`":`"$($networkUUID)`"}")};
                               $xparam.Add('method','PUT');
                               $xparam.Add('uriaddon',"$($xaddon)$($vnicUUID)/type");
                          break}

    'editVnicFirewall'   { $xparam.Add('body',"{`"firewallOverrideUuid`" : `"$firewallOverrideUuid`"}");
                           $xparam.Add('method','PUT');
                           $xparam.Add('uriaddon',"$($xaddon)$($vnicUUID)/firewall");
                          break}

    'editVnicMAC'        { if($vnicMac){$statement='false'}else{$statement='true'};
                           $xparam.Add('body',"{`"macAddress`" : `"$vnicMac`",`"automaticMACAssignment`" : $statement}");
                           $xparam.Add('method','PUT');
                           $xparam.Add('uriaddon',"$($xaddon)$($vnicUUID)/mac-address");
                          break}

    'addVnic'            { if($vnicMac){$statement='false'}else{$statement='true'};
                           if($firewallOverrideUuid){$firewallOverrideUuid = "`"$firewallOverrideUuid`""}else{$firewallOverrideUuid = 'null'}
                           $xparam.Add('body',"{`"name`" : `"$vnicname`",`"type`" : `"$vnictype`",`"networkUuid`" : `"$networkUUID`",`"firewallOverrideUuid`" : $($firewallOverrideUuid),`"macAddress`" : `"$vnicMac`",`"automaticMACAssignment`" : $statement}");
                           $xparam.Add('method','POST');
                           $xparam.Add('uriaddon',"$($xaddon)");
                          break}
                          
    'removeVnic'         { $xparam.Add('method','DELETE');
                           $xparam.Add('uriaddon',"$($xaddon)$($vnicUuid)");    
                          break}

    default                 { return 'no match'}
  }
  
  if('PUT','POST' -contains $xparam.Method){$xparam.Add('contenttype','application/json');}
  

    $result = submit-cldtxrestcall @xparam

  return $result


}
function edit-machineproperties{
<#
.Synopsis
Allows editing VM properties; it includes editing some properties that were included in other functions on this module

.Description
Allows managing the properties of a VM (parameter machineUUID). The following operations, provided via a validation list, are supported:
description 
datacenter 
migrationZone 
bootorder 
vCpus 
memory 
computeTags 
computeCategory 
vNicName 
vNicNetworkingType 
vNicFireWall 
vNicMacAddress 
diskName 
diskSize 
applicationVirtualizationSettings 
automaticRecoverySettings 
applicationVMMode

Some similar operations (i.e. vnic or vdisk related) may be executed via less complex functions (submit-diskaction, submit-vnicaction). However, they have been included in this function for human logic reasons.

Some of the operations unique to this function are:
Boot order setting (parameter bootOrderObject, bootOrderJson)
Memory size (parameter memory)
Compute Category (parameter computeCategoryUuid)
Application Virtualization Settings (parameter pplicationVirtualizationSettings)
Automatic Recovery Settings (parameter automaticRecoverySettings )
Application VM Mode (parameter applicationVMMode)
VM Description (no new parameter needed)
Data Center (no new parameter needed)
MigrationZone (parameter migrationZoneUuid)

#>
param (
[Parameter(Mandatory=$true)][ValidateSet('description','datacenter','migrationZone','bootorder','vCpus','memory','computeTags','computeCategory','vNicName','vNicNetworkingType','vNicFireWall','vNicMacAddress','diskName','diskSize','applicationVirtualizationSettings','automaticRecoverySettings','applicationVMMode')]$property,
[Parameter(Mandatory=$true)]$machineUUID,
[Parameter(Mandatory=$true)][ValidateSet('virtual-lab','prod','portal-rclab')]$portal, 
[Parameter(Mandatory=$true)]$apitoken,
[Parameter(Mandatory=$false)]$vmDescription,
[Parameter(Mandatory=$false)]$vmName=$null,
[Parameter(Mandatory=$false)]$datacenterUuid,
[Parameter(Mandatory=$false)]$migrationZoneUuid,
[Parameter(Mandatory=$false)]$bootOrderObject=$null,
[Parameter(Mandatory=$false)]$bootOrderJson=$null,
[Parameter(Mandatory=$false)]$vcpus,
[Parameter(Mandatory=$false)]$memory,
[Parameter(Mandatory=$false)]$addComputeTags=$null,
[Parameter(Mandatory=$false)]$removeComputeTags=$null,
[Parameter(Mandatory=$false,HelpMessage="Not needed to revert to the 'Any' category")]$computeCategoryUuid=$null,
[Parameter(Mandatory=$false)]$vnicUuid,
[Parameter(Mandatory=$false)]$vnicName,
[Parameter(Mandatory=$false)][ValidateSet('VLAN','VNET')]$vnicType,
[Parameter(Mandatory=$false)]$vnetNetworkUuid=$null,
[Parameter(Mandatory=$false)]$firewallOverrideUuid,
[Parameter(Mandatory=$false)]$macaddress=$null,
#[Parameter(Mandatory=$false)][ValidateSet('true','false')]$automaticMacAssignment='true'
[Parameter(Mandatory=$false)]$diskUuid,
[Parameter(Mandatory=$false)]$diskName,
[Parameter(Mandatory=$false)]$diskSize,
[Parameter(Mandatory=$false)][ValidateSet('true','false')]$hardwareAssistedVirtualization,
[Parameter(Mandatory=$false)][ValidateSet('true','false')]$automaticRecovery,
[Parameter(Mandatory=$false)][ValidateSet('Enhanced','Compatibility')]$vmMode
)

$xaddon = "applications/$($machineUUID)"
$method='PUT'
$idx = @{apitoken=$ApiToken;portal=$portal;method=$method;contenttype='application/json'}

switch ($property){

'description'        {$addon = "$($xaddon)/description";     $body = "{`"description`":`"$($vmDescription)`"}";break;}
'datacenter'         {$addon = "$($xaddon)/datacenter";      if($vmName){$body = "{`"name`":`"`$($vmname)`",`"datacenterUuid`":`"$($datacenterUuid)`"}";break;}else{$body = "{`"datacenterUuid`":`"$($datacenterUuid)`"}";break;}}
'migrationZone'      {$addon = "$($xaddon)/migration-zone";  $body = "{`"migrationZoneUuid`":`"$($migrationZoneUuid)`"}";break;}
'bootorder'          {$addon = "$($xaddon)/boot-order";      if($bootOrderJson){$body=$bootOrderJson;break};if($bootOrderobject){$body=$bootOrderObject | ConvertTo-Json;break}}
'vCpus'              {$addon = "$($xaddon)/vcpus";           $body="{`"vcpus`":$($vcpus)}";break;}
'memory'             {$addon = "$($xaddon)/memory";          $body="{`"memory`":$($memory)}";break;}
'computeTags'        {$addon = "$($xaddon)/compute-tags";    $computetagsjson = [pscustomobject]@{addTags=$addComputeTags;removeTags=$removeComputeTags} | Convertto-Json; $body=$computetagsjson;break;}
'computeCategory'    {$addon = "$($xaddon)/compute-category";$body="{`"categoryUuid`":`"$($computeCategoryUuid)`"}";break;}
'vNicName'           {$addon = "$($xaddon)/vnics/$($vnicUuid)/name";$body="{`"name`":`"$($vnicname)`"}";break}
'vNicNetworkingType' {$addon = "$($xaddon)/vnics/$($vnicUuid)/type";if($vnictype -eq 'VNET'){$body="{`"type`":`"$()$vnicType`",`"networkUuid`":`"$($vnetNetworkUuid)`"}"};if($vnictype -eq 'VLAN'){$body="{`"type`":`"$()$vnicType`"}"};break}
'vNicFireWall'       {$addon = "$($xaddon)/vnics/$($vnicUuid)/firewall";$body = "{`"firewallOverrideUuid`":`"$($firewallOverrideUuid)`"}";break;}
'vNicMacAddress'     {$addon = "$($xaddon)/vnics/$($vnicUuid)/mac-address";if($macaddress){$body="{`"macAddress`":`"$($macAddress)`",`"automaticMacAssignment`":`"false`"}"}else{$body="{`"macAddress`":`"`",`"automaticMacAssignment`":`"true`"}"};break}
'diskName'           {$addon = "$($xaddon)/disks/$($diskUuid)/name";$body="{`"name`":`"$($diskName)`"}";break}
'diskSize'           {$addon = "$($xaddon)/disks/$($diskUuid)/size";$body="{`"size`":$($diskSize)}";break}
'applicationVirtualizationSettings' {$addon = "$($xaddon)/hardware-assisted-virtualization";$body="{`"hardwareAssistedVirtualization`":$($hardwareAssistedVirtualization)}";break;}
'automaticRecoverySettings' {$addon = "$($xaddon)/automatic-recovery";$body="{`"automaticRecovery`": $($automaticRecovery)}";break;}
'applicationVMMode' {$addon = "$($xaddon)/vm-mode";$body="{`"vmMode`": `"$($vmMode)}`"}";break;}

default         {return "Error. Possibly wrong parameters"}

}

$result = submit-cldtxrestcall @idx -uriaddon $addon -body $body 

return $result
}
#-----------------------------------------------

#-------New API Token or Mail Settings File-----
function new-apitokenfile{
<#
.Synopsis
Creates a Json Organization Configuration file

.Description
Run without parameters to create (via a GUI element) a json file containing the organization configuration necessary for the Cloudistics REST API Calls and saving it to the desired location.
Use the parameters to create the same file programmatically.

#>
param (
[Parameter(Mandatory=$false)]$filelocation = $null,
[Parameter(Mandatory=$false)][ValidateSet('virtual-lab','prod','portal-rclab','beta')]$portal,
[Parameter(Mandatory=$false)]$apitoken=$null,
[Parameter(Mandatory=$false)]$organization=$null
)
if(!($filelocation)){
$xreply = set-message -message "New File? Hit 'Yes'`nEdit Existing File? Hit 'No'`nSecond Thoughts? Hit 'Cancel'" -title "Select API Token File Action" -buttons YesNoCancel

switch ($xreply){
'Yes'    {$stackparams = [pscustomobject]@{portal=$portal;organization=$organization;apitoken=$apitoken;location=$filelocation};break}
'No'     {$stackparams = get-apitoken;break;}
'Cancel' {exit}
                }
}


#region XAML window definition
$xaml = @'
<Window
   xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
   xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
   MinWidth="200"
   Width ="400"
   SizeToContent="Height"
   Title="Cloudistics API Info"
   Topmost="True">
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
      <TextBlock Grid.Column="0" Grid.Row="0" Grid.ColumnSpan="2" Margin="5">Please enter your details:</TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="1" Margin="5">Portal</TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="2" Margin="5">Organization</TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="3" Margin="5">API Token</TextBlock>
      <ComboBox Name="ComboPortal" Grid.Column="1" Grid.Row="1" Margin="5" AllowDrop="True" SelectedIndex="0">
      <ComboBoxItem Name="virtuallab">virtual-lab</ComboBoxItem>
      <ComboBoxItem Name="prod">prod</ComboBoxItem>
      <ComboBoxItem Name="portalrclab">portal-rclab</ComboBoxItem>
      <ComboBoxItem Name="beta">beta</ComboBoxItem>
      </ComboBox>      
      <TextBox Name="TxtOrg" Grid.Column="1" Grid.Row="2" Margin="5"></TextBox>
      <TextBox Name="TxtApiToken" Grid.Column="1" Grid.Row="3" Margin="5"  TextWrapping="Wrap"></TextBox>
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
$window.add_Loaded(
{
$cmbindex = $window.ComboPortal.Items.Name.indexof($stackparams.portal.Replace('-',$null))
$window.ComboPortal.SelectedIndex = $cmbindex
$window.TxtOrg.Text = $stackparams.organization
$window.TxtApiToken.Text = $stackparams.apitoken

}
)

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
#endregion Event Handlers

#region Manipulate Window Content
$null = $window.ComboPortal.Focus()
#endregion

# Show Window
$result = Show-WPFWindow -Window $window

#region Process results
if ($result -eq $true)
{

 $stackparams = [PSCustomObject]@{portal = $window.ComboPortal.SelectedValue.Content;organization = $window.TxtOrg.Text;apitoken=$window.TxtApiToken.Text;location=$filelocation}

$filelocation = get-fileName -savefile -initialDirectory (get-location) -titleroot "organization configuration settings"
$stackparams.location = $filelocation
if($filelocation){$stackparams | ConvertTo-Json | Out-File $filelocation
return $stackparams
}
}
else
{
  set-message -message 'Canceled!' -icon Warning
  return 'Canceled'
}
#endregion Process results
}
function new-mailinfo{
<#
.Synopsis
Configure e-mail settings to send a Cloudistics related file

.Description
Run without parameters to create (via a GUI) element a json file containing the configuration 
necessary to sending a file via e-mail to the desired recipient and saving it to the desired location.
Separate multiple recipients via comas.
Use the parameters to create the same file programmatically.
IMPORTANT: the 'get-key' function in the CloudisticsPowerShellModule module is needed for password encryption.
File:
{
    "mailfrom":  "<user@domain.com>",
    "mailto":  "<user@domain.com>",
    "smtpserver":  "<smtp.maildomain.com>",
    "smtpport":  "<smtpport>",
    "enableSSL":  "<yes/no>",
    "usecredentials":  "<yes/no>",
    "smtpusername":  "<user@domain.com>",
    "smtppassword":  "<encryptedSmtpPassword>",
    "location":  "<location>"
}

#>
param (
[Parameter(Mandatory=$false)]$mailfolderlocation=$null,
[Parameter(Mandatory=$false)]$organization=$null,
[Parameter(Mandatory=$false)]$mailfile = "$($organization)MailSettings.json",
[Parameter(Mandatory=$false)][switch]$otherlocation,
[Parameter(Mandatory=$false)]$key
)

#if(!($key)){$key = get-key}

#if(!(Test-Path $mailfolderlocation)){New-Item -Path $mailfolderlocation -ItemType Directory -Force |Out-Null}

$checkAssembly = ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object -FilterScript {$_.location -like "*PresentationCore*"}).Location
if(!($checkAssembly)){[System.Reflection.Assembly]::LoadWithPartialName("System.windows.Presentation.Core") | Out-Null}

if(!($mailfolderlocation)){
$xreply = set-message -message "New Mail Config File? Hit 'Yes'`nEdit Existing Mail Config File? Hit 'No'`nSecond Thoughts? Hit 'Cancel'" -title "Select API Token File Action" -buttons YesNoCancel
#$mailpropertylist = "mailfrom","mailto","smtpserver","smtpport","enableSSL","usecredentials","smtpusername","smtppassword","location"

switch ($xreply){
'Yes'    {$mailparams = [pscustomobject]@{mailfrom = $null; mailto=$null; smtpserver=$null;smtpport=$null;enableSSL=$null;usecredentials=$null;smtpusername=$null;smtppassword=$null;location=$null};
          break}
'No'     {
          $mailconfigpath = get-fileName -titleroot 'mail configuration file';
          break;}
'Cancel' {exit}
                }
}


<#
$mailconfigpath = "$($mailfolderlocation)\$($mailfile)"

if($otherlocation.IsPresent){

 $mailconfigpath = get-filename -initialDirectory "$($env:ProgramData)" -savefile -titleroot 'mail configuration file'
 if([System.string]::IsNullOrEmpty($mailconfigpath)){Write-Host "Canceled. Exiting...";exit}
 }
#>

#region XAML window definition
$xaml = @'
<Window
   xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
   xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
   MinWidth="200"
   Width="400"
   SizeToContent="Height"
   Title="Cloudistics Mail Settings Info"
   Topmost="True">
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
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <TextBlock
         Grid.Column="0"
         Grid.ColumnSpan="2"
         Grid.Row="0"
         Margin="5">Please enter your details:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="1" Margin="5">Mail From:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="2" Margin="5">Mail To:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="3" Margin="5">SMTP Server:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="4" Margin="5">SMTP Port:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="5" Margin="5">Enable SSL:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="6" Margin="5">Use Credentials:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="7" Margin="5" Name="tblckSMTPUserNAme">SMTP User Name:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="8" Margin="5" Name="tblckSMTPPassword">SMTP Password:
      </TextBlock>
      <CheckBox Name="chkShowPassword"  Grid.Row="9" Margin="5" Content=": Show Password" FlowDirection="RightToLeft" VerticalAlignment="Center"></CheckBox>
      <Label Name="lblPassword" Grid.Row="9" Margin="5"  Grid.Column="1" VerticalAlignment="Center" Content=""></Label>
      <TextBox
         Name="TxtMailFrom"
         Grid.Column="1"
         Grid.Row="1"
         Margin="5">
      </TextBox>
      <TextBox
         Name="TxtMailTo"
         Grid.Column="1"
         Grid.Row="2"
         Margin="5">
      </TextBox>
      <TextBox
         Name="TxtSMTPServer"
         Grid.Column="1"
         Grid.Row="3"
         Margin="5">
      </TextBox>
      <TextBox
         Name="TxtSMTPPort"
         Grid.Column="1"
         Grid.Row="4"
         Margin="5">
      </TextBox>
      <ComboBox
         Name="CmbSSL"
         Grid.Column="1"
         Grid.Row="5"
         Margin="5"
         AllowDrop="True"
         SelectedIndex="0">
         <ComboBoxItem Name="cs0">no
         </ComboBoxItem>
         <ComboBoxItem Name="cs1">yes
         </ComboBoxItem>
      </ComboBox>
      <ComboBox
         Name="CmbUseCreds"
         Grid.Column="1"
         Grid.Row="6"
         Margin="5"
         AllowDrop="True"
         SelectedIndex="0">
         <ComboBoxItem Name="c0">no
         </ComboBoxItem>
         <ComboBoxItem Name="c1">yes 
         </ComboBoxItem>
      </ComboBox>
      <TextBox
         Name="TxtUserName"
         Grid.Column="1"
         Grid.Row="7"
         Margin="5">
      </TextBox>
      <PasswordBox 
         Name="pwboxPassword"
          Visibility="Visible"
         Grid.Column="1"
         Grid.Row="8"
         Margin="5">
      </PasswordBox>
      <StackPanel
         Grid.ColumnSpan="2"
         Grid.Row="10"
         HorizontalAlignment="Right"
         Margin="0,10,0,0"
         VerticalAlignment="Bottom"
         Orientation="Horizontal">
         <Button
            Name="ButOk"
            Height="22"
            MinWidth="80"
            Margin="5">OK
         </Button>
         <Button
            Name="ButCancel"
            Height="22"
            MinWidth="80"
            Margin="5">Cancel
         </Button>
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

$window.cmbUseCreds.add_SelectionChanged(
{
if($window.cmbUseCreds.SelectedValue.content -eq 'no'){
$window.TxtUserName.Visibility=[System.Windows.Visibility]::Collapsed
$window.tblckSMTPUserNAme.Visibility =[System.Windows.Visibility]::Collapsed
$window.tblckSMTPPassword.Visibility=[System.Windows.Visibility]::Collapsed
$window.pwboxPassword.Visibility =[System.Windows.Visibility]::Collapsed
$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Collapsed
}
if($window.cmbUseCreds.SelectedValue.content -eq 'yes'){
$window.TxtUserName.Visibility=[System.Windows.Visibility]::Visible;
$window.tblckSMTPUserName.Visibility =[System.Windows.Visibility]::Visible;
$window.tblckSMTPPassword.Visibility=[System.Windows.Visibility]::Visible;
$window.pwboxPassword.Visibility = [System.Windows.Visibility]::Visible;
$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Visible;

}
}
)

$window.add_loaded(
{
$window.lblPassword.visibility=[System.Windows.Visibility]::Hidden

try{
$mailparams = Get-Content -Path $mailconfigpath -ErrorAction Stop | ConvertFrom-Json
$window.TxtMailFrom.Text=$mailparams.mailfrom
$window.TxtMailTo.Text=$mailparams.mailto
$window.TxtSmtpServer.Text=$mailparams.smtpserver
$window.TxtSmtpPort.Text=$mailparams.smtpport
if($mailparams.enableSSL -eq 'yes'){$selindex=1}else{$selindex=0}
$window.cmbSSL.selectedIndex = $selindex
if($mailparams.usecredentials -eq 'yes'){$selindex=1}else{$selindex=0}
$window.cmbUseCreds.SelectedIndex = $selindex
$window.TxtUserName.Text=$mailparams.smtpUserName
$window.pwboxPassword.password =  $mailparams.smtppassword | set-encodeEncrypt DecryptFromPlainText -key (get-key)
$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Visible
}
catch{
$mailparams = [pscustomobject]@{mailfrom=$null;mailto=$null;smtpserver=$null;smtpport="25";enableSSL="no";usecredentials="no";smtpusername="N/A";smtppassword="N/A"}

$window.TxtUserName.Visibility=[System.Windows.Visibility]::Collapsed
$window.tblckSMTPUserNAme.Visibility =[System.Windows.Visibility]::Collapsed
$window.tblckSMTPPassword.Visibility=[System.Windows.Visibility]::Collapsed
$window.pwboxPassword.Visibility =[System.Windows.Visibility]::Collapsed
$window.lblPassword.Visibility=[System.Windows.Visibility]::Collapsed
$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Collapsed
}
}
)

$window.chkShowPassword.add_Checked(
{
$window.lblPassword.Visibility= [System.Windows.Visibility]::Visible
$window.lblPassword.Content = $window.pwboxPassword.Password
}
)

$window.chkShowPassword.add_UnChecked(
{
$window.lblPassword.Visibility= [System.Windows.Visibility]::Hidden
#$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Hidden
}
)
$window.pwboxPassword.add_PasswordChanged(
{
$window.lblPassword.Content = $window.pwboxPassword.Password
}
)



#endregion Event Handlers

#region Manipulate Window Content
$null = $window.TxtMailFrom.Focus()
#endregion

# Show Window
$result = Show-WPFWindow -Window $window

#region Process results

if ($result -eq $true)
{
 #$stackparams = [PSCustomObject]@{portal = $window.ComboPortal.SelectedValue.Content;organization = $window.TxtOrg.Text;apitoken=$window.TxtApiToken.Text}
 $mailparams = [pscustomobject]@{
 mailfrom=$window.TxtMailFrom.Text;
 mailto=$window.TxtMailTo.Text;
 smtpserver=$window.TxtSMTPServer.Text;
 smtpport=$window.TxtSMTPPort.Text;
 enableSSL=$window.cmbSSL.selectedValue.Content;
 usecredentials=$window.cmbUseCreds.selectedValue.Content;
 smtpusername=$window.TxtUserName.Text;
 smtppassword=$window.pwboxPassword.Password.Trim() | set-encodeEncrypt Encrypt -key (get-key) -ErrorAction SilentlyContinue;
 location=$mailconfigpath
 }
$mailconfigpath = get-fileName -savefile -initialDirectory (get-location) -titleroot "mail configuration settings"
$mailparams.location = $mailconfigpath
if($mailconfigpath){$mailparams | convertto-json | Out-file -FilePath $mailconfigpath; $mailconfigpath = $null}
}
else
{
$mailconfigpath = $null
  return set-message -message 'Canceled!' -icon Warning

}
#endregion Process results


}

function new-mailinfox{
param (
[Parameter(Mandatory=$false)]$mailfolderlocation = "$($env:ProgramData)\Cloudistics\ScriptData",
[Parameter(Mandatory=$false)]$organization=$null,
[Parameter(Mandatory=$false)]$mailfile = "$($organization)MailSettings.json",
[Parameter(Mandatory=$false)][switch]$otherlocation,
[Parameter(Mandatory=$false)]$key
)

if(!($key)){$key = get-key}

if(!(Test-Path $mailfolderlocation)){New-Item -Path $mailfolderlocation -ItemType Directory -Force |Out-Null}

$checkAssembly = ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object -FilterScript {$_.location -like "*PresentationCore*"}).Location
if(!($checkAssembly)){[System.Reflection.Assembly]::LoadWithPartialName("System.windows.Presentation.Core") | Out-Null}

$mailconfigpath = "$($mailfolderlocation)\$($mailfile)"

if($otherlocation.IsPresent){

 $mailconfigpath = get-filename -initialDirectory "$($env:ProgramData)" -savefile -titleroot 'mail configuration file'
 if([System.string]::IsNullOrEmpty($mailconfigpath)){Write-Host "Canceled. Exiting...";exit}
 }



#region XAML window definition
$xaml = @'
<Window
   xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
   xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
   MinWidth="200"
   Width="400"
   SizeToContent="Height"
   Title="Cloudistics Mail Settings Info"
   Topmost="True">
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
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <TextBlock
         Grid.Column="0"
         Grid.ColumnSpan="2"
         Grid.Row="0"
         Margin="5">Please enter your details:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="1" Margin="5">Mail From:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="2" Margin="5">Mail To:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="3" Margin="5">SMTP Server:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="4" Margin="5">SMTP Port:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="5" Margin="5">Enable SSL:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="6" Margin="5">Use Credentials:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="7" Margin="5" Name="tblckSMTPUserNAme">SMTP User Name:
      </TextBlock>
      <TextBlock Grid.Column="0" Grid.Row="8" Margin="5" Name="tblckSMTPPassword">SMTP Password:
      </TextBlock>
      <CheckBox Name="chkShowPassword"  Grid.Row="9" Margin="5" Content=": Show Password" FlowDirection="RightToLeft" VerticalAlignment="Center"></CheckBox>
      <Label Name="lblPassword" Grid.Row="9" Margin="5"  Grid.Column="1" VerticalAlignment="Center" Content=""></Label>
      <TextBox
         Name="TxtMailFrom"
         Grid.Column="1"
         Grid.Row="1"
         Margin="5">
      </TextBox>
      <TextBox
         Name="TxtMailTo"
         Grid.Column="1"
         Grid.Row="2"
         Margin="5">
      </TextBox>
      <TextBox
         Name="TxtSMTPServer"
         Grid.Column="1"
         Grid.Row="3"
         Margin="5">
      </TextBox>
      <TextBox
         Name="TxtSMTPPort"
         Grid.Column="1"
         Grid.Row="4"
         Margin="5">
      </TextBox>
      <ComboBox
         Name="CmbSSL"
         Grid.Column="1"
         Grid.Row="5"
         Margin="5"
         AllowDrop="True"
         SelectedIndex="0">
         <ComboBoxItem Name="cs0">no
         </ComboBoxItem>
         <ComboBoxItem Name="cs1">yes
         </ComboBoxItem>
      </ComboBox>
      <ComboBox
         Name="CmbUseCreds"
         Grid.Column="1"
         Grid.Row="6"
         Margin="5"
         AllowDrop="True"
         SelectedIndex="0">
         <ComboBoxItem Name="c0">no
         </ComboBoxItem>
         <ComboBoxItem Name="c1">yes 
         </ComboBoxItem>
      </ComboBox>
      <TextBox
         Name="TxtUserName"
         Grid.Column="1"
         Grid.Row="7"
         Margin="5">
      </TextBox>
      <PasswordBox 
         Name="pwboxPassword"
          Visibility="Visible"
         Grid.Column="1"
         Grid.Row="8"
         Margin="5">
      </PasswordBox>
      <StackPanel
         Grid.ColumnSpan="2"
         Grid.Row="10"
         HorizontalAlignment="Right"
         Margin="0,10,0,0"
         VerticalAlignment="Bottom"
         Orientation="Horizontal">
         <Button
            Name="ButOk"
            Height="22"
            MinWidth="80"
            Margin="5">OK
         </Button>
         <Button
            Name="ButCancel"
            Height="22"
            MinWidth="80"
            Margin="5">Cancel
         </Button>
      </StackPanel>
   </Grid>
</Window>
'@
#endregion

#region Code Behind

#endregion Code Behind

#region Convert XAML to Window
$window = Convert-XAMLtoWindow -XAML $xaml 
#endregion

#region Define Event Handlers
# Right-Click XAML Text and choose WPF/Attach Events to
# add more handlers
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

$window.cmbUseCreds.add_SelectionChanged(
{
if($window.cmbUseCreds.SelectedValue.content -eq 'no'){
$window.TxtUserName.Visibility=[System.Windows.Visibility]::Collapsed
$window.tblckSMTPUserNAme.Visibility =[System.Windows.Visibility]::Collapsed
$window.tblckSMTPPassword.Visibility=[System.Windows.Visibility]::Collapsed
$window.pwboxPassword.Visibility =[System.Windows.Visibility]::Collapsed
$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Collapsed
}
if($window.cmbUseCreds.SelectedValue.content -eq 'yes'){
$window.TxtUserName.Visibility=[System.Windows.Visibility]::Visible;
$window.tblckSMTPUserName.Visibility =[System.Windows.Visibility]::Visible;
$window.tblckSMTPPassword.Visibility=[System.Windows.Visibility]::Visible;
$window.pwboxPassword.Visibility = [System.Windows.Visibility]::Visible;
$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Visible;

}
}
)

$window.add_loaded(
{
$window.lblPassword.visibility=[System.Windows.Visibility]::Hidden

try{
$mailparams = Get-Content -Path $mailconfigpath -ErrorAction Stop | ConvertFrom-Json
$window.TxtMailFrom.Text=$mailparams.mailfrom
$window.TxtMailTo.Text=$mailparams.mailto
$window.TxtSmtpServer.Text=$mailparams.smtpserver
$window.TxtSmtpPort.Text=$mailparams.smtpport
if($mailparams.enableSSL -eq 'yes'){$selindex=1}else{$selindex=0}
$window.cmbSSL.selectedIndex = $selindex
if($mailparams.usecredentials -eq 'yes'){$selindex=1}else{$selindex=0}
$window.cmbUseCreds.SelectedIndex = $selindex
$window.TxtUserName.Text=$mailparams.smtpUserName
$window.pwboxPassword.password =  $mailparams.smtppassword | set-encodeEncrypt DecryptFromPlainText
$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Visible
}
catch{
$mailparams = [pscustomobject]@{mailfrom=$null;mailto=$null;smtpserver=$null;smtpport="25";enableSSL="no";usecredentials="no";smtpusername="N/A";smtppassword="N/A"}

$window.TxtUserName.Visibility=[System.Windows.Visibility]::Collapsed
$window.tblckSMTPUserNAme.Visibility =[System.Windows.Visibility]::Collapsed
$window.tblckSMTPPassword.Visibility=[System.Windows.Visibility]::Collapsed
$window.pwboxPassword.Visibility =[System.Windows.Visibility]::Collapsed
$window.lblPassword.Visibility=[System.Windows.Visibility]::Collapsed
$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Collapsed
}
}
)

$window.chkShowPassword.add_Checked(
{
$window.lblPassword.Visibility= [System.Windows.Visibility]::Visible
$window.lblPassword.Content = $window.pwboxPassword.Password
}
)

$window.chkShowPassword.add_UnChecked(
{
$window.lblPassword.Visibility= [System.Windows.Visibility]::Hidden
#$window.chkShowPassword.Visibility=[System.Windows.Visibility]::Hidden
}
)
$window.pwboxPassword.add_PasswordChanged(
{
$window.lblPassword.Content = $window.pwboxPassword.Password
}
)



#endregion Event Handlers

#region Manipulate Window Content
$null = $window.TxtMailFrom.Focus()
#endregion

# Show Window
$result = Show-WPFWindow -Window $window

#region Process results
if ($result -eq $true)
{
 #$stackparams = [PSCustomObject]@{portal = $window.ComboPortal.SelectedValue.Content;organization = $window.TxtOrg.Text;apitoken=$window.TxtApiToken.Text}
 $mailparams = [pscustomobject]@{
 mailfrom=$window.TxtMailFrom.Text;
 mailto=$window.TxtMailTo.Text;
 smtpserver=$window.TxtSMTPServer.Text;
 smtpport=$window.TxtSMTPPort.Text;
 enableSSL=$window.cmbSSL.selectedValue.Content;
 usecredentials=$window.cmbUseCreds.selectedValue.Content;
 smtpusername=$window.TxtUserName.Text;
 smtppassword=$window.pwboxPassword.Password.Trim() | set-encodeEncrypt Encrypt -key $key;
 location=$mailconfigpath
 }
$mailconfigpath = get-fileName -savefile -initialDirectory (get-location) -titleroot "mail configuration settings"
if($mailconfigpath){$mailparams | convertto-json | Out-file -FilePath $mailconfigpath}
}
else
{
  return set-message -message 'Canceled!' -icon Warning

}
#endregion Process results


}
#-----------------------------------------------

#-------Process API Token or Mail config File---
function get-apitoken {
<#
.Synopsis
Retrieves API info

.Description
Retrieves the API configuration information from a json config file
File Example
 {
"portal":"<portal name>",
"organization":"<Stack Name (optional)>",
"apitoken":"<api token>",
"location": "<location>"
}
Note: 'The location' value is generated automatically and may or may not be updated based on programmatic needs.

#>
param (
$filelocation = $null
)
<#
File Example
 {
"portal":"<portal name>",
"organization":"<Stack Name (optional)>",
"apitoken":"<api token>"
}
#>
if([string]::IsNullOrEmpty($filelocation)){$filelocation = get-filename}
if($filelocation){
$stackparams = Get-Content -Raw -Path $filelocation -ErrorAction SilentlyContinue | ConvertFrom-Json
$stackparams.location = $filelocation
return $stackparams
}
return $null
}
function send-mailOld{
param(
[Parameter(Mandatory=$false)]$mailfolderlocation = "$($env:ProgramData)\Cloudistics\ScriptData",
[Parameter(Mandatory=$false)]$organization=$null,
[Parameter(Mandatory=$false)]$mailfile = "$($organization)mailsettings.json",
$mailattachment=$null,
$mailsubject="Cloudistics e-mail generated on $(get-date)",
$mailbody="Cloudistics e-mail generated on $(get-date)"
)

$jsonlocation = "$($mailfolderlocation)\$($mailfile)"

$mailparams = Get-Content -Path $jsonlocation | convertfrom-json


#E-Mail Configuration Section (Gmail)
#------------------------------------
#Start Configuration
###################################
$mailfrom=$mailparams.mailfrom
$mailto=$mailparams.mailto
$smtpserver=$mailparams.smtpserver
$smtpport=$mailparams.smtpport
$enableSSL=$mailparams.enableSSL
#values for $usecredentials and $enableSSL are $true and $false
$usecredentials=$mailparams.usecredentials
$smtpusername=$mailparams.smtpusername
$smtppassword=$mailparams.smtppassword 
###################################
#End Configuration
#--------------------


$attachment = new-object Net.Mail.Attachment($mailattachment)

$message = new-object Net.Mail.MailMessage
$message.from = $mailfrom
$message.to.Add($mailto)
$message.Subject=$mailsubject
$message.body=$mailbody
$message.Attachments.Add($attachment)
$message.DeliveryNotificationOptions = @('OnFailure','OnSuccess')

$smtpclient = new-object Net.Mail.SmtpClient($smtpServer, $smtpport)

if($usecredentials -eq 'yes'){$smtpclient.credentials=New-Object System.Net.NetworkCredential($smtpusername,"$($smtppassword | set-encodeEncrypt DecryptFromPlainText)"); Write-Host "checkpointCredentials" }
if($enableSSL -eq 'yes'){$smtpclient.EnableSsl=$true;Write-Host "checkpointSSL"}
$smtpclient.send($message)
Write-Host "Done!"
#$smtpclient
#$message
}
function send-mail{
<#
.Synopsis
Sends file to recipients via e-mail

.Description
Creates a mail object and performs a send operation based on the settings in the 'mailfile' parameter. 
IMPORTANT: the 'get-key' function in the module is needed for password encryption.
The 'key' parameter is deprecated.
File Example:
{
    "mailfrom":  "<user@domain.com>",
    "mailto":  "<user@domain.com>",
    "smtpserver":  "<smtp.maildomain.com>",
    "smtpport":  "<smtpport>",
    "enableSSL":  "<yes/no>",
    "usecredentials":  "<yes/no>",
    "smtpusername":  "<user@domain.com>",
    "smtppassword":  "<encryptedSmtpPassword>",
    "location":  "<location>"
}

#>
param(
[Parameter(Mandatory=$false)]$mailfolderlocation = "$($env:ProgramData)\Cloudistics\ScriptData",
[Parameter(Mandatory=$false)]$organization=$null,
[Parameter(Mandatory=$false)]$mailfile = "$($organization)mailsettings.json",
$mailattachment=$null,
$mailsubject="Cloudistics e-mail generated on $(get-date)",
$mailbody="Cloudistics e-mail generated on $(get-date)",
$key
)

$jsonlocation = "$($mailfolderlocation)\$($mailfile)"

$mailparams = Get-Content -Path $jsonlocation | convertfrom-json


$zmailparams = @{
From                     =$mailparams.mailfrom;
To                       =$mailparams.mailto;
Subject                  =$mailsubject;
Body                     =$mailbody;
SmtpServer               =$mailparams.smtpserver
Port                     =$mailparams.smtpPort
UseSsl                   =$true
Credential               =(New-Object System.Management.Automation.PSCredential ($mailparams.smtpusername, ($mailparams.smtppassword | ConvertTo-SecureString -Key (get-key) ))); 
Attachments              =$mailattachment;
DeliveryNotificationOption='OnSuccess'
}

Send-MailMessage @zmailparams 
Write-Host "Done!"

}
function get-cldtxJsonInfoOld{
param(
$commonrootpath="$($env:Programdata)\Cloudistics\ScriptData",
$apitokenfilename = $null,
$propertylist = @('portal','organization','apitoken','location'),
$filedescription= $null
)

if(!($apitokenfilename)){
Write-Host "`nAttempting to find the $filedescription file in $commonRootPath" -ForegroundColor Yellow
try{
$fileList = (Get-ChildItem $commonrootpath -Filter *.json -ErrorAction Stop | Sort-Object -Property LastWriteTime -Descending).FullName
}catch{Write-Host "Path does not Exist"}
foreach($jsonfile in $filelist){
Write-Host "Checking: $(Split-Path $jsonfile -Leaf)..." -NoNewline
$testfile = get-content $jsonfile | ConvertFrom-Json
$testresult = Compare-Object -ReferenceObject ($propertylist | sort-object) -DifferenceObject ((($testfile | get-member ) | where {$_.membertype -eq 'NoteProperty'}).Name | sort-object)
if(!($testresult)){
Write-Host "Using $(Split-Path $jsonfile -Leaf) [newest matching file]"
$zinfo = get-content $jsonfile | convertfrom-json
return $zinfo
}
Write-Host 'Failed!'
}
} else{
$apipath = "$($commonrootpath)\$($apitokenfilename)"
Write-Host "`n$filedescription file received via parameter" -ForegroundColor Yellow
if(Test-path $apipath){
Write-Host "$apitokenfilename found in $commonrootpath"
$zinfo = get-content $apipath | ConvertFrom-Json; 
$testresult = Compare-Object -ReferenceObject ($propertylist | sort-object) -DifferenceObject ((($zinfo | get-member ) | where {$_.membertype -eq 'NoteProperty'}).Name | sort-object)
if(!($testresult)){return $zinfo} 
}
}
Write-Host "`nAttempting to find the $filedescription file manually" -ForegroundColor Yellow
$zinfo = get-apitoken;
if($zinfo){$testresult = Compare-Object -ReferenceObject ($propertylist | sort-object) -DifferenceObject ((($zinfo | get-member ) | Where-Object -FilterScript {$_.membertype -eq 'NoteProperty'}).Name | sort-object)
if(!($testresult)){return $zinfo} 
}
Write-Host "`nNo API Token Present. Exiting..." -ForegroundColor Yellow; exit
}
function get-cldtxJsonInfo{
<#
.Synopsis
identify the json file config content

.Description
Identifies if a json file is either an api token configuration or a mail configuration file.
The parameter propertylist contains the list of property in the json object.
Note: when assessing a file, this function goes to 0 depth

#>
param(
$commonrootpath="$($env:Programdata)\Cloudistics\ScriptData",
$apitokenfilename = $null,
$propertylist = @('portal','organization','apitoken','location'),
$filedescription= $null
)

if(!($apitokenfilename)){
Write-Host "`nAttempting to find the $filedescription file in $commonRootPath" -ForegroundColor Yellow
try{
$fileList = (Get-ChildItem $commonrootpath -Filter *.json -ErrorAction Stop | Sort-Object -Property LastWriteTime -Descending).FullName
}catch{Write-Host "Path does not Exist"}
foreach($jsonfile in $filelist){
Write-Host "Checking: $(Split-Path $jsonfile -Leaf)..." -NoNewline
$testfile = get-content $jsonfile | ConvertFrom-Json
$testresult = Compare-Object -ReferenceObject ($propertylist | sort-object) -DifferenceObject ((($testfile | get-member ) | where {$_.membertype -eq 'NoteProperty'}).Name | sort-object)
if(!($testresult)){
Write-Host "Using $(Split-Path $jsonfile -Leaf) [newest matching file]"
$zinfo = get-content $jsonfile | convertfrom-json
if($zinfo.location -ne $jsonfile){$zinfo.location=$jsonfile}
return $zinfo
}
Write-Host 'Failed!'
}
} else{
$apipath = "$($commonrootpath)\$($apitokenfilename)"
Write-Host "`n$filedescription file received via parameter" -ForegroundColor Yellow
if(Test-path $apipath){
Write-Host "$apitokenfilename found in $commonrootpath"
$zinfo = get-content $apipath | ConvertFrom-Json; 
$testresult = Compare-Object -ReferenceObject ($propertylist | sort-object) -DifferenceObject ((($zinfo | get-member ) | where {$_.membertype -eq 'NoteProperty'}).Name | sort-object)
if(!($testresult)){
if($zinfo.location -ne $jsonfile){$zinfo.location=$jsonfile}
return $zinfo} 
}
}
Write-Host "`nAttempting to find the $filedescription file manually" -ForegroundColor Yellow
$zinfo = get-apitoken;
if($zinfo){$testresult = Compare-Object -ReferenceObject ($propertylist | sort-object) -DifferenceObject ((($zinfo | get-member ) | Where-Object -FilterScript {$_.membertype -eq 'NoteProperty'}).Name | sort-object)
if(!($testresult)){
#if($zinfo.location -ne $jsonfile){$zinfo.location=$jsonfile}
return $zinfo} 
}
Write-Host "`nNo API Token Present. Exiting..." -ForegroundColor Yellow; exit
}
#-----------------------------------------------

#-------- GUI AUX ------------------------------
function get-fileName {
<#
.Synopsis
Gets or sets (parameter savefile) file path using a GUI element (Windows default)
#>
param ($initialDirectory = (Get-Location),[switch]$savefile,$titleroot='Cloudistics Portal and API Key',$filterroot="JsonFiles (*.json)| *.json")

 $checkAssembly = ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object -FilterScript {$_.location -like "*System.Windows.Forms*"}).Location
 if(!($checkAssembly)){[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null}

 $FileDialog = New-Object System.Windows.Forms.OpenFileDialog
 $Title="Import $($titleroot)"
 if($savefile.IsPresent){
 $Filedialog = New-Object System.Windows.Forms.SaveFileDialog
 $Title = "Export $($titleroot)"
 }
 $filedialog.Title = $Title
 $FileDialog.initialDirectory = $initialDirectory
 $FileDialog.filter = "$($filterroot)| All files (*.*)| *.*"
 $FileDialog.ShowDialog() | Out-Null
 return $FileDialog.filename
}
function get-folderName{
<#
.Synopsis
Allows selecting a folder (where to save files) using a dialog similar with the Windows one (as opposed to Windows FolderBrowserDialog dialog)
#>
param(
$initialdirectory = (Get-Location),$title = 'Select Folder'
)
$folderdialog = New-Object FolderSelect.FolderSelectDialog
$folderdialog.Title = $title
$folderdialog.InitialDirectory=$initialdirectory

if($folderdialog.ShowDialog([System.IntPtr]::Zero)){return $folderdialog.FileName}
return $null
}
function set-message{
<#
.synopsis
display message GUI element

.Description
Allows displaying a message (and make yes/no/cancel decisions) using Windows messageBox and customizing it via validation lists as needed

Note: do set-message .... | Out-Null if no output is needed, otherwise it will be returned in addition to the function using it :)
#>
param(
[Parameter(Mandatory=$true)]
$message,
$title=$null,
[ValidateSet("OKCancel","YesNo","OK","RetryCancel","AbortRetryIgnore","YesNoCancel")][string]
$buttons="OK",
[ValidateSet("Asterisk","Error","Exclamation","Hand","Information","Question","Stop","Warning")][string]
$icon="None",
$defaultButton="Button1"
)
Load-Assembly -Assemblyname "System.Windows.Forms"|out-null

return [System.Windows.Forms.MessageBox]::Show($message,$title,$buttons,$icon,$defaultButton)
}
function Show-WPFWindow {
<#
.Synopsis
Allows displaying a window containing a XAML GUI element
#>
  param
  (
    [Parameter(Mandatory=$true)][Windows.Window]$Window
  )
  
  $result = $null
  $null = $window.Dispatcher.InvokeAsync{
    $result = $window.ShowDialog()
    Set-Variable -Name result -Value $result -Scope 1
  }.Wait()
  $result
}
function Convert-XAMLtoWindow {
<#
.Synopsis
Converts a XAML here string to a window object
#>
  param
  (
    [Parameter(Mandatory=$true)][string]$XAML
  )
  
  Add-Type -AssemblyName PresentationFramework
  
  $reader = [XML.XMLReader]::Create([IO.StringReader]$XAML)
  $result = [Windows.Markup.XAMLReader]::Load($reader)
  $reader.Close()
  $reader = [XML.XMLReader]::Create([IO.StringReader]$XAML)
  while ($reader.Read())
  {
      $name=$reader.GetAttribute('Name')
      if (!$name) { $name=$reader.GetAttribute('x:Name') }
      if($name)
      {$result | Add-Member NoteProperty -Name $name -Value $result.FindName($name) -Force}
  }
  $reader.Close()
  $result
}
function Load-Assembly {
<#
.Synopsis
Avoids loading the same assembly multiple times

.Description
Check if an Assembly is loaded (and load it if it is missing)
The report switch results in displaying a message re the assembly status. The assembly is still loaded if not present already.
#>
     [CmdletBinding()]
     param(
          [Parameter(Mandatory = $true,ValueFromPipeline = $true)][ValidateNotNullOrEmpty()][String]$AssemblyName,
          [Switch]$Report = $false
     )

     if(([appdomain]::currentdomain.getassemblies() | Where {$_ -match $AssemblyName}) -eq $null){
          if($Report) {Write-Output "Loading $AssemblyName assembly.";}
          [Void] [System.Reflection.Assembly]::LoadWithPartialName($AssemblyName);
          return 1
     }
     else {
          if($Report) {Write-Output "$AssemblyName is already loaded.";}
          return -1
     }
}
function get-powershellversion {
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
Write-Host "----------------------"
if($color -eq 'Red'){exit}
else {return $null}
}
#-----------------------------------------------

#---------Security------------------------------
function set-encodeEncrypt{
<#
.Synopsis
encode, decode, encrypt and decrypt strings and secure string objects

.Description
Allows clear text and secure string manipulation by
Encoding to base64, 
Decoding from base64, 
Encrypting with a key, 
decrypting with a key 
decrypting with a key from secure strings converted to text

Useful for e-mail passwords.
NOTE: Windows does not allow encrypting and decrypting secure strings on different machines or even for different users on the same machine without a key, thus making keyless encryption impractical for scheduled tasks portability or even scheduled tasks in general. To avoid confusions, the keyless encryption options have been removed. 
Additionally the key parameter is deprecated for security reasons. 
It is recommended setting up the encryption key inside the get-key function in the Cloudistics Powershell module

#>
param(
[Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=1)]$processString,
[Parameter(Mandatory=$true,Position=0)][ValidateSet('Encode','Decode','Encrypt','DecryptFromPlainText','Decrypt')]$action,
[Parameter(Mandatory=$false,Position=2)]$key
)
try{
if($action -eq 'Encode'){return [convert]::ToBase64String([Text.Encoding]::UNICODE.GetBytes($processString ))}

if($action -eq 'Decode'){return [System.Text.Encoding]::UNICODE.GetString([System.Convert]::FromBase64String($mailparams.smtppassword))}

if($action -eq 'Encrypt'){
return $processString | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString -Key (get-key)
}

$tempstring=$null
if($action -eq 'DecryptFromPlainText'){
$tempstring = $processString | ConvertTo-SecureString -Key (get-key)
}
if($action -eq 'Decrypt'){if(!($tempstring)){$tempstring = $processString}}

$pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $tempString )
$decryptedstring = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR( $pointer )
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR( $pointer )
return $decryptedstring

}catch{return $Error[0]}

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

    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")        
    if ($Check) { return $IsAdmin }     
 
    if ($MyInvocation.ScriptName -ne ""){  
        if (-not $IsAdmin){  
            try {  
                $zarg = "-file `"$($MyInvocation.ScriptName)`"" 
                Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $zarg -ErrorAction 'stop'
            }catch{Write-Warning "Error - Failed to restart script with runas";break } 
            exit # Quit this session of powershell 
        }  
    }else {Write-Warning "Error - Script must be saved as a .ps1 file first";break;}  
} 
function convert-textToSecureString {
<#
.Synopsis
The function receives a plain text string and converts it to a secure string (for the session duration)

.Description
Converts a plain text string into a memory residing secure string that can be used, for instance, to create a credentials object. 

.Example
PS C:\>'password' | convert-textToSecureString
System.Security.SecureString

#>
param([Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=0)][string]$plainText)
$securestring = new-object System.Security.SecureString
$chars = $plainText.toCharArray()
foreach ($char in $chars) {$secureString.AppendChar($char)}
return $securestring
}
function get-key{
<#
.Synopsis
converts a string into an encruption key

.Description
Converts a string into an encryption key, considering the following hash types (provided as a validation list):
MD5
SHA 
SHA1 
SHA256 
SHA512
The default algorithm is MD5

.Example
PS c:\> 'password' | get-key -hashtype SHA

#>
param (
[Parameter(ValueFromPipeline=$true,Mandatory=$false,Position=1)]$inputstring='Cloudistics',
[Parameter(ValueFromPipeline=$false,Mandatory=$false,Position=0)][ValidateSet('MD5','SHA','SHA1','SHA256','SHA512')]$hashtype='MD5'
)
return [System.Security.Cryptography.HashAlgorithm]::Create($hashtype).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($inputstring))
}
#-----------------------------------------------

#--------AUX-----------------------------------
function resize-image {
<#
.Synopsis
Resize image and convert to the desired format

.Description
Resizes and saves an image in the desired format for future use.
The default Quality parameter is set to 90 (meaning 90%)
The imgformat parameter is an aggregated value, represented in a string of the following format: WxHx<imgtype>, i.e. 120x80xpng
<imgtype> is one of the following:
BMP              
JPEG             
GIF              
TIFF             
PNG 
Note: This function will be enhanced in the future by adding GUI elements

#>
    param([String]$ImagePath, [String]$OutputLocation, [Int]$Quality = 90, [String]$imgformat)
 #note: Image Format = WxHximgtype i.e. 132x32xpng
    #Add-Type -AssemblyName "System.Drawing"
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $img = [System.Drawing.Image]::FromFile($ImagePath)
 
    $ImageEncoder = [System.Drawing.Imaging.Encoder]::Quality
    $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($ImageEncoder, $Quality)
    
    $imgparams = $imgformat.Split('x')
    $Codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object {$_.MimeType -eq "image/$($imgparams[2])"}
    $bmpResized = New-Object System.Drawing.Bitmap([int]$imgparams[0], [int]$imgparams[1])
    $graph = [System.Drawing.Graphics]::FromImage($bmpResized)
    $graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 
    $graph.Clear([System.Drawing.Color]::White)
    $graph.DrawImage($img, 0, 0, [int]$imgparams[0], [int]$imgparams[1])
 
    #save to file
    $bmpResized.Save($OutputLocation, $Codec, $($encoderParams))
    $bmpResized.Dispose()
    $img.Dispose()
}
#function execute-process captures the stdout result, stderror and exit code
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
function write-hostColored() {
    [CmdletBinding()]
    param(
        [parameter(Position=0, ValueFromPipeline=$true)]
        [string[]] $Text,
        [switch] $NoNewline,
        [ConsoleColor] $BackgroundColor = $host.UI.RawUI.BackgroundColor,
        [ConsoleColor] $ForegroundColor = $host.UI.RawUI.ForegroundColor
    )

    begin {
        if ($Text -ne $null) {
            $Text = "$Text"
        }
    }

    process {
        if ($Text) {

            $curFgColor = $ForegroundColor
            $curBgColor = $BackgroundColor

            $tokens = $Text.split("#")

            # Iterate over tokens.
            $prevWasColorSpec = $false
            foreach($token in $tokens) {

                if (-not $prevWasColorSpec -and $token -match '^([a-z]*)(:([a-z]+))?$') {
                    try {
                        $curFgColor = [ConsoleColor] $matches[1]
                        $prevWasColorSpec = $true
                    } catch {}
                    if ($matches[3]) {
                        try {
                            $curBgColor = [ConsoleColor] $matches[3]
                            $prevWasColorSpec = $true
                        } catch {}
                    }
                    if ($prevWasColorSpec) {
                        continue
                    }
                }

                $prevWasColorSpec = $false

                if ($token) {
                    $argsHash = @{}
                    if ([int] $curFgColor -ne -1) { $argsHash += @{ 'ForegroundColor' = $curFgColor } }
                    if ([int] $curBgColor -ne -1) { $argsHash += @{ 'BackgroundColor' = $curBgColor } }
                    Write-Host -NoNewline @argsHash $token
                }

                # Revert to default colors.
                $curFgColor = $ForegroundColor
                $curBgColor = $BackgroundColor

            }
        }
        # Terminate with a newline, unless suppressed
        if (-not $NoNewLine) { write-host }
    }
}

#-------- Deploy from template plus supporting code -------------
function new-vmfromtemplate{
param(
[Parameter(Mandatory=$true)][ValidateSet('virtual-lab','prod','portal-rclab')]$portal, 
[Parameter(Mandatory=$true)]$apitoken,
$vmname,$vmdescription,$vCPUscount,$memorysize,
$templateUuid,
$categoryUuid,
$tags,
$vdcUuid,$mzUuid,$flashpoolUuid,
$vnicName,$vnicUuid,$networkUuid,$firewallOverrideUuid,$automaticMACAssignment,$macaddress,$ordervNic,
$diskName,$diskUuid,$orderHD,$applicationGroupUuid,
$hardwareAssistedVirtualizationEnabled,$autostart,$guestAgentToolsAvailable
)


$zbody=@"
{
    "name":  "$($vmname)",
    "description":  "$($vmdescription)",
    "vcpus":  $($vCPUscount),
    "memory":  $($memorysize),
    "templateUuid":  "$($templateUuid)",
    "categoryUuid":  $($categoryUuid),
    "tags":  [ 
                     $($tags)
             ],
    "datacenterUuid":  "$($vdcUuid)",
    "migrationZoneUuid":  "$($mzUuid)",
    "flashPoolUuid":  "$($flashpoolUuid)",
    "networks":  [
                     {
                         "name":  "$($vnicName)",
                         "vnicUuid":  "$($vnicUuid)",
                         "networkUuid":  "$($networkUuid)",
                         "firewallOverrideUuid":  $($firewallOverrideUuid),
                         "automaticMACAssignment":  $($automaticMACAssignment),
                         "macaddress":  $($macaddress)
                     }
                 ],
    "bootOrder":  [
                      {
                          "diskUuid":  "$($diskUuid)",
                          "name":  "$($diskName)",
                          "order":  $($orderHD)
                      },
                      {
                          "name":  "$($vnicName)",
                          "order":  $($ordervNic),
                          "vnicUuid":  "$($vnicUuid)"
                      }
                  ],
    "hardwareAssistedVirtualizationEnabled":  $($hardwareAssistedVirtualizationEnabled),
    "vmMode":  "Enhanced",
    "applicationGroupUuid":  $($applicationGroupUuid),
    "autostart":  "$($autostart)",
    "guestAgentToolsAvailable":  "$($guestAgentToolsAvailable)"
}
"@

$xid = @{apitoken=$apitoken;portal='virtual-lab'; uriaddon='applications';contenttype ='application/json';method='POST';body=$zbody }
$result = submit-cldtxrestcall  @xid
return [pscustomobject]@{result = $result;'body'=$zbody}

}


# SIG # Begin signature block
# MIID5wYJKoZIhvcNAQcCoIID2DCCA9QCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1k4XwD0YCcuZM8ierPpPXoXC
# SFGgggIDMIIB/zCCAWigAwIBAgIQZXsLzuTF+b1PPg61Cp25RzANBgkqhkiG9w0B
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUtswBIwAbnAJr/4g8+riEm+g2MDcwDQYJKoZI
# hvcNAQEBBQAEgYB5wWiOAy3L2/ryKgmWL2PRIaYtkHSto9YX9cmcj6nUqB9cwH0/
# ndMrPABtkGBDVLnezEpcNjC8G5UkF8bQN9khl/3ww/7N0S6GrthNy33AWh5ER7VM
# /uy3UvD1oWN4LgH/4iYngS8C5dDJ/I4UknE2s+zWX9a06Eyiw1E/XapQ0A==
# SIG # End signature block
