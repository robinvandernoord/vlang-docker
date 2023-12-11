FROM alpine:latest

RUN apk update && \
    apk add --no-cache git

RUN git clone https://github.com/vlang/v.git /tmp/v


RUN apk update && \
    apk add --no-cache make gcc libc-dev libatomic

WORKDIR /tmp/v

# checkout latest tag for stability:
RUN git checkout $(git describe --tags `git rev-list --tags --max-count=1`)

RUN make

RUN apk --purge del git make
# keep essentials: libatomic, gcc, libc-dev

RUN /tmp/v/v symlink

CMD ["v"]
