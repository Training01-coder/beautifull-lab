# Déployer BricoShop avec GitHub Actions (fiche participant)

Chaque participant déploie **sa propre copie** du site, dans **son compte AWS**, depuis
**son dépôt GitHub**, sur **son nom de domaine**. Aucune clé d'accès AWS n'est stockée
dans GitHub : le pipeline s'authentifie par **OIDC** (identifiants temporaires).

```
pull request            ──> build + terraform plan    (rôle aec-github-actions-plan, lecture seule)
push branche par défaut ──> build + plan + apply      (rôle aec-github-actions-deploy, après approbation)
Run workflow (manuel)   ──> build + destroy + plan + apply  (case destroy_first, cochée par défaut)
```

Configuration figée dans les workflows : région **eu-west-1**, préfixe **`aec`** sur chaque
ressource, site **https://aec.alpha-awslab26.click**. Une seule variable GitHub :
`AWS_ACCOUNT_ID`.

En local, le profil AWS utilisé est `formation` :

```powershell
$env:AWS_PROFILE = "formation"   # session courante
[Environment]::SetEnvironmentVariable("AWS_PROFILE", "formation", "User")   # permanent
```

---

## Prérequis

| Quoi | Vérification |
|---|---|
| Un compte AWS avec des droits admin, configuré en local | `aws sts get-caller-identity` répond |
| Terraform **≥ 1.10** | `terraform version` |
| Une **zone hébergée publique Route 53** dans **ce même compte** AWS | Route 53 → Hosted zones |
| Un compte GitHub | — |

Pas encore de domaine ? Route 53 → *Registered domains* → *Register* (un `.click` coûte
quelques $/an, la zone est créée automatiquement). Domaine chez un autre registrar ? Créer la
hosted zone dans Route 53 et recopier ses 4 serveurs NS chez le registrar.

---

## 1. Copier le dépôt sur ton compte GitHub

*Fork* (ou *Use this template*) du dépôt du formateur vers ton compte. Note le **nom de ton
compte** et le **nom du dépôt** : `https://github.com/<github_owner>/<github_repo>`.

```bash
git clone https://github.com/<github_owner>/<github_repo>.git
cd <github_repo>
```

## 2. Renseigner ta configuration

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Édite `terraform.tfvars` :

```hcl
aws_region   = "eu-west-1"
github_owner = "participant-42"       # ton compte GitHub
github_repo  = "bricoshop"            # ton dépôt
domain_name  = "participant42.click"  # ta zone Route 53
subdomain    = "app"                  # => https://app.participant42.click
```

## 3. Lancer le bootstrap (une seule fois)

```bash
terraform init
terraform apply      # répondre "yes"
```

Il crée dans **ton** compte AWS : la confiance OIDC avec GitHub, le bucket du state Terraform
(`aec-bricoshop-tfstate-<account_id>`) et les deux rôles IAM du pipeline
(`aec-github-actions-plan`, `aec-github-actions-deploy`). Il vérifie aussi que ta zone Route 53
existe.

À la fin, il affiche ce qu'il faut recopier dans GitHub :

```
github_environment = "production"
github_variables = {
  "AWS_ACCOUNT_ID" = "123456789012"
}
site_url = "https://aec.alpha-awslab26.click"
```

(Pour le réafficher plus tard : `terraform output`.)

## 4. Configurer GitHub

Dans ton dépôt GitHub :

**a) Variables** — *Settings → Secrets and variables → Actions → onglet **Variables** →
New repository variable*. Crée `AWS_ACCOUNT_ID` avec la valeur de `github_variables`.
C'est une *Variable*, pas un *Secret* : rien de sensible. Les anciennes variables `AWS_REGION`,
`DOMAIN_NAME` et `SUBDOMAIN` ne sont plus lues (valeurs figées dans les workflows).

**b) Environnement** — *Settings → Environments → New environment* → nom **`production`**
(exactement). Coche **Required reviewers** et ajoute-toi : chaque déploiement attendra ton
approbation.

**c) Actions** — sur un fork, ouvre l'onglet **Actions** et clique *I understand… enable
workflows* (GitHub désactive les workflows des forks par défaut).

## 5. Déployer

Pousse un commit sur la branche par défaut (ou *Actions → build-and-deploy → Run workflow*) :

```bash
git commit --allow-empty -m "Premier déploiement"
git push
```

Dans l'onglet **Actions**, le job `deploy` attend ton approbation (*Review deployments →
Approve*), puis lance `terraform apply`. Le résumé du run affiche l'URL du site. Le HTTPS est
disponible **1 à 3 min** après l'apply, le temps d'obtenir le certificat Let's Encrypt.

```bash
curl https://app.participant42.click/health
```

Ensuite : toute **pull request** affiche le `terraform plan` en commentaire ; tout **merge** sur
la branche par défaut redéploie (sans destroy).

*Actions → build-and-deploy → Run workflow* : la case **destroy_first** (cochée par défaut)
détruit le site avant de le recréer. Chaque recréation redemande un certificat Let's Encrypt
(limite : **5 par semaine** pour `aec.alpha-awslab26.click`). Décoche la case pour un simple
redéploiement.

---

## Dépannage

| Symptôme | Cause / correction |
|---|---|
| Job build : `Variable GitHub … manquante` | Étape 4a incomplète ou nom de variable mal orthographié. |
| `bootstrap apply` : `EntityAlreadyExists … token.actions.githubusercontent.com` | Le compte a déjà un fournisseur OIDC GitHub. Ajouter `create_oidc_provider = false` dans `terraform.tfvars` et relancer. |
| `bootstrap apply` : `no matching Route 53 Hosted Zone found` | `domain_name` ne correspond à aucune zone publique de ce compte AWS. |
| `bootstrap apply` : `BucketAlreadyExists` | Rarissime (nom basé sur l'ID du compte). Vérifier qu'on est sur le bon compte AWS. |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `github_owner` / `github_repo` du tfvars ≠ dépôt réel (attention à la casse), ou environnement GitHub pas nommé exactement `production`. Corriger puis relancer `terraform apply` dans le bootstrap. |
| `configure-aws-credentials` boucle sur `Assuming role with OIDC` | Même cause que ci-dessus. CloudTrail (`AssumeRoleWithWebIdentity`, `AccessDenied`) montre le `sub` réel. S'il contient des `@<id>` (dépôt créé après le 15/07/2026), renseigner `github_owner_id` / `github_repo_id` dans le tfvars du bootstrap et relancer `terraform apply`. |
| Le job `deploy` ne se lance pas après un push | Le push n'est pas sur la branche par défaut du dépôt, ou le workflow est désactivé (fork : étape 4c). |
| Le site ne répond pas en HTTPS | Attendre 3 min. Puis vérifier que les NS du domaine pointent bien vers la zone Route 53. |

---

## Lancer Terraform depuis sa machine (facultatif)

Le pipeline suffit. Pour travailler en local sur le même state que la CI :

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # mêmes domain_name / subdomain / aws_region
terraform init -backend-config="bucket=aec-bricoshop-tfstate-<account_id>" -backend-config="region=eu-west-1"
```

La commande `init` exacte est donnée par `terraform output local_init_command` dans
`terraform/bootstrap`. Le state est verrouillé (lockfile S3) : pas de risque de conflit avec un
run CI en cours.

> **Formateur — infra déjà déployée avec un state local ?** Ajoute `-migrate-state` à la
> commande `init` ci-dessus, une seule fois, pour envoyer ton state existant dans le bucket.

---

## Nettoyage en fin de formation

Dans cet ordre (le state du site est dans le bucket que supprime le bootstrap) :

**1. Le site, depuis le pipeline** (workflow [`destroy.yml`](../.github/workflows/destroy.yml)) :

1. *Actions* → colonne de gauche → **destroy-site** → *Run workflow*.
2. Branche : la branche par défaut (`main` ou `master`). Champ **confirm** : taper `destroy`.
3. Le job `destroy` attend ton approbation : *Review deployments* → `production` → *Approve and deploy*.
4. Le step *Terraform plan -destroy* liste les ressources supprimées (EC2, EIP, SG, rôle IAM,
   bucket app, log group, enregistrement DNS).

> Un push ultérieur sur la branche par défaut **recrée le site** (workflow `build-and-deploy`).
> Pratique pour la session suivante, mais à garder en tête.

Alternative locale (après l'`init` ci-dessus) : `cd terraform && terraform destroy`.

**2. Le bootstrap, en local uniquement** (le pipeline ne peut pas supprimer son propre rôle) :

```bash
cd terraform/bootstrap  && terraform destroy   # OIDC, rôles, bucket de state
```

Puis, si un ancien déploiement utilisait des **clés d'accès IAM** (`aws configure` d'un user
CI, secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` dans GitHub) : les supprimer
(*GitHub → Settings → Secrets* et *IAM → Users → Security credentials*). L'OIDC les rend
inutiles.

---

## Pour le formateur : ce qui est figé dans le code

Ces noms sont des **conventions partagées** entre [`terraform/bootstrap/main.tf`](../terraform/bootstrap/main.tf)
et [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml). Ils sont identiques dans
chaque compte, c'est ce qui permet de n'avoir que 4 variables :

| Convention | Valeur |
|---|---|
| Préfixe (initiales) | `aec` : `prefix` des tfvars, `PREFIX` / `TF_VAR_prefix` des workflows |
| Rôles IAM | `aec-github-actions-plan`, `aec-github-actions-deploy` |
| Bucket de state | `aec-bricoshop-tfstate-<account_id>` |
| Ressources du site | `aec-secagent-java-*` (EC2, SG, rôle, bucket), log group `/aec/bricoshop/app` |
| Région / site | `eu-west-1` / `aec.alpha-awslab26.click` |
| Clé du state | `bricoshop/terraform.tfstate` ([`terraform/backend.tf`](../terraform/backend.tf)) |
| Environnement GitHub | `production` |
| Version Terraform en CI | `TF_VERSION` dans le workflow |

Sécurité : le rôle plan n'est assumable que depuis une **pull request** du dépôt du participant,
le rôle deploy que depuis son environnement **`production`** (conditions `sub` exactes + `aud =
sts.amazonaws.com`, jamais `repo:*`). Le rôle deploy n'a pas `AdministratorAccess` : sa
politique ne couvre que les ressources du projet (EC2/SG/EIP, rôle et instance-profile
`aec-secagent-java-ec2-*`, buckets `aec-secagent-java-app-*`, log group `/aec/bricoshop/app`, **la seule zone Route 53
du participant**). Si tu ajoutes une ressource au Terraform principal, étends cette politique
puis fais réappliquer le bootstrap.
