# Seules valeurs a renseigner par participant (dans terraform.tfvars).
# Tout le reste (bucket de state, ARN des roles, zone Route 53) en est deduit.

variable "aws_region" {
  description = "Region AWS du participant (ex: eu-west-1)"
  type        = string
  default     = "eu-west-1"
}

variable "github_owner" {
  description = "Compte ou organisation GitHub du participant (ex: participant-42)"
  type        = string
}

variable "github_repo" {
  description = "Nom du depot GitHub du participant, sans le owner (ex: bricoshop)"
  type        = string
}

# Format "sub" immuable de GitHub (defaut pour les depots crees apres le
# 15/07/2026) : repo:<owner>@<owner_id>/<repo>@<repo_id>:...
# Laisser vide pour l'ancien format repo:<owner>/<repo>:...
# Valeurs visibles dans CloudTrail (AssumeRoleWithWebIdentity refuse) ou via
# l'API : gh api repos/<owner>/<repo> --jq '.owner.id, .id'
variable "github_owner_id" {
  description = "ID numerique du owner GitHub (format sub immuable), vide sinon"
  type        = string
  default     = ""
}

variable "github_repo_id" {
  description = "ID numerique du depot GitHub (format sub immuable), vide sinon"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Zone Route 53 publique existante dans le compte AWS du participant (ex: participant42.click)"
  type        = string
}

variable "subdomain" {
  description = "Sous-domaine du site (app => app.<domain_name>)"
  type        = string
  default     = "app"
}

variable "create_oidc_provider" {
  description = "false si le compte AWS possede deja un fournisseur OIDC token.actions.githubusercontent.com"
  type        = bool
  default     = true
}
