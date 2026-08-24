# Ephemeral DigitalOcean deployment

This Terraform module creates one Ubuntu Droplet, a narrow firewall, and installs k3s. It deliberately does **not** store application secrets in Terraform state or cloud-init.

```powershell
$env:TF_VAR_do_token = "<local value>"
terraform -chdir=infra/digitalocean init
terraform -chdir=infra/digitalocean apply `
  -var "ssh_key_fingerprint=<existing-key-fingerprint>" `
  -var "repository_url=https://github.com/<owner>/enterprise-iceberg-lakehouse-demo.git"
```

After provisioning, connect by SSH, create Kubernetes Secrets from an ephemeral local `.env`, and deploy the manifests. Restrict PostgreSQL trusted sources to the Droplet/VPC before using it.

Destroy after the demonstration so compute billing stops:

```powershell
terraform -chdir=infra/digitalocean destroy
```

The SSH firewall is open in this initial scaffold so a new Droplet can be reached. Before a real client demo, set its source to the operator's current IP/CIDR.

