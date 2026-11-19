# Cloud Labs 2026: Blog API в Azure

REST API блогу (автори і пости) на **Python 3.12 + FastAPI + SQLAlchemy + PostgreSQL**,
запакований у Docker і розгорнутий в **Azure Container Apps** з керованою базою
**Azure Database for PostgreSQL**. Уся інфраструктура описана в **Terraform**, деплой
виконує **GitHub Actions** через OIDC без збережених ключів.

Репозиторій для лабораторних робіт курсу «Хмарні сервіси» (Lab 1, Lab 2, Lab 3).

## Публічна адреса

| | |
|---|---|
| API | https://ca-blog-api.bluemushroom-488bf397.polandcentral.azurecontainerapps.io |
| Swagger UI | https://ca-blog-api.bluemushroom-488bf397.polandcentral.azurecontainerapps.io/docs |
| Health check | https://ca-blog-api.bluemushroom-488bf397.polandcentral.azurecontainerapps.io/health |

> Адреса працює, поки інфраструктура не видалена (`terraform destroy`).
> Актуальне значення: `terraform -chdir=terraform/main output public_url`.

## Ендпоінти

| Метод | Шлях | Що робить |
|---|---|---|
| GET | `/` | назва сервісу і версія (хеш коміту) |
| GET | `/health` | 200, якщо застосунок і база працюють, інакше 503 |
| POST | `/authors` | створити автора |
| GET | `/authors?limit=&offset=` | список авторів |
| GET / PUT / DELETE | `/authors/{id}` | автор (з кількістю постів), оновити, видалити |
| POST | `/posts` | створити пост |
| GET | `/posts?limit=&offset=&author_id=` | список постів з пагінацією (новіші першими) |
| GET / PUT / DELETE | `/posts/{id}` | пост з автором, оновити, видалити |
| GET | `/cache/stats` | лічильники кешу: hits, misses, hit ratio |
| POST | `/cache/stats/reset` | обнулити лічильники кешу |

## Архітектура

```
                 GitHub (push у main)
                        │  GitHub Actions: build → push → update
                        │  вхід через OIDC, без ключів
                        ▼
   ┌──────────────── Azure, polandcentral ─────────────────────────────┐
   │                                                                    │
   │  ACR (Basic) ◄─ AcrPull ── managed identity застосунку              │
   │                                                                    │
   │  VNet 10.20.0.0/16                                                 │
   │  ├─ snet-aca      Container Apps Environment                       │
   │  │                 └─ ca-blog-api (0.25 vCPU, 0.5 GiB) ◄── HTTPS ── інтернет
   │  │                        │ 5432, TLS                               │
   │  ├─ snet-postgres  ◄──────┘ NSG: 5432 тільки з snet-aca              │
   │  │                 PostgreSQL Flexible B1ms, без публічного доступу  │
   │  │                 + private DNS zone                               │
   │  └─ snet-appgw     резерв під Application Gateway (enable_lb)       │
   │                                                                    │
   │  Log Analytics ◄── логи контейнерів                                │
   └────────────────────────────────────────────────────────────────────┘
```

## Структура репозиторію

```
app/                      код застосунку
  main.py                 FastAPI, /, /health, підключення роутерів
  database.py             підключення до БД (DATABASE_URL з env)
  models.py               таблиці authors, posts
  schemas.py              Pydantic-схеми запитів і відповідей
  routers/                /authors і /posts
  cache.py                cache-aside на Redis для GET /posts
Dockerfile                образ: python:3.12.16-slim-bookworm, не root
compose.yaml              локальний запуск: app + postgres:17.12 + redis:7.4
requirements.txt          зафіксовані версії залежностей
.env.example              шаблон локальних змінних (.env у .gitignore)
terraform/
  bootstrap/              один раз, локальний state: сховище для state,
                          identity для GitHub (OIDC), бюджет
  main/                   уся інфраструктура застосунку, state в Azure Storage
.github/workflows/
  deploy.yml              CD: push у main → образ у ACR → Container App
loadtest/                 k6: script.js, run.sh (одна команда), results/
docs/
  lab1/DEFENSE.md         відповіді на теоретичні питання Lab 1
  lab1/decisions.md       рішення, альтернативи, вартість
  AUTOSCALING.md          Lab 2: правило масштабування і хронологія
  LOADTEST.md             Lab 2: сценарій k6 і звіт
  ALERTS.md               Lab 2: алерт на email
  CACHE.md                Lab 2: Redis cache-aside, порівняння
  lab2/DEFENSE.md         відповіді на теоретичні питання Lab 2
  lab2/img/               скріни дашборда і листів
```

## Локальний запуск

Потрібен лише Docker.

```bash
cp .env.example .env          # і змініть POSTGRES_PASSWORD
docker compose up --build     # http://localhost:8000/docs
docker compose down           # дані лишаються у volume pgdata
docker compose down -v        # видалити разом з даними
```

База не публікує порт на хост: до неї звертається тільки застосунок через
мережу compose (ім'я сервісу `db`). Подивитись дані:
`docker compose exec db psql -U blog -d blog -c 'select * from posts;'`

## Розгортання в Azure

Потрібні: `az` (Azure CLI), `terraform >= 1.9`, акаунт Azure з підпискою.

```bash
az login --use-device-code
```

### 1. Bootstrap (один раз)

Створює resource group `rg-blog-bootstrap`, Storage Account для Terraform state,
managed identity для GitHub Actions з federated credential і бюджет $50 з
листами на $10, $25, $50.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # subscription_id, budget_email
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

State bootstrap зберігається локально (`terraform.tfstate`, у `.gitignore`), бо цей
крок і створює віддалене сховище.

Якщо репозиторій GitHub створено заново, змініть `github_owner_id` і
`github_repository_id` у `variables.tf`: GitHub додає ці ID в OIDC-subject.
Отримати їх: `gh api repos/<owner>/<repo> --jq '.owner.id, .id'`.

### 2. Основна інфраструктура

Якщо bootstrap створювався заново, впишіть `tfstate_storage_account_name` з його
outputs у `terraform/main/versions.tf` (блок `backend "azurerm"`).

```bash
cd terraform/main
cp terraform.tfvars.example terraform.tfvars   # subscription_id
terraform init
terraform plan -out=tfplan
terraform apply tfplan                         # 10-20 хвилин
terraform output public_url
```

Container App спершу запускається з образом-заглушкою
`mcr.microsoft.com/k8se/quickstart`. Справжній образ публікує CI.

### 3. CI/CD

У `.github/workflows/deploy.yml` у блоці `env` мають бути значення з outputs:
`AZURE_CLIENT_ID` (`github_client_id`), `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
`ACR_NAME`. Це ідентифікатори, а не секрети.

Кожен push у `main`, що змінює `app/`, `Dockerfile`, `requirements.txt` або сам workflow:

1. вхід в Azure через OIDC;
2. `docker build`, тег = хеш коміту;
3. `docker push` в ACR;
4. `az containerapp update --image ...`;
5. очікування, поки нова ревізія стане ready.

Перевірити, що працює нова версія: `GET /health` повертає `version` = хеш коміту.
Запустити вручну: Actions → deploy → Run workflow.

## Видалення

```bash
terraform -chdir=terraform/main destroy        # застосунок, база, ACR, мережа
terraform -chdir=terraform/bootstrap destroy   # state storage, identity, бюджет
```

Порядок важливий: спершу `main`, бо його state лежить у сховищі з bootstrap.
Azure сам створює `NetworkWatcherRG` разом з першою VNet. Ця група безкоштовна,
Terraform нею не керує, і її можна видалити вручну:
`az group delete -n NetworkWatcherRG`.

## Вартість (без Application Gateway)

Близько **$0.55 на добу**: ACR Basic ~$0.17, Container App API ~$0.14, Redis
Container App ~$0.20 (Lab 2), DNS zone ~$0.02.
PostgreSQL B1ms покриває free tier Azure for Students. Деталі в
[docs/lab1/decisions.md](docs/lab1/decisions.md).

## Документація

* [Lab 1: відповіді до захисту](docs/lab1/DEFENSE.md)
* [Lab 1: рішення і вартість](docs/lab1/decisions.md)
* [Lab 2: відповіді до захисту](docs/lab2/DEFENSE.md)
* [Lab 2: автоматичне масштабування](docs/AUTOSCALING.md)
* [Lab 2: навантажувальне тестування](docs/LOADTEST.md)
* [Lab 2: алерт](docs/ALERTS.md)
* [Lab 2: кешування](docs/CACHE.md)
* Lab 2: дашборд `dash-blog` в Azure Portal ([`terraform/main/dashboard.tf`](terraform/main/dashboard.tf))
