variable "project" {}

variable "region" {
  default = "us-central1"
}

variable "images_topic" {
  default = "images"
}

variable "labeled_topic" {
  default = "labeled"
}

variable "cluster_name" {}
