# General parser class for a PEG

# For better error messages
require 'colorize'

class Parser < BabelBridge::Parser

  # Holds all of the variables of the program
  # Several variables are provided by default:
  #  - argv -> Command line args provided to the file
  #  - is_main -> Whether or not we are importing the file as a module
  def initialize(store: {}, is_module: false)
    @store ||= store.merge({
      '__argv' => MiniParser.make_var(ARGV, false),
      '__name' => MiniParser.make_var(is_module ? "module" : "main", false)
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

  # The stack stores an array of locals...note that the top of the stack contains
  # a hash of variables that are locally defined. Allows for recursion
  def stack; @stack ||= [] end

  # Function locals
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

  # Get a variable from the store
  def get_var(key)
    ret = nil
    # puts "Stack: #{self.stack.reverse}"
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
    var = MiniParser.make_var(ret, mutable)
    if self.stack.length > 0 then
      self.stack[-1][key] = var
    else
      self.store[key] = var
    end
  end

end
