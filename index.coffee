###
# HumbleJS
# ========
#
# ODM for MongoDB.
#
# TODO
# ----
# * Fibrous compat
#
###
util = require 'util'
mongojs = require 'mongojs'

# Allow this stuff to work with fibrousity
try
  Future = require('fibrousity').Future
  Object.defineProperty exports, 'fibers_enabled', enumerable: true, get: ->
    # This is the only way I could think of to test whether we're currently in
    # a Fiber or not, without actual access to the Fiber module
    try
      process.nextTick.future().wait()
    catch err
      if err.message == "Can't wait without a fiber"
        return false
      throw err
    true
catch
  Future = {}
  exports.fibers_enabled = fibers_enabled = false

# This allows you to control whether queries are automatically mapped
exports.auto_map_queries = auto_map_queries = true


###
# The database class
###
class Database
  constructor: (args...) ->
    db = mongojs.apply mongojs, args

    Object.defineProperty this, 'collection', get: -> (args...) ->
      db.collection.apply db, args

    callable = (name) ->
      # Extra fancy shortcut for getting the DB instance directly
      if not name?
        return db

      # Super fancy shortcut for getting a collection
      db.collection name
    callable.__proto__ = this
    return callable

  document: (args..., mapping) ->
    collection = @collection.apply @collection, args
    return new Document collection, mapping

exports.Database = Database


###
# The document class
###
class Document
  constructor: (collection, mapping) ->
    Object.defineProperty this, 'collection', get: -> collection
    _document = this  # Closure over the document class
    # Create a prototype for the Document instances that already has all
    # the mapped attribute getters and setters
    @instanceProto = {}
    Object.defineProperties @instanceProto,
      # We store the schema for later
      __schema: value: mapping

      # Convenience methods
      save: get: -> (args...) ->
        args.unshift this
        _document.save.apply _document, args

      insert: get: -> (args...) ->
        args.unshift this
        _document.insert.apply _document, args

      update: get: -> (args...) ->
        if not this._id?
          throw new Error "Cannot update without '_id' field"
        args.unshift _id: this._id
        _document.update.apply _document, args

      remove: get: -> (args...) ->
        if not this._id?
          throw new Error "Cannot remove without '_id' field"
        args.unshift _id: this._id
        _document.remove.apply _document, args

      forJson: get: -> () ->
        _transform this, @__inverse_schema, {}

    # Recursively map the document class and prototype
    _map this, mapping, @instanceProto

    # Memoize the inverse mapping
    Object.defineProperty @instanceProto, '__inverse_schema',
      value: _invertSchema @instanceProto.__schema

    # This makes the class returned also callable for syntactic sugar's sake
    callable = (doc) =>
      @new doc
    callable.__proto__ = this
    return callable

  # Document wrapper method factory
  _wrap = (method) ->
    get: -> (query, args..., cb) ->
      if auto_map_queries and method isnt 'insert'
        # Map queries, which should be the first argument
        query = @_ query

      # If the callback isn't a function, but has a value (e.g. is an object)
      # it could be a projection or update object, so we want to add it back to
      # the args
      if cb not instanceof Function and cb?
        args.push cb
        cb = null

      args.unshift query
      # If there's no callback specified, return a cursor instead
      if method is 'find' and cb not instanceof Function
        return new Cursor this, @collection.find.apply @collection, args

      if exports.fibers_enabled and cb not instanceof Function
        future = new Future()
        args.push future.resolver()
        try
          @collection[method].apply @collection, args
        catch err
          # Throw synchronous errors via the future
          future.throw err
        # Get the returned value
        doc = future.wait()
        # If a document was returned, we define mappings on it
        if util.isArray doc
          doc = (@wrap d for d in doc)
        else if doc isnt null
          doc = @wrap doc
        return doc
      else
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
    find: _wrap 'find'
    findOne: _wrap 'findOne'
    findAndModify: _wrap 'findAndModify'
    insert: _wrap 'insert'
    update: _wrap 'update'
    count: _wrap 'count'
    remove: _wrap 'remove'
    # MongoJS methods that don't return documents
    save: get: -> @collection.save.bind @collection

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
      _transform doc, schema, dest


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
      if cb not instanceof Function
        return new Cursor @document, @cursor[method].apply @cursor, args
      # Otherwise we wrap the callback to return Document instances
      args.push @document.cb cb
      @cursor[method].apply @cursor, args

  # Used for methods which return documents, not cursors
  _wrap_doc = (method) ->
    get: -> (args..., cb) ->
      if not exports.fibers_enabled or cb instanceof Function
        # If we don't have a callback, then we are trying to chain the cursor,
        # which should throw an error for these methods, but we let the
        # underlying implementation do that for us
        if cb not instanceof Function
          return new Cursor @document, @cursor[method].apply @cursor, args
        # Otherwise we wrap the callback to return Document instances
        args.push @document.cb cb
        @cursor[method].apply @cursor, args
      else
        future = new Future()
        args.push future.resolver()
        try
          @cursor[method].apply @cursor, args
        catch err
          # Throw synchronous errors via the future
          future.throw err
        # Get the returned value
        doc = future.wait()
        # If a document was returned, we define mappings on it
        if util.isArray doc
          doc = (@document.wrap d for d in doc)
        else if doc isnt null and method isnt 'explain'
          doc = @document.wrap doc
        doc


  Object.defineProperties @prototype,
    batchSize: _wrap 'batchSize'
    count: _wrap_doc 'count'
    explain: _wrap_doc 'explain'
    forEach: _wrap 'forEach'
    limit: _wrap 'limit'
    map: _wrap_doc 'map'
    next: _wrap_doc 'next'
    skip: _wrap 'skip'
    sort: _wrap 'sort'
    toArray: _wrap_doc 'toArray'
    rewind: _wrap 'rewind'
    destroy: _wrap 'destroy'


###
# Embedded documents
###
class EmbeddedDocument
  constructor: (key, mapping) ->
    Object.defineProperties this,
      key: value: key
      mapping: value: mapping
      isEmbed: value: true

    for key, value of mapping
      this[key] = value

# This is a thin wrapper around EmbeddedDocument so we don't need to use the
# new keyword when instantiating document schemas
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


###
# Helper to map a document or query to a key set
###
_transform = (doc, schema, dest) ->
  for name, value of doc
    if name[0] == '$'
      # If we have a special key, we pretty much skip transforming it and
      # attempt to continue transforming subdocs
      dest[name] = {}
      _transform value, schema, dest[name]
      continue
    if '.' in name
      # If the name is a dot-notation key, then we try to transform the parts
      name = _transformDotted name, schema
    if name of schema
      # If we have a name in the schema, then we we need to transform it, and
      # possibly handle embedded and arrays
      key = schema[name]
      key_name = if key.isEmbed then key.key else key
      if key.isEmbed
        # If it's embedded, we have to check if it's an array, or recursively
        # map the embedded document
        if util.isArray value
          # Recursively map all the subdocs in the array
          dest[key_name] = (_transform v, key, {} for v in value)
        else
          # Not an array? Check if it's an object or primitive
          if value is Object value
            dest[key_name] = {}
            _transform value, key, dest[key_name]
          else
            # Must be a primitive
            dest[key_name] = value
      else
        # Not an embedded doc, so we just transform the key
        dest[key_name] = value
    else
      # This isn't a mapped property, so we just add it back
      dest[name] = value
  dest


###
# Helper to map dotted notation property names to key names
###
_transformDotted = (name, schema) ->
  if '.' not in name
    # If there's no more dots, we just attempt to transform the name
    if name of schema
      key = schema[name]
      key = if key.isEmbed then key.key else key
      return key
    else
      return name

  # If we're here, there's more dots to map
  dot = name.indexOf '.'
  parts = name.slice dot + 1
  name = name.slice 0, dot

  if name of schema
    key = schema[name]
    key = if key.isEmbed then key.key else key
    return key + '.' + _transformDotted parts, schema[name]
  else
    return name + '.' + parts


###
# Helper to invert object keys
###
_invertSchema = (schema) ->
  inverse = {}
  for key, value of schema
    if value.isEmbed
      inverse[value.key] = Embed key, _invertSchema value.mapping
    else if util.isArray value
      [value, default_value] = value
      inverse[value] = key
    else
      inverse[value] = key
  inverse

