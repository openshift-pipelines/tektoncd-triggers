ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.22
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:c0e70387664f30cd9cf2795b547e4a9a51002c44a4a86aa9335ab030134bf392

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/triggers
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/eventlistenersink \
    ./cmd/eventlistenersink

FROM $RUNTIME
ARG VERSION=triggers-main

ENV CONTROLLER=/usr/local/bin/eventlistenersink \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/eventlistenersink /ko-app/eventlistenersink
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-triggers-eventlistenersink-rhel8-container" \
      name="openshift-pipelines/pipelines-triggers-eventlistenersink-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Triggers Eventlistenersink" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Triggers Eventlistenersink" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Triggers Eventlistenersink" \
      io.k8s.description="Red Hat OpenShift Pipelines Triggers Eventlistenersink" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN microdnf install -y shadow-utils
RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/eventlistenersink"]
