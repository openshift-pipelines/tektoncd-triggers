ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.24
ARG RUNTIME=registry.redhat.io/ubi9/ubi-minimal@sha256:61d5ad475048c2e655cd46d0a55dfeaec182cc3faa6348cb85989a7c9e196483 

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/triggers
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GOEXPERIMENT=strictfipsruntime
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/eventlistenersink \
    ./cmd/eventlistenersink

FROM $RUNTIME
ARG VERSION=triggers-1.21

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
      io.openshift.tags="pipelines,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/eventlistenersink"]
