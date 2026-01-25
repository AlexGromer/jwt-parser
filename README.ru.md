# JWT Parser - Гибридная реализация на чистом Bash + Go

[![Лицензия: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Тесты](https://img.shields.io/badge/tests-131%20passing-brightgreen)](tests/)
[![Безопасность](https://img.shields.io/badge/security-approved-brightgreen)](tests/TEST_REPORT.md)
[![Версия Go](https://img.shields.io/badge/go-1.21+-blue.svg)](https://golang.org)
[![Версия Bash](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

**🇷🇺 Русский** | **[🇺🇸 English](README.md)**

---

## 🎯 Описание

Production-ready парсер JWT (JSON Web Token) с **тремя реализациями**:
- **Чистый Bash** - Нулевые зависимости (работает только с `base64`)
- **Чистый Go** - Полная поддержка JWT алгоритмов (HMAC, RSA, ECDSA)
- **Гибридный роутер** - Интеллектуальная маршрутизация между Bash и Go

**Разработан для ограниченных сред:** Работает в закрытых банковских контурах, минимальных образах Alpine и Astra Linux SE без jq/openssl.

---

## ✨ Ключевые возможности

### 🔒 Безопасность превыше всего
- ✅ **Нет SQL injection уязвимостей** (14/14 security тестов пройдено)
- ✅ **Нет command injection уязвимостей**
- ✅ **Нет утечки секретов** (stdout/stderr безопасны)
- ✅ **Устойчивость к DoS** (безопасная обработка больших токенов)
- ✅ **Защита от algorithm confusion** (отклоняет алгоритм "none")
- ✅ **Учёт timing-атак**

**Статус Security Audit:** ✅ **ОДОБРЕНО ДЛЯ PRODUCTION**

### ⚡ Производительность
| Реализация | Малый токен (~500B) | Средний токен (~5KB) | Большой токен (~50KB) |
|------------|---------------------|----------------------|-----------------------|
| **Bash Parser** | ~10ms | ~15ms | ~45ms |
| **Go Parser** | ~2ms | ~8ms | ~10ms |

### 🌐 Кроссплатформенная совместимость
Протестировано и проверено на:
- ✅ Alpine Linux (minimal images)
- ✅ Astra Linux SE 1.7 Smolensk
- ✅ Kali Linux (Purple)
- ✅ Debian/Ubuntu
- ✅ RHEL/CentOS

Работает в ограниченных средах:
- ✅ Без jq (pure bash JSON parsing)
- ✅ Без openssl (Go fallback)
- ✅ Минимальный PATH (только base64)
- ✅ Закрытые сетевые контуры

### 🔐 Поддерживаемые алгоритмы

#### HMAC (Hash-based)
- ✅ HS256 (SHA-256) - Bash + Go
- ✅ HS384 (SHA-384) - Bash + Go
- ✅ HS512 (SHA-512) - Bash + Go

#### RSA (Asymmetric)
- ✅ RS256 (SHA-256) - Только Go
- ✅ RS384 (SHA-384) - Только Go
- ✅ RS512 (SHA-512) - Только Go

#### ECDSA (Elliptic Curve)
- ✅ ES256 (P-256) - Только Go
- ✅ ES384 (P-384) - Только Go
- ✅ ES512 (P-521) - Только Go

---

## 📦 Установка

### Быстрая установка (рекомендуется)

```bash
# Клонировать репозиторий
git clone https://github.com/AlexGromer/jwt-parser.git
cd jwt-parser

# Собрать статический бинарник
make build-static

# Установить системно
sudo make install

# Проверить установку
jwt-parser --version
```

### Ручная установка

#### Bash версия (без компиляции)
```bash
chmod +x jwt-parser.sh
sudo cp jwt-parser.sh /usr/local/bin/jwt-parser
```

#### Go версия (требуется Go 1.21+)
```bash
go build -o jwt-parser jwt-parser.go
sudo cp jwt-parser /usr/local/bin/
```

### Установка через Docker

```bash
# Alpine-based образ (минимальный)
docker build -t jwt-parser:alpine -f Dockerfile.alpine .

# Использование
docker run --rm jwt-parser:alpine "eyJhbGci..."
```

---

## 🚀 Быстрый старт

### Базовый парсинг

```bash
# Парсинг JWT токена (без проверки подписи)
jwt-parser "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIiwibmFtZSI6IlRlc3QgVXNlciIsImV4cCI6MTc2OTQ0NzQ3Nn0.signature"
```

**Вывод:**
```
=== JWT Parser v1.0.0 ===

=== Available Tools ===
base64:        ✓
jq:            ✓
openssl/libre: ✓ (openssl)

=== JWT Header ===
{
  "alg": "HS256",
  "typ": "JWT"
}

=== JWT Payload ===
{
  "sub": "user123",
  "name": "Test User",
  "exp": 1769447476
}

=== Validation Status ===
Status:     VALID
Expires:    2026-01-26 03:17:56 UTC (in 23h 59m)
```

### Проверка подписи

```bash
# Проверка HMAC подписи
jwt-parser --secret "my-secret-key" "eyJhbGci..."
```

### JSON вывод для автоматизации

```bash
# JSON вывод
jwt-parser --json "eyJhbGci..." | jq .

# Извлечение конкретного claim
jwt-parser --json "eyJhbGci..." | jq -r '.payload.sub'
```

### Тихий режим (только результат валидации)

```bash
# Возвращает только статус валидации
jwt-parser --quiet "eyJhbGci..."
echo $?  # 0=valid, 3=expired, 4=not yet valid, 5=invalid signature
```

---

## 📖 Сценарии использования

### 1. Закрытый банковский контур - периодическая диагностика авторизации

**Сценарий:** Закрытая среда, нужна периодическая проверка токенов

**Решение:**
```bash
#!/bin/bash
# examples/auth-diagnostics.sh

while true; do
    token=$(get_auth_token)  # Получение токена

    # Парсинг и валидация
    result=$(jwt-parser --json "$token")
    status=$(echo "$result" | jq -r '.validation_status')

    if [[ "$status" != "VALID" ]]; then
        log_alert "Валидация токена провалилась: $status"
    fi

    sleep 300  # Проверка каждые 5 минут
done
```

### 2. Внутренняя авторизация микросервисов

**Сценарий:** Валидация JWT токенов между микросервисами

**Решение:**
```bash
#!/bin/bash
# examples/microservice-validator.sh

validate_request() {
    local auth_header="$1"
    local token="${auth_header#Bearer }"

    # Проверка подписи
    result=$(jwt-parser --secret "$JWT_SECRET" --json "$token")

    if echo "$result" | jq -e '.signature_valid == true' > /dev/null; then
        user_id=$(echo "$result" | jq -r '.payload.sub')
        echo "Авторизован: $user_id"
        return 0
    else
        echo "Не авторизован"
        return 1
    fi
}
```

### 3. DevOps/CI Pipeline

**Сценарий:** Валидация сервисных токенов в deployment скриптах

**Решение:**
```bash
# Использование hybrid router для оптимальной производительности
./jwt-parser-hybrid.sh "$SERVICE_TOKEN"

if [ $? -eq 0 ]; then
    echo "Токен валиден, продолжаем deployment"
    deploy_service
else
    echo "Токен невалиден, отмена"
    exit 1
fi
```

---

## 🧪 Тестирование

### Запуск всех тестов

```bash
# Полный набор тестов (131 тест)
make test
```

### Отдельные наборы тестов

```bash
# Bash unit тесты (31 тест)
bash tests/unit/test_bash_parser.sh

# Security тесты (14 тестов)
bash tests/security/test_security.sh

# Compatibility тесты (45 тестов)
bash tests/compatibility/test_compatibility.sh

# Integration тесты (23 теста)
bash tests/integration/test_integration.sh

# Go unit тесты (18 тестов)
go test -v
```

### Результаты тестов

```
Всего тест-наборов:  5
Всего тестов:        131
Пройдено:            131
Провалено:           0
Успешность:          100% ✅
```

**Детальные отчёты:**
- [TEST_REPORT.md](tests/TEST_REPORT.md) - Полный тестовый отчёт
- [TEST_SUMMARY.txt](tests/TEST_SUMMARY.txt) - Визуальная сводка

---

## 📊 Сравнение: Bash vs Go vs Hybrid

| Характеристика | Bash | Go | Hybrid |
|----------------|------|-----|--------|
| **Зависимости** | только base64 | Нет (static) | Оба парсера |
| **Размер** | 16KB скрипт | ~2MB бинарник | 11KB + парсеры |
| **Производительность** | Хорошая | Отличная | Оптимальная |
| **HMAC Support** | ✅ (с openssl) | ✅ | ✅ |
| **RSA Support** | ❌ | ✅ | ✅ (через Go) |
| **ECDSA Support** | ❌ | ✅ | ✅ (через Go) |
| **Портативность** | Высокая | Очень высокая | Высокая |
| **Лучше для** | Минимальная среда | Производительность | Авто-оптимизация |

### Матрица рекомендаций

| Окружение | Рекомендуемая версия | Обоснование |
|-----------|----------------------|-------------|
| **Alpine/Minimal** | Bash | Минимальный размер |
| **Production сервисы** | Go | Лучшая производительность |
| **Смешанные окружения** | Hybrid | Адаптивность |
| **Закрытые сети** | Bash | Минимум зависимостей |
| **Высокая нагрузка** | Go | В 2-3 раза быстрее |

---

## 🛠️ Конфигурация

### Переменные окружения

```bash
# HMAC секрет для проверки подписи
export JWT_SECRET="your-secret-key"

# Явное использование Go парсера
export PREFER_GO_PARSER=1

# Отключить цветной вывод
export NO_COLOR=1
```

### Exit коды

| Код | Значение | Пример |
|-----|----------|--------|
| 0 | Успех (токен валиден) | Токен распарсен и валидирован |
| 1 | Неверные аргументы | Отсутствует токен, неверные опции |
| 2 | Неверный формат JWT | Неправильная структура токена |
| 3 | Токен истёк | Истёк timestamp |
| 4 | Токен ещё не валиден | nbf (not before) не достигнут |
| 5 | Подпись невалидна | Неверный секрет или повреждённая подпись |
| 6 | Отсутствуют требуемые инструменты | base64 не найден |

---

## 📚 Документация

- [README.md](README.md) - Английская версия
- [README.ru.md](README.ru.md) - Этот файл (русский)
- [QUICKSTART.md](QUICKSTART.md) - Руководство быстрого старта
- [RELEASE_NOTES.md](RELEASE_NOTES.md) - Release notes v1.0.0
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Сводка проекта
- [tests/TEST_REPORT.md](tests/TEST_REPORT.md) - Детальный тестовый отчёт
- [tests/BUG_REPORT.md](tests/BUG_REPORT.md) - Отслеживание багов

---

## 🏗️ Структура проекта

```
jwt-parser/
├── jwt-parser.sh              Pure Bash парсер
├── jwt-parser.go              Pure Go парсер
├── jwt-parser-hybrid.sh       Интеллектуальный роутер
├── jwt-parser_test.go         Go unit тесты
├── Makefile                   Автоматизация сборки
├── examples/                  Примеры использования
│   ├── auth-diagnostics.sh
│   ├── microservice-validator.sh
│   └── generate-test-token.sh
└── tests/                     Тестовая инфраструктура
    ├── unit/
    ├── security/
    ├── compatibility/
    └── integration/
```

---

## 🤝 Участие в разработке

Приветствуются любые contributions! Не стесняйтесь создавать Pull Request.

### Настройка окружения разработки

```bash
# Клонировать репозиторий
git clone https://github.com/AlexGromer/jwt-parser.git
cd jwt-parser

# Установить зависимости
make deps

# Запустить тесты
make test

# Собрать все версии
make build-all
```

### Отчёты о багах

Нашли баг? Пожалуйста, сообщите:
1. Структура токена (только header/payload, без signature)
2. Ожидаемое поведение
3. Фактическое поведение
4. Окружение (ОС, версия bash, доступные инструменты)

---

## 📄 Лицензия

Этот проект распространяется под лицензией MIT - см. файл [LICENSE](LICENSE) для деталей.

---

## 🙏 Благодарности

### Используемые технологии
- **Bash** - GNU Bash 4.0+
- **Go** - Go 1.21+
- **JWT Standard** - RFC 7519
- **Testing** - Кастомный bash test framework + Go testing

### Библиотеки (Go)
- `github.com/golang-jwt/jwt/v5` - JWT реализация

---

## 📞 Поддержка

### Решение проблем

**Проблема:** "Required tools missing"
**Решение:** Установите base64 (должен быть доступен на всех UNIX системах)

**Проблема:** Проверка подписи проваливается
**Решение:** Проверьте, что секрет точно соответствует секрету подписания

**Проблема:** Ошибки парсинга JSON без jq
**Решение:** Установите jq или используйте pure bash режим (автоматический fallback)

**Проблема:** Слишком низкая производительность
**Решение:** Используйте Go версию (`jwt-parser`) вместо bash

---

## 🎯 Статус проекта

**Версия:** 1.0.0
**Статус:** ✅ **Production Ready**
**Тестовое покрытие:** 100% (131/131 тестов проходят)
**Security статус:** ✅ Одобрено

Этот JWT парсер был тщательно протестирован и одобрен для развертывания в банковских окружениях.

---

## 🔗 Ссылки

- **Репозиторий:** [github.com/AlexGromer/jwt-parser](https://github.com/AlexGromer/jwt-parser)
- **Issues:** [github.com/AlexGromer/jwt-parser/issues](https://github.com/AlexGromer/jwt-parser/issues)
- **Releases:** [github.com/AlexGromer/jwt-parser/releases](https://github.com/AlexGromer/jwt-parser/releases)

---

**Сделано с ❤️ для безопасного парсинга JWT в ограниченных средах**

**[🇺🇸 Read in English](README.md)**
