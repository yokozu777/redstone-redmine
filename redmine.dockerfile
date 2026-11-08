# Built from docker-compose.yaml
FROM redmine:trixie

# INSTALL_LIBREOFFICE=false saves ~500MB (DMSF cannot convert docx/xlsx)
# INSTALL_CJK_FONTS=false saves ~150MB (Chinese/Japanese/Korean fonts)
# INSTALL_LOCAL_CERT=true installs certificates from ./certs into the trusted CA store
# REMOTE_CA_URL, when set, downloads a CA from that URL (for example https://ca.mxhash.dev:8443/roots.pem)
# Plugins: false skips the download and install. redmine_2fa requires redmine_bots; additional_tags requires additionals.
ARG INSTALL_LIBREOFFICE=true
ARG INSTALL_CJK_FONTS=false
ARG INSTALL_LOCAL_CERT=false
ARG REMOTE_CA_URL=
ARG INSTALL_REDMINE_OAUTH=true
ARG INSTALL_REDMINE_GITLAB_HOOK=true
ARG INSTALL_REDMINE_DASHBOARD=true
ARG INSTALL_OPALE=true
ARG INSTALL_KANBAN=true
ARG INSTALL_ADDITIONALS=true
ARG INSTALL_ADDITIONAL_TAGS=true
ARG INSTALL_REDMINE_INDICATOR=true
ARG INSTALL_XLSX_EXPORTER=true
ARG INSTALL_REDMINE_DMSF=true
ARG INSTALL_REDMINE_STARTPAGE=true
ARG INSTALL_REDMINE_BOTS=true
ARG INSTALL_REDMINE_2FA=true  

# The Release file lists an uncompressed trixie/main Packages index (~54 MB) that the mirrors do not have (404).
# apt prefers that file and fails the update. The xz/gz indexes exist, so use only those.
RUN set -eux; \
    printf '%s\n' \
      'Acquire::Languages "none";' \
      'Acquire::Retries "3";' \
      'Acquire::http::Timeout "300";' \
      'Acquire::https::Timeout "300";' \
      'Acquire::http::Pipeline-Depth "0";' \
      'Acquire::https::Pipeline-Depth "0";' \
      'Acquire::CompressionTypes::Order { "xz"; "gz"; };' \
      > /etc/apt/apt.conf.d/99compression; \
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do \
      [ -f "$f" ] || continue; \
      sed -i 's|https\?://deb.debian.org|http://mirror.yandex.ru|g' "$f"; \
    done; \
    apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      libcurl4-openssl-dev \
      pkg-config \
      zlib1g-dev \
      libxapian-dev \
      xapian-omega \
      imagemagick \
      libmagickwand-dev \
      libpq-dev \
      libyaml-dev \
      ghostscript \
      poppler-utils \
      fonts-dejavu \
    && if [ "$INSTALL_LIBREOFFICE" = "true" ]; then apt-get install -y --no-install-recommends libreoffice-writer libreoffice-calc libreoffice-impress; fi \
    && if [ "$INSTALL_CJK_FONTS" = "true" ]; then apt-get install -y --no-install-recommends fonts-noto-cjk; fi \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i 's/<policy domain="coder" rights="none" pattern="PDF" \/>/<policy domain="coder" rights="read|write" pattern="PDF" \/>/' /etc/ImageMagick-6/policy.xml || true

WORKDIR /usr/src/redmine

COPY redmine/plugins/ /usr/src/redmine/plugins/
RUN rm -rf \
      /usr/src/redmine/plugins/easy_gantt \
      /usr/src/redmine/plugins/easy_gantt_pro \
      /usr/src/redmine/plugins/easy_baseline \
 && chown -R redmine:redmine /usr/src/redmine/plugins

COPY redmine/additional_environment.rb /usr/src/redmine/config/additional_environment.rb
RUN chown redmine:redmine /usr/src/redmine/config/additional_environment.rb

COPY redmine/configuration.yml /usr/src/redmine/config/configuration.yml
COPY redmine/config/storage.yml /usr/src/redmine/config/storage.yml
COPY redmine/db/migrate/20170806125915_create_active_storage_tables.rb /usr/src/redmine/db/migrate/
RUN chown redmine:redmine /usr/src/redmine/config/storage.yml /usr/src/redmine/db/migrate/20170806125915_create_active_storage_tables.rb

COPY certs/ /tmp/local-certs/
RUN set -eux; \
    if [ "$INSTALL_LOCAL_CERT" = "true" ]; then \
      cp /tmp/local-certs/*.crt /usr/local/share/ca-certificates/; \
    fi; \
    if [ -n "$REMOTE_CA_URL" ]; then \
      curl -fsSLk -o /usr/local/share/ca-certificates/remote-ca.crt "$REMOTE_CA_URL"; \
    fi; \
    rm -rf /tmp/local-certs; \
    find /usr/local/share/ca-certificates -name '*.crt' -exec chmod 644 {} +; \
    update-ca-certificates

RUN if [ "$INSTALL_REDMINE_OAUTH" = "true" ]; then \
      set -euxo pipefail; \
      mkdir -p plugins/redmine_oauth && \
      curl -fsSL "https://codeload.github.com/kontron/redmine_oauth/tar.gz/refs/tags/v4.2.3" \
        | tar -xz --strip=1 -C plugins/redmine_oauth && \
      chown -R redmine:redmine plugins/redmine_oauth; \
    fi

RUN if [ "$INSTALL_REDMINE_GITLAB_HOOK" = "true" ]; then \
      set -euxo pipefail; \
      mkdir -p plugins/redmine_gitlab_hook && \
      curl -fsSL "https://codeload.github.com/phlegx/redmine_gitlab_hook/tar.gz/tags/v4.0.0" \
        | tar -xz --strip=1 -C plugins/redmine_gitlab_hook && \
      chown -R redmine:redmine plugins/redmine_gitlab_hook; \
    fi

ARG REDMINE_DASHBOARD_REF=refs/tags/v2.16.0
RUN if [ "$INSTALL_REDMINE_DASHBOARD" = "true" ]; then \
      set -euxo pipefail; \
      mkdir -p plugins/redmine_dashboard && \
      curl -fsSL "https://codeload.github.com/jgraichen/redmine_dashboard/tar.gz/${REDMINE_DASHBOARD_REF}" \
        | tar -xz --strip=1 -C plugins/redmine_dashboard && \
      chown -R redmine:redmine plugins/redmine_dashboard; \
    fi

ARG OPALE_REF=refs/tags/1.7.2
RUN if [ "$INSTALL_OPALE" = "true" ]; then \
      set -euxo pipefail; \
      tmpdir="$(mktemp -d)"; \
      curl -fsSL "https://codeload.github.com/gagnieray/opale/tar.gz/${OPALE_REF}" \
        | tar -xz -C "$tmpdir" --strip=1; \
      install -d /usr/src/redmine/public/themes/opale \
                 /usr/src/redmine/app/assets/themes/opale; \
      cp -a "$tmpdir"/. /usr/src/redmine/public/themes/opale/; \
      cp -a "$tmpdir"/. /usr/src/redmine/app/assets/themes/opale/; \
      test -f /usr/src/redmine/public/themes/opale/stylesheets/application.css; \
      chown -R redmine:redmine \
        /usr/src/redmine/public/themes/opale \
        /usr/src/redmine/app/assets/themes/opale; \
      rm -rf "$tmpdir"; \
    fi

ARG KANBAN_REF=refs/heads/master
RUN if [ "$INSTALL_KANBAN" = "true" ]; then \
      set -euxo pipefail; \
      install -d /usr/src/redmine/plugins/kanban; \
      curl -fsSL "https://codeload.github.com/happy-se-life/kanban/tar.gz/${KANBAN_REF}" \
        | tar -xz --strip=1 -C /usr/src/redmine/plugins/kanban; \
      chown -R redmine:redmine /usr/src/redmine/plugins/kanban; \
    fi

ARG ADDITIONALS_REF=refs/tags/4.6.0
RUN if [ "$INSTALL_ADDITIONALS" = "true" ]; then \
      set -euxo pipefail; \
      install -d /usr/src/redmine/plugins/additionals; \
      curl -fsSL "https://codeload.github.com/alphanodes/additionals/tar.gz/${ADDITIONALS_REF}" \
        | tar -xz --strip=1 -C /usr/src/redmine/plugins/additionals; \
      chown -R redmine:redmine /usr/src/redmine/plugins/additionals; \
    fi

ARG ADDITIONAL_TAGS_REF=refs/tags/4.6.0
RUN if [ "$INSTALL_ADDITIONAL_TAGS" = "true" ]; then \
      set -euxo pipefail; \
      if [ "$INSTALL_ADDITIONALS" != "true" ]; then \
        echo "additional_tags requires INSTALL_ADDITIONALS=true" >&2; \
        exit 1; \
      fi; \
      install -d /usr/src/redmine/plugins/additional_tags; \
      curl -fsSL "https://codeload.github.com/alphanodes/additional_tags/tar.gz/${ADDITIONAL_TAGS_REF}" \
        | tar -xz --strip=1 -C /usr/src/redmine/plugins/additional_tags; \
      chown -R redmine:redmine /usr/src/redmine/plugins/additional_tags; \
    fi

ARG INDICATOR_REF=refs/heads/master
RUN if [ "$INSTALL_REDMINE_INDICATOR" = "true" ]; then \
      set -euxo pipefail; \
      install -d /usr/src/redmine/plugins/redmine_indicator; \
      curl -fsSL "https://codeload.github.com/fraoustin/redmine_indicator/tar.gz/${INDICATOR_REF}" \
        | tar -xz --strip=1 -C /usr/src/redmine/plugins/redmine_indicator; \
      chown -R redmine:redmine /usr/src/redmine/plugins/redmine_indicator; \
    fi

ARG XLSX_EXPORTER_REF=refs/tags/0.3.0
RUN if [ "$INSTALL_XLSX_EXPORTER" = "true" ]; then \
      set -euxo pipefail; \
      install -d /usr/src/redmine/plugins/redmine_xlsx_format_issue_exporter; \
      curl -fsSL "https://codeload.github.com/two-pack/redmine_xlsx_format_issue_exporter/tar.gz/${XLSX_EXPORTER_REF}" \
        | tar -xz --strip=1 -C /usr/src/redmine/plugins/redmine_xlsx_format_issue_exporter; \
      chown -R redmine:redmine /usr/src/redmine/plugins/redmine_xlsx_format_issue_exporter; \
    fi

# On Ruby 4, ostruct is already installed locally; declaring it inside a source block breaks Bundler.
# Ruby 4 does not pull pstore into the bundle on its own, so the Gemfile declaration must stay.
ARG REDMINE_DMSF_REF=refs/tags/v5.2.0
RUN if [ "$INSTALL_REDMINE_DMSF" = "true" ]; then \
      set -euxo pipefail; \
      sed -i "s/# require 'active_storage\/engine'/require 'active_storage\/engine'/" /usr/src/redmine/config/application.rb; \
      install -d /usr/src/redmine/plugins/redmine_dmsf; \
      curl -fsSL "https://codeload.github.com/picman/redmine_dmsf/tar.gz/${REDMINE_DMSF_REF}" \
        | tar -xz --strip=1 -C /usr/src/redmine/plugins/redmine_dmsf; \
      sed -i -e "/^[[:space:]]*gem 'ostruct'/d" -e "/gem 'rails-controller-testing'/d" /usr/src/redmine/plugins/redmine_dmsf/Gemfile; \
      chown -R redmine:redmine /usr/src/redmine/plugins/redmine_dmsf; \
    fi

ARG STARTPAGE_REF=refs/tags/0.2.2
RUN if [ "$INSTALL_REDMINE_STARTPAGE" = "true" ]; then \
      set -euxo pipefail; \
      install -d /usr/src/redmine/plugins/redmine_startpage; \
      curl -fsSL "https://codeload.github.com/duanejevon/redmine_startpage/tar.gz/${STARTPAGE_REF}" \
        | tar -xz --strip=1 -C /usr/src/redmine/plugins/redmine_startpage; \
      chown -R redmine:redmine /usr/src/redmine/plugins/redmine_startpage; \
    fi

# redmine_2fa is two-factor authentication (Telegram, SMS, Google Authenticator). It requires redmine_bots.
ARG REDMINE_BOTS_REF=refs/tags/v5.0.7
RUN if [ "$INSTALL_REDMINE_BOTS" = "true" ]; then \
      set -euxo pipefail; \
      install -d /usr/src/redmine/plugins/redmine_bots; \
      curl -fsSL "https://codeload.github.com/southbridgeio/redmine_bots/tar.gz/${REDMINE_BOTS_REF}" \
        | tar -xz --strip=1 -C /usr/src/redmine/plugins/redmine_bots; \
      sed -i "/Sidekiq::Logging\.logger/d" /usr/src/redmine/plugins/redmine_bots/init.rb; \
      sed -i 's/enum protocol:/enum :protocol,/' /usr/src/redmine/plugins/redmine_bots/app/models/telegram_proxy.rb; \
      chown -R redmine:redmine /usr/src/redmine/plugins/redmine_bots; \
      echo "gem 'slack-ruby-client', '0.17.0'" >> Gemfile.local; \
    fi

ARG REDMINE_2FA_REF=refs/tags/v1.7.7
RUN if [ "$INSTALL_REDMINE_2FA" = "true" ]; then \
      set -euxo pipefail; \
      if [ "$INSTALL_REDMINE_BOTS" != "true" ]; then \
        echo "redmine_2fa requires INSTALL_REDMINE_BOTS=true" >&2; \
        exit 1; \
      fi; \
      install -d /usr/src/redmine/plugins/redmine_2fa; \
      curl -fsSL "https://codeload.github.com/southbridgeio/redmine_2fa/tar.gz/${REDMINE_2FA_REF}" \
        | tar -xz --strip=1 -C /usr/src/redmine/plugins/redmine_2fa; \
      find /usr/src/redmine/plugins/redmine_2fa -name '*.rb' -exec sed -i '/unloadable/d' {} \;; \
      chown -R redmine:redmine /usr/src/redmine/plugins/redmine_2fa; \
    fi

RUN mkdir -p /usr/local/bundle /home/redmine/.bundle \
 && chown -R redmine:redmine /usr/local/bundle /usr/src/redmine /home/redmine \
 && chmod -R o-w /usr/local/bundle && \
    bundle config set without 'development test' && \
    bundle install && \
    apt-get update && apt-get purge -y build-essential pkg-config && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/bundle /home/redmine/.bundle \
 && chown -R redmine:redmine /usr/src/redmine /usr/local/bundle /home/redmine \
 && chmod -R o-w /usr/local/bundle
