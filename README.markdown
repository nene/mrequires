mRequires - Median JS loader and builder
========================================

mRequires is a JavaScipt build system used internally at [Median][].

It provides dynamic loading of JavaScript files at development time
and concatenation of all the code into one big JavaScript file for
deployment.


Usage
-----

To use mRequires statements in JavaScript you must first include the
mrequires.js file and then initialize mRequires, specifying loading
path for each namespace:

    MRequires.init({
      MyApp: "js/",
      MyLib: "lib/js/",
      "": "external-libs/"   // fallback for everything else
    });

After that one can use mRequires for loading files:

    MRequires("MyApp.SettingsPanel");
    MRequires("MyApp.some.other.Component");
    MRequires("MyLib.FooBar");
    MRequires("jquery");

Or doing the same with just one function call:

    MRequires(
      "MyApp.SettingsPanel",
      "MyApp.some.other.Component",
      "MyLib.FooBar",
      "jquery" 
    );

The code above (together with MRequires.init) will load the following
files:

    lib/js/FooBar.js
    js/SettingsPanel.js
    js/some/other/Component.js
    external-libs/jquery.js

This dynamic loading is all good for development purposes, but for
deployed app we want to concatenate all our JavaScript files into one
big file.  This work is done by mrequires.rb script.

The script takes the same config as mRequires.init(), but in a
slightly different format, and the JavaScript file to use as a
starting point:

    ruby mrequires.rb --conf=MyApp:js/,Bar:lib/js/,:external-libs/ main.js


Requirements
------------

To run the mrequires.rb script, default Ruby installation should be
enough.

To run unit tests you need [rubygems][] and [mocha][].


[Median]: http://median.ee
[rubygems]: http://rubyforge.org/projects/rubygems/
[mocha]: http://mocha.rubyforge.org/


