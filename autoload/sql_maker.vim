let s:save_cpo= &cpo
set cpo&vim

let s:maker= {}

function! s:maker.quote_char()
    return self.__quote_char
endfunction

function! s:maker.name_sep()
    return self.__name_sep
endfunction

function! s:maker.new_line()
    return self.__new_line
endfunction

function! s:maker.driver()
    return self.__driver
endfunction

function! s:maker.select_class()
    return self.__select_class
endfunction

function! s:maker.new_condition()
    return sql_maker#condition#new({
    \   'quote_char': self.quote_char(),
    \   'name_sep':   self.name_sep(),
    \})
endfunction

function! s:maker.new_select(...)
    let args= get(a:000, 0, {})

    return {self.select_class()}#new(extend({
    \       'name_sep': self.name_sep(),
    \       'quote_char': self.quote_char(),
    \       'new_line': self.new_line(),
    \   }, args))
endfunction

" $builder->insert($table, \%values, \%opt);
" $builder->insert($table, \@values, \%opt);
function! s:maker.insert(table, values, opt)
    let prefix= get(a:opt, 'prefix', 'INSERT INTO')
    let quoted_table= self._quote(a:table)

    let [columns, bind_columns, quoted_columns, values]= [[], [], [], []]

    " TODO
    " while (my ($col, $val) = splice(@values, 0, 2)) {
    "     push @quoted_columns, $self->_quote($col);
    "     if (ref($val) eq 'SCALAR') {
    "         # $builder->insert(foo => { created_on => \"NOW()" });
    "         push @columns, $$val;
    "     }
    "     elsif (ref($val) eq 'REF' && ref($$val) eq 'ARRAY') {
    "         # $builder->insert( foo => \[ 'UNIX_TIMESTAMP(?)', '2011-04-12 00:34:12' ] );
    "         my ( $stmt, @sub_bind ) = @{$$val};
    "         push @columns, $stmt;
    "         push @bind_columns, @sub_bind;
    "     }
    "     else {
    "         # normal values
    "         push @columns, '?';
    "         push @bind_columns, $val;
    "     }
    " }
    for col in keys(a:values)
        let val= a:values[col]

        let quoted_columns+= [self._quote(col)]

        if type(val) == type([])
            " $builder->insert( foo => \[ 'UNIX_TIMESTAMP(?)', '2011-04-12 00:34:12' ] );
            let stmt= val[0]
            let sub_bind= val[1 : ]

            let columns+= [stmt]
            let bind_columns+= sub_bind
        else
            " normal values
            let columns+= ['?']
            let bind_columns+= [val]
        endif
    endfor

    " Insert an empty record in SQLite.
    " ref. https://github.com/tokuhirom/SQL-Maker/issues/11
    if self.driver() =~# '^sqlite' && empty(columns)
        let sql= prefix . ' ' . quoted_table . self.new_line() . 'DEFAULT VALUES'
        return [sql, []]
    endif

    let sql=  prefix . ' ' . quoted_table . self.new_line()
    let sql.= '(' . join(quoted_columns, ', ') . ')' . self.new_line()
    let sql.= 'VALUES (' . join(columns, ', ') . ')'

    return [sql, bind_columns]
endfunction

function! s:maker._quote(label)
    return sql_maker#util#quote_identifier(a:label, self.quote_char(), self.name_sep())
endfunction

function! s:maker.delete(table, where, opt)
    let w= self._make_where_clause(a:where)
    let quoted_table= self._quote(a:table)
    let sql= 'DELETE FROM ' . quoted_table

    if has_key(a:opt, 'using')
        " $bulder->delete('foo', \%where, { using => 'bar' });
        " $bulder->delete('foo', \%where, { using => ['bar', 'qux'] });
        let tables= a:opt.using
        let using= join(map(tables, 'self._quote(v:val)'), ', ')
        let sql.= ' USING ' . using
    endif

    let sql.= w[0]
    return [sql, w[1]]
endfunction

function! s:maker.update(table, args, where)
    let [columns, bind_columns]= self.make_set_clause(a:args)

    let w= self._make_where_clause(a:where)
    let bind_columns+= w[1]

    let quoted_table= self._quote(a:table)
    let sql= 'UPDATE ' . quoted_table . ' SET ' . join(columns, ', ') . w[0]

    return [sql, bind_columns]
endfunction

" make "SET" clause.
function! s:maker.make_set_clause(args)
    let [columns, bind_columns]= [[], []]

    for col in keys(a:args)
        let val= a:args[col]

        let quoted_col= self._quote(col)

        " TODO
        " if (ref $val eq 'SCALAR') {
        "     # $builder->update(foo => { created_on => \"NOW()" });
        "     push @columns, "$quoted_col = " . $$val;
        " }
        " elsif ( ref $val eq 'REF' && ref $$val eq 'ARRAY' ) {
        "     # $builder->update( foo => \[ 'VALUES(foo) + ?', 10 ] );
        "     my ( $stmt, @sub_bind ) = @{$$val};
        "     push @columns, "$quoted_col = " . $stmt;
        "     push @bind_columns, @sub_bind;
        " }
        " else {
        "     # normal values
        "     push @columns, "$quoted_col = ?";
        "     push @bind_columns, $val;
        " }
        if type(val) == type([])
            " $builder->update( foo => \[ 'VALUES(foo) + ?', 10 ] );
            let stmt= val[0]
            let sub_bind= val[1 : ]

            let columns+= [quoted_col . ' = ' . stmt]
            let bind_columns+= sub_bind
        else
            " normal values
            let columns+= [quoted_col . ' = ?']
            let bind_columns+= [val]
        endif
    endfor

    return [columns, bind_columns]
endfunction

function! s:maker.where(where)
    let cond= self._make_where_condition(a:where)
    return [cond.as_sql(), cond.bind()]
endfunction

function! s:maker._make_where_condition(where)
    if empty(a:where)
        return self.new_condition()
    endif

    let w= self.new_condition()

    for col in keys(a:where)
        let val= a:where[col]

        call w.add(col, val)
    endfor

    return w
endfunction

function! s:maker._make_where_clause(where)
    if empty(a:where)
        return ['', []]
    endif

    let w= self._make_where_condition(a:where)
    let sql= w.as_sql(1)
    return [!empty(sql) ? ' WHERE ' . sql : '', w.bind()]
endfunction

" my($stmt, @bind) = $sql−>select($table, \@fields, \%where, \%opt);
function! s:maker.select()
    let stmt= self.select_query(a:table, a:fields, a:where, a:opt)

    return [stmt.as_sql(), stmt.bind()]
endfunction

function! s:maker.select_query(table, fields, where, opt)
    let stmt= self.new_select()

    for field in a:fields
        call stmt.add_select(field)
    endfor

    if !empty(a:table)
        if type(a:table) == type('')
            " $table = 'foo'
            $stmt->add_from( $table );
            call stmt.add_from(a:table)
        else
            " $table = [ 'foo', [ bar => 'b' ] ]
            for tbl in a:table
                call stmt.add_from(tbl)
            endfor
        endif
    endif

    if has_key(a:opt, 'prefix')
        call stmt.prefix(a:opt.prefix)
    endif

    if !empty(a:where)
        call stmt.set_where(self._make_where_condition(a:where))
    endif

    if has_key(a:opt, 'joins')
        for join in a:opt.joins
            call stmt.add_join(join)
        endfor
    endif

    if has_key(a:opt, 'order_by')
        " TODO
        " if (ref $o eq 'ARRAY') {
        "     for my $order (@$o) {
        "         if (ref $order eq 'HASH') {
        "             # Skinny-ish [{foo => 'DESC'}, {bar => 'ASC'}]
        "             $stmt->add_order_by(%$order);
        "         } else {
        "             # just ['foo DESC', 'bar ASC']
        "             $stmt->add_order_by(\$order);
        "         }
        "     }
        " } elsif (ref $o eq 'HASH') {
        "     # Skinny-ish {foo => 'DESC'}
        "     $stmt->add_order_by(%$o);
        " } else {
        "     # just 'foo DESC, bar ASC'
        "     $stmt->add_order_by(\$o);
        " }
        if type(a:opt.order_by) == type([])
            for order in a:opt.order_by
                if type(order) == type({})
                    " Skinny-ish {foo => 'DESC'}
                    call stmt.add_order_by(order)
                else
                    " just 'foo DESC, bar ASC'
                    call stmt.add_order_by(order)
                endif
            endfor
        elseif type(a:opt.order_by) == type({})
            " Skinny-ish {foo => 'DESC'}
            call stmt.add_order_by(a:opt.order_by)
        else
            " just 'foo DESC, bar ASC'
            call stmt.add_order_by(a:opt.order_by)
        endif
    endif

    if has_key(a:opt, 'group_by')
        " TODO
        " if (ref $o eq 'ARRAY') {
        "     for my $group (@$o) {
        "         if (ref $group eq 'HASH') {
        "             # Skinny-ish [{foo => 'DESC'}, {bar => 'ASC'}]
        "             $stmt->add_group_by(%$group);
        "         } else {
        "             # just ['foo DESC', 'bar ASC']
        "             $stmt->add_group_by(\$group);
        "         }
        "     }
        " } elsif (ref $o eq 'HASH') {
        "     # Skinny-ish {foo => 'DESC'}
        "     $stmt->add_group_by(%$o);
        " } else {
        "     # just 'foo DESC, bar ASC'
        "     $stmt->add_group_by(\$o);
        " }
        if type(a:opt.group_by) == type([])
            for group in a:opt.group_by
                if type(group) == type({})
                    " Skinny-ish {foo => 'DESC'}
                    call stmt.add_group_by(group);
                else
                    " just 'foo DESC, bar ASC'
                    call stmt.add_group_by(group);
                endif
            endfor
        elseif type(a:opt.group_by) == type({})
            " Skinny-ish {foo => 'DESC'}
            call stmt.add_group_by(a:opt.group_by);
        else
            " just 'foo DESC, bar ASC'
            call stmt.add_group_by(a:opt.group_by);
        endif
    endif

    if has_key(a:opt, 'index_hint')
        $stmt->add_index_hint(a:table, a:opt.index_hint);
    endif

    if has_key(a:opt, 'limit')
        call stmt.limit(a:opt.limit)
    endif

    if has_key(a:opt, 'offset')
        call stmt.offset(a:opt.offset)
    endif

    if has_key(a:opt, 'having')
        for col in keys(a:opt.having)
            let val= a:opt.having[col]

            call stmt.add_having(col, val)
        endfor
    endif

    if has_key(a:opt, 'for_update')
        call stmt.for_update(1)
    endif

    return stmt;
endfunction

function! sql_maker#new(args)
    " TODO: vdbc compatible
    if !has_key(a:args, 'driver')
        throw "sql-maker: `driver' is required for creating new instance."
    endif

    let obj= deepcopy(s:maker)

    let obj.__quote_char=   get(a:args, 'quote_char', (a:args.driver ==# 'mysql') ? '`' : '"')
    let obj.__name_sep=     get(a:args, 'name_sep', '.')
    let obj.__new_line=     get(a:args, 'new_line', "\n")
    let obj.__driver=       a:args.driver
    let obj.__select_class= (a:args.driver ==# 'Oracle') ? '' : ''

    return obj
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo
