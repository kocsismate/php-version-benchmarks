#!/usr/bin/env bash
set -e

sudo service docker stop
sudo systemctl stop containerd.service
