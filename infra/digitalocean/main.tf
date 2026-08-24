terraform {
  required_version = ">= 1.7.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_droplet" "demo" {
  name       = "enterprise-iceberg-demo"
  image      = "ubuntu-24-04-x64"
  region     = var.region
  size       = var.droplet_size
  ssh_keys   = [var.ssh_key_fingerprint]
  monitoring = true
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    repository_url = var.repository_url
  })
  tags = ["ephemeral", "lakehouse-demo"]
}

resource "digitalocean_firewall" "demo" {
  name        = "enterprise-iceberg-demo"
  droplet_ids = [digitalocean_droplet.demo.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

output "droplet_ip" {
  value = digitalocean_droplet.demo.ipv4_address
}

