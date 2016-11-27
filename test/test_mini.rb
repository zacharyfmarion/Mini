require "minitest/autorun"
require_relative "../mini"

# Read a file (duh)
def read_file(filepath)
  file = ""
  # Let's actually try to parse a json file
  File.open(filepath).each do |line|
    file += line
  end
  file
end

# LOL the name of the testing framework is MiniTest and the name of the
# language I am testing is Mini. This is rough
class TestMini < Minitest::Test 
  def setup
    # Put setup here
  end
  
  # ------------------------------------------------------------------------------ #
  # ------------------------------ STORE_INIT  ----------------------------------- #
  # ------------------------------------------------------------------------------ #

  # We can initialize the parser with a given environment
  def test_init
    val = {
      'value' => 'var_value',
      'type' => String,
      'mutable' => false
    }
    assert_equal('var_value', MiniParser.new(store: { "test" => val }).parse('test').evaluate )
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------ PRIMITIVES  ----------------------------------- #
  # ------------------------------------------------------------------------------ #

  def test_numbers
    assert_equal(2, MiniParser.new.parse('2').evaluate )
    assert_equal(2.0, MiniParser.new.parse('2.').evaluate )
  end

  def test_strings
    assert_equal("string!", MiniParser.new.parse('"string!"').evaluate )
  end

  def test_bools
    assert_equal(true, MiniParser.new.parse('true').evaluate )
    assert_equal(false, MiniParser.new.parse('false').evaluate )
  end

  def test_nada
    assert_equal(MiniParser.new.parse('nada').evaluate, nil)
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------ ARITHMETIC  ----------------------------------- #
  # ------------------------------------------------------------------------------ #

  def test_arithmetic
    assert_equal(6, MiniParser.new.parse('2 + 4').evaluate )
    # Make sure parentheses work
    assert_equal(30, MiniParser.new.parse('(2 + 4) * 5').evaluate )
    assert_equal(9, MiniParser.new.parse('1.5 * 6').evaluate )
    # Test for operator precedence
    assert_equal(22, MiniParser.new.parse('2 + 4 * 5').evaluate )
    assert_equal(3, MiniParser.new.parse('(2 * 1 + 10 / 5) - 1').evaluate )
    # Test for modulus
    assert_equal(1, MiniParser.new.parse('5 % 2').evaluate )
  end

  def test_negative
    skip "Need to worry about dealing with unary operators"
  end

  def test_and_or
    assert_equal(true, MiniParser.new.parse('true and true').evaluate )
    assert_equal(false, MiniParser.new.parse('true and false').evaluate )
    assert_equal(true, MiniParser.new.parse('true or false').evaluate )
    assert_equal(false, MiniParser.new.parse('false or false').evaluate )
  end

  def test_unary_ops
    assert_equal(false, MiniParser.new.parse('!true').evaluate )
    assert_equal(true, MiniParser.new.parse('!!true').evaluate )
    # TODO: Figure out how to test ~ better
    assert_equal(0, MiniParser.new.parse('~~0').evaluate )
  end

  def test_binary_ops
    assert_equal(1, MiniParser.new.parse('1 & 1').evaluate )
    assert_equal(0, MiniParser.new.parse('1 & 0').evaluate )
    assert_equal(1, MiniParser.new.parse('1 | 1').evaluate )
    assert_equal(1, MiniParser.new.parse('1 | 0').evaluate )
    assert_equal(0, MiniParser.new.parse('0 | 0').evaluate )
    assert_equal(1, MiniParser.new.parse('1 ^ 0').evaluate )
    assert_equal(0, MiniParser.new.parse('1 ^ 1').evaluate )
  end

  def test_comparisons
    assert_equal(true, MiniParser.new.parse('1 < 2').evaluate )
    assert_equal(false, MiniParser.new.parse('1 > 2').evaluate )
    assert_equal(true, MiniParser.new.parse('1 <= 2').evaluate )
    assert_equal(false, MiniParser.new.parse('1 >= 2').evaluate )
    assert_equal(false, MiniParser.new.parse('1 == 2').evaluate )

    # String equality need to be wrapped in parens for some reason...
    assert_equal(true, MiniParser.new.parse('("asdf" == "asdf")').evaluate )
  end

  # TODO: Yeah not sure how to handle this
  def test_equality
    # assert_equal(MiniParser.new.parse('1 is 2').evaluate, false)
    # assert_equal(MiniParser.new.parse('"test" is "test"').evaluate, true)
    skip "Not sure how to handle equality tbh"
  end

  # TODO: Deal with parser skipping whitespace within strings
  def test_concatenation
    assert_equal("this is interesting", MiniParser.new.parse('"this" . " is" . " interesting"').evaluate )
    assert_equal("abc", MiniParser.new.parse('"a"."b"."c"').evaluate )
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------------- VARIABLES  ----------------------------------- #
  # ------------------------------------------------------------------------------ #

  def test_variables
    assert_equal(1, MiniParser.new.parse("let i = 1 \n i").evaluate )
    assert_equal(1, MiniParser.new.parse("let i = 1 \n let j = i \n j").evaluate )
  end

  def test_mutability
    assert_equal(2, MiniParser.new.parse("let mut i = 1 \n i = 2").evaluate )
    # assert_raises(MiniParser.new.parse("let i = 1 \n i = 2").evaluate, RuntimeError)
  end

  # ------------------------------------------------------------------------------ #
  # ------------------------- COMPLEX DATA STRUCTURES  --------------------------- #
  # ------------------------------------------------------------------------------ #

  def test_arrays
    assert_equal([1,2,3,4,5], MiniParser.new.parse('[1,2,3,4,5]').evaluate )
    assert_equal(["this", "is", "a", "test"], MiniParser.new.parse('["this", "is", "a", "test"]').evaluate )
    assert_equal([false, "true", 0], MiniParser.new.parse('[false, "true", 0]').evaluate )
    assert_equal([1], MiniParser.new.parse('[] << 1').evaluate )
    assert_equal([1], MiniParser.new.parse("let test = [] \n test << 1").evaluate )
    str = '
          let arr_func = () => { [1] } 
          arr_func() << 2
          '
    assert_equal([1, 2], MiniParser.new.parse(str).evaluate )
  end

  def test_dicts
    assert_equal({1 => "testing"}, MiniParser.new.parse('{1: "testing"}').evaluate )
    assert_equal({"this" => "is", "a" => "json", "dictionary" => "thing"}, 
                 MiniParser.new.parse('{"this": "is", "a": "json", "dictionary": "thing"}').evaluate)
  end

  def test_member_access
    assert_equal("testing", MiniParser.new.parse('let test = {"test": "testing"} test -> test').evaluate )
  end

  # ------------------------------------------------------------------------------ #
  # -------------------------------- CONTROL FLOW  ------------------------------- #
  # ------------------------------------------------------------------------------ #

  def test_if
    assert_equal(1, MiniParser.new.parse("if (true) { 1 }").evaluate )
    assert_equal(1, MiniParser.new.parse("if (true) { 1 } else { 2 }").evaluate )
    assert_equal(2, MiniParser.new.parse("if (false) { 1 } else { 2 }").evaluate )
    def get_str(cond)
      " 
      if (#{cond == 0}) { println(\"if\") } 
      elseif (#{cond == 1}) { println(\"elseif1\") } 
      elseif (#{cond == 2}) { println(\"elseif2\") } 
      else { println(\"else\") }
      "
    end
    assert_output(/if/) { MiniParser.new.parse(get_str(0)).evaluate }
    assert_output(/elseif1/) { MiniParser.new.parse(get_str(1)).evaluate }
    assert_output(/elseif2/) { MiniParser.new.parse(get_str(2)).evaluate }
    assert_output(/else/) { MiniParser.new.parse(get_str(3)).evaluate }
  end

  def test_ternary
    str = '
          let func = () => { false }
          func() ? "true" : "false"
          '
    # Test function
    assert_equal("false", MiniParser.new.parse(str).evaluate )
    # Test boolean evaluate
    assert_equal(1, MiniParser.new.parse("true ? 1 : 0").evaluate )
    # Test infix 
    assert_equal(0, MiniParser.new.parse("(1 > 2) ? 1 : 0").evaluate )
  end

  def test_c_for
    str = 'let mut sum = 0 
           for (let mut i = 0 ; i < 10 ; i = i + 1) { 
             sum = sum + i 
           }
           sum'
    assert_equal(45, MiniParser.new.parse(str).evaluate )
  end

  def test_for_in
    str = 'let mut sum = 0 
           let els = [0,1,2,3,4,5,6,7,8,9] 
           for (el in els) { 
             sum = sum + el 
           }
           sum'
    assert_equal(45, MiniParser.new.parse(str).evaluate )
  end

  def test_while
    str = 'let mut sum = 0
           let mut i = 0
           while (i < 10) {
             sum = sum + i 
             i = i + 1
           }
           sum'
    assert_equal(45, MiniParser.new.parse(str).evaluate )
  end

  # ------------------------------------------------------------------------------ #
  # ---------------------------------- FUNCTIONS --------------------------------- #
  # ------------------------------------------------------------------------------ #

  def test_basic_functions
    str = 'let add = (a, b) => { a + b }
           add(12, 4) 
          '
    assert_equal(16, MiniParser.new.parse(str).evaluate )
  end

  def test_shadowing
    str = '
          let x = 1
          let double = (x) => {
            x * 2 
          }
          double(4)
          '
    assert_equal(8, MiniParser.new.parse(str).evaluate )
    str2 = 'let x = 1
            let double = (x) => {
              x * 2 
            }
            double(123)
            x
           '
    assert_equal(1, MiniParser.new.parse(str2).evaluate )
  end
  
  # Test that makes sure the stack is correctly used for local variables
  def test_recursion
    str = 'let factorial = (n) => {
             if (n > 0) {
               n * factorial(n-1) 
             } else { 1 }
           }
           factorial(5)'
    assert_equal(120, MiniParser.new.parse(str).evaluate )
  end

  def test_closure
    str = '
          let generator = () => {
            # Inner function
            (a, b) => { a + b }
          }
          let sum = generator()
          sum(1, 2)
          '
    assert_equal(3, MiniParser.new.parse(str).evaluate )
  end

  def test_statement
    str = '
          fun add(a, b) { a + b }
          add(1, 5)
          '
    assert_equal(6, MiniParser.new.parse(str).evaluate )
  end

  # ------------------------------------------------------------------------------ #
  # ---------------------------------- BUILTINS  --------------------------------- #
  # ------------------------------------------------------------------------------ #

  def test_println
    assert_output(/10/) { MiniParser.new.parse("println(10)").evaluate }
    assert_output(/Hello/) { MiniParser.new.parse('println("Hello")').evaluate }
  end

  def test_len
    assert_equal(4, MiniParser.new.parse('len("test")').evaluate )
    assert_equal(4, MiniParser.new.parse('len([1,2,3,4])').evaluate )
    assert_equal(2, MiniParser.new.parse('len({"one": 1, "two": 2})').evaluate )
  end

  def test_to_str
    assert_equal("1", MiniParser.new.parse("to_str(1)").evaluate )
    assert_equal("[1, 2, 3]", MiniParser.new.parse("to_str([1,2,3])").evaluate )
  end

  def test_conversions
    assert_equal(1, MiniParser.new.parse("to_int(1)").evaluate )
    assert_equal(10, MiniParser.new.parse('to_int("10")').evaluate )
    assert_equal(1.0, MiniParser.new.parse("to_float(1.0)").evaluate )
    assert_equal(10.0, MiniParser.new.parse('to_float("10.0")').evaluate )
  end

  # ------------------------------------------------------------------------------ #
  # ----------------------------- IMPORT / EXPORT  ------------------------------- #
  # ------------------------------------------------------------------------------ #

  def test_import
    # Importing a simple variable
    # exports_simple.mini: "export test = 10"
    str = '
          import "./test/test_files/export_simple.mini" 
          test
          '
    assert_equal(10, MiniParser.new.parse(str).evaluate )
    str2 = '
           import "./test/test_files/export_functions.mini" 
           println(add(10, 10))
           println(sub(10, 10))
           '
    # because we have multiple assertions we use I/O to check equality
    assert_output(/20\n0\n/) { MiniParser.new.parse(str2).evaluate }
    str3 = '
           import "./test/test_files/export_functions.mini" as mod
           println(mod::add(10, 10))
           println(mod::sub(10, 10))
          '
    assert_output(/20\n0\n/) { MiniParser.new.parse(str3).evaluate }
    str4 = '
           import "./test/test_files/export_functions"
           println(add(10, 10))
           println(sub(10, 10))
          '
    assert_output(/20\n0\n/) { MiniParser.new.parse(str4).evaluate }
    str5 = '
           import { add, sub } from "./test/test_files/export_functions"
           println(add(10, 10))
           println(sub(10, 10))
          '
    assert_output(/20\n0\n/) { MiniParser.new.parse(str5).evaluate }
    str6 = '
           import { add, sub } from "./test/test_files/export_functions" as mod
           println(mod::add(10, 10))
           println(mod::sub(10, 10))
          '
    assert_output(/20\n0\n/) { MiniParser.new.parse(str5).evaluate }
  end

  # ------------------------------------------------------------------------------ #
  # ---------------------------- CLASSES / OBJECTS ------------------------------- #
  # ------------------------------------------------------------------------------ #

  def test_classes
    str = '
          class Test {
            fun new() { }
            fun sayHello() {
              prinln("Hello") 
            }
          } 
          let test = Test.new()
          '
    # assert_output(/Hello/) { MiniParser.new.parse(str).evaluate }
    skip "Skipping classes for now"
  end

  def test_decorators
    str = '
          decorator add_one(f) {
            () => { f() + 1}
          }

          @add_one
          fun test() { 1 }

          test()
          '
    assert_equal(2, MiniParser.new.parse(str).evaluate )
  end

end
