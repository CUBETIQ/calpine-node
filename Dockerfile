FROM cubetiq/calpine-os-linux:latest
LABEL maintainer="sombochea@cubetiqs.com"

# Build with root access
USER root

ENV NODE_VERSION 16.17.0
ENV NODE_SHA256 6c94de8608fcd5b992f5f804c2d03bc3a7f422426760b1b80ea4ced486a694fe
ENV USER_UID 1001

RUN addgroup -g ${USER_UID} node \
  && adduser -u ${USER_UID} -G node -s /bin/sh -D node \
  && apk add --no-cache \
  libstdc++ \
  && apk add --no-cache --virtual .build-deps \
  curl \
  && ARCH= && alpineArch="$(apk --print-arch)" \
  && case "${alpineArch##*-}" in \
  x86_64) \
  ARCH='x64' \
  CHECKSUM=$NODE_SHA256 \
  ;; \
  *) ;; \
  esac \
  && if [ -n "${CHECKSUM}" ]; then \
  set -eu; \
  DL_ROOT="https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"; \
  echo "Downloading Node.js from ${DL_ROOT}"; \
  curl -fsSLO --compressed $DL_ROOT; \
  echo "$CHECKSUM  node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
  else \
  echo "Building from source" \
  # backup build
  && apk add --no-cache --virtual .build-deps-full \
  binutils-gold \
  g++ \
  gcc \
  gnupg \
  libgcc \
  linux-headers \
  make \
  python3 \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && for key in \
  4ED778F539E3634C779C87C6D7062848A1AB005C \
  94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
  74F12602B6F1C4E913FAA37AD3A89613643B6201 \
  71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
  8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
  C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
  DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
  A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
  108F52B48DB57BB0CC439B2997B01419BD92F80A \
  B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
  gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
  gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
  gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xf "node-v$NODE_VERSION.tar.xz" \
  && cd "node-v$NODE_VERSION" \
  && ./configure \
  && make -j$(getconf _NPROCESSORS_ONLN) V= \
  && make install \
  && apk del .build-deps-full \
  && cd .. \
  && rm -Rf "node-v$NODE_VERSION" \
  && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt; \
  fi \
  && rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" \
  && apk del .build-deps

ARG PNPM_VERSION=7.9.5
ENV PNPM_HOME=/root/.local/share/pnpm
ENV PATH=$PATH:$PNPM_HOME

RUN echo "Installing PNPM version: $PNPM_VERSION" && \
  apk add --no-cache curl && \
  curl -fsSL "https://github.com/pnpm/pnpm/releases/download/v${PNPM_VERSION}/pnpm-linuxstatic-x64" -o /bin/pnpm && chmod +x /bin/pnpm && \
  apk del curl

# Install yarn from npm package
RUN npm -g i yarn

# Checking packages version
RUN echo "NODE: $(node --version)" \
  && echo "NPM: $(npm --version)" \
  && echo "NPX: $(npx --version)" \
  && echo "YARN: $(yarn --version)" \
  && echo "PNPM: $(pnpm --version)"

COPY entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]

CMD [ "node" ]