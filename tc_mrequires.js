module("mRequires");

test("makeUrl with only default path", function() {
  var makeUrl = mRequires.init({"": "foo/"}).makeUrl;

  // components are by default JavaScript files
  equals(makeUrl("bar"), "foo/bar.js");
  equals(makeUrl("bar.baz"), "foo/bar/baz.js");
  equals(makeUrl("bar.baz"), "foo/bar/baz.js");
  equals(makeUrl("bar.bar.baz"), "foo/bar/bar/baz.js");
  
  // .js extension is optional
  equals(makeUrl("bar.js"), "foo/bar.js");
  equals(makeUrl("bar.js.baz"), "foo/bar/js/baz.js");

  // .css extension is required for CSS files
  equals(makeUrl("bar.css"), "foo/bar.css");
  equals(makeUrl("bar.baz.css"), "foo/bar/baz.css");
  
  // UPPERCASE extensions are silly, and therefore not acceptable
  equals(makeUrl("bar.JS"), "foo/bar/JS.js");
  equals(makeUrl("bar.CSS"), "foo/bar/CSS.js");
});

test("makeUrl with paths for some namespaces", function() {
  var makeUrl = mRequires.init({
    Foo: "foo/",
    Bar: "../lib/bar/",
    "": "default/"
  }).makeUrl;

  equals(makeUrl("Foo.bar"), "foo/bar.js");
  equals(makeUrl("Bar.baz"), "../lib/bar/baz.js");
  equals(makeUrl("Hoo.bar"), "default/Hoo/bar.js");
  equals(makeUrl("Foo.bar.css"), "foo/bar.css");
  
  // ensure, that we don't use Foo namespace here
  equals(makeUrl("Foobar"), "default/Foobar.js");
});


