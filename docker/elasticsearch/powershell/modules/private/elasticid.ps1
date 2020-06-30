function Approve-ElasticId {
    param (
        [Parameter (Mandatory=$true)][ValidateNotNullOrEmpty()][string] $ElasticId
    )

    $split = $ElasticId.Split(":")
    if ($split.Count -ne 2) {
        return $false;
    }

    try {
        $decodedId = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($split[1]))
        $splitId = $decodedId.Split("$")
        return ($splitId.Count -eq 3)
    }
    catch {
        return $false
    }
}

function Get-ElasticUrlFromId {
    param (
        [Parameter (Mandatory=$true)][ValidateNotNullOrEmpty()][string] $ElasticId
    )

    $split = $ElasticId.Split(":")
    $decodedId = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($split[1]))
    $splitId = $decodedId.Split("$")

    $elasticUrl = "https://" + $splitId[1] + "." + $splitId[0]
    return $elasticUrl
}

function Get-KibanaUrlFromId {
    param (
        [Parameter (Mandatory=$true)][ValidateNotNullOrEmpty()][string] $ElasticId
    )

    $split = $ElasticId.Split(":")
    $decodedId = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($split[1]))
    $splitId = $decodedId.Split("$")

    $kibanaUrl = "https://" + $splitId[2] + "." + $splitId[0]
    return $kibanaUrl
}
