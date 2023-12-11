FROM alpine:latest

ARG V_VERSION="master"

WORKDIR /tmp/v


RUN apk update && \
    apk add --no-cache git make gcc libc-dev libatomic

RUN git clone https://github.com/vlang/v.git /tmp/v


# checkout latest tag for stability:
RUN git checkout ${V_VERSION}

RUN make

RUN apk --purge del git make
# keep essentials: libatomic, gcc, libc-dev

RUN /tmp/v/v symlink

CMD ["v"]
