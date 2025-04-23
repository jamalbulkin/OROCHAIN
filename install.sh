#!/bin/bash

echo "🔧 Menyiapkan lingkungan..."

# Update & install dependensi dasar
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y curl wget unzip lsb-release ca-certificates apt-transport-https gnupg software-properties-common

# Install Docker jika belum ada
if ! command -v docker &> /dev/null; then
    echo "📦 Menginstal Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update -y && sudo apt install -y docker-ce
    sudo systemctl start docker && sudo systemctl enable docker
else
    echo "✅ Docker sudah terpasang."
fi

# Install Docker Compose jika belum ada
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Menginstal Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "✅ Docker Compose sudah terpasang."
fi

# Set timezone
TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')
if [ -z "$TIMEZONE" ]; then
    TIMEZONE="Asia/Jakarta"
fi
echo "⏰ Timezone: $TIMEZONE"

# Buat folder chromium
mkdir -p $HOME/chromium && cd $HOME/chromium

# Generate username dan password acak
CUSTOM_USER=$(openssl rand -hex 4)
PASSWORD=$(openssl rand -hex 12)
echo "👤 Username: $CUSTOM_USER"
echo "🔐 Password: $PASSWORD"

# Buat file docker-compose.yaml
cat <<EOF > docker-compose.yaml
version: "3.8"
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=$CUSTOM_USER
      - PASSWORD=$PASSWORD
      - PUID=1000
      - PGID=1000
      - TZ=$TIMEZONE
      - LANG=en_US.UTF-8
      - CHROME_CLI=https://google.com/
    volumes:
      - \$HOME/chromium/config:/config
    ports:
      - 3010:3000
    shm_size: "1gb"
    restart: unless-stopped
EOF

# Jalankan Chromium
echo "🚀 Menjalankan Chromium container..."
docker-compose up -d

# Install Cloudflared (Cloudflare Tunnel CLI)
echo "🌐 Menginstal Cloudflare Tunnel CLI..."
cd $HOME && curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/

# Jalankan tunnel dan tampilkan URL publik
echo "🌍 Menjalankan Cloudflare Tunnel..."
cloudflared tunnel --url http://localhost:3010 --no-autoupdate &
sleep 5

# Ambil URL dari log cloudflared (sementara via grep)
echo "🔗 Link akses publik akan muncul dalam beberapa detik..."
sleep 8
ps aux | grep "cloudflared tunnel" | grep -v grep

echo "✅ Setup selesai! Akses Chromium kamu via link di atas."
echo "📌 USERNAME: $CUSTOM_USER"
echo "📌 PASSWORD: $PASSWORD"
