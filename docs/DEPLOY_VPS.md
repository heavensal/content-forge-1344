# Déploiement Kamal sur le VPS (sans nom de domaine)

Cible actuelle : `ubuntu@51.75.124.208`, app en **HTTP** sur **`http://51.75.124.208:3001`**.

## 1. SSH sans mot de passe (obligatoire)

Kamal lance beaucoup de commandes SSH **sans terminal** : un mot de passe à la main ne suffit pas.

Une fois, depuis ton Mac :

```bash
ssh-copy-id ubuntu@51.75.124.208
```

Ensuite `ssh ubuntu@51.75.124.208` doit marcher **sans** taper le mot de passe.

## 2. Docker Hub (registry)

L’image ne peut pas rester sur `localhost` : il faut un registry public (ex. **Docker Hub**).

1. Crée un compte sur [hub.docker.com](https://hub.docker.com).
2. Crée un **Access Token** (remplace le mot de passe pour `docker login`).
3. **`config/deploy.yml`** utilise déjà l’image `adam1344/contentforge_1344_rails` et le registry `adam1344`.

4. **Secrets** : crée un fichier **`.env`** à la racine (déjà dans `.gitignore`) avec au minimum :

   - `DATABASE_URL='...'` — mets l’URL **entre quotes simples** si elle contient `&` (ex. Neon).
   - `KAMAL_REGISTRY_PASSWORD=dckr_pat_...` — token Docker Hub.

   Le fichier **`.kamal/secrets`** lit ces valeurs via des commandes `$(bash …)` compatibles Kamal/dotenv. Tu peux toujours exporter les variables à la main dans le terminal si tu préfères.

`RAILS_MASTER_KEY` est lu via `$(cat config/master.key)` dans `.kamal/secrets` — garde **`config/master.key` hors git**.

## 4. Premier déploiement

Sur la machine qui build (ton Mac, avec Docker lancé) :

```bash
cd /chemin/vers/contentforge-1344-rails
bundle install
bin/kamal setup    # installe Docker sur le VPS si besoin + prépare Kamal
bin/kamal deploy
```

Puis migrations (souvent une fois après le premier boot) :

```bash
bin/kamal app exec -i --reuse "bin/rails db:migrate"
```

## 5. Pare-feu sur le VPS

Ouvre au moins le port **3001** (HTTP) :

```bash
sudo ufw allow 3001/tcp
sudo ufw allow OpenSSH
sudo ufw enable   # si pas déjà actif
```

Le proxy Kamal peut aussi publier le **443** sur l’hôte (HTTPS désactivé côté app) ; si `ufw` bloque 443, ce n’est en général pas grave pour tester en **HTTP sur 3001** uniquement.

## 6. Accès

Dans le navigateur : **`http://51.75.124.208:3001`**

Si Rails répond “Blocked host”, vérifie que `RAILS_ALLOWED_HOSTS` dans `config/deploy.yml` contient bien `51.75.124.208` (déjà prévu).

## 7. Utilisateur `ubuntu` et Docker

Kamal / le script d’installation ajoute en principe `ubuntu` au groupe `docker`. Si `docker ps` échoue sans `sudo`, déconnecte-toi et reconnecte, ou :

```bash
sudo usermod -aG docker ubuntu
```

---

Quand tu auras un nom de domaine, tu pourras passer `proxy.ssl: true`, ajouter `host: ton.domaine.tld`, ouvrir **80/443**, et activer `force_ssl` / `assume_ssl` dans `production.rb` comme indiqué dans les commentaires Rails.
