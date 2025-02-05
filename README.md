# transfer-gitlab-ci-cd-variables

**EN** | [RU](README_RU.md)

## 1. Description

This Bash script allows to transfer (by copying) CI/CD variables from one GitLab project to another (GitLabs can differ too).

## 2. Requirements

- `bash`;
- `curl` and `jq` packages;
- Both project must exist;
- Access tokens for them must have role `Maintainer` and scope `api`.

## 3. Usage

```bash
transfer_gitlab_ci_cd_variables [--proxy <proxy_url>] <gitlab_project_1_url> <gitlab_project_1_api_token> <gitlab_project_2_url> <gitlab_project_2_api_token>
```

## 4. Example

```bash
transfer_gitlab_ci_cd_variables https://gitlab.com/someuser/someproject ACCESS_TOKEN_1 https://othergitlab.com/someotheruser/someotherproject ACCESS_TOKEN_2
```

With proxy:

```bash
transfer_gitlab_ci_cd_variables --proxy http://192.168.0.123:3128 https://gitlab.com/someuser/someproject ACCESS_TOKEN_1 https://othergitlab.com/someotheruser/someotherproject ACCESS_TOKEN_2
```

## 5. Contribution

Feel free to contribute via [pull requests](https://github.com/Nikolai2038/transfer-gitlab-ci-cd-variables/pulls) or [issues](https://github.com/Nikolai2038/transfer-gitlab-ci-cd-variables/issues)!
