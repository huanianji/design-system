#!/bin/sh
plugin_package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$plugin_package_dir/install.py" "$@"
