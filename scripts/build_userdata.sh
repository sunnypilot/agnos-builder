#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ROOT=$DIR/..
OUTPUT_DIR=$DIR/../output/userdata
GIT_BRANCH=staging-c3-new
RELEASE_BRANCH="master"

export DOCKER_BUILDKIT=1
docker build -f $ROOT/Dockerfile.builder -t agnos-meta-builder $DIR \
  --build-arg UNAME=$(id -nu) \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g)

function create_image() {
  IMAGE_SIZE=$1

  WORKDIR=$(mktemp -d)
  MNTDIR=$WORKDIR/mnt
  USERDATA_IMAGE=$WORKDIR/raw.img

  sudo umount $MNTDIR 2> /dev/null || true
  rm -rf $WORKDIR
  mkdir $WORKDIR
  cd $WORKDIR

  truncate -s $IMAGE_SIZE $USERDATA_IMAGE
  mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0 $USERDATA_IMAGE

  mkdir $MNTDIR
  sudo mount $USERDATA_IMAGE $MNTDIR
  sudo git clone --branch=$GIT_BRANCH --depth=1 https://github.com/sunnypilot/openpilot.git $MNTDIR/openpilot
  sudo touch $MNTDIR/.openpilot_cache

  sudo git -C $MNTDIR/openpilot remote set-branches --add origin $RELEASE_BRANCH
  sudo git -C $MNTDIR/openpilot update-ref refs/remotes/origin/$RELEASE_BRANCH refs/remotes/origin/$GIT_BRANCH
  sudo git -C $MNTDIR/openpilot branch -m $RELEASE_BRANCH
  sudo git -C $MNTDIR/openpilot branch --set-upstream-to=origin/$RELEASE_BRANCH

  # assume comma is the first non root user created
  sudo chown 1000:1000 -R $MNTDIR/openpilot

  echo "clone done for $(sudo cat $MNTDIR/openpilot/common/version.h)"
  sudo umount $MNTDIR

  echo "Sparsify"
  mkdir -p $OUTPUT_DIR  # ensure output exists
  docker run --rm -u $(id -u):$(id -g) --entrypoint img2simg -v $WORKDIR:$WORKDIR -v $ROOT:$ROOT -w $DIR agnos-meta-builder $USERDATA_IMAGE $OUTPUT_DIR/userdata_${sz}.img

  rm -rf $WORKDIR
}

for sz in 30 89 90; do
#for sz in 3 4 5; do
  echo "Building ${sz}GB userdata image"
  create_image ${sz}G
done

echo "Done!"
ls -la 
ls -la $OUTPUT_DIR
ls -la $DIR