ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.redhat.io/ubi8/ubi:latest@sha256:4f0a4e4deb450583408a06165e92a4dcd4f0740a23815f3326fc5c97ee9ca768

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/triggers
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/controller \
    ./cmd/controller

FROM $RUNTIME
ARG VERSION=triggers-1.16.4

ENV CONTROLLER=/usr/local/bin/controller \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/controller /ko-app/controller
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-triggers-controller-rhel8-container" \
      name="openshift-pipelines/pipelines-triggers-controller-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Triggers Controller" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Triggers Controller" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Triggers Controller" \
      io.k8s.description="Red Hat OpenShift Pipelines Triggers Controller" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot

USER 65532
ENTRYPOINT ["/ko-app/controller"]
