%global perl_vendorlib %(eval $(perl -V:vendorlib); echo $vendorlib)

Name:           gitolite
Version:        1.1
Release:        802f925
Summary:        Highly flexible server for git directory version tracker

Group:          Applications/System
License:        GPLv2
URL:            http://github.com/sitaramc/gitolite
# The source for this package was pulled from upstream's vcs.  Use the
# following commands to generate the tarball:
# $ git clone git://github.com/sitaramc/gitolite.git gitolite
# $ cd gitolite
# $ git checkout ed2bf5
# $ make ed2bf5.tar
Source0:        sitaramc-gitolite-802f925.tar.gz
# Far from being upstreamable
BuildRoot:      %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildArch:      noarch
BuildRequires:  perl(Text::Markdown)
# We provide the module, but don't create a package/name space
Provides:       perl(%{name}) = %{version}-%{release}
Requires:       git
Requires:       openssh-clients
Requires:       perl(:MODULE_COMPAT_%(eval $(%{__perl} -V:version); echo $version))
Requires(pre):  shadow-utils

%description
Gitolite allows a server to host many git repositories and provide access
to many developers, without having to give them real userids on the server.
The essential magic in doing this is ssh's pubkey access and the authorized
keys file, and the inspiration was an older program called gitosis.

Gitolite can restrict who can read from (clone/fetch) or write to (push) a
repository. It can also restrict who can push to what branch or tag, which
is very important in a corporate environment. Gitolite can be installed
without requiring root permissions, and with no additional software than git
itself and perl. It also has several other neat features described below and
elsewhere in the doc/ directory.


%prep
%setup -q -c
# Don't create backups; would mess with %%install


%build
# Format documentation
for F in doc/*.mkd
do
        perl -MText::Markdown >$(echo $F |sed s/.mkd/.html/) <$F \
                -e 'print Text::Markdown::markdown (join "", <>)'
done


%install
rm -rf $RPM_BUILD_ROOT

# Directory structure
install -d $RPM_BUILD_ROOT%{_sharedstatedir}/%{name}
install -d $RPM_BUILD_ROOT%{_bindir}
install -d $RPM_BUILD_ROOT%{perl_vendorlib}
install -d $RPM_BUILD_ROOT%{_datadir}/%{name}

# Code
install -p src/gl-* $RPM_BUILD_ROOT%{_bindir}
install -p -m644 src/*.pm $RPM_BUILD_ROOT%{perl_vendorlib}
cp -a conf src/hooks src/ga-* $RPM_BUILD_ROOT%{_datadir}/%{name}

 
%clean
rm -rf $RPM_BUILD_ROOT


%pre
# Add "gitolite" user per http://fedoraproject.org/wiki/Packaging/UsersAndGroups
getent group %{name} >/dev/null || groupadd -r %{name}
getent passwd %{name} >/dev/null || \
useradd -r -g %{name} -d %{_sharedstatedir}/%{name} -s /bin/sh \
        -c "git repository hosting" %{name}


%files
%defattr(-,root,root,-)
%{_bindir}/*
%{perl_vendorlib}/*
%{_datadir}/%{name}
%attr(-,%{name},%{name}) %{_sharedstatedir}/%{name}
%doc doc/COPYING doc/*.html


%changelog
* Wed Dec 16 2009 Lubomir Rintel (GoodData) <lubo.rintel@gooddata.com> - 0.95-2.20091216git
- Rename patch
- Fix path to post-update hook
- Make example configuration compilable

* Wed Dec 16 2009 Lubomir Rintel (GoodData) <lubo.rintel@gooddata.com> - 0.95-1.20091216git
- Initial packaging
