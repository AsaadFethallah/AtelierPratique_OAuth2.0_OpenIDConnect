# Liste des captures pour le compte rendu

Les captures doivent montrer uniquement l'état de l'application et les statuts HTTP utiles. Ne jamais laisser apparaître un Access Token complet.

## Déploiement et configuration

1. `docker compose ps` montrant `keycloak-atelier` actif sur le port 8080.
2. Keycloak, realm `enset-realm` sélectionné.
3. Client `react-client`, onglet **Settings** : client public, **Standard flow** activé, **Implicit flow** désactivé et **Direct access grants** désactivé.
4. Client `react-client`, URLs `Root URL`, `Home URL`, `Valid redirect URIs` et `Web origins`.
5. Client `react-client`, option PKCE réglée sur `S256`.
6. **Realm roles** montrant `USER` et `ADMIN`.
7. Utilisateur `alice`, onglet **Role mapping**, rôle `USER`.
8. Utilisateur `bob`, onglet **Role mapping**, rôles `USER` et `ADMIN`.

## Tests navigateur

9. Connexion réussie d'Alice : nom et rôle `USER` visibles.
10. Alice avec une demande `EN_ATTENTE` dans **Mes demandes** et panneau Administration absent.
11. Connexion réussie de Bob avec les rôles `USER, ADMIN`.
12. Bob voyant **Administration · toutes les demandes**.
13. Bob validant une demande : statut `VALIDEE`.
14. Bob refusant une demande : statut `REFUSEE`.
15. Outils développeur **Network** sur `GET /api/demandes`, avec seulement le préfixe `Bearer eyJ...` visible et le reste masqué.

## Tests API et sécurité

16. `GET /api/public` : HTTP 200 et message public.
17. `GET /api/demandes` sans token : HTTP 401.
18. Alice vers `GET /api/admin/demandes` : HTTP 403.
19. Bob vers `GET /api/admin/demandes` : HTTP 200.
20. Token modifié : HTTP 401.
21. `GET /api/profil` : identifiant et nom d'utilisateur issus du JWT.
22. Création d'une demande : owner égal au `sub` JWT et statut `EN_ATTENTE`.
23. Alice tentant un `PATCH /api/admin/demandes/{id}` : HTTP 403.
24. Bob envoyant `PATCH ...` avec `REFUSEE` : HTTP 200.
25. Sortie de `scripts/test-api.ps1` montrant les statuts, sans token affiché.

## Conseils pour le rapport

- Ajouter une courte légende et le numéro du test sous chaque capture.
- Masquer les identifiants de session, cookies et tokens dans les outils développeur.
- Ne pas capturer les mots de passe dans une fenêtre de navigateur ou un terminal partagé.
