ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.redhat.io/ubi8/ubi:latest@sha256:0c1757c4526cfd7fdfedc54fadf4940e7f453201de65c0fefd454f3dde117273

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
ARG VERSION=triggers-1.17.2

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

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot

USER 65532
ENTRYPOINT ["/ko-app/interceptors"]
