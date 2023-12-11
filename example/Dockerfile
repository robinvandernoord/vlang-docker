FROM robinvandernoord/vlang:latest

COPY src /tmp/src

RUN v /tmp/src -o /bin/vlang_docker_binary

RUN rm /tmp/src -r

CMD ["vlang_docker_binary"]
