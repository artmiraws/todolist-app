# Rodando a aplicação em Kubernetes local

Guia completo para rodar a aplicação TodoList em um cluster Kubernetes local,
do zero — sem experiência prévia com Kubernetes.

---

## 1. O que você vai precisar

| Ferramenta | O que é | Por que precisa |
|---|---|---|
| **Git** | Sistema de controle de versão | Clonar este repositório |
| **Docker** | Plataforma para rodar aplicações em contêineres | O cluster k8s e a aplicação rodam como contêineres |
| **k3d** | Kubernetes leve rodando dentro do Docker | Cria um cluster k8s local sem instalar nada no sistema |
| **kubectl** | CLI para conversar com o cluster k8s | Gerencia os recursos (deploy, pods, serviços) dentro do cluster |
| **make** | Ferramenta de automação | Executa os comandos do `Makefile` (`make up`, `make down`, etc.) |

> As instruções foram validadas em Linux (Ubuntu). Os passos para macOS e Windows
> estão incluídos como referência, mas não foram testados.

---

## 2. Instalando as ferramentas

### 2.1. Docker

O Docker é a base de tudo. Sem ele, nada funciona.

**Linux (Ubuntu/Debian):**
```bash
# Instalar Docker
curl -fsSL https://get.docker.com | sh

# Adicionar seu usuário ao grupo docker (para não precisar de sudo)
sudo usermod -aG docker $USER

# Sair e entrar novamente no terminal para o grupo ter efeito
```

**macOS:**
- Baixe o [Docker Desktop](https://www.docker.com/products/docker-desktop/) e instale normalmente.

**Windows:**
- Baixe o [Docker Desktop](https://www.docker.com/products/docker-desktop/) e instale.
- Ative o WSL2 quando solicitado durante a instalação.

**Verificar se funciona:**
```bash
docker --version
docker run --rm hello-world
```

Se o segundo comando mostrar "Hello from Docker!", está tudo certo.

---

### 2.2. k3d

O k3d cria um cluster Kubernetes completo (k3s) dentro de um contêiner Docker —
não instala nada fora do Docker, não precisa de root, e pode ser criado/destruído
em segundos.

**Linux e macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.8.3 bash
```

> Se o comando acima pedir senha (sudo), significa que o script não conseguiu
> instalar em `/usr/local/bin`. Nesse caso, baixe o binário manualmente:
> ```bash
> mkdir -p ~/.local/bin
> curl -sSL -o ~/.local/bin/k3d https://github.com/k3d-io/k3d/releases/download/v5.8.3/k3d-linux-amd64
> chmod +x ~/.local/bin/k3d
> # Adicione ~/.local/bin ao PATH se ainda não estiver:
> echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
> source ~/.bashrc
> ```
> No macOS, substitua `k3d-linux-amd64` por `k3d-darwin-amd64`.

**Windows:**
```powershell
# No PowerShell (como administrador):
curl -sSL -o ~/.local/bin/k3d.exe https://github.com/k3d-io/k3d/releases/download/v5.8.3/k3d-windows-amd64.exe
```

**Verificar:**
```bash
k3d version
```

---

### 2.3. kubectl

O k3d **não** instala o `kubectl` na sua máquina. O binário existe dentro do
contêiner do k3s, mas para gerenciar o cluster a partir do host é preciso
instalar o `kubectl` separadamente:

**Linux e macOS:**
```bash
curl -sLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Windows (PowerShell):**
```powershell
curl -sLO "https://dl.k8s.io/release/v1.31.0/bin/windows/amd64/kubectl.exe"
Move-Item kubectl.exe ~/.local/bin/kubectl.exe
```

**Verificar:**
```bash
kubectl version --client
```

---

### 2.4. Git e make

O Git é necessário para clonar o repositório e o `make` para executar os comandos
do `Makefile`.

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install -y git make
```

**macOS:**
```bash
# O make faz parte das Command Line Tools do Xcode:
xcode-select --install
# O Git normalmente já vem instalado; caso contrário:
brew install git
```

**Verificar:**
```bash
git --version
make --version
```

---

## 3. Rodando a aplicação

### 3.1. Tudo de uma vez (Makefile)

O repositório inclui um `Makefile` que automatiza todo o processo.
Execute **um único comando** para criar o cluster, buildar a imagem e
fazer o deploy:

```bash
make up
```

Esse comando vai:
1. Criar um cluster k3d local (se não existir)
2. Buildar a imagem Docker da aplicação
3. Importar a imagem para dentro do cluster
4. Aplicar todos os manifests k8s (namespace, banco, app, RBAC, etc.)
5. Aguardar os pods ficarem prontos

Depois, acesse: **http://localhost:8080**
(usuário: `admin` / senha: `admin`)

---

### 3.2. Passo a passo manual

Se preferir entender cada etapa:

```bash
# 1. Criar o cluster k3s dentro do Docker
#    --agents 1 = 1 node worker extra (além do server)
#    --port 8080:80 = mapeia a porta 80 do Traefik (ingress) para 8080 na sua máquina
k3d cluster create todolist --agents 1 --port "8080:80@loadbalancer"

# 2. Buildar a imagem Docker da aplicação (multi-stage Dockerfile)
docker build -t todolist-app:local .

# 3. Importar a imagem para dentro do cluster
#    (sem isso, os nodes k3d não conseguem puxar a imagem)
k3d image import todolist-app:local -c todolist

# 4. Aplicar os manifests Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/rbac.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/cronjob.yaml
kubectl apply -f k8s/hpa.yaml

# 5. Aguardar o PostgreSQL ficar pronto
kubectl -n todolist rollout status deploy/postgres

# 6. Aguardar a aplicação ficar pronta
kubectl -n todolist rollout status deploy/todolist-app

# 7. Acessar no navegador
#    http://localhost:8080
```

---

## 4. Comandos úteis do Makefile

| Comando | O que faz |
|---|---|
| `make up` | Cria cluster + build + import + deploy (tudo de uma vez) |
| `make down` | Remove todos os recursos do cluster (sem destruir o cluster) |
| `make destroy` | Destrói o cluster completamente |
| `make clean` | Remove recursos + destrói o cluster (ambiente limpo) |
| `make build` | Apenas builda a imagem Docker |
| `make import` | Apenas importa a imagem para o cluster |
| `make status` | Mostra o estado dos pods e deploys |
| `make logs` | Mostra os logs da aplicação em tempo real |
| `make health` | Testa o endpoint de health da aplicação (falha se a resposta não for HTTP 2xx) |
| `make pf` | Port-forward como alternativa ao ingress (acesso via `localhost:5000`) |
| `make restart` | Reinicia o Deployment da aplicação (para pegar uma imagem reconstruída) |

Os comandos que usam `kubectl` verificam se o contexto atual é `k3d-todolist`
(`k3d-<nome-do-cluster>`) antes de executar, para não alterar outro cluster por
engano. Para trocar manualmente: `kubectl config use-context k3d-todolist`.

Como a imagem local usa a tag fixa `todolist-app:local`, reconstruir a imagem e
rodar `make up` de novo não reinicia os pods (a tag não mudou). Depois de
`make build && make import`, rode `make restart` para o Deployment pegar a nova
imagem.

---

## 5. Sobre a aplicação

### Login

- **Usuário:** `admin`
- **Senha:** `admin`
- Valores definidos em `k8s/secret.yaml`. Não são seguros para produção.

### Funcionalidades

| Rota | O que faz |
|---|---|
| `/` | Lista de tarefas (precisa estar logado) |
| `/add` | Adiciona uma tarefa |
| `/toggle/<id>` | Marca/desmarca uma tarefa como concluída |
| `/delete/<id>` | Remove uma tarefa |
| `/pods` | Lista os pods do namespace (requer RBAC — já configurado) |
| `/cleanup` | Remove tarefas concluídas (requer token no header `X-Cleanup-Token`) |
| `/cleanup/status` | Histórico das execuções de limpeza + pausar/retomar o CronJob |
| `/healthz` | Health check (retorna `ok` se o banco estiver acessível) |

### Variáveis de ambiente

A aplicação lê configuração de dois lugares, nesta ordem:
1. **Arquivos** em `/var/run/secrets/todolist/` (montados como volume k8s Secret)
2. **Variáveis de ambiente** (fallback)

Isso significa que, no cluster, as credenciais ficam no objeto Secret do Kubernetes,
não expostas em variáveis de ambiente dos pods.

### Sessões

A aplicação usa **sessões Flask**, armazenadas em um cookie assinado com HMAC no
navegador — não na memória do pod. A chave que assina o cookie (`SESSION_KEY`) é
definida em `k8s/secret.yaml`. Como o cookie é do lado do cliente, o login
sobrevive a reinícios dos pods enquanto a `SESSION_KEY` não mudar; trocar a chave
invalida as sessões existentes.

### Banco de dados

- PostgreSQL 16 (Alpine) rodando como Deployment no namespace `todolist`
- Dados persistidos em um PersistentVolumeClaim (`postgres-data`, 500Mi)
- O schema é criado automaticamente pela aplicação na inicialização (`db.create_all()`)

### CronJob de limpeza

Um CronJob (`cleanup`) roda a cada 5 minutos e chama o endpoint `POST /cleanup`
para remover tarefas concluídas. O histórico pode ser visto em `/cleanup/status`,
onde é possível pausar e retomar o agendamento.

---

## 6. Solução de problemas

### O pod da aplicação não fica pronto (CrashLoopBackOff)

**Causa mais comum:** o PostgreSQL ainda não está pronto.
```bash
# Verificar status do PostgreSQL
kubectl -n todolist get pods
kubectl -n todolist logs deploy/postgres

# Verificar logs da aplicação
kubectl -n todolist logs -l app=todolist-app --tail=20
```

Espere até que o pod do PostgreSQL mostre `1/1 Running` antes de investigar
problemas na aplicação.

### Não consigo acessar http://localhost:8080

```bash
# Verificar se o ingress está configurado
kubectl -n todolist get ingress

# Verificar se o Traefik está rodando
kubectl -n kube-system get pods | grep traefik

# Testar com curl (o ingress não restringe hostname, então não é preciso header Host)
curl -fsS http://localhost:8080/healthz
```

Se o ingress estiver OK mas o browser não acessa, tente:
- Abrir `http://localhost:8080/login` diretamente
- Verificar se outro processo não está usando a porta 8080

### A página /pods mostra "Unable to query the Kubernetes API"

O ServiceAccount não tem permissões. Verifique:
```bash
kubectl -n todolist get rolebinding todolist-app -o yaml
kubectl -n todolist get sa todolist-app -o yaml
```

### HPA não funciona (FailedComputeMetricsReplicas)

O `metrics-server` precisa de tempo para coletar métricas. Em cluster local
com pouca carga, pode levar alguns minutos. Verifique:
```bash
kubectl top nodes
kubectl -n todolist get hpa
```

---

## 7. Estrutura dos arquivos

```
todolist-app/
├── Dockerfile          # Build multi-stage (builder + runtime)
├── .dockerignore       # Arquivos ignorados no build
├── app.py              # Código da aplicação Flask
├── requirements.txt    # Dependências Python
├── Makefile            # Comandos de automação
├── README.md           # Documentação geral
├── docs/
│   ├── local-kubernetes.md   # Este guia
│   └── PLAN.md               # Plano do desafio DevOps
└── k8s/
    ├── namespace.yaml    # Namespace todolist
    ├── configmap.yaml    # Configuração pública da app
    ├── secret.yaml       # Credenciais sensíveis
    ├── postgres.yaml     # PostgreSQL (Deployment + Service + PVC)
    ├── rbac.yaml         # ServiceAccount + Role + RoleBinding
    ├── deployment.yaml   # Deployment da aplicação
    ├── service.yaml      # Service ClusterIP
    ├── ingress.yaml      # Ingress via Traefik
    ├── cronjob.yaml      # CronJob de limpeza
    └── hpa.yaml          # HorizontalPodAutoscaler
```