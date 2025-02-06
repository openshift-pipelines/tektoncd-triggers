ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:3902bab19972cd054fd08b2a4e08612ae7e68861ee5d9a5cf22d828f27e2f479

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/triggers
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/interceptors \
    ./cmd/interceptors

FROM $RUNTIME
ARG VERSION=triggers-main

ENV CONTROLLER=/usr/local/bin/interceptors \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/interceptors /ko-app/interceptors
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-triggers-core-interceptors-rhel8-container" \
      name="openshift-pipelines/pipelines-triggers-core-interceptors-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Triggers Core Interceptors" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Triggers Core Interceptors" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Triggers Core Interceptors" \
      io.k8s.description="Red Hat OpenShift Pipelines Triggers Core Interceptors" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN microdnf install -y shadow-utils
RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/interceptors"]
