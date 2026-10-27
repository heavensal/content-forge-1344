# Forge MCP

## État et périmètre

Voir [l'audit initial](MCP_AUDIT.md). Le serveur est désactivé par défaut dans les environnements qui ne le configurent pas ; `config/deploy.yml` l'active explicitement en production. Forge utilise les comptes Devise existants et Doorkeeper pour jouer le rôle de serveur OAuth ; aucun fournisseur d'identité externe n'est requis.

`POST /mcp` sert JSON-RPC sur Streamable HTTP sans session ni SSE (`GET /mcp` retourne 405). Versions négociées : 2025-06-18 et 2025-11-25. Les clients doivent envoyer des messages individuels et le header MCP-Protocol-Version après initialisation. Pas de sampling, de ressources ni de prompts. Aucun appel OpenAI ni clé API OpenAI requis : ChatGPT génère le texte et appelle les outils.

| Outil | Comportement |
|---|---|
| list_websites | Jusqu'à 100 sites actifs accessibles, sans secrets |
| list_content | 50 contenus par page, curseur after_id |
| get_content | Lecture par site/type/id |
| prepare_change | Proposition create/update/delete/publish ; aucun contenu modifié |
| get_change | État de la proposition de l'utilisateur |

`content_type` est articles/reviews/faqs. Les champs acceptés suivent les formulaires Rails, sauf status/published_at qui ne sont jamais modifiables directement. Le HTML Article est limité à p/br/strong/em/ul/ol/li/h2/h3/blockquote/a, sans pièces jointes Action Text. Les reviews doivent refléter de vrais témoignages fournis par le client.

ChatGPT lit les instructions renvoyées par `initialize` ainsi que le titre, la description et le schéma de chaque outil renvoyé par `tools/list`. Ces informations expliquent l'ordre des appels, les trois types de contenu et la validation humaine. Le nom et la description du **plugin ChatGPT** sont saisis séparément dans ChatGPT lors de sa création : le serveur MCP ne peut pas remplir automatiquement ces champs. La page **Account → Manage ChatGPT access** affiche une description suggérée à copier. Après une mise à jour du serveur, rafraîchir les outils du plugin dans ses paramètres ChatGPT pour récupérer les nouvelles descriptions et instructions ([documentation OpenAI](https://developers.openai.com/api/docs/guides/custom-mcp-server#how-to-use)).

## Workflow humain

1. Le client ajoute le serveur MCP Forge dans ChatGPT. ChatGPT l'envoie vers Forge pour s'authentifier et consentir.
2. ChatGPT identifie le site, rédige et appelle prepare_change avec une clé de requête unique.
3. L'outil retourne un lien `/mcp/changes/:id`. Le client se connecte à Forge avec Devise, vérifie le contenu et approuve par un formulaire protégé CSRF. Un GET ne modifie rien.
4. La proposition est appliquée atomiquement, une seule fois. Elle expire après 30 minutes. Toute modification concurrente du contenu, révocation de membership ou archive du site empêche son application.
5. Une création produit un brouillon. Pour le publier, préparer une seconde proposition `publish` puis l'approuver. Une mise à jour d'un contenu déjà publié attend aussi l'approbation, sans retirer la version existante du site.
6. Après application, les callbacks existants demandent la reconstruction. `applied: true` signifie enregistré, pas reconstruction confirmée.

**Différence avec le flux souhaité entièrement dans ChatGPT :** cette version impose une validation authentifiée dans Forge. Un champ `confirmed: true` produit par le modèle ne prouve pas un consentement humain. Pour supprimer ce clic externe, ajouter ultérieurement une UI ChatGPT avec un canal d'approbation vérifiable, sans exposer une fonction d'approbation automatique au modèle.

## Connexion au compte et OAuth

Le client garde son compte et mot de passe Forge. Il ajoute le serveur MCP depuis ChatGPT. Le flux OAuth redirige vers Forge ; Devise authentifie l'utilisateur et Doorkeeper affiche le consentement à chaque nouvelle connexion, avec les scopes demandés. ChatGPT reçoit un jeton opaque à durée limitée avec refresh token. La page **Account → Manage ChatGPT access** liste les connexions et permet de les révoquer immédiatement. Aucun compte ChatGPT n'est associé par adresse email : l'accès utilise directement la session et l'identifiant interne du compte Forge connecté au consentement.

La connexion dans ChatGPT lance le consentement OAuth : si l'utilisateur n'est pas connecté à Forge, il entre ses identifiants Forge ; sinon il confirme les permissions. Il peut gérer ou révoquer l'accès depuis Forge et retirer la connexion ChatGPT depuis ChatGPT.

Forge publie les métadonnées OAuth, l'inscription dynamique de clients publics ChatGPT, l'autorisation, les jetons et PKCE S256. Il annonce `offline_access` et émet un refresh token pour maintenir la connexion après expiration du jeton d'accès. L'endpoint d'inscription n'accepte que les URL de callback HTTPS ChatGPT attendues, le flux authorization-code et les scopes connus. Le paramètre `resource` est obligatoire et vérifié à l'autorisation et à l'échange. Seul le flux authorization-code est activé ; pas de mot de passe OAuth, client credentials ou service account.

Forge héberge la connexion, le consentement, les codes, les refresh tokens et leur révocation. Il expose `/.well-known/oauth-authorization-server`, `/.well-known/oauth-protected-resource` et la variante `/mcp`, avec challenge WWW-Authenticate. Les jetons OAuth sont stockés sous forme hachée et vérifiés directement dans la base à chaque requête MCP :

- jeton non révoqué et non expiré ; propriétaire lié à un User Rails ;
- scopes accordés présents sur le jeton ; ressource MCP fixée par le flux OAuth validé.

Le jeton n'est jamais conservé dans les propositions. Les tokens de Website ne sont pas utilisables.

Scopes : `content:read` pour lire ; `content:write` en plus pour proposer ; `content:publish` en plus pour publier, modifier ou supprimer un contenu dont le statut est published (y compris publication future). L'outil renvoie un challenge d'augmentation des scopes si nécessaire. Les droits de membership sont relus, ils ne proviennent jamais des arguments du modèle. Les admins conservent leur accès global ; owner/editor conservent leurs droits existants.

## Configuration et déploiement

### Pour la PR de présentation et de descriptions MCP

Avant fusion : aucune nouvelle variable `.env`, aucun secret GitHub et aucune migration. Après fusion : attendre le déploiement automatique puis rafraîchir les outils dans les paramètres du plugin ChatGPT. Le nom et la description du plugin déjà créé restent à compléter manuellement dans ChatGPT si ces champs sont vides.

### Installation initiale et exploitation

1. Migrer en préproduction : `bin/rails db:migrate` ; vérifier le schéma et les tests sur une base dédiée.
2. Fournir `MCP_ENABLED=true` et `MCP_RESOURCE_URL=https://forge.1344.fr/mcp` au conteneur de production via `config/deploy.yml` ; aucune variable d'identifiants OAuth externes n'est nécessaire.
3. Vérifier dans les métadonnées les endpoints discovery, authorization, token et registration. L'inscription dynamique ChatGPT ne doit accepter que ses callbacks documentés.
4. Chaque client ajoute le MCP dans ChatGPT, se connecte à Forge avec son compte habituel et confirme les scopes demandés.
6. Configurer HTTPS, RAILS_ALLOWED_HOSTS, limite de corps HTTP 256 KiB et rate limiting au reverse proxy (par IP puis utilisateur selon l'infrastructure). Le contrôleur limite à 600 requêtes/IP/minute avant authentification et 120/utilisateur/minute après authentification, avec un cache mémoire borné par processus (pas une limite globale multi-instance). Il borne également le corps, mais le proxy doit rejeter les gros corps avant parsing Rails. Ne pas journaliser Authorization ni les jetons. Les attributs de contenu sont filtrés des logs Rails.
7. Autoriser seulement les origines nécessaires via MCP_ALLOWED_ORIGINS. Les appels serveur sans Origin sont acceptés, sous OAuth. Ne pas étendre le CORS de l'API publique pour contourner OAuth.
8. Si une préproduction existe, l'activer et y faire la recette avant la production. En production, ces deux variables sont définies dans `config/deploy.yml` ; une fusion déploie automatiquement le changement.
9. Pour couper l'intégration : MCP_ENABLED=false et révocation des connexions dans les paramètres Forge. Ne pas supprimer les propositions appliquées si elles servent à l'audit ; définir une politique de rétention pour leur contenu client.

## Recette obligatoire

- MCP Inspector : découverte, initialisation, tools/list, erreurs JSON-RPC, reconnexion.
- Tester l'inscription DCR valide/invalide, le rejet de callbacks hors ChatGPT, l'obligation PKCE et `resource`, les scopes, expiration, révocation et réautorisation.
- Deux clients réels A/B : impossibilité de lire, proposer ou approuver le site de l'autre ; retirer une membership entre proposition et approbation.
- Créer brouillon, lire, modifier, publier et supprimer chaque type ; vérifier absence de modification publique avant approbation et comportement sur double clic / version périmée.
- Contrôler l'API du site consommateur et la reconstruction après approbation ; ne pas annoncer le site déployé sur la seule base d'un retour MCP.
- Exécuter `bin/rails test`, `bin/rubocop`, `bin/brakeman --no-pager` avec les mêmes versions que CI.

## Limites conservées et suites

La queue production :async n'est pas durable ; activer une file persistante et l'observabilité de livraison avant de promettre une distribution garantie (voir SOLID_OPTIONAL.md). La publication programmée n'est pas exposée. L'audit signale une fenêtre de DNS rebinding dans le webhook existant ; une correction dédiée doit pinner les IP vérifiées et couvrir IPv6. Pas de modification des secrets ou réglages de Website via MCP. Pas de téléchargement/gestion de médias, pas de UI ChatGPT embarquée, pas de publication sans clic Forge. La liste de sites est limitée à 100 (à paginer si l'administration dépasse cette taille).

## Références

- https://developers.openai.com/plugins/build/auth — contrat OAuth ChatGPT/MCP, PKCE, discovery, resource et callback.
- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports — transport Streamable HTTP.
- https://www.rfc-editor.org/rfc/rfc8414 — métadonnées OAuth.
