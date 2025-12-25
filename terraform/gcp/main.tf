locals {
  node_tags = [
    "gke-private-nodes"
  ]

  kubeconfig_path = var.kubeconfig_path != "" ? var.kubeconfig_path : "${path.module}/kubeconfig-${var.cluster_name}.yaml"

  #worker_pool_config = {
  #name           = length(trimspace(try(var.cloud_build_worker_pool.name, ""))) > 0 ? trimspace(try(var.cloud_build_worker_pool.name, "")) : "${var.cluster_name}-deploy-pool"
  #location       = length(trimspace(try(var.cloud_build_worker_pool.location, ""))) > 0 ? trimspace(try(var.cloud_build_worker_pool.location, "")) : var.region
  #machine_type   = length(trimspace(try(var.cloud_build_worker_pool.machine_type, ""))) > 0 ? trimspace(try(var.cloud_build_worker_pool.machine_type, "")) : "e2-standard-4"
  #disk_size_gb   = try(var.cloud_build_worker_pool.disk_size_gb, 100)
  #no_external_ip = try(var.cloud_build_worker_pool.no_external_ip, true)
  #}
}

data "google_client_config" "current" {}

data "google_container_engine_versions" "asia_south1" {
  location = var.region
  project  = var.project_id
}

resource "google_compute_network" "primary" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  project                 = var.project_id
}

resource "google_compute_subnetwork" "gke" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  project       = var.project_id
  network       = google_compute_network.primary.id

  secondary_ip_range {
    range_name    = var.pods_secondary_range_name
    ip_cidr_range = var.pods_secondary_range_cidr
  }

  secondary_ip_range {
    range_name    = var.services_secondary_range_name
    ip_cidr_range = var.services_secondary_range_cidr
  }

  private_ip_google_access = true
}

resource "google_compute_router" "gke" {
  name    = "${var.vpc_name}-router"
  network = google_compute_network.primary.id
  region  = var.region
  project = var.project_id
}

resource "google_compute_router_nat" "gke" {
  name                               = "${var.vpc_name}-nat"
  router                             = google_compute_router.gke.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = var.nat_log_filter
  }
}

resource "google_artifact_registry_repository" "docker" {
  location      = var.artifact_registry_location
  repository_id = var.artifact_registry_repository
  description   = "Docker images for workloads deployed into the tenant cluster"
  format        = "DOCKER"

  labels = {
    managed_by  = "terraform"
    environment = "gke-private"
  }

  depends_on = [google_project_service.required]
}

resource "google_container_cluster" "primary" {
  provider = google-beta

  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  network    = google_compute_network.primary.id
  subnetwork = google_compute_subnetwork.gke.id

  remove_default_node_pool = true
  initial_node_count       = 1

  min_master_version = data.google_container_engine_versions.asia_south1.latest_master_version

  release_channel {
    channel = var.release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    master_global_access_config {
      enabled = false
    }
  }

  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = false
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }

    http_load_balancing {
      disabled = false
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  deletion_protection = false

  depends_on = [google_project_service.required]
}

resource "google_container_node_pool" "cpu" {
  provider = google-beta

  name     = var.cpu_node_pool.name
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  initial_node_count = var.cpu_node_pool.min_count

  node_config {
    machine_type = var.cpu_node_pool.machine_type
    disk_size_gb = var.cpu_node_pool.disk_size_gb
    disk_type    = var.cpu_node_pool.disk_type
    image_type   = "COS_CONTAINERD"
    labels       = var.cpu_node_pool.node_labels != null ? var.cpu_node_pool.node_labels : {}

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    tags = concat(local.node_tags, var.cpu_node_pool.tags)

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    dynamic "taint" {
      for_each = var.cpu_node_pool.taints != null ? var.cpu_node_pool.taints : []
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  autoscaling {
    min_node_count = var.cpu_node_pool.min_count
    max_node_count = var.cpu_node_pool.max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [google_container_cluster.primary]
}

resource "google_container_node_pool" "gpu" {
  provider = google-beta

  name     = var.gpu_node_pool.name
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  initial_node_count = var.gpu_node_pool.min_count

  node_config {
    machine_type = var.gpu_node_pool.machine_type
    disk_size_gb = var.gpu_node_pool.disk_size_gb
    disk_type    = var.gpu_node_pool.disk_type
    image_type   = "COS_CONTAINERD"
    labels       = var.gpu_node_pool.node_labels != null ? var.gpu_node_pool.node_labels : {}

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    tags = concat(local.node_tags, var.gpu_node_pool.tags)

    guest_accelerator {
      type  = var.gpu_node_pool.accelerator_type
      count = var.gpu_node_pool.accelerator_count
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    dynamic "taint" {
      for_each = var.gpu_node_pool.taints != null ? var.gpu_node_pool.taints : []
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  autoscaling {
    min_node_count = var.gpu_node_pool.min_count
    max_node_count = var.gpu_node_pool.max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [google_container_cluster.primary]
}

resource "local_file" "kubeconfig" {
  filename = local.kubeconfig_path

  content = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = google_container_cluster.primary.name
      cluster = {
        server                     = "https://${google_container_cluster.primary.endpoint}"
        certificate-authority-data = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
      }
    }]
    contexts = [{
      n
