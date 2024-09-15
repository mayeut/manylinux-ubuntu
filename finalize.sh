#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# disable some pip warnings
export PIP_ROOT_USER_ACTION=ignore
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_WARN_SCRIPT_LOCATION=0
# all cache goes to /tmp
export PIP_CACHE_DIR=/tmp/pip_cache

# update package, create symlinks for each python
mkdir /opt/python
for VERSION in 3.8 3.9 3.10 3.11 3.12 3.13 3.13t; do
	PREFIX=/opt/_internal/cpython-${VERSION}
	python${VERSION} -m venv --without-pip ${PREFIX}
	${MY_DIR}/finalize-one.sh ${PREFIX}
done

# create manylinux-interpreters script
cat <<EOF > /usr/local/bin/manylinux-interpreters
#!/bin/bash

set -euo pipefail

/opt/python/cp312-cp312/bin/python $MY_DIR/manylinux-interpreters.py "\$@"
EOF
chmod 755 /usr/local/bin/manylinux-interpreters

MANYLINUX_INTERPRETERS_NO_CHECK=1 /usr/local/bin/manylinux-interpreters ensure "$@"

# Create venv for certifi and pipx
TOOLS_PATH=/opt/_internal/tools
/opt/python/cp312-cp312/bin/python -m venv --without-pip ${TOOLS_PATH}

# Install certifi and pipx
/opt/python/cp312-cp312/bin/python -m pip --python ${TOOLS_PATH}/bin/python install -U --require-hashes -r ${MY_DIR}/requirements-base-tools.txt

# Make pipx available in PATH,
# Make sure when root installs apps, they're also in the PATH
cat <<EOF > /usr/local/bin/pipx
#!/bin/bash

set -euo pipefail

if [ \$(id -u) -eq 0 ]; then
	export PIPX_HOME=/opt/_internal/pipx
	export PIPX_BIN_DIR=/usr/local/bin
	export PIPX_MAN_DIR=/usr/local/share/man
fi
${TOOLS_PATH}/bin/pipx "\$@"
EOF
chmod 755 /usr/local/bin/pipx

# Our openssl doesn't know how to find the system CA trust store
#   (https://github.com/pypa/manylinux/issues/53)
# And it's not clear how up-to-date that is anyway
# So let's just use the same one pip and everyone uses
ln -s $(${TOOLS_PATH}/bin/python -c 'import certifi; print(certifi.where())') /opt/_internal/certs.pem
# If you modify this line you also have to modify the versions in the Dockerfiles:
export SSL_CERT_FILE=/opt/_internal/certs.pem

# initialize shared library
# workaround https://github.com/pypa/pip/issues/9243
/opt/python/cp312-cp312/bin/python -m pip download --dest /tmp/pinned-wheels --require-hashes -r /opt/_internal/build_scripts/requirements3.12.txt
pipx upgrade-shared --pip-args="--no-index --find-links=/tmp/pinned-wheels"

# install other tools with pipx
for TOOL_PATH in $(find ${MY_DIR}/requirements-tools -type f); do
	TOOL=$(basename ${TOOL_PATH})
	# uv doesn't provide musl s390x wheels due to Rust issues
	if [[ "${TOOL}" != "uv" || "${BASE_POLICY}-${AUDITWHEEL_ARCH}" != "musllinux-s390x" ]]; then
		pipx install --pip-args="--require-hashes -r ${TOOL_PATH} --only-binary" ${TOOL}
	fi
done

# We do not need the precompiled .pyc and .pyo files.
clean_pyc /opt/_internal

# remove cache
rm -rf /tmp/* || true

hardlink -c /opt/_internal
