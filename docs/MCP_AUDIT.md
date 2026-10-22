# Audit avant modification — 22 octobre 2026

Base auditée : `79e30d208d561bc60a65e3b55fde9d2bbeba44fd` (master).

## Architecture et associations

Rails ~> 8.1.2 (8.1.4 verrouillé), Ruby 3.3.10, PostgreSQL, Devise, Hotwire/Tailwind, Action Text pour Article.content. Minitest et CI GitHub Actions. Aucun serveur MCP ni fournisseur OAuth existant.

Website possède articles, reviews, faqs et website_memberships. User accède aux websites par ces memberships. Un utilisateur non admin ne peut appartenir qu'à un site (validation et index unique user_id) ; un seul owner par site (index partiel). Les admins n'ont pas de membership et voient tous les sites.

Article : titre/slug obligatoires, slug unique par website et locale ; contenu Action Text. Faq : question/slug obligatoires, réponse obligatoire à publication. Review : auteur, contenu et note 1–5 obligatoires à publication. Tous ont draft/published/archived, locale fr/en et published_at obligatoire si published. Les FK et index protègent les associations et slugs.

## Autorisation actuelle

ApplicationController#accessible_websites applique admin ? Website.all : current_user.websites. Les trois contrôleurs CRUD chargent le site dans ce scope, puis le contenu dans l'association du site. Les paramètres permis excluent website_id et user_id. Owner et editor ont les mêmes droits de contenu ; seul un admin attribue les memberships et supprime les websites. Un editor peut aussi modifier les paramètres du site et son webhook : convention existante à revoir séparément si ce rôle doit être restreint.

L'API /api/v1 utilise un token permanent de Website, sans identité utilisateur ni scopes OAuth. Elle expose seulement les contenus publiés dont la date est passée, avec fallback de locale. Elle sert aussi send_form. Ne pas réutiliser ce token pour les écritures MCP.

## Publication et limites observées

RebuildsWebsite déclenche après commit (create/update/destroy), y compris les brouillons. Website#schedule_rebuild! vérifie site actif, URL et imports_<type>. DeliverWebsiteRebuildJob appelle WebsiteRebuildWebhook : HTTPS, HMAC timestampé, bearer optionnel, repository_dispatch GitHub possible, retries sur erreurs transitoires. Le site consommateur doit ensuite relire l'API.

- Aucun workflow d'approbation ; une modification de contenu publié est immédiatement visible via l'API.
- La queue production :async est en mémoire : jobs perdus possibles lors d'un arrêt. Publication enregistrée ne signifie pas reconstruction livrée.
- Une publication future devient visible à sa date, mais aucun job planifié à cette date n'est présent.
- Le webhook vérifie les IP DNS avant une deuxième résolution par Net::HTTP : fenêtre de DNS rebinding possible. À traiter séparément ; le MCP n'expose aucun paramètre de webhook.
- Tests existants utiles pour memberships/API/webhooks ; plusieurs tests CRUD/modèles sont encore des squelettes.

## Choix d'intégration

Endpoint MCP isolé, transport HTTP JSON sans session, OAuth authorization-code/PKCE servi par contentForge avec Doorkeeper et les comptes Devise existants. Chaque jeton est lié au User qui a consenti ; aucune identité n'est rapprochée par email. Les droits Rails sont revérifiés à chaque opération, sites archivés exclus. Scopes content:read, content:write, content:publish.

Toutes les mutations MCP produisent une proposition persistée, sans modifier les tables de contenu. Une page Devise/CSRF montre les valeurs exactes et exige un POST humain avant application. Les propositions expirent, sont à usage unique, liées à leur auteur/site et refusées si le contenu a changé. Une modification de contenu publié exige aussi content:publish. Cette première version exige donc un clic authentifié dans contentForge ; un « oui » uniquement dans ChatGPT n'est pas considéré comme une preuve serveur. Aucun outil ne peut approuver une proposition.

La découverte OAuth, l'inscription dynamique des clients et le consentement sont fournis par Rails ; le raccordement réel à ChatGPT reste à tester en préproduction avant activation. Aucun changement de production ni appel de webhook réel pendant les tests.
