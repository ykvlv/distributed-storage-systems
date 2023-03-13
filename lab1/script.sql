do $$
    declare
        _schema       text     := ${LAB1_SCHEMA};
        _table        text     := ${LAB1_TABLE};

        _record       record;
        _prev         smallint := 0;
        _prev_con     bool     := false;

        _con_type_str text;
        _con_tmp      text;
        _con_record   record;
        _con_flag     bool;
    begin
        raise info 'Схема: %', _schema;
        raise info 'Таблица: % ', _table;
        raise info ' ';
        raise info 'No. Имя столбца                  Аттрибуты';
        RAISE INFO '--- ---------------------------- -----------------------------------------------';

        for _record in (select attnum,    --Порядковый номер столбца
                               attname,   --Имя столбца
                               typname,   --Имя типа данных
                               atttypmod, --Доп число для определения типа данных. Напр. ограничение длины для varchar.

                               conname,   --Имя ограничения
                               contype,   --Тип ограничения
                               confrelid, --Если это внешний ключ, таблица, на которую он ссылается; иначе 0
                               confkey,   --Для внешнего ключа определяет список столбцов, на которые он ссылается
                               relname    --Имя (в данном примере имя Таблицы)
                        from pg_attribute
                            join pg_type on pg_type.oid = atttypid
                            left join pg_constraint on (pg_attribute.attnum = any (pg_constraint.conkey)
                                                            and attrelid = conrelid)
                            left join pg_class on pg_class.oid = confrelid
                        where attrelid = (select oid
                                          from pg_class
                                          where relnamespace = (select oid
                                                                from pg_namespace
                                                                where pg_namespace.nspname = _schema)
                                            and relname = _table)
                          and attnum > 0
                        order by attnum)
            loop
                if _prev <> _record.attnum then
                    if _prev_con then
                        raise info ' '; _prev_con = false;
                    end if;
                    raise info '%', format('%-3s %-28s Type    : %s%s',
                        _record.attnum,
                        _record.attname,
                        _record.typname,
                        case when _record.atttypmod > -1 then format('(%s)', _record.atttypmod) end);
                    _prev = _record.attnum;
                end if;

                if _record.conname is not null then
                    if _record.contype = 'p' then
                        _con_type_str = 'Primary Key';
                    elsif _record.contype = 'f' then
                        for _con_record in (select attnum, attname
                                  from pg_attribute
                                           join pg_class on
                                          pg_attribute.attrelid = pg_class.oid
                                  where attrelid = _record.confrelid)
                            loop
                                _con_flag = false;
                                if _con_record.attnum = ANY (_record.confkey) then
                                    if _con_flag = false then
                                        _con_tmp = _con_record.attname;
                                        _con_flag = true;
                                    else
                                        _con_tmp = _con_tmp || ',' || _con_record.attname;
                                    end if;
                                end if;
                            end loop;
                        _con_type_str = format('References %s(%s)', _record.relname, _con_tmp);
                    end if;
                    raise info '%', format('%-32s %s %s %s', E'\u00A0', 'Constr  :', _record.conname, _con_type_str);
                    _prev_con = true;
                end if;
            end loop;
    end
$$ language plpgsql;
