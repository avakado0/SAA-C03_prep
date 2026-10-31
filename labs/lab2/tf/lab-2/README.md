# AWS SAA-C03 Lab 2: Public EC2 + FastAPI

This project recreates the **architecture** of the original hands-on Lab 2 using Terraform.

The goal is not production deployment. The goal is to make the AWS networking model reproducible and visible.

The core chain is:

**VPC -> Public Subnet -> Route Table -> Internet Gateway -> Public IPv4 -> Security Group -> EC2 -> FastAPI**

---

## 1. Target architecture

```text
                         INTERNET
                            |
                            | TCP/80
                            v
                  +---------------------+
                  |   Internet Gateway   |
                  +----------+----------+
                             |
                  +----------v----------+
                  |        VPC          |
                  |    10.20.0.0/16     |
                  |                     |
                  |  Public Subnet      |
                  |   10.20.1.0/24      |
                  |                     |
                  |   +-------------+   |
                  |   |     EC2     |   |
                  |   |             |   |
                  |   |  FastAPI    |   |
                  |   |    :80      |   |
                  |   +-------------+   |
                  |         |           |
                  |   Security Group    |
                  |   TCP/80  <- world  |
                  |   TCP/22  <- your IP|
                  +---------------------+
```

---

## 2. What makes the EC2 public?

There is no single switch called "make EC2 public."

Several independent pieces cooperate.

### Piece 1: VPC

The EC2 needs to exist inside a VPC.

This lab uses:

```text
10.20.0.0/16
```

The VPC is the network boundary.

It does not automatically provide Internet access.

### Piece 2: Subnet

The EC2 lives in:

```text
10.20.1.0/24
```

A subnet is an IP address range inside the VPC.

The word `public` is a description of its routing, not a special subnet type.

### Piece 3: Route table

The subnet uses a route table containing:

```text
Destination       Target
-----------       ------
10.20.0.0/16      local
0.0.0.0/0         Internet Gateway
```

The important route is:

```text
0.0.0.0/0 -> IGW
```

This is what makes the subnet a public subnet.

### Piece 4: Internet Gateway

The Internet Gateway is attached to the VPC.

It provides the VPC's connection point to the Internet.

Important:

> An Internet Gateway does not, by itself, make an EC2 public.

### Piece 5: Public IPv4

The EC2 receives a public IPv4 address.

Conceptually:

```text
Internet
   |
public IPv4
   |
AWS edge / IGW
   |
private VPC IP
   |
EC2 ENI
```

The instance still has a private IPv4 address.

### Piece 6: Security Group

The Security Group permits:

```text
TCP/80 from 0.0.0.0/0
```

Therefore Internet clients are allowed to initiate HTTP connections.

SSH is deliberately restricted:

```text
TCP/22 from YOUR_IP/32
```

### Piece 7: Application

Finally, something must actually listen on port 80.

This lab runs:

```text
Uvicorn
  |
  +-- FastAPI
  |
  +-- 0.0.0.0:80
```

---

# 3. Complete packet path

A request from your computer to the application looks conceptually like:

```text
Your computer
     |
     | TCP destination port 80
     v
Internet
     |
     v
Public IPv4 address
     |
     v
Internet Gateway
     |
     v
Public subnet
     |
     v
Route table
     |
     | 0.0.0.0/0 -> IGW
     v
EC2 ENI
     |
     v
Security Group
     |
     | TCP/80 allowed
     v
Uvicorn
     |
     v
FastAPI
     |
     v
HTTP 200
```

A successful `curl` therefore gives you evidence that many layers are working.

---

# 4. Security Group versus application

These are two different layers.

The Security Group answers:

> "May TCP traffic on port 80 reach this network interface?"

FastAPI answers:

> "Is there an application listening on port 80?"

For example:

```text
Security Group allows :80
          |
          v
EC2 receives connection
          |
          v
FastAPI listening?
       /       \
     YES        NO
      |          |
   HTTP 200    connection
               failure/refusal
```

This distinction was important in the original manual Lab 2.

A Security Group rule does not magically create a web server.

---

# 5. Why the application binds to 0.0.0.0

The service is started as:

```text
uvicorn app:app --host 0.0.0.0 --port 80
```

`0.0.0.0` means the application listens on the instance's available interfaces rather than only localhost.

Compare:

```text
127.0.0.1:80
```

with:

```text
0.0.0.0:80
```

The first is local-only.

The second allows traffic arriving through the EC2 network interface to reach the application.

---

# 6. Why there is no NAT Gateway

NAT Gateway is not needed here.

This is a **public EC2**:

```text
EC2
 |
 | public IPv4
 v
Internet Gateway
 |
 v
Internet
```

A typical private EC2 outbound architecture is different:

```text
Private EC2
 |
 v
NAT Gateway
 |
 v
Internet Gateway
 |
 v
Internet
```

That is a later lab.

---

# 7. Why there is no Load Balancer

The target architecture is deliberately:

```text
Internet -> EC2
```

A load balancer would introduce another layer:

```text
Internet
   |
   v
ALB
   |
   v
EC2
```

That is useful for learning ALB/target groups later, but it would obscure the basic public-EC2 networking model.

---

# 8. Why Terraform creates a new VPC

The original manual lab reused the default VPC.

This version deliberately creates its own VPC so that:

```text
terraform apply
```

creates the complete lab and:

```text
terraform destroy
```

removes the complete lab.

That avoids depending on:

- the default VPC
- previously created Security Groups
- previously created subnets
- previous route tables
- previous EC2 instances

The lab is therefore reproducible.

---

# 9. Prerequisites

Install:

- Terraform
- AWS CLI

Your AWS credentials must have permission to create the required EC2/VPC resources.

Check AWS authentication:

```bash
aws sts get-caller-identity
```

Check Terraform:

```bash
terraform version
```

---

# 10. Configure the variables

Copy:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit:

```bash
vim terraform.tfvars
```

Set your public IP:

```hcl
ssh_allowed_cidr = "YOUR.PUBLIC.IP/32"
```

The `/32` means exactly one IPv4 address.

If you want SSH access, also provide an existing EC2 key pair:

```hcl
key_name = "your-key-pair-name"
```

The key pair must already exist in the selected AWS region.

---

# 11. Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider and initializes the Terraform working directory.

---

# 12. Format and validate

Run:

```bash
terraform fmt
```

Then:

```bash
terraform validate
```

Expected:

```text
Success! The configuration is valid.
```

---

# 13. Inspect the plan

Run:

```bash
terraform plan
```

The important resources should include:

```text
VPC
Internet Gateway
Public Subnet
Route Table
Route Table Association
Security Group
EC2 Instance
```

This is a useful SAA habit:

> Before asking "what AWS service should I use?", identify the network layers that must exist.

---

# 14. Create the architecture

```bash
terraform apply
```

Review the plan.

Then enter:

```text
yes
```

Terraform creates the complete architecture.

---

# 15. Get the outputs

Run:

```bash
terraform output
```

Or retrieve individual values:

```bash
terraform output -raw public_ip
```

```bash
terraform output -raw private_ip
```

```bash
terraform output -raw fastapi_url
```

---

# 16. Test the application

Run:

```bash
curl "$(terraform output -raw fastapi_url)"
```

Expected:

```json
{"message":"Hello from Lab 2 EC2!","lab":"AWS SAA Lab 2","status":"public"}
```

You can also use:

```bash
curl -v "$(terraform output -raw fastapi_url)"
```

The verbose version lets you see the TCP connection and HTTP exchange.

---

# 17. What a successful HTTP response proves

A successful HTTP response means the request made it through several layers:

```text
Internet
   |
   v
Public IP
   |
   v
IGW
   |
   v
Route table
   |
   v
Subnet
   |
   v
EC2 ENI
   |
   v
Security Group
   |
   v
TCP/80
   |
   v
Uvicorn
   |
   v
FastAPI
```

It does not merely prove that "the EC2 is running."

---

# 18. Optional SSH

If `key_name` was supplied:

```bash
ssh -i ~/.ssh/YOUR_KEY.pem \
  ec2-user@$(terraform output -raw public_ip)
```

For Amazon Linux, the normal default user is:

```text
ec2-user
```

---

# 19. Inspect the AWS architecture

Get the VPC:

```bash
aws ec2 describe-vpcs \
  --vpc-ids "$(terraform output -raw vpc_id)"
```

Get the subnet:

```bash
aws ec2 describe-subnets \
  --subnet-ids "$(terraform output -raw public_subnet_id)"
```

Get the route table:

```bash
aws ec2 describe-route-tables \
  --route-table-ids "$(terraform output -raw route_table_id)"
```

Get the Security Group:

```bash
aws ec2 describe-security-groups \
  --group-ids "$(terraform output -raw security_group_id)"
```

Get the EC2:

```bash
aws ec2 describe-instances \
  --instance-ids "$(terraform output -raw instance_id)"
```

The point is to connect the Terraform abstraction with the actual AWS objects.

---

# 20. Useful SAA mental checklist

When you encounter:

> "An EC2 instance needs to be accessible from the Internet."

Walk through:

```text
[1] VPC
      |
[2] Subnet
      |
[3] Route table
      |
      +-- 0.0.0.0/0 -> IGW
      |
[4] Internet Gateway
      |
[5] Public IPv4
      |
[6] Security Group
      |
      +-- TCP/80 allowed
      |
[7] Application
      |
      +-- listening on :80
```

The key distinction:

```text
Public subnet
      !=
Public EC2
```

The public subnet gives you the routing environment.

The public IPv4 address gives the instance direct Internet-facing addressing.

The Security Group determines whether traffic is permitted.

The application must actually be listening.

---

# 21. Resource relationships

Terraform is also teaching you dependency relationships.

Conceptually:

```text
VPC
 |
 +----------------------+
 |                      |
 v                      v
Subnet             Internet Gateway
 |                      |
 |                      |
 v                      |
Route Table -------------+
 |
 v
Route Association
 |
 v
EC2
 |
 v
ENI
 |
 v
Security Group
 |
 v
FastAPI
```

The Security Group is attached to the EC2's network interface, while the subnet and route table provide the network path.

---

# 22. Cleanup

When the exercise is finished:

```bash
terraform destroy
```

Confirm:

```text
yes
```

Terraform should remove the resources belonging to this lab.

This is one of the major advantages of recreating the exercise with Terraform:

```text
terraform apply
      |
      v
complete lab
      |
      v
experiment
      |
      v
terraform destroy
      |
      v
clean AWS account
```

---

# 23. Final SAA takeaway

The public EC2 architecture is not:

```text
EC2 + Internet Gateway = public
```

It is closer to:

```text
             PUBLIC EC2
                 |
       +---------+---------+
       |                   |
   Addressing           Routing
       |                   |
  Public IPv4          Public subnet
                           |
                     0.0.0.0/0
                           |
                          IGW
       |
       +-------------------+
       |
    Security
       |
   SG allows :80
       |
    Application
       |
  FastAPI :80
```

The one-line memory hook:

> **Public subnet = route to IGW. Public EC2 = public IPv4 + usable route + permitted traffic + listening service.**

---

## 24. Cleanup checklist

Before considering Lab 2 finished:

```text
[ ] EC2 terminated
[ ] Security Group removed
[ ] Route table removed
[ ] Route association removed
[ ] Public subnet removed
[ ] Internet Gateway detached/removed
[ ] VPC removed
```

Or simply:

```bash
terraform destroy
```

and let Terraform manage the dependency order.
