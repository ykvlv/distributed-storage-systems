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

[script.sql](./script.sql)

## Результат

```
> psql -f script.sql
Введите название таблицы: meeting
INFO:  Таблица: meeting 
INFO:   
INFO:  No. Имя столбца                  Аттрибуты
INFO:  --- ---------------------------- -----------------------------------------------
INFO:  1   id                           Type    : int8
INFO:                                   Constr  : "meeting_pkey" Primary Key
INFO:   
INFO:  2   activity                     Type    : varchar(259)
INFO:  3   date                         Type    : int8
INFO:  4   space_id                     Type    : int8
INFO:  5   text                         Type    : varchar(1027)
INFO:  6   title                        Type    : varchar(259)
INFO:  7   creator_id                   Type    : int8
INFO:                                   Constr  : "fksdvip4776ud7j77yfl70s94fp" References vk_user(id)
```

```
> psql
# \i script.sql 
Введите название таблицы: meeting_users
INFO:  Таблица: meeting_users 
INFO:   
INFO:  No. Имя столбца                  Аттрибуты
INFO:  --- ---------------------------- -----------------------------------------------
INFO:  1   meeting_id                   Type    : int8
INFO:                                   Constr  : "meeting_users_pkey" Primary Key
INFO:                                   Constr  : "fk47jdjffi8soh6ygksssi2j6n4" References meeting(id)
INFO:   
INFO:  2   users_id                     Type    : int8
INFO:                                   Constr  : "meeting_users_pkey" Primary Key
INFO:                                   Constr  : "fk1sq7ee44gh147v12loju0ead5" References vk_user(id)
```

