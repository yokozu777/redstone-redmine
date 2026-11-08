# Redstone-Redmine

<p align="center">
  <a href="LICENSE"><img alt="Apache 2.0" src="https://img.shields.io/badge/license-Apache%202.0-1f6feb"></a>
  <img alt="Redmine 7" src="https://img.shields.io/badge/Redmine-7-b32024">
  <img alt="PostgreSQL 18" src="https://img.shields.io/badge/PostgreSQL-18-336791">
  <img alt="Ruby 4" src="https://img.shields.io/badge/Ruby-4-cc342d">
  <img alt="Debian Trixie" src="https://img.shields.io/badge/Debian-Trixie-a80030">
  <img alt="Docker Compose" src="https://img.shields.io/badge/Docker-Compose-2496ED">
</p>

**Redmine, already dressed for work.** Clone the repo, run one command, and open a project tracker with documents, a Kanban board, dashboards, OAuth, a GitLab webhook, Telegram bots, and two-factor login. Each piece is a build flag: leave it on, or ship a smaller image without it.

The database and uploaded files sit in Docker volumes, so the next image rebuild does not wipe the instance. The UI listens on port **3000**. On first boot the Opale theme is selected when that theme was included in the build.

| | |
| --- | --- |
| Issues, tags, xlsx export | Track work and take a spreadsheet with you |
| DMSF + WebDAV | Store project documents and preview Office files |
| Dashboards and Kanban | See the project as a board, not only as a list |
| OAuth and GitLab hook | Sign in with an identity provider and receive push events |
| Bots and 2FA | Telegram integration and a second factor |
| Private CA | Trust `certs/*.crt` only when you ask for it |

```bash
docker compose up -d --build
```

Then open [http://localhost:3000/](http://localhost:3000/). Details of the image, the flags, and the pinned plugin versions are below.

## Layout

| Path | Role |
| --- | --- |
| `redmine.dockerfile` | Image recipe: OS packages, CA certificates, plugins, theme, gems |
| `docker-compose.yaml` | `redmine` and `redmine-db`, build args, ports, volumes |
| `certs/` | Local CA certificates, installed only when `INSTALL_LOCAL_CERT=true` |
| `redmine/plugins/` | Optional plugins copied into the image before the downloaded ones. `easy_gantt`, `easy_gantt_pro`, and `easy_baseline` are always removed |
| `redmine/configuration.yml` | SMTP settings |
| `redmine/config/storage.yml` | ActiveStorage disk (`storage/` inside the Redmine tree) |
| `redmine/additional_environment.rb` | Enables DMSF ActiveStorage and WebDAV when that plugin is present, and sets the Opale theme on first boot when the theme is installed |
| `redmine/db/migrate/20170806125915_create_active_storage_tables.rb` | ActiveStorage tables, used by DMSF |

## Run

```bash
docker compose up -d --build
```

Open `http://localhost:3000/`. The official image creates the `admin` user on first start and asks for a new password.

Plugin migrations run on startup because `REDMINE_PLUGINS_MIGRATE` is `true`.

```bash
docker compose logs -f redmine
docker compose down          # keeps volumes
docker compose down -v       # deletes the database and uploaded files
```

Rebuild after changing a build arg:

```bash
docker compose build --no-cache redmine
docker compose up -d
```

## Services

**redmine-db** is `postgres:18-alpine`. The data volume is mounted at `/var/lib/postgresql`. PostgreSQL 18 rejects the old `/var/lib/postgresql/data` mount. Redmine waits until `pg_isready` succeeds.

**redmine** builds `redmine.dockerfile` and connects with `REDMINE_DB_POSTGRES=redmine-db`.

| Volume | Mount | Contents |
| --- | --- | --- |
| `pgdata` | `/var/lib/postgresql` | PostgreSQL data |
| `redmine_files` | `/usr/src/redmine/files` | Redmine attachments |

## Before you expose this stack

`docker-compose.yaml` ships with a database password of `redmine` and a fixed `REDMINE_SECRET_KEY_BASE`. Replace both before the instance is reachable from anywhere but your machine. Set the SMTP password in `redmine/configuration.yml`.

## Build arguments

Set them under `build.args` in `docker-compose.yaml`, or pass `--build-arg` to `docker build`. A value of `false` skips that component. Defaults below are the Dockerfile defaults; compose overrides the ones it lists.

| Argument | Default | Effect |
| --- | --- | --- |
| `INSTALL_LIBREOFFICE` | `true` | Writer, Calc, and Impress so DMSF can convert Office files. `false` saves about 500MB |
| `INSTALL_CJK_FONTS` | `false` | Noto CJK fonts, about 150MB |
| `INSTALL_LOCAL_CERT` | `false` | Copy `certs/*.crt` into the trust store |
| `REMOTE_CA_URL` | empty | Download a CA PEM and trust it. Empty skips the download. Example: `https://ca.mxhash.dev:8443/roots.pem` |
| `INSTALL_REDMINE_OAUTH` | `true` | OAuth login |
| `INSTALL_REDMINE_GITLAB_HOOK` | `true` | GitLab webhook |
| `INSTALL_REDMINE_DASHBOARD` | `true` | Project dashboards |
| `INSTALL_OPALE` | `true` | Opale theme (not a plugin). Applied on first boot when no theme is set |
| `INSTALL_KANBAN` | `true` | Kanban board |
| `INSTALL_ADDITIONALS` | `true` | Extra Redmine features used by other plugins |
| `INSTALL_ADDITIONAL_TAGS` | `true` | Issue tags. Requires `INSTALL_ADDITIONALS=true` |
| `INSTALL_REDMINE_INDICATOR` | `true` | Indicator plugin |
| `INSTALL_XLSX_EXPORTER` | `true` | Export issues to xlsx |
| `INSTALL_REDMINE_DMSF` | `true` | Document management, WebDAV, and ActiveStorage |
| `INSTALL_REDMINE_STARTPAGE` | `true` | Custom start page |
| `INSTALL_REDMINE_BOTS` | `true` | Telegram bot integration |
| `INSTALL_REDMINE_2FA` | `true` | Two-factor authentication. Requires `INSTALL_REDMINE_BOTS=true` |

The build fails if `additional_tags` is enabled without `additionals`, or if `redmine_2fa` is enabled without `redmine_bots`.

Version pins live next to each plugin in `redmine.dockerfile` (`*_REF` arguments). Change the ref there to move a plugin to another tag or branch.

## Plugins

| Component | Source | Ref |
| --- | --- | --- |
| redmine_oauth | kontron/redmine_oauth | `v4.2.3` |
| redmine_gitlab_hook | phlegx/redmine_gitlab_hook | `v4.0.0` |
| redmine_dashboard | jgraichen/redmine_dashboard | `v2.16.0` |
| Opale | gagnieray/opale | `1.7.2` |
| kanban | happy-se-life/kanban | `master` |
| additionals | alphanodes/additionals | `4.6.0` |
| additional_tags | alphanodes/additional_tags | `4.6.0` |
| redmine_indicator | fraoustin/redmine_indicator | `master` |
| redmine_xlsx_format_issue_exporter | two-pack/redmine_xlsx_format_issue_exporter | `0.3.0` |
| redmine_dmsf | picman/redmine_dmsf | `v5.2.0` |
| redmine_startpage | duanejevon/redmine_startpage | `0.2.2` |
| redmine_bots | southbridgeio/redmine_bots | `v5.0.7` |
| redmine_2fa | southbridgeio/redmine_2fa | `v1.7.7` |

DMSF on Ruby 4: the Gemfile line for `ostruct` is removed because that gem is already installed locally and a second declaration breaks Bundler. The `pstore` line is kept, because Ruby 4 will not load it unless the Gemfile lists it. The test-only `rails-controller-testing` line is removed so the entrypoint can parse the Gemfile.

`redmine_bots` is patched for Rails 8 (`enum :protocol`) and for a removed Sidekiq logger call. When bots are installed, `slack-ruby-client` is pinned to `0.17.0` because `slack-ruby-bot` does not work with the 3.x client. `redmine_2fa` has leftover `unloadable` calls stripped out.

With DMSF enabled, ActiveStorage is turned on in `config/application.rb` and the WebDAV middleware from `additional_environment.rb` is inserted. With DMSF disabled, neither of those runs.

## Certificates

Put `*.crt` files in `certs/` and set `INSTALL_LOCAL_CERT=true`. The files are copied into `/usr/local/share/ca-certificates` and registered with `update-ca-certificates`. When the flag is `false`, the directory is still copied during the build and then deleted; nothing from it is trusted.

`REMOTE_CA_URL` is independent. A non-empty URL is fetched with `curl -k` (the CA host may present the certificate that is being installed) and saved as `remote-ca.crt`.

## Image size

A full build with LibreOffice is several gigabytes. The largest optional pieces are LibreOffice and the CJK fonts. Compilers are installed for native gems and removed after `bundle install`, but they remain in an earlier image layer. Turning plugins off skips their download and their gems.

## Apt mirrors

Debian Trixie publishes an uncompressed `Packages` index that current mirrors return as 404. Apt insists on that file and the update fails. The Dockerfile forces `xz` then `gz` indexes, points `deb.debian.org` at `http://mirror.yandex.ru`, and raises the HTTP timeout so a slow link can finish the index download.
