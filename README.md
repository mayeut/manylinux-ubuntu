# manylinux-ubuntu

This is only a PoC that serves multiple purposes:
- experiment with multiarchitecture images in GHA
- provide a path to build armv7l manylinux wheels
- provide a path to build riscv64 manylinux wheels


## Why this won't be part of [pypa/manylinux](https://github.com/pypa/manylinux) as a whole

If you're building manylinux wheels for `x86_64`, `aarch64`, `ppc64le` or `s390x` then,
the already existing images based on RHEL derivatives are better suited for the job.
They do provide compatibility with older systems while providing a recent gcc toolchain.
As an example, the manylinux_2_28 image that ensure built wheels will run on glibc 2.28+ systems
currently provides a gcc 14 toolchain. A manylinux_2_35 image based on Ubuntu 22.04 would only ensure
compatibility with more recent glibc 2.35+ systems while providing an older gcc 11 toolchain.

This [linked issue](https://github.com/pypa/manylinux/issues/1012) has more information about this.


## Path to build `armv7l` manylinux wheels

`armv7l` is still used nowadays, for example on [Raspberry Pi](https://www.raspberrypi.com/).
There are no RHEL derivatives for this architecture that would allow for "old systems with a recent toolchain" out-of-the-box.

As such, one way forward is to have a Debian derivative image that allows building manylinux wheels for this architecture.
This comes with some caveats:
- in order to achieve compatibility with "older" systems, you get an older toolchain:
    - gcc9 on Ubuntu 20.04 (manylinux_2_31 wheels compatible with Ubuntu 20.04+, Debian 11+)
    - gcc11 on Ubuntu 22.04 (manylinux_2_35 wheels compatible with Ubuntu 22.04+, Debian 12+)
    - gcc13 on Ubuntu 24.04 (manylinux_2_39 wheels compatible with Ubuntu 24.04+, Debian 13+)
- the package manager & packages names are different than what is found on [pypa/manylinux](https://github.com/pypa/manylinux) images:
  [pypa/manylinux](https://github.com/pypa/manylinux) images are using RHEL derivatives only for now so using `yum`/`dnf` as a package manager and
  RHEL like packages names while images here are using `apt` and Debian like packages names.
  If one depends on let's say OpenSSL development package, then, the commands to issue to install it are a bit different:
    - `dnf -y install openssl-devel` on RHEL derivatives
    - `apt-get update && apt-get install -y libssl-dev` on Debian derivatives

An experiment was proposed in [pypa/cibuildwheel](https://github.com/pypa/cibuildwheel/pull/2052) using the `manylinux_2_31` image
from this repository as a first step towards supporting `armv7l` manylinux wheel building.

Following that experiment, a specific `armv7l` image has been [added in pypa/manylinux](https://github.com/pypa/manylinux/pull/1699).

[pypa/manylinux](https://github.com/pypa/manylinux) support for `riscv64` has been [added using an RHEL derivative](https://github.com/pypa/manylinux/pull/1743).
