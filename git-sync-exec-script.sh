#!/bin/sh
# this script will be executed in active path ${GIT_SYNC_ROOT}/(hash)
# and copy everything under the active directory to /docs

# Clean up /docs directory if anything exists
if [ "$(ls -A /docs)" ]; then
    echo "/docs is not empty. Removing all files and directories."
    rm -rf /docs/*
fi

# Copy everything under the active directory to /dags_dest
cp -R . /docs/
