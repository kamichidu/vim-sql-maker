let s:save_cpo= &cpo
set cpo&vim

function! sql_maker#util#quote_identifier(label, quote_char, name_sep)
    if a:label ==# '*'
        return a:label
    elseif empty(a:name_sep)
        return a:label
    else
        let idents= split(a:label, escape(a:name_sep, '.'))
        return join(map(idents, '(v:val ==# "*") ? v:val : a:quote_char . v:val . a:quote_char'), a:name_sep)
    endif
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo
