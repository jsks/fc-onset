###
# Multi-stage build to avoid accumulating build dependencies in the final image
#
# 1. Base image with build-essential (gcc/g++, make, etc.)
# 2. Build CmdStan and compile stan models
# 3. Download/build deb packages for newest version of Make and Quarto
# 4. Final image with R and project files
FROM debian:trixie-slim AS base

RUN rm -rf /etc/apt/apt.conf.d/docker-clean
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*

FROM base AS cmdstan

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl patchelf

RUN curl -LO 'https://github.com/stan-dev/cmdstan/releases/download/v2.34.1/cmdstan-2.34.1.tar.gz' \
    && mkdir -p cmdstan \
    && tar -xzf cmdstan-2.34.1.tar.gz --strip 1 -C cmdstan

WORKDIR /cmdstan

RUN mkdir -p /cmdstan/models
COPY stan/*.stan /cmdstan/models/
RUN make -j$(nproc) models/hierarchical_probit models/sim && \
    patchelf --set-rpath /usr/local/lib models/hierarchical_probit && \
    patchelf --set-rpath /usr/local/lib models/sim

FROM base AS deb

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates checkinstall curl

RUN curl -LO https://ftp.gnu.org/gnu/make/make-4.4.tar.gz && \
    tar -xvf make-4.4.tar.gz && \
    cd make-4.4 && \
    ./configure && \
    make -j $(nproc) && \
    checkinstall -y -D --nodoc --install=no --pkgname=make --pkgversion=4.4 make install

RUN curl -LO https://quarto.org/download/latest/quarto-linux-amd64.deb

FROM base

RUN --mount=type=cache,target=/var/cache/apt apt-get update && \
    apt-get install -y --no-install-recommends \
        gfortran \
        libcurl4-openssl-dev \
        libopenblas0-pthread \
        libopenblas-pthread-dev \
        r-base-core \
        pandoc \
        texlive-luatex \
        texlive-latex-base \
        tex-gyre \
        zlib1g-dev && \
    rm -rf  /var/lib/apt/lists/*

COPY --from=deb /make-4.4/make_4.4-1_amd64.deb /quarto-linux-amd64.deb /tmp/
RUN dpkg -i /tmp/quarto-linux-amd64.deb && dpkg -i /tmp/make_4.4-1_amd64.deb

ADD fc-onset-HEAD.tar.gz /proj
WORKDIR /proj

RUN --mount=type=cache,target=/root/.cache/R/renv \
    MAKEFLAGS="-j$(nproc)" Rscript -e "renv::restore()" -e "renv::isolate()"

COPY --from=cmdstan /cmdstan/models/hierarchical_probit /cmdstan/models/sim /proj/stan/
COPY --from=cmdstan /cmdstan/stan/lib/stan_math/lib/tbb/libtbb.so.2 /usr/local/lib/

CMD make bootstrap && make -O -j8 models && OUTPUT_DIR=/proj/output make
