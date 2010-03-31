#!/usr/bin/env ruby
require 'optparse'
require 'pp'

module MRequires
  
  class ModuleName
    # Takes config object, that specifies where dirrerent namespaces
    # can be found.
    def initialize(conf)
      @conf = conf
    end

    # Resolves module name to filename
    #
    # For example resolve("foo.bar") --> "scripts/foo/bar.js"
    #
    def resolve(name)
      # are we dealing with JavaScript or CSS?
      if name =~ /\.css$/
        suffix = ".css"
      else
        suffix = ".js"
      end
      
      # remove any existing .js or .css suffix,
      # so that we can replace remaining dots with dashes
      cmp_name = name.sub(Regexp.new("\\" + suffix + "$"), "")
        
      # divide component name into name and namespace.
      # when path for that namespace is defined in config,
      # use that path, otherwise use default path
      matches = /^([^.]+)\.(.*)$/.match(cmp_name)
      if (matches && @conf[matches[1]])
        path = @conf[ matches[1] ];
        sub_cmp_name = matches[2];
      else
        path = @conf[""];
        sub_cmp_name = cmp_name;
      end
      
      # add slash to the end of path if it's not already there
      path = /\/$/ =~ path ? path : path+"/"
      
      return path + sub_cmp_name.gsub(/\./, "/") + suffix;
    end
  end

  # Parent class for both CSS and JS splitters
  # Defines common #split_file method.
  # The actual #split method has to be defined by subclasses.
  class Splitter
    # Read in file and split it
    def self.split_file(filename)
      self.split( File.new(filename).read )
    end
  end
  
  # Splits javascript string containing mRequires stataments
  # into sections of code and required files.
  #
  # For example:
  #
  # JsSplitter.split('if (true) { mRequires("Foo.js", "Bar.js"); }')
  #
  # will produce the following array:
  #
  # [
  #   {:type => :source, :value => "if (true) { "},
  #   {:type => :requires, :value => "Foo.js"},
  #   {:type => :requires, :value => "Bar.js"},
  #   {:type => :source, :value => " }"},
  # ]
  #
  # TODO: Currently we don't parse JavaScript properly, which means
  # that mRequires statements are also found inside comments and
  # strings.
  #
  class JsSplitter < Splitter
    def self.split(js)
      result = []
      
      while js.length > 0
        
        if js =~ /\AmRequires\((.*?)\);(.*)\Z/m
          required_stuff = $1
          js = $2

          # add all required items separately
          required_stuff.strip.split(/\s*,\s*/).each do |item|
            result << {:type => :requires, :value => item.gsub(/["']/, "")}
          end
        elsif js =~ /\A(.*?)(mRequires\(.*\);.*)\Z/m
          result << {:type => :source, :value => $1}
          js = $2
        else
          result << {:type => :source, :value => js}
          js = ""
        end
        
      end
      
      return result
    end
  end

  # Finds url()-s from CSS strings
  #
  # For example:
  #
  # CssSplitter.split('body { background: url("img/bg.jpg") no-repeat }')
  #
  # will produce the following array:
  #
  # [
  #   {:type => :source, :value => "body { background: "},
  #   {:type => :url, :value => "img/bg.jpg"},
  #   {:type => :source, :value => " no-repeat }"},
  # ]
  #
  class CssSplitter < Splitter
    def self.split(css)
      result = []
      
      while css.length > 0
        
        if css =~ /\Aurl\((.*?)\)(.*)\Z/m
          css = $2
          result << {:type => :url, :value => $1.strip.gsub(/["']/, "")}
        elsif css =~ /\A(.*?)(url\(.*\).*)\Z/m
          result << {:type => :source, :value => $1}
          css = $2
        else
          result << {:type => :source, :value => css}
          css = ""
        end
        
      end
      
      return result
    end
  end
  
  class Parser
    def initialize(conf)
      @required_files = {}
      @module_name = ModuleName.new(conf)
    end

    # Parse given JavaScript file and concatenate all required files.
    # When mode=:js, returns concatenated JavaScript
    # When mode=:css, returns concatenated CSS
    # When mode=:img, returns list of image filenames included by CSS files
    # When mode=:jsfiles, returns list of JS filenames to be included
    def concat(filename, mode=:js)
      result = ""
      result += filename+"\n" if mode == :jsfiles
      
      JsSplitter.split_file(filename).each do |item|
        case item[:type]
        when :source
          result += item[:value] if mode == :js
        when :requires
          fname = @module_name.resolve(item[:value])
          # skip already required files
          unless @required_files[fname]
            @required_files[fname] = true
            # read CSS and JS files differently
            if fname =~ /\.css$/
              result += concat_css(fname, mode) if mode == :css || mode == :img
            else
              result += concat(fname, mode)
            end
          end
        end
      end
      
      return result
    end

    # When in CSS mode:
    # Reads in CSS file and strips path names from URL-s inside it.
    # So that url(foo/bar.jpg) will become url(bar.jpg).
    # Returns modified CSS.
    #
    # When in IMG mode:
    # Reads CSS file and returns image URL-s inside it
    def concat_css(filename, mode)
      result = ""
      CssSplitter.split_file(filename).each do |part|
        if part[:type] == :source
          result += part[:value] if mode == :css
        else
          if mode == :css
            result += "url('" + part[:value].sub(/^.*?([^\/]+)$/, '\1') + "')"
          else
            result += filename.sub(/[^\/]*$/, '') + part[:value] + "\n"
          end
        end
      end
      return result
    end
    
  end

end



# When running as program, parse the given file
if ARGV[0]
  options = {
    :type => :js,
    :conf => {"" => "js"},
    :file => "",
  }
  
  opts = OptionParser.new do | opts |
    opts.banner = "Usage: ruby mrequires.rb [options] file.js"
    
    opts.on('-t', '--type=TYPE', [:js, :css, :img, :jsfiles], "Result type (js, css, img, jsfiles)") do |type|
      options[:type] = type
    end
    
    opts.on('-c', '--conf=PATHS', "mRequires paths config: Namespace1:path1,NS2:path2,:default/path.\n"+
            "\t\t\t\t     For example --conf=Foo:/lib/foo,Bar:/lib/bar,:/default") do |conf|
      options[:conf] = Hash[ *conf.split(/,/).map{|x|x.split(/:/)}.flatten ]
    end

    opts.on('-h', '--help', "Prints this help message") do
      puts opts
      exit
    end
  end

  files = opts.parse!(ARGV)
  if !files[0]
    puts "ERROR: JavaScript file not specified."
    puts opts
    exit
  end
  options[:file] = files[0]

  parser = MRequires::Parser.new(options[:conf])
  puts parser.concat(options[:file], options[:type])
end

