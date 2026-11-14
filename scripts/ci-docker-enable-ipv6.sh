#!/bin/sh
# Enable IPv6 in Docker configuration
# By default, the Docker daemon in GHA images does not enable IPv6.
# It's necessary when running network tests in Docker containers.

set -eu

echo '{"ipv6":true, "fixed-cidr-v6":"2001:db8:1::/64"}' | sudo tee /etc/docker/daemon.json
sudo service docker restart
