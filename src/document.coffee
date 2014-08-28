###
Documents
=========

This file contains the Document class.

TODO
----

* Real documentation
* Full test coverage
* Embedded documents

###
util = require 'util'



###
# The document class
###
class Document
  constructor: (collection, mapping) ->
    Object.defineProperty this, 'collection', get: -> collection
    Object.defineProperty this, 'mapping', get: -> mapping
    # TODO Jake: We also need to figure out how to handle default values and
    # embedded documents... soon.
    instance_props = __schema: value: mapping
    # Create the attributes on the "class" level, which map to keys
    for attr, key of @mapping
      if util.isArray key
        # Split the key into the key and default value
        [key, value] = key

      # Add the attribute property to the document class
      Object.defineProperty this, attr,
        get: -> key
        enumerable: true

      # Add the getter and setters for the attribute on the document instance
      instance_props[attr] =
        get: ->
          # If the value exists in the doc, just return it
          if key of this
            return this[key]
          # Store callable defaults onto the doc
          val = value?()
          if val
            this[key] = val
          # Return either the calc'd/stored default, or the raw default
          val ? value
        set: (value) -> this[key] = value

    # Create a prototype for the Document instances that already has all
    # the mapped attribute getters and setters
    @instanceProto = {}
    Object.defineProperties @instanceProto, instance_props

    # This makes the class returned also callable for syntactic sugar's sake
    callable = (doc) =>
      @new doc
    callable.__proto__ = this
    return callable

  # Document wrapper method factory
  _wrap = (method) ->
    get: -> (args..., cb) ->
      # If there's no callback specified, return a cursor instead
      if method is 'find' and typeof cb isnt 'function'
        return new Cursor this, @collection.find.apply @collection, args
      # Wrap these callbacks since they return docs
      args.push @cb cb
      @collection[method].apply @collection, args

  Object.defineProperties @prototype,
    ###
    # Return a new document instance.
    #
    # This is the same as doing ``new MyDocument()``.
    ###
    new: value: (doc) ->
      doc ?= {}
      @wrap doc

    ###
    # MongoJS method wrappers
    ###
    # Methods that do return documents
    find: _wrap 'find'
    findOne: _wrap 'findOne'
    findAndModify: _wrap 'findAndModify'
    insert: _wrap 'insert'
    # TODO Jake: Confirm all these don't return documents
    # MongoJS methods that don't return documents
    update: get: -> @collection.update.bind @collection
    count: get: -> @collection.count.bind @collection
    save: get: -> @collection.save.bind @collection
    remove: get: -> @collection.remove.bind @collection

    ###
    # Helper for wrapping documents in a callback.
    ###
    cb: value: (cb) ->
      # This our callback wrapper that will munge the document
      (err, doc) =>
        # No doc or callback? Just get out
        if not doc or not cb
          return cb? err, doc
        # If a document was returned, we define mappings on it
        if util.isArray doc
          doc = (@wrap d for d in doc)
        else
          doc = @wrap doc
        # We use existence here to make sure we don't try to call non-functions
        cb? err, doc

    ###
    # Wrap an individual document
    ###
    wrap: value: (doc) ->
      # Create a proxy object so that assignments don't affect the prototype
      proxy = {}
      proxy.__proto__ = @instanceProto
      # Swap the doc's prototype for our proxy
      doc.__proto__ = proxy
      doc


exports.Document = Document


###
# Cursor which wraps MongoJS cursors ensuring we get document mappings.
###
class Cursor
  constructor: (@document, @cursor) ->

  # Wrapper method factory
  _wrap = (method) ->
    get: -> (args..., cb) ->
      args.push @document.cb cb
      @cursor[method].apply @cursor, args

  Object.defineProperties @prototype,
    batchSize: _wrap 'batchSize'
    count: _wrap 'count'
    explain: _wrap 'explain'
    forEach: _wrap 'forEach'
    limit: _wrap 'limit'
    map: _wrap 'map'
    next: _wrap 'next'
    skip: _wrap 'skip'
    sort: _wrap 'sort'
    toArray: _wrap 'toArray'
    rewind: _wrap 'rewind'
    destroy: _wrap 'destroy'

