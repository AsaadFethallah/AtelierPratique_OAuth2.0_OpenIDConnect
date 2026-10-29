param(
    [string]$AlicePassword = 'alice123',
    [string]$BobPassword = 'bob123'
)

$ErrorActionPreference = 'Stop'
$KeycloakUrl = 'http://localhost:8080'
$ApiUrl = 'http://localhost:8081'
$ClientId = 'test-cli'

function Get-AccessToken {
    param(
        [Parameter(Mandatory = $true)][string]$Username,
        [Parameter(Mandatory = $true)][string]$Password
    )

    $response = Invoke-RestMethod -Method Post `
        -Uri "$KeycloakUrl/realms/enset-realm/protocol/openid-connect/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{
            client_id  = $ClientId
            username   = $Username
            password   = $Password
            grant_type = 'password'
            scope      = 'openid profile'
        }
    if ([string]::IsNullOrWhiteSpace($response.access_token)) {
        throw "Aucun token obtenu pour $Username."
    }
    return $response.access_token
}

function Invoke-Api {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('GET', 'POST', 'PATCH')][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Token = '',
        [string]$Body = ''
    )

    $headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers['Authorization'] = "Bearer $Token"
    }
    $request = @{
        Method          = $Method
        Uri             = "$ApiUrl$Path"
        Headers         = $headers
        UseBasicParsing = $true
        TimeoutSec      = 15
        ErrorAction     = 'Stop'
    }
    if (-not [string]::IsNullOrWhiteSpace($Body)) {
        $request['ContentType'] = 'application/json'
        $request['Body'] = $Body
    }

    try {
        $response = Invoke-WebRequest @request
        return [PSCustomObject]@{
            Status  = [int]$response.StatusCode
            Content = $response.Content
        }
    } catch {
        $response = $_.Exception.Response
        if ($null -eq $response) {
            throw
        }
        $content = ''
        try {
            $stream = $response.GetResponseStream()
            $reader = [System.IO.StreamReader]::new($stream)
            $content = $reader.ReadToEnd()
            $reader.Dispose()
            $stream.Dispose()
        } catch {
            # Le statut HTTP reste suffisant pour les tests de sécurité.
        }
        return [PSCustomObject]@{
            Status  = [int]$response.StatusCode
            Content = $content
        }
    }
}

function Assert-Status {
    param(
        [Parameter(Mandatory = $true)][string]$Test,
        [Parameter(Mandatory = $true)]$Response,
        [Parameter(Mandatory = $true)][int]$Expected
    )
    if ($Response.Status -ne $Expected) {
        throw "${Test}: statut attendu $Expected, obtenu $($Response.Status)."
    }
    Write-Host ("{0,-52} HTTP {1}" -f $Test, $Response.Status)
}

Write-Host 'Obtention des tokens de test en mémoire...'
$aliceToken = Get-AccessToken -Username 'alice' -Password $AlicePassword
$bobToken = Get-AccessToken -Username 'bob' -Password $BobPassword

$test4 = Invoke-Api -Method GET -Path '/api/demandes'
Assert-Status -Test 'Test 4 - sans token' -Response $test4 -Expected 401

$test5 = Invoke-Api -Method GET -Path '/api/admin/demandes' -Token $aliceToken
Assert-Status -Test 'Test 5 - Alice vers API admin' -Response $test5 -Expected 403

$test6 = Invoke-Api -Method GET -Path '/api/admin/demandes' -Token $bobToken
Assert-Status -Test 'Test 6 - Bob vers API admin' -Response $test6 -Expected 200

$lastCharacter = $aliceToken.Substring($aliceToken.Length - 1, 1)
$replacement = if ($lastCharacter -eq 'A') { 'B' } else { 'A' }
$invalidToken = $aliceToken.Substring(0, $aliceToken.Length - 1) + $replacement
$test7 = Invoke-Api -Method GET -Path '/api/demandes' -Token $invalidToken
Assert-Status -Test 'Test 7 - token invalide' -Response $test7 -Expected 401

$profileResponse = Invoke-Api -Method GET -Path '/api/profil' -Token $aliceToken
Assert-Status -Test '§16.2 - profil Alice' -Response $profileResponse -Expected 200
$profile = $profileResponse.Content | ConvertFrom-Json
if ($profile.nomUtilisateur -ne 'alice') {
    throw "Le profil renvoyé ne correspond pas à Alice."
}

$objet = "Demande API $(Get-Date -Format 'yyyyMMdd-HHmmss')"
$createBody = @{ objet = $objet } | ConvertTo-Json -Compress
$createResponse = Invoke-Api -Method POST -Path '/api/demandes' -Token $aliceToken -Body $createBody
Assert-Status -Test 'Création Alice' -Response $createResponse -Expected 200
$created = $createResponse.Content | ConvertFrom-Json
if ($created.owner -eq 'alice') {
    throw 'Le owner ne doit pas être le username : il doit être le claim sub.'
}
$demandId = [long]$created.id

$alicePatch = Invoke-Api -Method PATCH -Path "/api/admin/demandes/$demandId" -Token $aliceToken -Body '{"statut":"REFUSEE"}'
Assert-Status -Test 'Sécurité - Alice ne modifie pas' -Response $alicePatch -Expected 403

$bobRefuse = Invoke-Api -Method PATCH -Path "/api/admin/demandes/$demandId" -Token $bobToken -Body '{"statut":"REFUSEE"}'
Assert-Status -Test '§16.1 - Refus par Bob' -Response $bobRefuse -Expected 200
$refused = $bobRefuse.Content | ConvertFrom-Json
if ($refused.statut -ne 'REFUSEE') {
    throw 'Le statut attendu après le refus est REFUSEE.'
}

Write-Host "`nTous les tests API sont réussis. Aucun token n'a été affiché."
