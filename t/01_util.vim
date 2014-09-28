let s:suite= themis#suite('')
let s:assert= themis#helper('assert')

function! s:suite.quote()
    call s:assert.equals(sql_maker#util#quote_identifier('foo.*', '`', '.'), '`foo`.*')
endfunction
