module("mRequires");

test("makeUrl with only default path", function() {
  var makeUrl = mRequires.init({"": "foo/"}).makeUrl;

  // components are by default JavaScript files
  same(makeUrl("bar"), "foo/bar.js");
  same(makeUrl("bar.baz"), "foo/bar/baz.js");
  same(makeUrl("bar.baz"), "foo/bar/baz.js");
  same(makeUrl("bar.bar.baz"), "foo/bar/bar/baz.js");
  
  // .js extension is optional
  same(makeUrl("bar.js"), "foo/bar.js");
  same(makeUrl("bar.js.baz"), "foo/bar/js/baz.js");

  // .css extension is required for CSS files
  same(makeUrl("bar.css"), "foo/bar.css");
  same(makeUrl("bar.baz.css"), "foo/bar/baz.css");
  
  // UPPERCASE extensions are silly, and therefore not acceptable
  same(makeUrl("bar.JS"), "foo/bar/JS.js");
  same(makeUrl("bar.CSS"), "foo/bar/CSS.js");
});

test("makeUrl with paths for some namespaces", function() {
  var makeUrl = mRequires.init({
    Foo: "foo/",
    Bar: "../lib/bar/",
    "": "default/"
  }).makeUrl;

  same(makeUrl("Foo.bar"), "foo/bar.js");
  same(makeUrl("Bar.baz"), "../lib/bar/baz.js");
  same(makeUrl("Hoo.bar"), "default/Hoo/bar.js");
  same(makeUrl("Foo.bar.css"), "foo/bar.css");
  
  // ensure, that we don't use Foo namespace here
  same(makeUrl("Foobar"), "default/Foobar.js");
});


