###############################################################################
## Start Powershell Cmdlets
###############################################################################

###############################################################################
# Get-PrtgObject


function Get-PrtgObject {

	Param (
		[Parameter(Mandatory=$false,Position=0)]
		[int]$ObjectId = 0
	)

	BEGIN {
		if ($PRTG.Protocol -eq "https") { $PRTG.OverrideValidation() }
	}

	PROCESS {

		$Parameters = @{
			"content" = "sensortree"
			"id" = $ObjectId
		}
		
		$url = $PrtgServerObject.UrlBuilder("api/table.xml",$Parameters)

		##### data returned; do!

		if ($Raw) {
			$QueryObject = HelperHTTPQuery $url
			return $QueryObject.Data
		}

		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data

		$DeviceType = $Data.prtg.sensortree.nodes.SelectNodes("*[1]").LocalName
		
		$ObjectXMLData = $Data.prtg.sensortree.nodes.SelectNodes("*[1]")
		
		
		####
		$TestReturn = "" | select type,data
		$TestReturn.type = $DeviceType
		$TestReturn.data = $ObjectXMLData
		
		return $TestReturn
		####
		
		#$ReturnData = @()
		
		<#
		
		HOW THIS WILL LIKELY NEED TO WORK
		---
		
		build a switch statement that uses $Content to determine which types of objects we're going to create
		foreach item, assign all properties to the object
		attach the object to $ReturnData
		
		#>
		
		$PrtgObjectType = switch ($DeviceType) {
			"probes"	{ "PrtgShell.PrtgProbe" }
			"groups"	{ "PrtgShell.PrtgGroup" }
			"devices"	{ "PrtgShell.PrtgDevice" }
			"sensors"	{ "PrtgShell.PrtgSensor" }
			"todos"		{ "PrtgShell.PrtgTodo" }
			"messages"	{ "PrtgShell.PrtgMessage" }
			"values"	{ "PrtgShell.PrtgValue" }
			"channels"	{ "PrtgShell.PrtgChannel" }
			"history"	{ "PrtgShell.PrtgHistory" }
		}
		
		$ObjectXMLData = $Data.prtg.sensortree.nodes.SelectNodes("*[1]")
		
		$ThisObject = New-Object $PrtgObjectType
		
		foreach ($p in $ObjectXMLData.GetEnumerator()) {
			$ThisObject.($p.name) = $p.'#Text'
		}
		
		return $ThisObject

		<#
		#$ThisRow = "" | Select-Object $SelectedColumns
			foreach ($Prop in $SelectedColumns) {
				if ($Content -eq "channels" -and $Prop -eq "lastvalue_raw") {
					# fix a bizarre formatting bug
					#$ThisObject.$Prop = HelperFormatHandler $item.$Prop
					$ThisObject.$Prop = $item.$Prop
				} elseif ($HTMLColumns -contains $Prop) {
					# strip HTML, leave bare text
					$ThisObject.$Prop =  $item.$Prop -replace "<[^>]*?>|<[^>]*>", ""
				} else {
					$ThisObject.$Prop = $item.$Prop
				}
			}
			$ReturnData += $ThisObject
		}

		if ($ReturnData.name -eq "Item" -or (!($ReturnData.ToString()))) {
			$DeterminedObjectType = Get-PrtgObjectType $ObjectId

			$ValidQueriesTable = @{
				group=@("devices","groups","sensors","todos","messages","values","history")
				probenode=@("devices","groups","sensors","todos","messages","values","history")
				device=@("sensors","todos","messages","values","history")
				sensor=@("messages","values","channels","history")
				report=@("Currently unsupported")
				map=@("Currently unsupported")
				storedreport=@("Currently unsupported")
			}

			Write-Host "No $Content; Object $ObjectId is type $DeterminedObjectType"
			Write-Host (" Valid query types: " + ($ValidQueriesTable.$DeterminedObjectType -join ", "))
		} else {
			return $ReturnData
		}
		
		#>
		
	}
}

###############################################################################
# Get-PrtgObjectProperty


function Get-PrtgObjectProperty {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
		[alias('DeviceId')]
        [int]$ObjectId,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$Property
    )

    BEGIN {
		if (!($PrtgServerObject.Server)) { Throw "Not connected to a server!" }
    }

    PROCESS {
		$Url = $PrtgServerObject.UrlBuilder("api/getobjectproperty.htm",@{
			"id"		= $ObjectId
			"name" 		= $Property
			"show" 		= "text"
		})

		$Data = $PrtgServerObject.HttpQuery($Url,$true)
		
		return $Data.Data.prtg.result
    }
}

###############################################################################
# Get-PrtgSensorHistoricData


function Get-PrtgSensorHistoricData {
	<#
	.SYNOPSIS
		Returns historic data from a specified time period from a sensor object.
	.DESCRIPTION
		Returns a table of data using the specified start and end dates and the specified interval.
	.PARAMETER SensorId
		The sensor to retrieve data for.
	.PARAMETER RangeStart
		DateTime object specifying the start of the history range.
	.PARAMETER RangeEnd
		DateTime object specifying the End of the history range.
	.PARAMETER IntervalInSeconds
		The minimum interval to include, in seconds. The default is one hour (3600 seconds). A value of zero (0) will return raw data. 
	.EXAMPLE
		Get-PrtgSensorHistoricData 2321 (Get-Date "2016-06-23 12:15") (Get-Date "2016-06-23 16:15") 60
	#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int] $SensorId,

		[Parameter(Mandatory=$True,Position=1)]
		[datetime] $RangeStart,
		
		[Parameter(Mandatory=$True,Position=2)]
		[datetime] $RangeEnd,
		
		[Parameter(Mandatory=$True,Position=3)]
		[int] $IntervalInSeconds = 3600
    )

    BEGIN {
		$PrtgServerObject = $Global:PrtgServerObject
    }

    PROCESS {
		$Parameters = @{
			"id" = $SensorId
			"sdate" = $RangeStart.ToString("yyyy-MM-dd-HH-mm-ss")
			"edate" = $RangeEnd.ToString("yyyy-MM-dd-HH-mm-ss")
			"avg" = $IntervalInSeconds
		}
		
		$url = $PrtgServerObject.UrlBuilder("api/historicdata.csv",$Parameters)
		
		$QueryObject = $PrtgServerObject.HttpQuery($url,$false)
		
		$DataPoints = $QueryObject.RawData | ConvertFrom-Csv | ? { $_.'Date Time' -ne 'Averages' }
	}
	
	END {
		return $DataPoints
    }
}

###############################################################################
# Get-PrtgSensorUptime


# optional thing to add here:
# make it so we can define a target month in this report, rather than manually specifying the start and end date.


function Get-PrtgSensorUptime {
	<#
	.SYNOPSIS
		Returns five-nines-style uptime for a specified time period from a sensor object.
	.DESCRIPTION
		Returns five-nines-style uptime for a specified time period from a sensor object.
	.PARAMETER SensorId
		The sensor to retrieve data for.
	.PARAMETER RangeStart
		DateTime object specifying the start of the history range.
	.PARAMETER RangeEnd
		DateTime object specifying the End of the history range.
	.EXAMPLE
		 Get-PrtgSensorUptime 2321 (Get-Date "2016-06-23 12:15") (Get-Date "2016-06-23 16:15")
	#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [int] $SensorId,

		[Parameter(Mandatory=$true,Position=1)]
		[datetime] $RangeStart,
		
		[Parameter(Mandatory=$false,Position=2)]
		[datetime] $RangeEnd		
    )

    BEGIN {
		$PrtgServerObject = $Global:PrtgServerObject
		
		if (!$RangeEnd) {
			$RangeStart = Get-Date ($RangeStart.ToString('MMMM yyyy'))
			$RangeEnd = $RangeStart.AddMonths(1).AddSeconds(-1)
		}
    }

    PROCESS {
		$ObjectInterval = Get-PrtgObject $SensorId | Select-Object -ExpandProperty interval
		
		$HistoricData = Get-PrtgSensorHistoricData $SensorId $RangeStart $RangeEnd 0
		
		$APropertyName = (($HistoricData | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) -notmatch "Coverage") -notmatch "Date Time" | Select-Object -First 1
		
		# maybe this is valid?
		$UpEntries = $HistoricData.$APropertyName | ? { $_ -ne "" }
		
	}
	
	END {
		$returnobject = "" | select SensorId,RangeStart,RangeEnd,TotalDatapoints,UpDatapoints,DownDatapoints,Interval,UptimePercentage
		$returnobject.SensorId = $SensorId
		$returnobject.RangeStart = $RangeStart
		$returnobject.RangeEnd = $RangeEnd
		$returnobject.TotalDatapoints = $HistoricData.Count
		$returnobject.UpDatapoints = $UpEntries.Count
		$returnobject.DownDatapoints = $HistoricData.Count - $UpEntries.Count
		$returnobject.Interval = $ObjectInterval
		if ($HistoricData.Count) {
			$returnobject.UptimePercentage = ($UpEntries.Count / $HistoricData.Count) * 100
		} else { 
			$returnobject.UptimePercentage = 0
		}
		
		return $returnobject
    }
}

###############################################################################
# Get-PrtgServer

function Get-PrtgServer {
	<#
	.SYNOPSIS
		Establishes initial connection to PRTG API.
		
	.DESCRIPTION
		The Get-PrtgServer cmdlet establishes and validates connection parameters to allow further communications to the PRTG API. The cmdlet needs at least three parameters:
		 - The server name (without the protocol)
		 - An authenticated username
		 - A passhash that can be retrieved from the PRTG user's "My Account" page.
		
		
		The cmdlet returns an object containing details of the connection, but this can be discarded or saved as desired; the returned object is not necessary to provide to further calls to the API.
	
	.EXAMPLE
		Get-PrtgServer "prtg.company.com" "jsmith" 1234567890
		
		Connects to PRTG using the default port (443) over SSL (HTTPS) using the username "jsmith" and the passhash 1234567890.
		
	.EXAMPLE
		Get-PrtgServer "prtg.company.com" "jsmith" 1234567890 -HttpOnly
		
		Connects to PRTG using the default port (80) over SSL (HTTP) using the username "jsmith" and the passhash 1234567890.
		
	.EXAMPLE
		Get-PrtgServer -Server "monitoring.domain.local" -UserName "prtgadmin" -PassHash 1234567890 -Port 8080 -HttpOnly
		
		Connects to PRTG using port 8080 over HTTP using the username "prtgadmin" and the passhash 1234567890.
		
	.PARAMETER Server
		Fully-qualified domain name for the PRTG server. Don't include the protocol part ("https://" or "http://").
		
	.PARAMETER UserName
		PRTG username to use for authentication to the API.
		
	.PARAMETER PassHash
		PassHash for the PRTG username. This can be retrieved from the PRTG user's "My Account" page.
	
	.PARAMETER Port
		The port that PRTG is running on. This defaults to port 443 over HTTPS, and port 80 over HTTP.
	
	.PARAMETER HttpOnly
		When specified, configures the API connection to run over HTTP rather than the default HTTPS.
		
	.PARAMETER Quiet
		When specified, the cmdlet returns nothing on success.
	#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[ValidatePattern("\d+\.\d+\.\d+\.\d+|(\w\.)+\w")]
		[string]$Server,

		[Parameter(Mandatory=$True,Position=1)]
		[string]$UserName,

		[Parameter(Mandatory=$True,Position=2)]
		[string]$PassHash,

		[Parameter(Mandatory=$False,Position=3)]
		[int]$Port = $null,

		[Parameter(Mandatory=$False)]
		[alias('http')]
		[switch]$HttpOnly,
		
		[Parameter(Mandatory=$False)]
		[alias('q')]
		[switch]$Quiet
	)

    BEGIN {
		
		$PrtgServerObject = New-Object PrtgShell.PrtgServer
		
		$PrtgServerObject.Server   = $Server
		$PrtgServerObject.UserName = $UserName
		$PrtgServerObject.PassHash = $PassHash
		
		if ($HttpOnly) {
			$Protocol = "http"
			if (!$Port) { $Port = 80 }
			
		} else {
			$Protocol = "https"
			if (!$Port) { $Port = 443 }
			
			#$PrtgServerObject.OverrideValidation()
		}
		
		$PrtgServerObject.Protocol = $Protocol
		$PrtgServerObject.Port     = $Port
    }

    PROCESS {
		$url = $PrtgServerObject.UrlBuilder("api/getstatus.xml")

		try {
			#$QueryObject = HelperHTTPQuery $url -AsXML
			#$PrtgServerObject.OverrideValidation()
			$QueryObject = $PrtgServerObject.HttpQuery($url)
		} catch {
			throw "Error performing HTTP query"
		}
		
		$Data = $QueryObject.Data

		# the logic and future-proofing of this is a bit on the suspect side.
		# the idea is that we want to get all the properties that it returns
		# and shove them into our new object, but if the object is missing 
		# the property in the first place we will get an error. this happens
		# periodically when paessler adds new properties to the output.
		#
		# so how do we gracefully handle new properties?
		foreach ($ChildNode in $data.status.ChildNodes) {
			# for now, we outright ignore them.
			if (($PrtgServerObject | Get-Member | Select-Object -ExpandProperty Name) -contains $ChildNode.Name) {
				
				if ($ChildNode.Name -ne "IsAdminUser") {
					$PrtgServerObject.$($ChildNode.Name) = $ChildNode.InnerText
				} else {
					# TODO
					# there's at least four properties that need to be treated this way
					# this is because this property returns a text "true" or "false", which powershell always evaluates as "true"
					$PrtgServerObject.$($ChildNode.Name) = [System.Convert]::ToBoolean($ChildNode.InnerText)
				}
				
			}
		}
		
        $global:PrtgServerObject = $PrtgServerObject

		#HelperFormatTest ###### need to add this back in
		# this tests for a decimal-placement bug that existed in the output from some old versions of prtg
		
		if (!$Quiet) {
			return $PrtgServerObject | Select-Object @{n='Connection';e={$_.ApiUrl}},UserName,Version
		}
    }
}

###############################################################################
# Get-PrtgStatus


function Get-PrtgStatus {

	# this is nowhere near complete or useful. the data returned by this control is tagged HTML with untagged, unlabelled, unidentified data, which could be immensely useful. if it was structured.
	
	BEGIN {
		if ($PRTG.Protocol -eq "https") { $PRTG.OverrideValidation() }
	}

	PROCESS {

		$Parameters = @{
			"content" = "sensortree"
			"id" = $ObjectId
		}
		
		$url = $PrtgServerObject.UrlBuilder("controls/systemstatus.htm")
		$QueryObject = HelperHTTPQuery $url
		return $QueryObject.Data
	}
}

###############################################################################
# Get-PrtgTableData


function Get-PrtgTableData {
	<#
		.SYNOPSIS
			Returns a PowerShell object containing data from the specified object in PRTG.
			
		.DESCRIPTION
			The Get-PrtgTableData cmdlet can return data of various different content types using the specified parent object, as well as specify the return columns or filtering options. The input formats generally coincide with the Live Data demo from the PRTG API documentation, but there are some content types that the cmdlet does not yet support, such as "sensortree".
		
		.PARAMETER Content
			The type of data to return about the specified object. Valid values are "devices", "groups", "sensors", "todos", "messages", "values", "channels", and "history". Note that all content types are not valid for all object types; for example, a device object can contain no groups or channels.
			
		.PARAMETER ObjectId
			An object ID from PRTG. Objects include probes, groups, devices, and sensors, as well as reports, maps, and todos.
		
		.PARAMETER Columns
			A string array of named column values to return. In general the default return values for a given content type will return all of the available columns; this parameter can be used to change the order of columns or specify which columns to include or ignore.
			
		.PARAMETER FilterTags
			A string array of sensor tags. This parameter only has any effect if the content type is "sensor". Output will only include sensors with the specified tags. Note that specifying multiple tags performs a logical OR of tags.
			
		.PARAMETER Count
			Number of records to return. PRTG's internal default for this is 500. Valid values are 1-50000.
			
		.PARAMETER Raw
			If this switch is set, the cmdlet will return the raw XML data rather than a PowerShell object.
		
		.EXAMPLE
			Get-PrtgTableData groups 1
			
			Returns the groups under the object ID 1, which is typically the Core Server's Local Probe.
		
		.EXAMPLE
			Get-PrtgTableData sensors -FilterTags corestatesensor,probesensor
			
			Returns a filtered list of sensors tagged with "corestatesensor" or "probesensor".
			
		.EXAMPLE
			Get-PrtgTableData messages 1002
			
			Returns the messages log for device 1002.
	#>

	[CmdletBinding()]
	Param (		
		[Parameter(Mandatory=$True,Position=0)]
		[ValidateSet("probes","groups","devices","sensors","todos","messages","values","channels","history","maps")]
		[string]$Content,

		[Parameter(Mandatory=$false,Position=1)]
		[int]$ObjectId = 0,

		[Parameter(Mandatory=$False)]
		[string[]]$Columns,

		[Parameter(Mandatory=$False)]
		[string[]]$FilterTags,
		
		[Parameter(Mandatory=$False)]
		[ValidateSet("Unknown","Collecting","Up","Warning","Down","NoProbe","PausedbyUser","PausedbyDependency","PausedbySchedule","Unusual","PausedbyLicense","PausedUntil","DownAcknowledged","DownPartial")]
		[string[]]$FilterStatus,
		
		[Parameter(Mandatory=$False)]
		[string]$FilterTarget,
		
		[Parameter(Mandatory=$False)]
		[string]$FilterValue,

		[Parameter(Mandatory=$False)]
		[int]$Count,

		[Parameter(Mandatory=$False)]
		[switch]$Raw
	)

	<# things to add
	
		filter_drel (content = messages only) today, yesterday, 7days, 30days, 12months, 6months - filters messages by timespan
		filter_status (content = sensors only) Unknown=1, Collecting=2, Up=3, Warning=4, Down=5, NoProbe=6, PausedbyUser=7, PausedbyDependency=8, PausedbySchedule=9, Unusual=10, PausedbyLicense=11, PausedUntil=12, DownAcknowledged=13, DownPartial=14 - filters messages by status
		sortby = sorts on named column, ascending (or decending with a leading "-")
		filter_xyz - fulltext filtering. this is a feature in its own right
	
	
		
	#>

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		
		$CountProperty = @{}
		$FilterProperty = @{}
		
		if ($Count) {
			$CountProperty =  @{ "count" = $Count }
		}

		
		if ($FilterTags -and (!($Content -eq "sensors"))) {
			throw "Get-PrtgTableData: Parameter FilterTags requires content type sensors"
		} elseif ($Content -eq "sensors" -and $FilterTags) {
			$FilterProperty += @{ "filter_tags" = $FilterTags }
		}
		
		$StatusFilterCodes = @{
			"Unknown" = 1
			"Collecting" = 2
			"Up" = 3
			"Warning" = 4
			"Down" = 5
			"NoProbe" = 6
			"PausedbyUser" = 7
			"PausedbyDependency" = 8
			"PausedbySchedule" = 9
			"Unusual" = 10
			"PausedbyLicense" = 11
			"PausedUntil" = 12
			"DownAcknowledged" = 13
			"DownPartial" = 14
		}
		
		if ($FilterStatus -and (!($Content -eq "sensors"))) {
			throw "Get-PrtgTableData: Parameter FilterStatus requires content type sensors"
		} elseif ($Content -eq "sensors" -and $FilterStatus) {
			# I apparently wrote some code that gracefully
			# handles this (multiple properties w/ same name) two years ago.
			# good job, past josh
			$FilterProperty += @{ "filter_status" = $StatusFilterCodes[$FilterStatus] }
		}
		
		if ($FilterTarget) {
			if (!$FilterValue) {
				throw "Get-PrtgTableData: Parameter FilterTarget requires parameter FilterValue also"
			}
			$FilterName = "filter_" + $FilterTarget
			$FilterProperty += @{ $FilterName = $FilterValue }
		}

		if (!$Columns) {
			# this function currently doesn't work with "sensortree" or "maps"

			$TableLookups = @{
				"probes" = @("objid","type","name","tags","active","probe","notifiesx","intervalx","access","dependency","probegroupdevice","status","message","priority","upsens","downsens","downacksens","partialdownsens","warnsens","pausedsens","unusualsens","undefinedsens","totalsens","favorite","schedule","comments","condition","basetype","baselink","parentid","fold","groupnum","devicenum")
				
				"groups" = @("objid","type","name","tags","active","group","probe","notifiesx","intervalx","access","dependency","probegroupdevice","status","message","priority","upsens","downsens","downacksens","partialdownsens","warnsens","pausedsens","unusualsens","undefinedsens","totalsens","favorite","schedule","comments","condition","basetype","baselink","parentid","location","fold","groupnum","devicenum")
				
				"devices" = @("objid","type","name","tags","active","device","group","probe","grpdev","notifiesx","intervalx","access","dependency","probegroupdevice","status","message","priority","upsens","downsens","downacksens","partialdownsens","warnsens","pausedsens","unusualsens","undefinedsens","totalsens","favorite","schedule","deviceicon","comments","host","basetype","baselink","icon","parentid","location")
				
				"sensors" = @("objid","type","name","tags","active","downtime","downtimetime","downtimesince","uptime","uptimetime","uptimesince","knowntime","cumsince","sensor","interval","lastcheck","lastup","lastdown","device","group","probe","grpdev","notifiesx","intervalx","access","dependency","probegroupdevice","status","message","priority","lastvalue","lastvalue_raw","upsens","downsens","downacksens","partialdownsens","warnsens","pausedsens","unusualsens","undefinedsens","totalsens","favorite","schedule","minigraph","comments","basetype","baselink","parentid")
				
				"channels" = @("objid","name","lastvalue","lastvalue_raw")
				
				"todos" = @("objid","datetime","name","status","priority","message","active")
				
				"messages" = @("objid","datetime","parent","type","name","status","message")
				
				"values" = @("datetime","value_","coverage")
				
				"history" = @("datetime","dateonly","timeonly","user","message")
				
				"storedreports" = @("objid","name","datetime","size")
				
				"reports" = @("objid","name","template","period","schedule","email","lastrun","nextrun")
				
				"maps" = @("objid","name")
			}
	
			$SelectedColumns = $TableLookups.$Content
		} else {
			$SelectedColumns = $Columns
		}

		$SelectedColumnsString = $SelectedColumns -join ","

		$HTMLColumns = @("downsens","partialdownsens","downacksens","upsens","warnsens","pausedsens","unusualsens","undefinedsens","message","favorite")
	}

	PROCESS {

		$Parameters = @{
			"content" = $Content
			"columns" = $SelectedColumnsString
			"id" = $ObjectId
		} ################################################# needs to handle filters!
		
		$Parameters += $CountProperty
		$Parameters += $FilterProperty
		
		$url = $PrtgServerObject.UrlBuilder("api/table.xml",$Parameters)

		##### data returned; do!

		if ($Raw) {
			$QueryObject = $PrtgServerObject.HttpQuery($url,$false)
			return $QueryObject.Data
		}

		$QueryObject = $PrtgServerObject.HttpQuery($url)
		$Data = $QueryObject.Data

		$ReturnData = @()
		
		<#
		
		HOW THIS WILL LIKELY NEED TO WORK
		---
		
		build a switch statement that uses $Content to determine which types of objects we're going to create
		foreach item, assign all properties to the object
		attach the object to $ReturnData
		
		#>
		
		$PrtgObjectType = switch ($Content) {
			"probes"	{ "PrtgShell.PrtgProbe" }
			"groups"	{ "PrtgShell.PrtgGroup" }
			"devices"	{ "PrtgShell.PrtgDevice" }
			"sensors"	{ "PrtgShell.PrtgSensor" }
			"todos"		{ "PrtgShell.PrtgTodo" }
			"messages"	{ "PrtgShell.PrtgMessage" }
			"values"	{ "PrtgShell.PrtgValue" }
			"channels"	{ "PrtgShell.PrtgChannel" }
			"history"	{ "PrtgShell.PrtgHistory" }
			"maps"	{ "PrtgShell.PrtgBaseObject" }
		}
		
		if ($Data.$Content.item.childnodes.count) { # this will return zero if there's an empty set
			foreach ($item in $Data.$Content.item) {
				$ThisObject = New-Object $PrtgObjectType
				#$ThisRow = "" | Select-Object $SelectedColumns
				foreach ($Prop in $SelectedColumns) {
					if ($Content -eq "channels" -and $Prop -eq "lastvalue_raw") {
						# fix a bizarre formatting bug
						#$ThisObject.$Prop = HelperFormatHandler $item.$Prop
						$ThisObject.$Prop = $item.$Prop
					} elseif ($HTMLColumns -contains $Prop) {
						# strip HTML, leave bare text
						$ThisObject.$Prop =  $item.$Prop -replace "<[^>]*?>|<[^>]*>", ""
					} else {
						$ThisObject.$Prop = $item.$Prop
					}
				}
				$ReturnData += $ThisObject
			}
		} else {
			$ErrorString = "Object" + $ObjectId + " contains no objects of type" + $Content
			if ($FilterProperty.Count) {
				$ErrorString += " matching specified filter parameters"
			}
			
			Write-Host $ErrorString
		}

		<#
		# this section needs to be revisited
		# if the filter ends up returning an empty set, we need to say so, or return said empty said
		# and we also need to make the "get-prtgobjecttype" cmdlet that this depends on
		
		if ($ReturnData.name -eq "Item" -or (!($ReturnData.ToString()))) {
			$DeterminedObjectType = Get-PrtgObjectType $ObjectId

			$ValidQueriesTable = @{
				group=@("devices","groups","sensors","todos","messages","values","history")
				probenode=@("devices","groups","sensors","todos","messages","values","history")
				device=@("sensors","todos","messages","values","history")
				sensor=@("messages","values","channels","history")
				report=@("Currently unsupported")
				map=@("Currently unsupported")
				storedreport=@("Currently unsupported")
			}

			Write-Host "No $Content; Object $ObjectId is type $DeterminedObjectType"
			Write-Host (" Valid query types: " + ($ValidQueriesTable.$DeterminedObjectType -join ", "))
		} else {
			return $ReturnData
		}
		
		#>
		
		return $ReturnData
	}
}

###############################################################################
# Move-PrtgObject


function Move-PrtgObject {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[int]$ObjectId,
        [Parameter(Mandatory=$True,Position=1)]
        [int]$TargetGroupId
	)

    BEGIN {
        if (!($PrtgServerObject.Server)) { Throw "Not connected to a server!" }
    }

    PROCESS {
	
		$Url = $PrtgServerObject.UrlBuilder("moveobjectnow.htm",@{
			"id" = $ObjectId
			"targetid" = $TargetGroupId
			"approve" = 1
		})
		
		$Data = $PrtgServerObject.HttpQuery($Url,$false)
		
		return $Data | select HttpStatusCode,Statuscode
    }
}

###############################################################################
# New-PrtgDevice


function New-PrtgDevice {
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [PrtgShell.PrtgDeviceCreator]$PrtgObject
    )

    BEGIN {
        if (!($PrtgServerObject.Server)) { Throw "Not connected to a server!" }
		$PrtgServerObject.OverrideValidation()
    }

    PROCESS {

        $Url = $PrtgServerObject.UrlBuilder("adddevice2.htm")

        HelperHTTPPostCommand $Url $PrtgObject.QueryString

    }
}

###############################################################################
# New-PrtgGroup


function New-PrtgGroup {
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [PrtgShell.PrtgGroupCreator]$PrtgObject
    )

    BEGIN {
        if (!($PrtgServerObject.Server)) { Throw "Not connected to a server!" }
		$PrtgServerObject.OverrideValidation()
    }

    PROCESS {

        $Url = $PrtgServerObject.UrlBuilder("addgroup2.htm")

        HelperHTTPPostCommand $Url $PrtgObject.QueryString | Out-Null

    }
}

###############################################################################
# New-PrtgResult


function New-PrtgResult {
    <#
	.SYNOPSIS
		Creates a PrtgShell.XmlResult object for use in ExeXml output.
			
	.DESCRIPTION
		Creates a PrtgShell.XmlResult object for use in ExeXml output.
		
	.PARAMETER Channel
		Name of the channel.
			
	.PARAMETER Value
    		Integer value of the channel.
	
	.PARAMETER Unit
		Unit of the value.
			
	.PARAMETER SpeedSize
		Size of the value given, used for speed measurements.
			
	.PARAMETER VolumeSize
		Size of the value given, used for disk/file measurements.
			
	.PARAMETER SpeedTime
		Interval for displaying a speed measurement.

	.PARAMETER Difference
            Set the value as a difference value, as opposed to absolute.

        .PARAMETER DecimalMode
            Set the decimal display mode.

        .PARAMETER Warning
            Enable warning state for channel.

        .PARAMETER IsFloat
            Specify the value is a float, instead of integer.

        .PARAMETER ShowChart
            Show the channel in the charts section of the web ui.

        .PARAMETER ShowTable
            Show the channel in the table section of the web ui.

        .PARAMETER LimitMaxError
            Set the maximum value before a channel goes into an error state.  Only applies the first time a channel is reported to as sensor.

        .PARAMETER LimitMinError
            Set the minimum value before a channel goes into an error state.  Only applies the first time a channel is reported to as sensor.

        .PARAMETER LimitMaxWarning
            Set the maximum value before a channel goes into a warning state.  Only applies the first time a channel is reported to as sensor.

        .PARAMETER LimitMinWarning
            Set the minimum value before a channel goes into a warning state.  Only applies the first time a channel is reported to as sensor.

        .PARAMETER LimitErrorMsg
            Set the message reported when the channel goes into an error state.  Only applies the first time a channel is reported to as sensor.

        .PARAMETER LimitMaxError
            Set the message reported when the channel goes into a warning state.  Only applies the first time a channel is reported to as sensor.

        .PARAMETER LimitMode
            Set if the Limits defined are active.

        .PARAMETER ValueLookup
            Set a custom lookup file for the channel.
	#>
    PARAM (
        [Parameter(Mandatory=$True,Position=0)]
        [string]$Channel,

        [Parameter(Mandatory=$True,Position=1)]
        [decimal]$Value,

        [Parameter(Mandatory=$False)]
        [string]$Unit,

        [Parameter(Mandatory=$False)]
        [Alias('ss')]
        [ValidateSet("one","kilo","mega","giga","tera","byte","kilobyte","megabyte","gigabyte","terabyte","bit","kilobit","megabit","gigabit","terabit")]
        [string]$SpeedSize,

        [Parameter(Mandatory=$False)]
        [Alias('vs')]
        [ValidateSet("one","kilo","mega","giga","tera","byte","kilobyte","megabyte","gigabyte","terabyte","bit","kilobit","megabit","gigabit","terabit")]
        [string]$VolumeSize,

        [Parameter(Mandatory=$False)]
        [Alias('st')]
        [ValidateSet("second","minute","hour","day")]
        [string]$SpeedTime,

        [Parameter(Mandatory=$False)]
        [switch]$Difference,

        [Parameter(Mandatory=$False)]
        [Alias('dm')]
        [ValidateSet("auto","all")]
        [string]$DecimalMode,

        [Parameter(Mandatory=$False)]
        [switch]$Warning,

        [Parameter(Mandatory=$False)]
        [switch]$IsFloat,

		# note that both showchart and showtable default to "TRUE" in the actual API
		# which is to say, if they're not defined, they're assumed to be true
		# this is also true in the c# object that generates the XML,
		# but it is NOT assumed to be true here.
		# This is the part of the code that always puts in the showchart and showtables tags with zeroes!
        [Parameter(Mandatory=$False)]
        [Alias('sc')]
        [switch]$ShowChart,

        [Parameter(Mandatory=$False)]
        #[Alias('st')] # also the alias to "speedtime"
        [switch]$ShowTable,

        [Parameter(Mandatory=$False)]
        [int]$LimitMaxError = -1,

        [Parameter(Mandatory=$False)]
        [int]$LimitMinError = -1,

        [Parameter(Mandatory=$False)]
        [int]$LimitMaxWarning = -1,

        [Parameter(Mandatory=$False)]
        [int]$LimitMinWarning = -1,

        [Parameter(Mandatory=$False)]
        [string]$LimitErrorMsg,

        [Parameter(Mandatory=$False)]
        [string]$LimitWarningMsg,

        #[Parameter(Mandatory=$False)]
        #[Alias('lm')]
        #[switch]$LimitMode,

        [Parameter(Mandatory=$False)]
        [Alias('vl')]
        [string]$ValueLookup
    )

    BEGIN {
    }

    PROCESS {
        $ReturnObject = New-Object PrtgShell.XmlResult

        $ReturnObject.channel         = $Channel
        $ReturnObject.resultvalue     = $Value
        $ReturnObject.unit            = $Unit
        $ReturnObject.speedsize       = $SpeedSize
        $ReturnObject.volumesize      = $VolumeSize
        $ReturnObject.speedtime       = $SpeedTime
        $ReturnObject.valuemode       = $Mode # had to rename the object property; needs revisiting
        $ReturnObject.decimalmode     = $DecimalMode
        $ReturnObject.Warning         = $Warning
        $ReturnObject.isfloat         = $IsFloat
        $ReturnObject.showchart       = $ShowChart
        $ReturnObject.showtable       = $ShowTable
        $ReturnObject.limitmaxerror   = $LimitMaxError
        $ReturnObject.limitminerror   = $LimitMinError
        $ReturnObject.limitmaxwarning = $LimitMaxWarning
        $ReturnObject.limitminwarning = $LimitMinWarning
        $ReturnObject.limiterrormsg   = $LimitErrorMsg
        $ReturnObject.limitwarningmsg = $LimitWarningMsg
        #$ReturnObject.limitmode       = $LimitMode # read-only automatically-determined property. any reason we shouldn't do this?
        $ReturnObject.valuelookup     = $ValueLookup

        return $ReturnObject
    }
}

###############################################################################
# New-PrtgSensor


function New-PrtgSensor {
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [PrtgShell.PrtgSensorCreator]$PrtgObject
    )

    BEGIN {
        if (!($PrtgServerObject.Server)) { Throw "Not connected to a server!" }
		$PrtgServerObject.OverrideValidation()
    }

    PROCESS {

        $Url = $PrtgServerObject.UrlBuilder("addsensor5.htm")

        HelperHTTPPostCommand $Url $PrtgObject.QueryString | Out-Null

    }
}

###############################################################################
# Remove-PrtgObject


# remove-prtgobject
# needs to accept: an ID (the old way)
# a string of IDs (will this work?)
# a single prtgshell object object
# or an array of prtgshell object objects


# for handling objects
# needs to string together the objids from the objects received
# and then in the END block, execute the actual DO

function Remove-PrtgObject {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[int[]]$ObjectId
		#TODO: document this; $ObjectID for this cmdlet can either be a single integer or a comma-separated string of integers to handle multiples
	)

    BEGIN {
        if (!($PrtgServerObject.Server)) { Throw "Not connected to a server!" }
    }

    PROCESS {
		[string]$ObjectId = $ObjectId -join ","
	
		$Url = $PrtgServerObject.UrlBuilder("deleteobject.htm",@{
			"id" = $ObjectId
			"approve" = 1
		})
		
		$Data = $PrtgServerObject.HttpQuery($Url,$false)
		
		return $Data | select HttpStatusCode,Statuscode
    }
}

###############################################################################
# Set-PrtgError

function Set-PrtgError {
  Param (
    [Parameter(Mandatory=$True,Position=0)]
    [string]$ErrorText
  )

  PROCESS {
    $XmlObject = New-Object PrtgShell.ExeXml
    return $XmlObject.PrintError($ErrorText)
  }
}

###############################################################################
# Set-PrtgObjectPause


<#

actions.

resume
pause indefinitely (with message)
pause for a duration of minutes (with message)
or - pause until a datetime
set maintenance window (start/stop)


#>


function Set-PrtgObjectPause {
	<#
		.SYNOPSIS
			Pauses or resumes the specified PRTG object.
			
		.DESCRIPTION
			The Set-PrtgObjectPause cmdlet can be used to pause or resume an object, optionally with a message, for a specified duration, until a specified time, or as a one-time maintenance window.
		
		.PARAMETER PrtgObjectId
			An integer representing the target IDs to modify.
			
		.PARAMETER Resume
			Switch to resume the specified object and remove the paused state.
		
		.PARAMETER Message
			The string message to note on the object as the pause reason.
			
		.PARAMETER DurationInMins
			An integer specifying the duration of the paused state.
			
		.PARAMETER Until
			A datetime specifying the end of the paused state.
			
		.PARAMETER MaintenanceStart
			A datetime specifying the start of the one-time maintenance window.
			
		.PARAMETER MaintenanceStop
			A datetime specifying the end of the one-time maintenance window.
			
		.EXAMPLE
			Set-PrtgObjectPause 12345 -DurationInMins 10
			
			Pauses the object with ID 12345 for a duration of 10 minutes.
			
		.EXAMPLE
			Set-PrtgObjectPause 12345 -Until (Get-Date "4pm") -Message "Application recovery"
			
			Pauses the object with ID 12345 until 4:00 PM with the message "Application recovery".

		.EXAMPLE
			Set-PrtgObjectPause 12345 -MaintenanceStart (Get-Date "4pm") -MaintenanceStop (Get-Date "5pm")
			
			Reconfigures the object with ID 12345 for a maintenance window of 4:00 PM to 5:00 PM.
		
		.EXAMPLE
			Set-PrtgObjectPause 12345 -Resume
			
			Resumes the object with ID 12345, clearing the paused state and associated message.
		
	#>
	
	[CmdletBinding(DefaultParameterSetName="indefinite")]
    Param (
		[Parameter(Position = 0, Mandatory = $true)]
		[alias("id")]
		[int[]]$PrtgObjectId,
		
		[Parameter(ParameterSetName = "resume")]
		[switch]$Resume,
		
		[Parameter(Mandatory = $false, ParameterSetName = "indefinite")]
		[Parameter(Mandatory = $false, ParameterSetName = "duration")]
		[Parameter(Mandatory = $false, ParameterSetName = "until")]
		[string]$Message,
		
		[Parameter(Mandatory = $true, ParameterSetName = "duration")]
		[alias("duration")]
		[int]$DurationInMins,
		
		[Parameter(Mandatory = $true, ParameterSetName = "until")]
		[datetime]$Until,
		
		[Parameter(Mandatory = $true, ParameterSetName = "maintenance")]
		[datetime]$MaintenanceStart,
		
		[Parameter(Mandatory = $true, ParameterSetName = "maintenance")]
		[datetime]$MaintenanceStop
    )

    BEGIN {
        if (!($PrtgServerObject.Server)) { Throw "Not connected to a server!" }
		$PrtgServerObject.OverrideValidation()
    }

    PROCESS {
		
		switch ($PSCmdlet.ParameterSetName) {
			"resume" {
				$Url = $PrtgServerObject.UrlBuilder("api/pause.htm")
				
				$QueryStringTable = @{
					"id" 		= $PrtgObjectId
					"action"	= 1
				}
			}
			
			"indefinite" {
				$Url = $PrtgServerObject.UrlBuilder("api/pause.htm")
				
				$QueryStringTable = @{
					"id" 		= $PrtgObjectId
					"action"	= 0
				}
				
				if ($Message) { $QueryStringTable['pausemsg'] = $Message }
			}
			
			"duration" {
				$Url = $PrtgServerObject.UrlBuilder("api/pauseobjectfor.htm")
				
				$QueryStringTable = @{
					"id" 		= $PrtgObjectId
					"action"	= 0
					"duration"	= $DurationInMins
				}
				
				if ($Message) { $QueryStringTable['pausemsg'] = $Message }
			}
			
			"until" {
				$Url = $PrtgServerObject.UrlBuilder("api/pauseobjectfor.htm")
				
				$QueryStringTable = @{
					"id" 		= $PrtgObjectId
					"action"	= 0
					"duration"	= [int]($Until - (Get-Date)).TotalMinutes
				}
				
				if ($Message) { $QueryStringTable['pausemsg'] = $Message }
			}
			
			"maintenance" {
				$Url = $PrtgServerObject.UrlBuilder("editsettings")
				
				$QueryStringTable = @{
					"id" 			= $PrtgObjectId
					"maintstart_"	= (Get-Date $MaintenanceStart -Format "yyyy-MM-dd-HH-mm-ss")
					"maintend_"		= (Get-Date $MaintenanceStop -Format "yyyy-MM-dd-HH-mm-ss")
					"maintenable_"	= 1
				}
			}
		}
	
		# create a blank, writable HttpValueCollection object
		$QueryString = [System.Web.httputility]::ParseQueryString("")

		# iterate through the hashtable and add the values to the HttpValueCollection
		foreach ($Pair in $QueryStringTable.GetEnumerator()) {
			$QueryString[$($Pair.Name)] = $($Pair.Value)
		}

		$QueryString = $QueryString.ToString()

		HelperHTTPPostCommand $Url $QueryString | Out-Null
    }
}

###############################################################################
# Set-PrtgObjectProperty


function Set-PrtgObjectProperty {
        <#
        .SYNOPSIS
                
        .DESCRIPTION
                
        .EXAMPLE
                
        #>

    Param (
		[Parameter(Mandatory=$True,Position=0)]
		[int]$ObjectId,

		[Parameter(Mandatory=$True,Position=1)]
		[string]$Property,

		[Parameter(Mandatory=$True,Position=2)]
		[string]$Value
    )

	BEGIN {
		if (!($PrtgServerObject.Server)) { Throw "Not connected to a server!" }
	}

    PROCESS {
		$Url = $PrtgServerObject.UrlBuilder("api/setobjectproperty.htm",@{
			"id"		= $ObjectId
			"name" 		= $Property
			"value" 	= $Value
		})
		
		$Data = $PrtgServerObject.HttpQuery($Url,$false)
		
		return $Data.RawData -replace "<[^>]*?>|<[^>]*>", ""
	}
}

###############################################################################
# Set-PrtgSetting


function Set-PrtgSetting {
	<#
		.SYNOPSIS
			Sets the specified parameter(s) to the provided value(s) on the specified PRTG object(s).
			
		.DESCRIPTION
			The Set-PrtgSetting cmdlet can be used to set any reachable setting in any reachable object, or multiple settings on multiple objects. The only explicitly required parameter is the "id" parameter, which specifies one or more target objects to configure. Different object types accept different parameters.
		
		.PARAMETER PrtgObjectId
			An integer (or array of integers) representing the target IDs to modify.
			
		.PARAMETER PrtgObjectProperty
			The name of the parameter to modify. Note that many parameter names in PRTG have trailing underscores; this cmdlet currently does no validation on input.
		
		.PARAMETER PrtgObjectPropertyValue
			The value to set the PrtgObjectProperty to.
			
		.PARAMETER PrtgSettingHashtable
			A hashtable containing the IDs and properties you wish to configure. Ensure that the hashtable contains an "id" property.
			
		.EXAMPLE
			Set-PrtgSetting 1 name_ "Core Server" 
			
			Renames the local probe object (ID = 1) to "Core Server".
		
		.EXAMPLE
			$table = @{ "id" = 2076,2077,2070; "priority_" = 3; "tags_" = "newsensortag"}
			Set-PrtgSetting -table $table
			
			Sets the priority of sensors 2076, 2077, and 2070 to "3" and overwrites the current tag settings with "newsensortag".
	#>

    Param (
		[Parameter(Position = 0, Mandatory = $true)]
		[alias("id")]
		[int[]]$PrtgObjectId,
		
		[Parameter(Position = 1, Mandatory = $true, ParameterSetName = "singleproperty")]
		[alias("property")]
		[string]$PrtgObjectProperty,
		
		[Parameter(Position = 2, Mandatory = $true, ParameterSetName = "singleproperty")]
		[alias("value")]
		$PrtgObjectPropertyValue,
		
		[Parameter(Position = 1, ParameterSetName = "multipleproperties")]
		[alias("table")]
		[hashtable]$PrtgSettingHashtable
    )

    BEGIN {
        if (!($PrtgServerObject.Server)) { Throw "Not connected to a server!" }
		$PrtgServerObject.OverrideValidation()
    }

    PROCESS {

        $Url = $PrtgServerObject.UrlBuilder("editsettings")
		
		if ($PrtgObjectId) {
			if ($PrtgObjectId.Count -gt 1) {
				[string]$PrtgObjectId = $PrtgObjectId -join ","
			}
			
			$QueryStringTable = @{
				"id" 					= $PrtgObjectId
				$PrtgObjectProperty		= $PrtgObjectPropertyValue
			}
			
			if ($PrtgSettingHashtable) {
				$QueryStringTable += $PrtgSettingHashtable
			}
		} else {
			if ($PrtgSettingHashtable.id) {
				$QueryStringTable = $PrtgSettingHashtable
			} else {
				throw "Command requires Object ID!"
			}
		}
		
        # create a blank, writable HttpValueCollection object
        $QueryString = [System.Web.httputility]::ParseQueryString("")

        # iterate through the hashtable and add the values to the HttpValueCollection
        foreach ($Pair in $QueryStringTable.GetEnumerator()) {
	        $QueryString[$($Pair.Name)] = $($Pair.Value)
        }

        $QueryString = $QueryString.ToString()

        HelperHTTPPostCommand $Url $QueryString | Out-Null
    }
}

###############################################################################
# _helpers



function HelperHTTPQuery {
	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[string]$URL,

		[Parameter(Mandatory=$False)]
		[alias('xml')]
		[switch]$AsXML
	)

	try {
		$Response = $null
		$Request = [System.Net.HttpWebRequest]::Create($URL)
		$Response = $Request.GetResponse()
		if ($Response) {
			$StatusCode = $Response.StatusCode.value__
			$DetailedError = $Response.GetResponseHeader("X-Detailed-Error")
		}
	}
	catch {
		$ErrorMessage = $Error[0].Exception.ErrorRecord.Exception.Message
		$Matched = ($ErrorMessage -match '[0-9]{3}')
		if ($Matched) {
			throw ('HTTP status code was {0} ({1})' -f $HttpStatusCode, $matches[0])
		}
		else {
			throw $ErrorMessage
		}

		#$Response = $Error[0].Exception.InnerException.Response
		#$Response.GetResponseHeader("X-Detailed-Error")
	}

	if ($Response.StatusCode -eq "OK") {
		$Stream    = $Response.GetResponseStream()
		$Reader    = New-Object IO.StreamReader($Stream)
		$FullPage  = $Reader.ReadToEnd()

		if ($AsXML) {
			$Data = [xml]$FullPage
		} else {
			$Data = $FullPage
		}

		$Global:LastResponse = $Data

		$Reader.Close()
		$Stream.Close()
		$Response.Close()
	} else {
		Throw "Error Accessing Page $FullPage"
	}

	$ReturnObject = "" | Select-Object StatusCode,DetailedError,Data
	$ReturnObject.StatusCode = $StatusCode
	$ReturnObject.DetailedError = $DetailedError
	$ReturnObject.Data = $Data

	return $ReturnObject
}

function HelperHTTPPostCommand() {
	param(
		[string] $url = $null,
		[string] $data = $null,
		[System.Net.NetworkCredential]$credentials = $null,
		[string] $contentType = "application/x-www-form-urlencoded",
		[string] $codePageName = "UTF-8",
		[string] $userAgent = $null
	);

	if ( $url -and $data ) {
		[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create($url);
		
		$webRequest.ServicePoint.Expect100Continue = $false;
		#$webRequest.MaximumAutomaticRedirections = 2;
		
		if ( $credentials ) {
			$webRequest.Credentials = $credentials;
			$webRequest.PreAuthenticate = $true;
		}
		$webRequest.ContentType = $contentType;
		$webRequest.Method = "POST";
		if ( $userAgent ) {
			$webRequest.UserAgent = $userAgent;
		}

		$enc = [System.Text.Encoding]::GetEncoding($codePageName);
		[byte[]]$bytes = $enc.GetBytes($data);
		$webRequest.ContentLength = $bytes.Length;
		[System.IO.Stream]$reqStream = $webRequest.GetRequestStream();
		$reqStream.Write($bytes, 0, $bytes.Length);
		$reqStream.Flush();

		$resp = $webRequest.GetResponse();
		$rs = $resp.GetResponseStream();
		[System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs;
		$sr.ReadToEnd();
	}
}

function HelperFormatTest {
	$URLKeeper = $global:lasturl

	$CoreHealthChannels = Get-PrtgSensorChannels 1002
	$HealthPercentage = $CoreHealthChannels | ? {$_.name -eq "Health" }
	$ValuePretty = [int]$HealthPercentage.lastvalue.Replace("%","")
	$ValueRaw = [int]$HealthPercentage.lastvalue_raw

	if ($ValueRaw -eq $ValuePretty) {
		$RawFormatError = $false
	} else {
		$RawFormatError = $true
	}

	$global:lasturl = $URLKeeper

	$StoredConfiguration = $Global:PrtgServerObject | Select-Object *,RawFormatError
	$StoredConfiguration.RawFormatError = $RawFormatError

	$global:PrtgServerObject = $StoredConfiguration
}

function HelperFormatHandler {
    Param (
        [Parameter(Mandatory=$False,Position=0)]
        $InputData
	)

	if (!$InputData) { return }

	if ($Global:PrtgServerObject.RawFormatError) {
		# format includes the quirk
		return [double]$InputData.Replace("0.",".")
	} else {
		# format doesn't include the quirk, pass it back
		return [double]$InputData
	}
}

###############################################################################
## Export Cmdlets
###############################################################################

Export-ModuleMember *-*
