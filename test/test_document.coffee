###
 * Document tests
###
chai = require 'chai'
should = chai.should()
expect = chai.expect
Faker = require 'Faker'
mongojs = require 'mongojs'


describe 'Document', ->
  Document = require('../index').Document

  # Document that we're going to do some simple testing with
  simple_doc = _id: "simple_doc", foo: "bar"

  simple_collection = mongojs('humblejs').collection('simple')
  # Create the SimpleDoc humble document
  SimpleDoc = new Document mongojs('humblejs').collection('simple'),
    foobar: 'foo'

  # Create the MyDoc humble document
  MyDoc = new Document mongojs('humblejs').collection('my_doc'),
    attr: 'a'

  before ->
    # Empty the collection defensively
    simple_collection.remove {}
    MyDoc.remove {}
    # Insert our simple doc into our collection
    simple_collection.insert(simple_doc)

  after ->
    # Empty the collection back out
    simple_collection.remove {}
    MyDoc.remove {}

  it "should be available from the package root", ->
    index = require '../index'
    expect(index.Document).to.not.be.undefined

  it "should return a key value when accessing an attribute on the class", ->
    debugger
    MyDoc.attr.should.equal 'a'

  it "should be able to find a document", (done) ->
    SimpleDoc.findOne {}, (err, doc) ->
      throw err if err
      expect(doc).to.not.be.null
      done()

  it "should not include findOne when you iterate over the document", ->
    for key, value of MyDoc
      key.should.not.equal 'findOne'

  it "should not break due to weird prototype things", (done) ->
    doc = new MyDoc()
    expect(doc).to.eql {}
    doc.attr = true
    expect(doc).to.eql {a: true}
    doc = new MyDoc()
    expect(doc).to.eql {}
    doc.should.have.property '__schema'
    done()

  it "should actually return a document", (done) ->
    SimpleDoc.findOne {}, (err, doc) ->
      throw err if err
      expect(doc).to.not.be.undefined
      doc.should.have.property '__schema'
      doc.foobar.should.equal simple_doc.foo
      doc._id.should.equal simple_doc._id
      done()

  it "should map attributes to values on instances", (done) ->
    SimpleDoc.findOne {}, (err, doc) ->
      throw err if err
      expect(doc).to.not.be.undefined
      doc.foobar.should.equal 'bar'
      done()

  it "should assign mapped attributes to the correct key", (done) ->
    SimpleDoc.findOne {}, (err, doc) ->
      throw err if err
      expect(doc).to.not.be.undefined
      doc.foobar.should.equal 'bar'
      doc.foobar = 'barfoo'
      doc.foo.should.equal 'barfoo'
      done()

  it "should be able to create new mapped document instances", (done) ->
    doc = new SimpleDoc()
    doc.foobar = true
    doc.foo.should.equal true
    doc.foo = false
    doc.foobar.should.equal false
    doc.foo = 'bar'
    doc._id = simple_doc._id
    doc.should.eql simple_doc
    done()

  it "should be save-able without any sort of modification", (done) ->
    doc = new MyDoc()
    doc.attr = 'attribute'
    doc.a.should.equal 'attribute'
    doc._id = 'unmodified'
    MyDoc.save doc, (err) ->
      throw err if err
      MyDoc.findOne _id: doc._id, (err, retrieved) ->
        throw err if err
        doc.should.eql retrieved
        retrieved.should.eql doc
        retrieved.should.eql _id: 'unmodified', a: 'attribute'
        done()

  it "should allow you to use cursors and wrap callbacks", (done) ->
    cursor = MyDoc.collection.find {}
    cursor.limit 1, (err, docs) ->
      throw err if err
      docs.should.have.length.of 1
      docs[0].should.not.have.property '__schema'

      cursor = MyDoc.find {}
      cursor.limit 1, (err, docs) ->
        throw err if err
        docs.should.have.length.of 1
        docs[0].should.have.property '__schema'
        done()

  describe "#find()", ->
    it "should wrap all returned docs", (done) ->
      MyDoc.save _id: 1, 'a': 1, (err) ->
        throw err if err
        MyDoc.save _id: 2, 'a': 2, (err) ->
          throw err if err
          MyDoc.find {}, (err, docs) ->
            docs.should.have.length.of.at.least 2
            for doc in docs
              doc.should.have.property '__schema'
            done()

  describe "#insert()", ->
    it "should create a new document", (done) ->
      doc = new MyDoc()
      doc.attr = 'insert'
      MyDoc.insert doc, (err, doc) ->
        throw err if err
        doc.should.have.property '_id'
        doc.attr.should.equal 'insert'
        doc.a.should.equal 'insert'
        done()

    it "should allow multiple documents", (done) ->
      docs = (_id: 'insert-multi' + id for id in [0..3])
      MyDoc.insert docs, (err, docs) ->
        throw err if err
        docs.should.have.length.of 4
        docs[0]._id.should.equal 'insert-multi' + 0
        docs[1]._id.should.equal 'insert-multi' + 1
        docs[2]._id.should.equal 'insert-multi' + 2
        docs[3]._id.should.equal 'insert-multi' + 3
        done()

    it "should map all documents", (done) ->
      docs = (_id: 'insert-map' + id for id in [0..3])
      MyDoc.insert docs, (err, docs) ->
        throw err if err
        for doc in docs
          doc.should.have.property '__schema'
        done()

  describe "#new()", ->
    it "is just an alias and helper", ->
      doc = new MyDoc()
      doc.should.have.property '__schema'
      doc = MyDoc.new()
      doc.should.have.property '__schema'

    it "should be able to accept a doc", ->
      doc = new MyDoc a: 'accepting'
      doc.attr.should.equal 'accepting'

  describe "default values", ->
    it "should be declared as arrays", ->
      HasDefaults = new Document mongojs('humblejs').collection('defaults'),
        value: ['v', true]
      HasDefaults.value.should.equal 'v'
      doc = new HasDefaults()
      doc.value.should.equal true

    it "can take functions as defaults which are stored", ->
      i = 0
      counter = ->
        i += 1
      HasDefaults = new Document mongojs('humblejs').collection('defaults'),
        value: ['v', counter]

      doc = new HasDefaults()
      doc.value.should.equal 1
      doc.value.should.equal 1
      doc.v.should.equal 1

      doc = new HasDefaults()
      doc.value.should.equal 2
      doc.v.should.equal 2


