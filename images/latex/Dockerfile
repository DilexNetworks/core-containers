ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN apk add --no-cache \
    make \
    perl \
    texlive \
    texlive-binextra \
    texlive-latexrecommended \
    texlive-latexextra \
    texlive-xetex

# Add the Metropolis Beamer theme.
#RUN git clone --depth 1 https://github.com/matze/mtheme /tmp/mtheme \
#    && make -C /tmp/mtheme sty install \
#    && rm -rf /tmp/mtheme

WORKDIR /files
ENTRYPOINT ["/usr/bin/latexmk", "-pdf"]