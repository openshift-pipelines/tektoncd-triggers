ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.redhat.io/ubi8/ubi:latest@sha256:244e9858f9d8a2792a3dceb850b4fa8fdbd67babebfde42587bfa919d5d1ecef

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
ARG VERSION=triggers-1.16.4

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
      io.openshift.tags="pipelines,tekton,openshift" \
      cpe="cpe:/a:redhat:openshift_pipelines:1.16::el8"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot

USER 65532
ENTRYPOINT ["/ko-app/eventlistenersink"]
