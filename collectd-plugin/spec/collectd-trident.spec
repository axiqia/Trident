Summary:   collectd plugin to output trident data.
Name:      collectd-trident
Version:   1.0
Release:   1
BuildArch: noarch
Source:    %{name}-%{version}.tar.gz
Source1:   README.md
License:   GPLv3
URL:       https://gitlab.cern.ch/UP/Trident

Requires: collectd

%description
collectd plugin to output trident measurements

%prep
%setup -q
cp %{SOURCE1} .

%build
%{__python} setup.py build

%install
%{__python} setup.py install --skip-build --root %{buildroot}
mkdir -p %{buildroot}/usr/share/collectd
install -m 0644 share/trident_types.db %{buildroot}/usr/share/collectd/trident_types.db

%files
%doc README.md
%{python_sitelib}/*
/usr/share/collectd/trident_types.db

%changelog
* Thu Apr 26 2018 David Smith <david.smith@cern.ch> 1.0-1
- Initial
