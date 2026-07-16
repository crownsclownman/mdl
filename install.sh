#!/usr/bin/bash
set -e

REPO="crownsclownman/mdl"
URL="https://github.com/$REPO/releases/latest/download/mdlcc"
INSTALL_PATH="/usr/local/bin/mdlcc"

curl -L $URL -o /tmp/mdlcc
mv /tmp/mdlcc $INSTALL_DIR
chmod +x $INSTALL_DIR

echo "Successfully installed to $INSTALL_DIR"
