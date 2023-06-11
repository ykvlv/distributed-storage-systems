# Лабораторная работа №2

**Вариант №8**

| Выполнил      | Группа | Преподаватель  |
| :------------ | ------ | -------------- |
| Яковлев Г. А. | P33111 | Николаев В. В. |

## Задание

На выделенном узле создать и сконфигурировать новый кластер БД, саму БД, табличные пространства и новую роль в соответствии с заданием. Произвести наполнение базы.

**Инициализация кластера БД**

- Имя узла — pg139.
- Имя пользователя — postgres1.
- Директория кластера БД — $HOME/u07/dtt88.
- Кодировка, локаль — KOI8-R, русская
- Перечисленные параметры задать через переменные окружения.

**Конфигурация и запуск сервера БД**

- Способ подключения к БД — TCP/IP socket, номер порта 9108.
- Остальные способы подключений запретить.
- Способ аутентификации клиентов — по паролю SHA-256.
- Настроить следующие параметры сервера БД: max_connections, shared_buffers, temp_buffers, work_mem, checkpoint_timeout, effective_cache_size, fsync, commit_delay. Параметры должны быть подобраны в соответствии со сценарием OLTP: 1500 транзакций/сек. с записью размером по 16 КБ, акцент на высокую доступность данных;
- Директория WAL файлов — $HOME/u02/dcj13.
- Формат лог-файлов — log.
- Уровень сообщений лога — WARNING.
- Дополнительно логировать — контрольные точки.

**Дополнительные табличные пространства и наполнение**

- Создать новое табличное пространство для индексов: $HOME/u05/dcj22.
- На основе template0 создать новую базу — whitebunny7.
- От имени новой роли (не администратора) произвести наполнение существующих баз тестовыми наборами данных. Предоставить права по необходимости. Табличные пространства должны использоваться по назначению.
- Вывести список всех табличных пространств кластера и содержащиеся в них объекты.

## Выполнение

### Инициализация кластера БД

```bash
export PGDATA=$HOME/u07/dtt88
export PGHOST=pg139
mkdir -p $HOME/u07/dtt88 $HOME/u02/dcj13 $HOME/u05/dcj22
initdb --locale=ru_RU.KOI8-R --encoding=KOI8 --username=postgres1 --waldir=$HOME/u02/dcj13
```

Вывод

```bash
Файлы, относящиеся к этой СУБД, будут принадлежать пользователю "postgres1".
От его имени также будет запускаться процесс сервера.

Кластер баз данных будет инициализирован с локалью "ru_RU.KOI8-R".
Выбрана конфигурация текстового поиска по умолчанию "russian".

Контроль целостности страниц данных отключён.

создание каталога /var/db/postgres1/u07/dtt88... ок
создание подкаталогов... ок
выбирается реализация динамической разделяемой памяти... posix
выбирается значение max_connections по умолчанию... 100
выбирается значение shared_buffers по умолчанию... 128MB
выбирается часовой пояс по умолчанию... W-SU
создание конфигурационных файлов... ок
выполняется подготовительный скрипт... ок
выполняется заключительная инициализация... ок
сохранение данных на диске... ок

initdb: предупреждение: включение метода аутентификации "trust" для локальных подключений
Другой метод можно выбрать, отредактировав pg_hba.conf или используя ключи -A,
--auth-local или --auth-host при следующем выполнении initdb.

Готово. Теперь вы можете запустить сервер баз данных:

    pg_ctl -D /var/db/postgres1/u07/dtt88 -l файл_журнала start
```

### Конфигурация и запуск сервера БД

Зададим пароль пользователю

```postgresql
psql -h localhost -d postgres
postgres=# ALTER USER postgres1 WITH PASSWORD 'postgres1';
```

**pg_hba.conf**

Разрешаем подключение по паролю через host, остальные способы подключения запрещаем

```bash
# TYPE  DATABASE        USER            ADDRESS                 METHOD

host    all             all             all                     scram-sha-256

# "local" is for Unix domain socket connections only
local   all             all                                     reject
# IPv4 local connections:
host    all             all             127.0.0.1/32            reject
...
```

**postgresql.conf**

Меняем следующие параметры:

```bash
# Способ подключения
listen_addresses = '*'
port = 9108
password_encryption = scram-sha-256

# Logging
log_min_messages = warning
log_directory = 'pg_log'
logging_collector = on
log_checkpoints = on

# WAL директория была изменена через initdb
# initdb ... --waldir=$HOME/u02/dcj13

# Configuration
max_connections = 200         # макс количество одновременных соединений
shared_buffers = 2GB          # объем ОЗУ для кэширования данных
temp_buffers = 16MB           # объем ОЗУ для временных объектов
work_mem = 64MB               # объем ОЗУ для выполнения операций
effective_cache_size = 6GB    # оценка объема кэша ОС
checkpoint_timeout = 5min     # интервал между контрольными точками
fsync = on                    # синхронная запись на диск
commit_delay = 100            # задержка перед подтверждением транзакции
```



Перезапускаем сервер: `pg_ctl restart -D /var/db/postgres1/u07/dtt88 `

Теперь можем подключаться через команду: `psql -h pg139 -U postgres1 -d postgres -p 9108`

### Дополнительные табличные пространства и наполнение

Создадим новое табличное пространство

```postgresql
[postgres1@pg139 ~] psql -h pg139 -U postgres1 -d postgres -p 9108
postgres=# CREATE TABLESPACE indexspace LOCATION '/var/db/postgres1/u05/dcj22';
```

Создадим новую БД whitebunny на основе template0

```postgresql
[postgres1@pg139 ~] createdb -p 9108 -T template0 whitebunny
[postgres1@pg139 ~] psql -h pg139 -U postgres1 -d postgres -p 9108
postgres=# CREATE TABLE my_table (id bigserial primary key, name text, info text);
postgres=# CREATE INDEX ON my_table(name) TABLESPACE indexspace;
postgres=# CREATE ROLE postgres404 LOGIN PASSWORD 'postgres404';
postgres=# GRANT SELECT, INSERT ON my_table TO postgres404;
```

От имени новой роли наполним базу осмысленном набором текстовых данных

```postgresql
[postgres1@pg139 ~] psql -h pg139 -U postgres404 -d postgres -p 9108
postgres=> INSERT INTO my_table (id, name, info) VALUES (1, 'Grisha', 'likes RSHD');
postgres=> INSERT INTO my_table (id, name, info) VALUES (2, 'Nikolaev', 'dislikes Grisha');
postgres=> SELECT * FROM my_table;
 id |   name   |      info       
----+----------+-----------------
  1 | Grisha   | likes RSHD
  2 | Nikolaev | dislikes Grisha
(2 строки)

postgres=> UPDATE my_table SET info = 'likes Grisha' WHERE name = 'Nikolaev' and id = 1;
ОШИБКА:  нет доступа к таблице my_table
```

Выведем список всех табличных пространств кластера и содержащиеся в них объекты

```postgresql
postgres=# SELECT t.spcname, STRING_AGG(c.relname, E'\n')
           FROM pg_class c
           LEFT JOIN pg_tablespace t ON c.reltablespace = t.oid
           GROUP BY t.spcname
           order by t.spcname;
  spcname   |                  string_agg                   
------------+-----------------------------------------------
 indexspace | my_table_name_idx
 pg_global  | pg_toast_1262                                +
            | pg_toast_1262_index                          +
            | pg_toast_2964                                +
            | pg_toast_2964_index                          +
            | pg_toast_1213                                +
            | pg_toast_1213_index                          +
            | pg_toast_1260                                +
            | pg_toast_1260_index                          +
            | pg_toast_2396                                +
            | pg_toast_2396_index                          +
            | pg_toast_6000                                +
            | pg_toast_6000_index                          +
            | pg_toast_3592                                +
            | pg_toast_3592_index                          +
            | pg_toast_6100                                +
            | pg_toast_6100_index                          +
            | pg_database_datname_index                    +
            | pg_database_oid_index                        +
            | pg_db_role_setting_databaseid_rol_index      +
            | pg_tablespace_oid_index                      +
            | pg_tablespace_spcname_index                  +
...
```

## Вывод

В ходе выполнения лабораторной работы №2 была выполнена следующая работа: на выделенном узле был создан и сконфигурирован новый кластер БД с заданными параметрами. Далее была создана база данных и дополнительное табличное пространство для индексов. Была создана новая роль и назначены права доступа к таблице. В конечном итоге, база данных была успешно наполнена тестовыми данными.
