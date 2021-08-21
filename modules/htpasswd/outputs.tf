output "name" {
  value = kubernetes_secret.this.id
}

output "content" {
  value     = kubernetes_secret.this.data
  sensitive = true
}

output "passwords" {
  value     = { for k, v in htpasswd_password.this : k => v.password }
  sensitive = true
}
