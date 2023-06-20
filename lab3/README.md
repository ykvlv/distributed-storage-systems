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

Напишем bash скрипт для выполнения резервного копирования

```bash
#!/bin/bash

# Путь к директории, где будет создана полная копия базы данных
BACKUP_DIR="$HOME/cp"

# Создание уникальной директории для каждого резервного копирования
TIMESTAMP=$(date +%Y%m%d%H%M%S)
CURRENT_BACKUP_DIR="$BACKUP_DIR/backup_$TIMESTAMP"
mkdir -p "$CURRENT_BACKUP_DIR" 

# Создание и копирование полной копии базы данных
pg_basebackup -p 9108 -D "$CURRENT_BACKUP_DIR" -X stream -Ft -z -P
scp -r "$CURRENT_BACKUP_DIR" postgres6@pg162:~/cp/backup_"$TIMESTAMP"

# Удаление устаревших копий
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} \;
ssh postgres6@pg162 "find /var/db/postgres6/cp -type d -mtime +30 -exec rm -rf {} \;"
```

Добавим автозапуск через cron. Два раза в сутки – 6:00 и 18:00

```bash
[postgres1@pg139 ~]$ crontab -e
0 6,18 * * * $HOME/cp.sh
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

Воссоздадим файловую структуру кластера

```bash
mkdir -p ~/u07/dtt88
chmod 700 ~/u07/dtt88
cd ~/u07/dtt88
tar xvf ~/cp/backup_20230612184930/base.tar.gz
```

Воссоздадим файлы табличного пространства

```bash
mkdir -p ~/u05/dcj22
cd ~/u05/dcj22
tar xvf ~/cp/backup_20230612184930/16384.tar.gz
```

Отчищаем директорию для wal-файлов и Указываем команду для загрузки wal-файлов

```
короче на допсе сдам..
была пробема – файлов .history не было рядом с WAL
я либо неправильно что то кеширую, либо да
нужно включить archive_mode = on и настроить archive_command
```

```
rm -rf ~/u07/dtt88/pg_wal/*
ln -s /var/db/postgres6/u02/dcj13 ~/u07/dtt88/pg_tblspc/16384

```

Проверим работоспособность кластера

```postgresql
[postgres6@pg162 ~]$ psql -h pg162 -U postgres1 -d whitebunny -p 9108
whitebunny=> SELECT * FROM my_table;
 id |   name   |      info       
----+----------+-----------------
  1 | Grisha   | likes RSHD
  2 | Nikolaev | dislikes Grisha
(2 строки)
```

### Повреждение файлов БД

### Логическое повреждение данных

Создаем изменения в базе данных

```postgresql
[postgres1@pg139 ~]$ psql -h pg139 -U postgres1 -d whitebunny -p 9108
whitebunny=# INSERT INTO my_table (id, name, info) VALUES (3, 'Cat', 'sleep');
whitebunny=# INSERT INTO my_table (id, name, info) VALUES (4, 'Dog', 'bark');
whitebunny=# SELECT * FROM my_table;
 id |   name   |      info       
----+----------+-----------------
  1 | Grisha   | likes RSHD
  2 | Nikolaev | dislikes Grisha
  3 | Cat      | sleep
  4 | Dog      | bark
(4 строки)
```
