variable "do_token" {
  description = "DigitalOcean API token. Supply with TF_VAR_do_token; never commit it."
  type        = string
  sensitive   = true
}

variable "ssh_key_fingerprint" {
  description = "Fingerprint of an existing DigitalOcean SSH key."
  type        = string
}

variable "region" {
  type    = string
  default = "sgp1"
}

variable "droplet_size" {
  type    = string
  default = "s-4vcpu-8gb"
}

variable "repository_url" {
  description = "Public Git clone URL for this repository."
  type        = string
}

