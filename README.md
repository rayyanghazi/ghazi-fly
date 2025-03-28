# **Secure SSH Server Deployment on Fly.io**

This guide outlines the steps to deploy a secure SSH server on Fly.io with persistent configuration for enhanced reliability.

---

## 🚀 **Prerequisites**
Before you begin, ensure you have:

✅ A registered Fly.io account  
✅ Fly.io CLI installed (`flyctl`)  
✅ An SSH client (e.g., OpenSSH, MobaXterm)  
✅ A public SSH key (`~/.ssh/id_ed25519.pub`)  

---

## 🔧 **Deployment Steps**

### **1. Initialize the Application**
Run the following command to create a new Fly.io app and set up the environment:

```bash
fly launch --name rayyan --region iad --dockerfile Dockerfile
```

---

### **2. Create a Persistent Volume**
This volume stores SSH keys to ensure they persist across VM restarts.

```bash
fly volumes create ssh_keys -a rayyan --size 1 --region iad
```

---

### **3. Set SSH Authorized Keys**
Add your SSH public key as an environment variable for secure login:

```bash
fly secrets set AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)" -a rayyan
```

---

### **4. Deploy the Application**
Deploy your SSH server to Fly.io with:

```bash
fly deploy --strategy immediate --remote-only --detach
```

---

## 📂 **Configuration File Structure**

### **Dockerfile**
Defines the SSH server setup and entrypoint:

```dockerfile
FROM debian:bookworm-slim

# Install paket dasar dan dependensi
RUN apt-get update && apt-get install -y \
    build-essential software-properties-common \
    ca-certificates locales wget curl git \
    unzip zip tar nano vim screen htop \
    neofetch tmux fail2ban ufw openssh-server \
    supervisor net-tools iptables gnupg2 \
    lsb-release dnsutils tree bash-completion \
    && rm -rf /var/lib/apt/lists/*

# Konfigurasi locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Konfigurasi SSH
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    mkdir /var/run/sshd && \
    chmod 755 /var/run/sshd

COPY sshd_config /etc/ssh/sshd_config
RUN chmod 600 /etc/ssh/sshd_config

RUN ssh-keygen -A

RUN rm -f /etc/ssh/ssh_host_* && \
    mkdir -p /mnt/ssh_keys && \
    chmod 700 /mnt/ssh_keys

COPY entrypoint.sh /entrypoint.sh

# Setup volume untuk kunci SSH persisten
VOLUME ["/mnt/ssh_keys"]

# Setup entrypoint
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Default command (jika diperlukan)
CMD []
```

---

### **entrypoint.sh**
Handles SSH key generation, persistence, and authorized keys setup:

```bash
#!/bin/bash
set -e

# Generate SSH keys jika belum ada
mkdir -p /mnt/ssh_keys
if [ ! -f /mnt/ssh_keys/ssh_host_ed25519_key ]; then
  echo "Generating new SSH host keys..."
  ssh-keygen -A >/dev/null
  cp /etc/ssh/ssh_host_* /mnt/ssh_keys/
fi

# Link keys dari volume
rm -f /etc/ssh/ssh_host_*
ln -sf /mnt/ssh_keys/* /etc/ssh/

# Setup authorized_keys
mkdir -p /root/.ssh
if [ -n "$AUTHORIZED_KEYS" ]; then
  echo "$AUTHORIZED_KEYS" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi

# Start SSH dengan opsi eksplisit
echo "Starting SSH server..."
exec /usr/sbin/sshd -D -o "ListenAddress 0.0.0.0:2222" -e
```

---

### **sshd_config**
Secure SSH configuration for better protection:

```conf
Port 2222
AddressFamily inet
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key 
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin prohibit-password
PasswordAuthentication yes
ChallengeResponseAuthentication no
PrintMotd no
Subsystem sftp /usr/lib/openssh/sftp-server
LogLevel VERBOSE
```

---

### **fly.toml**
Fly.io configuration file for deployment settings:

```toml
app = "rayyan"
primary_region = "iad"

[build]

[mounts]
  source = "ssh_keys"
  destination = "/mnt/ssh_keys"  # Pastikan path sesuai

[[services]]
  internal_port = 2222
  protocol = "tcp"
  
  [[services.ports]]
    port = 2222  # Gunakan port external yang sama dengan internal
    handlers = []  # Hapus handler TLS untuk port non-standar

[[vm]]
  memory = "16gb"
  cpu_kind = "shared"
  cpus = 8
```

---

## 🔐 **Connect to Your SSH Server**

### **Standard Port (Recommended)**
```bash
ssh -p 22 root@rayyan.fly.dev
```

### **Alternative Port**
```bash
ssh -p 2222 root@rayyan.fly.dev
```

For convenience, add this to your `~/.ssh/config`:

```
Host rayyan
  HostName rayyan.fly.dev
  User root
  Port 22
  IdentityFile ~/.ssh/id_ed25519
```

---

## 🛠️ **Troubleshooting**

### **Check Logs**
```bash
fly logs -a rayyan
```

---

### **Repair or Recreate Volume**
If volume issues arise:

1. List volumes:
   ```bash
   fly volumes list -a rayyan
   ```

2. Delete the problematic volume:
   ```bash
   fly volumes delete <volume-id> -a rayyan --yes
   ```

3. Recreate the volume:
   ```bash
   fly volumes create ssh_keys -a rayyan --size 1 --region iad
   ```

---

### **Force Re-deploy**
```bash
fly deploy --strategy immediate --remote-only --detach
```

---

## 🔒 **Optional Enhancements**

### **Enable Fail2ban**
To enhance security and block brute-force attacks:

```bash
fly ssh console -a rayyan
apt update && apt install fail2ban
systemctl start fail2ban
```

---

### **Configure Firewall**
Limit SSH access to secure your server:

```bash
ufw allow 2222
ufw enable
```

---

## 📝 **Notes**
✅ The server scales down automatically when idle  
✅ Use SSH key type `ed25519` for optimal security  
✅ Port 22 benefits from Fly.io's TLS termination  
✅ SSH host keys persist in the volume for improved stability  

If you encounter issues or have questions, feel free to ask! 🚀
