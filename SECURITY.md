# Security

This repository packages a Redmine 7 image (official `redmine:latest`, PostgreSQL 18, optional plugins). It is not the Redmine core or the upstream plugin source.

## Reporting

Report a problem in this packaging (Dockerfile, compose, config copied into the image) privately to the maintainers. Do not open a public issue that includes exploit steps, passwords, API keys, or the live `REDMINE_SECRET_KEY_BASE`.

Vulnerabilities in Redmine itself or in a plugin belong with that project. Plugins are fetched at build time from the GitHub refs pinned in `redmine.dockerfile`. `kanban` and `redmine_indicator` track `master`, so their contents can change between builds.

## Secrets in this repo

`docker-compose.yaml` is a local development stack. Before the instance is reachable beyond your machine, replace:

- `REDMINE_SECRET_KEY_BASE` (it signs cookies and sessions; rotating it logs everyone out)
- `POSTGRES_PASSWORD` (the committed value is `redmine`, and the database user and database name are also `redmine`)
- the SMTP password in `redmine/configuration.yml` (the committed value is the placeholder `change_me`)

The SMTP host and mailbox in `redmine/configuration.yml` are real settings for this deployment. Do not replace the placeholder password with a live one and commit it.

`certs/*.crt` are public CA certificates. Do not commit the matching private key, or any `*.key`, `*.pem` with a private key, bot token, or OAuth client secret.

OAuth client secrets, Telegram bot tokens, and user API keys are stored in the Redmine database after you configure the plugins. They do not belong in git. `pgdata` holds password hashes and those secrets; `redmine_files` holds attachments. `docker compose down -v` deletes both.

## Network

Compose publishes Redmine on `0.0.0.0:3000` as plain HTTP. PostgreSQL is not published on the host; only the `redmine` container talks to it. Put TLS in front of port 3000 before exposing the app.

The official image creates `admin` / `admin` on first boot and requires a password change. Do not leave that password in place.

`REDMINE_PLUGINS_MIGRATE=true` runs plugin migrations as the container starts. That is expected. Do not point this compose file at a production database that you have not backed up.

## Plugins and extra surface

| Piece | What to watch |
| --- | --- |
| `redmine_dmsf` | Turns on ActiveStorage and inserts the DMSF WebDAV middleware. Documents on disk live under the Redmine tree; attachments also use the `redmine_files` volume. The image relaxes the ImageMagick PDF policy to `read\|write` so previews work. |
| `redmine_gitlab_hook` | Public webhook endpoint. Configure the hook token in Redmine and do not leave it empty. |
| `redmine_oauth` | Client secrets stay in the database. |
| `redmine_bots`, `redmine_2fa` | Bot tokens and one-time secrets stay in the database. `redmine_2fa` is useless without `redmine_bots`. |
| REST API | Leave it off unless something needs it. When it is on, issue keys are credentials. |
| `REMOTE_CA_URL` | The fetch uses `curl -k`, so TLS verification is skipped for that download. Prefer `INSTALL_LOCAL_CERT=true` and a file in `certs/` when you can. |
| `INSTALL_LOCAL_CERT` | Only certificates in `certs/` are added to the trust store, and only when this is `true`. An empty URL does not download a CA. |

Turning a plugin build arg to `false` removes that code from the image. `additional_tags` still requires `additionals`, and `redmine_2fa` still requires `redmine_bots`; the build fails if those pairs are split.
