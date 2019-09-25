#!/bin/sh

# should be run with sudo

set -e

_pid=`cat /opt/canvas/canvas/tmp/pids/delayed_jobs_pool.pid`
ps u $_pid
echo killing existing delayed jobs pid $_pid
systemctl stop canvas
kill $_pid || :
echo Stopping apache...
systemctl stop apache2
sleep 1
echo Starting delayed jobs...
systemctl start canvas
echo Starting apache...
systemctl start apache2
echo Done
