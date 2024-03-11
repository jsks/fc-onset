###
# Multi-stage build to avoid accumulating build dependencies in the final image
#
# 1. Base image with build-essential (gcc/g++, make, etc.)
# 2. Build CmdStan and compile stan models
# 3. Final image with R + dependencies and project files

###
# Common base for each stage
FROM debian:trixie-slim AS base

RUN rm -rf /etc/apt/apt.conf.d/docker-clean
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends build-essential curl locales && \
    rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
        && locale-gen en_US.utf8 \
        && /usr/sbin/update-locale LANG=en_US.UTF-8

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

###
# Cmdstan stage to compile Stan models
FROM base AS cmdstan

ARG CMDSTAN_VERSION=2.34.1

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates patchelf

RUN curl -LO https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/cmdstan-${CMDSTAN_VERSION}.tar.gz \
    && mkdir -p cmdstan \
    && tar -xzf cmdstan-${CMDSTAN_VERSION}.tar.gz --strip 1 -C cmdstan

WORKDIR /cmdstan

COPY etc/cmdstan/local /cmdstan/make/local
COPY stan/*.stan /cmdstan/models/
RUN make -j$(nproc) models/hierarchical_probit models/sim && \
    patchelf --set-rpath /usr/local/lib models/hierarchical_probit && \
    patchelf --set-rpath /usr/local/lib models/sim && \
    strip -s models/hierarchical_probit models/sim stan/lib/stan_math/lib/tbb/libtbb.so.2

###
# Final stage to create our project image with R + quarto/latex
FROM base

ARG QUARTO_VERSION=1.4.551 \
    MAKE_VERSION=4.4

LABEL org.opencontainers.image.source="https://github.com/jsks/fc-onset" \
      org.opencontainers.image.authors="Joshua Krusell <joshua.krusell@gu.se>" \
      org.opencontainers.image.description="Container image for the fc-onset project"

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        checkinstall \
        gfortran \
        fonts-texgyre \
        fonts-texgyre-math \
        libcurl4-openssl-dev \
        libopenblas0-pthread \
        libopenblas-pthread-dev \
        lmodern \
        r-base-core \
        texlive-latex-base \
        texlive-latex-recommended \
        texlive-luatex \
        zlib1g-dev && \
    rm -rf  /var/lib/apt/lists/*

# Install Quarto
RUN curl -LO https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    dpkg -i quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    rm quarto-${QUARTO_VERSION}-linux-amd64.deb

# Install latest version of Make - required for .WAIT feature in Makefile
RUN curl -LO https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz && \
    tar -xvf make-${MAKE_VERSION}.tar.gz && \
    cd make-${MAKE_VERSION} && \
    ./configure && \
    make -j $(nproc) && \
    checkinstall -y -D --nodoc --pkgname=make --pkgversion=${MAKE_VERSION} make install && \
    cd ../ && rm -rf make-${MAKE_VERSION} make-${MAKE_VERSION}.tar.gz

ADD fc-onset-HEAD.tar.gz /proj
WORKDIR /proj

ENV _R_SHLIB_STRIP_=TRUE \
    RENV_CONFIG_INSTALL_VERBOSE=TRUE

RUN --mount=type=cache,target=/root/.cache/R/renv \
    mkdir -p ~/.R && mv etc/R/Makevars ~/.R/Makevars && \
    MAKEFLAGS="-j$(nproc)" Rscript -e "renv::restore()" -e "renv::isolate()"

COPY --from=cmdstan /cmdstan/models/hierarchical_probit /cmdstan/models/sim /proj/stan/
COPY --from=cmdstan /cmdstan/stan/lib/stan_math/lib/tbb/libtbb.so.2 /usr/local/lib/

CMD make init && make -O -j $(nproc) models && OUTPUT_DIR=/proj/output make
