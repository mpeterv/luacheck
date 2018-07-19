Name: tarantool-luacheck
# During package building {version} is overwritten by Packpack with
# VERSION. It is set to major.minor.patch.number_of_commits_above_last_tag.
# major.minor.patch tag and number of commits above are taken from the
# github repository: https://github.com/tarantool/luacheck
Version: 0.22.0
Release: 1%{?dist}
Summary: A static analyzer and a linter for Lua
Group: Development/Tools
License: MIT
URL: https://github.com/tarantool/luacheck
Source0: luacheck-%{version}.tar.gz

BuildArch: noarch

BuildRequires: tarantool >= 1.9.0.0
Requires: tarantool >= 1.9.0.0

%description
Luacheck is a command-line tool for linting and static analysis of Lua code.
It is able to spot usage of undefined global variables, unused local variables
and a few other typical problems within Lua programs.

%prep
%setup -q -n luacheck-%{version}

%install
echo \#\!/usr/bin/env tarantool$'\n'"require('luacheck.main')" > luacheck
chmod +x luacheck
mkdir -p %{buildroot}%{_bindir}
mv luacheck %{buildroot}%{_bindir}/luacheck
mkdir -p %{buildroot}%{_prefix}/share/tarantool/luacheck/
cp ./src/luacheck/* %{buildroot}%{_prefix}/share/tarantool/luacheck/

%files
%{_prefix}/share/tarantool/luacheck
%{_bindir}/luacheck

%changelog

* Tue Jul 10 2018 Ivan Koptelov <ivan.koptelov@tarantool.org> 0.22.0-1
- Initial release
