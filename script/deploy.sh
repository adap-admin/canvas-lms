#!/bin/bash

# Bytelion 
# Circle CI deploy script for canvas-lms

# This uses installconfig and rmdeploy, and depends on the
# following NOPASSWD setup in sudoers:
#
#  ddombrowsky ALL=NOPASSWD: /opt/canvas/installconfig
#  ddombrowsky ALL=NOPASSWD: /opt/canvas/rmdeploy
#  ddombrowsky ALL=(canvasuser) NOPASSWD:ALL


set -e

SRCDIR=/home/ddombrowsky/downloads/canvas-lms
DEPLOYROOT=/opt/canvas
DEPLOYNAME=canvas
REPO=
BRANCH=$1

if [ -z "$BRANCH" ] ; then
    echo "ERROR: no branch specified" 2>&1
    exit 1
fi

shift

if [ "$1" != "--forreal" ] ; then
    pushd $SRCDIR > /dev/null || exit 1
    git pull || exit 2
    popd > /dev/null
    exec $0 $BRANCH --forreal
fi

# Get the name of the next deployment directory.
# It goes in a round-robin rotation, so canvas.0
# to canvas.3, and then back to 0.
_next=0
getnext() {
    cur=`readlink $DEPLOYROOT/$DEPLOYNAME`
    echo Current deploy: $cur
    curnum=${cur##*.}
    nextnum=$(((curnum+1)%3))
    _next=$nextnum
}

resetdir() {
    dirnum=$1
    dir=${DEPLOYNAME}.$dirnum
    echo Resetting next deploy dir $dir
    if [ -d $dir ] ; then
        cur=`readlink $DEPLOYROOT/$DEPLOYNAME`
        if [ "$cur" == "$dir"  ] ; then
            echo "ERROR: cannot reset running deploy" >&2
            exit 1
        fi
        echo Removing existing installation dir $dir
        sudo /opt/canvas/rmdeploy $dirnum || exit 3
    fi
    # Doing a full rebuild of the assets is just not
    # possible on the production machine.  It runs out of memory.
    # So we cannot do a git clone.  
    # git clone git@github.com:Bytelion/canvas-lms.git $dir

    mkdir $dir
    cd $dir

    # NOTE: this requires a bootstrapped existing installation,
    # because it copies in the configuration files from there.
    set -x
    sudo /opt/canvas/installconfig || exit 4

    git fetch
    git checkout $BRANCH
    git merge --ff-only origin/$BRANCH || exit 5
    sudo -u canvasuser RAILS_ENV=production bundle exec rails db:migrate

    # FINAL STEP: update the symlink
    rm -v $DEPLOYROOT/$DEPLOYNAME
    ln -vs $dir $DEPLOYROOT/$DEPLOYNAME

    # Restart Services:
    sudo /opt/canvas/restart_services.sh

    set +x
}

echo Deploying canvas-lms at branch $BRANCH
echo Started at `date`
cd $DEPLOYROOT
getnext
resetdir $_next
echo Finished at `date`
