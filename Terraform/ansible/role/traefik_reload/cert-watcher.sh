#!/bin/bash

# Мониторинг директории с SSL сертификатами для автоматической перезагрузки Traefik
# При обнаружении изменений отправляет сигнал HUP контейнеру Traefik

WATCH_DIR="/opt/traefik/certs"
DELAY=5
LOG="/var/log/cert-watcher.log"

log() { 
    echo "$(date '+%F %T') - $1" >> "$LOG" 
}

# Проверяем директорию
if [ ! -d "$WATCH_DIR" ]; then
    echo "$(date '+%F %T') - ОШИБКА: Директория $WATCH_DIR не существует" >> "$LOG"
    exit 1
fi

log "Начало работы монитора сертификатов в $WATCH_DIR"

# Начальный хэш
OLD_HASH=$(find "$WATCH_DIR" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum)

# Основной цикл
while true; do
    sleep 2

    # Текущий хэш
    NEW_HASH=$(find "$WATCH_DIR" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum)

    if [ "$NEW_HASH" != "$OLD_HASH" ]; then
        log "Найдены изменения, жду $DELAY секунд"
        sleep $DELAY

        # Финальный хэш после задержки
        FINAL_HASH=$(find "$WATCH_DIR" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum)

        if [ "$FINAL_HASH" != "$OLD_HASH" ]; then
            log "Изменения найдены, перезагружаю Traefik"
            
            # Ищем контейнер Traefik
            CONTAINER=$(docker ps -q --filter "name=traefik")
            
            if [ -n "$CONTAINER" ]; then
                # Отправляем сигнал HUP
                docker exec "$CONTAINER" kill -HUP 1
                
                # Проверяем результат
                if [ $? -eq 0 ]; then
                    log "Traefik перезагружен контейнер: ${CONTAINER}"
                else
                    log "Не удалось перезагрузить Traefik"
                fi
            else
                log "Контейнер Traefik не найден"
            fi

            OLD_HASH="$FINAL_HASH"
        else
            log "Изменения не подтвердились, продолжаю мониторинг"
        fi
    fi
done
