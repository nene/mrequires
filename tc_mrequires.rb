require "mrequires"
require "test/unit"
require "rubygems"
require "mocha"

module MRequires
  class TestModuleName < Test::Unit::TestCase
    def test_resolve_with_only_default_path
      mn = MRequires::ModuleName.new({"" => "foo/"})
      
      # components are by default JavaScript files
      assert_equal("foo/bar.js", mn.resolve("bar"))
      assert_equal("foo/bar/baz.js", mn.resolve("bar.baz"))
      assert_equal("foo/bar/baz.js", mn.resolve("bar.baz"))
      assert_equal("foo/bar/bar/baz.js", mn.resolve("bar.bar.baz"))
      
      # .js extension is optional
      assert_equal("foo/bar.js", mn.resolve("bar.js"))
      assert_equal("foo/bar/js/baz.js", mn.resolve("bar.js.baz"))

      # .css extension is required for CSS files
      assert_equal("foo/bar.css", mn.resolve("bar.css"))
      assert_equal("foo/bar/baz.css", mn.resolve("bar.baz.css"))
      
      # UPPERCASE extensions are silly, and therefore not acceptable
      assert_equal("foo/bar/JS.js", mn.resolve("bar.JS"))
      assert_equal("foo/bar/CSS.js", mn.resolve("bar.CSS"))
    end
    
    def test_resolve_with_paths_for_some_namespaces
      mn = MRequires::ModuleName.new({
                                        "Foo" => "foo/",
                                        "Bar" => "../lib/bar/",
                                        "" => "default/"
                                      });
      
      assert_equal("foo/bar.js", mn.resolve("Foo.bar"))
      assert_equal("../lib/bar/baz.js", mn.resolve("Bar.baz"))
      assert_equal("default/Hoo/bar.js", mn.resolve("Hoo.bar"))
      assert_equal("foo/bar.css", mn.resolve("Foo.bar.css"))
  
      # ensure, that we don't use Foo namespace here
      assert_equal("default/Foobar.js", mn.resolve("Foobar"))
    end
    
    def test_paths_without_trailing_slash
      mn = MRequires::ModuleName.new({
                                        "Foo" => "foo",
                                        "Bar" => "../lib/bar",
                                        "" => "default"
                                      });
      
      assert_equal("foo/bar.js", mn.resolve("Foo.bar"))
      assert_equal("../lib/bar/baz.js", mn.resolve("Bar.baz"))
      assert_equal("default/Hoo/bar.js", mn.resolve("Hoo.bar"))
    end
  end
  
  class TestSplitter < Test::Unit::TestCase
    def test_split_file
      Splitter.expects(:split).with(:source).returns(:splitted)
      File.expects(:new).with("foo.js").returns(stub(:read => :source))
      assert_equal :splitted, Splitter.split_file("foo.js")
    end
  end
  
  class TestJsSplitter < Test::Unit::TestCase
    # smaller name for test function
    def split(js)
      MRequires::JsSplitter.split(js)
    end
    
    def test_source_code_only
      assert_equal([{:type => :source, :value => "blah blah"}],
                   split("blah blah"))
    end

    def test_requires_only
      assert_equal([{:type => :requires, :value => "Foo.bar"}],
                   split("mRequires('Foo.bar');"))
    end
      
    def test_requires_only_with_double_quotes
      assert_equal([{:type => :requires, :value => "Foo.bar.baz.js"}],
                   split('mRequires("Foo.bar.baz.js");'))
    end
      
    def test_multiple_requires_simple
      assert_equal([{:type => :requires, :value => "foo"},
                    {:type => :requires, :value => "bar"}],
                   split("mRequires('foo', 'bar');"))
    end
      
    def test_multiple_requires_complex
      assert_equal([{:type => :requires, :value => "foo"},
                    {:type => :requires, :value => "bar"},
                    {:type => :requires, :value => "baz"}],
                   split("mRequires( \n 'foo', \n \"bar\",'baz' \n );"))
    end

    def test_empty_requires
      assert_equal([], split("mRequires( );"))
    end

    def test_empty_source
      assert_equal([], split(""))
    end

    def test_source_before_requires
      assert_equal([{:type => :source, :value => "foo(); "},
                    {:type => :requires, :value => "Foo.bar"}],
                   split("foo(); mRequires('Foo.bar');"))
    end
      
    def test_source_after_requires
      assert_equal([{:type => :requires, :value => "Foo.bar"},
                    {:type => :source, :value => " foo();"}],
                   split("mRequires('Foo.bar'); foo();"))
    end

    def test_inside_oneline_comment
      assert_equal([{:type => :source, :value => "bla bla // bla mRequires('foo'); \n "},
                    {:type => :requires, :value => "bar"}],
                   split("bla bla // bla mRequires('foo'); \n mRequires('bar');"))
    end
      
    def test_inside_multiline_comment
      assert_equal([{:type => :source, :value => "bla bla /* bla \n mRequires('foo'); */ "},
                    {:type => :requires, :value => "bar"}],
                   split("bla bla /* bla \n mRequires('foo'); */ mRequires('bar');"))
    end
      
    def test_inside_sq_string
      assert_equal([{:type => :source, :value => "bla bla ' bla mRequires('foo'); ' "},
                    {:type => :requires, :value => "bar"}],
                   split("bla bla ' bla mRequires('foo'); ' mRequires('bar');"))
    end
      
    def test_inside_dq_string
      assert_equal([{:type => :source, :value => 'bla bla " bla mRequires("foo"); " '},
                    {:type => :requires, :value => "bar"}],
                   split('bla bla " bla mRequires("foo"); " mRequires("bar");'))
    end
      
    def test_inside_escaped_sq_string
      assert_equal([{:type => :source, :value => "bla ' bla \\' bla mRequires('foo'); ' "},
                    {:type => :requires, :value => "bar"}],
                   split("bla ' bla \\' bla mRequires('foo'); ' mRequires('bar');"))
    end

    def test_inside_escaped_dq_string
      assert_equal([{:type => :source, :value => 'bla " bla \" bla mRequires("foo"); " '},
                    {:type => :requires, :value => "bar"}],
                   split('bla " bla \" bla mRequires("foo"); " mRequires("bar");'))
    end

    def test_comments_inside_strings
      assert_equal([{:type => :source, :value => '" // /* "; \' // /* \'; '},
                    {:type => :requires, :value => "foo"}],
                   split('" // /* "; \' // /* \'; mRequires("foo");'))
    end

    # Using somewhat real code
    def test_source_and_requires_intermixed
      assert_equal([{:type => :source, :value => "if (true) {\n  "},
                    {:type => :requires, :value => "foo"},
                    {:type => :source, :value => "\n}\nelse {\n  "},
                    {:type => :requires, :value => "bar"},
                    {:type => :requires, :value => "baz"},
                    {:type => :source, :value => "\n}\n"},
                   ],
                   split("if (true) {\n" +
                         "  mRequires('foo');\n"+
                         "}\n" +
                         "else {\n" +
                         "  mRequires('bar', 'baz');\n"+
                         "}\n"))
    end
  end

  class TestCssSplitter < Test::Unit::TestCase
    # smaller name for test function
    def split(js)
      MRequires::CssSplitter.split(js)
    end
    
    def test_source_code_only
      assert_equal([{:type => :source, :value => "blah blah"}],
                   split("blah blah"))
    end
    
    def test_url_only
      assert_equal([{:type => :url, :value => "img/foo.jpg"}],
                   split("url('img/foo.jpg')"))
    end
      
    def test_url_only_with_double_quotes
      assert_equal([{:type => :url, :value => "img/foo.jpg"}],
                   split('url("img/foo.jpg")'))
    end
      
    def test_url_only_without_quotes
      assert_equal([{:type => :url, :value => "img/foo.jpg"}],
                   split('url(img/foo.jpg)'))
    end
      
    def test_url_only_without_quotes_spaced
      assert_equal([{:type => :url, :value => "img/foo.jpg"}],
                   split("url(  img/foo.jpg \t  )"))
    end
      
    def test_empty_source
      assert_equal([], split(""))
    end

    # Using somewhat real code
    def test_source_and_url_intermixed
      assert_equal([{:type => :source, :value => "#nav a:link {\n  background: "},
                    {:type => :url, :value => "img/bg.gif"},
                    {:type => :source, :value => " no-repeat;\n}\n#nav a:hover {\n  background-image: "},
                    {:type => :url, :value => "img/hover.png"},
                    {:type => :source, :value => ";\n}\n"},
                   ],
                   split("#nav a:link {\n" +
                         "  background: url( 'img/bg.gif' ) no-repeat;\n"+
                         "}\n" +
                         "#nav a:hover {\n" +
                         "  background-image: url( img/hover.png );\n"+
                         "}\n"))
    end
  end
  
  class TestParser < Test::Unit::TestCase
    def setup
      JsSplitter.stubs(:split_file).returns([])
      @parser = Parser.new(:conf)
    end
    
    def test_conf_is_passed_to_ModuleName
      ModuleName.expects(:new).with(:conf)
      parser = Parser.new(:conf)
    end
    
    def test_file_is_splitted
      JsSplitter.expects(:split_file).with(:filename).returns([])
      @parser.concat(:filename)
    end
    
    def test_only_source_segment
      JsSplitter.stubs(:split_file).returns([{:type => :source, :value => "Some JS code"}])
      assert_equal "Some JS code", @parser.concat(:filename)
    end
    
    def test_many_source_segments
      JsSplitter.stubs(:split_file).returns([{:type => :source, :value => "Some JS code,"},
                                           {:type => :source, :value => "More JS code"}])
      assert_equal "Some JS code,More JS code", @parser.concat(:filename)
    end
    
    def test_require_one_js_file
      ModuleName.any_instance.expects(:resolve).with("Bar").returns("bar.js")
      
      JsSplitter.expects(:split_file).with("foo.js").returns([{:type => :requires, :value => "Bar"},
                                                            {:type => :source, :value => "<local JS>"}])
      JsSplitter.expects(:split_file).with("bar.js").returns([{:type => :source, :value => "<included JS>"}])
      
      assert_equal "<included JS><local JS>", @parser.concat("foo.js")
    end
    
  end

  class TestParserLive < Test::Unit::TestCase
    def prepare(files)
      files.each do |name, source|
        File.expects(:new).with(name).returns(stub(:read => source))
      end
      @parser = Parser.new({"" => "js/"})
    end
    
    def test_two_files_require_same_file
      prepare({
        "js/Init.js" => "mRequires('View');mRequires('Lang');<init>",
        "js/View.js" => "mRequires('Lang');<view>",
        "js/Lang.js" => "<lang>",
      })
      assert_equal "<lang><view><init>", @parser.concat("js/Init.js")
    end
    
    def test_ignoring_css_files
      prepare({
        "js/Init.js" => "mRequires('Foo.css');mRequires('View.js');<init>",
        "js/View.js" => "mRequires('Haa.css');<view>",
      })
      assert_equal "<view><init>", @parser.concat("js/Init.js")
    end
    
    def test_css_mode
      prepare({
        "js/Init.js" => "mRequires('Foo.css');mRequires('View.js');mRequires('Haa.css');<init>",
        "js/View.js" => "mRequires('Haa.css');<view>mRequires('Hii.css');",
        "js/Foo.css" => "#foo{background:url(img/foo.jpg)}\n",
        "js/Haa.css" => "#haa{background:url('../../src/images/haa.jpg')}\n",
        "js/Hii.css" => "#hii{background:url(\"hii.jpg\")}\n",
      })
      assert_equal("#foo{background:url('foo.jpg')}\n" +
                   "#haa{background:url('haa.jpg')}\n" +
                   "#hii{background:url('hii.jpg')}\n",
                   @parser.concat("js/Init.js", :css))
    end
    
    def test_img_mode
      prepare({
        "js/Init.js" => "mRequires('Foo.css');mRequires('View.js');mRequires('Haa.Haa.css');<init>",
        "js/View.js" => "mRequires('Haa.Haa.css');<view>mRequires('Hii.css');",
        "js/Foo.css" => "#foo{background:url(img/foo.jpg)}\n",
        "js/Haa/Haa.css" => "#haa{background:url('../haa.jpg')}\n",
        "js/Hii.css" => "#hii{background:url(\"hii.jpg\")}\n",
      })
      assert_equal("js/img/foo.jpg\n" +
                   "js/Haa/../haa.jpg\n" +
                   "js/hii.jpg\n",
                   @parser.concat("js/Init.js", :img))
    end
    
    def test_jsfiles_mode
      prepare({
        "js/Init.js" => "mRequires('View');mRequires('Foo.css');<init>",
        "js/View.js" => "mRequires('Display');<view>mRequires('Foo.css');",
        "js/Display.js" => "<display>"
      })
      assert_equal("js/Init.js\n" +
                   "js/View.js\n" +
                   "js/Display.js\n",
                   @parser.concat("js/Init.js", :jsfiles))
    end
  end
  
end
