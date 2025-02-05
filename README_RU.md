# transfer-gitlab-ci-cd-variables

[EN](README.md) | **RU**

## 1. Описание

Этот Bash-скрипт позволяет перенести (скопируя) переменные CI/CD из одного проекта GitLab в другой (GitLab'ы могут быть разные).

## 2. Требования

- `bash`;
- Пакеты `curl` и `jq`;
- Оба проекта GitLab должны быть созданы;
- Токены доступа (Access tokens) для обоих проектов должны иметь роль (role) `Maintainer` и область (scope) `api`.

## 3. Использование

```bash
transfer_gitlab_ci_cd_variables [--proxy <proxy_url>] <gitlab_project_1_url> <gitlab_project_1_api_token> <gitlab_project_2_url> <gitlab_project_2_api_token>
```

## 4. Пример

```bash
transfer_gitlab_ci_cd_variables https://gitlab.com/someuser/someproject ACCESS_TOKEN_1 https://othergitlab.com/someotheruser/someotherproject ACCESS_TOKEN_2
```

С прокси:

```bash
transfer_gitlab_ci_cd_variables --proxy http://192.168.0.123:3128 https://gitlab.com/someuser/someproject ACCESS_TOKEN_1 https://othergitlab.com/someotheruser/someotherproject ACCESS_TOKEN_2
```

## 5. Развитие

Не стесняйтесь участвовать в развитии репозитория, используя [pull requests](https://github.com/Nikolai2038/transfer-gitlab-ci-cd-variables/pulls) или [issues](https://github.com/Nikolai2038/transfer-gitlab-ci-cd-variables/issues)!
