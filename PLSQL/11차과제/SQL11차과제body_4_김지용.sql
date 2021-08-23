create or replace package body ddl_get_pkg
IS
--------------------tab 프로시저-----------------------
    procedure tab_proc
    (
        f_user varchar2,  -- user 로 부터 입력받을 유저이름
        f_tabname varchar2 -- user 로 부터 입력받을 테이블이름
    )
    is   
        --TABLE 관련변수
        r_notnull varchar(10); -- not null 조건을 확인하는 변수
        r_real_leng varchar(100); -- column의 길이를 위한 변수
        r_column varchar2(1000); -- 한줄로 list하여 출력하기 위한 변수
        i binary_integer := 0; -- count를 위한 변수 
        
        not_result exception; -- 사용자 정의 exception
      
    begin
        select max(COLUMN_NAME) -- 값이 있는지 확인
        into r_column
        from sys.dba_tab_columns a   
        where a.owner = f_user
        and a.table_name = f_tabname;
      
        if r_column is null then -- 결과값이 아무것도 없으면
            raise not_result; --정의 exception 호출
        end if;
        r_column := '';
        
        --CREATE TABLE 입력
        i := 1;
        insert into ddl_scripts (owner, object_type, object_name,line,text)
            values (f_user, 'TABLE',f_tabname, i,'CREATE TABLE'||' '||f_user||'.'||f_tabname);
        --괄호 입력
        i := i+1;
        insert into ddl_scripts (owner, object_type, object_name,line,text)
            values (f_user, 'TABLE',f_tabname, i,'(');    
            
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
                
                if tab_list.nullable = 'N' then
                    r_notnull := 'not null';
                else
                    r_notnull := '';
                end if; 
                --null인지 아닌지 체크
                
                if tab_list.data_precision is not null then
                    r_real_leng := tab_list.data_precision ;
                else
                    r_real_leng := tab_list.data_length;
                end if; 
                --datatype에 따라 다른값을 출력해야함으로 precision이 null인지 확인
                  
                if (tab_list.data_scale is not null) and (tab_list.data_scale > 0) then
                    r_real_leng := r_real_leng||','||tab_list.data_scale;
                else
                    r_real_leng := r_real_leng||'';
                end if; 
                --v_temp_scale이 null인지 확인하면서, 0보다 큰지 체크
                
                r_real_leng := '('||r_real_leng||')';
                --형식에 맞게 수정      
                if tab_list.data_type = 'DATE' then
                    r_real_leng :='';
                end if;
                 
                 --date 타입일 경우 출력안함
                r_column := tab_list.column_name
                    ||' '
                    ||tab_list.data_type
                    ||' '
                    ||r_real_leng
                    ||' '
                    ||r_notnull||',';
                
                insert into ddl_scripts (owner, object_type, object_name,line,text)
                values (f_user, 'TABLE',f_tabname, i,'    '||r_column);
                
        end loop;
        -- 마지막 컬럼 뒤에 ,를 짜르기 위한 update문
        update ddl_scripts set text = '    '||rtrim(r_column,',') where line= i ;

        --괄호입력
        i := i+1;
        insert into ddl_scripts (owner, object_type, object_name,line,text)
            values (f_user, 'TABLE',f_tabname, i,')');
        --문장입력
        i := i+1;
        insert into ddl_scripts (owner, object_type, object_name,line,text)
            values (f_user, 'TABLE',f_tabname, i,'TABLESPACE USERS;');
            
        --커밋
        commit;

        exception
        when no_data_found then --데이터가 없을때
            RAISE_APPLICATION_ERROR(-20996,'not_data_found');
        when value_error then --값을 잘못입력 했을때
            RAISE_APPLICATION_ERROR(-20997,'value_error');
        when not_result then 
            RAISE_APPLICATION_ERROR(-20999,'데이터가 검색되지 않습니다. 유저명과 테이블 이름을 확인해 주십시오.');
        when others then --그외
            RAISE_APPLICATION_ERROR(-20998,'others error');
    end tab_proc; 
--------------------source 프로시저--------------------
    procedure source_proc
    (
        f_user varchar2,  -- user 로 부터 입력받을 유저이름
        f_objname varchar2 -- user 로 부터 입력받을 오브젝트이름
    )
    is
        --source 관련변수
        v_create varchar2(100); -- CREATE OR REPLACE을 위한 변수
        v_type varchar(100);
        i binary_integer := 0; -- count를 위한 변수 
        
        not_result exception; -- 사용자 정의 exception
    
    begin 
        
        select max(name) -- 값이 있는지 확인
        into v_create
        from sys.dba_source    
        where owner = f_user
        and name = f_objname;
      
        if v_create is null then -- 결과값이 아무것도 없으면
            raise not_result; --정의 exception 호출
        end if;
        v_create := '';
        
        --source 테이블 검색
        for objlist in
        (
            select *
            from sys.dba_source    
            where owner = f_user
            and name = f_objname  
        )loop
            
            i:= i+1;
            if i=1 or v_type != objlist.type then--첫번째 줄이거나 오브젝트 타입이 달라지면 
            
                i:=1;
                v_create := 'CREATE OR REPLACE'; -- 이문구를 변수에 넣는다
                v_type := objlist.type;
            else
                v_create := '';
               
            end if;

            insert into ddl_scripts (owner, object_type, object_name,line,text)
                        values (f_user, objlist.type, f_objname, i,v_create||' '||objlist.text);
        
        end loop;
        

        commit;
        
        exception
        when not_result then 
            RAISE_APPLICATION_ERROR(-20999,'데이터가 검색되지 않습니다. 유저명과 오브젝트 이름을 확인해 주십시오.');
        when no_data_found then --데이터가 없을때
            RAISE_APPLICATION_ERROR(-20996,'not_data_found');
        when value_error then --값을 잘못입력 했을때
            RAISE_APPLICATION_ERROR(-20997,'value_error');
        when others then --그외
            RAISE_APPLICATION_ERROR(-20998,'others error');
    end source_proc;
    
--------------------ind 프로시저-----------------------
    procedure ind_proc
    (
        f_user varchar2,  -- user 로 부터 입력받을 유저이름
        f_tabname varchar2 -- user 로 부터 입력받을 인덱스이름
    )
    is
        --INDEX 관련변수
        
        i binary_integer := 0; -- count를 위한 변수 
        
        v_index varchar2(1000):=''; -- 한줄로 list하여 출력하기 위한 변수
        v_unique varchar(40); -- unique 여부를 위한 변수
        
        not_result exception; -- 사용자 정의 exception 
        
    begin
        select max(INDEX_NAME) -- 값이 있는지 확인
        into v_index
        from sys.dba_ind_columns    
        where table_owner = f_user
        and table_name=f_tabname;
        
        if v_index is null then -- 결과값이 아무것도 없으면
            raise not_result; --정의 exception 호출
        end if;
        v_index := '';

        --이후로는 INDEX 문장 입력
        for ind_list in 
            (
                select distinct INDEX_NAME
                from sys.dba_ind_columns    
                where table_owner = f_user
                and table_name=f_tabname
            )loop
                select max(decode(CONSTRAINT_TYPE,'P','UNIQUE',null))
                into v_unique
                from all_constraints
                where table_name = f_tabname
                and owner = f_user
                and INDEX_NAME = ind_list.INDEX_NAME;
                
                i:=0;
                
                --CREATE INDEX 입력
                i := i+1;
                insert into ddl_scripts (owner, object_type, object_name,line,text)
                    values (f_user, 'INDEX',ind_list.INDEX_NAME, i,'CREATE '||v_unique||' INDEX'||' '||f_user||'.'||ind_list.INDEX_NAME);
                
                --인덱스 owner 입력
                i := i+1;
                insert into ddl_scripts (owner, object_type, object_name,line,text)
                    values (f_user, 'INDEX',ind_list.INDEX_NAME, i,'ON'||' '||f_user||'.'||f_tabname);
                    
                    for col_list in  --반복문
                    (
                        select COLUMN_NAME
                        from sys.dba_ind_columns   
                        WHERE TABLE_OWNER = f_user
                        and table_name = f_tabname
                        and index_name = ind_list.INDEX_NAME
                        order by COLUMN_POSITION
                    )
                    loop
                        --list로 차곡차곡저장
                        v_index := v_index||
                            col_list.COLUMN_NAME
                            ||','
                            
                            ;
                            
                    end loop;
                    v_index := rtrim(v_index,',');
                    DBMS_OUTPUT.PUT_LINE( v_index );
                    
                --괄호 입력
                i := i+1;
                insert into ddl_scripts (owner, object_type, object_name,line,text)
                    values (f_user, 'INDEX',ind_list.INDEX_NAME, i,'('||v_index||')');
                v_index := '';
                --문장입력
                i := i+1;
                insert into ddl_scripts (owner, object_type, object_name,line,text)
                    values (f_user, 'INDEX',ind_list.INDEX_NAME, i,'TABLESPACE USERS;');
                    
        end loop;
        
         --2차 커밋
        commit;
         exception
        when no_data_found then --데이터가 없을때
            RAISE_APPLICATION_ERROR(-20996,'not_data_found');
        when value_error then --값을 잘못입력 했을때
            RAISE_APPLICATION_ERROR(-20997,'value_error');
        when not_result then 
            RAISE_APPLICATION_ERROR(-20999,'데이터가 검색되지 않습니다. 유저명과 인덱스 이름을 확인해 주십시오.');   
        --when others then --그외
         --   RAISE_APPLICATION_ERROR(-20998,'others error');
        
    end ind_proc; 
    
    --------------------view 프로시저-----------------------
    procedure view_proc
    (
        f_user varchar2,  -- user 로 부터 입력받을 유저이름
        f_viewname varchar2 -- user 로 부터 입력받을 인덱스이름
        
    )
    is
        i binary_integer := 0; -- count를 위한 변수 
        j binary_integer := 0; -- 문자열이 끝나는지  체크하기 위한 변수 
        v_text varchar2(100); -- 한줄로 list받기위한 변수
        
        not_result exception; -- 사용자 정의 exception

    begin
        select max(view_name) -- 값이 있는지 확인
        into v_text
        from sys.dba_views    
        where owner = f_user
        and view_name=f_viewname;
            
        if v_text is null then -- 결과값이 아무것도 없으면
            raise not_result; --정의 exception 호출
        end if;
        v_text := '';

        for view_list in 
            (
                select *          
                from sys.dba_views    
                where owner = f_user
                and view_name=f_viewname
            )loop           
                i:=0;         
                --CREATE VIEW 입력
                i := i+1;
                insert into ddl_scripts (owner, object_type, object_name,line,text)
                    values (f_user, 'VIEW',view_list.VIEW_NAME, i,'CREATE OR REPLACE VIEW '||view_list.VIEW_NAME||' AS');
                    --첫문장 입력
                v_text := substr(view_list.text_vc, 1,INSTR(view_list.text_vc,CHR(10), 1 , 1));  
                    
                i := i+1;
                insert into ddl_scripts (owner, object_type, object_name,line,text)
                    values (f_user, 'VIEW',view_list.VIEW_NAME, i,v_text);
                
                loop
                    i := i+1;
                    v_text := substr(view_list.text_vc,
                    INSTR(view_list.text_vc,CHR(10), 1 , i-2),
                    INSTR(view_list.text_vc,CHR(10), 1 , i-1)-INSTR(view_list.text_vc,CHR(10), 1 , i-2));
                    
                    insert into ddl_scripts (owner, object_type, object_name,line,text)
                    values (f_user, 'VIEW',view_list.VIEW_NAME, i,v_text);
                    
                    
                    j := INSTR(view_list.text_vc,CHR(10), 1 , i-1);
                    
                    exit when j = 0;
                end loop;
                -- ; 입력
                
            update ddl_scripts 
            set text = text||';' 
            where line = i;     
                    
        end loop;      
        
         --커밋
        commit; 
        exception
        when no_data_found then --데이터가 없을때
            RAISE_APPLICATION_ERROR(-20996,'not_data_found');
        when value_error then --값을 잘못입력 했을때
            RAISE_APPLICATION_ERROR(-20997,'value_error');
        when not_result then 
            RAISE_APPLICATION_ERROR(-20999,'데이터가 검색되지 않습니다. 유저명과 뷰 이름을 확인해 주십시오.');   
        when others then --그외
            RAISE_APPLICATION_ERROR(-20998,'others error');
    end view_proc;
--------------------seq 프로시저-----------------------
procedure seq_proc
    (
        f_user varchar2,  -- user 로 부터 입력받을 유저이름
        f_seqname varchar2 -- user 로 부터 입력받을 시퀸스이름
    )
        is
        i binary_integer := 0; -- count를 위한 변수 
        v_text varchar2(100); -- 한줄로 list받기위한 변수
        
        not_result exception; -- 사용자 정의 exception
      
    begin
        for seq_list in 
        (
                select *          
                from sys.dba_sequences    
                where sequence_owner = f_user
                and sequence_name=f_seqname
         )loop 
            i:=i+1;
            insert into ddl_scripts (owner, object_type, object_name,line,text)
                values (f_user, 'SEQUENCE',f_seqname, i,'CREATE SEQUENCE '||seq_list.SEQUENCE_NAME);
            i:=i+1;
            insert into ddl_scripts (owner, object_type, object_name,line,text)
                values (f_user, 'SEQUENCE',f_seqname, i,'INCREMENT BY '||seq_list.INCREMENT_BY);
            i:=i+1;
            insert into ddl_scripts (owner, object_type, object_name,line,text)
                values (f_user, 'SEQUENCE',f_seqname, i,'MINVALUE '||seq_list.MIN_VALUE);
            i:=i+1;
            insert into ddl_scripts (owner, object_type, object_name,line,text)
                values (f_user, 'SEQUENCE',f_seqname, i,'MAXVALUE '||seq_list.MAX_VALUE);
                
            if seq_list.cycle_flag = 'N' then
                v_text := 'NOCYCLE';
            else
                v_text := 'CYCLE';
            end if;           
                
            i:=i+1;
            insert into ddl_scripts (owner, object_type, object_name,line,text)
                values (f_user, 'SEQUENCE',f_seqname, i,v_text);
                
            
            
            if seq_list.ORDER_FLAG = 'N' then
                v_text := 'NOORDER';
            else
                v_text := 'ORDER';
            end if;
            
            i:=i+1;
            insert into ddl_scripts (owner, object_type, object_name,line,text)
                values (f_user, 'SEQUENCE',f_seqname, i,v_text);
            
            if seq_list.cache_size != 0 then
            
                i := i+1;
                insert into ddl_scripts (owner, object_type, object_name,line,text)
                    values (f_user, 'SEQUENCE',f_seqname, i,'CACHE '||seq_list.cache_size); 
            end if;
            
            i:=i+1;
            insert into ddl_scripts (owner, object_type, object_name,line,text)
                values (f_user, 'SEQUENCE',f_seqname, i,';');
            
        end loop;
    end seq_proc;
END ddl_get_pkg;