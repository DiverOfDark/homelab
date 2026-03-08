resource "cloudflare_email_routing_settings" "email_routing" {
  zone_id = cloudflare_zone.zone.id
}

resource "cloudflare_email_routing_rule" "i_at_kirillorlov_pro" {
  zone_id = cloudflare_zone.zone.id
  name    = "i@kirillorlov.pro"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = "i@kirillorlov.pro"
  }]

  actions = [{
    type  = "forward"
    value = ["diverofdark@gmail.com"]
  }]
}

resource "cloudflare_email_routing_rule" "me_at_kirillorlov_pro" {
  zone_id = cloudflare_zone.zone.id
  name    = "me@kirillorlov.pro"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = "me@kirillorlov.pro"
  }]

  actions = [{
    type  = "forward"
    value = ["diverofdark@gmail.com"]
  }]
}

resource "cloudflare_email_routing_catch_all" "send_all_to_gmail" {
  zone_id = cloudflare_zone.zone.id
  name    = "catch all"
  enabled = true

  matchers = [{
    type = "all"
  }]

  actions = [{
    type  = "forward"
    value = ["diverofdark@gmail.com"]
  }]
}
