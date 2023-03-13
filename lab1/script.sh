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
  if psql -h "$host" -d "$database" -c "SELECT nspname FROM pg_catalog.pg_namespace" -qt | awk '{print $1}' | grep -qw "$scheme"; then
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
