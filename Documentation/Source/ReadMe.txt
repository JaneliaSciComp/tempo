To build and deploy the documentation:

	cd Documentation/Source
	make html
	cp -R build/html/* ..
	rm -R build

You need to have Sphinx <http://sphinx-doc.org> installed for this to work.
