# General parser class for a PEG

# For better error messages
require 'colorize'
require "babel_bridge"

class Parser < BabelBridge::Parser

  # Holds all of the variables of the program
  # Several variables are provided by default:
  #  - argv -> Command line args provided to the file
  #  - is_module -> Whether or not we are importing the file as a module
  def initialize(store: {}, is_module: false)
    @store ||= store.merge({
      '__argv' => Parser.make_var(ARGV, false),
      '__name' => Parser.make_var(is_module ? "module" : "main", false)
    })
  end

  # Getter for the store
  def store; @store end

  # Setter for the store
  def store=(store)
    @store = store
  end

  # Exports is a dictionary of things to export to another file
  def exports; @exports ||= {} end
  def imports; @imports ||= {} end

  # The stack stores an array of locals...note that the top of the stack contains
  # a hash of variables that are locally defined. Allows for recursion
  def stack; @stack ||= [] end

  # Function locals
  # TODO: GET RID OF THIS AND JUST USE THE STACK...not sure how to get rid of this
  # without breaking simple decorators (see files/decorators.mini)
  def locals; @locals ||= {} end

  def locals=(locals)
    @locals = locals
  end

  # Create a variable
  def self.make_var(var, mut=false)
    { "value"  => var, "mutable" => mut }
  end

  # Raise a generic error message
  def self.error(msg, node, type = RuntimeError)
    source = ""; line = node.line
    sep = " " * 50
    msg = msg.colorize(:color => :red)
    node.text.each_line do |code|
      source += "#{line} ".colorize(:color => :white, :background => :blue)
      source += " #{code}"
      line += 1
    end
    raise type.new "\n\n#{msg}\n#{sep}\n#{source}\n#{sep}\n"

  end

  # Read an import string and parse the files contents (if it exists)
  # node - the import statement node 
  # argv - the ARGV array for the file being executed (maybe don't need this...)
  # string - the import string (path to the file)
  def self.read_import(node, argv, string)
    basepath = ""
    if argv.length > 0 && argv[0] != "-i" && argv[0] != "--interactive"
      basepath = File.dirname(argv[0])
    end
    # If there is no extension add the "mini" extension
    string = File.extname(string) == "" ? string + ".mini" : string
    # Parsing the file and extracting the exports
    mod = read_file("./" + basepath + string[1..-1])  
    Parser.error("File #{string} does not exist", node, IOError) unless mod
    p = MiniParser.new(is_module: true)
    p.parse(mod).evaluate
    p # return the parser class
  end

  # Get the imports from a parser containing a files exports
  # p - The parser for the imported file
  # from_statement - The optional from statement "{ map, reduce } from "
  def self.get_imports(p, from_statement)
    exports = {}
    if from_statement
      from_statement.evaluate.each do |import_name|
        exports[import_name] = p.exports[import_name]
      end
    else; exports = p.exports end
    exports
  end

  # Get a variable from the store
  def get_var(key)
    ret = nil
    self.stack.reverse_each do |frame|
      # puts "Searching for #{key} in frame #{frame}"
      if frame.has_key?(key); return frame[key] end
    end
    if self.locals.has_key?(key)
      return locals[key]
    end
    # If ret is nil then it was not a local variable
    if ret == nil then
      if self.store.has_key?(key); ret = self.store[key] end
    end
    ret
  end

  # Find out if a variable exists
  def has_var?(key) 
    self.get_var(key) != nil
  end

  # Add a variable to the store
  def add_var(key, ret, mutable)
    var = Parser.make_var(ret, mutable)
    if self.stack.length > 0 then
      self.stack[-1][key] = var
    else
      self.store[key] = var
    end
  end

end
