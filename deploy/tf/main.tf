provider "google" {
  project = "${var.project}"
  region  = "us-central1"
}

# The APIs that must be enabled
resource "google_project_services" "apis" {
  project  = "${var.project}"
  services = [
    "iam.googleapis.com", "cloudbuild.googleapis.com", "compute.googleapis.com", "container.googleapis.com", "vision.googleapis.com"
  ]
}

/*
 * The necessary IAM resources
 */

# Service account for the GKE cluster nodes
resource "google_service_account" "cluster_service_account" {
  account_id   = "cluster-service-account"
  display_name = "Kubernetes engine cluster service account"
}

# Least privilege policy for the cluster node service account
# - logging.logWriter, monitoring.metricWriter, monitoring.viewer, storage.objectViewer
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

# Service account for the archiver pod
resource "google_service_account" "archiver_service_account" {
  account_id   = "archiver-service-account"
  display_name = "Image Archiver archiver service account"
}

# Least privilege policy for the archiver pod
# - storage.objectAdmin, pubsub.editor
resource "google_project_iam_policy" "archiver" {
  project     = "${var.project}"
  policy_data = "${data.google_iam_policy.archiver_pod.policy_data}"
}

data "google_iam_policy" "archiver_pod" {
  binding {
    role = "roles/storage.objectAdmin"

    members = [
      "serviceAccount:${google_service_account.archiver_service_account.email}",
    ]
  }
  binding {
    role = "roles/pubsub.editor"

    members = [
      "serviceAccount:${google_service_account.archiver_service_account.email}",
    ]
  }
}

# Grant the cluster node service account iam.serviceAccountTokenCreator on the archiver service account
resource "google_service_account_iam_binding" "archiver_token_creator" {
  service_account_id = "${google_service_account.archiver_service_account.name}"
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${google_service_account.cluster_service_account.email}"
  ]
}

# Service account for the labeler pod
resource "google_service_account" "labeler_service_account" {
  account_id   = "labeler-service-account"
  display_name = "Image Archiver Labeler service account"
}

# Least privilege policy for the labeler pod
# - pubsub.editor
resource "google_project_iam_policy" "labeler" {
  project     = "${var.project}"
  policy_data = "${data.google_iam_policy.labeler_pod.policy_data}"
}

data "google_iam_policy" "labeler_pod" {
  binding {
    role = "roles/pubsub.editor"

    members = [
      "serviceAccount:${google_service_account.labeler_service_account.email}",
    ]
  }
}

# Grant the cluster node service account iam.serviceAccountTokenCreator on the labeler service account
resource "google_service_account_iam_binding" "labeler_token_creator" {
  service_account_id = "${google_service_account.labeler_service_account.name}"
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${google_service_account.cluster_service_account.email}"
  ]
}

# Service account for the receiver pod
# - pubsub.editor
resource "google_service_account" "receiver_service_account" {
  account_id   = "receiver-service-account"
  display_name = "Image Archiver Receiver service account"
}

# Least privilege policy for the receiver pod
resource "google_project_iam_policy" "receiver" {
  project     = "${var.project}"
  policy_data = "${data.google_iam_policy.receiver_pod.policy_data}"
}

data "google_iam_policy" "receiver_pod" {
  binding {
    role = "roles/pubsub.editor"

    members = [
      "serviceAccount:${google_service_account.receiver_service_account.email}",
    ]
  }
}

# Grant the cluster node service account iam.serviceAccountTokenCreator on the receiver service account
resource "google_service_account_iam_binding" "receiver_token_creator" {
  service_account_id = "${google_service_account.receiver_service_account.name}"
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${google_service_account.cluster_service_account.email}"
  ]
}

# GKE cluster
resource "google_container_cluster" "cluster" {
  depends_on = [ "google_project_services.apis" ]

  name               = "${var.cluster_name}"
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
  }
}
