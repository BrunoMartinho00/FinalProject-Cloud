# Projeto Final - Cloud Information Systems

**Autor:** Bruno Martinho a22400694
**Track:** Approach A (Reference Application)

## 1. Visão Geral
Este repositório contém a infraestrutura como código (IaC), pipelines de automação e o código-fonte de uma arquitetura *Cloud-Native* baseada em microsserviços. O sistema foi integralmente provisionado na Amazon Web Services (AWS) com foco em resiliência, segurança e automação contínua. 

O projeto adota a separação de responsabilidades (*Compute* vs. *Storage*), utilizando uma instância EC2 para orquestração de contentores (Docker) e um serviço gerido Amazon RDS para persistência relacional, com comunicação assíncrona orientada a eventos gerida por Apache Kafka.

### Tech Stack
* **Cloud Provider:** AWS (Custom VPC, EC2, RDS PostgreSQL, Internet Gateway)
* **Infrastructure as Code (IaC):** Terraform (Módulos e Remote State via S3)
* **Configuration Management:** Ansible
* **Containerização:** Docker & Docker Compose v2
* **CI/CD:** GitHub Actions (OpenID Connect - OIDC)
* **Camada Aplicacional:** Java 17, Spring Boot, Apache Kafka, Zookeeper

## 2. Organização do Repositório

O repositório está estruturado segundo as melhores práticas para separar o código aplicacional da gestão de infraestrutura:

```text
├── .github/workflows/   # Pipelines de CI/CD (Deploy automático e Destroy)
├── ansible/             # Playbooks e inventário para configuração da EC2
├── docs/                # Documentação técnica detalhada (Arquitetura, Segurança, etc.)
├── api-gateway/         # Reverse Proxy e ponto único de entrada público (Porta 80)
├── order-service/       # Microsserviço de orquestração de encomendas (Producer Kafka)
├── product-service/     # Microsserviço de catálogo e gestão de stock (Consumer Kafka)
├── user-service/        # Microsserviço de gestão de perfis e identidades de clientes
├── terraform/           # Código de provisionamento IaC (Módulos: vpc, compute, db, security)
├── docker-compose.yml   # Orquestração local e de produção dos contentores
└── README.md            # Este documento
```

## 3. Documentação Técnica

Toda a documentação exigida para a defesa do projeto encontra-se na pasta `docs/`. É fortemente recomendado seguir a ordem de leitura abaixo para uma compreensão total da topologia e das decisões de engenharia:

1. [**Arquitetura e Fluxo de Dados** (`docs/architecture.md`)](./docs/architecture.md)
2. [**Segurança e IAM** (`docs/security.md`)](./docs/security.md)
3. [**Guia de Configuração e Pré-requisitos** (`docs/setup.md`)](./docs/setup.md)
4. [**Guia de Deployment Passo-a-Passo** (`docs/deployment.md`)](./docs/deployment.md)
5. [**Limitações e Trabalhos Futuros** (`docs/limitations.md`)](./docs/limitations.md)

## 4. Como Executar e Testar

O processo de *deployment* é totalmente automatizado via GitHub Actions a cada *push* para a *branch* `main`. Para instruções sobre como fazer o *deploy* manualmente do zero, consulte o [Guia de Deployment](./docs/deployment.md).

Após o sistema estar online, o *API Gateway* fica acessível via HTTP na porta 80 da instância EC2. Pode testar o fluxo de comunicação síncrono e assíncrono (*Event-Driven*) utilizando os seguintes comandos no terminal:

**1. Criar um Utilizador:**
```bash
curl -X POST http://<EC2_PUBLIC_IP>/api/users \
-H "Content-Type: application/json" \
-d '{"name": "Bruno Martinho", "email": "bruno@ulht.pt"}'
```

**2. Adicionar um Produto ao Catálogo (com Stock Inicial):**
```bash
curl -X POST http://<EC2_PUBLIC_IP>/api/products \
-H "Content-Type: application/json" \
-d '{"name": "Kit Arduino ESP32", "description": "Kit IoT", "price": 45.99, "stockQuantity": 10}'
```

**3. Criar uma Encomenda (Despoleta evento Kafka para o Product Service):**
```bash
curl -X POST http://<EC2_PUBLIC_IP>/api/orders \
-H "Content-Type: application/json" \
-d '{
  "userId": 1,
  "items": [
    {
      "productId": 1,
      "quantity": 2
    }
  ]
}'
```
*Nota: A criação da encomenda atinge a base de dados do `order-service` de forma síncrona, e de seguida uma mensagem assíncrona é consumida pelo `product-service` via Kafka para subtrair a quantidade requerida ao stock global.*
