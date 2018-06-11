#
# spec file for package trident-support-util
#

Name:           trident-support-util
Version:		Alpha
Release:        0
License:		GPL-3.0
Summary:        Used to detect if trident is supported in the given architecture
BuildRequires:  wget
BuildRequires:  gcc
Requires:       kernel >= 2.6.31
Prefix:			/local
%define 		PFMVersion	4.9.0
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
#URL for downloading libpfm source code
wget 'https://sourceforge.net/projects/perfmon2/files/libpfm4/libpfm-%{PFMVersion}.tar.gz'

tar -xvf libpfm-%{PFMVersion}.tar.gz
cp -r %{_tridentsrcdir} trident_src

%build
cd %{_build_dir}
cd libpfm-%{PFMVersion}
make static
cd ..
cd trident_src
PFM_DIR=%{_build_dir}/libpfm-%{PFMVersion} make trident_support

%install
cd %{_build_dir}
mkdir -p %{buildroot}%{_bindir}
cp trident_src/trident_support %{buildroot}%{_bindir}/trident_support
strip %{buildroot}%{_bindir}/trident_support

%files
%{_bindir}/trident_support

%changelog

%clean
rm -rf %{buildroot}
rm -rf %{_build_dir}
