$token = $env:GH_RUNNER_TOKEN
$url = $env:GH_RUNNER_URL
$apiUrl = $env:GH_RUNNER_API_URL
$runnerName = $env:GH_RUNNER_NAME
$runnerGroup = $env:GH_RUNNER_GROUP
$runnerMode = $env:GH_RUNNER_MODE
$appId = $env:GH_RUNNER_APP_ID
$appPrivateKey = $env:GH_RUNNER_APP_PRIVATE_KEY
$appLogin = $env:GH_RUNNER_APP_LOGIN

$hasRunnerGroup = ($null -ne $runnerGroup -and $runnerGroup -ne "")
$isEphemeral = $true

if($null -ne $runnerMode -and $runnerMode -ne "" -and $runnerMode.ToLower() -eq "persistent") {
    $isEphemeral = $false
}

# Parse the GitHub URL once - used by both the GitHub App and PAT flows
$githubUrlSplit = $url.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)
if($githubUrlSplit.Length -eq 3) {
    $githubOrgRepoSegment = $githubUrlSplit[-1]
    $tokenType = "orgs"
} else {
    $githubOrgRepoSegment = $githubUrlSplit[-2] + "/" + $githubUrlSplit[-1]
    $tokenType = "repos"
}

if($null -eq $apiUrl -or $apiUrl -eq "") {
    $domain = $githubUrlSplit[1]
    if($domain.ToLower() -like "*ghe.com") {
        $apiUrl = "https://api.$domain"
    } else {
        $apiUrl = "https://api.github.com"
    }
}

function ConvertTo-Base64Url {
    param([byte[]]$Bytes)
    return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function New-GitHubAppJwt {
    param([string]$AppId, [string]$PrivateKeyPem)

    $iat = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 60
    $exp = $iat + 600

    $header = '{"alg":"RS256","typ":"JWT"}'
    $payload = "{`"iat`":$iat,`"exp`":$exp,`"iss`":$AppId}"

    $headerB64 = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($header))
    $payloadB64 = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($payload))
    $signingInput = "$headerB64.$payloadB64"

    $rsa = [System.Security.Cryptography.RSA]::Create()
    try {
        $rsa.ImportFromPem($PrivateKeyPem)
        $signature = $rsa.SignData(
            [System.Text.Encoding]::UTF8.GetBytes($signingInput),
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } finally {
        $rsa.Dispose()
    }

    return "$signingInput." + (ConvertTo-Base64Url $signature)
}

function Get-GitHubAppInstallationAccessToken {
    param([string]$AppId, [string]$PrivateKeyPem, [string]$AppLogin, [string]$ApiBaseUrl)

    $jwt = New-GitHubAppJwt -AppId $AppId -PrivateKeyPem $PrivateKeyPem
    $headers = @{
        Authorization = "Bearer $jwt"
        Accept        = "application/vnd.github.v3+json"
    }

    $installations = Invoke-RestMethod -Uri "$ApiBaseUrl/app/installations" -Headers $headers -Method Get
    $installation = $installations | Where-Object { $_.account.login -eq $AppLogin -and $_.app_id -eq [int64]$AppId } | Select-Object -First 1

    if($null -eq $installation) {
        throw "No GitHub App installation found for app id '$AppId' and login '$AppLogin'."
    }

    return (Invoke-RestMethod -Uri $installation.access_tokens_url -Headers $headers -Method Post).token
}

# Resolve credentials: GitHub App > PAT > raw runner token
$hasApp = (-not [string]::IsNullOrEmpty($appId)) -and (-not [string]::IsNullOrEmpty($appPrivateKey))
$anyAppPart = (-not [string]::IsNullOrEmpty($appId)) -or `
              (-not [string]::IsNullOrEmpty($appPrivateKey)) -or `
              (-not [string]::IsNullOrEmpty($appLogin))

$isAppInstallationToken = $false
if($hasApp) {
    if(-not [string]::IsNullOrEmpty($token)) {
        Write-Error "GH_RUNNER_TOKEN cannot be combined with GH_RUNNER_APP_ID/GH_RUNNER_APP_PRIVATE_KEY. These are mutually exclusive."
        exit 1
    }

    if([string]::IsNullOrEmpty($appLogin)) {
        # Default to the org name (or repo owner) parsed from the URL, matching the ACA behaviour
        $appLogin = $githubUrlSplit[2]
    }

    # Allow the PEM to be supplied with literal "\n" sequences (common when injecting via env vars)
    $pem = $appPrivateKey -replace '\\n', "`n"

    Write-Host "Obtaining a GitHub App installation access token for app id $appId and login $appLogin"
    $token = Get-GitHubAppInstallationAccessToken -AppId $appId -PrivateKeyPem $pem -AppLogin $appLogin -ApiBaseUrl $apiUrl
    $isAppInstallationToken = $true
} elseif($anyAppPart) {
    Write-Error "Partial GitHub App configuration. GH_RUNNER_APP_ID and GH_RUNNER_APP_PRIVATE_KEY must both be supplied."
    exit 1
}

# Get the runner registration token from the GitHub API if a PAT or App installation token is in play
$isPat = $false
if((-not [string]::IsNullOrEmpty($token)) -and ($token.StartsWith("ghp_") -or $token.StartsWith("github_pat_"))) {
    $isPat = $true
}

if($isPat -or $isAppInstallationToken) {
    $tokenApiUrl = "${apiUrl}/$($tokenType)/$($githubOrgRepoSegment)/actions/runners/registration-token"

    if($isAppInstallationToken) {
        Write-Host "Generating a new runner registration token using the GitHub App installation token from the url $tokenApiUrl"
    } else {
        Write-Host "Generating a new runner registration token using the supplied PAT from the url $tokenApiUrl"
    }

    $headers = @{}
    $headers.Add("Authorization", "bearer $token")
    $headers.Add("Accept", "application/vnd.github.v3+json")

    $token = (Invoke-RestMethod -Uri $tokenApiUrl -Headers $headers -Method Post).token
}

# Register the runner
$env:RUNNER_ALLOW_RUNASROOT = "1"
if($hasRunnerGroup) {
    if($isEphemeral) {
        Write-Host "Registering the runner $runnerName with the runner group $runnerGroup and ephemeral mode"
        ./config.sh --unattended --replace --url $url --token $token --name $runnerName --runnergroup $runnerGroup --ephemeral
    } else {
        Write-Host "Registering the runner $runnerName with the runner group $runnerGroup"
        ./config.sh --unattended --replace --url $url --token $token --name $runnerName --runnergroup $runnerGroup
    }
} else {
    if($isEphemeral) {
        Write-Host "Registering the runner $runnerName in ephemeral mode"
        ./config.sh --unattended --replace --url $url --token $token --name $runnerName --ephemeral
    } else {
        Write-Host "Registering the runner $runnerName"
        ./config.sh --unattended --replace --url $url --token $token --name $runnerName
    }
}

./run.sh
