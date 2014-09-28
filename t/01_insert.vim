let s:assert= themis#helper('assert')

"
" For sqlite
"
let s:suite= themis#suite('driver sqlite')

function! s:suite.column_value()
    let builder= sql_maker#new({'driver': 'sqlite'})

    let [sql, binds]= builder.insert('foo', {
    \   'bar': 'baz',
    \   'created_on': sql_maker#raw("datetime('now')"),
    \   'john': 'man',
    \   'updated_on': ['datetime(?)', 'now'],
    \})

    call s:assert.equals(sql, join(
    \   [
    \       'INSERT INTO "foo"',
    \       '("bar", "created_on", "john", "updated_on")',
    \       "VALUES (?, datetime('now'), ?, datetime(?))",
    \   ],
    \   "\n"
    \))
    call s:assert.equals(binds, ['baz', 'man', 'now'])
endfunction

function! s:suite.insert_ignore_column_value()
    let builder= sql_maker#new({'driver': 'sqlite'})

    let [sql, binds]= builder.insert('foo',
    \   {
    \       'bar': 'baz',
    \       'created_on': sql_maker#raw("datetime('now')"),
    \       'john': 'man',
    \       'updated_on': ['datetime(?)', 'now'],
    \   },
    \   {'prefix': 'INSERT IGNORE'})

    call s:assert.equals(sql, join(
    \   [
    \       'INSERT IGNORE "foo"',
    \       '("bar", "created_on", "john", "updated_on")',
    \       "VALUES (?, datetime('now'), ?, datetime(?))",
    \   ],
    \   "\n"
    \))
    call s:assert.equals(binds, ['baz', 'man', 'now'])
endfunction

"
" For MySql
"
let s:suite= themis#suite('driver mysql')

function! s:suite.column_value()
    let builder= sql_maker#new({'driver': 'mysql'})

    let [sql, binds]= builder.insert('foo', {
    \   'bar': 'baz',
    \   'created_on': sql_maker#raw('NOW()'),
    \   'john': 'man',
    \   'updated_on': ['FROM_UNIXTIME(?)', 1302536204],
    \})

    call s:assert.equals(sql, join(
    \   [
    \       'INSERT INTO `foo`',
    \       '(`bar`, `created_on`, `john`, `updated_on`)',
    \       "VALUES (?, NOW(), ?, FROM_UNIXTIME(?))",
    \   ],
    \   "\n"
    \))
    call s:assert.equals(binds, ['baz', 'man', 1302536204])
endfunction

function! s:suite.insert_ignore_column_value()
    let builder= sql_maker#new({'driver': 'mysql'})

    let [sql, binds]= builder.insert('foo',
    \   {
    \       'bar': 'baz',
    \       'created_on': sql_maker#raw('NOW()'),
    \       'john': 'man',
    \       'updated_on': ['FROM_UNIXTIME(?)', 1302536204],
    \   },
    \   {'prefix': 'INSERT IGNORE'})

    call s:assert.equals(sql, join(
    \   [
    \       'INSERT IGNORE `foo`',
    \       '(`bar`, `created_on`, `john`, `updated_on`)',
    \       "VALUES (?, NOW(), ?, FROM_UNIXTIME(?))",
    \   ],
    \   "\n"
    \))
    call s:assert.equals(binds, ['baz', 'man', 1302536204])
endfunction
