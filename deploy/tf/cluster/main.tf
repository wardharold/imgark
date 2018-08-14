variable "project" {}
variable "region" {
  default = "us-central1"
}

provider "google" {
  project = "${var.project}"
  region  = "us-central1"
}
