try
    let maker= sql_maker#new({'driver': 'pg'})

    let [sql, binds]= maker.insert('jf_user', {'user_code': '1234'}, {})
    echo sql
    echo binds

    PP maker.new_select()
catch
    echo v:throwpoint
    echo v:exception
endtry
