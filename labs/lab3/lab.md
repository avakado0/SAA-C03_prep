# AWS SAA-C03 Lab 3 — Private EC2 → Internet via NAT Gateway

## Lab Goal

Understand how a **private EC2 instance can initiate outbound Internet connections without being directly reachable from the Internet**.

The central concept of this lab was:

> **Inbound return traffic is not the same thing as an Internet host initiating a new inbound connection.**

A private EC2 can:

* initiate a connection to the Internet
* receive the response to that connection
* download packages
* call public APIs

while an arbitrary Internet host cannot directly initiate a new connection to that EC2.

The mechanism used for this was a **public NAT Gateway**.

---

# 1. Intended Architecture

The architecture we reasoned out before building was:

```text
                         INTERNET
                            ▲
                            │
                     Internet Gateway
                            ▲
                            │
                     Public Subnet
                            │
                       NAT Gateway
                            ▲
                            │
                    Private Subnet
                            │
                       Private EC2
```

More precisely:

```text
Private EC2
    │
    │ 0.0.0.0/0
    ▼
Private Route Table
    │
    │ → NAT Gateway
    ▼
NAT Gateway
    │
    ▼
Public Subnet Route Table
    │
    │ 0.0.0.0/0 → IGW
    ▼
Internet Gateway
    │
    ▼
Internet
```

---

# 2. The Key Reasoning Before Building

We established an important distinction:

### "Private EC2 cannot be reached from the Internet"

does **not** mean:

> "The private EC2 can never receive packets originating from the Internet."

Instead, the important distinction is **who initiated the connection**.

### Private EC2 initiates

```text
Private EC2
    │
    │ SYN
    ▼
Internet
    │
    │ SYN/ACK
    ▼
Private EC2
```

The returning packets are allowed because they belong to the connection initiated by the private EC2.

### Internet host initiates

```text
Internet
    │
    │ SYN
    ▼
Private EC2
```

This is a new unsolicited inbound connection and is not what the NAT architecture allows.

This distinction resolved the apparent contradiction between:

> "The private EC2 cannot be reached from the Internet"

and:

> "The private EC2 can download something from the Internet."

---

# 3. VPC Resources Used

Existing VPC:

```text
VPC ID: vpc-0example1
Region: eu-north-1
```

We reused the existing VPC rather than creating another one.

---

# 4. Private Subnet

Created:

```text
Name: saa-lab-3-private
Subnet ID: subnet-0example2
CIDR: 172.31.48.0/20
AZ: eu-north-1a
```

Purpose:

> Private subnet for Lab 3 NAT Gateway experiment.

This subnet was explicitly associated with the dedicated private route table.

---

# 5. Private Route Table

Created:

```text
Name: saa-lab-3-private-rt
```

Description:

> Route table for private subnet; sends Internet-bound traffic through NAT Gateway.

Routes:

```text
Destination       Target
----------------  ----------------
172.31.0.0/16     local
0.0.0.0/0         NAT Gateway
```

The important route is:

```text
0.0.0.0/0 → NAT Gateway
```

This means:

> Traffic destined outside the VPC should be sent to the NAT Gateway.

Subnet association:

```text
saa-lab-3-private
172.31.48.0/20
```

---

# 6. NAT Gateway

Created:

```text
Name: saa-lab-3-nat
NAT Gateway ID: nat-058ae4272eff2dae8
Connectivity type: Public
Availability mode: Zonal
Subnet: subnet-0example3
Primary public IPv4: <public-ip>
Primary private IPv4: 172.31.3.208
State: Available
```

The NAT Gateway was placed in an existing **public subnet**.

The public subnet already had the necessary Internet route through the Internet Gateway.

Conceptually:

```text
Public Subnet Route Table

Destination       Target
----------------  ----------------
172.31.0.0/16     local
0.0.0.0/0         Internet Gateway
```

Therefore:

```text
NAT Gateway
    │
    ▼
Public subnet
    │
    ▼
0.0.0.0/0 → IGW
    │
    ▼
Internet
```

---

# 7. Security Groups

## Public Bastion SG

Created:

```text
Name: saa-lab-3-public
ID: sg-0example4
```

Description:

> Security group for public bastion EC2 used to access the private instance.

### Inbound

```text
SSH
TCP
22
Source: <public-ip>/32
```

Description:

> Allow SSH from my workstation to the Lab 3 public bastion.

### Outbound

```text
All traffic
0.0.0.0/0
```

Description:

> Allow bastion outbound traffic to private VPC resources and the Internet.

---

## Private EC2 SG

Created:

```text
Name: saa-lab-3-private
ID: sg-0example5
```

Description:

> Security group for private EC2 used to test NAT Gateway outbound Internet access.

### Inbound

```text
SSH
TCP
22
Source: saa-lab-3-public
```

Description:

> Allow SSH from the Lab 3 public bastion.

Important:

We did **not** allow:

```text
0.0.0.0/0
```

for SSH.

The private instance only accepts SSH from the bastion's security group.

### Outbound

```text
All traffic
0.0.0.0/0
```

Description:

> Allow private EC2 outbound connections through the NAT Gateway.

---

# 8. Public Bastion EC2

Created:

```text
Name: saa-lab-3-public
Instance type: t3.micro
AZ: eu-north-1a
Public IPv4: <public-ip>
Private IPv4: 172.31.28.165
```

Description:

> Public bastion for accessing the private EC2 during SAA Lab 3.

It existed primarily so that we could enter the private EC2 and test its outbound Internet connectivity.

---

# 9. First Private EC2 Attempt: Failure

The first private instance was accidentally launched in the wrong subnet.

Instance:

```text
Name: saa-lab-3-private
Private IP: 172.31.16.35
```

But the instance was actually in:

```text
Subnet: subnet-0example1
CIDR: 172.31.16.0/20
```

while our intended private subnet was:

```text
saa-lab-3-private
subnet-0example2
172.31.48.0/20
```

This caused the NAT test to fail.

We ran:

```bash
curl -v --connect-timeout 5 -m 10 https://example.com
```

The result showed:

```text
IPv6: Network is unreachable
```

and more importantly:

```text
IPv4 connection timed out
```

The NAT Gateway itself was not the problem.

This was a useful lesson:

> An EC2 instance must actually be attached to the subnet whose route table contains the NAT route.

Simply creating the correct NAT Gateway and route table elsewhere in the VPC does not affect an instance attached to a different subnet.

The incorrect instance was terminated.

---

# 10. Correct Private EC2

The second instance was launched correctly.

```text
Instance ID: i-0example3
Name: saa-lab-3-private
Private IPv4: 172.31.63.214
Public IPv4: none
Subnet: subnet-0example2
Subnet name: saa-lab-3-private
CIDR: 172.31.48.0/20
AZ: eu-north-1a
Instance type: t3.micro
```

This time:

```text
172.31.63.214
```

is correctly inside:

```text
172.31.48.0/20
```

and the instance had **no public IPv4 address**.

---

# 11. Accessing the Private EC2

From the local computer:

```bash
ssh -A -i ~/.ssh/aws/saa-lab-1.pem ec2-user@<public-ip>
```

This connected to the public bastion.

Then:

```bash
ssh ec2-user@172.31.63.214
```

This connected to the private EC2 through its private IP.

The path was:

```text
Laptop
   │
   │ SSH over Internet
   ▼
Public EC2
<public-ip>
   │
   │ SSH over private VPC networking
   ▼
Private EC2
172.31.63.214
```

This demonstrated that:

> A private EC2 does not need a public IP to be reachable from another appropriately permitted resource inside the VPC.

---

# 12. Verifying the Private EC2 Route

From the private EC2:

```bash
ip route
```

Output included:

```text
default via 172.31.48.1 dev ens5 proto dhcp src 172.31.63.214 metric 512
172.31.48.0/20 dev ens5 proto kernel scope link src 172.31.63.214 metric 512
```

The important point was:

```text
default via 172.31.48.1
```

The operating system sends Internet-bound traffic to the subnet's default gateway.

AWS then applies the subnet's route table:

```text
0.0.0.0/0 → NAT Gateway
```

---

# 13. Successful NAT Test

We ran:

```bash
curl -4 -v --connect-timeout 5 https://example.com
```

This succeeded.

The connection was established:

```text
Established connection to example.com (<public-ip> port 443)
```

TLS negotiation completed successfully.

The server returned:

```text
HTTP/2 200
```

Therefore the private EC2 successfully reached the public Internet.

The complete path was:

```text
Private EC2
172.31.63.214
      │
      ▼
Private subnet
172.31.48.0/20
      │
      ▼
Private route table
0.0.0.0/0 → NAT Gateway
      │
      ▼
NAT Gateway
<public-ip>
      │
      ▼
Public subnet
      │
      ▼
Internet Gateway
      │
      ▼
Internet
```

---

# 14. Final Lab Result

### Private EC2 → Internet

```text
✅ WORKS
```

The private EC2 successfully established an HTTPS connection to `example.com`.

### Private EC2 has public IPv4

```text
❌ NO
```

It had no public IPv4 address.

### Private EC2 uses NAT Gateway

```text
✅ YES
```

Its private route table sends `0.0.0.0/0` to the NAT Gateway.

### Internet can directly initiate a new connection to private EC2

```text
❌ NOT PROVIDED
```

The private instance has no public IPv4 address and there is no direct Internet path to it.

---

# 15. What We Learned

## NAT Gateway

A public NAT Gateway allows instances in private subnets to initiate connections to the Internet.

```text
Private EC2
    ↓
NAT Gateway
    ↓
Internet
```

## Public vs private subnet

The private subnet's Internet-bound route points to:

```text
NAT Gateway
```

rather than directly to:

```text
Internet Gateway
```

## NAT Gateway placement

For the classic architecture used in this lab:

```text
NAT Gateway → Public Subnet
```

## Internet Gateway

The Internet Gateway provides the VPC's Internet path.

The NAT Gateway uses the public subnet's route to reach it.

## Security Groups

The private SG used:

```text
SSH :22
Source = saa-lab-3-public SG
```

rather than allowing SSH from the Internet.

Security groups therefore handled access control, while routing determined the network path.

## Connection initiation

The most important conceptual distinction:

```text
Private EC2 initiates
        ↓
Internet responds
        ↓
Return traffic belongs to the existing connection
```

is fundamentally different from:

```text
Internet host initiates a new connection
        ↓
Private EC2
```

This distinction explains how a private EC2 can download files while remaining non-publicly reachable.

---

# 16. Failure We Encountered

The most useful failure in this lab was **not a NAT failure**.

It was an incorrect subnet assignment.

We had:

```text
Correct NAT route:
172.31.48.0/20
        ↓
NAT Gateway
```

but the first private EC2 was actually:

```text
172.31.16.35
172.31.16.0/20
```

Therefore it was using a different subnet and route-table configuration.

Lesson:

> Always verify an EC2's actual subnet and route table when debugging VPC connectivity.

---

# 17. What We Did Not Finish

We stopped once the primary NAT objective was proven.

We did **not** perform the additional experiments:

```text
1. Check the public IP seen by the Internet
2. Remove the NAT route and observe failure
3. Explicitly test that unsolicited Internet → private EC2 connections fail
```

Those are useful follow-up experiments, but the central Lab 3 objective was already successfully demonstrated.

---

# 18. SAA Mental Model

Keep this picture:

```text
                         INTERNET
                            ▲
                            │
                           IGW
                            ▲
                            │
                     PUBLIC SUBNET
                            │
                       NAT GATEWAY
                            ▲
                            │
                    PRIVATE SUBNET
                            │
                       PRIVATE EC2
```

And remember:

```text
Public EC2
    → direct Internet path

Private EC2
    → NAT Gateway
    → Internet

Internet
    → does not directly initiate connections
       to the private EC2
```

The three pieces answer different questions:

| Component        | Question it answers                                    |
| ---------------- | ------------------------------------------------------ |
| Public IP        | What Internet-facing address does this resource have?  |
| Route table      | Where should this traffic go?                          |
| NAT Gateway      | How does a private resource reach the public Internet? |
| Internet Gateway | How does the VPC connect to the Internet?              |
| Security Group   | Is this connection allowed?                            |

---

# 19. Cleanup Status

At the end of today's session, the lab-specific resources were still present because the next cleanup step was not performed yet.

Current lab resources include:

```text
saa-lab-3-nat
saa-lab-3-private
saa-lab-3-private-rt
saa-lab-3-public
saa-lab-3-private
```

and the two EC2 instances:

```text
saa-lab-3-public
saa-lab-3-private
```

The VPC itself is shared infrastructure and should remain available for future labs.

Before ending the AWS session completely, terminate the two EC2 instances and delete the NAT Gateway to avoid ongoing charges. Then remove the lab-specific security groups and private route table/subnet if they will not be reused.

---

# 20. Core Takeaway

> **A private EC2 can initiate outbound Internet connections through a NAT Gateway without having a public IP and without exposing itself to direct Internet-initiated connections.**

The traffic flow is:

```text
Private EC2
   ↓
Private Route Table
   ↓
NAT Gateway
   ↓
Public Subnet
   ↓
Internet Gateway
   ↓
Internet
```

That is the Lab 3 concept.

