# JWT Parser - Quick Start Guide

## Три версии на выбор

### 1. Pure Bash (jwt-parser.sh)
**Когда использовать:** Закрытый контур, минимальные зависимости

```bash
# Парсинг токена (работает везде где есть base64)
./jwt-parser.sh "YOUR_TOKEN"

# С проверкой подписи (если есть openssl)
./jwt-parser.sh --secret "your-secret" "YOUR_TOKEN"

# JSON output для автоматизации
./jwt-parser.sh --json "YOUR_TOKEN" | jq .
```

**Возможности:**
- ✅ Работает без jq (pure bash JSON parser)
- ✅ Работает без openssl (только парсинг)
- ✅ Проверка claims (exp, nbf, iat)
- ❌ Только HMAC подписи (HS256/384/512)

---

### 2. Pure Go (jwt-parser)
**Когда использовать:** Микросервисы, Docker, нужна полная валидация

```bash
# Парсинг + полная валидация
./jwt-parser "YOUR_TOKEN"

# С проверкой подписи (HMAC)
./jwt-parser -secret "your-secret" "YOUR_TOKEN"

# С проверкой RSA подписи
./jwt-parser -public-key /path/to/public.pem "YOUR_TOKEN"

# Секрет из переменной окружения
export JWT_SECRET="your-secret"
./jwt-parser -secret-env JWT_SECRET "YOUR_TOKEN"
```

**Возможности:**
- ✅ Все алгоритмы (HS256, RS256, ES256, etc.)
- ✅ Статическая компиляция (3.1 MB, нет зависимостей)
- ✅ Работает в Alpine, Astra, любом Linux
- ✅ Полная библиотека golang-jwt

---

### 3. Hybrid (jwt-parser-hybrid.sh)
**Когда использовать:** Универсальное решение, оптимальная производительность

```bash
# Автоматический выбор между Bash и Go
./jwt-parser-hybrid.sh --secret "your-secret" "YOUR_TOKEN"

# Показать решение о маршрутизации
./jwt-parser-hybrid.sh --verbose --secret "your-secret" "YOUR_TOKEN"
```

**Логика маршрутизации:**
- Нет проверки подписи → **Bash** (быстрее)
- HMAC + openssl есть → **Bash** (нативно)
- RSA/ECDSA алгоритмы → **Go** (required)
- Нет openssl но есть Go → **Go** (fallback)

---

## Банковские сценарии

### Сценарий 1: Диагностика авторизации

```bash
# Периодическая проверка токенов
./examples/auth-diagnostics.sh "YOUR_TOKEN"

# Логируется в /var/log/auth-diagnostics.log
# Exit codes: 0=OK, 3=expired, 5=invalid signature
```

### Сценарий 2: Валидация в микросервисе

```bash
# Установить секрет
export JWT_SECRET="production-secret"

# Проверить токен
./examples/microservice-validator.sh "YOUR_TOKEN"

# Возвращает JSON с user_id, roles, tenant
```

### Сценарий 3: Генерация тестовых токенов

```bash
# Создать тестовый токен
./examples/generate-test-token.sh "user123" "John Doe"

# Использовать для тестирования
```

---

## Exit коды для автоматизации

```bash
./jwt-parser.sh "$TOKEN"
case $? in
    0) echo "Valid" ;;
    3) echo "Expired - need renewal" ;;
    4) echo "Not yet valid" ;;
    5) echo "SECURITY: Invalid signature!" ;;
    *) echo "Invalid token" ;;
esac
```

---

## Docker / Alpine

```dockerfile
FROM alpine:3.18

# Копируем статический бинарник (работает без зависимостей)
COPY jwt-parser-alpine /usr/local/bin/jwt-parser

# Использование
RUN jwt-parser -secret "$JWT_SECRET" "$TOKEN"
```

---

## Проверка доступных инструментов

Bash версия автоматически определяет что доступно:

```
=== Available Tools ===
base64:        ✓
jq:            ✓
openssl/libre: ✓ (openssl)
```

Если чего-то нет - работает в degraded mode (pure bash).

---

## Быстрый тест

```bash
# Сгенерировать тестовый токен
TEST_TOKEN=$(./examples/generate-test-token.sh | grep "^ey" | head -1)

# Проверить все три версии
./jwt-parser.sh --secret "my-bank-secret-key-2024" "$TEST_TOKEN"
./jwt-parser -secret "my-bank-secret-key-2024" "$TEST_TOKEN"
./jwt-parser-hybrid.sh --verbose --secret "my-bank-secret-key-2024" "$TEST_TOKEN"
```

---

## Полная документация

См. `README.md` для:
- Детальное описание всех функций
- Примеры использования
- Troubleshooting
- Безопасность
- Performance сравнение

---

**Вопросы?** См. README.md или примеры в examples/
