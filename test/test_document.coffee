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

  simple_collection = mongojs('humbledb_js_test', ['simple']).simple
  # Create the SimpleDoc humble document
  SimpleDoc = new Document simple_collection,
    foobar: 'foo'

  # Create the MyDoc humble document
  MyDoc = new Document mongojs('humbledb_js_test').collection('my_doc'),
    attr: 'a'

  before ->
    # Insert our simple doc into our collection
    simple_collection.insert(simple_doc)

  after ->
    # Empty the collection back out
    simple_collection.remove()
    MyDoc.remove()

  it "should have a document in the collection", (done) ->
    doc = simple_collection.findOne {}, (err, doc) ->
      expect(doc).to.not.be.undefined
      doc.should.eql simple_doc
      expect(err).to.be.null
      done()

  it "should be available on the index", ->
    index = require '../index'
    expect(index.Document).to.not.be.undefined

  it "should return a key value when accessing an attribute on the class", ->
    MyDoc.attr.should.equal 'a'

  it "should be able to find a document", (done) ->
    MyDoc.findOne {}, (err, doc) ->
      throw err if err
      expect(doc).to.not.be.undefined
      done()

  it "should not include findOne when you iterate over the document", ->
    for key, value of MyDoc
      key.should.not.equal 'findOne'

  it "should actually return a document", (done) ->
    SimpleDoc.findOne {}, (err, doc) ->
      throw err if err
      expect(doc).to.not.be.undefined
      doc.should.eql simple_doc
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
    doc = SimpleDoc.new()
    doc.foobar = true
    doc.foo.should.equal true
    doc.foo = false
    doc.foobar.should.equal false
    doc.foo = 'bar'
    doc._id = simple_doc._id
    doc.should.eql simple_doc
    done()

  it "should be save-able without any sort of modification", (done) ->
    doc = MyDoc.new()
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

  it "should wrap all returned docs from a find", (done) ->
    MyDoc.save _id: 1, 'a': 1, (err) ->
      throw err if err
      MyDoc.save _id: 2, 'a': 2, (err) ->
        throw err if err
        MyDoc.find {}, (err, docs) ->
          docs.should.have.length.of.at.least 2
          for doc in docs
            doc.should.have.__mapping
          done()


