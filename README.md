humblejs - MongoDB ODM for Javascript
=====================================

HumbleDB for Javascript.

**Document**(*collection*, *schema*) - Return a new Document type, which uses
*collection*. *schema* is an object specifying the property to key mapping.

**Example**:

```javascript
var mongojs = require('mongojs')
var Document = require('humblejs').Document
var MyDoc = new Document(mongojs('testdb').collection('my_doc'), {
    prop: 'a',
    other_prop: 'o',
    default_value: ['d', some_default],
    with_a_stored_default: ['s', function(){ Math.random() }],
    });
doc = new MyDoc();
doc.prop = "foobar"

// Property assignment is mapped
doc === {a: "foobar"}

// Accessing a missing default will return the specified value
doc.default_value === "some default"
```

