#!/bin/bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1

export readonly ARCH=${1:-amd64}
export readonly NAME=${2:-$(basename "${PWD%/*}")}
export readonly VERSION=${3:-$(basename "$PWD")}

IMAGE_MC="minio/mc:RELEASE.2024-03-03T00-13-08Z"
IMAGE_MINIO="minio/minio:RELEASE.2024-02-09T21-25-16Z"

mkdir -p "opt/$NAME"
if [ -s install.sh ]; then
  mv install.sh "opt/$NAME"
fi
pushd "opt/$NAME" && {
  [ -s kubectl-minio ] || wget -qO kubectl-minio "https://staging-udesk.oss-cn-beijing.aliyuncs.com/czl/kubectl-minio_${VERSION#*v}_linux_$ARCH"
  if [ -s install.sh ]; then
    sed -i "s#IMAGE_MC#$IMAGE_MC#g;s#IMAGE_MINIO#$IMAGE_MINIO#g" install.sh
  fi
  chmod a+x ./*
}
popd

mkdir -p images/shim
pushd images/shim && {
  [ -s /tmp/kubectl-minio ] || wget -qO "/tmp/kubectl-minio" "https://staging-udesk.oss-cn-beijing.aliyuncs.com/czl/kubectl-minio_${VERSION#*v}_linux_$ARCH"
  chmod a+x /tmp/kubectl-minio
  {
    echo "$IMAGE_MC"
    #echo "$IMAGE_MINIO"
    /tmp/kubectl-minio tenant create -h | grep :RELEASE. | awk -F\" '{print $(NF-1)}'
    {
      /tmp/kubectl-minio init -o
    } | grep -E "image: .+:.+" | awk '{print $NF}'
  } | sort | uniq >>"${NAME}Images"
}
popd

mkdir -p charts

mkdir -p manifests

while read -r d; do [[ -z "$(find "$d" -type f)" ]] && rm -r "$d"; done < <(find . -maxdepth 1 -mindepth 1 -type d)
cat <<EOF >"Kubefile"
FROM scratch
COPY . .
CMD ["bash -e opt/$NAME/install.sh"]
EOF
