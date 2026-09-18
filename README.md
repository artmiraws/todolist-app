# TodoList

Aplicação web de lista de tarefas.

![Tela principal da aplicação](assets/todolist.png)

## Stack

- Python 3.11
- Flask
- SQLAlchemy
- PostgreSQL
- gunicorn

## Variáveis de ambiente

### Aplicação

| Variável | Padrão | Descrição |
|---|---|---|
| `APP_NAME` | `TodoList` | Título exibido na interface |
| `APP_PORT` | `5000` | Porta do servidor |
| `APP_COLOR` | *(cinza)* | Cor do tema da interface. Valores aceitos abaixo |
| `SESSION_KEY` | `dev-only-insecure-key` | Assina os cookies de sessão via HMAC |
| `ADMIN_USER` | `admin` | Usuário de login |
| `ADMIN_PASSWORD` | `admin` | Senha de login |
| `CLEANUP_TOKEN` | *(vazio)* | Token exigido no header `X-Cleanup-Token` pelo endpoint `POST /cleanup` |

### Banco de dados

| Variável | Padrão | Descrição |
|---|---|---|
| `DB_HOST` | `localhost` | Host do PostgreSQL |
| `DB_PORT` | `5432` | Porta do PostgreSQL |
| `DB_NAME` | `todolist` | Nome do banco |
| `DB_USER` | `todolist` | Usuário do banco |
| `DB_PASSWORD` | *(vazio)* | Senha do usuário do banco |

O schema é criado pela própria aplicação na inicialização. O banco precisa existir e estar
acessível antes de a aplicação subir.

## Credenciais em arquivo

As credenciais podem vir de arquivo, em vez de variável de ambiente. A aplicação procura por
um arquivo com o nome da variável dentro de `SECRETS_DIR`, e usa a variável de ambiente apenas
quando o arquivo não existe.

| Variável | Padrão | Descrição |
|---|---|---|
| `SECRETS_DIR` | `/var/run/secrets/todolist` | Diretório onde a aplicação procura as credenciais em arquivo |

Valores que aceitam arquivo: `DB_USER`, `DB_PASSWORD`, `SESSION_KEY`, `ADMIN_USER`,
`ADMIN_PASSWORD` e `CLEANUP_TOKEN`.

Exemplo: com `SECRETS_DIR` no padrão, um arquivo em
`/var/run/secrets/todolist/DB_PASSWORD` é lido no lugar da variável `DB_PASSWORD`. Espaços e
quebras de linha nas pontas do arquivo são descartados.

## Valores aceitos em `APP_COLOR`

`purple`, `green`, `blue`, `cyan`, `pink`, `red`, `orange`, `brown`, `yellow`.

Valor ausente ou inválido resulta no tema cinza.

## Endpoints

| Endpoint | Método | Autenticação | Descrição |
|---|---|---|---|
| `/` | GET | Sessão | Lista de tarefas |
| `/login` | GET, POST | — | Formulário de login |
| `/logout` | GET | Sessão | Encerra a sessão |
| `/add` | POST | Sessão | Cria uma tarefa |
| `/toggle/<id>` | POST | Sessão | Alterna a tarefa entre feita e pendente |
| `/delete/<id>` | POST | Sessão | Remove uma tarefa |
| `/healthz` | GET | — | Verifica a conexão com o banco e responde `ok` |
| `/cleanup` | POST | Header `X-Cleanup-Token` | Remove todas as tarefas concluídas e responde com a quantidade removida |
| `/pods` | GET | Sessão | Lista os pods do namespace |
| `/cleanup/status` | GET, POST | Sessão | Histórico das execuções de limpeza. O POST suspende ou retoma o agendamento |

## Limpeza das tarefas concluídas

A aplicação não remove tarefas concluídas por conta própria. A limpeza precisa ser acionada de
fora, chamando o endpoint periodicamente com o token no header `X-Cleanup-Token`:

```bash
curl -X POST -H "X-Cleanup-Token: $CLEANUP_TOKEN" http://<host>/cleanup
```

A resposta é a quantidade de tarefas removidas, no formato `deleted N`. Sem o token correto o
endpoint responde `401`.

A página `/cleanup/status` mostra o resultado das últimas execuções e permite pausar e retomar
o agendamento.

## Executando localmente

Requisitos: Python 3.11 e um PostgreSQL acessível.

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=todolist
export DB_USER=todolist
export DB_PASSWORD=sua-senha

export SESSION_KEY=chave-local
export ADMIN_USER=admin
export ADMIN_PASSWORD=admin
export CLEANUP_TOKEN=token-local

gunicorn --bind 0.0.0.0:5000 app:app
```

A aplicação fica disponível em `http://localhost:5000`.

## Observações

A aplicação foi escrita para rodar em Kubernetes. Fora de um cluster, parte das
funcionalidades não funciona por completo.

## Estratégia de ambientes

O plano completo está em [`docs/PLAN.md`](docs/PLAN.md).

- **Local (k3s em k3d):** cluster de validação do desenvolvedor, sem custo de AWS; não é uma etapa de pipeline.
- **Dev (AWS EKS):** escopo inicial de cloud — um único cluster EKS pequeno e econômico. Não há promoção de local para dev: o GitHub Actions builda a partir do código-fonte e faz o deploy no dev via Helm (planejado, ainda não implementado).
- **Prod (EKS separado):** ambiente isolado, opcional e condicionado ao tempo restante após os requisitos; a promoção dev → prod reutiliza o mesmo digest de imagem testado, com aprovação explícita.
- **Staging:** trabalho futuro — ambiente semelhante à produção para testes de performance e outras validações.

## Executando em Kubernetes local (k3d)

A forma recomendada para rodar a aplicação é dentro de um cluster Kubernetes local
(k3d/k3s) — não há dependência de cloud, mas a experiência reflete um deploy real.

Se você nunca usou Kubernetes, siga o guia completo em
[`docs/local-kubernetes.md`](docs/local-kubernetes.md). Ele explica cada ferramenta,
como instalá-la e o que cada comando faz.

### Rápido (`make up`)

Pré-requisitos: [Docker](https://www.docker.com/), [k3d](https://k3d.io/),
`kubectl` e `make` instalados (instruções em
[`docs/local-kubernetes.md`](docs/local-kubernetes.md)).

```bash
make up
```

Esse comando cria o cluster, builda a imagem, faz o deploy e aguarda os pods
ficarem prontos. A aplicação fica em **http://localhost:8080**
(usuário: `admin` / senha: `admin`).

Outros comandos úteis:

| Comando | O que faz |
|---|---|
| `make status` | Mostra o estado dos pods e do ingress |
| `make logs` | Acompanha os logs da aplicação |
| `make health` | Testa o health check da aplicação (falha se a resposta não for HTTP 2xx) |
| `make restart` | Reinicia o Deployment (para pegar uma imagem reconstruída) |
| `make down` | Remove a aplicação do cluster (mantém o cluster) |
| `make destroy` | Destrói o cluster |
| `make clean` | Remove a aplicação e destrói o cluster |

### Conteúdo dos manifests (`k8s/`)

| Arquivo | Recurso |
|---|---|
| `namespace.yaml` | Namespace `todolist` |
| `configmap.yaml` | Variáveis públicas (APP_NAME, DB_HOST, etc.) |
| `secret.yaml` | Credenciais sensíveis (DB_PASSWORD, SESSION_KEY, etc.) |
| `postgres.yaml` | Deployment + Service + PVC do PostgreSQL |
| `rbac.yaml` | ServiceAccount + Role + RoleBinding (acesso à API K8s) |
| `deployment.yaml` | Deployment da aplicação (probes, limits, secrets) |
| `service.yaml` | Service ClusterIP da aplicação |
| `ingress.yaml` | Ingress local via Traefik, sem restrição de hostname (`localhost:8080`) |
| `cronjob.yaml` | CronJob de limpeza de tarefas concluídas |
| `hpa.yaml` | HorizontalPodAutoscaler (2–6 réplicas, CPU 60%) |

### Observações

- A imagem `postgres:16-alpine` é baixada do Docker Hub no primeiro deploy.
- Os valores em `secret.yaml` são para ambiente local **apenas** — não devem ser usados
  em produção. Em um cluster real, devem ser injetados via External Secrets Operator
  e AWS Secrets Manager.
- O HPA depende do `metrics-server` (incluído no k3s). Em cluster local com pouca
  carga, a métrica de CPU pode não ser exposta imediatamente; o HPA aguarda a
  primeira leitura antes de decidir a escala.
- A página `/pods` e `/cleanup/status` requerem as permissões definidas em
  `rbac.yaml`. Sem elas, a aplicação retorna uma mensagem amigável.

## Helm (AWS dev)

O chart em [`charts/todolist`](charts/todolist) empacota a aplicação para o ambiente `dev` na AWS
(EKS), com imagem por digest, credenciais via External Secrets Operator e Ingress ALB. O
desenvolvimento local continua usando os manifests em `k8s/` com `make up`. Detalhes, valores e
diferenças entre local e cloud estão em [`docs/helm-chart.md`](docs/helm-chart.md).
