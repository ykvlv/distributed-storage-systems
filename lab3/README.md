# Лабораторная работа №3

**Вариант №123**

| Выполнил      | Группа | Преподаватель  |
| :------------ | ------ | -------------- |
| Яковлев Г. А. | P33111 | Николаев В. В. |

## Задание

Лабораторная работа включает настройку резервного копирования данных с основного узла на резервный, а также несколько сценариев восстановления. Узел из предыдущей лабораторной работы используется в качестве основного; новый узел используется в качестве резервного. В сценариях восстановления необходимо использовать копию данных, полученную на первом этапе данной лабораторной работы.

**Резервное копирование**

1. Настроить резервное копирование с основного узла на резервный следующим образом:
   1. Периодические обособленные (standalone) полные копии.
   2. Полное резервное копирование (pg_basebackup) по расписанию (cron) два раза в сутки. Необходимые файлы WAL должны быть в составе полной копии, отдельно их не архивировать. Срок хранения копий на основной системе - 1 неделя, на резервной - 1 месяц. По истечении срока хранения, старые архивы должны автоматически уничтожаться.
2. Подсчитать, каков будет объем резервных копий спустя месяц работы системы,
   исходя из следующих условий: Средний объем измененных данных за сутки: ~150 МБ.
3. Проанализировать результаты.

**Потеря основного узла**

Этот сценарий подразумевает полную недоступность основного узла. Необходимо восстановить работу СУБД на резервном узле, продемонстрировать успешный запуск СУБД и доступность данных.

**Повреждение файлов БД**

Этот сценарий подразумевает потерю данных (например, в результате сбоя диска или файловой системы) при сохранении доступности основного узла. Необходимо выполнить полное восстановление данных из резервной копии и перезапустить СУБД на основном узле.

1. Симулировать сбой: удалить с диска директорию любой таблицы со всем содержимым.
2. Проверить работу СУБД, доступность данных, перезапустить СУБД, проанализировать результаты.
3. Выполнить восстановление данных из резервной копии, учитывая следующее условие: Исходное расположение дополнительных табличных пространств недоступно - разместить в другой директории и скорректировать конфигурацию.
4. Запустить СУБД, проверить работу и доступность данных, проанализировать результаты.

**Логическое повреждение данных**

Этот сценарий подразумевает частичную потерю данных (в результате нежелательной или ошибочной операции) при сохранении доступности основного узла. Необходимо выполнить восстановление данных на основном узле следующим способом: Генерация файла на резервном узле с помощью pg_dump и последующее применение файла на основном узле.

1. В каждую таблицу базы добавить 2-3 новые строки, зафиксировать результат.
2. Зафиксировать время и симулировать ошибку: Удалить каждую вторую строку в любой таблице (DELETE)
3. Продемонстрировать результат.
4. Выполнить восстановление данных указанным способом.
5. Продемонстрировать и проанализировать результат.

## Выполнение

### Резервное копирование

**Настройка резервного копирования**

Создадим репликанта от имени суперпользователя

```postgresql
[postgres1@pg139 ~]$ psql -h pg139 -U postgres1 -d postgres -p 9108
postgres=# create role replica replication login password 'replica';
```

Нужно добавить запись в pg_hba.conf о разрешении подключения

```bash
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    replication     replica         all                     scram-sha-256
```

Для создания бэкапов я использовал следующую команду: `pg_basebackup -D "${FULL_PATH_NAME}" -p 9108 -U replica -X stream -T "${INDEX_SPACE}"="${NEW_INDEX_SPACE}"` Таким образом получается создать полную копию без отдельного архивирования WAL файлов. Здесь replica – созданный пользователь с правами на репликацию. Флаг -T используется для переноса в бэкап. Так же в .pgpass нужно указать `*:*:*:replica:replica` чтобы подключение происходило автоматически.

Далее я создал два скрипта – один для создания бэкапов на основном узле `backup_script.sh`, а другой – для удаления бэкапов с основного узла и резервного спустя прошедшее время (согласно варианту) `delete_script.sh`.

**Скрипт создания бэкапов**

```bash
#!/bin/bash

BACKUP_DIR="${HOME}/backups"
INDEX_SPACE="${HOME}/u05/dcj22"

DATE=$(date +%Y%m%d%H%M%S)
BACKUP_NAME="backup_${DATE}"

FULL_PATH_NAME="${BACKUP_DIR}/${BACKUP_NAME}"
NEW_INDEX_SPACE="${HOME}/index_backups/${BACKUP_NAME}"

SECOND_STORAGE="postgres6@pg162:~"

pg_basebackup -D "${FULL_PATH_NAME}" -p 9108 -U replica -X stream -T "${INDEX_SPACE}"="${NEW_INDEX_SPACE}"

/usr/local/bin/rsync -av "${FULL_PATH_NAME}" "${SECOND_STORAGE}/backups/${BACKUP_NAME}" --rsync-path="/usr/local/bin/rsync"
/usr/local/bin/rsync -av "${NEW_INDEX_SPACE}" "${SECOND_STORAGE}/index_backups/${BACKUP_NAME}" --rsync-path="/usr/local/bin/rsync"
```

**Скрипт удаления бэкапов**

```bash
#!/bin/bash

BACKUP_DIR_MAIN="${HOME}/backups"
INDEX_DIR_MAIN="${HOME}/index_backups"

PERIOD=$(( 7 * 24 * 3600 )) # 7 дней для основного узла (30 для резервного)
current_time=$(date +%s)

for backup_dir in "$BACKUP_DIR_MAIN"/*; do
    file_modified_time=$(stat -f %m "$backup_dir")
    time_diff=$((current_time - file_modified_time))

    if [ "$time_diff" -gt "$PERIOD" ]; then
        rm -rf "$backup_dir"
        echo "file(dir) deleted $backup_dir"
    fi
done

for index_dir in "$INDEX_DIR_MAIN"/*; do
    file_modified_time=$(stat -f %m "$index_dir")
    time_diff=$((current_time - file_modified_time))

    if [ "$time_diff" -gt "$PERIOD" ]; then
        rm -rf "$index_dir"
        echo "file(dir) deleted $index_dir"
    fi
done
```

Добавим автозапуск через cron. Два раза в сутки – 6:00 и 18:00

```bash
[postgres1@pg139 ~]$ crontab -e
0 6,18 * * * $HOME/backup_script.sh
0 6,18 * * * $HOME/delete_script.sh

[postgres6@pg162 ~]$ crontab -e
0 6,18 * * * $HOME/delete_script.sh
```

Генерируем ssh ключи чтобы копирование выполнялось без запроса пароля

```bash
ssh-keygen -t rsa
ssh-copy-id -i ~/.ssh/id_rsa.pub postgres6@pg162
```

**Подсчет объема резервных копий**

**N** - количество хранящихся копий, **A** - размер первой копии, **B** - размер последней копии

Объем: (N / 2) * (A + B) = (60 / 2) * (150 + 150 * 30) = 139.500 МБ = 137 ГБ

**Анализ результата**

Использование полных бэкапов может быть эффективным в случае простоты восстановления или надежности, однако использование инкрементальных бэкапов является более эффективным с точки зрения экономии пространства на диске.

### Потеря основного узла

Чтобы восстановить работу СУБД на резервном узле надо запустить кластер из ранее созданного бэкапа. Но indexspace ссылается в каталог пользователя postgres1. Чтобы это исправить изменяем символьную ссылку.

```bash
[postgres6@pg162 ~/backups/backup_20231004025528/pg_tblspc]$ readlink 16384
/var/db/postgres1/index_backups/backup_20231004022833
[postgres6@pg162 ~/backups/backup_20231004025528/pg_tblspc]$ ln -sf /var/db/postgres6/index_backups/backup_20231004022833 16384
```

Проверим работоспособность кластера

```bash
[postgres6@pg162 ~]$ pg_ctl -D backups/backup_20231004025528/backup_20231004025528 start
[postgres6@pg162 ~]$ psql -h pg162 -U postgres1 -d whitebunny -p 9108

whitebunny=# SELECT * FROM my_table;
 id |   name   |      info       
----+----------+-----------------
  1 | Grisha   | likes RSHD
  2 | Nikolaev | dislikes Grisha
(2 строки)
```

**Результаты:** данные на месте, а значит восстановить потерянный узел удалось успешно. В целом, если резервный узел имеет схожую файловую систему (в нашем случае необходимо было лишь поднастроить ссылки на табличные пространства, что можно учесть в скрипте переноса бэкапа на резервный узел), то восстановление не создаёт проблем.

### Повреждение файлов БД

Запускаем кластер. можем стереть все табличное пространство, на работу кластера оно не влияет. Ошибка возникает лишь когда запрашиваем информацию из этого пространства

```bash
[postgres1@pg139 ~]$ pg_ctl -D u07/dtt88/ start
[postgres1@pg139 ~]$ rm -rf u05/dcj22/
[postgres1@pg139 ~]$ psql -h pg139 -U postgres1 -d whitebunny -p 9108

whitebunny=# \d
                     Список отношений
 Схема  |       Имя       |        Тип         | Владелец  
--------+-----------------+--------------------+-----------
 public | my_table        | таблица            | postgres1
 public | my_table_id_seq | последовательность | postgres1
(2 строки)

whitebunny=# select * from my_table;
ОШИБКА:  не удалось открыть файл "pg_tblspc/16384/PG_14_202107181/16385/16395": Нет такого файла или каталога
```

Учитывая что по заданию «Исходное расположение дополнительных табличных пространств недоступно» можем воспользоваться вышесказанным методом и поменять ссылку в pg_tblspc на каталог с индексным пространством из бэкапа.

```bash
[postgres1@pg139 ~/u07/dtt88/pg_tblspc]$ readlink 16384
/var/db/postgres1/u05/dcj22
[postgres1@pg139 ~/u07/dtt88/pg_tblspc]$ ln -sf /var/db/postgres1/index_backups/backup_20231004040244 16384
[postgres1@pg139 ~/u07/dtt88/pg_tblspc]$ readlink 16384
/var/db/postgres1/index_backups/backup_20231004040244
```

Такая операция не требует перезапуска, кластер работает штатно

```bash
[postgres1@pg139 ~/u07/dtt88/pg_tblspc]$ psql -h pg139 -U postgres1 -d whitebunny -p 9108

whitebunny=# select * from my_table;
 id |   name   |      info       
----+----------+-----------------
  1 | Grisha   | likes RSHD
  2 | Nikolaev | dislikes Grisha
(2 строки)
```

**Результаты:** при повреждении табличного пространства ошибка об этом появится при любом взаимодействии с ним внутри БД, а после этого можно понять в чём проблема. При создании бэкапов с маппингом табличных пространств создаются копии табличных пространств, так что можно быстро восстановить табличное пространство из любого бэкапа.

### Логическое повреждение данных

Для восстановления БД после логического повреждения данных, был написан скрипт, который восстанавливает данные по dump. 

При логическом повреждении файлов БД нам надо сделать сначала dump на резервном узле. Для этого был написан скрипт (`create_dump.sh` - для резервного узла). Потом нужно получить dump с резервного узла, и развернуть его. Для этого был написан скрипт (`extract_dump.sh` - для основного узла)

create_dump.sh - для резервного узла

```bash
#!/bin/bash

dumps_dir="${HOME}/dumps/"
dump_name="db-$(date +"%m-%d-%Y-%H-%M-%S").dump"

pg_dump -h pg162 -p 9108 -d whitebunny -U postgres1 -Fc > $dumps_dir$dump_name
```

extract_dump.sh - для основного узла

```bash
#!/bin/bash

dumps_dir="dumps/"

dump_name=$1

rsync --rsync-path=/usr/local/bin/rsync --archive postgres6@pg162:~/$dumps_dir$dump_name ~/
pg_restore -h pg139 -p 9108 -d whitebunny -U postgres1 -c $dump_name -v
rm -rf $dump_name
```

**Ход работы**

1. Произведем логическое повреждение данных на основном узле

```postgresql
[postgres1@pg139 ~]$ psql -h pg139 -U postgres1 -d whitebunny -p 9108
whitebunny=# INSERT INTO my_table (id, name, info) VALUES (3, 'new666', '999');
whitebunny=# INSERT INTO my_table (id, name, info) VALUES (4, 'new666', '999');
whitebunny=# SELECT * FROM my_table;
 id |    name    |      info       
----+------------+-----------------
  1 | Grisha     | likes RSHD
  2 | Nikolaev   | dislikes Grisha
  3 | example123 | info1
  4 | new666     | 999
(4 строки)
```

2. На резервном узле делаем дамп с нужными исходными данными

```bash
[postgres6@pg162 ~]$ bash create_dump.sh 
[postgres6@pg162 ~]$ ls dumps
db-10-04-2023-14-17-01.dump
```

3. На основном узле загружаем дамп и восстанавливаемся

```bash
[postgres1@pg139 ~]$ bash extract_dump.sh db-10-04-2023-14-17-01.dump
pg_restore: подключение к базе данных для восстановления
pg_restore: удаляется INDEX my_table_name_idx
pg_restore: удаляется CONSTRAINT my_table my_table_pkey
pg_restore: удаляется DEFAULT my_table id
pg_restore: удаляется SEQUENCE my_table_id_seq
pg_restore: удаляется TABLE my_table
pg_restore: создаётся TABLE "public.my_table"
pg_restore: создаётся SEQUENCE "public.my_table_id_seq"
pg_restore: создаётся SEQUENCE OWNED BY "public.my_table_id_seq"
pg_restore: создаётся DEFAULT "public.my_table id"
pg_restore: обрабатываются данные таблицы "public.my_table"
pg_restore: выполняется SEQUENCE SET my_table_id_seq
pg_restore: создаётся CONSTRAINT "public.my_table my_table_pkey"
pg_restore: создаётся INDEX "public.my_table_name_idx"
pg_restore: создаётся ACL "public.TABLE my_table"
```

4. Проверяем объекты базы данных

```postgresql
[postgres1@pg139 ~]$ psql -h pg139 -U postgres1 -d whitebunny -p 9108
whitebunny=# SELECT * FROM my_table;
 id |   name   |      info       
----+----------+-----------------
  1 | Grisha   | likes RSHD
  2 | Nikolaev | dislikes Grisha
(2 строки)
```

Как видно, все данные были восстановлены до резервной копии.

## Вывод

В ходе лабораторной работы познакомился с методами физического и логического резервного копирования кластера или данных. Также разобрался с восстановлением работоспособности кластера(или целостности данных) и присущими проблемами.
