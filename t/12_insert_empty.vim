let s:assert= themis#helper('assert')

function! s:normalize(s)
    return substitute(a:s, "\n", ' ', 'g')
endfunction

" see https://github.com/tokuhirom/SQL-Maker/issues/11

"
" For sqlite
"
let s:suite= themis#suite('sqlite')

function! s:suite.sqlite()
    let maker= sql_maker#new({'driver': 'SQLite'})

    let [sql, binds]= maker.insert('foo', {})

    call s:assert.equals(s:normalize(sql), 'INSERT INTO "foo" DEFAULT VALUES')
    call s:assert.equals(binds, [])
endfunction

function! s:suite.mysql()
    let maker= sql_maker#new({'driver': 'mysql'})

    let [sql, binds]= maker.insert('foo', {})

    call s:assert.equals(s:normalize(sql), 'INSERT INTO `foo` () VALUES ()')
    call s:assert.equals(binds, [])
endfunction
