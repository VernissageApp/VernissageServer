# Install Vernissage with vernissagectl

`vernissagectl` is a command-line installer and administration tool for Vernissage. It guides you through a complete Docker-based installation and provides commands for diagnostics, updates, backups, restores, logs, and routine service management.

![vernissagectl](https://dze8wklcbv7qo.cloudfront.net/articles/7671702156419795339/e1eaaac570c44be89a9d236f2b0fb504.png)

You can find the source code, complete documentation, and available commands in the [Vernissage Installer repository](https://github.com/VernissageApp/VernissageInstaller).

> **Important:** `vernissagectl` is currently experimental and undergoing production testing. The available features are already complete enough to install and perform basic management of a Vernissage instance, but you should still monitor your installation carefully and maintain regular backups.

---

## Who is this installer for?

`vernissagectl` creates and manages a Docker-based installation on a single server. This makes it particularly suitable for small and medium-sized instances that do not expect very high traffic.

For larger installations, consider separating critical services across multiple machines or using managed infrastructure. The main `vernissage.photos` installation, for example, runs multiple instances of important services to provide redundancy and reduce downtime.

That level of complexity is usually unnecessary for a small community or personal instance, where running everything on one properly maintained server can be a reasonable starting point.

---

## Before you begin

You will need a server and a domain name.

### Server

Create a new server running Ubuntu 24.04. Both x86-64 and ARM64 are supported.

Your server should have:

- A static or reserved public IPv4 address, or a correctly configured public IPv6 address.
- Enough CPU, memory, and disk space for the expected number of users and uploaded photographs.
- Inbound TCP ports `80` and `443` open.
- SSH access, normally through TCP port `22`.

If you use Azure, AWS, or another cloud provider, remember that ports may need to be opened both in the operating system firewall and in the provider's network firewall or security group.

Restrict SSH access to trusted IP addresses whenever possible.

### Domain

Register a new domain or create a subdomain for the instance, for example:

```text
photos.example.com
```

Add the appropriate DNS record:

- An `A` record for a public IPv4 address.
- An `AAAA` record for a public IPv6 address.

Only create an `AAAA` record if the server has fully working public IPv6 connectivity.

You can check whether the record is resolving with:

```bash
dig +short A photos.example.com
dig +short AAAA photos.example.com
```

You can also use `nslookup` if `dig` is unavailable. Keep in mind that DNS changes may take some time to propagate.

> **Important:** The domain becomes the permanent federated identity of your instance. Changing it later can break existing ActivityPub relationships, so choose it carefully before installation.

---

## Recommended production services

The installer can create local PostgreSQL, Redis, and MinIO containers. This is convenient for smaller installations, but local Docker volumes are not backups. A disk or server failure may still cause permanent data loss.

For a production instance, consider preparing the following services in advance.

### Managed PostgreSQL

A managed PostgreSQL service is strongly recommended. Ideally, it should provide:

- Automatic backups or snapshots.
- Point-in-time recovery.
- Monitoring and alerts.
- A documented upgrade procedure.
- Storage redundancy.

The installer can also create PostgreSQL locally if you prefer a simpler setup. If you choose this option, arrange regular off-server backups.

### S3 object storage

You can use:

- AWS S3, which is currently the most thoroughly tested option.
- Another S3-compatible storage service.
- A local MinIO container created by the installer.

For AWS or another provider, create an S3 bucket and credentials that allow Vernissage to upload, download, and delete objects in that bucket.

A CDN such as CloudFront is optional, but it can reduce traffic to your storage service and improve image delivery for geographically distributed users.

### Redis

Using a local Redis container is perfectly reasonable for most small installations. Redis is used for queues, distributed locks, and temporary data. PostgreSQL and S3 remain the primary sources of persistent application data.

---

## Install Docker

Connect to the server over SSH:

```bash
ssh your-user@your-server-address
```

Install Docker Engine and the Docker Compose plugin using the official [Docker installation instructions for Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

After installation, verify that Docker is running:

```bash
sudo systemctl status docker
sudo docker run hello-world
```

By default, Ubuntu may require `sudo` to access the Docker daemon. This is normal.

Docker can also be configured for use without `sudo`, but adding a user to the `docker` group grants that user root-level privileges. Follow Docker's official [Linux post-installation guide](https://docs.docker.com/engine/install/linux-postinstall/) and only grant this access to trusted administrators.

---

## Install vernissagectl

Download and install the latest version:

```bash
curl -fsSL https://joinvernissage.org/install.sh | sudo sh
```

If you prefer, you can inspect the installation script before running it:

```bash
curl -fsSL https://joinvernissage.org/install.sh -o install.sh
less install.sh
sudo sh install.sh
```

Verify the installation:

```bash
vernissagectl --version
```

---

## Run the installation wizard

If your user does not have permission to access Docker directly, run:

```bash
sudo vernissagectl install
```

If Docker works for your user without `sudo`, you can instead run:

```bash
vernissagectl install
```

Use the same privilege model for subsequent management commands.

The wizard will guide you through the complete installation, including:

- Checking Docker and Docker Compose.
- Verifying the instance domain and network configuration.
- Connecting to or installing PostgreSQL.
- Connecting to or installing Redis.
- Configuring AWS S3, another S3-compatible service, or local MinIO.
- Installing the Vernissage API and background jobs.
- Creating the permanent administrator account.
- Installing the web application and Web Push service.
- Building and configuring the Vernissage reverse proxy.
- Configuring HTTPS.

Read each question carefully. The recommended choices are a good default for most installations.

For a publicly accessible instance, select `Production HTTPS — Automatic Let's Encrypt certificate`. For automatic certificate issuance to work, the domain must resolve to the server and ports `80` and `443` must be publicly reachable.

The development HTTPS option uses a locally issued certificate and is intended only for testing. Browsers and other devices will not trust it automatically.

![vernissagectl](https://dze8wklcbv7qo.cloudfront.net/articles/7671702156419795339/babbec819cb94b689837f7f9e7c102ed.png)

---

## After installation

When all checks pass, the installer will display the HTTPS address of the new instance. Open it in a browser and sign in using the administrator account created during installation. The installer disables the default administrator login as part of the setup.

The technical installation is now complete, but the instance still needs some application-level configuration. Open the **Settings** page and review:

- Instance name and description.
- Administrator and contact information.
- Email and SMTP delivery.
- Registration and moderation settings.
- Web Push notifications.
- Optional AI integrations.
- Storage and image URL settings.

You can verify the installation from the server with:

```bash
sudo vernissagectl doctor
sudo vernissagectl status
```

Run the commands from the directory containing the generated configuration, or pass it explicitly:

```bash
sudo vernissagectl --config /path/to/vernissage.yml doctor
```

---

## Keep the generated configuration safe

At the end of the installation, `vernissagectl` creates two important files:

- `vernissage.yml` describes the installed services and allows future management commands to locate the correct containers.
- `vernissage.secrets.yml` contains sensitive credentials required to recreate or update the installation.

The installer will print their exact locations.

Do not commit `vernissage.secrets.yml` to Git or share it with anyone. Store an encrypted copy in a secure location. Losing the file may make future recovery and maintenance more difficult.

These configuration files are not backups of your database or uploaded photographs. You should still maintain separate backups of PostgreSQL and S3 or MinIO data, preferably outside the server.

---

## Installation complete

Your new Vernissage instance should now be online and ready to use.
