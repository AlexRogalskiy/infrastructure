resource "kubernetes_namespace" "stress" {
  metadata {
    name = "stress"
  }

  depends_on = [
    module.cluster.node_pools
  ]
}

# Creates the CloudSQL Postgres database to be used by the `stress`
# Concourse deployment.
#
module "stress_database" {
  source = "../../dependencies/database"

  name            = "stress"
  cpus            = "4"
  disk_size_gb    = "150"
  memory_mb       = "5120"
  region          = var.region
  zone            = var.zone
  max_connections = "200"
}

data "template_file" "concourse_stress_values" {
  template = file("${path.module}/concourse-values.yml.tpl")
  vars = {
    cluster_name = "stress"

    image_repo   = var.concourse_stress_image_repo
    image_digest = var.concourse_stress_image_digest

    lb_address   = module.concourse_stress_address.address
    external_url = "https://${var.stress_subdomain}.${var.domain}"

    db_ip          = jsonencode(module.stress_database.ip)
    db_user        = jsonencode(module.stress_database.user)
    db_password    = jsonencode(module.stress_database.password)
    db_database    = jsonencode(module.stress_database.database)
    db_ca_cert     = jsonencode(module.stress_database.ca_cert)
    db_cert        = jsonencode(module.stress_database.cert)
    db_private_key = jsonencode(module.stress_database.private_key)

    encryption_key = jsonencode(random_password.encryption_key.result)
    local_users    = jsonencode("admin:${random_password.admin_password.result}")

    host_key     = jsonencode(tls_private_key.host_key.private_key_pem)
    host_key_pub = jsonencode(tls_private_key.host_key.public_key_openssh)

    worker_key     = jsonencode(tls_private_key.worker_key.private_key_pem)
    worker_key_pub = jsonencode(tls_private_key.worker_key.public_key_openssh)

    session_signing_key = jsonencode(tls_private_key.session_signing_key.private_key_pem)

    vault_ca_cert            = jsonencode(module.vault.ca_pem)
    vault_client_cert        = jsonencode(module.vault.client_cert_pem)
    vault_client_private_key = jsonencode(module.vault.client_private_key_pem)

    otelcol_config_map_name = kubernetes_config_map.otel_collector_stress.metadata.0.name
  }
}

resource "helm_release" "concourse_stress" {
  namespace  = kubernetes_namespace.stress.metadata.0.name
  name       = "concourse"
  repository = "https://concourse-charts.storage.googleapis.com"
  chart      = "concourse"
  version    = var.concourse_chart_version

  timeout = 2000

  values = [
    data.template_file.concourse_stress_values.rendered,
  ]

  depends_on = [
    module.cluster.node_pools,
  ]
}
