#!/bin/bash
set -e

# Generate SSH keys jika belum ada
mkdir -p /ghazi
chmod 777 /ghazi

# Buat .bash_profile jika belum ada
if [ ! -f /ghazi/.bash_profile ]; then
    cat << EOF > /ghazi/.bash_profile
# Load .bashrc jika ada
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# Alias contoh
alias ll="ls -lah"
EOF
fi

# Tambahkan custom prompt untuk ghazi
echo 'export PS1="\[\e[32m\][g-cdg] \[\e[36m\]\u@\h:\w\$ \[\e[m\]"' >> /ghazi/.bashrc

chown -R ghazi:ghazi /ghazi

if [ ! -f /ghazi/ssh_host_ed25519_key ]; then
  echo "Generating new SSH host keys..."
  ssh-keygen -A >/dev/null
  cp /etc/ssh/ssh_host_* /ghazi/
fi

# Link keys dari volume
rm -f /etc/ssh/ssh_host_*
ln -sf /ghazi/* /etc/ssh/

# Setup authorized_keys
mkdir -p /root/.ssh
if [ -n "$AUTHORIZED_KEYS" ]; then
  echo "$AUTHORIZED_KEYS" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi

# Start SSH dengan opsi eksplisit
echo "Starting SSH server..."
exec /usr/sbin/sshd -D -o "ListenAddress 0.0.0.0:2222" -e

# Token & Chat ID Telegram (ganti dengan punyamu)
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
#MESSAGE_THREAD_ID="3"  # ID topik di super grup

# Ambil hostname Fly.io
HOSTNAME_URL="https://$FLY_APP_NAME.fly.dev"

# Kirim notifikasi ke Telegram
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    #-d "message_thread_id=$MESSAGE_THREAD_ID" \
    -d "text=🚀 Server di Fly.io aktif! Hostname: $HOSTNAME_URL" \
    -d "parse_mode=Markdown"
