%global macrosdir %(d=%{_rpmconfigdir}/macros.d; [ -d $d ] || d=%{_sysconfdir}/rpm; echo $d)

Name:           Lmod
Version:        8.2.5
Release:        2.ug%{?dist}
Summary:        Environmental Modules System in Lua

# Lmod-5.3.2/tools/base64.lua is LGPLv2
License:        MIT and LGPLv2
URL:            https://www.tacc.utexas.edu/tacc-projects/lmod
Source0:        https://github.com/TACC/Lmod/archive/%{version}.tar.gz#/Lmod-%{version}.tar.gz
Source1:        macros.%{name}
Source2:        SitePackage.lua
Source3:        run_lmod_cache.py
Source4:        admin.list
Patch0:         Lmod-spider-no-hidden-cluster-modules.patch

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
# Lmod 8.x ships binaries when configured with --with-fastTCLInterp=yes (which is the default)
# BuildArch:      noarch
BuildRequires:  lua-devel
BuildRequires:  lua-filesystem
BuildRequires:  lua-json
BuildRequires:  lua-posix
BuildRequires:  lua-term
BuildRequires:  tcl-devel
Requires:       lua-filesystem
Requires:       lua-json
Requires:       lua-posix
Requires:       lua-term
Requires:       tcl
Requires:       /bin/ps
Conflicts:      environment-modules

%description
Lmod is a Lua based module system that easily handles the MODULEPATH
Hierarchical problem.  Environment Modules provide a convenient way to
dynamically change the users' environment through modulefiles. This includes
easily adding or removing directories to the PATH environment variable.
Modulefiles for library packages provide environment variables that specify
where the library and header files can be found.


%prep
%setup -q
%patch0 -p1
sed -i -e 's,/usr/bin/env ,/usr/bin/,' src/*.tcl
# Remove bundled lua-term
rm -r pkgs/luafilesystem/ pkgs/term/ tools/json.lua
sed -i -e 's/^spiderCacheSupport: lfs/spiderCacheSupport: /' Makefile.in
# Remove unneeded shbangs
sed -i -e '/^#!/d' init/*.in


%build
%configure --prefix=%{_datadir} PS=/bin/ps --with-caseIndependentSorting=yes --with-redirect=yes --with-autoSwap=no --with-disableNameAutoSwap=yes --with-shortTime=86400 --with-pinVersions=yes --with-module-root-path=/etc/modulefiles/vsc --with-cachedLoads=yes --with-siteName='HPC-UGent'
make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT

%make_install
# init scripts are sourced
find %{buildroot}%{_datadir}/lmod/%{version}/init/ -type f -print0 | xargs -0 chmod -x
mkdir -p %{buildroot}%{_sysconfdir}/modulefiles
mkdir -p %{buildroot}%{_datadir}/modulefiles
mkdir -p %{buildroot}%{_sysconfdir}/profile.d
# Install profile links to override environment-modules
ln -s %{_datadir}/lmod/lmod/init/bash %{buildroot}%{_sysconfdir}/profile.d/modules.sh
ln -s %{_datadir}/lmod/lmod/init/csh %{buildroot}%{_sysconfdir}/profile.d/modules.csh
# Install the rpm config file
install -Dpm 644 %{SOURCE1} %{buildroot}/%{macrosdir}/macros.%{name}
# Override SitePackage.lua
install -Dpm 644 %{SOURCE2} %{buildroot}%{_datadir}/lmod/%{version}/libexec
# install icinga/nagios wrapper for the cache creation
install -Dpm 755 %{SOURCE3} %{buildroot}%{_datadir}/lmod/%{version}/libexec
# install admin.list
mkdir -p %{buildroot}%{_datadir}/lmod/etc
install -Dpm 644 %{SOURCE4} %{buildroot}%{_datadir}/lmod/etc

%clean
rm -rf %{buildroot}

%files
%doc INSTALL License README.md README_lua_modulefiles.txt
%{_sysconfdir}/modulefiles
%{_sysconfdir}/profile.d/modules.csh
%{_sysconfdir}/profile.d/modules.sh
%{_datadir}/lmod
%{_datadir}/modulefiles
%{macrosdir}/macros.%{name}


%changelog
* Tue Nov 26 2019 Kenneth Hoste <kenneth.hoste@ugent.be> - 8.2.5-1.ug
  - update to Lmod 8.2.5 (support for extensions)

* Tue Sep 24 2019 Kenneth Hoste <kenneth.hoste@ugent.be> - 8.1.17-1.ug
  - update to Lmod 8.1.17 (restores 'module switch')

* Mon Sep 23 2019 Kenneth Hoste <kenneth.hoste@ugent.be> - 8.1.16-1.ug
  - update to Lmod 8.1.16

* Wed Sep 26 2018 Kenneth Hoste <kenneth.hoste@ugent.be> - 7.8.4-1.ug
- update to Lmod 7.8.4 + tweak admin.list

* Wed Apr 4 2018 Kenneth Hoste <kenneth.hoste@ugent.be> - 7.7.26-1.ug
- update to Lmod 7.7.26 (clean error when cache file can not be read & more)

* Fri Sep 29 2017 Kenneth Hoste <kenneth.hoste@ugent.be> - 7.7.5-1.ug
- update to Lmod 7.7.5 (faster bash completion)

* Thu Jul 13 2017 Kenneth Hoste <kenneth.hoste@ugent.be> - 7.5.10-7.ug
- add patch to ensure Lmod cache is used when loading cluster modules which include prepend_path($MODULEPATH, ...)

* Fri Jul 7 2017 Kenneth Hoste <kenneth.hoste@ugent.be> - 7.5.10-6.ug
- fix grabbing $MODULEPATH root from Lmod config in run_lmod_cache.py, 'config' was renamed to 'configT' in Lmod 7

* Thu Jul 6 2017 Kenneth Hoste <kenneth.hoste@ugent.be> - 7.5.10-5.ug
- update to Lmod 7.5.10
- fix msg hooks in SitePackage.lua (thanks to Ward Poelmans)
- remove patch for 'module' and 'ml', no longer needed
- add patch to avoid listing hidden cluster modules in output of 'ml spider'

* Mon Nov 28 2016 Ward Poelmans <ward.poelmans@ugent.be> - 6.6-2ug
- Install a admin.list (aka nag file)

* Fri Oct 14 2016 Ward Poelmans <ward.poelmans@ugent.be> - 6.6-1ug
- Use the json config interface of Lmod in cache creation script

* Thu May 19 2016 Ward Poelmans <ward.poelmans@ugent.be> - 6.3.5-2ug
- Add icinga/nagios wrapper for cache creation script

* Wed May 11 2016 Ward Poelmans <ward.poelmans@ugent.be> - 6.3.3-1ug
- Sync to upstream Lmod version
- Drop zsh as build dep (we don't use it)

* Thu Feb 18 2016 Ward Poelmans <ward.poelmans@ugent.be> - 6.1.3-1ug
- Adapt to UGent use

* Thu Feb 11 2016 Orion Poplawski <orion@cora.nwra.com> - 6.1.3-1
- Update to 6.1.3

* Wed Feb 10 2016 Orion Poplawski <orion@cora.nwra.com> - 6.1.2-1
- Update to 6.1.2

* Sat Feb 6 2016 Orion Poplawski <orion@cora.nwra.com> - 6.1-1
- Update to 6.1

* Fri Feb 5 2016 Orion Poplawski <orion@cora.nwra.com> - 6.0.29-1
- Update to 6.0.29

* Wed Feb 03 2016 Fedora Release Engineering <releng@fedoraproject.org> - 6.0.26-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_24_Mass_Rebuild

* Mon Feb 1 2016 Orion Poplawski <orion@cora.nwra.com> - 6.0.26-1
- Update to 6.0.26

* Tue Jan 12 2016 Orion Poplawski <orion@cora.nwra.com> - 6.0.25-1
- Update to 6.0.25

* Tue Dec 22 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.24-2
- Add Requires: /usr/bin/ps

* Tue Dec 1 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.24-1
- Update to 6.0.24

* Wed Nov 25 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.22-1
- Update to 6.0.22

* Mon Nov 23 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.21-1
- Update to 6.0.21

* Fri Nov 20 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.20-1
- Update to 6.0.20

* Wed Nov 18 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.19-1
- Update to 6.0.19

* Mon Nov 16 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.18-1
- Update to 6.0.18

* Thu Nov 12 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.17-1
- Update to 6.0.17

* Wed Nov 11 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.16-1
- Update to 6.0.16

* Wed Oct 28 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.15-2
- Set PS path
- Add BR zsh

* Mon Oct 26 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.15-1
- Update to 6.0.15

* Wed Oct 21 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.12-2
- Mark 00-modulepath files as config

* Mon Oct 19 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.12-1
- Update to 6.0.12
- Drop shell patch fixed upstream

* Mon Oct 19 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.11-2
- Add patch to support generic and non-bash shells

* Tue Oct 6 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.11-1
- Update to 6.0.11

* Sun Sep 6 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.10-1
- Update to 6.0.10

* Wed Aug 12 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.9-1
- Update to 6.0.9

* Tue Jul 14 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.5-1
- Update to 6.0.5
- Drop tput patch applied upstream

* Mon Jul 13 2015 Orion Poplawski <orion@cora.nwra.com> - 6.0.4-1
- Update to 6.0.4

* Thu Jul 9 2015 Orion Poplawski <orion@cora.nwra.com> - 5.9.4.2-4
- Add patch to suppress tput output

* Tue Jun 16 2015 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 5.9.4.2-3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_23_Mass_Rebuild

* Tue May 26 2015 Orion Poplawski <orion@cora.nwra.com> - 5.9.4.2-2
- Fix alternatives script handling

* Tue May 19 2015 Orion Poplawski <orion@cora.nwra.com> - 5.9.4.2-1
- Update to 5.9.4.2

* Wed Apr 8 2015 Orion Poplawski <orion@cora.nwra.com> - 5.9.3-1
- Update to 5.9.3

* Tue Mar 31 2015 Orion Poplawski <orion@cora.nwra.com> - 5.9.2-1.git76a45db
- Update to 5.9.2-1.git76a45db for Lua 5.3 support

* Wed Mar 18 2015 Orion Poplawski <orion@cora.nwra.com> - 5.9-1
- Update to 5.9

* Tue Nov 4 2014 Orion Poplawski <orion@cora.nwra.com> - 5.8-1
- Update to 5.8

* Fri Sep 5 2014 Orion Poplawski <orion@cora.nwra.com> - 5.7.5-1
- Update to 5.7.5

* Wed Aug 20 2014 Orion Poplawski <orion@cora.nwra.com> - 5.7.4-1
- Update to 5.7.4

* Tue Aug 5 2014 Orion Poplawski <orion@cora.nwra.com> - 5.7.1-1
- Update to 5.7.1

* Thu Jun 26 2014 Orion Poplawski <orion@cora.nwra.com> - 5.6.2-1
- Update to 5.6.2

* Fri Jun 06 2014 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 5.6-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_21_Mass_Rebuild

* Tue May 27 2014 Orion Poplawski <orion@cora.nwra.com> - 5.6-1
- Update to 5.6

* Mon May 5 2014 Orion Poplawski <orion@cora.nwra.com> - 5.5.1-1
- Update to 5.5.1

* Fri May 2 2014 Orion Poplawski <orion@cora.nwra.com> - 5.5-2
- Add EL support

* Thu May 1 2014 Orion Poplawski <orion@cora.nwra.com> - 5.5-1
- Update to 5.5

* Fri Apr 18 2014 Orion Poplawski <orion@cora.nwra.com> - 5.4.2-1
- Update to 5.4.2

* Mon Apr 14 2014 Orion Poplawski <orion@cora.nwra.com> - 5.4.1-1
- Update to 5.4.1

* Tue Apr  1 2014 Orion Poplawski <orion@cora.nwra.com> - 5.3.2-1
- Initial package
