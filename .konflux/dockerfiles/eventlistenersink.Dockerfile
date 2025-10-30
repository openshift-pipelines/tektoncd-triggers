ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:34880b64c07f28f64d95737f82f891516de9a3b43583f39970f7bf8e4cfa48b7

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/triggers
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -tags strictfipsruntime -v -o /tmp/eventlistenersink \
    ./cmd/eventlistenersink

FROM $RUNTIME
ARG VERSION=triggers-1.18

ENV CONTROLLER=/usr/local/bin/eventlistenersink \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/eventlistenersink /ko-app/eventlistenersink
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-triggers-eventlistenersink-rhel9-container" \
      name="openshift-pipelines/pipelines-triggers-eventlistenersink-rhel9" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Triggers Eventlistenersink" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Triggers Eventlistenersink" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Triggers Eventlistenersink" \
      io.k8s.description="Red Hat OpenShift Pipelines Triggers Eventlistenersink" \
      io.openshift.tags="pipelines,tekton,openshift" \
      cpe="cpe:/a:redhat:openshift_pipelines:1.18::el9"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/eventlistenersink"]
