#!/usr/bin/env bash
# Copyright 2025 The etcd Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Build all release binaries and images to directory ./release.
# Run from repository root.
#
set -euo pipefail

source ./scripts/test_lib.sh

VERSION=${1:-}
if [ -z "${VERSION}" ]; then
  VERSION=$(git describe --tags --always --dirty)
fi
NO_DOCKER_PUSH=${2:-0}

if ! command -v docker >/dev/null; then
    echo "cannot find docker"
    exit 1
fi

if ! command -v goreleaser >/dev/null; then
    echo "cannot find goreleaser"
    exit 1
fi

ETCD_ROOT=$(dirname "${BASH_SOURCE[0]}")/..

# Consumed by .goreleaser.yaml templates.
export VERSION
# An empty OCI_REGISTRY must be unset so the goreleaser templates fall back to
# the default gcr.io/quay.io image pair.
if [ -z "${OCI_REGISTRY:-}" ]; then
  unset OCI_REGISTRY OCI_PATH
fi

# goreleaser needs GITHUB_TOKEN to create the release; fall back to gh's
# token, and skip the GitHub release entirely when neither is available.
if [ -z "${GITHUB_TOKEN:-}" ] && command -v gh >/dev/null && gh auth status &>/dev/null; then
  GITHUB_TOKEN="$(gh auth token)"
  export GITHUB_TOKEN
fi
if [ -z "${GITHUB_TOKEN:-}" ]; then
  export SKIP_GH_RELEASE=true
fi

# Multi-arch builds need a docker-container buildx builder with binfmt.
if [ "${CI:-}" == "true" ]; then
  docker run --privileged --rm tonistiigi/binfmt --install all
  docker buildx create \
    --name multiarch-multiplatform-builder \
    --driver docker-container \
    --bootstrap --use
fi

# --parallelism=1 keeps the archive entry order (and therefore checksums)
# reproducible across machines: goreleaser packs binaries in build-completion
# order, which is timing-dependent when builds run concurrently.
goreleaser_args=(release --clean --skip=validate --parallelism=1 --release-notes-tmpl=scripts/release_notes.md.tmpl)
if [ "${NO_DOCKER_PUSH}" == 1 ]; then
  # Snapshot mode builds the images locally without pushing.
  goreleaser_args+=(--snapshot)
fi

pushd "${ETCD_ROOT}" >/dev/null
  log_callout "Building release ${VERSION} with goreleaser..."
  run goreleaser "${goreleaser_args[@]}"

  if [ -n "${PUBLISH_TO_GCS:-}" ]; then
    # cloudbuild will copy contents of this folder to GCS
    echo "Copying release artifacts to release/cloudbuild/${VERSION}"
    mkdir -p "release/cloudbuild/${VERSION}"
    cp release/SHA256SUMS release/cloudbuild/"${VERSION}"/SHA256SUMS
    cp release/*.zip release/cloudbuild/"${VERSION}"/ 
    cp release/*.tar.gz release/cloudbuild/"${VERSION}"/
    gcloud storage cp --recursive "release/cloudbuild/" "gs://${GCS_LOCATION}"

    if [[ "${VERSION}" =~ ^v[0-9]+.[0-9]+.[0-9]+(-[a-zA-Z]+.[0-9]+)?$ ]]; then
      echo "Updating latest release artifacts in gs://${GCS_LOCATION}/latest"
      gcloud storage cp --recursive "gs://${GCS_LOCATION}/${VERSION}/" "gs://${GCS_LOCATION}/latest/"
    fi

  fi
popd >/dev/null
