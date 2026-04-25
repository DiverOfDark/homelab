# Long-lived API token from OpenBao
# Expected key: api_token (added alongside jwt_secret, sso_encryption_key)
data "vault_kv_secret_v2" "artifact_keeper" {
  mount = "secret"
  name  = "artifact-keeper"
}

provider "restapi" {
  alias                = "artifact_keeper"
  uri                  = "https://artifacts.kirillorlov.pro"
  write_returns_object = true
  id_attribute         = "key"
  update_method        = "PATCH"
  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer ${data.vault_kv_secret_v2.artifact_keeper.data["api_token"]}"
  }
}

resource "restapi_object" "repository_docker_local" {
  provider = restapi.artifact_keeper

  path         = "/api/v1/repositories"
  id_attribute = "key"

  data = jsonencode({
    key         = "docker-local"
    name        = "[Local] Docker"
    format      = "docker"
    repo_type   = "local"
    description = "Internal Docker / OCI images"
    is_public   = true
  })
}

locals {
  docker_proxy_repositories = {
    docker-hub = {
      name         = "Docker Hub"
      upstream_url = "https://registry-1.docker.io"
    }
    ghcr = {
      name         = "GitHub Container Registry"
      upstream_url = "https://ghcr.io"
    }
    quay = {
      name         = "Quay"
      upstream_url = "https://quay.io"
    }
    registry-k8s = {
      name         = "Kubernetes Registry"
      upstream_url = "https://registry.k8s.io"
    }
    lscr = {
      name         = "LinuxServer Container Registry"
      upstream_url = "https://lscr.io"
    }
    ecr-public = {
      name         = "AWS ECR Public"
      upstream_url = "https://public.ecr.aws"
    }
  }
}

resource "restapi_object" "repository_docker_proxy" {
  provider = restapi.artifact_keeper
  for_each = local.docker_proxy_repositories

  path         = "/api/v1/repositories"
  id_attribute = "key"

  data = jsonencode({
    key          = each.key
    name         = each.value.name
    format       = "docker"
    repo_type    = "remote"
    description  = "Proxy for ${each.value.upstream_url}"
    is_public    = true
    upstream_url = each.value.upstream_url
  })
}
