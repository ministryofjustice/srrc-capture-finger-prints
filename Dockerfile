# Build args available to all stages
ARG BUILD_NUMBER
ARG GIT_REF
ARG GIT_BRANCH

# Stage: build assets
# Debian-based (glibc) to match the distroless runtime image - node_modules
# installed here must be compatible with the final stage
FROM node:24-bookworm-slim AS build

ARG BUILD_NUMBER
ARG GIT_REF
ARG GIT_BRANCH

# Cache breaking and ensure required build / git args defined
RUN test -n "$BUILD_NUMBER" || (echo "BUILD_NUMBER not set" && false)
RUN test -n "$GIT_REF" || (echo "GIT_REF not set" && false)
RUN test -n "$GIT_BRANCH" || (echo "GIT_BRANCH not set" && false)

WORKDIR /app

COPY package*.json .allowed-scripts.mjs .npmrc ./
RUN NPM_CONFIG_AUDIT=false NPM_CONFIG_FUND=false npm run setup
ENV NODE_ENV='production'

COPY . .
RUN npm run build

RUN npm prune --no-audit --no-fund --omit=dev

# Stage: copy production assets and dependencies
# Distroless entrypoint is the node binary, runs as root by default and has no
# shell, package manager or npm
FROM gcr.io/distroless/nodejs24-debian12

ARG BUILD_NUMBER
ARG GIT_REF
ARG GIT_BRANCH

WORKDIR /app

# 65532 is the distroless "nonroot" user
COPY --from=build --chown=65532:65532 \
        /app/package.json \
        /app/package-lock.json \
        ./

COPY --from=build --chown=65532:65532 \
        /app/dist ./dist

COPY --from=build --chown=65532:65532 \
        /app/node_modules ./node_modules

EXPOSE 3000
ENV BUILD_NUMBER=${BUILD_NUMBER}
ENV GIT_REF=${GIT_REF}
ENV GIT_BRANCH=${GIT_BRANCH}
ENV NODE_ENV='production'
ENV TZ='Europe/London'
USER 65532

CMD [ "dist/server.js" ]
