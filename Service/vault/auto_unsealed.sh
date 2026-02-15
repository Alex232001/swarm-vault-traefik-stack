#!/bin/bash

# Ключи
KEY1=""
KEY2=""
KEY3=""

# Контейнер Vault
CONTAINER=$(docker ps -q --filter name=vault_vault)

# Разблокируем - передаем ключ как аргумент
docker exec $CONTAINER vault operator unseal $KEY1
docker exec $CONTAINER vault operator unseal $KEY2
docker exec $CONTAINER vault operator unseal $KEY3

# Проверяем
docker exec $CONTAINER vault status
