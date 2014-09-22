let s:save_cpo= &cpo
set cpo&vim

let s:select= {}

function! s:select.distinct(val)
    let self.__distinct= a:val
endfunction

function! s:select.for_update(val)
    let self.__for_update= a:val
endfunction

function! s:select.prefix(...)
    if a:0 == 0
        return self.__prefix
    else
        let self.__prefix= a:1
    endif
endfunction

function! s:select.quote_char()
    return self.__quote_char
endfunction

function! s:select.name_sep()
    return self.__name_sep
endfunction

function! s:select.new_line()
    return self.__new_line
endfunction

function! s:select.offset(...)
    if a:0 == 0
        return self.__offset
    else
        let self.__offset= a:1
        return self.__offset
    endif
endfunction

function! s:select.limit(...)
    if a:0 == 0
        return self.__limit
    else
        let self.__limit= a:1
        return self.__limit
    endif
endfunction

function! s:select.new_condition()
    return sql_maker#condition#new({
    \   'quote_char': self.quote_char(),
    \   'name_sep': self.name_sep(),
    \})
endfunction

function! s:select.bind()
    let bind= []

    if !empty(self.__subqueries)
        let bind+= self.__subqueries
    endif
    if !empty(self.__where)
        let bind+= self.__where.bind()
    endif
    if !empty(self.__having)
        let bind+= self.__having.bind()
    endif

    return bind
endfunction

function! s:select.add_select(term, ...)
    let col= get(a:000, 0, a:term)

    let self.__select+= [a:term]
    let self.__select_map[a:term]= col
    let self.__select_map_reverse[col]= a:term

    return self
endfunction

function! s:select.add_from(table, alias)
    if type(a:table) == type({}) && has_key(a:table, 'as_sql') && type(a:table.as_sql) == type(function('tr'))
        let self.__subqueries+= a:table.bind()
        let self.__from+= ['(' . a:table.as_sql() . ')', a:alias]
    else
        let self.__from+= [a:table, a:alias]
    endif

    return self
endfunction

function! s:select.add_join(table_ref, joins)
    let [table, alias]= (type(a:table_ref) == type([])) ? a:table_ref : [a:table_ref, '']

    if type(table) == type({}) && has_key(table, 'as_sql') && type(table.as_sql) == type(function('tr'))
        let self.__subqueries+= table.bind()
        let table= '(' . table.as_sql() . ')'
    endif

    let self.__joins+= [{
    \   'table': [table, alias],
    \   'joins': a:joins,
    \}]

    return self
endfunction

function! s:select.add_index_hint(table, hint)
    if type(a:hint) == type({})
        " { type => '...', list => ['foo'] }
        let type= a:hint.type
        let list= (type(a:hint.list) == type([])) ? a:hint.list : [a:hint.list]
    else
        " ['foo, 'bar'] or just 'foo'
        let type= 'USE'
        let list= (type(a:hint) == type([])) ? a:hint : [a:hint]
    endif

    let self.__index_hint[a:table]= {
    \   'type': type,
    \   'list': list,
    \}

    return self
endfunction

function! s:select._quote(label)
    if type(a:label) == type('')
        return a:label
    endif

    return sql_maker#util#quote_identifier(a:label, self.quote_char(), self.name_sep())
endfunction

function! s:select.as_sql()
    let sql= ''
    let new_line= self.new_line()
    
    if !empty(self.__select)
        let sql.= self.prefix()
        if self.distinct()
            let sql.= 'DISTINCT '
        endif
        for it in self.__select
            if !has_key(self.__select_map, it)
                let sql.= self._quote(it)
            elseif has_key(self.__select_map, it) && it =~# '\%(^\|\.\)alias\>'
                let sql.= self._quote(it)
            else
                let sql.= self._quote(it) . ' AS ' . self._quote(self.__select_map[it])
            endif
        endfor
        let sql.= new_line
    endif

    let sql.= 'FROM '

    "" Add any explicit JOIN statements before the non-joined tables.
    if !empty(self.__joins)
        let initial_table_written= 0
        for j in self.__joins
            let [table, join]= [j.table, j.joins]

            let table= self._add_index_hint(table) " index hint handling
            if !initial_table_written
                let sql.= table
            endif
            if join.type
                let sql.= ' ' . tolower(join.type)
            endif
            let sql.= ' JOIN ' . self._quote(join.table)
            if join.alias
                let sql.= ' ' . self._quote(join.alias)
            endif

            if has_key(join, 'condition')
                if type(join.condition) == type([])
                    let sql.= ' USING (' . join(map(copy(join.condition), 'self._quote(v:val)'), ', ') . ')'
                elseif type(join.condition) == type({})
                    let conds= []
                    for key in keys(join.condition)
                        let conds+= [self._quote(key) . ' = ' . self._quote(join.condition[key])]
                    endfor
                    let sql.= ' ON ' . join(conds, ' AND ')
                else
                    let sql.= ' ON ' . join.condition
                endif
            endif

            let initial_table_written= 1
        endfor

        if !empty(self.from)
            let sql.= ', '
        endif
    endif

    if !empty(self.from)
        let sql.= join(map(copy(self.from), 'self._add_index_hint(v:val[0], v:val[1])'), ', ')
    endif

    let sql.= new_line
    if self.where
        let sql.= self.as_sql_where()
    endif
    if self.group_by
        let sql.= self.as_sql_group_by()
    endif
    if self.having
        let sql.= self.as_sql_having()
    endif
    if self.order_by
        let sql.= self.as_sql_order_by()
    endif
    if self.limit
        let sql.= self.as_sql_limit()
    endif

    let sql.= self.as_sql_for_update()

    return sql
endfunction

function! s:select.as_sql_limit()
    if self.__limit
        return ''
    endif

    let n= self.__limit

    if n =~ '\D'
        throw 'Non-numerics in limit clause (' . n . ')'
    endif

    return printf('LIMIT %d%s' . self.__new_line, n, (self.__offset) ? ' OFFSET ' . self.__offset : '')
endfunction

function! s:select.add_order_by(col, type)
    let self.__order_by+= [[a:col, a:type]]
    return self
endfunction

function! s:select.as_sql_order_by()
    if empty(self.__order_by)
        return ''
    endif

    return 'ORDER BY ' . 
    my @attrs = @{$self->{order_by}};
    return '' unless @attrs;

    return 'ORDER BY '
           . join(', ', map {
                my ($col, $type) = @$_;
                if (ref $col) {
                    $$col
                } else {
                    $type ? $self->_quote($col) . " $type" : $self->_quote($col)
                }
           } @attrs)
           . $self->new_line;
endfunction

sub add_group_by {
    my ($self, $group, $order) = @_;
    push @{$self->{group_by}}, $order ? $self->_quote($group) . " $order" : $self->_quote($group);
    return $self;
}

sub as_sql_group_by {
    my ($self,) = @_;

    my $elems = $self->{group_by};

    return '' if @$elems == 0;

    return 'GROUP BY '
           . join(', ', @$elems)
           . $self->new_line;
}

sub set_where {
    my ($self, $where) = @_;
    $self->{where} = $where;
    return $self;
}

sub add_where {
    my ($self, $col, $val) = @_;

    $self->{where} ||= $self->new_condition();
    $self->{where}->add($col, $val);
    return $self;
}

sub add_where_raw {
    my ($self, $term, $bind) = @_;

    $self->{where} ||= $self->new_condition();
    $self->{where}->add_raw($term, $bind);
    return $self;
}

sub as_sql_where {
    my $self = shift;

    my $where = $self->{where}->as_sql();
    $where ? "WHERE $where" . $self->new_line : '';
}

sub as_sql_having {
    my $self = shift;
    if ($self->{having}) {
        'HAVING ' . $self->{having}->as_sql . $self->new_line;
    } else {
        ''
    }
}

sub add_having {
    my ($self, $col, $val) = @_;

    if (my $orig = $self->{select_map_reverse}->{$col}) {
        $col = $orig;
    }

    $self->{having} ||= $self->new_condition();
    $self->{having}->add($col, $val);
    return $self;
}

sub as_sql_for_update {
    my $self = shift;
    $self->{for_update} ? ' FOR UPDATE' : '';
}

sub _add_index_hint {
    my ($self, $tbl_name, $alias) = @_;
    my $quoted = $alias ? $self->_quote($tbl_name) . ' ' . $self->_quote($alias) : $self->_quote($tbl_name);
    my $hint = $self->{index_hint}->{$tbl_name};
    return $quoted unless $hint && ref($hint) eq 'HASH';
    if ($hint->{list} && @{ $hint->{list} }) {
        return $quoted . ' ' . uc($hint->{type} || 'USE') . ' INDEX (' . 
                join (',', map { $self->_quote($_) } @{ $hint->{list} }) .
                ')';
    }
    return $quoted;
}

function! sql_maker#select#new(...)
    let args= get(a:000, 0, {})

    let obj= deepcopy(s:select)

    let obj.__select=             get(args, 'select', [])
    let obj.__distinct=           get(args, 'distinct', 0)
    let obj.__select_map=         get(args, 'select_map', {})
    let obj.__select_map_reverse= get(args, 'select_map_reverse', {})
    let obj.__from=               get(args, 'from', [])
    let obj.__joins=              get(args, 'joins', [])
    let obj.__index_hint=         get(args, 'index_hint', {})
    let obj.__group_by=           get(args, 'group_by', [])
    let obj.__order_by=           get(args, 'order_by', [])
    let obj.__prefix=             get(args, 'prefix', 'SELECT ')
    let obj.__new_line=           get(args, 'new_line', "\n")

    return obj
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo
