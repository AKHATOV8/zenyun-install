# ZenyunVPN — Installation Scripts

Private installer for deploying [ZenyunVPN](https://t.me/zenyuntestbot) on a VPS.

## Quick install

```bash
curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/install.sh | bash
```

> Repository: `AKHATOV8/zenyun-install` (private)

## Requirements

| Requirement | Details |
|-------------|---------|
| OS | Ubuntu 20.04+ (22.04/24.04 recommended) |
| RAM | Minimum 1 GB |
| Disk | 5+ GB free |
| Domain | DNS A-record pointing to your server |
| Telegram | Bot token from [@BotFather](https://t.me/BotFather) |
| GitHub | Deploy key with read access to the private bot repo |

## What the installer does

1. **Password gate** — SHA-256 hash verification (no plain password stored)
2. **System check** — Ubuntu version, RAM, disk
3. **Docker** — installs Docker Engine + Compose plugin if missing
4. **Configuration** — prompts for bot token, admin ID, domains, SSL mode
5. **Clone** — pulls private bot source via deploy key
6. **`.env`** — auto-generates secrets (Postgres password, admin path secret)
7. **Nginx** — generates reverse-proxy config for subscription + cabinet
8. **SSL** — Let's Encrypt (manual DNS) or Cloudflare Origin Certificate
9. **Launch** — `docker compose up -d --build`
10. **Status** — prints access URLs and BotFather setup steps

## Configuration prompts

During install you will be asked for:

- **Bot token** — from @BotFather
- **Admin Telegram ID** — your numeric Telegram user ID
- **Subscription domain** — e.g. `sub.example.com`
- **Cabinet domain** — e.g. `app.example.com` (auto-suggested)
- **Landing domain** — e.g. `example.com` (optional)
- **GitHub username** — owner of the private bot repository
- **SSL mode** — Let's Encrypt or Cloudflare Origin Certificate
- **Deploy key path** — default `/root/.ssh/zenyun_deploy_key`

## Deploy key setup

Before running the installer, add a read-only deploy key to your private bot repo:

```bash
ssh-keygen -t ed25519 -f /root/.ssh/zenyun_deploy_key -N ""
cat /root/.ssh/zenyun_deploy_key.pub
```

Add the public key in GitHub → Repository → Settings → Deploy keys.

## SSL options

### Option 1: Let's Encrypt (manual)

Point your domain DNS A-records to the server IP before install completes.
The script uses `certbot --standalone` to obtain certificates.

### Option 2: Cloudflare

1. Create an Origin Certificate in Cloudflare dashboard
2. Save cert and key on the server
3. Choose option 2 during install and provide file paths
4. Set Cloudflare SSL mode to **Full (strict)**

## Updating an existing installation

```bash
cd /home/vpnbot
curl -sSL https://raw.githubusercontent.com/AKHATOV8/zenyun-install/main/check-update.sh -o check-update.sh
chmod +x check-update.sh
bash check-update.sh
```

The update script:
- Verifies installation password
- Runs `git pull`
- Rebuilds with `docker compose up -d --build`
- Shows recent changelog (`git log`)

## Installed paths

| Path | Purpose |
|------|---------|
| `/home/vpnbot/` | Application root |
| `/home/vpnbot/.env` | Environment variables |
| `/home/vpnbot/nginx/certs/` | TLS certificates |
| `/home/vpnbot/backups/` | Daily backups |

## Useful commands

```bash
# View logs
docker compose -f /home/vpnbot/docker-compose.yml logs -f bot web

# Restart services
docker compose -f /home/vpnbot/docker-compose.yml restart bot web

# Container status
docker compose -f /home/vpnbot/docker-compose.yml ps
```

## BotFather setup (after install)

1. `/mybots` → your bot → **Bot Settings** → **Configure Mini App**
   - URL: `https://sub.yourdomain.com/app`
   - Short name: `zenyunminiapp` (or your choice)
2. **Menu Button** → URL: `https://sub.yourdomain.com/app`
   - Text: `🖥 Личный кабинет`

## Support

Telegram: [@zenyuntestbot](https://t.me/zenyuntestbot)

## Files in this repository

| File | Description |
|------|-------------|
| `install.sh` | Full VPS installation script |
| `check-update.sh` | Update existing deployment |
| `README.md` | This documentation |

## Security notes

- Installation password is verified via SHA-256 hash only
- `.env` is generated with random Postgres password and admin secret
- Deploy key should be read-only
- Keep this repository **private**
