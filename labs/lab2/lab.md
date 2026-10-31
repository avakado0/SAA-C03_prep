# AWS SAA-C03 Lab 2 — Public EC2

## Goal

Understand what actually makes an EC2 instance **publicly reachable from the Internet**.

The experiment focuses on the relationship between:

* Public IPv4 address
* Internet Gateway (IGW)
* Route table
* Subnet
* Security Group
* Application listener

The main question:

> **What must be true for an Internet user to reach an application running on EC2?**

---

# 1. Intended Scenario

We wanted to build:

```text
                    INTERNET
                       │
                       ▼
                Internet Gateway
                       │
                       ▼
                  Route Table
                 0.0.0.0/0 → IGW
                       │
                       ▼
                 Public Subnet
                       │
                       ▼
                     EC2-C
                 Public IPv4
                       │
                       ▼
                Security Group
                 TCP 80 allowed
                       │
                       ▼
                 Web Application
                    :80
```

The intended requirements were:

1. EC2 must be reachable from the Internet.
2. EC2 must have a public IPv4 address.
3. The subnet must have a route to an Internet Gateway.
4. The Security Group must allow inbound TCP/80.
5. A web application must actually be listening on TCP/80.

---

# 2. What We Reused From Lab 1

Instead of creating another VPC from scratch, we inspected the existing Lab 1 VPC.

### VPC

```text
VPC:
vpc-0example1
```

### Existing subnet

```text
Subnet:
subnet-0example1

CIDR:
172.31.16.0/20
```

We initially thought we had not created a subnet during Lab 1.

That was incorrect.

The subnet already existed and our EC2 instances were placed inside it. We simply inherited the existing subnet rather than creating it manually.

### Main route table

```text
Route table:
rtb-0efc33b61691c1638
```

It was the **main route table**, meaning the subnet had no explicit route-table association.

Its routes were:

```text
172.31.0.0/16 → local
0.0.0.0/0     → Internet Gateway
```

The Internet Gateway was:

```text
igw-0366d9731f9f185c0
```

This was an important discovery.

The existing subnet already had:

```text
0.0.0.0/0 → IGW
```

Therefore, from a routing perspective, it was already capable of being a **public subnet**.

---

# 3. What We Had to Create

We decided not to reuse the Lab 1 Security Groups because they represented different security relationships.

We created a dedicated Lab 2 Security Group:

```text
saa-lab-2-public
```

Inbound:

```text
HTTP
TCP
80
0.0.0.0/0
```

Outbound:

```text
All traffic
0.0.0.0/0
```

The important distinction was:

> Lab 1 SGs represented specific machine-to-machine relationships. Lab 2's SG represents a publicly accessible web service.

---

# 4. EC2-C

We launched a new EC2 instance in the existing VPC/subnet.

Instance:

```text
EC2-C
```

Private IP:

```text
172.31.25.140
```

Public IPv4:

```text
<public-ip>
```

The instance used an Amazon Linux AMI.

This was useful because we also encountered an SSH username difference compared with our Debian instance from Lab 1.

For Amazon Linux:

```bash
ssh -i ~/.ssh/aws/saa-lab-1.pem ec2-user@<public-ip>
```

rather than:

```bash
ssh ... admin@<public-ip>
```

---

# 5. First Experiment: No Application Listening

Before running a web server, we tested:

```bash
curl -v --connect-timeout 5 http://<public-ip>
```

Result:

```text
Trying <public-ip>:80...
connect to <public-ip> port 80 ... failed:
Connection refused
```

This was exactly what we predicted.

At this point:

```text
Public IPv4              ✅
Internet Gateway         ✅
Route table              ✅
Public subnet            ✅
Security Group :80       ✅
EC2 running              ✅
Application on :80       ❌
```

Therefore:

```text
TCP connection
      ↓
EC2 reached
      ↓
Nothing listening on :80
      ↓
Connection refused
```

### Important distinction

**Connection refused is not the same as a Security Group timeout.**

A refused connection indicates that the network path reached the destination but there was no service accepting the connection on that port.

---

# 6. SSH Troubleshooting

We initially tried:

```bash
ssh -i ~/.ssh/aws/saa-lab-1.pem admin@<public-ip>
```

At first, SSH appeared to hang.

This was because the Lab 2 Security Group only allowed:

```text
TCP 80
```

and did not allow:

```text
TCP 22
```

Therefore:

```text
Laptop
   │
   │ TCP 22
   ▼
EC2 Security Group
   │
   ✋ blocked
```

We temporarily allowed SSH from our own public IP.

After that, SSH reached the instance, but initially returned:

```text
Permission denied (publickey,...)
```

This was no longer a networking problem.

The TCP connection was working.

The problem had moved to **SSH authentication**.

We then used the appropriate Amazon Linux username:

```bash
ec2-user
```

and successfully connected.

This demonstrated another useful troubleshooting principle:

> A timeout and an authentication failure occur at different layers.

---

# 7. FastAPI Application

Instead of installing nginx, we decided to run an actual Python application.

We created:

```text
app.py
```

with:

```python
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def home():
    return {
        "message": "Hello from EC2-C!",
        "lab": "AWS SAA Lab 2",
        "status": "public"
    }
```

We installed:

```bash
pip3 install fastapi uvicorn
```

The packages were installed in the user's local Python environment:

```text
~/.local/lib/python3.9/site-packages
```

---

# 8. Python / sudo Issue

Initially we attempted:

```bash
sudo python3 -m uvicorn app:app --host 0.0.0.0 --port 80
```

This produced:

```text
/usr/bin/python3: No module named uvicorn
```

But:

```bash
pip3 install fastapi uvicorn
```

reported that Uvicorn was already installed.

The reason was that:

```text
pip3
   ↓
ec2-user's Python environment
   ↓
~/.local/lib/python3.9/site-packages
```

while:

```text
sudo python3
   ↓
root's Python environment
```

did not have Uvicorn installed.

We solved this by allowing Python to bind to the privileged port 80:

```bash
sudo /usr/sbin/setcap \
  'cap_net_bind_service=+ep' \
  /usr/bin/python3.9
```

Verified with:

```bash
getcap /usr/bin/python3.9
```

Result:

```text
/usr/bin/python3.9 cap_net_bind_service=ep
```

Then we could run:

```bash
python3 -m uvicorn app:app \
    --host 0.0.0.0 \
    --port 80
```

Successfully:

```text
Uvicorn running on http://0.0.0.0:80
```

---

# 9. Successful Internet Request

From the local machine:

```bash
curl -v http://<public-ip>
```

Result:

```text
Connected to <public-ip> (<public-ip>) port 80
```

Then:

```text
HTTP/1.1 200 OK
server: uvicorn
content-type: application/json
```

Response:

```json
{
    "message": "Hello from EC2-C!",
    "lab": "AWS SAA Lab 2",
    "status": "public"
}
```

This experimentally confirmed the entire path:

```text
Laptop
   │
   │ HTTP :80
   ▼
Public IPv4
<public-ip>
   │
   ▼
Internet Gateway
   │
   ▼
Route Table
0.0.0.0/0 → IGW
   │
   ▼
Subnet
172.31.16.0/20
   │
   ▼
EC2-C
   │
   ▼
Security Group
TCP 80 allowed
   │
   ▼
Uvicorn :80
   │
   ▼
FastAPI
   │
   ▼
HTTP 200
```

---

# 10. Deliberate Security Group Failure

With FastAPI still running, we removed:

```text
HTTP
TCP 80
0.0.0.0/0
```

from the Security Group.

Then:

```bash
curl -v --connect-timeout 5 http://<public-ip>
```

produced:

```text
Trying <public-ip>:80...
```

and waited.

This demonstrated a **timeout**.

The application was still running.

Therefore:

```text
Uvicorn                 ✅
EC2                     ✅
Public IPv4             ✅
Route to IGW            ✅
Security Group :80      ❌
```

The Security Group silently dropped the traffic.

This gave us a direct comparison:

### Application unavailable

```text
SG allows :80
        ↓
Nothing listening
        ↓
Connection refused
```

### Security Group blocks traffic

```text
Application listening
        ↓
SG blocks :80
        ↓
Timeout
```

This distinction is highly useful when interpreting connectivity problems.

---

# 11. Final Mental Model

The most important lesson from Lab 2 is that **"public EC2" is not one switch**.

For direct Internet access, think:

```text
                    INTERNET
                       │
                       ▼
               Public IPv4 address
                       │
                       ▼
                Internet Gateway
                       │
                       ▼
                 Route Table
              0.0.0.0/0 → IGW
                       │
                       ▼
                 Public Subnet
                       │
                       ▼
                    EC2 ENI
                       │
                       ▼
                Security Group
                       │
                       ▼
                Application :80
```

Each component has a different job.

### Public IPv4

**Who can address the instance from the Internet?**

### Internet Gateway

**Provides the VPC's Internet connectivity.**

### Route Table

**Where should traffic go?**

```text
0.0.0.0/0 → IGW
```

### Subnet

**Where does the EC2's private address live?**

A subnet is effectively "public" when its route table provides a route to an Internet Gateway.

There isn't a magical "Public Subnet" switch.

### Security Group

**Is this traffic allowed to reach the ENI?**

It is a stateful firewall.

### Application

**Is anything actually listening on that port?**

---

# 12. SAA Exam Takeaways

### Public EC2 generally requires

```text
Public IPv4
+
Subnet route to IGW
+
IGW attached to VPC
+
Security Group allowing required inbound traffic
+
Application actually listening
```

### Don't confuse these

```text
Public IP ≠ permission
```

A public IP gives the instance an Internet-facing address.

```text
Public subnet ≠ public IP
```

The subnet's public/private nature comes from its routing.

```text
Security Group ≠ route table
```

Route table determines the path.

Security Group determines whether traffic is permitted.

```text
IGW ≠ Security Group
```

IGW provides Internet connectivity.

SG filters traffic.

---

# 13. What We Actually Experienced

Rather than merely reading the theory, we observed:

```text
1. No listener
   → Connection refused

2. SG blocks traffic
   → Connection timeout

3. SG allows traffic + listener exists
   → HTTP 200

4. SSH blocked by SG
   → Timeout

5. SSH allowed but wrong credentials/user
   → Permission denied

6. Correct SSH configuration
   → Successful login
```

This made the troubleshooting layers visible instead of treating "can't connect" as one generic AWS problem.

---

# 14. Cleanup

We restored the HTTP Security Group rule:

```text
TCP 80
0.0.0.0/0
```

We stopped the FastAPI server with:

```text
Ctrl+C
```

The EC2 instance can be reused for the next lab if desired.

The VPC, subnet, Internet Gateway, and route table can also be reused.

The temporary SSH rule should be removed after the lab if it is no longer needed.

---

# 15. Lab 2 Final Summary

**Question:**

> What makes an EC2 publicly reachable?

**Answer:**

```text
Public IPv4
    +
Subnet route to Internet Gateway
    +
Internet Gateway attached to VPC
    +
Security Group allowing the traffic
    +
Application listening on the destination port
```

The most useful troubleshooting rule from this lab:

```text
TIMEOUT
→ suspect network path / SG / NACL / routing

CONNECTION REFUSED
→ network path probably works,
  but nothing is accepting the connection

HTTP RESPONSE
→ network + security + application path works
```

---

## Lab 2 Status

**Completed ✅**

### Concepts practiced

* VPC
* Subnet
* Main route table
* Internet Gateway
* Public IPv4
* Public subnet
* Security Groups
* TCP/80
* TCP/22
* SSH authentication
* FastAPI
* Uvicorn
* Connection timeout vs connection refused
* Internet → EC2 traffic flow
* Layered network troubleshooting

### Next Lab

**Lab 3: Private EC2**

We will remove the public Internet-facing characteristics and answer:

> **What exactly makes an EC2 private, and how can we prove that it is actually private?**

