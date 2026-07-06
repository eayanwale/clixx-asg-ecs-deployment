# stack-aut-Clixx

Terraform stack that provisions the full AWS runtime for **CliXX Retail**, a WordPress application: VPC/networking, an Application Load Balancer, an auto-scaling EC2 fleet, EFS-backed shared storage, and an RDS database restored from a snapshot. A Jenkins pipeline (`Jenkinsfile`) drives `init`/`plan`/`apply`/`destroy`, runs an AI source-code audit step, and posts status to Slack.

---

## Architecture

```
                    Internet
                        │
                        ▼
        Application Load Balancer (public, HTTP:80)
                        │
                Target Group (200,301,302)
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
     EC2 #1          EC2 #2          EC2 #3     ← Auto Scaling Group (1-3, target-tracking on CPU)
        │               │               │          private subnets, custom AMI (built by image pipeline)
        └───────────────┼───────────────┘
                        ▼
        /var/www/html ← EFS mount (shared WordPress files)
                        │
                        ▼
        RDS (db.m5.large, restored from snapshot)

  Bastion host (public subnet) ── SSH access into the private network
```

See [docs/architecture.png](docs/architecture.png) for the original diagram and [docs/stack-Clixx.md](docs/stack-Clixx.md) for a deeper (though partially historical) design writeup — the version history in `docs/v1.x-*.md` tracks how the stack evolved.

## What this stack creates

| Area | File | Notes |
|---|---|---|
| Networking | [vpc.tf](vpc.tf) | VPC (`10.1.0.0/16`), 2 public + 2 private subnets across 2 AZs, IGW, NAT gateway, route tables, S3 gateway endpoint. |
| Security groups | [security.tf](security.tf) | App SG, ALB SG, bastion SG, EFS SG, DB SG — least-privilege ingress scoped to the relevant SG rather than open CIDRs (except the ALB's public `:80`). |
| Compute | [ec2.tf](ec2.tf), [launch-template.tf](launch-template.tf) | ALB + target group + listener, Auto Scaling Group (private subnets, min 1 / max 3), CPU target-tracking scaling policy (80%), a bastion instance in the public subnet, and the launch template that boots each instance. |
| Storage | [ec2.tf](ec2.tf) | EFS filesystem mounted at `/var/www/html` on every instance, shared across the fleet. |
| Database | [rds.tf](rds.tf) | RDS instance restored from the most recent `clixx-recent-snapshot`. |
| DNS | [route53.tf](route53.tf) | `clixx.example.com` CNAME to the ALB, created in a separate AWS account via an assumed role. |
| Data sources | [data.tf](data.tf) | Pulls the custom AMI, DB password, org name, role name, git repo URL, and instance profile ARN from SSM Parameter Store; looks up running ASG instances. |
| Bootstrap | [scripts/user-data.sh](scripts/user-data.sh) | Runs on every instance boot — see below. |

## Instance bootstrap (`scripts/user-data.sh`)

Runs once per instance launch, logs to `/var/log/user-data.log`, and is idempotent (safe to re-run / re-launch without breaking existing state):

1. Mounts EFS at `/var/www/html` (region discovered via IMDSv2).
2. Clones the CliXX repo (`GIT_REPO`, branch `latest`) into EFS — only on the first boot; later instances just find the files already there.
3. Generates `wp-config.php` from the sample and injects DB host/name/user/password.
4. Installs WP-CLI if missing.
5. Reconciles WordPress's `siteurl`/`home` options with the ALB's DNS name (via both raw SQL and `wp option update`, so caches are flushed).
6. Installs `wp-force-login` so anonymous visitors are redirected to `/wp-login.php` — this is why the target group's health-check matcher includes `301`.
7. Seeds a couple of default contributor users via `wp user create`.
8. Restarts `httpd`.

The EBS/LVM disk-partitioning step from earlier versions of this script is currently commented out — the launch template no longer attaches extra data disks, relying solely on the AMI's native block configuration (see `docs/v1.4-jenkins-cicd-pipeline.md` for why).

## Prerequisites

Provisioned outside this stack, and expected to already exist:

- An IAM role Terraform assumes to deploy (`ROLE_NAME`, read from SSM `/stack/role`).
- A custom AMI matching `ami-stack-*` owned by `var.ami_owner_account_id`, built by the separate image pipeline (installs baked in ahead of boot).
- An IAM instance profile (SSM `/stack/instanceProfile`) granting the instances permission to read SSM parameters, mount EFS, and reach RDS.
- A DB snapshot named `clixx-recent-snapshot` in the target account/region.
- SSM parameters: `/stack/orgname`, `/stack/role`, `/stack/clixx/repo`, `/stack/instanceProfile`, `/stack/clixx/db_password` (SecureString).
- An S3 bucket for remote state (`enoch-tf-state-bucket`, see [versions.tf](versions.tf)).
- A Route 53 hosted zone (`example.com`) in the account reachable via the `domain_account` provider alias.
- An EC2 key pair named `dev-servers` for bastion/instance SSH access.

## Deploying

### Via Jenkins (primary path)

The [Jenkinsfile](Jenkinsfile) runs against the `stack-aut-Clixx` directory:

1. **AI Source Code Audit** (apply only) — Claude Code scans for hardcoded secrets and fixes minor `.tf` syntax issues; stops if secrets are found.
2. **Terraform Init** — `terraform init -upgrade`, Slack notification.
3. **Terraform Plan** — `terraform plan -out=tfplan` (`-destroy` when tearing down).
4. **Terraform Apply** — applies the plan, posts the live `clixx_url` output to Slack.
5. **Terraform Destroy** — `terraform destroy -auto-approve`, Slack notification.

Trigger the job with the `ACTION` parameter set to `apply` or `destroy`.

### Manually

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Outputs

| Output | Description |
|---|---|
| `clixx_url` | Public URL for the site (`http://clixx.example.com`). |
| `bastion_ip` | Public IP of the bastion host, for SSH access into the private subnets. |
| `clixx_priv_ips` | Private IPs of the running ASG instances. |

## Known caveats

- `skip_final_snapshot = true` on the RDS instance means a `terraform destroy` (or any RDS-forcing change) throws away the live database without a final snapshot — fine since the source snapshot is the durable copy, but any writes since the last restore are lost.
- EBS volumes are `encrypted = false` and the DB password SSM parameter caveat noted in `data.tf` — tighten both before this carries anything beyond dev data.
- `force_delete = true` on the ASG is convenient for iterating in dev but should not be carried into a production stack as-is.
