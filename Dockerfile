# Odoo (PSMS) - production image
# Built by GitHub Actions and published to ghcr.io/dilanthapsms/oodo-psms
FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Runtime libraries, fonts and wkhtmltopdf (PDF reports)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 libldap-2.5-0 libsasl2-2 libxml2 libxslt1.1 libjpeg62-turbo zlib1g libffi8 libmagic1 \
        postgresql-client curl ca-certificates fontconfig \
        fonts-dejavu-core fonts-noto-core xfonts-75dpi xfonts-base \
    && curl -fsSL -o /tmp/wkhtmltox.deb \
        https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb \
    && apt-get install -y --no-install-recommends /tmp/wkhtmltox.deb \
    && rm -f /tmp/wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies (build tools installed and removed in the same layer)
COPY requirements.txt /opt/odoo/requirements.txt
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential libpq-dev libldap2-dev libsasl2-dev libxml2-dev libxslt1-dev \
        libjpeg-dev zlib1g-dev libffi-dev \
    && pip install -r /opt/odoo/requirements.txt rl-renderPM \
    && apt-get purge -y --auto-remove build-essential libpq-dev libldap2-dev libsasl2-dev \
        libxml2-dev libxslt1-dev libjpeg-dev zlib1g-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --home-dir /var/lib/odoo --shell /bin/bash odoo

# Free community accounting apps by Odoo Mates (LGPL-3), branch 20.0, pinned commit
ARG ODOOMATES_REF=0cb8d6123115aab8b9fdb10b27d4176dd6c3a3db
RUN mkdir -p /mnt/extra-addons \
    && curl -fsSL https://github.com/odoomates/odooapps/archive/${ODOOMATES_REF}.tar.gz \
       | tar -xz -C /mnt/extra-addons --strip-components=1 \
    && rm -f /mnt/extra-addons/*.md \
    && pip install pypdf

# Free MuK Backend Theme (LGPL-3) - app grid home screen; only muk_web_* modules, pinned commit
ARG MUK_REF=12dea039322ca33ca4f614d351f4bbfb7c9f5fd1
RUN curl -fsSL https://github.com/muk-it/odoo-modules/archive/${MUK_REF}.tar.gz \
       | tar -xz -C /mnt/extra-addons --strip-components=1 --wildcards "odoo-modules-${MUK_REF}/muk_web_*"

# Fahires custom modules (MIRA GST statements, Sales pipeline & approvals, ...)
COPY fahires_addons.zip /tmp/fahires_addons.zip
RUN python3 -m zipfile -e /tmp/fahires_addons.zip /mnt/extra-addons/ && rm -f /tmp/fahires_addons.zip

WORKDIR /opt/odoo
COPY . /opt/odoo
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /opt/odoo/odoo-bin \
    && mkdir -p /etc/odoo /mnt/extra-addons /var/lib/odoo \
    && chown -R odoo:odoo /etc/odoo /mnt/extra-addons /var/lib/odoo

USER odoo
EXPOSE 8069 8072
ENTRYPOINT ["/entrypoint.sh"]
