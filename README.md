# AWS Security Monitoring Lab

A production-aligned cloud security monitoring environment built with Terraform to demonstrate skills relevant to SOC analyst and cloud security engineer roles.

> **Built using an AI-assisted workflow** — architecture reviewed, security decisions validated, and every resource verified independently before deployment. This reflects modern cloud engineering practice.

---

## Skills Demonstrated

- **AWS CloudTrail** — Multi-region audit logging with hardened S3 destination
- **Amazon GuardDuty** — Threat detection with S3 protection, sample findings generated
- **AWS Security Hub CSPM** — CIS AWS Foundations Benchmark v1.4 and FSBP v1.0 enabled
- **Amazon VPC** — Public/private subnet architecture with Internet Gateway
- **EC2** — Amazon Linux 2023, SSM-only access, no key pair, IMDSv2 enforced
- **IAM** — Least privilege role design, inline and managed policies
- **S3** — Bucket policy hardening, confused deputy prevention, log integrity controls
- **Terraform** — Full infrastructure as code across six deployment phases
- **SSM Session Manager** — Keyless EC2 access with full CloudTrail audit trail
- **Defense in Depth** — Layered controls across network, identity, and data layers

---

## Architecture

```
Internet
    |
Internet Gateway
    |
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24)
│   └── EC2 t2.micro (AL2023, SSM only, no key pair)
│       └── IAM Role: SSM + S3 read-only on CT bucket
│       └── Security Group: 0 inbound rules, 443 outbound only
└── Private Subnet (10.0.2.0/24)
    └── Isolated - no outbound route, no NAT Gateway

Security Services (us-east-2)
├── CloudTrail → S3 (encrypted, versioned, deletion-protected)
├── GuardDuty → S3 protection enabled, 15-min publishing
└── Security Hub CSPM → CIS v1.4 + FSBP v1.0, GuardDuty integrated

S3 Buckets
├── security-monitoring-lab-cloudtrail-[ACCOUNT-ID]
│   ├── SSE-S3 encryption
│   ├── Versioning enabled
│   ├── Bucket policy: aws:SourceArn scoped to lab-audit-trail
│   ├── DenyNonTLS statement
│   └── DenyObjectDeletion on AWSLogs/ prefix
└── security-monitoring-lab-app-[ACCOUNT-ID]
    ├── SSE-S3 encryption
    ├── Versioning enabled
    ├── Server access logging to logs/ prefix
    ├── DenyNonTLS statement
    └── S3LogDeliveryWrite scoped with aws:SourceAccount
```

---

## Build Order and Phases

The environment was built in a deliberate sequence — logging infrastructure first to capture all subsequent API activity.

| Phase | Resources | Key Security Decision |
|-------|-----------|----------------------|
| 1 | CloudTrail S3 bucket | Bucket policy scoped to specific trail ARN via aws:SourceArn |
| 2 | VPC, subnets, IGW, route tables | Private subnet with empty route table, no NAT Gateway |
| 3 | Security group, IAM role/profile | Zero inbound rules, least privilege inline S3 policy |
| 4 | EC2 instance | No key pair, SSM only, IMDSv2 enforced by AL2023 |
| 5 | Application S3 bucket | HTTPS-only, access logging, no force_destroy |
| 6 | GuardDuty, Security Hub CSPM | Explicit Terraform-managed product subscription |

---

## Key Security Decisions

### Why SSM Session Manager Instead of SSH
Zero inbound ports. The security group has no inbound rules — there is no exposed attack surface. SSM sessions are automatically logged to CloudTrail, creating a full audit trail of every command run on the instance. No key pair means no private key to protect, rotate, or accidentally expose.

### Why aws:SourceArn on the CloudTrail Bucket Policy
Without this condition, any CloudTrail principal in any AWS account could write to a bucket that allows the CloudTrail service principal — a confused deputy vulnerability. The `aws:SourceArn` condition pins the write permission to the specific trail ARN in this specific account only.

### Why No NAT Gateway
The private subnet contains no workloads requiring outbound internet access. A NAT Gateway costs approximately $32/month idle plus data transfer charges for zero security value on an empty subnet. The correct engineering decision is to add it when a specific requirement demands it, not by default.

### Why force_destroy = false on the Application Bucket
The CloudTrail bucket has `force_destroy = true` to allow clean teardown during lab exercises. The application bucket has `force_destroy = false` to mirror production behavior — in production, a bucket containing application data should never be silently deleted by a Terraform operation.

### Why enable_default_standards = false in Security Hub
AWS auto-enables FSBP when Security Hub is activated. Without this flag, Terraform attempts to create the same standard subscription and throws a conflict error. Setting it to false gives Terraform full control over which standards are enabled, preventing state drift.

### Why the Private Route Table Is Empty
The private route table intentionally has no outbound route beyond the implicit local route. This is not a misconfiguration — it is a deliberate isolation decision. Any resource accidentally launched in the private subnet has no outbound internet path, reducing attack surface. The local route covers intra-VPC communication.

---

## Findings Generated

### GuardDuty Sample Findings
Three finding types were generated and verified in the console:

| Finding Type | Severity | Description |
|---|---|---|
| UnauthorizedAccess:EC2/SSHBruteForce | Low | SSH brute force activity detected against the instance |
| Recon:EC2/PortProbeUnprotectedPort | Low | Unprotected port on EC2 instance being probed |
| Trojan:EC2/BlackholeTraffic | Medium | EC2 instance communicating with a blackholed IP address |

### Security Hub CSPM Findings
- **1 Critical** — AWS Config not enabled (accepted known risk, documented below)
- **12 Low** — CIS and FSBP control evaluations

### CloudTrail
18 compressed `.json.gz` log files confirmed in the S3 bucket, capturing all API activity from account creation through lab deployment.

---

## Lab vs. Production Notes

These are deliberate differences made for cost and scope reasons, documented explicitly:

| Setting | Lab | Production Standard |
|---|---|---|
| GuardDuty publishing frequency | 15 minutes | 6 hours (reduces API volume at scale) |
| NAT Gateway | Absent | Present when private subnet workloads require outbound |
| AWS Config | Disabled | Required for full Security Hub scoring and compliance |
| EC2 detailed monitoring | Disabled | Standard — 1-min resolution for production workloads |
| Availability zones | Single | Minimum two for any production workload |
| VPC Flow Logs | Absent | Standard — required for network-level investigation |

**On the Critical Security Hub finding:** AWS Config not being enabled generates a Critical finding in Security Hub. This is an accepted known risk in this lab. Config per-configuration-item charges are unnecessary for demonstrating the core security monitoring concepts targeted here. In production, Config would be the first service enabled before Security Hub and before any other compliance evaluation begins.

---

## IMDSv2 Note

Amazon Linux 2023 enforces IMDSv2 by default. During SSM session validation, a simple `curl http://169.254.169.254/latest/meta-data/instance-id` returned empty because IMDSv1 is disabled. The correct two-step token-based request was required:

```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") && \
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

This is the expected behavior — IMDSv2 prevents SSRF-based IAM credential theft that is possible with IMDSv1.

---

## Security Hub Console Note

During deployment, AWS had launched a redesigned Security Hub interface that renamed the original service to **Security Hub CSPM**. The Terraform resource successfully enabled the service via API, which was confirmed using `aws securityhub describe-hub --region us-east-2` before navigating the console. This illustrates that CLI verification is more reliable than console UI state during service transitions — a real-world scenario cloud engineers encounter.

---

## Repository Structure

```
security-monitoring-lab/
├── providers.tf          # Terraform + AWS provider pinning (~> 5.0)
├── variables.tf          # Input variables with defaults
├── terraform.tfvars      # Lab-specific values
├── main.tf               # CloudTrail S3 bucket and policy
├── vpc.tf                # VPC, subnets, IGW, route tables
├── security_groups.tf    # EC2 security group (zero inbound)
├── iam.tf                # EC2 IAM role, profile, policies
├── ec2.tf                # EC2 instance (dynamic AMI via SSM)
├── app_bucket.tf         # Application S3 bucket
├── security_services.tf  # GuardDuty, Security Hub, standards
├── outputs.tf            # Bucket names, ARNs, instance IDs
└── screenshots/
    ├── guardduty-findings-list.png
    ├── guardduty-finding-detail.png
    ├── securityhub-summary.png
    ├── securityhub-standards.png
    ├── securityhub-critical-finding.png
    ├── s3-cloudtrail-bucket-policy.png
    ├── s3-cloudtrail-versioning.png
    ├── s3-app-bucket-permissions.png
    ├── vpc-route-tables.png
    ├── ec2-instance-details.png
    ├── ssm-session-terminal.png
    └── cloudtrail-logs-s3.png
```

---

## Tools and Services

| Tool/Service | Purpose |
|---|---|
| Terraform v1.14.8 | Infrastructure as code |
| AWS CLI v2.34.29 | Account configuration and CLI commands |
| AWS SSM Session Manager Plugin | Keyless EC2 terminal access |
| Amazon GuardDuty | Threat detection |
| AWS Security Hub CSPM | Compliance posture management |
| AWS CloudTrail | API audit logging |
| Amazon S3 | Log storage with integrity controls |
| Amazon VPC | Network isolation |
| AWS IAM | Identity and access management |
| Amazon EC2 | Compute — Amazon Linux 2023 |

---

*Account IDs, public IPs, and other identifying values have been redacted from all documentation per security best practices.*
