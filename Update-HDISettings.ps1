##################################################################################################
#
# This code snippet demonstrates how to update HDInsight settings and change some variables
# More details about the code can be find here 
# https://docs.microsoft.com/en-us/azure/hdinsight/hdinsight-hadoop-manage-ambari-rest-api 
#
##################################################################################################

$LocalAdminUser = "admin"
$LocalAdminPassword = ConvertTo-SecureString -String '<clusterpass>' -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential($LocalAdminUser, $LocalAdminPassword)
$ClusterName = "<clusterName>"
# In this example, we increase the default size of HTTP header (part of hive-site.xml)
$hiveParameters = "hive.server2.thrift.http.request.header.size=13310072", "hive.server2.thrift.http.response.header.size=13310072"
$clusterType = "hive-site"

# Get Hive configuration versions
$clusterVersionsUri = Invoke-WebRequest -Uri "https://$ClusterName.azurehdinsight.net/api/v1/clusters/$ClusterName/configurations?type=$clusterType" -Credential $creds
$cluserVersions = ConvertFrom-Json $clusterVersionsUri.Content
$lastestClusterTag = $cluserVersions.items[-1].tag; # -1 returns the latest element
# Get the lastest Hive config
$configDataUri = Invoke-WebRequest -Uri "https://$ClusterName.azurehdinsight.net/api/v1/clusters/$ClusterName/configurations?type=$clusterType&tag=$lastestClusterTag" -Credential $creds
$configContent = ConvertFrom-Json $configDataUri.Content

# Check if parameters exist
if ($true) #TODO: Validate if parameters don't exist already
{
    # Get the unique time to use for config tag
    $epoch = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $now = Get-Date
    $unixTimeStamp = [math]::truncate($now.ToUniversalTime().Subtract($epoch).TotalMilliSeconds)
    # Create a new configuration
    $newConfig = [ordered] @{
        Clusters = [ordered] @{
            desired_config = [ordered] @{
                tag                   = "version$unixTimeStamp"
                type                  = $clusterType
                properties            = $configContent.items.properties
                properties_attributes = $configContent.items.properties_attributes
            }
        }
    }
    # Add new parameters
    ForEach ($parameter in $hiveParameters) {
        $parameterSplit = $parameter.Split("=")
        $newConfig.Clusters.desired_config.properties | Add-Member NoteProperty -Name $parameterSplit[0] -Value $parameterSplit[1]
    }

    $newConfigJson = $newConfig | ConvertTo-Json -Depth 10

    # Submit new config to HDInsight
    $inputParameters = @{
        Credential = $creds
        Uri        = "https://$ClusterName.azurehdinsight.net/api/v1/clusters/$ClusterName"
        Method     = "PUT"
        Headers    = @{"X-Requested-By" = "ambari"}
        Body       = $newConfigJson
    }
    Invoke-WebRequest @inputParameters

    # Restart all dependent services
    $inputParameters = @{
        Credential = $creds
        Uri        = "https://$ClusterName.azurehdinsight.net/api/v1/clusters/$ClusterName/requests"
        Method     = "POST"
        Headers    = @{"X-Requested-By" = "ambari"}
        Body       = '{"RequestInfo":{"command":"RESTART","context":"Restart all required services","operation_level":"host_component"},"Requests/resource_filters":[{"hosts_predicate":"HostRoles/stale_configs=true"}]}'
    }
    Invoke-WebRequest @inputParameters
}