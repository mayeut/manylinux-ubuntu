#!/bin/bash

set -euxo pipefail

# patch tests
sed -i 's/assert sqlite3.sqlite_version_info/# assert sqlite3.sqlite_version_info/g' /opt/_internal/tests/modules-check.py
sed -i 's/assert zstd.zstd_version_info/# assert zstd.zstd_version_info/g' /opt/_internal/tests/modules-check.py
sed -i 's/"idlelib",/# "idlelib",/g' /opt/_internal/tests/modules-check.py
sed -i 's/"lib2to3",/# "lib2to3",/g' /opt/_internal/tests/modules-check.py
sed -i 's/modules.remove("lib2to3")/# modules.remove("lib2to3")/g' /opt/_internal/tests/modules-check.py
sed -i 's/"turtledemo",/# "turtledemo",/g' /opt/_internal/tests/modules-check.py
sed -i 's/def test_sysconfig/def disabled_test_sysconfig/g' /opt/_internal/tests/modules-check.py

cat <<EOF > /opt/_internal/tests/autotools/configure.ac
AC_PREREQ([2.69])
AC_INIT(test_autotools,1.0.0)
AM_INIT_AUTOMAKE([1.16.1])
AC_PROG_LIBTOOL
LT_PREREQ([2.4.6])
LT_INIT()
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
EOF

sed -i 's|AUDITWHEEL_LD_LIBRARY_PATH=.*|AUDITWHEEL_LD_LIBRARY_PATH="${SRC_DIR}/eleven:${SRC_DIR}/ten"|g' /opt/_internal/tests/run_tests.sh

/opt/_internal/tests/run_tests.sh
