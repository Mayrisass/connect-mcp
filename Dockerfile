# Runtime image for @quidli/connect-mcp (Base44 dev environment).
#
# Only the manifests are copied: dependencies are installed at image build
# time (cached, no network at container start), while the application source
# is bind-mounted at /workspace so edits stay live.
FROM node:22

ENV NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

WORKDIR /opt/deps
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund \
 && npm install --no-save --no-package-lock --no-audit --no-fund tsx

WORKDIR /workspace
