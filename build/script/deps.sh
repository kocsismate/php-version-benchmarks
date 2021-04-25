#!/bin/sh
set -e

apt-get update
apt-get install -y --no-install-recommends git
apt-get install linux-tools-common linux-tools-generic linux-tools-`uname -r`
