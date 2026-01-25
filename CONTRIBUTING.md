# Contributing to JWT Parser

**[🇷🇺 Русский](#участие-в-разработке-ru)** | **🇺🇸 English**

---

## 🤝 Welcome Contributors!

Thank you for your interest in contributing to JWT Parser! This document provides guidelines and instructions for contributing.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)

---

## 📜 Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code.

**Be respectful, inclusive, and constructive.**

---

## 🎯 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

**Bug Report Template:**
```markdown
**Description:** Brief description of the bug

**To Reproduce:**
1. Step 1
2. Step 2
3. ...

**Expected Behavior:** What you expected to happen

**Actual Behavior:** What actually happened

**Environment:**
- OS: [e.g., Alpine Linux, Astra Linux SE]
- Bash Version: [e.g., 5.1.16]
- Go Version (if applicable): [e.g., 1.21.5]
- Available Tools: [e.g., jq: yes, openssl: yes]

**Token Structure (NO SECRETS):**
```json
{
  "header": {...},
  "payload": {...}
}
```
```

### Suggesting Enhancements

Enhancement suggestions are welcome! Please:
- Use a clear and descriptive title
- Provide detailed description of the enhancement
- Explain why this would be useful
- Provide examples if applicable

### Pull Requests

We actively welcome your pull requests!

---

## 🛠️ Development Setup

### Prerequisites

- **Bash:** 4.0 or higher
- **Go:** 1.21 or higher (for Go components)
- **Git:** Latest version
- **Optional:** jq, openssl (for testing)

### Setup Instructions

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/jwt-parser.git
cd jwt-parser

# Add upstream remote
git remote add upstream https://github.com/AlexGromer/jwt-parser.git

# Create feature branch
git checkout -b feature/your-feature-name

# Install Go dependencies
make deps

# Run tests to verify setup
make test
```

---

## 🧪 Testing

**All contributions must include tests.**

### Running Tests

```bash
# Run all tests
make test

# Run specific test suite
bash tests/unit/test_bash_parser.sh
bash tests/security/test_security.sh
bash tests/compatibility/test_compatibility.sh
bash tests/integration/test_integration.sh
go test -v

# Check test coverage (Go)
go test -coverprofile=coverage.txt
go tool cover -html=coverage.txt
```

### Writing Tests

#### Bash Tests

Add tests to appropriate file in `tests/`:
- `tests/unit/` - Unit tests for bash parser
- `tests/security/` - Security-related tests
- `tests/compatibility/` - Compatibility tests
- `tests/integration/` - Integration tests

Example:
```bash
test_your_feature() {
    local token="eyJhbGci..."
    local output=$("$PARSER" "$token" 2>&1)

    assert_contains "$output" "expected_text" "Test description"
}
test_your_feature
```

#### Go Tests

Add tests to `jwt-parser_test.go`:

```go
func TestYourFeature(t *testing.T) {
    parser := NewJWTParser()
    result, err := parser.Parse(tokenString)

    if err != nil {
        t.Fatalf("Parse failed: %v", err)
    }

    if result.Subject != "expected" {
        t.Errorf("Expected 'expected', got '%s'", result.Subject)
    }
}
```

---

## 🔄 Pull Request Process

1. **Update Documentation**
   - Update README if adding features
   - Add/update examples if needed
   - Update CHANGELOG.md (if exists)

2. **Ensure Tests Pass**
   ```bash
   make test
   ```
   All 131 tests must pass!

3. **Follow Commit Message Format**
   ```
   <type>: <subject>

   <body>

   <footer>
   ```

   Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

   Example:
   ```
   feat: Add ES256 algorithm support

   - Implement ECDSA P-256 signature verification
   - Add tests for ES256 tokens
   - Update documentation with new algorithm

   Closes #42
   ```

4. **Create Pull Request**
   - Use descriptive title
   - Fill out PR template
   - Link related issues
   - Request review

5. **Code Review**
   - Address reviewer feedback
   - Keep discussion constructive
   - Update PR based on comments

6. **Merge**
   - Squash commits if needed
   - Ensure CI passes
   - Wait for maintainer approval

---

## 📏 Coding Standards

### Bash

- Use `#!/bin/bash` shebang
- Enable strict mode when appropriate: `set -euo pipefail`
- Quote variables: `"$variable"`
- Use functions for reusable code
- Add comments for complex logic
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

**Example:**
```bash
parse_token() {
    local token="$1"

    # Validate input
    if [[ -z "$token" ]]; then
        echo "Error: Token required" >&2
        return 1
    fi

    # Process token
    local header payload signature
    IFS='.' read -r header payload signature <<< "$token"

    echo "Parsed successfully"
}
```

### Go

- Follow [Effective Go](https://golang.org/doc/effective_go)
- Use `gofmt` for formatting
- Run `golangci-lint` before committing
- Write godoc comments for exported functions
- Handle errors explicitly

**Example:**
```go
// ParseToken parses a JWT token and returns the result.
// Returns an error if the token is malformed.
func (p *JWTParser) ParseToken(tokenString string) (*ParseResult, error) {
    if tokenString == "" {
        return nil, fmt.Errorf("token cannot be empty")
    }

    // Parse token
    result, err := p.parse(tokenString)
    if err != nil {
        return nil, fmt.Errorf("parse failed: %w", err)
    }

    return result, nil
}
```

### Git

- One feature per branch
- Atomic commits (one logical change per commit)
- Clear commit messages
- Rebase before merging (if needed)

---

## 🔒 Security

**DO NOT commit:**
- Secrets or API keys
- Actual JWT tokens with real data
- Private keys or certificates
- Credentials of any kind

**For security issues:**
- DO NOT open public issues
- Email maintainers privately
- Use GitHub Security Advisories

---

## 📝 Documentation

When adding features, update:
- README.md (English)
- README.ru.md (Russian)
- Inline code comments
- Test cases
- Examples (if applicable)

---

## ✅ Checklist Before Submitting PR

- [ ] Code follows project style guidelines
- [ ] Tests added/updated and passing (131/131)
- [ ] Documentation updated (EN + RU)
- [ ] Commit messages are clear
- [ ] No secrets or sensitive data
- [ ] Branch is up to date with `main`/`develop`
- [ ] CI checks pass

---

## 🎁 Recognition

Contributors will be recognized in:
- Project README
- Release notes
- Git commit history (Co-authored-by)

---

## 📞 Questions?

- Open an issue with `question` label
- Check existing documentation
- Review closed issues/PRs

---

## 🙏 Thank You!

Your contributions make this project better for everyone!

---

# Участие в разработке (RU)

**🇷🇺 Русский** | **[🇺🇸 English](#contributing-to-jwt-parser)**

---

## 🤝 Добро пожаловать, контрибьюторы!

Спасибо за ваш интерес к проекту JWT Parser! Этот документ содержит рекомендации по участию в разработке.

## 📋 Содержание

- [Кодекс поведения](#кодекс-поведения)
- [Как я могу помочь?](#как-я-могу-помочь)
- [Настройка окружения](#настройка-окружения)
- [Тестирование](#тестирование-1)
- [Процесс Pull Request](#процесс-pull-request)
- [Стандарты кодирования](#стандарты-кодирования)

---

## 📜 Кодекс поведения

Этот проект следует Кодексу поведения. Участвуя, вы обязуетесь соблюдать его.

**Будьте уважительны, инклюзивны и конструктивны.**

---

## 🎯 Как я могу помочь?

### Сообщение о багах

Перед созданием сообщения о баге проверьте существующие issues во избежание дубликатов.

**Шаблон Bug Report:**
```markdown
**Описание:** Краткое описание бага

**Как воспроизвести:**
1. Шаг 1
2. Шаг 2
3. ...

**Ожидаемое поведение:** Что должно было произойти

**Фактическое поведение:** Что произошло на самом деле

**Окружение:**
- ОС: [например, Alpine Linux, Astra Linux SE]
- Версия Bash: [например, 5.1.16]
- Версия Go (если применимо): [например, 1.21.5]
- Доступные инструменты: [например, jq: да, openssl: да]

**Структура токена (БЕЗ СЕКРЕТОВ):**
```json
{
  "header": {...},
  "payload": {...}
}
```
```

### Предложения по улучшениям

Приветствуются предложения по улучшениям! Пожалуйста:
- Используйте чёткий и описательный заголовок
- Предоставьте детальное описание улучшения
- Объясните, почему это будет полезно
- Приведите примеры, если применимо

### Pull Requests

Мы с радостью принимаем ваши pull requests!

---

## 🛠️ Настройка окружения

### Требования

- **Bash:** 4.0 или выше
- **Go:** 1.21 или выше (для Go компонентов)
- **Git:** Последняя версия
- **Опционально:** jq, openssl (для тестирования)

### Инструкции по настройке

```bash
# Клонировать ваш форк
git clone https://github.com/YOUR_USERNAME/jwt-parser.git
cd jwt-parser

# Добавить upstream remote
git remote add upstream https://github.com/AlexGromer/jwt-parser.git

# Создать feature ветку
git checkout -b feature/your-feature-name

# Установить Go зависимости
make deps

# Запустить тесты для проверки настройки
make test
```

---

## 🧪 Тестирование

**Все contributions должны включать тесты.**

### Запуск тестов

```bash
# Запустить все тесты
make test

# Запустить конкретный набор тестов
bash tests/unit/test_bash_parser.sh
bash tests/security/test_security.sh
bash tests/compatibility/test_compatibility.sh
bash tests/integration/test_integration.sh
go test -v

# Проверить покрытие тестами (Go)
go test -coverprofile=coverage.txt
go tool cover -html=coverage.txt
```

### Написание тестов

#### Bash тесты

Добавляйте тесты в соответствующий файл в `tests/`:
- `tests/unit/` - Unit тесты для bash парсера
- `tests/security/` - Security тесты
- `tests/compatibility/` - Compatibility тесты
- `tests/integration/` - Integration тесты

Пример:
```bash
test_your_feature() {
    local token="eyJhbGci..."
    local output=$("$PARSER" "$token" 2>&1)

    assert_contains "$output" "expected_text" "Описание теста"
}
test_your_feature
```

#### Go тесты

Добавляйте тесты в `jwt-parser_test.go`:

```go
func TestYourFeature(t *testing.T) {
    parser := NewJWTParser()
    result, err := parser.Parse(tokenString)

    if err != nil {
        t.Fatalf("Parse failed: %v", err)
    }

    if result.Subject != "expected" {
        t.Errorf("Expected 'expected', got '%s'", result.Subject)
    }
}
```

---

## 🔄 Процесс Pull Request

1. **Обновление документации**
   - Обновите README при добавлении features
   - Добавьте/обновите примеры при необходимости
   - Обновите CHANGELOG.md (если существует)

2. **Убедитесь, что тесты проходят**
   ```bash
   make test
   ```
   Все 131 тест должны пройти!

3. **Следуйте формату commit сообщений**
   ```
   <тип>: <тема>

   <тело>

   <футер>
   ```

   Типы: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

   Пример:
   ```
   feat: Добавлена поддержка алгоритма ES256

   - Реализована проверка ECDSA P-256 подписей
   - Добавлены тесты для ES256 токенов
   - Обновлена документация с новым алгоритмом

   Closes #42
   ```

4. **Создание Pull Request**
   - Используйте описательный заголовок
   - Заполните PR template
   - Свяжите с issues
   - Запросите review

5. **Code Review**
   - Отвечайте на отзывы рецензентов
   - Поддерживайте конструктивное обсуждение
   - Обновляйте PR на основе комментариев

6. **Merge**
   - Squash commits при необходимости
   - Убедитесь, что CI проходит
   - Дождитесь одобрения мейнтейнеров

---

## 📏 Стандарты кодирования

### Bash

- Используйте `#!/bin/bash` shebang
- Включайте strict mode когда уместно: `set -euo pipefail`
- Заключайте переменные в кавычки: `"$variable"`
- Используйте функции для переиспользуемого кода
- Добавляйте комментарии для сложной логики
- Следуйте [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

### Go

- Следуйте [Effective Go](https://golang.org/doc/effective_go)
- Используйте `gofmt` для форматирования
- Запускайте `golangci-lint` перед коммитом
- Пишите godoc комментарии для экспортируемых функций
- Обрабатывайте ошибки явно

### Git

- Одна feature на ветку
- Атомарные коммиты (одно логическое изменение на коммит)
- Чёткие commit сообщения
- Rebase перед merge (при необходимости)

---

## 🔒 Безопасность

**НЕ коммитьте:**
- Секреты или API ключи
- Реальные JWT токены с настоящими данными
- Приватные ключи или сертификаты
- Любые credentials

**Для проблем безопасности:**
- НЕ открывайте публичные issues
- Пишите мейнтейнерам приватно
- Используйте GitHub Security Advisories

---

## ✅ Checklist перед отправкой PR

- [ ] Код следует стандартам проекта
- [ ] Тесты добавлены/обновлены и проходят (131/131)
- [ ] Документация обновлена (EN + RU)
- [ ] Commit сообщения чёткие
- [ ] Нет секретов или чувствительных данных
- [ ] Ветка синхронизирована с `main`/`develop`
- [ ] CI проверки проходят

---

## 🙏 Спасибо!

Ваши contributions делают этот проект лучше для всех!
