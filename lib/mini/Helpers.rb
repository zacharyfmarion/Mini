# A series of helper functions for manipulating nodes in a parse tree
# Used in Parser.rb and ../mini.rb

module Helpers

  # Mapping ruby types to mini types
  def Helpers.get_type(class_name) 
    case class_name.to_s
    when "Fixnum"; return "Integer"
    when "Float"; return "Float"
    when "Method"; return "Function"
    when "String"; return "String"
    when "Array"; return "Array"
    when "Hash"
      # TODO: We need to check if the Hash is actually a function
      return "Dict"
    when "FalseClass"; return "Boolean"
    when "TrueClass"; return "Boolean"
    else; return nil
    end
  end

  # Get the distance to the nearest function (up the parse tree)
  def Helpers.dist_to_nearest_func(node)
    dist = 0
    while node
      if Helpers.node_name(node) == "FuncStatementNode" ||
         Helpers.node_name(node) == "FuncVariableNode"
        return dist
      end
      dist += 1
      node = node.parent
    end
    # Did not find a function parent
    return nil
  end

  # Return whether a value is an exception or not
  def Helpers.is_exception(node_val, exception) 
    if node_val.class == Hash && node_val.has_key?("exception_type") &&
        node_val["exception_type"] == exception 
      return true
    end
    return false
  end

  # Get the nearest function node on the parse tree
  def Helpers.get_nearest_function(node)
    while node
      if Helpers.node_name(node) == "FuncStatementNode" ||
         Helpers.node_name(node) == "FuncVariableNode"
        return node
      end
      node = node.parent
    end
    # Did not find a function parent
    return nil
  end

  # Strip the trailing number from a node name (probably a better way to do this)
  def Helpers.node_name(node)
    node.relative_class_name.gsub(/\d+$/, '')
  end

  # Create a variable
  def Helpers.make_var(var, mut=false)
    { "value"  => var, "mutable" => mut }
  end

  # Raise a generic error message
  # TODO: Really should print out the Statement node in which the error is 
  # contained ... currently just prints "asdf" if that was the undefined variable
  # in an expression
  # TODO: Also pad the line numbers if there are more than 10 lines
  def Helpers.error(msg, node, type = RuntimeError)
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
  # string - the import string (path to the file) - if it's not a relative path
  #   then we look in lib/modules for the file
  def Helpers.read_import(node, argv, string)
    path = ""
    # If there is no extension add the "mini" extension
    string = File.extname(string) == "" ? string + ".mini" : string
    # if it is not a relative path look in the native modules folder
    if string[0] != "."
      # Get path to the libraries
      path = File.dirname(File.dirname(__FILE__)) + "/modules/" + string
    elsif argv.length > 0 && argv[0] != "-i" && argv[0] != "--interactive"
      path = "./" + File.dirname(argv[0]) + string
    else
      path = string
    end
    # Parsing the file and extracting the exports
    mod = read_file(path)  
    Helpers.error("File #{path} does not exist", node, IOError) unless mod
    p = MiniParser.new(is_module: true)
    p.parse(mod).evaluate
    p # return the parser class
  end

  # Get the imports from a parser containing a files exports
  # p - The parser for the imported file
  # from_statement - The optional from statement "{ map, reduce } from "
  def Helpers.get_imports(p, from_statement)
    exports = {}
    if from_statement
      from_statement.evaluate.each do |import_name|
        exports[import_name] = p.exports[import_name]
      end
    else; exports = p.exports end
    exports
  end

end
