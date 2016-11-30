" Vim syn file
" Language: Mini
" Maintainer: Zachary Marion
" Latest Revision: 22 November 2016

if exists("b:current_syn")
  finish
endif

" Keywords
syn keyword MiniKeyword if elseif else 
syn keyword MiniKeyword while break continue
syn keyword MiniKeyword for
syn keyword MiniKeyword in
syn keyword MiniKeyword nada
syn keyword MiniKeyword return
syn keyword MiniKeyword true false
" syn keyword MiniKeyword let

syn match MiniOperator '\*'
syn match MiniOperator '/'
" syn match MiniOperator '\+'
syn match MiniOperator '-'
syn match MiniOperator '&'
syn match MiniOperator '^'
syn match MiniOperator '|'

" Functions
syn keyword MiniFunction print println to_str to_num
syn keyword MiniFunction eval len
" Not sure why this isn't working
syn match MiniFunction /\v(fun\s+)@>[a-zA-Z_]+/ 
syn match MiniFunction /@.*$/ 

" Types
syn keyword MiniType fun decorator
syn keyword MiniType ::
syn keyword MiniType let mut

" Special
syn keyword MiniSpecial export import from as
syn keyword MiniSpecial __argv __name

" Comment
syn match MiniComment '#.*$'
syn region MiniComment start=/\v\/\*/ skip=/\v\\./ end=/\v\*\//

" String
syn region MiniString start=/\v"|'/ skip=/\v\\./ end=/\v"|'/
" Docstrings
syn region MiniString start=/\v\=\=\// skip=/\v\\./ end=/\v\/\=\=/

" Function def
" TODO: Figure this out
" syn match MiniFunction ''

" Variable
syn match MiniVariable '[a-zA-Z_]*(?= =)'

" Number
syn match MiniNumber '\d\+'
syn match MiniNumber '[-+]\d\+'

" Matches

" Regions

" Mapping it to vim
hi def link MiniKeyword Statement
hi def link MiniNumber  Constant
hi def link MiniVariable Constant
hi def link MiniComment Comment
hi def link MiniString  String
hi def link MiniFunction Function
hi def link MiniOperator Operator
hi def link MiniType Type
hi def link MiniSpecial Special
