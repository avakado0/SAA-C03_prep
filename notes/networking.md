# Networking Notes

## Transit Gateway — share Direct Connect across accounts

Problem: multiple accounts/VPCs need one Direct Connect connection, but DX normally ties to single VPC/account.

Solution:
- Corp datacenter → Direct Connect location (VLAN link)
- DX endpoint → Direct Connect Gateway (via Transit VIF)
- Direct Connect Gateway → Transit Gateway
- Transit Gateway attaches VPCs in Account 1 + Account 2
- Result: one DX connection shared across multiple accounts/VPCs
- Bonus: use AWS Resource Access Manager (RAM) to share Transit Gateway itself across accounts

## Networking Costs in AWS (per GB)

- Ingress (traffic in) → always free
- Same AZ, private IP → free
- Cross-AZ, same region, private IP → $0.01/GB
- Cross-AZ, same region, public/Elastic IP → $0.02/GB
- Inter-region → $0.02/GB
- Takeaway: private IP always cheaper + faster than public/Elastic IP
