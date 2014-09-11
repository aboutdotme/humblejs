HumbleJS: MongoDB ODM for Javascript
####################################

HumbleJS is the sister project of `HumbleDB <http://humbledb.readthedocs.org>`_,
an ODM for Python. It attempts to achieve parity as best as possible with the
HumbleDB project, while leveraging nuances of the Javascript language to
provide a convenient and concise API.

.. contents:: User's Guide
   :local:

Tutorial
========

TODO: Write this section


API Documentation
=================

.. The primary domain for this Sphinx documentation is already "js", so we
   don't need that in our declarations here.

This section contains documentation on the public HumbleJS API.

.. class:: Database(mongodb_uri[, options])

   This is a helper class for managing database connections, getting
   collections and creating new documents.


.. class:: Document(collection[, schema])

   This is the basic document class.


.. class:: Embed(key, schema)

   This is used to define embedded document schemas.


