#!/usr/bin/env bash

while true; do
  find "$PWD/src/" -type f -name "*.elm" | entr -d "$@"
done
