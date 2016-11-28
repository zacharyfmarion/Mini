#!/usr/bin/env ruby

require_relative "./mini/Parser"
require "pp"

# TODO: This is a list of things that I want to implement in this language
# 1. DETAILS
#   i) Equality for all expressions (use ruby's equality testing / eval)
#   ii) Floating point numbers - in fact I feel like I should just make all
#      numbers floating pt. seeing as I'm not worried about performance
#   iv) MAKE A RETURN STATEMENT!!!
#   v) MAKE A NULL expression (nada)
# 2. CLASSES - Implement a class syntax to allow for object oriented programming
#    ...this is probably going to be a bit of a pain
# 3. LIBRARIES - write libraries for Math, Strings, etc (once you can do some
#    more things with the language
# 4. Add better error handling
# 6. Actually plan out what kind of syntax you want in the language...right now
#    it's pretty C-like...maybe try some different things
# 7. Break this out into multiple files - this is getting too big to put in one

class MiniParser < Parser
  ignore_whitespace

  # ------------------------------------------------------------------------------ #
  # ----------------------------- HIGHEST LEVEL ---------------------------------- #
  # ------------------------------------------------------------------------------ #

  # A program is a series of expresssions?
  # ...for now this will be sufficient
  rule :program, :statements do
    def evaluate
      statements.evaluate
    end
  end

  # Convenience rule to reduce repetitive code
  rule :codeblock, "{", :statements, "}" do
    def evaluate
      statements.evaluate
    end
  end

  rule :statements, many?(:statement) do
    def evaluate
      ret = nil
      statement.each do |s|
        ret = s.evaluate
      end
      ret
    end
  end

  # A statement is the highest level thing in the language...a program
  # is essentially a group of statements
  rule :statement, any(:import, :export, :decorator, :func_statement, :codeblock, 
                       :comment, :ifelse, :cfor, :forloop, :whileloop, :builtins, 
                       :array_push, :assignment, :expr) do
    def evaluate
      matches[0].evaluate
    end
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------- MODULES -------------------------------------- #
  # ------------------------------------------------------------------------------ #

  # Importing basically means you just evaluate the file in another env
  rule :import, "import", :from_statement?, :string, :import_alias? do
    def evaluate
      # We need to find the basepath relative to the file we are executing (if it is in
      # fact a file
      p = Parser.read_import(self, ARGV, string.evaluate)
      # if there is a from statement, we only take the required exports
      imports = Parser.get_imports(p, from_statement)
      # Import aliasing
      if import_alias
        parser.imports[import_alias.evaluate] = imports
      else
        parser.store = parser.store.merge(imports)
      end
      nil
    end
  end

  # Optional part of import (like JS)
  # import { map, blah } from "./lib/arrays.mini" as arr
  rule :from_statement, "{", many(:lvalue, ","),"}", "from" do
    def evaluate
      lvalue.map {|param| param.to_s }.compact
    end
  end

  rule :import_alias, "as", :lvalue do
    def evaluate; lvalue.evaluate end
  end

  rule :export, "export", any(:func_statement, :assignment, :variable) do
    def evaluate
      # Get name is a method that both assignments and variables have...it returns
      # the string of the variable name in the expression
      name = matches[2].get_name()
      expr = matches[2].evaluate
      parser.exports[name] = Parser.make_var(expr, false)
    end
  end
 
  # ------------------------------------------------------------------------------ #
  # ----------------------------- CONTROL FLOW ----------------------------------- #
  # ------------------------------------------------------------------------------ #

  # dont evaluate a comment to anything
  rule :comment, /#.*$/ do
    def evaluate; nil end
  end

  # If statement
  rule :ifelse, "if", "(", :expr, ")", :codeblock, many?(:elseifclause), :elseclause? do
    def evaluate
      evaluated = false # Whether or not a condition has been met
      ret = nil # if is technically an expression like everything else
      if expr.evaluate then
        ret = statements.evaluate
        evaluated = true
      # If the elseifclause evaluates
      elsif elseifclause 
        elseifclause.each do |clause|
          if clause.condition
            ret = clause.evaluate
            evaluated = true
            return
          end
        end
      end
      if !evaluated
        # Only evaluate the else clause if one exists!
        ret = elseclause ? elseclause.evaluate : nil
      end
      ret
    end
  end

  rule :elseifclause, "elseif", "(", :expr, ")", :codeblock do
    def condition; expr.evaluate end
    def evaluate; codeblock.evaluate end
  end

  # Necessary because the else clause in an if statement is optional
  rule :elseclause, "else", :codeblock do
    def evaluate
      codeblock.evaluate
    end
  end

  # While loop
  rule :whileloop, "while", "(", :expr, ")", :codeblock do
    def evaluate
      while expr.evaluate do
        codeblock.evaluate
      end
    end
  end

  # Traditional c for loop
  rule :cfor, "for", "(", :assignment, ";", :expr, ";", :statement, ")", :codeblock do
    def evaluate
      # save the value of a shadowed variable...there should be a better way to do this
      var_name = assignment.get_name
      temp = nil
      if parser.has_var?(var_name) 
        temp = parser.get_var(var_name)
      end
      # Evaluate the assingment
      assignment.evaluate
      while expr.evaluate do
        codeblock.evaluate
        statement.evaluate
      end
      # Add the value back
      if temp != nil
        parser.add_var(temp["value"], temp["mutable"])
      end
    end
  end

  # For in loop for an array (Really should change this to an iterable...should
  # be able to do something at least similar for a dict
  rule :forloop, "for", "(", :lvalue, "in", :expr, ")", :codeblock do
    def evaluate
      # Need to create a variable in the environment and executed it
      var = lvalue.evaluate
      temp = nil
      i = 0 # This is the index of the array we are on
      arr = expr.evaluate
      Parser.error("#{arr.class} is not iterable (must be an Array)", self) unless arr.class == Array
      if parser.store.has_key?(var) then
        temp = parser.store[var]
      end
      while i < arr.length
        parser.store[var] = Parser.make_var(arr[i])
        codeblock.evaluate
        i += 1
      end
      # Replace the shadowed value back with it's original
      parser.store[var] = temp
    end
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------ BUILT-INS ------------------------------------- #
  # ------------------------------------------------------------------------------ #

  rule :builtins, any(:println, :print, :eval, :raise, :len, :to_str, :to_int, :to_float)

  # A way to print a line
  rule :print, "print", "(", :expr, ")" do
    def evaluate
      print expr.evaluate.to_s
    end
  end

  rule :println, "println", "(", :expr, ")" do
    def evaluate
      puts expr.evaluate.to_s
    end
  end

  # Raise an exception
  rule :raise, "raise", "(", :string, ")" do
    def evaluate
      raise string.evaluate
    end
  end

  rule :eval, "eval", "(", :string, ")" do
    def evaluate; eval(string.evaluate) end
  end

  rule :len, "len", "(", :expr, ")" do
    def evaluate
      expr.evaluate.length
    end
  end

  rule :to_str, "to_str", "(", :expr, ")" do
    def evaluate
      expr.evaluate.to_s
    end
  end

  rule :to_int, "to_int", "(", :expr, ")" do
    def evaluate
      expr.evaluate.to_i
    end
  end

  rule :to_float, "to_float", "(", :expr, ")" do
    def evaluate
      expr.evaluate.to_f
    end
  end
  
  # ------------------------------------------------------------------------------ #
  # ------------------------------ EXPRESSIONS ----------------------------------- #
  # ------------------------------------------------------------------------------ #

  # An expression is something that evaluates to something primitive
  rule :expr, any(:tern, :func, :element_access, :array, :dict, :nada, :unary, :bool, :infix, 
                  :string, :builtins, :call, :number, :variable ) do
    def evaluate
      matches[0].evaluate
    end
  end

  # ------------------------------------------------------------------------------ #
  # ---------------------- HIGHER ORDER DATA STRUCTURES -------------------------- #
  # ------------------------------------------------------------------------------ #

  # Rule for arrays
  rule :array, "[", many?(:expr, ","), "]" do
    def evaluate
      # This is basically like map()...returns a ruby array containing
      # the evaluated items in the array...can be nested !
      expr.collect {|o| o.evaluate}
    end
  end

  # push to an array
  rule :array_push, any(:call, :variable, :array), "<<", :expr do
    def evaluate
      # TODO: Add error handling
      matches[0].evaluate << expr.evaluate 
    end
  end

  # Rule for dicts
  rule :dict, "{", many?(:pair, ","), "}" do
    def evaluate
      # I'm assuming Hash creates a has from a nested list...
      # lemme check that
      Hash[ pair.collect { |p| p.evaluate }]
    end
  end

  # Rule for a pair (helper of dict)
  rule :pair, :expr, ":", :expr do 
    def evaluate
      [ expr[0].evaluate, expr[1].evaluate ]
    end
  end

  rule :element_access, any(:member_access, :array_dict_access)

  # Accessing an array
  rule :array_dict_access, :variable, "[", :expr ,"]" do
    def evaluate
      variable.evaluate[expr.evaluate]
    end
  end

  # For example: test->name
  # Really should have a concept of classes before doing this
  rule :member_access, :variable, "->", :lvalue do
    def evaluate
      var = variable.evaluate 
      Parser.error("Variable does not exist", self) unless var != ""
      Parser.error("Variable #{variable.var_name} cannot be accessed with member syntax", self) unless 
        (var.class == Hash || var.class == Class)
      var[lvalue.evaluate]
    end
  end


  # ------------------------------------------------------------------------------ #
  # ------------------------------ OTHER EXPR ------------------------------------ #
  # ------------------------------------------------------------------------------ #

  rule :tern, any(:bool, :infix, :func, :variable), "?", :expr, ":", :expr do
    def evaluate
      if matches[0].evaluate then expr[0].evaluate
      else expr[1].evaluate end
    end
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------ FUNCTIONS ------------------------------------- #
  # ------------------------------------------------------------------------------ #

  rule :decorator, "@", :variable, :arguments?, :func_statement do
    def evaluate
      # We need to essentially hijack the function statement by passing it through
      # the decorator function
      wrapper_func = nil
      dec = variable.evaluate
      Parser.error("Decorator @#{variable.get_name} must be a Method, not #{dec.class}", self, TypeError) unless dec.class == Hash
      # If we are dealing with a complex decorator
      if arguments
        # We have to call the decorator wrapper with the args to get the actual
        # decorator
        decorator_wrapper = dec["function"]
        wrapper_func = decorator_wrapper.call(*arguments.evaluate)["value"]["function"]
      else
        wrapper_func = dec["function"]
      end 
      func = func_statement.get_function
      # Now assign the function to a variable
      key = func_statement.get_name
      parser.add_var(key, wrapper_func.call(func), false)
    end
  end

  # Helper for parameters
  rule :arguments, "(", many?(:expr, ","), ")" do 
    def evaluate
      expr.map {|tup| tup.evaluate }.compact
    end
  end

  rule :func, any(:func_statement, :func_variable)

  # Functions are really just expressions that can be passed around as 
  # variables...kinda like in python (or ruby for that matter )
  rule :func_variable, "(", many?(:lvalue, ","), ")", "=>", :codeblock do
    def evaluate
      def function(*args)
        # Open up a stack frame for the function call...local variables get stored here
        parser.stack << {}
        params = lvalue
        # Make sure we have the correct number of arguments
        if params.length != args.length then
          Parser.error("Expected #{params.length} arguments, got #{args.length}", self, ArgumentError)
        end
        # Iterate over the parameters
        # We need to update the environment so that the params become variables  
        # make sure we don't override any existing vars - only shadow them
        # args = array of arguments passed in (e.g. function(1,2,3))
        # params = array of parameter names (e.g. define function(a,b,c))
        params.each_with_index do |param, i|
          param_str = param.evaluate
          # Save the arg as a variable in the env
          parser.stack[-1][param_str] = Parser.make_var(args[i])
        end
        # Now we actually evaluate the codeblock in the correct env
        ret = codeblock.evaluate
        # Pop off from the stack all the values of the locals variables
        parser.stack.pop()
        # Return ret ... the last statement by the codeblock...note that we could
        # easily implement a return statement as a "statement" of the highest 
        # precedence which would terminate the execution of the rest of a codeblock...
        # but it would actually be a bit tricky
        ret
      end
      # Finally we return the function
      # The "locals" value stores all the local values on the stack at the time
      # of the creation
      {
        "function" => method(:function),
        "locals" => parser.stack.reduce({}, :merge)
      }
    end
  end

  # Making a function *statement* as a opposed to an expression
  rule :func_statement, /fun|decorator/, :lvalue,  "(", many?(:lvalue, ",") ,")", :codeblock do
    def evaluate
      # Now assign the function to a variable
      func = self.get_function
      key = lvalue[0].evaluate
      parser.add_var(key, func, false)
      func
    end

    def get_function
      def function(*args)
        # Open up a stack frame for the function call...local variables get stored here
        parser.stack << {}
        # get rid of the first lvalue
        params = lvalue[1..-1]
        # Make sure we have the correct number of arguments
        if params.length != args.length then
          Parser.error("Expected #{params.length} arguments, got #{args.length}", self, ArgumentError)
        end
        params.each_with_index do |param, i|
          param_str = param.evaluate
          parser.stack[-1][param_str] = Parser.make_var(args[i])
        end
        # print "Calling #{lvalue[0].to_s}. Stack: "
        # pp parser.stack
        ret = codeblock.evaluate
        parser.stack.pop()
        ret
      end
      {
        "function" => method(:function),
        "locals" => parser.stack.reduce({}, :merge)
      }
    end

    def get_name
      lvalue[0].evaluate
    end
  end
 
  # Call a defined function
  rule :call, :variable, "(", many?(:expr, ","), ")" do
    def evaluate
      args = expr.map {|tup| tup.evaluate }.compact
      func = variable.evaluate
      # Parser.error("Function '#{variable.get_name}' does not exist", self) unless func == Hash
      parser.locals = func["locals"]
      # puts "CALLING: #{variable.get_name}"
      # puts "FUNCTION: #{func}"
      func["function"].call(*args)
    end
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------ PRIMITIVES  ----------------------------------- #
  # ------------------------------------------------------------------------------ #

  # Deal with basic arithmetic and binary and comparisons
  binary_operators_rule :infix, any(:number, :string, :bool, :element_access, :call, :variable), [[:/, :*], [".", :+, :-, :%, :&, :|, :^, "and", "or"], [:<, :<=, :>, :>=, :==]] do
    def evaluate
      # Evaluating the left and right side recursively (with the
      # correct precedence) and checking to make sure the values are 
      # both acutally integers (not floats or whatever the hell else)
      l = left.evaluate; r = right.evaluate
      Parser.error("Cannot perform #{operator} on 'nada'", self, TypeError) unless
        (l != nil && r != nil)
      if operator.to_s == "."
        return l.send :+, r
      elsif operator.to_s == "or"
        return (l || r)
      elsif operator.to_s == "and"
        return (l && r)
      end
      l.send operator, r
    end
  end

  rule :expr, "(", :expr, ")"
  rule :number, "(", :infix, ")"

  rule :unary, any(:not, :binary_not)

  rule :not, "!", :expr do
    def evaluate
      return !expr.evaluate
    end
  end

  rule :binary_not, "~", :expr do
    def evaluate
      return ~expr.evaluate
    end
  end

  # For an lvalue we just return the string value of the parsed
  # variable...as opposed to variable where we actually look up the
  # value in our store
  rule :lvalue, /[a-zA-Z_]+/ do
    def evaluate
      to_s
    end
  end

  rule :bool, any("true", "false") do
    def evaluate
      eval(matches[0].to_s)
    end
  end

  rule :variable, any(:import_access, :simple_var)

  rule :import_access, :lvalue, "::", :lvalue do
    def evaluate
      mod = lvalue[0].evaluate
      var = lvalue[1].evaluate
      if !parser.imports.has_key?(mod)
        Parser.error("Module '#{mod}' does not exist", self)
      elsif !parser.imports[mod].has_key?(var)
        Parser.error("Module '#{mod}' does not contain variable '{var}'", self)
      else 
        parser.imports[mod][var]["value"]
      end
    end
  end
  
  # Retreiving the value of a variable. Note that we check both the store for globals
  # and the stack for local variables saved from a function call
  # TODO: Make this prettier
  rule :simple_var, /[a-zA-Z_]+/ do
    def evaluate
      ret = nil
      var = matches[0].to_s
      if parser.has_var?(var)
        ret = parser.get_var(var)["value"]
      else 
        Parser.error("Variable #{var} does not exist", self)
      end
      ret
    end

    def get_name
      matches[0].to_s
    end
  end

  rule :assignment, any(:init_assignment, :reassignment)

  # Note that if the stack frame is open then the variables are
  # local to that frame
  # Assignments are immutable by default
  rule :init_assignment, "let", match?("mut"), :lvalue, "=", :expr do
    def evaluate
      mutable = (matches[2].to_s == "mut")
      ret = expr.evaluate
      key = lvalue.evaluate
      parser.add_var(key, ret, mutable)
      # Assignment returns the expr that was assigned
      ret
    end

    def get_name
      lvalue.to_s
    end
  end

  rule :reassignment, :lvalue, "=", :expr do
    def evaluate
      ret = expr.evaluate
      key = lvalue.evaluate
      mutable = parser.get_var(key)["mutable"] 
      if !parser.has_var?(key)
        Parser.error("Variable '#{key}' does not exist", self)
      elsif !mutable
        Parser.error("Cannot reassign '#{key}': variable is immutable", self)
      else
        parser.add_var(key, ret, mutable)
      end
      # Assignment returns the expr that was assigned
      ret
    end

    def get_name
      lvalue.to_s
    end
  end
  
  binary_operators_rule :concatenation, any(:string, :call, :number), ["."] do
    def evaluate
      left.evaluate.to_s.send :+, right.evaluate.to_s
    end
  end

  rule :nada, "nada" do
    def evaluate; nil end
  end

  rule :string, "\"", /[^"]*/, "\"" do
    def evaluate
      # Make sure we keep track of whitespace
      matches[1].to_s + matches[2].to_s + matches[3].to_s
    end
  end

  # Number is either a float or int
  rule :number, any(:float, :int)

  rule :int, /\d+/ do
    def evaluate
      to_s.to_i
    end
  end

  rule :float, /\d+\.\d*/ do
    def evaluate
      to_s.to_f
    end
  end

end

# Function to read a file...returns nil if file doesn't exist
def read_file(filename)
  if !File.file?(filename); return nil end
  File.read(filename)
end

# If a command line argument is provided then we parse and run the
# provided file - otherwise we start an interactive session
if ARGV.length == 0 then
  # do nothing
elsif ARGV[0] == "--interactive" || ARGV[0] == "-i"
  # Start an interactive session
  BabelBridge::Shell.new(MiniParser.new).start
else
  # Parse the file with our parser
  mini_parser = MiniParser.new
  file = read_file ARGV[0]
  parse_tree = mini_parser.parse file 
  # Check that the parse tree is valid 
  if parse_tree
    ruby_data_structure = parse_tree.evaluate
    puts ruby_data_structure.inspect
  else
    puts "ParsingError: " + mini_parser.parser_failure_info
  end
end
