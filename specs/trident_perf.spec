#
# spec file for package perf
#
#

Name:           trident-util-perf
Version:		4.15
Release:        0
License:		GPL-3.0
Summary:        Static version of perf for recording HW counters in Trident
BuildRequires:  unzip
BuildRequires:  binutils-devel
BuildRequires:  bison
BuildRequires:  flex
BuildRequires:  xz-devel
BuildRequires:  openssl-devel
BuildRequires:  zlib-devel
Requires:       kernel >= 2.6.31
Prefix:			/local
%define			_prefix /local
%define			_build_dir %{name}-%{version}-build
BuildRoot:      %{_topdir}/%{_build_dir}

%description
This package provides a userspace statically built version of 'perf',
to record performance counters for trident performance analysis tool.
Assume all other features of standard to be absent from this version.

%prep
rm -rf %{buildroot}
rm -rf %{_build_dir}
mkdir -p %{buildroot}
mkdir -p %{_build_dir}
cd %{_build_dir}
#URL for downloading Linux source code
wget 'https://codeload.github.com/torvalds/linux/zip/v%{version}'
unzip v%{version}
cd linux-%{version}
chmod +x tools/perf/util/generate-cmdlist.sh

%build
cd %{_build_dir}
cd linux-%{version}/tools/perf
export WERROR=0
make -f Makefile.perf -j32 prefix=local FIXDEP=1 LDFLAGS=-static EXTRA_CLFAGS=-fPIC install perf

%install
cd %{_build_dir}
cd linux-%{version}/tools/perf
mkdir -p %{buildroot}%{_bindir}
cp local/bin/perf %{buildroot}%{_bindir}/perf_static
strip %{buildroot}%{_bindir}/perf_static

%files
%{_bindir}/perf_static

%changelog

%clean
rm -rf %{buildroot}
rm -rf %{_build_dir}
