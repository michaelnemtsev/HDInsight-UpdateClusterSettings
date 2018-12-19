# HDInsight-UpdateClusterSettings
This PowerShell code demonstrates how to update HDI clusters config (for example hive-site.xml) and restart the cluster to apply the changes

The approach consists of the 3 major steps:

1) Read the HDInsight cluster configurations
2) Construct the new Configuration JSON object, including the existing parameters from the previous configuraion version
3) Submit the new config and restart the cluster

See the code for the details
