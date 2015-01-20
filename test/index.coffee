###
 * Document tests
###
chai = require 'chai'
should = chai.should()
expect = chai.expect
moment = require 'moment'
mongojs = require 'mongojs'

humblejs = require '../index'
Database = humblejs.Database
Document = humblejs.Document
Embed = humblejs.Embed
SparseReport = humblejs.SparseReport


Db = new Database 'humblejs'

# Document that we're going to do some simple testing with
simple_doc = _id: "simple_doc", foo: "bar"

# Create a reference to the raw collection
simple_collection = new Db 'simple'

# Create the SimpleDoc humble document
SimpleDoc = Db.document 'simple',
  foobar: 'foo'
  foo_id: '_id'

# Create the MyDoc humble document
MyDoc = Db.document 'my_doc',
  my_id: '_id'
  attr: 'a'


describe 'Database', ->
  MyDB = new Database 'humblejs'

  it "should return a callable, which returns a collection", ->
    a_collection = new MyDB 'simple'
    expect(a_collection.find).to.be.a 'function'

  it "should have a document creation shortcut", ->
    SomeDoc = MyDB.document 'simple',
      foo_id: '_id'

    expect(SomeDoc.foo_id).to.equal '_id'

  it "should have an accessible collection property", ->
    expect(MyDB.collection).to.be.a 'function'


describe 'Document', ->
  before (done) ->
    # Empty the collection defensively
    simple_collection.remove {}, (err) ->
      MyDoc.remove {}, (err) ->
        # Insert our simple doc into our collection
        simple_collection.insert simple_doc, (err, doc) ->
          throw err if err
          done()

  after (done) ->
    # Empty the collection back out
    simple_collection.remove {}
    MyDoc.remove {}, done

  it "should be available from the package root", ->
    index = require '../index'
    expect(index.Document).to.not.be.undefined

  it "should return a key value when accessing an attribute on the class", ->
    MyDoc.attr.should.equal 'a'

  it "should be able to find a document", (done) ->
    SimpleDoc.findOne _id: 'simple_doc', (err, doc) ->
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
      doc.should.have.property 'foobar'
      expect(doc.foobar).to.equal simple_doc.foo
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

  it "shouldn't care about embedded documents yet", (done) ->
    doc = new MyDoc()
    doc.attr = foo: 'bar'
    doc.attr.foo.should.equal 'bar'
    doc.attr = {}
    doc.attr.bar = 'foo'
    done()

  it "should allow you to create documents without mappings", (done) ->
    _id = 'no_mapping'
    NoMapping = new Document simple_collection
    doc = new NoMapping()
    doc._id = _id
    doc.foo = 'bar'
    doc.should.eql _id: _id, foo: 'bar'
    doc.save (err) ->
      throw err if err
      NoMapping.findOne _id: _id, (err, doc) ->
        throw err if err
        doc.should.eql _id: _id, foo: 'bar'
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

    it "should auto map queries", (done) ->
      SimpleDoc.find foo_id: 'simple_doc', (err, docs) ->
        throw err if err
        docs.should.have.length 1
        doc = docs[0]
        expect(doc).to.not.be.null
        doc.should.eql simple_doc
        done()

    it "should respect projections", (done) ->
      i = 'projections'
      doc = new MyDoc()
      doc._id = i
      doc.attr = i
      doc.save (err) ->
        throw err if err
        MyDoc.find {_id: i}, {_id: 0, a: 1}, (err, docs) ->
          throw err if err
          docs.should.eql [{a: i}]
          done()

    it "should auto map projections", (done) ->
      i = 'projections_map'
      doc = new MyDoc()
      doc._id = i
      doc.attr = i
      doc.save (err) ->
        throw err if err
        MyDoc.find {_id: i}, {_id: 0, attr: 1}, (err, docs) ->
          throw err if err
          docs.should.eql [{a: i}]
          done()

    it "should auto map projections with defaults", (done) ->
      DocWithDefaults = Db.document 'my_doc_with_defaults',
        my_id: '_id'
        attr: ['attr', 'no']

      doc = new DocWithDefaults()
      doc.my_id = 'hello'
      doc.attr = 'yes'
      doc.save (err, docs) ->
        throw err if err
        DocWithDefaults.find my_id: 'hello', {_id: 0, attr: 1}, (err, docs) ->
          throw err if err
          expect(docs).to.not.be.empty
          docs.length.should.equal 1
          doc = docs.pop()
          doc.should.eql attr: 'yes'
          done()

  describe "#findOne()", ->
    it "should auto map queries", (done) ->
      SimpleDoc.findOne foo_id: 'simple_doc', (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        doc.should.eql simple_doc
        done()

    it "should auto map projections", (done) ->
      SimpleDoc.findOne {foo_id: 'simple_doc'}, {foo_id: 1}, (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        doc.should.eql {_id: 'simple_doc'}
        done()

    it "should auto map projections with defaults", (done) ->
      DocWithDefaults = Db.document 'my_doc_with_defaults',
        my_id: '_id'
        attr: ['attr', 'no']

      doc = new DocWithDefaults()
      doc.my_id = 'hello'
      doc.attr = 'yes'
      doc.save()

      DocWithDefaults.findOne {my_id: 'hello'}, {attr: 1}, (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        doc.attr.should.eql 'yes'
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

  describe "#update()", ->
    it "should auto map updates", (done) ->
      i = 'auto_map_updates'
      doc = new MyDoc()
      doc._id = i
      doc.save (err) ->
        throw err if err
        MyDoc.update {my_id: i}, {$inc: {attr: -1}}, (err, result) ->
          throw err if err
          result.n.should.equal 1
          MyDoc.findOne my_id: i, (err, doc) ->
            throw err if err
            doc.should.eql _id: i, a: -1
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
      doc.should.eql a: 'accepting'

  describe "Default values", ->
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

    it "should work when the attribute name is the same as the key name", ->
      Defaulty = Db.document 'defaulty',
        attr: ['attr', 'a']
        attr2: ['attr2', -> 'b']
        attr3: ['a', 'c']

      doc = new Defaulty()
      doc._id = 'defaulty'
      doc.attr.should.equal 'a'
      doc.attr = 1
      doc.attr.should.equal 1
      doc.attr2.should.equal 'b'
      doc.attr2 = 2
      doc.attr2.should.equal 2
      doc.attr3.should.equal 'c'
      doc.attr3 = 3
      doc.attr3.should.equal 3

    it "should work with embedded documents", ->
      Defaulty = Db.document 'defaultyEmbed',
        attr: ['attr', 'a']
        embed: Embed 'embed',
          attr: ['attr', 1]

      doc = new Defaulty()
      doc.attr.should.equal 'a'
      doc.embed.attr.should.equal 1

    it "should work with deeply embedded documents", ->
      Defaulty = Db.document 'defaultyEmbedDeep',
        attr: ['attr', 'a']
        embed: Embed 'embed',
          embed: Embed 'embed',
            attr: ['attr', 1]
            attr2: ['attr2', -> 2]

      doc = new Defaulty()
      doc.attr.should.equal 'a'
      doc.embed.embed.attr.should.equal 1
      doc.embed.embed.attr2.should.equal 2


  describe "Query helper", ->
    it "should transform top level keys into their mapped counterpart", ->
      query = MyDoc._ attr: "test"
      query.should.eql a: "test"

    it "should work inline", (done) ->
      SimpleDoc.findOne SimpleDoc._(foo_id: "simple_doc"), (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        doc.should.eql _id: "simple_doc", foo: "bar"
        done()

    it "should map embedded keys as well", ->
      QueryHelper = Db.document 'queryHelperEmbed',
        attr: 'a'
        embed: Embed 'em',
          attr: 'a'

      query = QueryHelper._ attr: 1, embed: attr: 2
      query.should.eql a: 1, em: a: 2

    it "should work with attributes that have default values", ->
      QueryHelper = Db.document 'queryHelperDefault',
        attr: ['a', 1]

      query = QueryHelper._ attr: true
      query.should.eql a: true


  describe "Convenience methods", ->
    it "should allow saving of a document", (done) ->
      doc = MyDoc()
      doc._id = 'convenience-save'
      doc.attr = 'saved'
      doc.save (err, doc) ->
        throw err if err
        doc.should.eql _id: 'convenience-save', a: 'saved'
        done()

    it "should allow inserting of a document", (done) ->
      doc = MyDoc()
      doc._id = 'convenience-insert'
      doc.attr = 'inserted'
      doc.insert (err, doc) ->
        throw err if err
        doc.should.eql _id: 'convenience-insert', a: 'inserted'
        done()

    it "should allow updating of a document", (done) ->
      doc = MyDoc()
      doc._id = 'convenience-update'
      doc.save (err, doc) ->
        throw err if err
        doc.should.eql _id: 'convenience-update'
        doc.update $set: a: true, (err, result) ->
          throw err if err
          MyDoc.findOne _id: 'convenience-update', (err, doc) ->
            doc.should.eql _id: 'convenience-update', a: true
            done()

    it "should allow removing of a document", (done) ->
      doc = MyDoc()
      doc._id = 'convenience-remove'
      doc.save (err, doc) ->
        throw err if err
        doc.remove (err, result) ->
          throw err if err
          result.should.eql n: 1
          MyDoc.findOne _id: 'convenience-remove', (err, doc) ->
            throw err if err
            expect(doc).to.be.null
            done()

    it "should error when trying to update a document with no _id", (done) ->
      doc = MyDoc()
      doc.attr = 'bad-update'
      try
        doc.update $inc: foo: 1, (err, result) ->
      catch err
        err.message.indexOf("Cannot update").should.equal 0
        done()

    it "should error when trying to remove a document with no _id", (done) ->
      doc = MyDoc()
      doc.attr = 'bad-remove'
      try
        doc.remove (err, result) ->
      catch err
        err.message.indexOf("Cannot remove").should.equal 0
        done()

  describe "#forJson()", ->
    it "should reverse keys", ->
      doc = new MyDoc _id: 'reverse', a: "val"
      doc.should.eql _id: 'reverse', a: "val"
      dest = doc.forJson()
      dest.should.eql my_id: 'reverse', attr: "val"

    it "should include default values", ->
      DefaultJson = Db.document 'defaultJson',
        attr: ['a', 1]
        attr2: ['b', -> 2]
        attr3: 'c'

      doc = new DefaultJson c: 3
      dest = doc.forJson()
      dest.should.eql attr: 1, attr2: 2, attr3: 3

    it "should include default values with embedded documents", ->
      DefaultJson = Db.document 'defaultJsonEmbed',
        attr: 'a'
        embed: Embed 'em',
          attr: ['at', 1]
          attr2: ['at2', -> 2]

      doc = new DefaultJson()
      doc.attr = []
      dest = doc.forJson()
      dest.should.eql attr: [], embed: attr: 1, attr2: 2

    it "should include default values with deeply embedded documents", ->
      DefaultJson = Db.document 'defaultJsonEmbedDeep',
        attr: 'attr'
        embed: Embed 'embed',
          embed: Embed 'embed',
            attr: ['attr', 1]
            attr2: ['attr2', -> 2]

      doc = new DefaultJson()
      doc.attr = []
      dest = doc.forJson()
      dest.should.eql attr: [], embed: embed: attr: 1, attr2: 2

    it "should not obliterate existing values with defaults", ->
      DefaultJson = Db.document 'defaultJsonEmbedExisting',
        attr: 'attr'
        embed: Embed 'embed',
          attr: ['attr', 0]
          attr2: ['attr2', 2]
          embed: Embed 'embed',
            attr: ['attr', 1]
            attr2: ['attr2', -> 2]

      doc = new DefaultJson()
      doc.attr = []
      doc.embed.foo = 'bar'
      doc.embed.attr = 'a'
      doc.embed.embed.foo = 'bar'
      doc.embed.embed.attr = 'b'
      doc.should.eql
        attr: []
        embed:
          foo: 'bar'
          attr: 'a'
          embed:
            foo: 'bar'
            attr: 'b'
      dest = doc.forJson()
      dest.should.eql
        attr: []
        embed:
          foo: 'bar'
          attr: 'a'
          attr2: 2
          embed:
            attr: 'b'
            attr2: 2
            foo: 'bar'

    it "should not overwrite embedded mapped attributes which have been
      assigned non-object values", ->
      DefaultJson = Db.document 'defaultJsonEmbed',
        attr: 'a'
        embed: Embed 'em',
          attr: ['at', 1]
          attr2: ['at2', -> 2]

      doc = new DefaultJson()
      doc.attr = []
      doc.embed = 1
      dest = doc.forJson()
      dest.should.eql attr: [], embed: 1

    it "should not include embeds without any default values", ->
      DefaultJson = Db.document 'defaultJsonEmbedDeep',
        attr: 'attr'
        embed: Embed 'embed',
          embed: Embed 'embed',
            attr: 'attr'
            attr2: 'attr2'

      doc = DefaultJson()
      doc.forJson().should.eql {}
      doc.attr = 'a'
      doc.forJson().should.eql attr: 'a'
      doc.embed = {}
      doc.forJson().should.eql attr: 'a', embed: {}
      doc.embed.attr = 'b'
      doc.forJson().should.eql attr: 'a', embed: attr: 'b'


describe "Cursor", ->
  before (done) ->
    MyDoc.remove {}, (err) ->
      throw err if err
      MyDoc.insert _id: 'cursor', (err, doc) ->
        throw err if err
        done()

  it "should allow deeply chained cursor", ->
    cursor = MyDoc.find {}
    cursor.should.have.property 'document'
    cursor.should.have.property 'cursor'
    cursor = cursor.limit 1
    cursor.should.have.property 'document'
    cursor.should.have.property 'cursor'
    cursor = cursor.skip 1
    cursor.should.have.property 'document'
    cursor.should.have.property 'cursor'
    cursor = cursor.sort '_id'
    cursor.should.have.property 'document'
    cursor.should.have.property 'cursor'
    cursor.next (err, doc) ->
      throw err if err
      doc.should.not.be.null
      doc.should.have.property '__schema'

  it "should work with forEach", ->
    count = 0
    MyDoc.insert _id: 'forEach', (err, doc) ->
      throw err if err
      cursor = MyDoc.find {}
      cursor.forEach (err, doc) ->
        throw err if err
        if not doc
          count.should.be.gte 1
        count += 1


describe "Embed", ->
  EmbedSave = new Document simple_collection,
    attr: 'a'
    other: 'o'
    sub: Embed 'em',
      val: 'v'

  Embedded = new Document simple_collection,
    attr: 'at'
    embed: Embed 'em',
      attr: ['at', 666]

  Deep = new Document simple_collection,
    one: Embed '1',
      two: Embed '2',
        three: Embed '3',
          four: '4'

  after ->
    EmbedSave.remove {}
    Embedded.remove {}

  it "should work at the class level", ->
    Embedded.embed.should.equal 'em'
    Embedded.embed.attr.should.equal 'em.at'

  it "should allow subkey access via .key", ->
    Embedded.embed.attr.key.should.equal 'at'

  it "should allow deeply nested embedded documents", ->
    Deep.one.two.three.four.should.equal '1.2.3.4'
    Deep.one.two.three.four.key.should.equal '4'

  it "should work when saving", (done) ->
    doc = new EmbedSave()
    doc._id = 'embed-save'
    doc.attr = "attrval"
    doc.other = "otherval"
    doc.sub.val = true
    EmbedSave.save doc, (err, doc) ->
      throw err if err
      doc.should.eql
        _id: "embed-save"
        a: "attrval"
        o: "otherval"
        em:
          v: true
      done()

  it "should work with deep assignment", ->
    doc = new Deep()
    doc.one.two.three.four = 'fourval'
    doc.should.eql 1: 2: 3: 4: 'fourval'

  it "should work with arrays", ->
    doc = new Embedded()
    doc.embed = [{at: 1}, {at: 2}]
    doc.embed[0].attr.should.equal 1
    doc.embed[1].attr.should.equal 2

  it "should allow you to use .new() on arrays", ->
    doc = new Embedded()
    doc.embed = []
    subdoc = doc.embed.new()
    subdoc.attr = 'new works'
    doc.should.eql em: [at: 'new works']

  it "should work with retrieved documents that have arrays too", (done) ->
    doc = new Embedded()
    doc._id = 'array-saving'
    doc.embed = []
    item = doc.embed.new()
    item.attr = "huzzah"
    Embedded.save doc, (err, doc) ->
      throw err if err
      doc.should.eql _id: 'array-saving', em: [at: 'huzzah']

      Embedded.findOne _id: 'array-saving', (err, doc) ->
        throw err if err
        doc.should.eql _id: 'array-saving', em: [at: 'huzzah']
        doc.embed[0].attr.should.equal 'huzzah'
        done()

  it "should correctly transform embedded keys", ->
    doc = Embedded._ attr: 'alpha', embed: attr: 'beta'
    doc.should.eql at: 'alpha', em: at: 'beta'

    doc = Deep._ one: two: three: four: 'five'
    doc.should.eql 1: 2: 3: 4: 'five'

  it "should correctly transform dotted keys", ->
    doc = Embedded._ 'embed.attr': 'dotted'
    doc.should.eql 'em.at': 'dotted'

    doc = Embedded._ 'embed.foo': 'dotted'
    doc.should.eql 'em.foo': 'dotted'

  it "should continue mapping dotted keys within operators", ->
    doc = Embedded._ $set: 'embed.attr': 'dotted'
    doc.should.eql $set: 'em.at': 'dotted'

  it "should map all keys within operators", ->
    doc = Embedded._ $set: embed: attr: 'operators'
    doc.should.eql $set: em: at: 'operators'

  it "should work when mapping embedded docs that aren't docs", ->
    doc = Embedded._ attr: 'alpha', embed: 'beta'
    doc.should.eql at: 'alpha', em: 'beta'

  it "should work with #forJson()", ->
    doc = new Embedded()
    doc._id = 'embed'
    doc.embed.attr = 'value'
    json = doc.forJson()
    json.should.eql _id: 'embed', embed: attr: 'value'

  it "should work with #forJson() on deeply nested documents", ->
    doc = new Deep()
    doc._id = 'deep-embed'
    doc.one.two.three.four = 'five'
    json = doc.forJson()
    json.should.eql _id: 'deep-embed', one: two: three: four: 'five'

  it "should work with arrays when calling #forJson()", ->
    doc = new Embedded()
    doc._id = 'arrays'
    doc.embed = [{at: 1}, {at: 2}]
    json = doc.forJson()
    json.should.eql _id: 'arrays', embed: [{attr: 1}, {attr: 2}]


# This is the best way that I can think of to check whether fibers tests
# should work, since describe isn't run itself in a fiber
try
  require.resolve 'mocha-fibers'
  require.resolve 'fibrousity'
  describeFibers = describe
catch err
  describeFibers = describe.skip

describeFibers "Fibers", ->
  # This test suite really should cover everything...
  before (done) ->
    MyDoc.save _id: 'fibers', done

  describe "Document", ->
    describe "#findOne()", ->
      it "should work synchronously", ->
        doc = MyDoc.findOne _id: 'fibers'
        doc.should.eql _id: 'fibers'

    describe "#find()", ->
      it "should work synchronously", ->
        docs = MyDoc.find(_id: 'fibers').toArray()
        docs.should.eql [_id: 'fibers']

      it "should respect projections", ->
        i = 'projections_fibers'
        doc = new MyDoc()
        doc._id = i
        doc.attr = i
        doc.save()
        docs = MyDoc.find {_id: i}, {_id: 0, a: 1}
            .toArray()
        docs.should.eql [{a: i}]

      it "should auto map projections", ->
        i = 'projections_auto_fiber'
        doc = new MyDoc()
        doc.my_id = i
        doc.attr = i
        doc.save()
        docs = MyDoc.find {my_id: i}, {my_id: 0, attr: 1}
            .toArray()
        docs.should.eql [a: i]

      it "should auto map projections with defaults", ->
        DocWithDefaults = Db.document 'my_doc_with_defaults',
          my_id: '_id'
          attr: ['attr', 'no']

        doc = new DocWithDefaults()
        doc.my_id = 'hello'
        doc.attr = 'yes'
        doc.save()

        docs = DocWithDefaults.find {my_id: 'hello'}, {attr: 1}
            .toArray()
        docs[0].attr.should.eql 'yes'

    describe "#findOne()", ->
      it "should work synchronously", ->
        doc = MyDoc.findOne _id: 'fibers'
        doc.should.eql _id: 'fibers'

      it "should respect projections", ->
        i = 'projections_fiber_findOne'
        doc = new MyDoc()
        doc._id = i
        doc.attr = i
        doc.save()
        doc = MyDoc.findOne {_id: i}, {_id: 0}
        doc.should.eql a: i

      it "should auto map projections", ->
        i = 'projections_auto_fiber_findOne'
        doc = new MyDoc()
        doc.my_id = i
        doc.attr = i
        doc.save()
        doc = MyDoc.findOne {my_id: i}, {my_id: 0, attr: 1}
        doc.should.eql a: i

      it "should auto map projections with defaults", ->
        DocWithDefaults = Db.document 'my_doc_with_defaults',
          my_id: '_id'
          attr: ['attr', 'no']

        doc = new DocWithDefaults()
        doc.my_id = 'hello'
        doc.attr = 'yes'
        doc.save()

        doc = DocWithDefaults.findOne {my_id: 'hello'}, {attr: 1}
        doc.attr.should.eql 'yes'

    describe "#count()", ->
      it "should work synchronously", ->
        count = MyDoc.find().count()
        count.should.be.gte 1

      it "should work without find", ->
        count = MyDoc.count()
        count.should.be.gte 1

    describe "#update()", ->
      it "should create a new doc with upsert", ->
        starting_count = MyDoc.count()
        res = MyDoc.update {_id: 'Fibers.update'}, {$inc: {test: 10}},
          {upsert: true}
        res.n.should.equal 1
        MyDoc.count().should.equal starting_count + 1

      it "should auto map updates", ->
        i = 'update_fiber_auto'
        doc = new MyDoc()
        doc.my_id = i
        doc.update {$inc: attr: 2}, {upsert: true}
        doc = MyDoc.findOne _id: i
        doc.should.eql _id: i, a: 2


describe "SparseReport", ->
  compound_collection = new Db 'compound_index'

  before (done) ->
    compound_collection.remove {}, done

  after (done) ->
    compound_collection.remove {}, done

  skip = it.skip ? ->

  it "should initialize", ->
    DailyReport = new SparseReport simple_collection,
      total: 't',
      all: 'a',
      events: 'e',
    ,
      period: SparseReport.DAY
      ttl: SparseReport.WEEK
      id_mark: '#'
      sum: true

  it "should work like a regular document", (done) ->
    DailyReport = new SparseReport simple_collection,
      total: 't',
      all: 'a',
      events: 'e',
    ,
      period: SparseReport.DAY
      ttl: SparseReport.WEEK
      id_mark: '#'
      sum: true

    doc = new DailyReport()
    doc.total = 1
    doc.all = [1]
    doc.events = metric: 1

    doc.save (err) ->
      throw err if err
      DailyReport.findOne _id: doc._id, (err, doc) ->
        expect(doc).to.be.not.null
        doc.total.should.equal 1
        doc.all.should.eql [1]
        doc.events.metric.should.equal 1
        done()

  describe "#getId", ->
    Report = new SparseReport simple_collection, {},
      period: SparseReport.DAY

    it "should return a string identifier", ->
      _id = Report.getId 'ident', 0
      _id.should.equal 'ident#000000000000000'

    it "should respect id_mark options", ->
      MarkedReport = new SparseReport simple_collection, {},
        period: SparseReport.DAY
        id_mark: '-'
      _id = MarkedReport.getId 'ident', 0
      _id.should.equal 'ident-000000000000000'

    it "should work without specifying the timestamp", ->
      _id = Report.getId 'ident'
      _id.should.match /^ident#\d{15}/

  describe "#getTimestamp", ->
    it "should floor the timestamp to the given period", ->
      YearReport = new SparseReport simple_collection, {},
        period: SparseReport.YEAR

      start = moment.utc 1, 'MM'
      start = start.unix()

      timestamp = YearReport.getTimestamp()
      timestamp.should.eql start

  describe "#dateRange", ->
    Report = new SparseReport simple_collection, {},
      period: SparseReport.MONTH

    it "should correctly return a range less than the period", ->
      # less than a month
      start = new Date(2000, 0, 1)
      end = new Date(2000, 1, 4)
      range = Report.dateRange start, end
      expected_start = moment.utc([2000, 0, 1]).toDate()
      expected_end = moment.utc([2000, 1, 1]).toDate()
      range.length.should.equal 2
      range[0].toString().should.equal expected_start.toString()
      range[1].toString().should.equal expected_end.toString()

    it "should correctly return a range more than the period", ->
      # more than a month
      start = new Date(2000, 0, 1)
      end = new Date(2000, 1, 4)
      range = Report.dateRange start, end
      expected_start = moment.utc([2000, 0, 1]).toDate()
      expected_end = moment.utc([2000, 1, 1]).toDate()
      range.length.should.equal 2
      range[0].toString().should.equal expected_start.toString()
      range[1].toString().should.equal expected_end.toString()

    it "should correctly return a range within the period", ->
      # within a month
      start = new Date(2000, 0, 1)
      end = new Date(2000, 0, 4)
      range = Report.dateRange start, end
      expecte_period = moment.utc([2000, 0, 1]).toDate()
      range.length.should.equal 1
      range[0].toString().should.equal expecte_period.toString()

  describe "#record", ->
    Report = new SparseReport simple_collection, {},
      period: SparseReport.MINUTE

    it "should create a new document", (done) ->
      Report.record 'new_document', event: 1, (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        done()

    it "should record events properly", (done) ->
      Report.record 'user_name',
        'view.source.dashboard': 1
        (err, doc) ->
          throw err if err
          expect(doc).to.not.be.null
          doc.total.should.equal 1
          doc.events.view.source.dashboard.should.equal 1
          done()

    it "should work for multikey events", (done) ->
      Report.record 'user_name_multikey',
        'compliments.type.fave': 1
        'compliments.source.dashboard': 1
        (err, doc) ->
          throw err if err
          expect(doc).to.not.be.null
          doc.total.should.equal 1
          doc.events.compliments.type.fave.should.equal 1
          doc.events.compliments.source.dashboard.should.equal 1
          done()

    it "should work with no events", (done) ->
      Report.record 'no_events', {}, (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        doc.total.should.equal 1
        done()

    it "should work with a number instead of events", (done) ->
      Report.record 'just_increment', 13, (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        doc.total.should.equal 13
        done()

    it "should increase the total appropriately with multiple events", (done) ->
      Report.record 'multi_events',
        'compliments.type.fave': 6
        'compliments.source.dashboard': 8
        (err, doc) ->
          throw err if err
          expect(doc).to.not.be.null
          doc.total.should.equal 8
          done()

    it "should allow past timestamps", (done) ->
      Report.record 'past_timestamp', old: 1, new Date(0), (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        doc.total.should.equal 1
        doc.events.old.should.equal 1
        doc._id.should.equal 'past_timestamp#000000000000000'
        done()

    it "should work for really old dates", (done) ->
      Report.record 'really_old', old: 1, new Date('1900-01-01'), (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        doc.total.should.equal 1
        doc._id.should.equal 'really_old#-00002208988800'
        done()

  describe "#get", ->
    Report = new SparseReport simple_collection, {},
      period: SparseReport.MINUTE
    MonthReport = new SparseReport simple_collection, {},
      period: SparseReport.DAY

    before (done) ->
      counter = 0
      increment = (err, data) ->
        throw err if err
        counter++
        if counter == 2
          done()
      Report.remove {}, increment
      MonthReport.remove {}, increment

    it "should find nothing when empty", (done) ->
      Report.get 'empty', (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        doc.all.length.should.equal 1
        doc.total.should.equal 0
        done()

    it "should actually work", (done) ->
      Report.record 'work_get', event: 1, (err, doc) ->
        throw err if err
        Report.get 'work_get', (err, doc) ->
          throw err if err
          expect(doc).to.not.be.null
          doc.total.should.equal 1
          doc.all[0].should.equal 1
          doc.events.event.should.equal 1
          done()

    it "should work with deep events", (done) ->
      Report.record 'deep_events', 'here.is.a.event': 1, (err, doc) ->
        throw err if err
        Report.get 'deep_events', (err, doc) ->
          throw err if err
          expect(doc).to.not.be.null
          doc.total.should.equal 1
          doc.all[0].should.equal 1
          doc.events.here.is.a.event.should.equal 1
          done()

    it "should work with deep events and multiple documents", (done) ->
      timestamp = moment()
      Report.record 'mult', 'a.b.c': 1, timestamp.toDate(), (err, doc) ->
        throw err if err
        timestamp.add -1, 'minute'
        Report.record 'mult', 'a.b.c': 1, timestamp.toDate(), (err, doc) ->
          throw err if err
          timestamp.add -1, 'minute'
          Report.record 'mult', 'a.b.c': 1, timestamp.toDate(), (err, doc) ->
            throw err if err
            Report.get 'mult', timestamp.toDate(), (err, doc) ->
              throw err if err
              expect(doc).to.not.be.null
              doc.total.should.equal 3
              doc.all.slice(0).should.eql [1, 1, 1]
              doc.events.a.b.c.should.equal 3
              done()

    it "should work with some silly amount of stuff", (done) ->
      count = 30
      timestamp = moment()
      increment = ->
        Report.record 'silly', 'a.b.c': 1, timestamp.toDate(), (err, doc) ->
          throw err if err
          count -= 1
          timestamp.add -10, 'seconds'
          return retrieve() if not count
          increment()

      retrieve = ->
        Report.get 'silly', timestamp.toDate(), (err, doc) ->
          throw err if err
          expect(doc).to.not.be.null
          doc.all.length.should.equal 6
          doc.events.a.b.c.should.equal 30
          done()

      increment()

    it "should give us a zero'd out .all for the range", (done) ->
      name = 'zeroes'
      stamp = moment()
      little_bit_ago = (moment(stamp).add -10, 'minutes').toDate()
      last_hour = (moment(stamp).add -1, 'hour').toDate()
      Report.record name, 'a.b.c': 1, little_bit_ago, (err, doc) ->
        throw err if err
        expect(doc).to.not.be.null
        Report.get 'zeroes', last_hour, (err, doc) ->
          throw err if err
          expect(doc).to.not.be.null
          doc.all.length.should.equal 60
          done()
'''
    it "should return period + 1 results", (done) ->
      name = 'weekguy'
      stamp = moment()
      MonthReport.record name, stamp, {}, (err, doc) ->
        throw err if err
        last_week = (moment(stamp).add -1, 'week').toDate()
        Report.get name, last_week, (err, doc) ->
          console.dir(doc)
          doc.all.length.should.equal 61
          done()

    it skip "should return data recorded just now", (done) ->
      name = 'justnow'
      stamp = moment()
      MonthReport.record name, new Date(), {}, (err, doc) ->
        throw err if err
        yesterday = (moment(stamp).add -1, 'second').toDate()
        Report.get name, yesterday, (err, doc) ->
          console.dir(doc)
          doc.all.length.should.equal 6
          done()
'''
