# Лабораторная работа №1

**Вариант №311727**

| Выполнил      | Группа | Преподаватель  |
| :------------ | ------ | -------------- |
| Яковлев Г. А. | P33111 | Николаев В. В. |

## Задание

Используя сведения из системных каталогов получить информацию о любой таблице: Номер по порядку, Имя столбца, Атрибуты (в атрибуты столбца включить тип данных и внешние ключи).

```
Таблица: н_характеристики_видов_работ  

 No. Имя столбца   Атрибуты
 --- -----------   ------------------------------------------------------
   1 свр_ид        Type   : NUMBER(9)
                   Constr : "хвр_свр_fk" References н_свойства_вр(ид)
  
   2 вр_ид         Type   : NUMBER(9)
                   Constr : "хвр_вр_fk"  References н_виды_работ(ид)
   
   2 кто_создал    Type   : Date
   3 когда_создал  Type   : Date
   4 кто_изменил   Type   : Date
   5 когда_изменил Type   : Date
```

Программу оформить в виде анонимного блока.

## Выполнение

**script.sh**

```sh
#!/bin/bash

# Запрашиваем и проверяем хост
while true; do
  read -p 'Имя хоста: (localhost) ' host
  host=${host:-localhost}
  if ping -c 1 "$host" &> /dev/null
  then
    break
  fi
  echo "Хост $host недоступен" >&2
done

# Запрашиваем и проверяем БД
while true; do
  read -p 'База данных: (postgres) ' database
  database=${database:-postgres}
  if psql -h "$host" -lqt | cut -d \| -f 1 | grep -qw "$database"; then
    break
  fi
  echo "База данных $database на $host не найдена" >&2
done

# Запрашиваем и проверяем схему
while true; do
  read -p 'Схема: (public) ' scheme
  scheme=${scheme:-public}
  if psql -h "$host" -d "$database" -c "\dn" -qt | awk '{print $1}' | grep -qw "$scheme"; then
    break
  fi
  echo "Схема $scheme в базе данных $database на $host не найдена" >&2
done

# Запрашиваем и проверяем таблицу
while true; do
  read -p 'Таблица: (postgres) ' table
  table=${table:-postgres}
  if psql -h "$host" -d "$database" -c "\dt $scheme.$table" -qt | awk '{print $3}' | grep -qw "$table"; then
    break
  fi
  echo "Таблица $table в схеме $scheme в базе данных $database на $host не найдена" >&2
done

export LAB1_SCHEMA=\'$scheme\'
export LAB1_TABLE=\'$table\'
envsubst < script.sql | psql -h $host -d $database
```

**script.sql**

```postgresql
do $$
    declare
        _schema         text    :=  ${LAB1_SCHEMA};
        _table          text    :=  ${LAB1_TABLE};

        _record         record;

        _con_type_str   text;
        _con_tmp        text;
        _con_record     record;
        _con_flag       bool;
    begin
        raise info 'Схема: %', _schema;
        raise info 'Таблица: % ', _table;
        raise info ' ';
        raise info 'No. Имя столбца                  Аттрибуты';
        RAISE INFO '--- ---------------------------- ------------------------------';

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
                raise info '%', format('%-3s %-28s Type    : %s%s',
                    _record.attnum,
                    _record.attname,
                    _record.typname,
                    case when _record.atttypmod > -1 then format('(%s)', _record.atttypmod) end);

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
                    raise info ' ';
                end if;
            end loop;
    end
$$ language plpgsql;
```

## Результат

```
> ./script.sh
Имя хоста: (localhost) pg
Хост pg недоступен
Имя хоста: (localhost) localhost
База данных: (postgres) 
Схема: (public) ykvlv
Схема ykvlv в базе данных postgres на localhost не найдена
Схема: (public) 
Таблица: (postgres) meeting
INFO:  Схема: public
INFO:  Таблица: meeting 
INFO:   
INFO:  No. Имя столбца                  Аттрибуты
INFO:  --- ---------------------------- -----------------------------------------------
INFO:  1   id                           Type    : int8
INFO:                                   Constr  : meeting_pkey Primary Key
INFO:   
INFO:  2   activity                     Type    : varchar(259)
INFO:  3   date                         Type    : int8
INFO:  4   space_id                     Type    : int8
INFO:  5   text                         Type    : varchar(1027)
INFO:  6   title                        Type    : varchar(259)
INFO:  7   creator_id                   Type    : int8
INFO:                                   Constr  : fksdvip4776ud7j77yfl70s94fp References vk_user(id)
```

```
> ./script.sh
Имя хоста: (localhost) 
База данных: (postgres) 
Схема: (public) 
Таблица: (postgres) meeting_users
INFO:  Схема: public
INFO:  Таблица: meeting_users 
INFO:   
INFO:  No. Имя столбца                  Аттрибуты
INFO:  --- ---------------------------- -----------------------------------------------
INFO:  1   meeting_id                   Type    : int8
INFO:                                   Constr  : meeting_users_pkey Primary Key
INFO:                                   Constr  : fk47jdjffi8soh6ygksssi2j6n4 References meeting(id)
INFO:   
INFO:  2   users_id                     Type    : int8
INFO:                                   Constr  : meeting_users_pkey Primary Key
INFO:                                   Constr  : fk1sq7ee44gh147v12loju0ead5 References vk_user(id)
```

