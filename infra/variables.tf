variable "root_domain" {
  description = "Apex domain the site is served from. Its public hosted zone must exist in the DNS account."
  type        = string
  default     = "deployresponsibly.com"
}

variable "dns_profile" {
  description = "AWS CLI profile for the account that owns the domain's Route 53 hosted zone."
  type        = string
}

variable "rate_limit_per_5min" {
  description = "Max requests per client IP over 5 minutes before WAF blocks it."
  type        = number
  default     = 2000
}

variable "github_repo" {
  description = "GitHub repository (owner/name) that deploys the site."
  type        = string
  default     = "deployresponsibly/cloud-blog"
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for the site account, in USD."
  type        = string
  default     = "20"
}

variable "alert_email" {
  description = "Address that receives budget alerts."
  type        = string
}
