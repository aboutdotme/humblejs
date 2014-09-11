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
   don't need that in our declarations here. See:
   http://sphinx-doc.org/domains.html#the-javascript-domain for more
   information.

This section contains documentation on the public HumbleJS API.


.. class:: Database(mongodb_uri[, options])

   This is a helper class for managing database connections, getting
   collections and creating new documents.

   :param string mongodb_uri: A MongoDB connection URI (see `the MongoDB \
      documentation on connection strings <http://docs.mongodb.org/manual/reference/connection-string/>`_)
   :param object options: Additional connection options

.. function:: Database.document(collection[, schema])
   
   Factory function for declaring new documents which belong to this
   database.


.. class:: Document(collection[, schema])

   This is the basic document class.

   :param object collection: A MongoJS collection instance
   :param object schema: The schema for this document


.. class:: Embed(key, schema)

   This is used to define embedded document schemas.

   :param string key: The key name for this embedded document
   :param object schema: The embedded document schema


