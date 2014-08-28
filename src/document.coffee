###
Documents
=========

This file contains the Document class.

###
util = require 'util'


class Document
  constructor: (collection, mapping) ->
    Object.defineProperty this, 'collection', get: -> collection
    Object.defineProperty this, 'mapping', get: -> mapping
    # TODO Jake: We also need to figure out how to handle default values and
    # embedded documents... soon.
    # Create the attributes on the "class" level, which map to keys
    for attr, key of @mapping
      Object.defineProperty this, attr,
        get: -> key
        enumerable: true

    # TODO Jake: Optimize _map_document on document instances by prebuilding a
    # suitable object to pass to defineProperties instead of looping and
    # calling defineProperty

  Object.defineProperties @prototype,
    ###
    # Return a new document instance.
    ###
    new: value: (doc) ->
      doc ?= {}
      _map_document @mapping, doc

    ###
    # MongoJS method wrappers
    ###
    # Methods that do return documents
    find: value: (args..., cb) ->
      # If there's no callback specified, return a cursor instead
      if typeof cb isnt 'function'
        return @collection.find.apply @collection, args
      args.push @cb cb
      @collection.find.apply @collection, args

    findOne: value: (args..., cb) ->
      args.push @cb cb
      @collection.findOne.apply @collection, args

    # TODO: Finish these
    findAndModify: value: ->
    insert: value: ->
    update: value: ->
    count: value: ->

    # MongoJS methods that don't return documents
    save: get: -> @collection.save.bind @collection
    remove: get: -> @collection.remove.bind @collection

    ###
    # Helper for wrapping documents in a callback.
    ###
    cb: value: (cb) ->
      _mapping = @mapping
      # This our callback wrapper that will munge the document
      (err, doc) ->
        if not cb
          return
        if not doc
          return cb err, doc
        # If a document was returned, we define mappings on it
        if util.isArray doc
          doc = (_map_document(_mapping, d) for d in doc)
        else
          doc = _map_document _mapping, doc
        # We use existence here to make sure we don't try to call non-functions
        cb?(err, doc)


exports.Document = Document


###
# Helper to create mapped attributes on a document.
###
_map_document = (mapping, doc) ->
  # If this already exists, the doc is already mapped
  if doc.__lookupGetter__ '__mapping'
    return
  Object.defineProperty doc, '__mapping', get: -> mapping
  # Iterate over the mapping, creating new getter/setters for all the
  # mapped attributes
  for attr, key of mapping
    Object.defineProperty doc, attr,
      get: -> doc[key]
      set: (value) -> doc[key] = value
  doc

