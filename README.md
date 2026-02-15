#  DevOps Engineer / Infrastructure Architect

**Слои:**
1.  **Инфраструктура (Terraform):** ВМ, сети, DNS зоны, сервисные аккаунты в Yandex Cloud
2.  **Оркестрация (Ansible + Docker Swarm):** Настройка хостов, создание Swarm кластера (managers/workers)
3.  **Сеть и безопасность:** Overlay-сети, Traefik как входная точка
4.  **Service Discovery & Config:** Consul для регистрации сервисов, динамическая маршрутизация (Traefik + Consul Catalog) для apps
5.  **Secrets Management:** HashiCorp Vault с агентом для распространения сертификатов
6.  **Мониторинг:** Prometheus, Grafana, cAdvisor, Node Exporter

##  Ключевые особенности
*   **Динамическая инфраструктура:** С помощью variable "vm_names" можно контролировать количество создаваемых машин (как серверов так и клиентов) тажке ansible обновляет inventory на основе текущей конфигурации 
*   **Динамическая маршрутизация:** Traefik автоматически настраивает правила для сервисов, зарегистрированных в Consul
*   **High Availability:** Swarm managers распределены, сервисы реплицированы, vault настроен как backend consul
*   **Безопасность:** Изолированные сети, SSL/TLS для всех сервисов (wildcard), сертификаты в Vault
*   **Наблюдаемость:** Комплексный стек 

##  Обновление SSL сертификатов

Проект использует три механизма:
1.  **Ansible роль + systemd timer:** Выполняет `lego` в Docker для обновления сертификатов по расписанию отправляет в vault
2.  **Vault Agent:** Распространяет обновленные сертификаты с использованием AppRole аутентификации. Агент работает как глобальный сервис в Swarm, рендеря файлы на shared volume
3. **Certificate watcher:** Обновляет рабочие инстансы traefik на manager (Реализован как systemd, наблюдает за сертификатами при изменении отправляет сигнал перечитать конфиг)

##  Мониторинг и доступ

После деплоя сервисы будут доступны по HTTPS:
*   **Traefik Dashboard:** `https://traefik.stellarclaw.ru`
*   **Consul UI:** `https://consul.stellarclaw.ru`
*   **Vault UI:** `https://vault.stellarclaw.ru`
*   **Grafana:** `https://grafana.stellarclaw.ru` (admin пароль из Docker secret)
*   **Prometheus:** `https://prometheus.stellarclaw.ru`

##  Примечания

*   Для работы DNS-01 провайдера Let's Encrypt необходим публичный домен и делегированная DNS зона в Yandex Cloud.
*   Инициализация Vault (unseal, настройка политик) требует дополнительных шагов после первого запуска.


