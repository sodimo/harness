FROM scratch AS ctx

COPY build_files /ctx/build_files
COPY system_files /ctx/system_files
COPY cosign.pub /ctx/cosign.pub

FROM ghcr.io/ublue-os/brew:latest AS brew

FROM quay.io/fedora/fedora-bootc:44

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --network=none \
    bash /ctx/build_files/00-base-pre.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    bash /ctx/build_files/00-base-fetch.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=bind,from=brew,source=/system_files,target=/ctx/brew_files \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --network=none \
    cp -avf /ctx/brew_files/. / && \
    bash /ctx/build_files/00-base-post.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    bash /ctx/build_files/01-copr-fetch.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    bash /ctx/build_files/01-theme-fetch.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --network=none \
    bash /ctx/build_files/01-theme-post.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --network=none \
    bash /ctx/build_files/kargs/set-kargs.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    bash /ctx/build_files/99-misc-fetch.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --network=none \
    bash /ctx/build_files/99-misc-post.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --network=none \
    bash /ctx/build_files/99-dracut.sh

RUN rm -rf /var/* && mkdir /var/tmp && bootc container lint

LABEL containers.bootc=1 \
      org.opencontainers.image.title="Harness" \
      org.opencontainers.image.description="Personal Fedora 44 bootc image — Niri + QuickShell + greetd" \
      org.opencontainers.image.source="https://github.com/mecattaf/harness" \
      org.opencontainers.image.vendor="mecattaf"
