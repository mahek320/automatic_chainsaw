output "cluster_name" {
  description = "Name of the provisioned GKE cluster."
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Private endpoint of the GKE control plane."
  value       = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster; include it in kubeconfig."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "gke_access_token" {
  description = "Short-lived Google Cloud access token (from current auth context) for kubeconfig users."
  value       = data.google_client_config.current.access_token
  sensitive   = true
}

output "kubeconfig_file_path" {
  description = "Absolute path on the local machine where Terraform wrote the kubeconfig file."
  value       = local.kubeconfig_path
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository details for pushing Docker images."
  value = {
    name     = google_artifact_registry_repository.docker.name
    location = google_artifact_registry_repository.docker.location
    format   = google_artifact_registry_repository.docker.format
    repo_id  = google_artifact_registry_repository.docker.repository_id
  }
}

output "network_name" {
  description = "Name of the custom VPC network."
  value       = google_compute_network.primary.name
}

output "subnet_self_link" {
  description = "Self link of the primary GKE subnet."
  value       = google_compute_subnetwork.gke.self_link
}

output "cloud_nat_details" {
  description = "Key properties of the Cloud NAT serving the private GKE nodes."
  value = {
    name   = google_compute_router_nat.gke.name
    region = google_compute_router_nat.gke.region
    router = google_compute_router_nat.gke.router
    logging = {
      enabled = google_compute_router_nat.gke.log_config[0].enable
      filter  = google_compute_router_nat.gke.log_config[0].filter
    }
  }
}

# Cloud Build worker pool outputs are intentionally disabled
# because the worker pool resource is not created in this module.
#
# output "cloud_build_worker_pool" {
#   description = "Details for the private Cloud Build worker pool that performs builds and kubectl deployments."
#   value = {
#     id             = google_cloudbuild_worker_pool.deploy.id
#     name           = google_cloudbuild_worker_pool.deploy.name
#     location       = google_cloudbuild_worker_pool.deploy.location
#     machine_type   = google_cloudbuild_worker_pool.deploy.worker_config[0].machine_type
#     disk_size_gb   = google_cloudbuild_worker_pool.deploy.worker_config[0].disk_size_gb
#     no_external_ip = google_cloudbuild_worker_pool.deploy.worker_config[0].no_external_ip
#     peered_network = google_cloudbuild_worker_pool.deploy.network_config[0].peered_network
#   }
# }
