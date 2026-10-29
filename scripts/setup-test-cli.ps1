$ErrorActionPreference = 'Stop'

$Container = 'keycloak-atelier'
$Realm = 'enset-realm'

function Invoke-Kc {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    & docker exec $Container /opt/keycloak/bin/kcadm.sh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "La commande kcadm a échoué (code $LASTEXITCODE)."
    }
}

Invoke-Kc @('config', 'credentials', '--server', 'http://localhost:8080', '--realm', 'master', '--user', 'admin', '--password', 'admin')
$json = & docker exec $Container /opt/keycloak/bin/kcadm.sh get clients -r $Realm -q clientId=test-cli --format json
if ($LASTEXITCODE -ne 0) {
    throw 'Recherche de test-cli impossible.'
}
$client = $json | ConvertFrom-Json | Select-Object -First 1

$settings = @(
    '-s', 'clientId=test-cli',
    '-s', 'name=test-cli',
    '-s', 'protocol=openid-connect',
    '-s', 'publicClient=true',
    '-s', 'enabled=true',
    '-s', 'standardFlowEnabled=false',
    '-s', 'implicitFlowEnabled=false',
    '-s', 'directAccessGrantsEnabled=true'
)

if ($null -eq $client) {
    Invoke-Kc (@('create', 'clients', '-r', $Realm) + $settings)
    Write-Host 'Client test-cli créé pour les scripts locaux.'
} else {
    Invoke-Kc (@('update', "clients/$($client.id)", '-r', $Realm) + $settings)
    Write-Host 'Client test-cli mis à jour pour les scripts locaux.'
}

Invoke-Kc @('get', 'clients', '-r', $Realm, '-q', 'clientId=test-cli', '--fields', 'clientId,publicClient,standardFlowEnabled,implicitFlowEnabled,directAccessGrantsEnabled')
