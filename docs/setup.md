# Guia de Configuração e Pré-requisitos (Setup)

Este documento descreve todos os pré-requisitos locais e configurações na nuvem necessários para provisionar e executar este projeto de infraestrutura e microsserviços.

## 1. Pré-requisitos Locais (Local Toolchain)

Para interagir com a infraestrutura e testar a aplicação localmente, a máquina de desenvolvimento (ex: ambiente Linux/Ubuntu/Pop!_OS) deve ter as seguintes ferramentas instaladas:

* **Git:** Para controlo de versão e clonagem do repositório.
* **AWS CLI v2:** Para interação manual com a conta AWS e configuração de credenciais.
* **Terraform (v1.9+):** Para provisionamento da infraestrutura (*Infrastructure as Code*).
* **Ansible:** Para gestão de configuração e execução do *playbook* na EC2.
* **Docker & Docker Compose:** Para testes locais dos microsserviços e do ecossistema Kafka.
* **Java 17 & Maven:** (Opcional) Apenas necessário para compilar os ficheiros `.jar` localmente antes de sincronizar para o servidor.

## 2. Pré-requisitos AWS (Cloud Setup)

Antes de executar qualquer automação, é necessário preparar o terreno na consola da AWS (região `us-east-1`):

### 2.1. Credenciais e Acesso (IAM)
* Criar um utilizador IAM (ou Role) com permissões programáticas (Access Key / Secret Key) ou configurar o **OIDC (OpenID Connect)** para permitir que o GitHub Actions comunique com a AWS sem chaves estáticas.

### 2.2. Estado Remoto do Terraform (Remote State)
Para garantir que a infraestrutura pode ser gerida por múltiplos ambientes e pelo pipeline CI/CD de forma idempotente, o ficheiro de estado não é guardado localmente.
* Criar um **S3 Bucket** (ex: `bruno-finalproject-tfstate-123`) na região `us-east-1` para armazenar o `terraform.tfstate`.

### 2.3. Par de Chaves SSH (Key Pair)
* Criar um par de chaves EC2 (formato `.pem`) na região `us-east-1` chamado `projeto-final-key`.
* Fazer o download do ficheiro `projeto-final-key.pem` e colocá-lo na pasta `terraform/` do repositório local.
* Garantir permissões de leitura estritas (necessário em sistemas Linux/macOS):
  ```bash
  chmod 400 terraform/projeto-final-key.pem
  ```

## 3. Configuração do Repositório (GitHub Actions)

Para que o pipeline de CI/CD automatizado funcione de forma segura, é estritamente obrigatório configurar os seguintes **Repository Secrets** no GitHub (`Settings > Secrets and variables > Actions`):

| Nome do Secret | Descrição |
| :--- | :--- |
| `AWS_ACCESS_KEY_ID` | Chave de acesso do utilizador IAM (se não usar OIDC). |
| `AWS_SECRET_ACCESS_KEY` | Chave secreta do utilizador IAM (se não usar OIDC). |
| `AWS_ROLE_TO_ASSUME` | ARN da Role IAM (caso utilize autenticação OIDC). |
| `DB_USERNAME` | O nome de utilizador *master* pretendido para a base de dados PostgreSQL. |
| `DB_PASSWORD` | A password segura para a base de dados (injetada dinamicamente via pipeline). |

## 4. Clonar e Iniciar o Projeto Localmente

Após validar todos os pré-requisitos acima, o ambiente está pronto para ser iniciado:

```bash
# 1. Clonar o repositório
git clone <URL_DO_REPOSITORIO>
cd <NOME_DA_PASTA>

# 2. Configurar credenciais AWS localmente (caso não use SSO)
aws configure

# 3. Validar a sintaxe e inicializar o Terraform
cd terraform
terraform fmt -recursive
terraform init
```

Para prosseguir com o levantamento da infraestrutura e deploy da aplicação, consultar o ficheiro **`docs/deployment.md`**.