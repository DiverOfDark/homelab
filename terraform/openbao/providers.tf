provider "zitadel" {
  domain           = var.zitadel_domain
  insecure         = var.zitadel_insecure
  port             = var.zitadel_port
  jwt_profile_file = var.zitadel_jwt_profile_file
}

provider "vault" {
  address = var.openbao_addr
  token   = var.openbao_token
}
