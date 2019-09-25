#!/bin/sh

echo "install goss"

which curl 2> /dev/null &&
  curl -fsSL https://goss.rocks/install | sh ||
  wget $(wget https://api.github.com/repos/aelsabbahy/goss/releases/latest -O - 2> /dev/null | grep browser_download_url | grep goss-linux-amd64 | cut -d '"' -f 4) -O /usr/local/bin/goss 2> /dev/null

chmod +rx /usr/local/bin/goss

while pgrep cloud-init > /dev/null ; do
  echo "waiting for cloud-init to finish, sleeping for 10 seconds..."
  sleep 10
done

echo "launching goss"
/usr/local/bin/goss validate
