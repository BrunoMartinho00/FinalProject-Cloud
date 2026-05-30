# Documentação Técnica e Arquitetural - Projeto Final Cloud

## 1. Visão Geral da Infraestrutura

O ambiente de produção foi aprovisionado na Amazon Web Services (AWS) adotando uma arquitetura de microsserviços. A camada de computação é assegurada por uma instância EC2 a correr Ubuntu 22.04 LTS, operando como um *host* Docker. A camada de persistência de dados foi delegada para um serviço gerido, o Amazon RDS (PostgreSQL), garantindo separação de responsabilidades (Compute vs. Storage) e maior resiliência.

### Especificações Técnicas Atuais
* **Compute:** Instância AWS EC2 `t3.micro` (2 vCPUs, 1 GB RAM física).
* **Networking (VPC):** `vpc-07b98ad6cecd321b8` alocada na sub-rede pública `subnet-08c5a016ccb7bca7f` (us-east-1a).
* **Endereçamento:** Elastic IP Público estático (`52.201.94.165`).
* **Storage/Memória Virtual:** 8 GB EBS (Root Volume) + 2 GB Swap File (Alocação manual).
* **Orquestração:** Docker Engine com Docker Compose v2.

---

## 2. Diário de Bordo: Desafios, Diagnósticos e Resoluções

Durante a fase de *deployment* e integração contínua, foram identificados e mitigados três bloqueios arquiteturais críticos. Abaixo detalha-se a análise de causa raiz (Root Cause Analysis) para cada incidente.

### 2.1. Isolamento de Rede e Alocação Dinâmica CGNAT
**Descrição do Incidente:**
Após uma interrupção intencional da instância EC2 (*Stop/Start*) para otimização de custos, o servidor ficou inacessível via SSH (Porta 22) e deixou de responder a pacotes ICMP (Ping), resultando em 100% *packet loss*.

**Diagnóstico (Root Cause Analysis):**
Na AWS, instâncias lançadas sem um Elastic IP perdem o seu endereço IPv4 público aquando do encerramento. No reinício, a infraestrutura da AWS atribuiu um endereço IP interno da gama *Carrier-Grade NAT* (`100.55.6.211`). Este IP pertence a um espaço de endereçamento partilhado usado pela AWS para colmatar a escassez de IPv4 e não é diretamente roteável a partir da Internet pública. Adicionalmente, verificou-se a integridade das *Route Tables* da VPC.

**Resolução Técnica:**
1. Provisionamento de um **Elastic IP** e associação direta à interface de rede (ENI) da instância `i-04d27c7969046909d`.
2. Validação da *Route Table* associada à sub-rede pública (`rtb-09a4b8753a5a1e303`).
3. Confirmação da existência da rota `0.0.0.0/0` apontada para o *Internet Gateway* (`igw`), garantindo a capacidade de tráfego bidirecional.

### 2.2. Exaustão de Recursos de Hardware (OOM Killer)
**Descrição do Incidente:**
A execução do comando de orquestração `docker-compose up -d` resultava num congelamento global do Sistema Operativo convidado (Ubuntu). O *daemon* do SSH era terminado abruptamente e a instância tornava-se inoperável, exigindo um *Hard Reboot* via consola AWS.

**Diagnóstico (Root Cause Analysis):**
A instância `t3.micro` dispõe de apenas 1 GB de memória RAM física. A arquitetura da aplicação exige a inicialização concorrente de quatro microsserviços baseados em Java 17 e Spring Boot (`api-gateway`, `user-service`, `product-service`, `order-service`). A *Java Virtual Machine* (JVM), ao inicializar o ecossistema Spring (incluindo o Tomcat embebido e o contexto JPA/Hibernate), aloca agressivamente memória. A soma das reservas de memória excedeu a RAM física disponível. O *kernel* do Linux, como mecanismo de autodefesa, invocou o **Out-Of-Memory (OOM) Killer**, terminando os processos mais pesados, incluindo o próprio `sshd` e o `dockerd`.

**Resolução Técnica:**
Como a infraestrutura AWS em modo *Free Tier* restringe o *upgrade* para instâncias com mais RAM (ex: `t3.small`), a solução incidiu na gestão de memória do Sistema Operativo, criando espaço de paginação (*Swap Space*).

```bash
# Criação de um bloco contíguo de 2GB no disco EBS
sudo fallocate -l 2G /swapfile

# Configuração de permissões estritas por motivos de segurança
sudo chmod 600 /swapfile

# Formatação e ativação do espaço de paginação
sudo mkswap /swapfile
sudo swapon /swapfile
```
Esta intervenção permitiu que o *kernel* transferisse páginas de memória inativas (como processos em *background*) para o disco SSD, libertando a RAM física crucial para a inicialização das JVMs.

### 2.3. Conflito de Dialeto ORM e Conectividade JDBC
**Descrição do Incidente:**
Com a memória estabilizada, os contentores iniciaram, contudo o `user-service` e o `product-service` falhavam sistematicamente (código de saída Docker `Exited 1`). Os logs expuseram a exceção: `java.lang.RuntimeException: Driver org.h2.Driver claims to not accept jdbcUrl, jdbc:postgresql://...`

**Diagnóstico (Root Cause Analysis):**
Apesar de a conexão de rede TCP entre a instância EC2 e a base de dados AWS RDS na porta `5432` ter sido validada com sucesso através do utilitário `netcat` (`nc -zv`), a camada de persistência (*Hibernate*) estava mal configurada. Sem instruções explícitas, o Spring Boot ativou o perfil de *fallback* para a base de dados em memória (H2), cujo *driver* não é capaz de interpretar o protocolo `jdbc:postgresql://`.

**Resolução Técnica:**
Foi necessário aplicar o padrão *12-Factor App*, externalizando as configurações de ambiente para o ficheiro de orquestração do Docker, anulando as predefinições locais compiladas no `.jar`.

As variáveis de ambiente injetadas no `docker-compose.yml` foram:
| Variável de Ambiente | Valor Atribuído | Propósito |
| :--- | :--- | :--- |
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://<rds-endpoint>:5432/postgres` | Endpoint remoto da base de dados. |
| `SPRING_DATASOURCE_DRIVER_CLASS_NAME` | `org.postgresql.Driver` | Força a utilização do driver nativo do Postgres. |
| `SPRING_JPA_DATABASE_PLATFORM` | `org.hibernate.dialect.PostgreSQLDialect` | Instrui o Hibernate sobre o dialeto SQL a gerar. |

Após a reconstrução das imagens (`docker-compose up --build -d`), os serviços estabeleceram com sucesso o *pool* de conexões (HikariCP) com a base de dados RDS.

---

## 3. Topologia e Port Map do Ambiente Operacional

A infraestrutura foi desenhada para limitar a superfície de ataque. Apenas o API Gateway tem exposição pública na porta 80, atuando como *Reverse Proxy* e *Load Balancer* interno para os restantes microsserviços.

| Contentor / Serviço | Runtime | Bind Mount (Host:Container) | Rede Docker |
| :--- | :--- | :--- | :--- |
| **app_api-gateway_1** | Java 17 | `0.0.0.0:80 -> 8080/tcp` | `app_default` |
| **app_user-service_1** | Java 17 | N/A (Apenas interno 8080) | `app_default` |
| **app_product-service_1** | Java 17 | N/A (Apenas interno 8080) | `app_default` |
| **app_order-service_1** | Java 17 | N/A (Apenas interno 8080) | `app_default` |

---

## 4. Pipeline de Sincronização de Código (Deployment)

Para a entrega contínua do código local para o ambiente de produção, estabeleceu-se um fluxo baseado em SSH e sincronização diferencial (`rsync`), otimizando a largura de banda e o tempo de *deploy*.

```bash
# 1. Empacotamento local (Build)
mvn clean package -DskipTests

# 2. Sincronização diferencial para a Cloud
rsync -av -e "ssh -i terraform/projeto-final-key.pem" \
--exclude='.git' --exclude='.terraform' --exclude='*.pem' \
./ ubuntu@52.201.94.165:/home/ubuntu/app/

# 3. Recreação da infraestrutura (Rolling Update)
cd /home/ubuntu/app
sudo docker-compose down
sudo docker-compose up --build -d
```


------------------

Este repositório contém a infraestrutura e o código aplicacional para uma arquitetura de microsserviços na Cloud (AWS), cumprindo os requisitos da "Approach A - Reference Application Track".

## 1. Estado Atual e Requisitos Implementados

Até ao momento, o núcleo central da infraestrutura e da aplicação está 100% operacional, cobrindo os seguintes requisitos obrigatórios:

* **Cloud Infrastructure (Req. 1):** Implementação de uma VPC customizada na AWS, subnets e Security Groups.
* **Infrastructure as Code (Req. 2):** Todo o provisionamento (EC2 `t3.micro` e base de dados RDS PostgreSQL) está automatizado via Terraform.
* **Containerization (Req. 3):** Os serviços e a infraestrutura de mensageria correm em contentores Docker via `docker-compose`.
* **Distributed Architecture (Req. 4):** Arquitetura distribuída composta por um API Gateway e 3 microsserviços Java Spring Boot (User, Product, Order).
* **Event-Driven Communication (Req. 5):** Integração do ecossistema Kafka (com Zookeeper) para comunicação assíncrona entre o `order-service` e o `product-service`.
* **Persistence Layer (Req. 6):** Base de dados AWS RDS (PostgreSQL) centralizada na cloud.
* **Configuration Management (Req. 7):** Utilização do Ansible para instalação de dependências (Docker), configuração de Swap na EC2 e arranque automático da aplicação.

## 2. Principais Dificuldades e Soluções

Durante o desenvolvimento e integração, foram ultrapassados vários desafios de engenharia, típicos de sistemas distribuídos:

1. **O "Abraço da Morte" da Memória (Limitações do AWS Free Tier):**
   * *Problema:* A instância `t3.micro` possui apenas 1GB de RAM. O arranque simultâneo de 4 aplicações Java, Kafka e Zookeeper esgotava a memória e bloqueava o servidor (*Connection refused* / quebra de SSH).
   * *Solução:* Implementação de limites rigorosos de memória diretamente no `docker-compose.yml`. Foi injetada a variável `JAVA_OPTS=-Xms128m -Xmx256m` nos microsserviços e `KAFKA_HEAP_OPTS=-Xmx256M -Xms128M` no Kafka, garantindo estabilidade na máquina.
2. **Falha no Build Local do Docker:**
   * *Problema:* O Docker Compose tentava descarregar imagens inexistentes do Docker Hub (erro `pull access denied`) em vez de compilar o código fonte local.
   * *Solução:* Adição da diretiva `build: context: ./<serviço>` e `dockerfile: Dockerfile` a cada serviço no ficheiro compose.
3. **Bloqueio de Firewall após *Rebuild*:**
   * *Problema:* Ao aplicar o princípio de infraestrutura imutável (destruir e recriar o ambiente com o Terraform), a nova base de dados RDS rejeitava conexões da nova instância EC2.
   * *Solução:* Processo manual (a automatizar futuramente) de atualização das *Inbound rules* do Security Group da RDS na consola da AWS, permitindo a porta `5432` para o novo IP público `/32` da EC2.
4. **Incompatibilidade do Modelo de Dados (Efeito Dominó):**
   * *Problema:* O teste de criação de encomenda falhava porque o produto estava sem stock. Isto devia-se ao facto do JSON enviado usar a chave `"stock"`, enquanto a classe Java esperava `"stockQuantity"`.
   * *Solução:* Correção do *payload* de teste, provando que a validação inter-serviços e a mensageria do Kafka estavam ativas e a funcionar corretamente.

## 3. Como Iniciar e Testar o Projeto

### Pré-requisitos
* AWS CLI configurada localmente.
* Terraform e Ansible instalados.
* Chave SSH `projeto-final-key.pem` gerada e acessível.

### Passo 1: Subir a Infraestrutura (Terraform)
Na pasta `terraform`, executar:
```bash
terraform init
terraform apply
```
*Anotar os outputs gerados: `ec2_public_ip` e `rds_endpoint`.*

### Passo 2: Configurar Ligações Locais
1. No ficheiro `docker-compose.yml` (raiz), atualizar a variável `SPRING_DATASOURCE_URL` com o novo *endpoint* do RDS.
2. No ficheiro `ansible/inventory.ini`, substituir o IP alvo pelo novo `ec2_public_ip`.

### Passo 3: Abrir a Firewall da Base de Dados
Na consola da AWS (RDS > Security Groups), adicionar uma regra *Inbound* do tipo PostgreSQL para o IP da nova EC2 (`<EC2_IP>/32`).

### Passo 4: Fazer o Deploy (Ansible)
Na pasta `ansible`, executar:
```bash
ansible-playbook -i inventory.ini playbook.yml
```
*Aguardar 1 a 2 minutos após o final da execução para permitir o arranque completo da JVM (devido aos limites de RAM).*

### Passo 5: Testar o Fluxo (Event-Driven)
Executar os seguintes comandos no terminal para validar o ciclo completo da aplicação:

**1. Criar Utilizador:**
```bash
curl -X POST http://<EC2_IP>/api/users \
-H "Content-Type: application/json" \
-d '{"name": "Bruno Martinho", "email": "bruno@ulht.pt"}'
```

**2. Criar Produto (com Stock):**
```bash
curl -X POST http://<EC2_IP>/api/products \
-H "Content-Type: application/json" \
-d '{"name": "Kit Arduino ESP32", "description": "Kit IoT", "price": 45.99, "stockQuantity": 10}'
```

**3. Criar Encomenda (Dispara evento no Kafka):**
```bash
curl -X POST http://<EC2_IP>/api/orders \
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

## 4. Trabalhos Futuros / O que falta
Para a conclusão total do projeto, falta implementar:
* **Automação de CI/CD (Req. 8):** Criação dos *workflows* no GitHub Actions para substituição da execução manual do Terraform e Ansible.
* **Segurança de Credenciais (Req. 9):** Remoção da password em *plain text* da base de dados e passagem para variáveis de ambiente injetadas no momento do *deploy*.