#!/bin/bash

SRCDIR=/home/ddombrowsky/downloads/canvas-lms

if [ "$1" != "--forreal" ] ; then
    pushd $SRCDIR > /dev/null || exit 1
    git pull || exit 2
    popd > /dev/null
    exec $0 --forreal
fi

echo HEY DEPLOY!

true
