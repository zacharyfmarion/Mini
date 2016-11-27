# Mini

Hi there! Welcome to the Mini language. A couple of weeks ago I found out about a seriously awesome and underrapreciated library called [BabelBridge](https://github.com/shanebdavis/Babel-Bridge) which lets you create an interpreted language without the pain of lexing and parsing separately (oh yeah and you're writing ruby instead of C, take that yacc!). Obviously it's not exactly blazing fast but the library is a super fun way to play around with syntaxes and try to better understand how language work (which I don't profess to know!). Anyways, let me know what you think!

## Setting up

Install the dependencies in the Gemfile with `bundle install` (run `gem install bundle` if you don't have it already). It's way more legit if you make `mini.rb` an executable so go ahead and chmod the crap out of it:

```
chmod 777 lib/mini.rb      <-- Because '777' is always a good idea, right?
```

If you want to run mini as a repl, then run: `lib/mini.rb -i` or `lib/mini.rb --interactive`. If you would rather run a file, simply pass in the filename as the first argument (e.g. `lib/mini.rb test.mini`)

## Testing

Testing is done with MiniTest, using Rake. To run the current tests (found in `test/test_mini.rb`) simply type `rake`.

## Syntax

I've been mostly just pulling things I like from a lot of languages - anonymous functions from Javscript, immutablility by default from Rust, iteration from python, etc. Below is a quick example of some of the syntax:

```mini
# File: Arrays.mini
# -------------------------------------------------------
export fun map(arr, func) {
  let ret = []
  for (el in arr) { ret << func(el) }
  ret
}

# Slice an array
export fun slice(arr, start, end) {
  let ret = []
  for (let mut i = start; i < end; i = i + 1) {
    ret << arr[i] 
  }
  ret
}
```

```mini
# File: main.mini
# -------------------------------------------------------
import { map } from "./Arrays.mini" as arrays
# Or import "./Arrays.mini"
# Or import { map } from "./Arrays.mini"

fun main() {
  let arr = [1,2,3,4,5]
  # Double each element in the array
  print(arrays::map(arr, (el) => { el * 2 }))
}

if (__name == "main") { main() }
```

I'm in the process of adding things like decorators and classes, but they're a bit more complicated. In the mean time there are some obvious and gaping wholes in the language - like ~~NO FLOATS AT ALL~~ (fixed) and for some reason 'true or false' evaluates to false, which kinda blows my mind. Anywho, if you want to mess around with it or simply talk about languages I'm happy to engage! Hope you enjoy!

## TODO

- [ ] Integrate Travis
- [x] Add Floats
- [ ] Fix Arithmetic bugs
- [ ] Implement basic libs
- [ ] Add classes
- [ ] Add decorators with args (get rid of locals Hash)
- [x] Support module import aliasing (`import "./some_module.mini" as blah`)
- [ ] Add better error handling (expand on `Parser.error() function`)
