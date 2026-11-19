# Lab 1: рішення і чому саме так

| # | Рішення | Чому | Альтернатива і чому ні |
|---|---|---|---|
| 1 | **Azure Container Apps** (Consumption) для застосунку | PaaS: даємо образ, Azure керує серверами, TLS і перезапусками. Є в списку дозволених сервісів лаби | VM: треба самим патчити ОС, ставити Docker, налаштовувати TLS |
| 2 | Регіон **polandcentral** | Політика Azure for Students дозволяє тільки 5 регіонів; Польща найближча, у ній є всі потрібні сервіси | swedencentral як запасний |
| 3 | **PostgreSQL Flexible B1ms, 32 GB**, без HA і geo-backup | Входить у free tier студентської підписки | HA подвоює ціну і не підтримується на Burstable |
| 4 | База **тільки в приватній підмережі** + private DNS zone | Немає публічного IP, доступ тільки з VNet | Public access + firewall по IP: база видна з інтернету |
| 5 | **NSG**: 5432 тільки з `snet-aca`, решта deny | Аналог «від security group застосунку»: в Azure ASG працюють тільки з NIC VM, а в Container Apps своїх NIC немає, тому ідентичністю застосунку є його виділена підмережа | Правило по довільному IP-діапазону |
| 6 | **ACR Basic**, admin вимкнений | Найдешевший приватний реєстр; доступ тільки через Entra-ролі | Docker Hub: публічний або платний приватний; admin-пароль = довговічний ключ |
| 7 | **Managed identity** для застосунку (AcrPull) | Без паролів до реєстру | Admin-креденшели ACR у секреті |
| 8 | **User-assigned managed identity + federated credential** для GitHub | В університетському тенанті студент може не мати права створювати App Registration; managed identity створюється в підписці | App Registration + client secret: секрет у GitHub = довговічний ключ |
| 9 | Ролі GitHub: **AcrPush на ACR + Container Apps Contributor на один app** | Найменші привілеї серед вбудованих ролей, scope на конкретні ресурси | Contributor на підписку: може все |
| 10 | **Terraform у двох частинах**: `bootstrap` (local state) і `main` (remote state) | Сховище для state треба створити до того, як ним користуватися | Один стек: курка і яйце з backend |
| 11 | Перший образ **`mcr.microsoft.com/k8se/quickstart`**, `ignore_changes` на image | Terraform не може посилатися на образ, якого ще немає в ACR; далі образом володіє CI | Terraform керує тегом: кожен деплой вимагав би `terraform apply` |
| 12 | Тег образу = **`github.sha`** | Однозначно видно, який код запущено; простий відкат | `latest`: незрозуміло, що запущено |
| 13 | **Application Gateway за прапорцем `enable_lb`** (false за замовчуванням) | ~$6 на добу; вмикається тільки на демо, вимикається одразу після | Завжди увімкнений: спалить кредит за 2 тижні |
| 14 | App Gateway → **статичний IP internal environment + Host header** | Не треба окремої private DNS zone для домену environment; TLS-сертифікат збігається, бо hostname той самий | Private DNS zone `*.<env domain>`: ще 2 ресурси |
| 15 | **Log Analytics з `daily_quota_gb = 0.15`** | Логи ніколи не вийдуть за безкоштовні 5 GB на місяць | Без ліміту: зациклений лог може коштувати гроші |
| 16 | **Budget $50** з листами на $10, $25, $50 | Перше, що вимагає лаба; бюджет тільки сповіщає | Немає |
| 17 | `min_replicas = max_replicas = 1` | Немає cold start на демо, передбачувана ціна | `min 0`: дешевше, але перший запит чекає кілька секунд |
| 18 | `Base.metadata.create_all` замість міграцій | Просто пояснити; для двох таблиць достатньо | Alembic: правильніше для реального проєкту, але більше коду |

## Вартість (polandcentral, оцінка)

| Ресурс | На добу |
|---|---|
| ACR Basic | ~$0.17 |
| Container App 0.25 vCPU / 0.5 GiB, 1 репліка | ~$0.14 у простої, до ~$0.47 під навантаженням |
| PostgreSQL B1ms + 32 GB | $0 у free tier (інакше ~$0.55) |
| Private DNS zone | ~$0.02 |
| Log Analytics, VNet, NSG, identities, storage для state | ~$0 |
| **Разом без App Gateway** | **~$0.33** |
| Application Gateway Standard_v2 + Public IP (тільки на демо) | ~$0.26 на годину |
