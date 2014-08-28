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
    new: get: -> (doc) ->
      doc ?= {}
      _map_document @mapping, doc

    find: get: -> (args..., cb) ->
      args.push @_wrap_cb cb
      @collection.find.apply @collection, args

    ###
    # Return a single document.
    ###
    findOne: get: -> (args..., cb) ->
      args.push @_wrap_cb cb
      @collection.findOne.apply @collection, args

    ###
    # Save a document instance
    ###
    save: get: -> (args..., cb) ->
      args.push @_wrap_cb cb
      @collection.save.apply @collection, args

    ###
    # Remove one or more document instances
    ###
    remove: get: -> (args..., cb) ->
      args.push @_wrap_cb cb
      @collection.remove.apply @collection, args

    ###
    # Helper for wrapping a single document in a callback.
    ###
    _wrap_cb: get: -> (cb) ->
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
        cb err, doc


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

