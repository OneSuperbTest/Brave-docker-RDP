FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    RDP_USER=rdp \
    HOME=/data/home/rdp \
    XDG_CONFIG_HOME=/data/home/rdp/.config \
    XDG_CACHE_HOME=/tmp/rdp-cache \
    XDG_DATA_HOME=/data/home/rdp/.local/share \
    XDG_STATE_HOME=/data/home/rdp/.local/state

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg \
    xrdp xorgxrdp xorg dbus-x11 \
    openbox \
    pcmanfm \
    fonts-liberation fonts-noto-core fonts-noto-cjk \
    mesa-utils libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers \
    pulseaudio \
    procps psmisc iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Brave's official Debian repository.
RUN install -d -m 0755 /usr/share/keyrings \
    && curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
       https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
    && curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
       https://brave-browser-apt-release.s3.brave.com/brave-browser.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends brave-browser \
    && rm -rf /var/lib/apt/lists/*

# Dedicated non-root account. Its home is on the Railway volume.
RUN useradd --create-home --home-dir /data/home/rdp --shell /bin/bash rdp \
    && usermod -aG audio,video rdp \
    && mkdir -p /data/home/rdp /data/Downloads /data/logs /data/cache \
    && chown -R rdp:rdp /data \
    && mkdir -p /var/run/xrdp /var/log/xrdp \
    && chown xrdp:xrdp /var/run/xrdp /var/log/xrdp \
    && chmod 1777 /tmp

COPY xrdp.ini /etc/xrdp/xrdp.ini
COPY sesman.ini /etc/xrdp/sesman.ini
COPY xorg.conf /etc/X11/xrdp/xorg.conf
COPY startwm.sh /etc/xrdp/startwm.sh
COPY openbox/autostart /etc/xdg/openbox/autostart
COPY brave-launcher.sh /usr/local/bin/brave-launcher
COPY start.sh /usr/local/bin/start.sh

RUN chmod 0755 /etc/xrdp/startwm.sh /usr/local/bin/start.sh /usr/local/bin/brave-launcher \
    && mkdir -p /etc/xrdp/certificates \
    && chmod 0700 /etc/xrdp/certificates

EXPOSE 3389
ENTRYPOINT ["/usr/local/bin/start.sh"]
