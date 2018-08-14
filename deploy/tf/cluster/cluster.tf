resource "google_service_account" "cluster_service_account" {
  account_id   = "cluster-service-account"
  display_name = "Kubernetes Engine Cluster Service Account"
}

resource "google_project_iam_policy" "cluster" {
  project     = "${var.project}"
  policy_data = "${data.google_iam_policy.cluster_node.policy_data}"
}

data "google_iam_policy" "cluster_node" {
  binding {
    role = "roles/logging.logWriter"

    members = [
      "serviceAccount:${google_service_account.cluster_service_account.email}",
    ]
  }
  binding {
    role = "roles/monitoring.metricWriter"

    members = [
      "serviceAccount:${google_service_account.cluster_service_account.email}",
    ]
  }
  binding {
    role = "roles/monitoring.viewer"

    members = [
      "serviceAccount:${google_service_account.cluster_service_account.email}",
    ]
  }
  binding {
    role = "roles/storage.objectViewer"

    members = [
      "serviceAccount:${google_service_account.cluster_service_account.email}",
    ]
  }
}

resource "google_container_cluster" "terratest" {
  name               = "terratest-01"
  zone               = "us-central1-b"
  initial_node_count = 3

  master_auth {
    username = ""
    password = ""
  }
  node_config {
    service_account = "${google_service_account.cluster_service_account.email}"
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/userinfo.email"
    ]
    labels {
      role = "test"
    }
  }
}
