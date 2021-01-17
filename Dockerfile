FROM nginx:alpine AS builder

ENV NGINX_VERSION=1.17.8
ENV HEADERS_MORE_VERSION=v0.33
ENV DAV_EXT_VERSION=v3.0.0

# Download sources
RUN wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O nginx.tar.gz && \
  wget "https://github.com/openresty/headers-more-nginx-module/archive/${HEADERS_MORE_VERSION}.tar.gz" -O headers-more-nginx-module.tar.gz && \
  wget "https://github.com/arut/nginx-dav-ext-module/archive/${DAV_EXT_VERSION}.tar.gz" -O nginx-dav-ext-module.tar.gz

# For latest build deps, see https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile
RUN apk add --no-cache --virtual .build-deps \
  gcc \
  libc-dev \
  make \
  openssl-dev \
  pcre-dev \
  zlib-dev \
  linux-headers \
  curl \
  gnupg \
  libxslt-dev \
  gd-dev \
  geoip-dev

# Reuse same cli arguments as the nginx:alpine image used to build
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') && \
  CONFARGS=${CONFARGS/-Os -fomit-frame-pointer/-Os} && \
  mkdir /usr/src && \
  tar -zxC /usr/src -f nginx.tar.gz && \
  mkdir ./nginx-dav-ext-module && \
  mkdir ./headers-more-nginx-module && \
  tar -xzC ./nginx-dav-ext-module -f nginx-dav-ext-module.tar.gz --strip-components 1 && \
  tar -xzC ./headers-more-nginx-module -f headers-more-nginx-module.tar.gz --strip-components 1 && \
  DAV_EXT_DIR="$(pwd)/nginx-dav-ext-module" && \
  HEADERS_MORE_DIR="$(pwd)/headers-more-nginx-module" && \
  cd /usr/src/nginx-$NGINX_VERSION && \
  ./configure --with-compat --with-http_dav_module $CONFARGS --add-module=$HEADERS_MORE_DIR --add-module=$DAV_EXT_DIR && \
  make && make install

FROM nginx:alpine
LABEL maintainer="Jemy Zhang<jemy.zhang@gmail.com>"
ARG nginx_version
ENV NGINX_VERSION=$nginx_version
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/lib/nginx /usr/lib/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx

EXPOSE 80
STOPSIGNAL SIGTERM
CMD ["nginx", "-g", "daemon off;"]
