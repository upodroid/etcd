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

set -euo pipefail

source ./scripts/test_lib.sh

VERSION=${1:-}
if [ -z "$VERSION" ]; then
  echo "Usage: ${0} VERSION" >&2
  exit 1
fi

PLATFORMS=${2:-"linux/amd64,linux/arm64,linux/ppc64le,linux/s390x"}

tag_args=()
if [ -z "${OCI_REGISTRY:-}" ]; then
  tag_args+=("-t" "gcr.io/etcd-development/etcd:${VERSION}")
  tag_args+=("-t" "quay.io/coreos/etcd:${VERSION}")
else
  tag_args+=("-t" "${OCI_REGISTRY}/${OCI_PATH:-etcd}:${VERSION}")
fi

if [ "${NO_DOCKER_PUSH:-0}" == 1 ]; then
  OUTPUT="type=oci,dest=/tmp/image.tar.gz"
else
  OUTPUT="type=registry,unpack=false"
fi

docker buildx build --build-arg="VERSION=${VERSION}" \
  --build-arg="BUILDDIR=${BUILD_DIR}" \
  --platform="${PLATFORMS}" \
  --output="${OUTPUT}" \
  "${tag_args[@]}" \
  .

