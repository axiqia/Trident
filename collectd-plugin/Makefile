SPECFILE = spec/collectd-trident.spec
PACKAGE=$(shell grep -s '^Name'    $(SPECFILE) | sed -e 's/Name: *//')
VERSION=$(shell grep -s '^Version' $(SPECFILE) | sed -e 's/Version: *//')
PKGNAME=$(PACKAGE)-$(VERSION)
TARFILE=$(PKGNAME).tar.gz

all:
	rm -rf BUILD/$(PKGNAME)
	mkdir -p BUILD/$(PKGNAME)
	cp -rp setup.py collectd_trident share BUILD/$(PKGNAME)/
	cd BUILD/$(PKGNAME) ; python setup.py sdist
	mv BUILD/$(PKGNAME)/dist/$(TARFILE) .
	rm -rf BUILD/$(PKGNAME)

clean:
	rm -f *.tar.gz
	rm -rf BUILD

srpm:   all
	rpmbuild -bs --define '_sourcedir $(PWD)' ${SPECFILE}

rpm:   all
	rpmbuild -ba --define '_sourcedir $(PWD)' ${SPECFILE}

test:
	PYTHONPATH=testing python collectd_trident/__init__.py
