# HumbleJS - MongoDB ODM for Javascript

HumbleJS is the sister project of [HumbleDB](http://humbledb.readthedocs.org/),
a MongoDB ORM for Python. HumbleJS tries to maintain API parity with HumbleDB
where at all possible, and when it makes sense, extends the API for convenience
and clarity in JavaScript and CoffeeScript.

HumbleJS is written in CoffeeScript, but compiled and distributed as
JavaScript.

[![Build Status](https://travis-ci.org/aboutdotme/humblejs.svg?branch=master)](https://travis-ci.org/aboutdotme/humblejs)

Currently HumbleJS is stable in core features, but under development as
nice-to-have features are added regularly. Documentation is a work in progress.

## [Documentation](http://humblejs.readthedocs.org)

[Documentation](http://humblejs.readthedocs.org) is available on Read The Docs.

## Quickstart

HumbleJS is available on [npm](https://www.npmjs.org/package/humblejs).

Instaling HumbleJS...

```bash
$ npm install humblejs
```

And working with HumbleJS makes code clear, concise and readable...

```javascript
var humblejs = require('humblejs');

// Create a new database instance
var my_db = new humblejs.Database('mongodb://localhost:27017/my_db');

// Use the document factory to declare a new Document subclass
var MyDoc = my_db.document('my_docs_collection', {
    doc_id: '_id',
    value: 'val',
    default: ['def', true],
    meta: humblejs.Embed('meta', {
        author: 'auth',
        created: 'created'
    })
});

// A document maps attribute names to document keys for clean, readable code
var doc = new MyDoc();
doc.doc_id = 'example';
doc.value = 1;
doc.meta.author = "Jimmy Page";
doc.meta.created = new Date();

// Documents have convenience methods for saving, inserting, and removing
doc.save(function (err) {
    console.log("Document saved:\n", doc);
    /*
    Document saved:
     { _id: 'example',
       val: 1,
       meta:
        { auth: 'Jimmy Page',
          created: Tue Nov 11 2014 13:11:05 GMT-0800 (PST) } }
    */
});

// Document classes have convenience methods for querying, updating, etc.
MyDoc.find({doc_id: 'example'}, function (err, docs) {
    if (err) throw err;
    // Do something with docs here, which will be an array
});
```

## Changelog

### 1.0.2

* Fix a bug where `$or` and other operators that take an array argument would
  not work.

*Released June 10, 2015*


## Contributors

* [shakefu](https://github.com/shakefu>) (creator, maintainer)
* [nigelkibodeaux](https://github.com/nigelkibodeaux>)

## License

MIT - See LICENSE

