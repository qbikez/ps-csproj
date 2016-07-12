
function update-profileproperty($profile, $propName, $propValue) {
    write-verbose "setting $propName to '$propValue'"
    if ($profile.Project.PropertyGroup."$propName" -eq $null) {
        #$profile.Project.PropertyGroup | Add-Member -MemberType NoteProperty -Name $propName -Value $propValue
        #$profile.Project.PropertyGroup | Set-Property
        #$profile.Project | Set-Property
     $child = $profile.CreateElement($propName, $profile.Project.xmlns)
    
     $null = $profile.Project.PropertyGroup.AppendChild($child)
    }
    $profile.Project.PropertyGroup."$propName" = "$propValue"
}

function update-pubprofile(
[Parameter(Mandatory=$true)] $path, 
$outPath, 
$serverUrl, 
$appPath, 
$username,
$properties = @{}
) {


$profileStr = get-content $path
$profile = [xml]$profileStr

if ($outPath -eq $null) { $outPath = $path }

  if ($profile -eq $null -and !$buildOnly) {
        throw "publishing profile '$path' not found"
}


try {

    $changed = $false
#    if ($profile.Project.PropertyGroup.LastUsedBuildConfiguration -ne $null -and $profile.Project.PropertyGroup.LastUsedBuildConfiguration -ne $($Config.server.buildConfiguration)) {
#        $profile.Project.PropertyGroup.LastUsedBuildConfiguration = $($Config.server.buildConfiguration)
#        $changed = $true
#    }

<#

 <PropertyGroup>
    <WebPublishMethod>MSDeploy</WebPublishMethod>
    <LastUsedBuildConfiguration>Preprod</LastUsedBuildConfiguration>
    <LastUsedPlatform>Any CPU</LastUsedPlatform>
    <SiteUrlToLaunchAfterPublish>http://neprod3.cloudapp.net/admin-staging</SiteUrlToLaunchAfterPublish>
    <LaunchSiteAfterPublish>True</LaunchSiteAfterPublish>
    <ExcludeApp_Data>False</ExcludeApp_Data>
    <MSDeployServiceURL>https://neprod3.cloudapp.net:8172/msdeploy.axd</MSDeployServiceURL>
    <DeployIisAppPath>ne-prod/admin-staging</DeployIisAppPath>
    <RemoteSitePhysicalPath />
    <SkipExtraFilesOnServer>True</SkipExtraFilesOnServer>
    <MSDeployPublishMethod>WMSVC</MSDeployPublishMethod>
    <EnableMSDeployBackup>True</EnableMSDeployBackup>
    <UserName>jpawlowski</UserName>
    <_SavePWD>True</_SavePWD>
    <_DestinationType>AzureVirtualMachine</_DestinationType>
    <PublishDatabaseSettings>
</PropertyGroup>

#>

    if ($username -ne $null) {
        
        update-profileproperty $profile "UserName" $username
        $changed = $true
    }
    if ($serverUrl -ne $null) {
        update-profileproperty $profile "MSDeployServiceURL" $serverUrl
        $changed = $true
    }
    if ($appPath -ne $null) {
        update-profileproperty $profile "DeployIisAppPath" $appPath
        $changed = $true
    }
    if ($properties -ne $null) {
        foreach($prop in $properties.GetEnumerator()) {
            update-profileproperty $profile $prop.Key $prop.Value
            $changed = $true
        }
        
    }

    if ($changed) {
        write-verbose "saving pubprofile to $outpath"
        import-module pscx
        # TODO: remove PSCX dependency
        $profile | pscx\format-xml | Out-File $outPath -Encoding utf8 -Force
    }
    
}
finally {
    #if ($profileStr -ne $null) {
    #    $profileStr | Out-File $outPath -Encoding utf8 -Force
    #}
}

}