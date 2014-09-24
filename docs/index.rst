.. raw:: html

   <script src="http://localhost:35729/livereload.js"></script>

HumbleJS: MongoDB ODM for Javascript
####################################

HumbleJS is the sister project of `HumbleDB <http://humbledb.readthedocs.org>`_,
an ODM for Python. It attempts to achieve parity as best as possible with the
HumbleDB project, while leveraging nuances of the Javascript language to
provide a convenient and concise API.

.. contents:: User's Guide
   :depth: 2
   :local:


Tutorial
========

This is the comprehensive tutorial for using HumbleJS.

.. contents::
   :depth: 1
   :local:

Quickstart
----------

Install HumbleJS::

   $ npm install --save humblejs


Create a new database connection:

.. code-block:: javascript

   var humblejs = require('humblejs');

   my_db = new humblejs.Database('mongodb://localhost:27107/my_db')

Your database object has a factory function for declaring document collection
classes:

.. code-block:: javascript

   // my_db.document(collection_name, schema)
   Coder = my_db.document('coders', {
      name: 'n',
      lang: 'l',
      skill: 's'
      votes: 'v'
      })

The schema is used to map long class and instance property names to short
document keys.

Once created, you can use your document class to create, save, find, etc. All
the MongoDB collection methods are available:

.. code-block:: javascript

   // Create a new document instance
   doc = new Coder()
   doc.name = "Grace Hopper"
   doc.lang = "COBOL"

   // Save the document
   // Document.save(document, callback)
   Coder.save(doc, function(err, doc) {
      if (err) { throw err; }
      console.log("Coder saved")
      })

   // Find a document
   // Queries are automatically translated from long properties to short keys
   // Document.find(query, callback)
   Coder.find({lang: "COBOL"}, function(err, docs) {
      if (err) { throw err; }
      docs.forEach(function(doc){ console.log(doc); })
   })

HumbleJS also provides convenience methods for documents which define an
``_id`` already. If the ``_id`` is missing, then these will throw an error:
   
.. code-block:: javascript

   doc = new Coder()
   doc._id = 1
   doc.name = "Ada Lovelace"

   doc.save(function(err, doc) {
      if (err) { throw err; }
      console.log("Coder saved")
      })

HumbleJS also provides a way to map embedded documents:

.. code-block:: javascript

   Embed = humblejs.Embed

   // Embed(key, schema)
   Library = my_db.document('libraries', {
      name: '_id',
      lang: 'l',
      meta: Embed('m', {
         created: 'c',
         author: 'a'
         }),
      install: 'i'
      })

   doc = new Library()
   doc.name = 'humblejs'
   doc.lang = 'coffeescript'
   doc.meta.created = new Date()
   doc.meta.author = "Jacob Alheid"
   doc.install = "npm install humblejs"

   doc.insert(function (err, doc){
      if (err) { throw err; }
      console.log("Library inserted")
      })

See the rest of the tutorial for more features and detailed descriptions.

Installation
------------

TODO: Write this section

Database connnections
---------------------

This section describes database objects and their use.

Documents
---------

This section describes how to declare, instantiate, and manipulate documents.

Default values
^^^^^^^^^^^^^^

This section describes how to provide default values.

Embedded documents
------------------

This section describes how to use embedded document schemas.

Embedded arrays
^^^^^^^^^^^^^^^

This section describes how embedded arrays work.

Document mapping
----------------

This section describes how HumbleJS maps property names to document keys.

Auto and manual mapping
^^^^^^^^^^^^^^^^^^^^^^^

This section describes how auto-mapping queries works and how to map an
arbitrary long property document to short key names.

Reverse mapping
^^^^^^^^^^^^^^^

This section describes how to translate documents to a human readable or JSON
friendly form.

Convenience methods
-------------------

This section describes shortcut methods available on document instances.


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

   .. function:: document(collection[, schema])

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


Changelog
=========

This section contains a brief history of changes by version.

0.0.7
-----

* Fix bug where projections were lost when calling methods synchronously.

`Released September 24, 2014`.

0.0.6
-----

* Started documentation

