FROM gcr.io/distroless/static-debian12@sha256:a9fcaedd4c9b59e12dd65d954f0b5044f19b0647a8a3712e77205df9e7b102cd

# Build context is provided by goreleaser (see .goreleaser.yaml), which lays
# out pre-built binaries under linux/<arch>/.
ARG TARGETPLATFORM

COPY ${TARGETPLATFORM}/etcd /usr/local/bin/
COPY ${TARGETPLATFORM}/etcdctl /usr/local/bin/
COPY ${TARGETPLATFORM}/etcdutl /usr/local/bin/

WORKDIR /var/etcd/
WORKDIR /var/lib/etcd/

EXPOSE 2379 2380

# Define default command.
CMD ["/usr/local/bin/etcd"]
