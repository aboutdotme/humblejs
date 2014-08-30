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


# TODO: Expose this?
auto_map_queries = true


###
# The document class
###
class Document
  constructor: (collection, mapping) ->
    Object.defineProperty this, 'collection', get: -> collection
    # Create a prototype for the Document instances that already has all
    # the mapped attribute getters and setters
    @instanceProto = {}
    Object.defineProperty @instanceProto, '__schema', value: mapping

    # Recursively map the document class and prototype
    _map this, mapping, @instanceProto

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
    # TODO shakefu: Confirm all these don't return documents
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
      _proxy doc, @instanceProto

    ###
    # Transform keys in a query document into their mapped counterpart
    ###
    _: value: (doc) ->
      # TODO shakefu: Make this recursively map keys for embedded documents, as
      # well as dot notation keys
      schema = @instanceProto.__schema
      dest = {}
      for name, value of doc
        if name of schema
          dest[schema[name]] = value
        else
          dest[name] = value
      dest


exports.Document = Document


###
# Cursor which wraps MongoJS cursors ensuring we get document mappings.
###
# TODO: shakefu test cursor chaining to ensure that it continues to wrap the
# cursor
class Cursor
  constructor: (@document, @cursor) ->

  # Wrapper method factory
  _wrap = (method) ->
    get: -> (args..., cb) ->
      # If we don't have a callback, then we are chaining the cursor
      if typeof cb isnt 'function'
        return new Cursor @document, @cursor[method].apply @cursor, args
      # Otherwise we wrap the callback to return Document instances
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


###
# Embedded documents
###
class EmbeddedDocument
  constructor: (key, mapping) ->
    Object.defineProperty this, 'key', value: key
    Object.defineProperty this, 'mapping', value: mapping
    Object.defineProperty this, 'isEmbed', value: true

# This is a thin wrapper around EmbeddedDocument so we don't need to use the
# new keyword when instantiating documents
Embed = (key, mapping) ->
  new EmbeddedDocument key, mapping

exports.Embed = Embed


###
# Helper to proxy an object prototype for instances
###
_proxy = (obj, proto) ->
  # Create a proxy object so that assignments don't affect the prototype
  proxy = {}
  proxy.__proto__ = proto
  # Swap the obj's prototype for our proxy
  obj.__proto__ = proxy
  obj


###
# Helper to recursively map properties on and build instance prototypes
###
_map = (obj, mapping, proto, parent_key) ->
  for name, key of mapping
    do (name, key) ->
      if key.isEmbed
        embed = key
        key = embed.key
        # We have to wrap the string key in a String object so we can add more
        # objerties to it
        embed_key = if parent_key then parent_key + '.' + key else key
        embed_key = new String embed_key

        # Define the mapped property
        Object.defineProperty obj, name,
          value: embed_key
          enumerable: true

        # Create the object we use for the embed prototypes
        embed_proto = {}
        # If we it's an embedded array, we need a different prototype
        array_proto = {}
        array_proto.__proto__ = Array.prototype
        # Add a .new() method to embedded arrays to allow creation of new
        # mapped embedded documents conveniently
        Object.defineProperty array_proto, 'new', value: ->
          new_obj = {}
          this.push new_obj
          return _proxy new_obj, embed_proto

        # Define the property on the instance prototype
        Object.defineProperty proto, name,
          get: ->
            # If the value exists in the doc, just return it
            if key of this
              existing = this[key]
              if util.isArray existing
                # If we have an array, we need to map all the embedded
                # documents in that array
                for item in existing
                  _proxy item, embed_proto
                # As well as add the 'new' method to the array itself
                existing = _proxy existing, array_proto
              else
                existing = _proxy existing, embed_proto
              return existing

            # Embeds don't support defaults right now, but if they did, that
            # code would go right here

            # For embedded items we have to save back a new object that we can
            # hold subproperties on
            value = {}
            this[key] = value
            return _proxy value, embed_proto
          set: (value) ->
            this[key] = value

        # Save the submapping onto the Embed prototype
        Object.defineProperty embed_proto, '___schema',
          value: embed.mapping

        # Recursively map embedded keys
        _map embed_key, embed.mapping, embed_proto, embed_key
      else
        if util.isArray key
          # Split the key into the key and default value
          [key, value] = key

        # Add the property to the object we're maping
        if parent_key
          class_key = new String parent_key + '.' + key
          Object.defineProperty obj, name,
            value: class_key
            enumerable: true
          Object.defineProperty obj[name], 'key', value: key
        else
          Object.defineProperty obj, name,
            value: key
            enumerable: true

        # Define the property on the instance prototype
        Object.defineProperty proto, name,
          get: ->
            # If the value exists in the doc, just return it
            if key of this
              return this[key]
            # Store callable defaults onto the doc
            val = value?()
            if val isnt undefined
              this[key] = val
              return val
            # Return either the calc'd/stored default, or the raw default
            return value
          set: (value) ->
            this[key] = value

