variable "aws_region" {
  description = "Region AWS de deploiement (forcee : eu-west-1)"
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = var.aws_region == "eu-west-1"
    error_message = "La region est forcee a eu-west-1."
  }
}

# Initiales du participant : prefixe de chaque nom de ressource (compte AWS partage).
# Doit rester identique au prefix du bootstrap (droits IAM scopes sur ces noms).
variable "prefix" {
  description = "Initiales du participant, prefixe des noms de ressources (ex: aec)"
  type        = string
  default     = "aec"

  validation {
    condition     = can(regex("^[a-z]{2,6}$", var.prefix))
    error_message = "prefix : 2 a 6 lettres minuscules."
  }
}

variable "domain_name" {
  description = "Zone hebergee Route 53 PUBLIQUE existante"
  type        = string
  default     = "alpha-awslab26.click"
}

variable "subdomain" {
  description = "Sous-domaine du site (aec => aec.alpha-awslab26.click)"
  type        = string
  default     = "aec"
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "demo_vuln" {
  description = "true = active une XSS volontaire sur /search pour que Security Agent ait quelque chose a trouver"
  type        = bool
  default     = false
}
