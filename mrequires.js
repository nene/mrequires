/**
 * Creates requirering function for dynamic loading of JavaScript
 * and CSS files.
 * 
 * Synopsis
 * 
 *   // First initialize requirerer by defining namespace-path mapping.
 *   // "" specifies the default path.
 *   mRequires.init({
 *     Median: "../lib/js/median/",
 *     SeeMe: "js/",
 *     "": "../lib/js/"
 *   });
 *   
 *   // Then require the JS and CSS files you need.  Note that adding
 *   // ".js" extension is optional, but ".css" is mandatory.
 *   mRequires(
 *     "SeeMe.foo",
 *     "SeeMe.bar.baz.js",
 *     "SeeMe.bar.baz.css",
 *     "Median.foobar"
 *   );
 * 
 *   // The following files will be loaded:
 *   //
 *   // - js/foo.js
 *   // - js/bar/baz.js
 *   // - js/bar/baz.css
 *   // - ../lib/js/median/foobar.js
 *   
 *   // After that you can call the loaded code
 *   SeeMe.foo();
 * 
 * Loading of JavaScript files works recursively.  When Median.foo
 * requires Median.bar and Median.baz, then these also get loaded
 * when you require Median.foo.
 * 
 */
var mRequires = (function() {
  
  var conf = undefined;
  var loaded = {};
  
  /**
   * Initializes mRequires with conf object.
   * @returns mRequires function itself (just for convenience).
   */
  function init(configuration) {
    conf = configuration;
    return requires;
  }
  
  /**
   * Performs syncronous request to retrieve JavaScript file
   * and evaluates it.
   */
  function loadJavaScript(url) {
    syncRequest({
      // prevent caching
      url: url + "?rand=" + Math.random(),
      success: function(response) {
        var code = response.responseText;
        // evaluate file in the context of global object
        
        // IE will evaluate window.eval() in current scope.
        // Therefore we use IE specific window.execScript()
        if (window.execScript) {
          window.execScript(code);
        }
        else {
          window.eval(code);
        }
      },
      
      // Make a lot of noise on error.
      // Failed mRequires() usually results in serious crash
      // when concatenating JS files for deployment.
      failure: function(response) {
        alert(
          "mRequires: Loading file '" + url + "'\n" +
          "Got: " + response.status + " " + response.statusText
        );
      }
    });
  }
  
  // Makes syncronous XML HTTP Request
  function syncRequest(conf) {
    var xhr = makeXmlHttpRequest();
    
    xhr.open("GET", conf.url, false);
    // At least in Firefox we can not just skip the parameter, so we use null.
    xhr.send(null);
    
    if (xhr.status === 200) {
      conf.success(xhr);
    }
    else {
      conf.failure(xhr);
    }
  }
  
  var makeXmlHttpRequest = (function(){
    if (window.XMLHttpRequest) {
      return function() {
        return new XMLHttpRequest();
      };
    }
    else {
      return function() {
        return new ActiveXObject("Microsoft.XMLHTTP");
      };
    }
  })();
  
  /**
   * Loads CSS file by adding <link> element to document
   *
   * At first I tried to do this with Ext DomHelper and DomQuery,
   * but that didn't work out in IE and Google Chrome.  Using the
   * good-old DOM API directly works fine.
   * 
   * To prevent caching we append unique parameter to the URL.
   */
  function loadCss(url) {
    var head = document.getElementsByTagName("head")[0];
    var link = document.createElement("link");
    link.href = url + "?rand=" + Math.random();
    link.rel = "stylesheet";
    link.type = "text/css";
    head.appendChild(link);
  }
  
  /**
   * Returns the URL of required item
   *
   * @parem name   name of required item
   */
  function makeUrl(name) {
    // are we dealing with JavaScript or CSS?
    if (/\.css$/.test(name)) {
      var suffix = ".css";
    }
    else {
      var suffix = ".js";
    }
    
    // remove any existing .js or .css suffix,
    // so that we can replace remaining dots with dashes
    var cmpName = name.replace(new RegExp("\\" + suffix + "$"), "");
    
    // divide component name into name and namespace.
    // when path for that namespace is defined in config,
    // use that path, otherwise use default path
    var matches = cmpName.match(/^([^.]+)\.(.*)$/);
    if (matches && conf[matches[1]]) {
      var path = conf[ matches[1] ];
      var subCmpName = matches[2];
    }
    else {
      var path = conf[""];
      var subCmpName = cmpName;
    }
    
    return path + subCmpName.replace(/\./g, "/") + suffix;
  }

  /**
   * Loads JavaScript and CSS components
   * 
   * Takes variable number of JavaScript and CSS component names.
   */
  function requires() {
    if (!conf) {
      alert("Mrequires: mRequires() used before MRequires.init() called.");
      return;
    }
    
    for (var i=0; i<arguments.length; i++) {
      
      // We keep track of items by their URL, because different
      // component names can refer to the same URL and we never
      // want to load the same URL twice.
      var url = makeUrl(arguments[i]);
      
      // Load only when not already loaded
      if (!loaded[url]) {
        // mark as loaded
        loaded[url] = true;
        
        if (/\.js$/.test(url)) {
          loadJavaScript(url);
        }
        else if (/\.css$/.test(url)) {
          loadCss(url);
        }
        else {
          alert("mRequires: Unknown file type '"+url+"'.");
        }
      }
    }
  }

  // Make some functions available publicly.
  // - init is needed for initialization.
  // - makeUrl is needed for testing purposes.
  requires.init = init;
  requires.makeUrl = makeUrl;
  
  return requires;
  
})();

