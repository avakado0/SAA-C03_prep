# EC2 SSH Key Pairs

## Public/private key concept
- Two math-linked keys: public locks, private unlocks. Can't derive private from public.
- Public key: safe to share, sits on server.
- Private key: secret, stays only on your computer, never shared.
- SSH auth: your computer proves it holds matching private key. No password sent.

## AWS flow
1. Create key pair BEFORE/DURING instance launch (EC2 console → "Key pairs", or launch wizard prompt).
2. AWS generates both keys:
   - **Private key**: AWS gives it to you ONCE as a download (`.pem` file). Not stored by AWS — no re-download later.
   - **Public key**: AWS keeps it.
3. On instance launch, AWS auto-injects public key into instance's `~/.ssh/authorized_keys`.
4. Instance holds public key, you hold private key (.pem) → match = SSH works.

Lose the .pem = no recovery. Must create new key pair or add new key via SSM/other method to a running instance.

## Connecting
```
ssh -i /path/to/key.pem ec2-user@<public-ip>
```
- User depends on AMI: `ec2-user` (Amazon Linux), `ubuntu` (Ubuntu), `admin` (Debian).
- Permissions matter: `chmod 400 key.pem` — SSH refuses key if too open.
- No key pair selected at launch = no SSH via key (only SSM Session Manager, if IAM role configured).

## .pem vs .ppk
- **.pem**: standard format (base64-encoded). AWS gives you this. Works natively with OpenSSH (Mac/Linux, and Windows 10+ built-in `ssh` command).
- **.ppk**: PuTTY's own format. Needed only for PuTTY client (legacy Windows tool).
- Same private key, different container. Convert .pem → .ppk via PuTTYgen if using PuTTY.
- Recommended: skip PuTTY, use `ssh -i key.pem ...` directly from terminal.
