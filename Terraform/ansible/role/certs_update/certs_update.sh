#!/bin/bash
LOG_FILE="/var/log/cert_check.log"
CERT_FILE="/opt/traefik/certs/stellarclaw.ru.crt"
CERT_DIR="/opt/traefik/certs"

# Пишем в лог
echo "Проверка: $(date)" >> "$LOG_FILE"
HOSTNAME=$(hostname)

export VAULT_NAME=$(docker ps -q --filter name=vault_vault)
CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Флаг нужно ли обновлять
NEED_RENEW=false

# Проверяем срок
if [ -f "$CERT_FILE" ]; then
    # Получаем дату истечения
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)

    if [ -n "$EXPIRY" ]; then
        echo "Сертификат действителен до: $EXPIRY" >> "$LOG_FILE"

        # Конвертируем в дни
        EXPIRY_SEC=$(date -d "$EXPIRY" +%s)
        NOW_SEC=$(date +%s)
        DAYS=$(( (EXPIRY_SEC - NOW_SEC) / 86400 ))

        echo "Осталось дней: $DAYS" >> "$LOG_FILE"

        # Если меньше 30 дней - обновляем
        if [ "$DAYS" -lt 30 ]; then
            echo "Мало дней ($DAYS), запускаем обновление" >> "$LOG_FILE"
            NEED_RENEW=true
        else
            echo "Обновление не требуется ещё $DAYS дней" >> "$LOG_FILE"
        fi
    else
        echo "Не удалось прочитать срок сертификата, обновляем" >> "$LOG_FILE"
        NEED_RENEW=true
    fi
else
    echo "Сертификат не найден, создаём новый" >> "$LOG_FILE"
    NEED_RENEW=true
fi

# ЕСЛИ НУЖНО ОБНОВЛЯТЬ
if [ "$NEED_RENEW" = true ]; then
    YANDEX_CLOUD_FOLDER_ID="TOKEN"
    YANDEX_CLOUD_IAM_TOKEN=$(cat /usr/local/bin/lego-service-account-key.json | base64)

    echo "Запускаем Docker Lego" >> "$LOG_FILE"
    
    docker run -it --rm \
      -v "$CERT_DIR:/.lego/certificates" \
      -e "YANDEX_CLOUD_FOLDER_ID=$YANDEX_CLOUD_FOLDER_ID" \
      -e "YANDEX_CLOUD_IAM_TOKEN=$YANDEX_CLOUD_IAM_TOKEN" \
      goacme/lego:latest \
      --email="admin@stellarclaw.ru" \
      --domains="*.stellarclaw.ru" \
      --domains="stellarclaw.ru" \
      --dns="yandexcloud" \
      --accept-tos \
      run 2>&1 >> "$LOG_FILE"

    # Проверяем успешность Docker
    if [ $? -eq 0 ]; then
        echo "Docker Lego успешно выполнился" >> "$LOG_FILE"
        
        cd "$CERT_DIR" || exit 1

        if [ -f "_.stellarclaw.ru.crt" ]; then
            mv _.stellarclaw.ru.crt stellarclaw.ru.crt
            mv _.stellarclaw.ru.key stellarclaw.ru.key

            chmod 740 stellarclaw.ru.crt
            chmod 740 stellarclaw.ru.key

            chown traefik-vault:traefik-vault stellarclaw.ru.crt
            chown traefik-vault:traefik-vault stellarclaw.ru.key

            MESSAGE=" $CURRENT_TIME  Скрипт выполнен на сервере: $HOSTNAME"
            echo "$MESSAGE" >> "$LOG_FILE"

            # Загружаем в Vault если Vault доступен
            if [ -n "$VAULT_NAME" ]; then
                VAULT_TOKEN_LEGO="hvs.TOKEN"

                docker cp stellarclaw.ru.crt "$VAULT_NAME:/tmp/"
                docker cp stellarclaw.ru.key "$VAULT_NAME:/tmp/"

                docker exec -e VAULT_TOKEN="$VAULT_TOKEN_LEGO" "$VAULT_NAME" vault kv put secret/certs/wildcard.stellarclaw.ru \
                  certificate=@/tmp/stellarclaw.ru.crt \
                  private_key=@/tmp/stellarclaw.ru.key 2>&1 >> "$LOG_FILE"
                
                echo "Сертификат загружен в Vault" >> "$LOG_FILE"
            else
                echo "Vault не найден, пропускаем загрузку" >> "$LOG_FILE"
            fi

            echo "Обновление завершено успешно" >> "$LOG_FILE"
        else
            echo "ОШИБКА: Файлы сертификатов не созданы" >> "$LOG_FILE"
        fi
    else
        echo "ОШИБКА: Docker Lego завершился с ошибкой" >> "$LOG_FILE"
    fi
fi

echo "---" >> "$LOG_FILE"
