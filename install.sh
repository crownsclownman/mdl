#!/usr/bin/bash
set -e

REPO="crownsclownman/mdl"
URL="https://github.com/$REPO/releases/latest/download/mdlcc"
INSTALL_PATH="/usr/local/bin/mdlcc"

curl -sS -L $URL -o /tmp/mdlcc
mv /tmp/mdlcc $INSTALL_PATH
chmod +x $INSTALL_PATH

echo "Successfully installed to $INSTALL_PATH"
