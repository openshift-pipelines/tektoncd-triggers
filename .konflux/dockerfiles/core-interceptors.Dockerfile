ARG GO_BUILDER=registry.redhat.io/ubi9/go-toolset:latest@sha256:a2ad457dc7525635613d2355037239ca9bf4374ba3b59961d1cdaa4d5f1af7d8
ARG UBI_RUNTIME=registry.redhat.io/ubi9/ubi-minimal-pqc:latest@sha256:9aca95ae4e261eab848dc6abdfd08eb4c2453944232021245b2e3108eb25ae18

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/triggers
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GOEXPERIMENT=strictfipsruntime
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/interceptors \
    ./cmd/interceptors

FROM $UBI_RUNTIME
ARG VERSION=1.24

ENV CONTROLLER=/usr/local/bin/interceptors \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/interceptors /ko-app/interceptors
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
    com.redhat.component="openshift-pipelines-triggers-core-interceptors-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.24::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-triggers core-interceptors" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-triggers core-interceptors" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-triggers core-interceptors" \
    io.openshift.tags="tekton,openshift,tektoncd-triggers,core-interceptors" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-triggers-core-interceptors-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-triggers core-interceptors" \
    version="v1.24.4"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/interceptors"]
