FROM debian:13.2

RUN apt-get update && \
    apt-get install -y \
    git \
    make \
    python3 \
    python3-pip \
    python3-venv \
    ruby \
    gem \
    ghostscript \
    libxml2-utils \
    eslint \
    xsltproc \
    enscript \
    lpr \
    aps-filter \
    html2ps \
    groff \
    imagemagick

RUN gem install bundler

RUN bundler install

WORKDIR /workspace

CMD ["/bin/bash"]
