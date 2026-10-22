# contentForge MCP

## État et périmètre

Voir [l'audit initial](MCP_AUDIT.md). Le serveur est **désactivé par défaut**. Cette implémentation ajoute le resource server OAuth et le workflow d'approbation Rails ; elle n'installe pas un fournisseur OAuth. Le branchement réel ChatGPT nécessite encore un fournisseur configuré et une recette de bout en bout.

`POST /mcp` sert JSON-RPC sur Streamable HTTP sans session ni SSE (`GET /mcp` retourne 405). Versions négociées : 2025-06-18 et 2025-11-25. Les clients doivent envoyer des messages individuels et le header MCP-Protocol-Version après initialisation. Pas de sampling, de ressources ni de prompts. Aucun appel OpenAI ni clé API OpenAI requis : ChatGPT génère le texte et appelle les outils.

| Outil | Comportement |
|---|---|
| list_websites | Jusqu'à 100 sites actifs accessibles, sans secrets |
| list_content | 50 contenus par page, curseur after_id |
| get_content | Lecture par site/type/id |
| prepare_change | Proposition create/update/delete/publish ; aucun contenu modifié |
| get_change | État de la proposition de l'utilisateur |

`content_type` est articles/reviews/faqs. Les champs acceptés suivent les formulaires Rails, sauf status/published_at qui ne sont jamais modifiables directement. Le HTML Article est limité à p/br/strong/em/ul/ol/li/h2/h3/blockquote/a, sans pièces jointes Action Text. Les reviews doivent refléter de vrais témoignages fournis par le client.

## Workflow humain

1. Le client connecte contentForge à ChatGPT via OAuth.
2. ChatGPT identifie le site, rédige et appelle prepare_change avec une clé de requête unique.
3. L'outil retourne un lien `/mcp/changes/:id`. Le client se connecte à contentForge avec Devise, vérifie le contenu et approuve par un formulaire protégé CSRF. Un GET ne modifie rien.
4. La proposition est appliquée atomiquement, une seule fois. Elle expire après 30 minutes. Toute modification concurrente du contenu, révocation de membership ou archive du site empêche son application.
5. Une création produit un brouillon. Pour le publier, préparer une seconde proposition `publish` puis l'approuver. Une mise à jour d'un contenu déjà publié attend aussi l'approbation, sans retirer la version existante du site.
6. Après application, les callbacks existants demandent la reconstruction. `applied: true` signifie enregistré, pas reconstruction confirmée.

**Différence avec le flux souhaité entièrement dans ChatGPT :** cette version impose une validation authentifiée dans contentForge. Un champ `confirmed: true` produit par le modèle ne prouve pas un consentement humain. Pour supprimer ce clic externe, ajouter ultérieurement une UI ChatGPT avec un canal d'approbation vérifiable, sans exposer une fonction d'approbation automatique au modèle.

## Connexion au compte et OAuth

Le client conserve son compte et son mot de passe contentForge. Dans **Account → Manage ChatGPT connection**, il associe le compte de l'identity provider utilisé par ChatGPT. Cette liaison passe par OpenID Connect Authorization Code + PKCE S256 ; contentForge valide la signature RS256 via JWKS, issuer, audience, expiration, nonce, état et le compte contentForge actuellement connecté. L'identité persistée est uniquement le couple stable `(issuer, sub)`, jamais l'adresse email. Un sujet déjà associé à un autre compte ne peut pas être réclamé. La déconnexion de cette page marque l'association comme révoquée, préserve son propriétaire et fait échouer les prochains appels MCP. Elle ne peut pas être transférée à un autre utilisateur ; le propriétaire initial peut la rétablir après une nouvelle vérification. Le client doit aussi retirer la connexion MCP de ses paramètres ChatGPT pour terminer sa révocation auprès du fournisseur.

Ensuite, le client ajoute le MCP contentForge dans ChatGPT. ChatGPT mène son **propre** consentement OAuth avec le même identity provider ; celui-ci doit émettre pour le resource server un access token dont le `sub` est le même que l'ID token OIDC lié dans contentForge. Le `resource` envoyé par ChatGPT doit apparaître dans `aud`. L'approbation de scopes MCP est distincte de la liaison dans les paramètres contentForge. La déconnexion dans ChatGPT retire son autorisation OAuth, tandis que la déconnexion côté contentForge invalide l'association locale.

Fournisseur requis : service établi qui supporte OAuth authorization-code + PKCE S256, OpenID Connect Discovery et JWKS RSA RS256 pour le client de liaison, ainsi que discovery MCP OAuth/CIMD ou DCR, le paramètre `resource`, l'audience MCP, l'introspection et les scopes pour la connexion ChatGPT. Les deux clients sont distincts : un client confidentiel de liaison de compte (`MCP_LINK_*`, redirect URI propre à contentForge) et le client MCP ChatGPT enregistré chez le même fournisseur (CIMD/DCR ou client prédéfini). Le client ChatGPT doit demander le consentement utilisateur ; aucun flux client-credentials/service-account ne remplace l'identité.

Le fournisseur héberge la connexion, le consentement, les codes, les refresh tokens et leur révocation. contentForge expose `/.well-known/oauth-protected-resource` et la variante `/mcp`, avec challenge WWW-Authenticate. L'introspection serveur à serveur RFC 7662 utilise HTTP Basic et exige :

- active = true ; iss exactement MCP_OAUTH_ISSUER ; aud (chaîne ou liste) contenant MCP_RESOURCE_URL ;
- exp numérique future, nbf respecté si présent ; sub non vide ; scope chaîne ;
- liaison McpIdentity `(issuer, subject)` existante vers un User Rails.

Le jeton n'est jamais conservé dans les propositions. Chaque appel fait une introspection sans cache ; une panne refuse l'accès. Les tokens de Website ne sont pas utilisables. Le provider doit retourner `iss`, `aud`, `exp`, `sub` et `scope`, même si certains champs sont facultatifs dans RFC 7662.

Scopes : `content:read` pour lire ; `content:write` en plus pour proposer ; `content:publish` en plus pour publier, modifier ou supprimer un contenu dont le statut est published (y compris publication future). L'outil renvoie un challenge d'augmentation des scopes si nécessaire. Les droits de membership sont relus, ils ne proviennent jamais des arguments du modèle. Les admins conservent leur accès global ; owner/editor conservent leurs droits existants.

## Configuration et déploiement

1. Migrer en préproduction : `bin/rails db:migrate` ; vérifier le schéma et les tests sur une base dédiée.
2. Configurer les variables `.env.example` via le gestionnaire de secrets : MCP_RESOURCE_URL (URL HTTPS canonique `/mcp`), MCP_OAUTH_ISSUER, MCP_OAUTH_INTROSPECTION_URL, MCP_OAUTH_CLIENT_ID, MCP_OAUTH_CLIENT_SECRET. Ces deux valeurs authentifient le **resource server pour introspection**. Configurer aussi MCP_LINK_CLIENT_ID, MCP_LINK_CLIENT_SECRET et MCP_LINK_REDIRECT_URI, puis enregistrer exactement l'URI de callback dans un client OIDC confidentiel. Ces identifiants diffèrent de l'enregistrement OAuth ChatGPT.
3. Enregistrer MCP_LINK_REDIRECT_URI comme callback exact du client OIDC de liaison ; activer `openid profile email`, authorization code, PKCE S256, RS256 et Discovery/JWKS HTTPS.
4. Enregistrer le client OAuth MCP ChatGPT auprès du même fournisseur : scopes `content:read content:write content:publish`, consentement et permissions d'introspection. Émettre le même `sub` stable, l'audience MCP MCP_RESOURCE_URL et les claims vérifiés par le serveur. Copier **exactement** l'URI de callback ChatGPT présentée dans l'espace de configuration MCP ; pas de wildcard. Si le fournisseur annonce `authorization_response_iss_parameter_supported`, il doit retourner le même `iss` pour chaque réponse d'autorisation, y compris une erreur.
5. Chaque client associe son compte dans Account → Manage ChatGPT connection avec son compte contentForge habituel, puis ajoute le MCP séparément dans ChatGPT et accorde les scopes OAuth.
6. Configurer HTTPS, RAILS_ALLOWED_HOSTS, filtrage réseau de l'introspection, limite de corps HTTP 256 KiB et rate limiting au reverse proxy (par IP puis utilisateur selon l'infrastructure). Le contrôleur limite à 600 requêtes/IP/minute avant introspection et 120/utilisateur/minute après authentification, avec un cache mémoire borné par processus (pas une limite globale multi-instance). Il borne également le corps, mais le proxy doit rejeter les gros corps avant parsing Rails. Ne pas journaliser Authorization ni les réponses d'introspection. Les attributs de contenu sont filtrés des logs Rails.
7. Autoriser seulement les origines nécessaires via MCP_ALLOWED_ORIGINS. Les appels serveur sans Origin sont acceptés, sous OAuth. Ne pas étendre le CORS de l'API publique pour contourner OAuth.
8. Activer MCP_ENABLED=true en préproduction. Connecter l'URL `/mcp` dans ChatGPT avec OAuth, puis faire la recette ci-dessous avant activation production.
9. Pour couper l'intégration : MCP_ENABLED=false et révocation du client/tokens chez le fournisseur. Ne pas supprimer les propositions appliquées si elles servent à l'audit ; définir une politique de rétention pour leur contenu client.

## Recette obligatoire

- MCP Inspector : découverte, initialisation, tools/list, erreurs JSON-RPC, reconnexion.
- Lier un utilisateur contentForge puis connecter ChatGPT avec le même compte fournisseur ; tester sujet différent, état/nonce incorrect, signature/JWKS invalide, mauvais issuer/audience, expiration, annulation, révocation et retrait du lien.
- Deux clients réels A/B : impossibilité de lire, proposer ou approuver le site de l'autre ; retirer une membership entre proposition et approbation.
- Créer brouillon, lire, modifier, publier et supprimer chaque type ; vérifier absence de modification publique avant approbation et comportement sur double clic / version périmée.
- Contrôler l'API du site consommateur et la reconstruction après approbation ; ne pas annoncer le site déployé sur la seule base d'un retour MCP.
- Exécuter `bin/rails test`, `bin/rubocop`, `bin/brakeman --no-pager` avec les mêmes versions que CI.

## Limites conservées et suites

La queue production :async n'est pas durable ; activer une file persistante et l'observabilité de livraison avant de promettre une distribution garantie (voir SOLID_OPTIONAL.md). La publication programmée n'est pas exposée. L'audit signale une fenêtre de DNS rebinding dans le webhook existant ; une correction dédiée doit pinner les IP vérifiées et couvrir IPv6. Pas de modification des secrets ou réglages de Website via MCP. Pas de téléchargement/gestion de médias, pas de UI ChatGPT embarquée, pas de publication sans clic contentForge. La liste de sites est limitée à 100 (à paginer si l'administration dépasse cette taille).

## Références

- https://developers.openai.com/plugins/build/auth — contrat OAuth ChatGPT/MCP, PKCE, discovery, resource et callback.
- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports — transport Streamable HTTP.
- https://www.rfc-editor.org/rfc/rfc7662 — introspection OAuth.
