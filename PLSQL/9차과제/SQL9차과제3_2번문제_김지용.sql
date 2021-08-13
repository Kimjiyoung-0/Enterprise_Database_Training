create or replace function tab_column_function(f_user varchar2,f_tabname varchar2)
    return varchar2
is
    type v_temp_tab is table of sys.dba_tab_columns%rowtype
    index by binary_integer;
    
    v_temp v_temp_tab;
    r_notnull varchar(10);
    r_real_leng varchar(100);
    r_column varchar2(1000); -- 한줄로 list하여 출력하기 위한 변수
    i binary_integer := 0; -- count를 위한 변수 
    
    
begin
    --max(rownum)으로 행이 몇개가 있는지 카운트한다.
 
    
    --1부터 행의 개수만큼 반복문을 돌린다.
    for tab_list in 
    (
        select *
        from sys.dba_tab_columns a   
        where a.owner = f_user
        and a.table_name = f_tabname
        order by column_id
    )loop
        i := i+1;
        
        v_temp(i).column_name := tab_list.column_name;
        v_temp(i).data_type := tab_list.data_type;
        v_temp(i).data_length := tab_list.data_length;
        v_temp(i).data_precision := tab_list.data_precision;
        v_temp(i).data_scale := tab_list.data_scale;
        v_temp(i).nullable := tab_list.nullable;
        v_temp(i).column_id := tab_list.column_id;       
        --i값으로 행을 구분한다.
        
        if v_temp(i).nullable = 'N' then
            r_notnull := 'not null';
        else
            r_notnull := '';
        end if; 
        --null인지 아닌지 체크
        
        if v_temp(i).data_precision is not null then
            r_real_leng := v_temp(i).data_precision ;
        else
            r_real_leng := v_temp(i).data_length;
        end if; 
        --datatype에 따라 다른값을 출력해야함으로 precision이 null인지 확인
          
        if (v_temp(i).data_scale is not null) and (v_temp(i).data_scale > 0) then
            r_real_leng := r_real_leng||','||v_temp(i).data_scale;
        else
            r_real_leng := r_real_leng||'';
        end if; 
        --v_temp_scale이 null인지 확인하면서, 0보다 큰지 체크
        
        r_real_leng := '('||r_real_leng||')';
        --형식에 맞게 수정      
        if v_temp(i).data_type = 'DATE' then
         r_real_leng :='';
         end if;
         
         --date 타입일 경우 출력안함
        r_column := r_column 
            ||v_temp(i).column_name
            ||' '
            ||v_temp(i).data_type
            ||' '
            ||r_real_leng
            ||' '
            ||r_notnull||',';

    end loop;
    r_column := rtrim(r_column,',');
    --맨오른쪽에서 , 하나 제거
    if trim(r_column) is null then
            r_column := '데이터가 검색되지 않습니다. 유저명, 테이블명을 확인해주세요.';
    end if;
    return r_column;  
    
    exception
    when no_data_found then --데이터가 없을때
        r_column := 'no_data_found';
        return r_column;
    when value_error then --값을 잘못입력했을때
        r_column := 'value_error';
        return r_column;
        
    when others then --그외
        r_column := 'others error';
        return r_column;
        
end;