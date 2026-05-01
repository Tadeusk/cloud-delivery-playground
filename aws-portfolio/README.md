# ☁️ AWS Architecture: Scalable & Secure Infrastructure as Code

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4.svg?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900.svg?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

## 🎯 Project Purpose
This project implements a secure, isolated cloud environment designed according to the **AWS Well-Architected Framework**. By transitioning from manual console management to full automation with **Terraform**, this repository ensures repeatability, version control, and the elimination of configuration drift.

> **Status:** Active Development (Parallel to AWS Solutions Architect Associate Certification).

---

## 🏗️ System Architecture
The infrastructure is designed with a focus on **High Availability** and **Security by Design**.

### Core Components:
*   **Networking:** Custom VPC (`10.0.0.0/16`) featuring public and private subnet segmentation in the `eu-west-1a` availability zone.
*   **Compute:** Cost-optimized EC2 instances (t2.micro) protected by dedicated, tiered Security Groups.
*   **Storage:** Amazon S3 implementation utilizing a global unique naming convention and environment tagging.
*   **Security & Identity:** 
    *   **IAM Roles & Groups:** Implementation of the "Least Privilege" principle for developer access.
    *   **Network Security:** Fine-grained Security Group rules (TCP/22 restricted ingress).
*   **Governance:** Multi-account structure readiness via **AWS Organizations** (Management, Dev, and Prod OUs).

---

## 🛠️ Tech Stack
*   **Infrastructure:** Terraform (HCL)
*   **Cloud Provider:** Amazon Web Services (AWS)
*   **Versioning & Tooling:** Git, AWS CLI

---

## 🚀 Quick Start

### Prerequisites
- Configured AWS CLI with appropriate IAM permissions.
- Terraform v1.5+ installed.

### Deployment Steps
```bash
# 1. Clone the repository
git clone [https://github.com/Tadeusk/cloud-delivery-playground.git](https://github.com/Tadeusk/cloud-delivery-playground.git)

# 2. Initialize Terraform providers and modules
terraform init

# 3. Preview the infrastructure changes
terraform plan

# 4. Deploy the infrastructure
terraform apply