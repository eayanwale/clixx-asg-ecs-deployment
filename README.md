# stack-aut-Clixx

Terraform stack that provisions the full AWS runtime for **CliXX Retail**, a WordPress application. It runs **two parallel deployment paths** side by side in the same VPC — a classic Auto Scaling Group of EC2 instances, and an ECS cluster on EC2 capacity — each behind its own ALB and backed by its own RDS database restored from a shared snapshot. A Jenkins pipeline (`Jenkinsfile`) drives `init`/`plan`/`apply`/`destroy`, runs an AI source-code audit step, and posts status to Slack.

See **[docs/asg-stack.md](docs/asg-stack.md)** and **[docs/ecs-stack.md](docs/ecs-stack.md)** for the full architecture, resources, and caveats of each stack. This README covers what's shared between them plus how to deploy.

---

## Architecture

```
                                    Internet
                                        │
                    ┌───────────────────┴───────────────────┐
                    ▼                                       ▼
        tf-lb (ASG stack ALB, :443)              ecs-lb (ECS stack ALB, :443)
        asg.clixx.example.com                ecs.clixx.example.com
                    │                                       │
              Target Group tf-tg                      Target Group ecs-tg
                    │                                       │
             ASG tf-asg (1-2)                        ECS Service on ecs-asg (1-2)
          EC2, custom AMI, EFS-backed              EC2 (ECS-optimized AMI), bridge mode,
                    │                               container from ECR, dynamic host ports
                    ▼                                       ▼
        RDS clixx-restored                    RDS clixx-restored-ecs
     (restored from clixx-working-snapshot)  (restored from the same snapshot, separate instance)

  Bastion host (public subnet) ── SSH access into the private network, shared by both stacks
```

Both stacks share the same VPC/networking (`vpc.tf`), security groups (`security.tf`), bastion host, and source DB snapshot — everything downstream of the ALB is independent per stack. See the sub-docs for the full resource breakdown of each.

## Shared foundation

| Area | File | Notes |
|---|---|---|
| Networking | [vpc.tf](vpc.tf) | VPC (`10.1.0.0/16`), 2 public + 2 private subnets across 2 AZs, IGW, NAT gateway, route tables, S3 gateway endpoint. |
| Security groups | [security.tf](security.tf) | `clixx-sg` (app instances, both stacks), `alb-sg` (shared by both ALBs), bastion SG, EFS SG, DB SG — least-privilege ingress scoped to the relevant SG rather than open CIDRs (except the ALBs' public `:80`/`:443`). |
| Bastion | [ec2.tf](ec2.tf) | Public-subnet EC2 instance for SSH access into the private subnets — the quickest place to run one-off `wp-cli` commands against either stack's DB. |
| Data sources | [data.tf](data.tf) | SSM parameters (DB password, org name, role name, git repo URL, instance profile ARN), the ASG/ECS AMIs, the ECR repo (cross-account), and the Route 53 zone. |

## Deploying

### Via Jenkins (primary path)

The [Jenkinsfile](Jenkinsfile) runs against this directory:

1. **AI Source Code Audit** (apply only) — an unattended Claude Code agent scans for hardcoded secrets and fixes minor `.tf` syntax issues, then commits/tags/opens a PR if it changed anything; stops without proceeding if secrets are found. See **[docs/ci-cd-pipeline.md](docs/ci-cd-pipeline.md)** for the full stage-by-stage breakdown — this stage has real teeth (it can push branches and open PRs on its own) and is worth understanding before relying on it.
2. **Terraform Init** — `terraform init -upgrade`, Slack notification.
3. **Terraform Plan** — `terraform plan -out=tfplan` (`-destroy` when tearing down).
4. **Terraform Apply** — applies the plan, posts the live `clixx_asg_url`/`clixx_ecs_url` outputs to Slack.
5. **Terraform Destroy** — `terraform destroy -auto-approve`.

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
| `clixx_asg_url` | Public URL for the ASG stack (`https://asg.clixx.example.com`). |
| `clixx_ecs_url` | Public URL for the ECS stack (`https://ecs.clixx.example.com`). |
| `bastion_ip` | Public IP of the bastion host. |
| `clixx_priv_ips` | Private IPs of the running ASG instances. |
| `clixx_ecs_priv_ips` | Private IPs of the running ECS container instances. |

## Prerequisites

Provisioned outside this stack, and expected to already exist:

- An IAM role Terraform assumes to deploy (`ROLE_NAME`, read from SSM `/stack/role`).
- Two custom AMIs: `ami-stack-*` (ASG stack, built by the [packer](../packer) pipeline) and `ami-ecs-stack-*` (ECS stack, built by the `ECS-AMI-BUILD` pipeline) — both owned by `var.ami_owner_account_id`.
- The `clixx-repository` ECR repo populated with the app image, in the account behind the `aws.ecs-repo-account` provider alias.
- A DB snapshot named `clixx-working-snapshot` in the target account/region — both stacks restore their own independent RDS instance from it.
- An IAM instance profile (SSM `/stack/instanceProfile`) granting the ASG instances permission to read SSM parameters, mount EFS, and reach RDS.
- SSM parameters: `/stack/orgname`, `/stack/role`, `/stack/clixx/repo`, `/stack/instanceProfile`, `/stack/clixx/db_password` (SecureString).
- An S3 bucket for remote state (`enoch-tf-state-bucket`, see [versions.tf](versions.tf)).
- A Route 53 hosted zone (`clixx.example.com`).
- An ACM certificate covering `*.clixx.example.com` in `us-east-1`, shared by both ALBs' HTTPS listeners.
- An EC2 key pair (`var.key_name`, default `dev-servers`) for bastion/instance SSH access.

## Known caveats

- `skip_final_snapshot = true` on both RDS instances means a `terraform destroy` throws away the live databases without a final snapshot — fine since the source snapshot is the durable copy, but any writes since the last restore are lost.
- EBS volumes are `encrypted = false` — tighten before this carries anything beyond dev data.
- `force_delete = true` on both ASGs and the ECS service is convenient for iterating in dev but should not be carried into a production stack as-is.
- See [docs/asg-stack.md](docs/asg-stack.md#known-caveats) and [docs/ecs-stack.md](docs/ecs-stack.md#known-caveats) for stack-specific caveats.

## Further reading

- [docs/asg-stack.md](docs/asg-stack.md) — ASG/EC2 stack deep dive.
- [docs/ecs-stack.md](docs/ecs-stack.md) — ECS stack deep dive.
- [docs/ci-cd-pipeline.md](docs/ci-cd-pipeline.md) — Jenkins pipeline deep dive, including the AI Source Code Audit stage's secret-scan/syntax-fix/auto-PR flow.
- [docs/stack-Clixx.md](docs/stack-Clixx.md) — original design writeup (partially historical, predates the ECS stack).
- [docs/architecture.png](docs/architecture.png) — original architecture diagram (ASG stack only).
- `docs/v1.x-*.md` — version history tracking how the stack evolved.
