resource "random_password" "this" {
  for_each = var.users

  length = 32
}

resource "htpasswd_password" "this" {
  for_each = var.users

  password = random_password.this[each.key].result
  salt     = substr(sha512(random_password.this[each.key].result), 0, 8)
}



resource "kubernetes_secret" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  data = {
    auth = templatefile("${path.module}/templates/htpasswd.tmpl", {
      hashes = { for k, v in htpasswd_password.this : k => v.bcrypt }
    })
  }
}
