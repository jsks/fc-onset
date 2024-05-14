FROM debian:trixie-slim

LABEL org.opencontainers.image.source="https://github.com/jsks/fc-onset" \
      org.opencontainers.image.authors="Joshua Krusell <joshua.krusell@gu.se>" \
      org.opencontainers.image.description="Container image for the fc-onset project"

ARG CMDSTAN_VERSION=2.34.1 \
    QUARTO_VERSION=1.4.551 \
    MAKE_VERSION=4.4 \
    YQ_VERSION=4.42.1

RUN rm -rf /etc/apt/apt.conf.d/docker-clean
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        checkinstall \
        curl \
        gfortran \
        git \
        fonts-texgyre \
        fonts-texgyre-math \
        libcurl4-openssl-dev \
        libopenblas0-pthread \
        libopenblas-pthread-dev \
        lmodern \
        locales \
        r-base-core \
        texlive-latex-base \
        texlive-latex-recommended \
        texlive-luatex \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
        && locale-gen en_US.utf8 \
        && /usr/sbin/update-locale LANG=en_US.UTF-8

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

# Install cmdstan
RUN curl -LO https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/cmdstan-${CMDSTAN_VERSION}.tar.gz \
    && mkdir -p ~/.cmdstan \
    && tar -xzf cmdstan-${CMDSTAN_VERSION}.tar.gz -C ~/.cmdstan/

COPY etc/cmdstan/local ~/.cmdstan/cmdstan-${CMDSTAN_VERSION}/make/local
RUN cd ~/.cmdstan/cmdstan-${CMDSTAN_VERSION} && make -j$(nproc) build

# Install Quarto + Pandoc
RUN curl -LO https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    dpkg -i quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    ln -s /opt/quarto/bin/tools/x86_64/pandoc /usr/local/bin/pandoc && \
    rm quarto-${QUARTO_VERSION}-linux-amd64.deb

# Install latest version of Make - required for .WAIT feature in Makefile
RUN curl -LO https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz && \
    tar -xvf make-${MAKE_VERSION}.tar.gz && \
    cd make-${MAKE_VERSION} && \
    ./configure && \
    make -j $(nproc) && \
    checkinstall -y -D --nodoc --pkgname=make --pkgversion=${MAKE_VERSION} make install && \
    cd ../ && rm -rf make-${MAKE_VERSION} make-${MAKE_VERSION}.tar.gz

# Install go-yq - for wordcount
RUN curl -L https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64.tar.gz -o - | \
    tar xz && mv yq_linux_amd64 /usr/local/bin/yq

# Install R packages with renv
ADD renv-archive.tar.gz /pkg
WORKDIR /pkg

ENV _R_SHLIB_STRIP_=TRUE \
    RENV_CONFIG_INSTALL_VERBOSE=TRUE

RUN --mount=type=cache,target=/root/.cache/R/renv \
    mkdir -p ~/.R && mv etc/R/Makevars ~/.R/Makevars && \
    MAKEFLAGS="-j$(nproc)" Rscript -e "renv::restore()" -e "renv::isolate()"

# Project directory
RUN mkdir -p /proj
WORKDIR /proj

ENV RENV_PATHS_RENV=/pkg/renv

CMD make init && make -O -j $(nproc) models && make wp
