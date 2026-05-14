# Wasabi is S3-compatible, so it's managed via the official AWS provider with
# custom endpoints. The dedicated terrabitz/wasabi provider can't manage
# eu-central-2 buckets (unauthenticated HeadBucket region discovery returns 403
# there): https://github.com/terrabitz/terraform-provider-wasabi/pull/242
provider "aws" {
  alias      = "wasabi"
  region     = "eu-central-2"
  access_key = data.vault_kv_secret_v2.wasabi.data["access_key"]
  secret_key = data.vault_kv_secret_v2.wasabi.data["secret_key"]

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    s3 = "https://s3.eu-central-2.wasabisys.com"
  }
}

resource "aws_s3_bucket" "wasabi_homelab_backup" {
  provider = aws.wasabi
  bucket   = "diverofdark-homelab-backup"
}