#!/usr/bin/env ruby

require_relative "./mini/Parser"
require_relative "./mini/Helpers"
require "pp"

# TODO: This is a list of things that I want to implement in this language
# 1. DETAILS
#    - Add string formatting
#    - Pass arrays by reference!!!
# 2. CLASSES - Implement a class syntax to allow for object oriented programming
#    ...this is probably going to be a bit of a pain
# 3. LIBRARIES - write libraries for Math, Strings, etc (once you can do some
#    more things with the language
# 4. Actually plan out what kind of syntax you want in the language...right now
#    it's pretty js-like...maybe try some different things
# 5. Break this out into multiple files - this is getting too big to put in one

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

    def get_statements
      statements.get_statements
    end
  end

  rule :statements, many?(:statement) do
    def evaluate
      ret = nil
      dist = Helpers.dist_to_nearest_func(self)
      # Note that this logic is complicated because we have to worry about 
      # exception handling (return, break, continue, etc)
      statement.each do |s|
        ret = s.evaluate
        if Helpers.is_exception(ret, "return")
          # If the value is a return statement we either return the expression (if a function
          # is at the next level up the tree) or just the Hash containing the exception, which 
          # gets carried up through the statements until it reaches a function to return from
          Helpers.error("Cannot return from a non-function", self) unless dist != nil
          return dist > 1 ? ret : ret["value"]
        elsif Helpers.is_exception(ret, "break") || Helpers.is_exception(ret, "continue")
          return ret
        end
      end
      return ret
    end

    def get_statements
      statement
    end
  end

  # A statement is the highest level thing in the language...a program
  # is essentially a group of statements
  rule :statement, any(:import, :export, :decorator, :class_statement, :func_statement, :codeblock, 
                       :comment, :keywords, :ifelse, :cfor, :forloop, :whileloop, :array_push, 
                       :assignment, :expr) do
    def evaluate
      # puts matches[0].parent.class
      matches[0].evaluate
    end

    def is_return; Helpers.node_name(matches[0]) == "ReturnNode" end
  end

  # ------------------------------------------------------------------------------ #
  # ----------------------------------- HELPERS ---------------------------------- #
  # ------------------------------------------------------------------------------ #

  rule :named_param, :lvalue, ":", :expr do
    def get_lvalue; lvalue end
    def get_expr; expr end
  end

  # An argument evaluates to a name (nil if not a named arg, else the lvalue) and
  # a value (the expression that was evaluated)
  rule :arg, any(:named_param, :expr) do
    def evaluate
      is_named = Helpers.node_name(matches[0]) == "NamedParamNode"
      {
        "name" => is_named ? matches[0].get_lvalue.evaluate : nil,
        "value" => is_named ? matches[0].get_expr.evaluate : matches[0].evaluate
      }
    end
  end

  # Helper for parameters
  rule :arguments, "(", many?(:arg, ","), ")" do 
    def evaluate
      arg.map {|a| a.evaluate }.compact
    end
  end

  # Either a param that has a default value or just a regular param
  rule :param, any(:named_param, :lvalue) do
    def evaluate
      is_named = Helpers.node_name(matches[0]) == "NamedParamNode"
      {
        "name" => is_named ? matches[0].get_lvalue.evaluate : matches[0].evaluate,
        "default" => is_named ? matches[0].get_expr.evaluate : nil
      }
    end
  end

  rule :parameters, "(", many?(:param, ","), ")" do 
    def evaluate
      param.map {|p| p.evaluate }.compact
    end
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------- COMMENTS ------------------------------------- #
  # ------------------------------------------------------------------------------ #

  rule :comment, any(:simple_comment, :multi_line_comment) do
    def evaluate; nil end
  end

  # dont evaluate a comment to anything
  rule :simple_comment, /#.*$/

  # Basically keep matching until you see the '*/' group
  rule :multi_line_comment, "/*", /.*?(?=\*\/)/m, "*/"

  rule :docstring, "==/", /.*?(?=\/\=\=)/m, "/==" do
    def evaluate
      matches[2].to_s.strip
    end
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------- CLASSES -------------------------------------- #
  # ------------------------------------------------------------------------------ #

  # This is gonna be quite the pain...you need local vars for classes too so we need
  # To figure out exactly how to store them
  rule :class_statement, "class", :lvalue, :inherit_statement?, "{", many?(:func_statement), "}" do
    def evaluate
      # Basic error handling
      if Helpers.dist_to_nearest_func(self) != nil
        Helpers.error("Cannot declare a class inside a function", self)
      end
      # This is the variable that will store the declared class
      class_name = lvalue.evaluate
      class_var = {
        "__type" => "class",
        "methods" => {}
      }
      # First define a self variable that can be accessed by functions in the class
      # Now evaluate all functions in the class' context
      func_statement.each do |f|
        # Get the bound function object
        method = f.get_function
        name = f.get_name
        # Add the method to the array of methods
        class_var["methods"][name] = method
      end
      # Define an init method that handle the actual instantiation of the the object 
      def __init(*args)
        # if the init function is defined for the class
        if class_var["methods"].has_key?("__init") 
          # Call the init method 
          class_var["methods"]["__init"].call(*args)
        end
      end
      # Redefine the init method to the sugared one above
      class_var["methods"]["__init"] = method(:__init)
      # Add the class as a variable to the store
      parser.add_var(class_name, class_var, true)
      return nil
    end
  end

  rule :class_instantiation, "new", :variable, :arguments do
    def evaluate
      args = arguments.evaluate
      class_var = variable.evaluate
      obj_var = {
        "__type" => "object",
        "methods" => class_var["methods"],
        "instance_vars" => {}
      }
      return obj_var
    end
  end

  rule :inherit_statement, ":", :variable do
    def evaluate
      variable.evaluate
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
      p = Helpers.read_import(self, ARGV, string.evaluate)
      # if there is a from statement, we only take the required exports
      imports = Helpers.get_imports(p, from_statement)
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
      parser.exports[name] = Helpers.make_var(expr, false)
    end
  end

  # ------------------------------------------------------------------------------ #
  # --------------------------------- KEYWORDS ----------------------------------- #
  # ------------------------------------------------------------------------------ #
 
  rule :keywords, any(:return, :break, :continue)

  # Return statement is distinguished so that a codeblock can exit
  # if no expression is provided just return nil
  rule :return, "return", :expr? do
    def evaluate
      # Get the nearest function
      func_node = Helpers.get_nearest_function(self)
      ret = expr ? expr.evaluate : nil
      # If there is an excaption a has is returned
      # IDK of a better way to do this
      return {
        "exception_type" => "return",
        "value" => ret
      }
    end
  end

  # Keywords for loops
  rule :break, "break" do
    def evaluate
      { "exception_type" => "break" }
    end
  end

  rule :continue, "continue" do
    def evaluate
      { "exception_type" => "continue" }
    end
  end

  # ------------------------------------------------------------------------------ #
  # ----------------------------- CONTROL FLOW ----------------------------------- #
  # ------------------------------------------------------------------------------ #

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
        ret = codeblock.evaluate
        dist = Helpers.dist_to_nearest_func(self)
        # Deal with break and continue statements
        if Helpers.is_exception(ret, "return")
          Helpers.error("Cannot return from a non-function", self) unless dist != nil
          return ret
        elsif Helpers.is_exception(ret, "break")
          break
        elsif Helpers.is_exception(ret, "continue")
          # do nothing...by stopping evaluating the statements you have 
          # effectively continued already
        end
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
        ret = codeblock.evaluate
        dist = Helpers.dist_to_nearest_func(self)
        # Deal with break and continue statements
        if Helpers.is_exception(ret, "return")
          Helpers.error("Cannot return from a non-function", self) unless dist != nil
          return ret
        elsif Helpers.is_exception(ret, "break")
          break
        elsif Helpers.is_exception(ret, "continue")
          # do nothing...by stopping evaluating the statements you have 
          # effectively continued already
        end
        statement.evaluate
      end
      # Add the value back
      if temp != nil
        parser.add_var(var_name, temp["value"], temp["mutable"])
      end
    end
  end

  rule :lvalue_tuple, :lvalue, ",", :lvalue do
    def evaluate
      return [ lvalue[0].evaluate, lvalue[1].evaluate]
    end
  end

  # For in loop for a dict (expect a key and value)
  rule :forloop, "for", "(", :lvalue_tuple, "in", :expr, ")", :codeblock do
    def evaluate
      # Need to create a variable in the environment and executed it
      key, value = lvalue_tuple.evaluate
      temp_key = nil; temp_val = nil
      dict = expr.evaluate
      Helpers.error("#{dict.class} is not a suitable iterable (must be an Dict)", self) unless 
        dict.class == Hash
      if parser.store.has_key?(key) then temp_key = parser.store[key] end
      if parser.store.has_key?(value) then temp_val = parser.store[value] end
      dict.each do |k, v|
        parser.store[key] = Helpers.make_var(k)
        parser.store[value] = Helpers.make_var(v)
        ret = codeblock.evaluate
        dist = Helpers.dist_to_nearest_func(self)
        # Deal with break and continue statements
        if Helpers.is_exception(ret, "return")
          Helpers.error("Cannot return from a non-function", self) unless dist != nil
          return ret
        elsif Helpers.is_exception(ret, "break")
          break
        elsif Helpers.is_exception(ret, "continue")
          # do nothing...by stopping evaluating the statements you have 
          # effectively continued already
        end
      end
      # Replace the shadowed value back with it's original
      parser.store[key] = temp_key
      parser.store[value] = temp_val
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
      Helpers.error("#{arr.class} is not a suitable iterable (must be an Array)", self) unless 
        arr.class == Array
      if parser.store.has_key?(var) then
        temp = parser.store[var]
      end
      while i < arr.length
        parser.store[var] = Helpers.make_var(arr[i])
        ret = codeblock.evaluate
        dist = Helpers.dist_to_nearest_func(self)
        # Deal with break and continue statements
        if Helpers.is_exception(ret, "return")
          Helpers.error("Cannot return from a non-function", self) unless dist != nil
          return ret
        elsif Helpers.is_exception(ret, "break")
          break
        elsif Helpers.is_exception(ret, "continue")
          # do nothing...by stopping evaluating the statements you have 
          # effectively continued already
        end
        i += 1
      end
      # Replace the shadowed value back with it's original
      parser.store[var] = temp
    end
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------ BUILT-INS ------------------------------------- #
  # ------------------------------------------------------------------------------ #

  rule :builtins, any(:println, :print, :hash, :eval, :doc, :char, :from_char, :raise,
                      :len, :to_str, :to_int, :to_float, :type)

  # A way to print a line
  rule :print, "print", "(", :expr?, ")" do
    def evaluate
      if expr
        print expr.evaluate.to_s
      else
        print()
      end
    end
  end

  # TODO: Add formatted output (like printf)
  rule :println, "println", "(", :expr?, ")" do
    def evaluate
      if expr
        puts expr.evaluate.to_s
      else
        puts()
      end
    end
  end

  rule :hash, "hash", "(", :expr, ")" do
    def evaluate
      return expr.evaluate.hash
    end
  end

  # Get the docstring of a function
  rule :doc, "doc", "(", :variable, ")" do
    def evaluate
      var = variable.evaluate
      if var.class == Hash && var.has_key?("function") && var["function"].class == Method
        return var["docstring"]
      else 
        Parser.error("Cannot get docstring for non-function")
      end
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

  rule :char, "char", "(", :expr, ")" do
    def evaluate
      str = expr.evaluate
      Helpers.error("Cannot get ascii code for expression of type #{str.class}", self) unless 
        str.class == String
      str.ord
    end
  end

  rule :from_char, "from_char", "(", :expr, ")" do
    def evaluate
      int = expr.evaluate
      Helpers.error("Ascii code must be an integer", self) unless 
        int.class == Fixnum
      int.chr
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

  # We return our custom classes
  rule :type, "type", "(", :expr, ")" do
    def evaluate
      return Helpers.get_type(expr.evaluate.class)
    end
  end
  
  # ------------------------------------------------------------------------------ #
  # ------------------------------ EXPRESSIONS ----------------------------------- #
  # ------------------------------------------------------------------------------ #

  # An expression is something that evaluates to something primitive
  rule :expr, any(:tern, :class_instantiation, :func, :nada, :unary, :infix, 
                  :array, :dict, :element_access, :bool, :string, :builtins, :call, 
                  :number, :variable ) do
    def evaluate
      matches[0].evaluate
    end
  end

  # ------------------------------------------------------------------------------ #
  # ---------------------- HIGHER ORDER DATA STRUCTURES -------------------------- #
  # ------------------------------------------------------------------------------ #

  rule :array, any(:array_comprehension, :simple_array)

  # Rule for arrays
  rule :simple_array, "[", many?(:expr, ","), "]" do
    def evaluate
      # This is basically like map()...returns a ruby array containing
      # the evaluated items in the array...can be nested !
      expr.collect {|o| o.evaluate}
    end
  end

  rule :trailing_if, "if", :expr do
    def evaluate
      return expr.evaluate
    end
  end

  # TODO: Figure out how you want to do this (lazy evaluation ?) 
  # [ 1, 3, 5, 7, 9 ] -> basically a way to filter an array?
  # [ x | x in range(10)] ... really need an "Iterable"
  # [ x | x in range(10) if x < 5 ]
  rule :array_comprehension, "[", :expr, "for", :lvalue, "in", :expr, :trailing_if?, "]" do
    def evaluate
      ret = []
      expr[1].evaluate.each do |e|
        # Add the item we are iterating over
        parser.add_var(lvalue.evaluate, e, true) 
        if trailing_if && trailing_if.evaluate || !trailing_if
          ret << expr[0].evaluate
        end
        # TODO: remove that dummy var
      end
      return ret
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
  rule :array_dict_access, any(:variable, :string, :array, :dict), "[", any(:pair, :expr) ,"]" do
    def evaluate
      expr = matches[0].evaluate
      # if node is a pair then slice the expression
      if Helpers.node_name(matches[4]) == "PairNode"
        Helpers.error("Cannot access a range from expression of type #{expr.class}", self) unless
          expr.class == String || expr.class == Array
        first, last = matches[4].evaluate 
        if first == last; return "" end
        return expr[first..last]
      end
      Helpers.error("Cannot access a element from expression of type '#{expr.class}'", self) unless
        expr.class == String || expr.class == Array || expr.class == Hash
      expr[matches[4].evaluate]
    end
    
    def get_key
      if Helpers.node_name(matches[4]) != "PairNode"
        return matches[4].evaluate
      end
      return nil
    end

    def get_name; variable.get_name end
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
      Helpers.error("Decorator @#{variable.get_name} must be a Method, not #{dec.class}", self, TypeError) unless dec.class == Hash
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

  rule :func, any(:func_statement, :func_variable)

  # Functions are really just expressions that can be passed around as 
  # variables...kinda like in python (or ruby for that matter )
  rule :func_variable, :parameters, "=>", any(:expr, :codeblock) do
    def evaluate
      def function(*args)
        # Open up a stack frame for the function call...local variables get stored here
        parser.stack << {}
        params = parameters.evaluate
        # Make sure we have the correct number of arguments
        if params.length != args.length then
          Helpers.error("Expected #{params.length} arguments, got #{args.length}", self, ArgumentError)
        end
        # Iterate over the parameters
        # We need to update the environment so that the params become variables  
        # make sure we don't override any existing vars - only shadow them
        # args = array of arguments passed in (e.g. function(1,2,3))
        # params = array of parameter names (e.g. define function(a,b,c))
        params.each_with_index do |param, i|
          # Save the arg as a variable in the env
          if args[i]
            parser.stack[-1][param["name"]] = Helpers.make_var(args[i]["value"], true)
          # Else if args[i] does not exist but a default value was specified
          elsif param["default"] != nil
            parser.stack[-1][param["name"]] = Helpers.make_var(param["default"], true)
          else
            Helpers.error("Cannot map function arguments to declared parameters", self, ArgumentError)
          end
        end
        # Now we actually evaluate the codeblock in the correct env
        ret = matches[4].evaluate
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
  rule :func_statement, /fun|decorator/, :lvalue, :parameters, "{", :docstring?, :statements, "}" do
    def evaluate
      # Now assign the function to a variable
      func = self.get_function
      key = lvalue.evaluate
      parser.add_var(key, func, false)
      func
    end

    def get_function
      def function(*args)
        # Open up a stack frame for the function call...local variables get stored here
        parser.stack << {}
        # Array of parameters - either have a specified default value or not
        params = parameters.evaluate
        # puts "Params: #{params}"
        # puts "Args: #{args}"
        # Iterate over each parameter - determine whether it is named or not
        params.each_with_index do |param, i|
          if args[i]
            parser.stack[-1][param["name"]] = Helpers.make_var(args[i]["value"], true)
          # Else if args[i] does not exist but a default value was specified
          elsif param["default"] != nil
            parser.stack[-1][param["name"]] = Helpers.make_var(param["default"], true)
          else
            Helpers.error("Cannot map function arguments to declared parameters", self, ArgumentError)
          end
        end
        ret = statements.evaluate
        parser.stack.pop()
        ret
      end
      {
        "function" => method(:function),
        "locals" => parser.stack.reduce({}, :merge),
        "docstring" => (docstring ? docstring.evaluate : "")
      }
    end

    def get_name
      lvalue.evaluate
    end
  end
 
  # Call a defined function
  rule :call, :variable, :arguments do
    def evaluate
      args = arguments.evaluate
      func = variable.evaluate
      # Helpers.error("Function '#{variable.get_name}' does not exist", self) unless func == Hash
      parser.locals = func["locals"]
      # puts "CALLING: #{variable.get_name}"
      # puts "FUNCTION: #{func}"
      func["function"].call(*args)
    end

    def get_name; variable.get_name end
    def get_arguments; arguments end

  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------ PRIMITIVES  ----------------------------------- #
  # ------------------------------------------------------------------------------ #

  # Deal with basic arithmetic and binary and comparisons
  binary_operators_rule :infix, any(:builtins, :call, :element_access, :nada, :number, :string, :bool, :array, :dict, :variable), [[:**], [:/, :*], [".", :+, :-, :%, :&, :|, :^, "and", "or"], [:<, :<=, :>, :>=, :==, :!=]] do
    def evaluate
      # Evaluating the left and right side recursively (with the
      # correct precedence) and checking to make sure the values are 
      # both acutally integers (not floats or whatever the hell else)
      l = left.evaluate; r = right.evaluate
      # Helpers.error("Cannot perform #{operator} on 'nada'", self, TypeError) unless
        # (l != nil && r != nil)
      if operator.to_s == "."
        return l.to_s.send :+, r.to_s
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

  # boolean is just evaluated as the keywords are the same in ruby
  rule :bool, any("true", "false") do
    def evaluate
      eval(matches[0].to_s)
    end
  end

  rule :variable, any(:import_access, :member_access, :simple_var)

  # For example: test->name
  # Really should have a concept of classes before doing this
  
  rule :member_access, :simple_var, "->", :call do
    def evaluate
      object = simple_var.evaluate 
      Helpers.error("Variable '#{simple_var.get_name}' cannot be accessed with member syntax", self) unless 
        (object.class == Hash && object.has_key?("__type") && object["__type"] == "object")
      method_name = call.get_name
      args = call.get_arguments.evaluate
      puts "Method: #{method_name}"
      puts "Args: #{args}"
      pp object
    end
  end

  rule :member_access, :simple_var, "->", :lvalue do
    def evaluate
      object = matches[0].evaluate 
      prop = lvalue.evaluate
      Helpers.error("Variable '#{matches[0].get_name}' cannot be accessed with member syntax", self) unless 
        (object.class == Hash && object.has_key?("__type") && object["__type"] == "object")
      Helpers.error("Object '#{matches[0].get_name}' does not have property '#{prop}'", self) unless 
        object["instance_vars"].has_key?(prop)
      return object["instance_vars"][prop]
    end
  end

  rule :import_access, :lvalue, "::", :lvalue do
    def evaluate
      mod = lvalue[0].evaluate
      var = lvalue[1].evaluate
      if !parser.imports.has_key?(mod)
        Helpers.error("Module '#{mod}' does not exist", self)
      elsif !parser.imports[mod].has_key?(var)
        Helpers.error("Module '#{mod}' does not contain variable '{var}'", self)
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
        Helpers.error("Variable '#{var}' does not exist", self)
      end
      ret
    end

    def get_name
      matches[0].to_s
    end
  end

  rule :assignment, any(:array_dict_assignment, :init_assignment, :reassignment, :inc_dec)

  # Increment or decrement shorthand (e.g. i++)
  rule :inc_dec, :variable, /(\+\+)|(--)/ do
    def evaluate
      var = variable.evaluate
      key = variable.get_name
      Helpers.error("#{key} must be an integer", self, TypeError) unless 
        var.class == Fixnum
      ret = matches[2].to_s == "++" ? var + 1 : var - 1
      mutable = parser.get_var(key)["mutable"] 
      if !parser.has_var?(key)
        Helpers.error("Variable '#{key}' does not exist", self)
      elsif !mutable
        Helpers.error("Cannot reassign '#{key}': variable is immutable", self)
      else
        parser.add_var(key, ret, mutable)
      end
      # Assignment returns the expr that was assigned
      ret
    end
  end

  rule :array_dict_assignment, :array_dict_access, "=", :expr do
    def evaluate
      ret = expr.evaluate 
      name = array_dict_access.get_name
      key = array_dict_access.get_key
      if !parser.has_var?(name)
        Helpers.error("Variable '#{name}' does not exist", self)
      end
      replace_val = parser.get_var(name)
      replace_val["value"][key] = ret
      parser.add_var(name, replace_val["value"], replace_val["mutable"])
    end
  end

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
        Helpers.error("Variable '#{key}' does not exist", self)
      elsif !mutable
        Helpers.error("Cannot reassign '#{key}': variable is immutable", self)
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

  rule :nada, "nada" do
    def evaluate; nil end
  end

  rule :string, any(:multiline_string, :simple_string)

  rule :multiline_string, "`", /.*?(?=`)/m, "`" do
    def evaluate
      # Make sure we keep track of whitespace
      str = matches[1].to_s + matches[2].to_s + matches[3].to_s
      # Now we deal with formatting:
      str = str.gsub(/%\{(.*?(?=}))\}/) { parser.parse($1).evaluate.to_s}
      return str
    end
  end

  rule :simple_string, /"|'/, /[^'"]*/, /"|'/ do
    def evaluate
      # Make sure we keep track of whitespace
      return matches[1].to_s + matches[2].to_s + matches[3].to_s
    end
  end

  # Negative numbers are parsed first
  rule :number, "-", any(:number, :variable) do
    def evaluate
      return -(matches[2].evaluate)
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
    # puts parse_tree.inspect
    ruby_data_structure = parse_tree.evaluate
    puts ruby_data_structure.inspect
  else
    puts "ParsingError: " + mini_parser.parser_failure_info
  end
end
