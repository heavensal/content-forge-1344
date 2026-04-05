# Réactiver Solid (cache / queue / cable en base)

Actuellement l’app utilise **`:memory_store`**, **`:async`** pour Active Job, et **Action Cable `async`**. Aucune gem Solid.

Pour revenir au stack Rails 8 « full Solid » sur PostgreSQL :

1. **Gemfile** — décommenter `solid_cache`, `solid_queue`, `solid_cable`, puis `bundle install`.

2. **`config/environments/production.rb`** — commenter `memory_store` / `async` ; décommenter et activer `solid_cache_store`, `solid_queue`, `solid_queue.connects_to`.

3. **`config/database.yml`** — remplacer le bloc `production` simple par le bloc multi-DB commenté en bas du fichier.

4. **`config/cable.yml`** — production : reprendre le bloc `solid_cable` commenté dans ce fichier.

5. **`config/puma.rb`** — décommenter `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` et définir `SOLID_QUEUE_IN_PUMA=true` dans le déploiement si besoin.

6. **`config/recurring.yml`** — décommenter la section `production` si tu utilises les tâches planifiées Solid Queue.

7. **`bin/jobs`** — restaurer le contenu d’origine (voir l’historique git ou le générateur `rails solid_queue:install`).

8. **Schémas** — régénérer avec `rails solid_cache:install`, `solid_queue:install`, `solid_cable:install` (les anciens `db/*_schema.rb` Solid ont été retirés du repo).

9. **`bin/docker-entrypoint`** — si tu avais besoin de charger le schéma queue au boot, réintroduire le bloc documenté dans l’historique.

Référence : [guides Rails — multiple databases](https://guides.rubyonrails.org/active_record_multiple_databases.html), gems `solid_cache`, `solid_queue`, `solid_cable`.
