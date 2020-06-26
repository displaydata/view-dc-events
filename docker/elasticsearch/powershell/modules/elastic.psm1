Get-ChildItem -Path $PSScriptRoot\public\*.ps1, $PSScriptRoot\private\*.ps1 -Exclude *.tests.ps1, *profile.ps1 -ErrorAction SilentlyContinue |
ForEach-Object {
    . $_.FullName
}

function Import-ElasticSettingsToUrl {
  param(
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Url,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Path,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Username,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Password
  )

  Import-ElasticSettings -Url $url -Path $Password -Username $Username -Password $Password
}

function Import-ElasticSettingsToElasticCloud {
  param(
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$ElasticId,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Path,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Username,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$Password
  )
  $valid = Approve-ElasticId -ElasticId $ElasticId
  if ($valid -eq $false) {
    throw "Could not validate the Elastic Cloud Id"
  }
  
  $url = Get-ElasticUrlFromId -ElasticId $ElasticId
  Write-Host $url
  Import-ElasticSettingsToUrl -Url $url -Path $Password -Username $Username -Password $Password
}

Export-ModuleMember -Function Import-ElasticSettingsToUrl
Export-ModuleMember -Function Import-ElasticSettingsToElasticCloud
