# Arquitetura do Sistema

## 1. Visão Geral
O projeto implementa uma arquitetura *Cloud-Native* baseada em microsserviços, aprovisionada integralmente na Amazon Web Services (AWS) através de *Infrastructure as Code* (Terraform). O design adota o padrão de separação de responsabilidades (*Compute* vs. *Storage*), com a camada aplicacional a correr em contentores Docker numa instância EC2, e a camada de persistência delegada para um serviço gerido (Amazon RDS) isolado da Internet pública.

## 2. Diagrama de Arquitetura

O diagrama abaixo ilustra a topologia da infraestrutura na Cloud, os limites de rede (VPC e Sub-redes) e o fluxo de comunicação entre os serviços.

```mermaid
architecture-beta
    group aws(cloud)[AWS Cloud - us-east-1]

    group vpc(cloud)[Custom VPC - 10.0.0.0/16] in aws
    
    group public_subnet(cloud)[Sub-rede Pública - 10.0.1.0/24] in vpc
    group private_subnet(cloud)[Sub-redes Privadas - 10.0.2.0/24 e 10.0.3.0/24] in vpc

    service igw(internet)[Internet Gateway] in vpc
    
    service ec2(server)[EC2 t3.small] in public_subnet
    service rds(database)[RDS PostgreSQL] in private_subnet

    igw:L -- R:ec2
    ec2:R -- L:rds
```

*Nota: O tráfego externo entra via Internet Gateway, atingindo o API Gateway na EC2 (Sub-rede Pública). A EC2 comunica internamente com a Base de Dados (Sub-rede Privada).*

## 3. Componentes da Infraestrutura AWS

A infraestrutura foi desenhada com foco na segurança e otimização de recursos (Tiering), sendo composta pelos seguintes módulos principais:

* **Networking (VPC Customizada):** * Bloco CIDR `10.0.0.0/16`.
  * **Sub-rede Pública** (`10.0.1.0/24`): Alojamento do nó de computação (EC2) com roteamento para a Internet via Internet Gateway.
  * **Sub-redes Privadas** (`10.0.2.0/24` e `10.0.3.0/24`): Alojamento do DB Subnet Group para o RDS, garantindo que a base de dados não possui endereçamento IP público.
* **Segurança (Security Groups):**
  * `web_sg`: Permite tráfego de entrada HTTP (Porta 80) e SSH (Porta 22) globalmente (`0.0.0.0/0`).
  * `db_sg`: Restringe o acesso à porta `5432` (PostgreSQL) **exclusivamente** à origem do `web_sg`, bloqueando qualquer tentativa de acesso direto.
* **Compute (EC2):**
  * Instância `t3.small` (2 vCPUs, 2 GB RAM) a correr Ubuntu 22.04 LTS.
  * Otimização de memória com alocação estática de um volume de *Swap* de 2GB.
  * Orquestração local assegurada por Docker Engine e Docker Compose v2.
* **Persistência (RDS):**
  * Instância gerida `db.t3.micro` a correr PostgreSQL 15.
  * Integração orientada a microsserviços com o dialeto *Hibernate* otimizado via variáveis de ambiente.

## 4. Arquitetura Aplicacional e Fluxo de Dados

A aplicação (Java 17 / Spring Boot) adota um modelo distribuído e orientado a eventos. A superfície de ataque é minimizada expondo apenas o API Gateway à rede do *host*.

### 4.1. Microsserviços
| Componente | Tipo de Exposição | Responsabilidade |
| :--- | :--- | :--- |
| **API Gateway** | Externa (`0.0.0.0:80`) | *Reverse Proxy*, roteamento de pedidos HTTP e *Load Balancing* interno. |
| **User Service** | Interna (Docker Bridge) | Gestão de perfis e identidades de clientes. |
| **Product Service** | Interna (Docker Bridge) | Gestão de catálogo e stock de produtos. |
| **Order Service** | Interna (Docker Bridge) | Orquestração de compras e faturação. |

### 4.2. Comunicação Assíncrona (Event-Driven)
A comunicação síncrona HTTP é limitada ao contacto inicial via API Gateway. Para garantir o desacoplamento temporal e resiliência entre o serviço de encomendas e o serviço de inventário, foi implementado o **Apache Kafka** (apoiado pelo Zookeeper).
* **Fluxo:** Quando uma encomenda é criada no `order-service`, um evento é publicado num tópico Kafka. O `product-service` atua como consumidor desse tópico, efetuando o débito do stock (validação assíncrona) sem bloquear a resposta ao cliente.

## 5. Decisões Arquiteturais e Trade-offs

* **EC2 como Docker Host vs. ECS/Fargate:** Optou-se por concentrar os contentores numa única instância EC2 orquestrada via `docker-compose`. Embora ferramentas nativas como o AWS ECS Fargate ofereçam melhor escalabilidade horizontal e eliminem a gestão do SO, a solução atual foi escolhida para otimizar os custos rigorosos e manter o controlo simplificado da topologia via Ansible.
* **Gestão de Estado Remoto:** O *state file* do Terraform foi migrado para um *S3 Bucket*. Esta decisão permite a idempotência do pipeline de CI/CD (GitHub Actions), evitando colisões na recriação da infraestrutura.
* **Limitações de Memória vs. Swap:** O bloqueio inicial da instância por exaustão de memória (OOM Killer provocado pelo arranque paralelo de múltiplas JVMs e do Kafka) foi mitigado através de um *upgrade* para `t3.small` associado à criação de 2GB de *Swap space*. Este trade-off sacrifica uma fração mínima de performance de I/O em prol da estabilidade estrutural do sistema em cenários de picos de carga de inicialização.