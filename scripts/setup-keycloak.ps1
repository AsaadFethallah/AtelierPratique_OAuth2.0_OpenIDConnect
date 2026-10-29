$ErrorActionPreference = 'Stop'

$Container = 'keycloak-atelier'
$KeycloakUrl = 'http://localhost:8080'
$Realm = 'enset-realm'

function Invoke-Kc {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    & docker exec $Container /opt/keycloak/bin/kcadm.sh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "La commande kcadm a échoué (code $LASTEXITCODE): $($Arguments -join ' ')"
    }
}

function Test-KcResource {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    & docker exec $Container /opt/keycloak/bin/kcadm.sh @Arguments *> $null
    return ($LASTEXITCODE -eq 0)
}

function Set-PkceS256 {
    param([Parameter(Mandatory = $true)][string]$ClientId)

    # Keycloak 26.8 accepte mal cette clé contenant plusieurs points via -s.
    # L'Admin REST API permet de la définir sans ambiguïté.
    $tokenResponse = Invoke-RestMethod -Method Post `
        -Uri "$KeycloakUrl/realms/master/protocol/openid-connect/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ client_id = 'admin-cli'; username = 'admin'; password = 'admin'; grant_type = 'password' }
    $headers = @{ Authorization = "Bearer $($tokenResponse.access_token)" }
    $clientUri = "$KeycloakUrl/admin/realms/$Realm/clients/$ClientId"
    $clientRepresentation = Invoke-RestMethod -Method Get -Uri $clientUri -Headers $headers
    $attributes = @{}
    if ($null -ne $clientRepresentation.attributes) {
        foreach ($property in $clientRepresentation.attributes.PSObject.Properties) {
            $attributes[$property.Name] = [string]$property.Value
        }
    }
    $attributes['pkce.code.challenge.method'] = 'S256'
    $clientRepresentation.attributes = $attributes
    $payload = $clientRepresentation | ConvertTo-Json -Depth 30
    Invoke-RestMethod -Method Put -Uri $clientUri -Headers $headers -ContentType 'application/json' -Body $payload | Out-Null
}

Write-Host "Connexion à l'administration Keycloak..."
Invoke-Kc @('config', 'credentials', '--server', $KeycloakUrl, '--realm', 'master', '--user', 'admin', '--password', 'admin')

if (-not (Test-KcResource @('get', "realms/$Realm"))) {
    Write-Host "Création du realm $Realm..."
    Invoke-Kc @('create', 'realms', '-s', "realm=$Realm", '-s', 'enabled=true', '-s', 'registrationAllowed=false')
}

foreach ($role in @('USER', 'ADMIN')) {
    if (-not (Test-KcResource @('get', "roles/$role", '-r', $Realm))) {
        Write-Host "Création du realm role $role..."
        Invoke-Kc @('create', 'roles', '-r', $Realm, '-s', "name=$role")
    }
}

$clientJson = & docker exec $Container /opt/keycloak/bin/kcadm.sh get clients -r $Realm -q clientId=react-client --format json
if ($LASTEXITCODE -ne 0) {
    throw 'Impossible de rechercher le client react-client.'
}
$client = $clientJson | ConvertFrom-Json | Select-Object -First 1
if ($null -eq $client) {
    Write-Host 'Création du client react-client...'
    Invoke-Kc @(
        'create', 'clients', '-r', $Realm,
        '-s', 'clientId=react-client',
        '-s', 'name=react-client',
        '-s', 'protocol=openid-connect',
        '-s', 'publicClient=true',
        '-s', 'enabled=true',
        '-s', 'standardFlowEnabled=true',
        '-s', 'implicitFlowEnabled=false',
        '-s', 'directAccessGrantsEnabled=false',
        '-s', 'rootUrl=http://localhost:5173/',
        '-s', 'baseUrl=http://localhost:5173/'
    )
    $clientJson = & docker exec $Container /opt/keycloak/bin/kcadm.sh get clients -r $Realm -q clientId=react-client --format json
    $client = $clientJson | ConvertFrom-Json | Select-Object -First 1
}

if ($null -eq $client -or [string]::IsNullOrWhiteSpace($client.id)) {
    throw 'Le client react-client est introuvable après sa création.'
}

Write-Host 'Mise à jour de la configuration du client react-client...'
Invoke-Kc @(
    'update', "clients/$($client.id)", '-r', $Realm,
    '-s', 'clientId=react-client',
    '-s', 'protocol=openid-connect',
    '-s', 'publicClient=true',
    '-s', 'enabled=true',
    '-s', 'standardFlowEnabled=true',
    '-s', 'implicitFlowEnabled=false',
    '-s', 'directAccessGrantsEnabled=false',
    '-s', 'rootUrl=http://localhost:5173/',
    '-s', 'baseUrl=http://localhost:5173/'
)
Set-PkceS256 -ClientId $client.id
Invoke-Kc @(
    'update', "clients/$($client.id)", '-r', $Realm,
    '-s', 'redirectUris=[]',
    '-s', 'webOrigins=[]'
)
Invoke-Kc @(
    'update', "clients/$($client.id)", '-r', $Realm,
    '-s', 'redirectUris+=http://localhost:5173/*',
    '-s', 'webOrigins+=http://localhost:5173'
)

foreach ($user in @(
    @{ Username = 'alice'; Password = 'alice123'; Email = 'alice@enset.local'; FirstName = 'Alice'; LastName = 'Etudiante'; Roles = @('USER') },
    @{ Username = 'bob'; Password = 'bob123'; Email = 'bob@enset.local'; FirstName = 'Bob'; LastName = 'Administrateur'; Roles = @('USER', 'ADMIN') }
)) {
    $userJson = & docker exec $Container /opt/keycloak/bin/kcadm.sh get users -r $Realm -q username=$($user.Username) --format json
    if ($LASTEXITCODE -ne 0) {
        throw "Impossible de rechercher l'utilisateur $($user.Username)."
    }
    $existingUser = $userJson | ConvertFrom-Json | Select-Object -First 1
    if ($null -eq $existingUser) {
        Write-Host "Création de l'utilisateur $($user.Username)..."
        Invoke-Kc @(
            'create', 'users', '-r', $Realm,
            '-s', "username=$($user.Username)",
            '-s', 'enabled=true',
            '-s', "email=$($user.Email)",
            '-s', "firstName=$($user.FirstName)",
            '-s', "lastName=$($user.LastName)",
            '-s', 'emailVerified=true'
        )
        $userJson = & docker exec $Container /opt/keycloak/bin/kcadm.sh get users -r $Realm -q username=$($user.Username) --format json
        $existingUser = $userJson | ConvertFrom-Json | Select-Object -First 1
    }
    if ($null -eq $existingUser -or [string]::IsNullOrWhiteSpace($existingUser.id)) {
        throw "L'utilisateur $($user.Username) est introuvable après sa création."
    }
    Invoke-Kc @(
        'update', "users/$($existingUser.id)", '-r', $Realm,
        '-s', 'enabled=true',
        '-s', "username=$($user.Username)",
        '-s', "email=$($user.Email)",
        '-s', "firstName=$($user.FirstName)",
        '-s', "lastName=$($user.LastName)",
        '-s', 'emailVerified=true'
    )
    Invoke-Kc @('set-password', '-r', $Realm, '--userid', $existingUser.id, '--new-password', $user.Password)
    foreach ($role in $user.Roles) {
        Invoke-Kc @('add-roles', '-r', $Realm, '--uid', $existingUser.id, '--rolename', $role)
    }
}

Write-Host "`n=== Vérification realm ==="
Invoke-Kc @('get', "realms/$Realm")
Write-Host "`n=== Vérification rôles realm ==="
Invoke-Kc @('get', 'roles', '-r', $Realm)
Write-Host "`n=== Vérification client react-client ==="
Invoke-Kc @('get', 'clients', '-r', $Realm, '-q', 'clientId=react-client')
Write-Host "`n=== Vérification utilisateurs ==="
foreach ($username in @('alice', 'bob')) {
    Write-Host "-- $username --"
    $userJson = & docker exec $Container /opt/keycloak/bin/kcadm.sh get users -r $Realm -q username=$username --format json
    $existingUser = $userJson | ConvertFrom-Json | Select-Object -First 1
    if ($null -eq $existingUser) {
        throw "Utilisateur absent: $username"
    }
    Invoke-Kc @('get', "users/$($existingUser.id)/role-mappings/realm", '-r', $Realm)
}

Write-Host "`nConfiguration Keycloak terminée."
