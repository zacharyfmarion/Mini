" Vim syntax file
" Language: Mini
" Maintainer: Zachary Marion
" Latest Revision: 22 November 2016

if exists("b:current_syntax")
  finish
endif

" Keywords
syn keyword MiniKeyword if elseif else 
syn keyword MiniKeyword while 
syn keyword MiniKeyword for
syn keyword MiniKeyword in
syn keyword MiniKeyword nada
" syn keyword MiniKeyword let

syntax match MiniOperator '\*'
syntax match MiniOperator '/'
" syntax match MiniOperator '\+'
syntax match MiniOperator '-'
syntax match MiniOperator '&'
syntax match MiniOperator '^'
syntax match MiniOperator '|'

" Functions
syn keyword MiniFunction print println to_str to_num
" Not sure why this isn't working
syn match MiniFunction /\v(fun\s+)@>[a-zA-Z_]+/ 
syn match MiniFunction /@.*$/ 

" Types
syntax keyword MiniType fun decorator
syntax keyword MiniType let mut

" Special
syntax keyword MiniSpecial export import
syn keyword MiniSpecial __argv __name

" Comment
syn match MiniComment '#.*$'

" String
syntax region MiniString start=/\v"/ skip=/\v\\./ end=/\v"/


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
