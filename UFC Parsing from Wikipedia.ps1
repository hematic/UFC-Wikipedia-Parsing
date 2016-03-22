#region Function Declarations

function Parse-CardData
{
	param
		(
		[pscustomobject]$Card
	)
	
	<# No known issues with this section at this time! #>
	
	
	<################################## Card Number Parsing######################################################>
	
	$Card.Number = ([regex]::matches($Card.Number, "(?:>)(.*)(?:<)")).groups[1].value
	If ($Card.number -eq "-") { $Card.number = "N/A" }
	
	<################################## Card Title Parsing#######################################################>
	
	$TempCardTitle = ([regex]::matches($Card.Title, "(?:title)(.+?)(?:<\/a>)")).groups[1].value
	$Card.Title = ([regex]::matches($TempCardTitle, "(?:>)(.*)")).groups[1].value
	
	<################################## Card Date Parsing########################################################>
	
	$Card.Date = ([regex]::matches($Card.Date, "(?:white-space:nowrap`">)(.+?)(?:</span>)")).groups[1].value
	
	<################################## Card Venue Parsing#######################################################>
	
	$Card.Venue = ([regex]::matches($Card.Venue, "(?:`">)(.+?)(?:<)")).groups[1].value
	If ($Card.venue -eq "The O") { $Card.venue = "The O2 arena" }
	If ($Card.venue -eq "O") { $Card.venue = "O2 World" }
	<################################## Card Location Parsing####################################################>
	
	$Card.Location = ([regex]::matches($Card.Location, "(?:`">)(.+?)(?:<)")).groups[1].value
	
	<################################## Card Link Parsing########################################################>
	
	$Card.Link = $WikiPrefix + ([regex]::matches($Card.Link, "(?:a href=`")(.+?)(?:`")")).groups[1].value
	
	<################################## Card Synopsis Parsing####################################################>
	
	$Card.Synopsis = "$($Card.Title) was a MMA event held on $($Card.Date), at the $($Card.Venue) in $($Card.Location)"
	
	<############################################################################################################>
		
	Return $Card
}

function Parse-FightResults
{
	param
		(
		[pscustomobject]$Card
	)
	foreach ($Fight in $Card.Fights)
	{
		$Fight.Weight = ([regex]::matches($Fight.Weight, "(?:>)(.+?)(?:<\/td>)")).groups[1].value
		$Fight.Fighter1 = ([regex]::matches($Fight.Fighter1, "(?:[^;`"]`">)(.+?)(?:<\/)")).groups[1].value
		If ($Fight.Fighter1 -like "*td style*") { $Fight.Fighter1 = ([regex]::matches($Fight.Fighter1, "(?:`">)(.+?)(?:<)")).groups[1].value }
		$Fight.Result = ([regex]::matches($Fight.Result, "(?:[^;`"]`">)(.+?)(?:<\/)")).groups[1].value
		$Fight.Fighter2 = ([regex]::matches($Fight.Fighter2, "(?:[^x`"]`">)(.+?)(?:<\/)")).groups[1].value
		If ($Fight.Fighter2 -like "*td style*") { $Fight.Fighter2 = ([regex]::matches($Fight.Fighter2, "(?:`">)(.+?)(?:<)")).groups[1].value }
		$Fight.Method = ([regex]::matches($Fight.Method, "(?:`">)(.+?)(?:<\/)")).groups[1].value
		$Fight.Round = ([regex]::matches($Fight.Round, "(?:`">)(.+?)(?:<\/)")).groups[1].value
		$Fight.Time = ([regex]::matches($Fight.Time, "(?:`">)(.+?)(?:<\/)")).groups[1].value
	}
	Return $Card.Fights
}

function Populate-CardBackgroundInformation
{
	
	param
		(
		[pscustomobject]$Card
	)
	
	<# Doesnt Work with TUF. Has extra line breaks. #>
	
	$Site = $Card.Link
	$Request = Invoke-WebRequest -URI $Site
	$AllCardContent = $request.content
	$pos = $AllCardContent.IndexOf("id=`"Background`">Background")
	$leftPart = $AllCardContent.Substring(0, $pos)
	$CardData = $AllCardContent.Substring($pos + 1)
	
	IF ($Card.Name -notlike '*The Ultimate Fighter*')
	{
		$Carddata = ([regex]::matches($Carddata, "(?:<p>)([\S\s]+?)(?:<h2>)")).groups[1].value
		$Carddata = $Carddata -replace "<.*?(>)", ''
		$Carddata = $Carddata -replace "\[.*?(\])", ''
		$Carddata = $Carddata -replace "`n", ''
		Return $Carddata
	}
	
	Else
	{
		<#Change this later to something that works.
		
		$pos = $CardData.IndexOf("<p>")
		$garbage = $CardData.Substring(0, $pos)
		$CardData = $CardData.Substring($pos + 1)
		
		$Carddata = $Carddata -replace "<.*?(>)", ''
		$Carddata = $Carddata -replace "\[.*?(\])", ''
		$Carddata = $Carddata -replace "`n", ''#>
		Return $Carddata
	}
	
}

function Populate-FightsArray
{
	
	param
		(
		[pscustomobject]$Card
	)
	
	$Site = $Card.Link
	$Request = Invoke-WebRequest -URI $Site
	$AllCardContent = $request.content
	$Pos = $AllCardContent.IndexOf("Notes</th>")
	$ResultsData = $AllCardContent.Substring($pos + 1)
	$Pos = $ResultsData.IndexOf("<td style")
	$ResultsData = $ResultsData.Substring($pos + 1)
	[System.Collections.ArrayList]$ResultsDataArray += ($Resultsdata -split '[\r\n]')
	$PrunedResults = @()
	
	Foreach ($Line in $Resultsdataarray) { If ($Line -like "*td style=*") { $PrunedResults += $Line } }
	
	$Counter = 0
	
	For ($I = 0; $PrunedResults.length -gt $($Counter + 7); $I++)
	{
		$FightsArray +=
		@([pscustomobject]@{
			Weight = $PrunedResults[($Counter)];
			Fighter1 = $PrunedResults[$Counter + 1];
			Result = $PrunedResults[$Counter + 2];
			Fighter2 = $PrunedResults[$Counter + 3];
			Method = $PrunedResults[$Counter + 4];
			Round = $PrunedResults[$Counter + 5];
			Time = $PrunedResults[$Counter + 6];
		})
		$Counter = $($Counter + 7)
	}
	
	Return $FightsArray
}

#endregion

#region Variable Declarations

$ErrorActionPreference = "SilentlyContinue"
$WikiPrefix = "en.wikipedia.org"

#endregion

#region Gather List of Cards

$Site = "http://en.wikipedia.org/wiki/List_of_UFC_events"
$Request = Invoke-WebRequest -URI $Site

<#Splits off the first couple hundred lines of unnecessary code.#>
$AllContent = $request.content
$pos = $AllContent.IndexOf("<th scope=`"col`">Attendance</th>")
$leftPart = $AllContent.Substring(0, $pos)
$CardData = $AllContent.Substring($pos + 1)

<#Trims off the last few lines and makes an arraylist with each new line.#>
$pos = $CardData.IndexOf("<tr>")
$leftPart = $CardData.Substring(0, $pos)
$CardData = $CardData.Substring($pos + 1)
[System.Collections.ArrayList]$Carddataarray += ($Carddata -split '[\r\n]')

#endregion

#region Create Initial Cards Object Array

Do
{
	$CardArray +=
	@([pscustomobject]@{
		Number = $Carddataarray[1];
		Title = $Carddataarray[2];
		Date = $Carddataarray[3];
		Venue = $Carddataarray[4];
		Location = $Carddataarray[5];
		Link = $Carddataarray[2];
		Synopsis = ''
		BackGround = ''
		Fights = ''
	})
	
	$Carddataarray.RemoveRange(0, 8)
}

While ($Carddataarray[0] -ne "</table>")

#endregion

#region Function Calls to Manipulate Data

Foreach ($Card in $CardArray)
{
	
	$Card = Parse-CardData $Card
	$Card.Background = Populate-CardBackgroundInformation $Card
	$Card.Fights = Populate-FightsArray $Card
	$Card.Fights = Parse-FightResults $Card
}

#endregion