variable cluster_service_account {}

resource "google_service_account" "archiver_service_account" {
  account_id   = "archiver-service-account"
  display_name = "Image Archiver Archiver service account"
}

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

resource "google_service_account_iam_binding" "archiver_token_creator" {
  service_account_id = "${google_service_account.archiver_service_account.name}"
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${var.cluster_service_account}"
  ]
}

resource "google_service_account" "labeler_service_account" {
  account_id   = "labeler-service-account"
  display_name = "Image Archiver Labeler service account"
}

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

resource "google_service_account_iam_binding" "labeler_token_creator" {
  service_account_id = "${google_service_account.labeler_service_account.name}"
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${var.cluster_service_account}"
  ]
}

resource "google_service_account" "receiver_service_account" {
  account_id   = "receiver-service-account"
  display_name = "Image Archiver Receiver service account"
}

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

resource "google_service_account_iam_binding" "receiver_token_creator" {
  service_account_id = "${google_service_account.receiver_service_account.name}"
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${var.cluster_service_account}"
  ]
}
