Class Test.PM.Integration.Base Extends %UnitTest.TestCase
{

Parameter REGISTRYNAME = "test_registry";

Parameter CLIENTNS As STRING = "UTCLIENT";

Property UserCreated As %Boolean [ InitialExpression = 0 ];

Property ClientNSCreated As %Boolean [ InitialExpression = 0 ];

Property RegistryAdded As %Boolean [ InitialExpression = 0 ];

Method Setup() As %Status
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		do $$$AssertStatusOK(##class(%ZPM.PackageManager.Client.FilesystemServerDefinition).%DeleteExtent())
		do $$$AssertStatusOK(##class(%ZPM.PackageManager.Client.RemoteServerDefinition).%DeleteExtent())
		do $$$AssertStatusOK(##class(%ZPM.PackageManager.Client.LocalServerDefinition).%DeleteExtent())
		
		If '$$$AssertStatusOK(##class(%ZPM.PackageManager.Developer.UnitTest.Utils).CreateNamespace(..#CLIENTNS)) {
			Quit
		}
		Set ..ClientNSCreated = 1
		
		// Client namespace setup
		Set $Namespace = ..#CLIENTNS
		
		// Create local cache repository in client namespace
		Do $$$AssertStatusOK(##class(%ZPM.PackageManager.Client.Utils).InitializeLocalCache(.tCreated))
		Do $$$AssertTrue(tCreated,"Local cache created.")
		
		if ($system.Util.GetEnviron("TEST_REGISTRY")="") {
			Do $$$AssertFailure("Registry Server not defined")
			Quit
		}
		if ('..RegistryAdded) {
			Set tServerDefn = ##class(%ZPM.PackageManager.Client.RemoteServerDefinition).%New()
			Set tServerDefn.Name = ..#REGISTRYNAME
			Set tServerDefn.Enabled = 1
			Set tServerDefn.URL = $system.Util.GetEnviron("TEST_REGISTRY")
			Set tServerDefn.DeploymentEnabled = 1
			Set tServerDefn.Username = $system.Util.GetEnviron("TEST_REGISTRY_USER")
			Set tServerDefn.Password = $system.Util.GetEnviron("TEST_REGISTRY_PASSWORD")
			Set tServerDefn.Prereleases = 1
			Set tServerDefn.Snapshots = 1
			Do $$$AssertStatusOK(tServerDefn.%Save(),"Remote server definition saved.")
	
			Set ..RegistryAdded = 1

      /// Clear any packages on remote registry for debug purposes
      Do tServerDefn.GetPackageService().ResetRegistry()
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method TearDown() As %Status
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		Set tSC = ##class(%ZPM.PackageManager.Developer.UnitTest.Utils).DeleteNamespace(..#CLIENTNS)
		Do:..ClientNSCreated $$$AssertStatusOK(tSC,"Client namespace deleted.")
		if ..RegistryAdded {
			Do $$$AssertStatusOK(##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyDelete(..#REGISTRYNAME))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ReadXDataToModule(pNamespace As %String = {$NAMESPACE}, pXDataName As %String, ByRef pModule As %ZPM.PackageManager.Developer.Module) As %Status
{
	New $Namespace
	Set tInitNS = $Namespace
	Set tStatus = $$$OK
	Try {
		Set $Namespace = pNamespace
		Set tXData = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||"_pXDataName,,.tStatus)
		If $$$ISERR(tStatus) {
			Quit
		}
		
		// Find the module name by inspecting the XML prior to importing it as a document.
		Set tReader = ##class(%XML.Reader).%New()
		Set tSC = tReader.OpenStream(tXData.Data)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Do tReader.Correlate("Module","%ZPM.PackageManager.Developer.Module")
		Do tReader.Next(.tModule,.tSC)
		Set tName = tModule.Name_".ZPM"
		Do tXData.Data.Rewind()
		
		Set $Namespace = tInitNS
			
		Set tStatus = ##class(%ZPM.PackageManager.Developer.Document.Module).ImportStream(.tName,tXData.Data)
		If $$$ISERR(tStatus) {
			Quit
		}
		
		Set pModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen($Piece(tName,".",1,*-1),,.tStatus)
		If $$$ISERR(tStatus) {
			Quit
		}
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

}
