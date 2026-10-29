# Atelier OAuth 2.0 et OpenID Connect

Application locale de gestion des demandes sécurisée avec Keycloak, Spring Boot et React/Vite.

## Architecture

```text
Navigateur React/Vite :5173
          │ Authorization Code + PKCE S256
          ▼
Keycloak :8080  ── Access Token JWT ──▶  API Spring Boot :8081
                                      Resource Server
```

- Keycloak joue le rôle d'Authorization Server et d'OpenID Provider.
- React est un client public OIDC (`react-client`). Les tokens restent en mémoire dans `keycloak-js`.
- Spring Boot valide les JWT et applique les autorisations selon les realm roles.
- Les demandes sont conservées en mémoire et sont perdues au redémarrage de l'API.

## Prérequis vérifiés

- Docker Desktop actif
- Docker 29.9.2 et Docker Compose 5.6.1
- Java 21 (Java 17 minimum)
- Node.js 20.19.0 et npm 10.8.2
- Maven non installé : le projet utilise `mvnw.cmd` (Maven Wrapper)

## Démarrage

Ouvrir trois terminaux PowerShell dans ce dossier.

### 1. Keycloak

```powershell
docker compose up -d
.\scripts\setup-keycloak.ps1
```

Keycloak est disponible sur <http://localhost:8080>.

### 2. API Spring Boot

```powershell
Set-Location .\demandes-api
.\mvnw.cmd -q -DskipTests package
.\mvnw.cmd spring-boot:run
```

L'API est disponible sur <http://localhost:8081>.

Vérifications rapides :

```powershell
Invoke-WebRequest http://localhost:8081/api/public
Invoke-WebRequest http://localhost:8081/api/demandes
```

La première requête renvoie HTTP 200 ; la seconde renvoie HTTP 401 sans token.

### 3. Frontend React

```powershell
Set-Location .\demandes-front
npm install --no-audit --no-fund --legacy-peer-deps
npm run dev
```

React est disponible sur <http://localhost:5173>.

## Configuration Keycloak

Realm : `enset-realm`

Client React : `react-client`

- Client authentication : Off
- Standard flow : On
- Implicit flow : Off
- Direct access grants : Off
- PKCE : S256
- Redirect URI : `http://localhost:5173/*`
- Web origin : `http://localhost:5173`

Comptes du TP :

| Utilisateur | Mot de passe | Realm roles |
|---|---|---|
| `alice` | `alice123` | `USER` |
| `bob` | `bob123` | `USER`, `ADMIN` |

Le compte administrateur local de Keycloak est `admin` / `admin`.

Pour les tests API automatisés uniquement, le client public temporaire `test-cli` active Direct Access Grants. Il ne doit pas être utilisé par React ni exposé hors de la machine locale :

```powershell
.\scripts\setup-test-cli.ps1
.\scripts\test-api.ps1
```

## API principale

| Méthode | Endpoint | Autorisation | Fonction |
|---|---|---|---|
| GET | `/api/public` | publique | Message de contrôle |
| GET | `/api/profil` | authentifié | `sub` et `preferred_username` |
| GET | `/api/demandes` | USER ou ADMIN | Demandes du propriétaire JWT |
| POST | `/api/demandes` | USER ou ADMIN | Créer une demande |
| GET | `/api/admin/demandes` | ADMIN | Toutes les demandes |
| PATCH | `/api/admin/demandes/{id}` | ADMIN | `EN_ATTENTE`, `VALIDEE` ou `REFUSEE` |

Le propriétaire d'une demande est toujours extrait du claim JWT `sub`, jamais du JSON envoyé par React.

## Tests réalisés

| Test | Résultat |
|---|---|
| Compilation `mvnw.cmd -q -DskipTests package` | ✅ Réussie |
| Tests Spring MockMvc | ✅ 9/9 |
| `/api/public` sans token | ✅ HTTP 200 |
| `/api/demandes` sans token | ✅ HTTP 401 |
| Alice dans l'interface | ✅ Réussi |
| Bob et panneau Administration | ✅ Réussi |
| Boutons Valider et Refuser | ✅ Réussi |
| Alice vers `/api/admin/demandes` | ✅ HTTP 403 |
| Bob vers `/api/admin/demandes` | ✅ HTTP 200 |
| Token invalide | ✅ HTTP 401 |
| `/api/profil` | ✅ HTTP 200 |
| Owner basé sur `sub` | ✅ Vérifié |

## Sécurité et limites du TP

- Ne jamais publier un Access Token réel ; les scripts n'affichent aucun token complet.
- Les tokens ne sont jamais stockés dans `localStorage` ou `sessionStorage`.
- Le masquage du panneau ADMIN dans React n'est pas une protection : Spring Security protège réellement les endpoints.
- `start-dev`, `admin/admin`, les mots de passe de TP et le stockage mémoire sont réservés à l'environnement local universitaire.

## Arrêt

Arrêter les processus Spring Boot et Vite avec `Ctrl+C`, puis arrêter Keycloak :

```powershell
docker compose down
```

Cette commande arrête les conteneurs sans supprimer le volume nommé `keycloak_data`.
