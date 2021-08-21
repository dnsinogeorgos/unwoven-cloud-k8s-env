output "ingress-prometheus-passwords" {
  value     = module.ingress_secret_prometheus.passwords
  sensitive = true
}

output "ingress-loki-passwords" {
  value     = module.ingress_secret_loki.passwords
  sensitive = true
}
