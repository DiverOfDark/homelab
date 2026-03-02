resource "cloudflare_account" "account" {
  name = var.account_name
  type = "standard"
}

resource "cloudflare_account_member" "main_account" {
  account_id    = cloudflare_account.account.id
  email_address = var.owner_email
  role_ids      = ["33666b9c79b9a5273fc7344ff42f953d"]  # Owner role
  status        = "accepted"
}

resource "cloudflare_zone" "zone" {
  account_id = cloudflare_account.account.id
  zone       = var.zone_name
  type       = "full"
}