# Limitações e Trabalhos Futuros (Roadmap)

Este documento descreve as limitações arquiteturais conhecidas da atual infraestrutura e estabelece um *roadmap* para futuras melhorias, focando-se em resiliência, escalabilidade e observabilidade. Muitas destas limitações resultam de *trade-offs* conscientes para manter o projeto dentro dos limites do **AWS Free Tier** e do tempo de desenvolvimento estipulado.

## 1. Limitações Arquiteturais Conhecidas

### 1.1. Single Point of Failure (SPOF) e Escalabilidade
* **Limitação:** A arquitetura baseia-se num único nó de computação (Instância EC2 `t3.small`) que atua simultaneamente como *host* de todos os microsserviços, API Gateway, Kafka e Zookeeper. Se esta instância falhar (ou a *Availability Zone* `us-east-1a` ficar indisponível), o sistema sofre uma interrupção total (Downtime).
* **Ausência de Auto Scaling:** Não existe um *Auto Scaling Group* (ASG) configurado. O sistema não consegue escalar horizontalmente em resposta a picos de tráfego.

### 1.2. Gestão de Memória e Sobrecarga de I/O
* **Limitação:** O arranque simultâneo de quatro *Java Virtual Machines* (JVMs) e do ecossistema Apache Kafka excede a memória física disponível na instância `t3.small` (2 GB).
* **Trade-off:** Foi alocado um volume de *Swap* de 2 GB no disco EBS para evitar que o *kernel* (OOM Killer) terminasse os processos críticos. Contudo, a paginação intensiva para o disco SSD reduz a performance de I/O e aumenta a latência geral da aplicação.

### 1.3. Orquestração de Contentores
* **Limitação:** O uso de `docker-compose` é excelente para ambientes de desenvolvimento ou infraestruturas simples, mas carece de funcionalidades avançadas de *self-healing* (substituição automática de contentores mortos), *service discovery* e gestão de *secrets* nativa.

## 2. Dívida Técnica de Segurança (Security Debt)

* **Exposição da Porta SSH:** Para permitir que o GitHub Actions execute o *playbook* do Ansible, a porta 22 (SSH) do *Security Group* público foi mantida aberta globalmente (`0.0.0.0/0`). Numa infraestrutura de produção rigorosa, isto representa um risco desnecessário.
* **Injeção de Segredos:** Embora os segredos já não estejam *hardcoded* no código-fonte, o Ansible escreve um ficheiro `.env` em texto limpo no disco da instância EC2.

## 3. Roadmap e Próximos Passos (Future Improvements)

Para elevar a infraestrutura a um padrão *Enterprise/Production-Ready*, o roadmap arquitetural focar-se-ia nas seguintes implementações:

### FASE 1: Managed Services e Redução de Carga
* **Migração do Kafka para AWS SQS / SNS:** A manutenção de um cluster Kafka + Zookeeper consome demasiada RAM. [cite_start]A substituição pela infraestrutura gerida de mensageria assíncrona nativa da AWS (Amazon SQS) [cite: 316, 317] [cite_start]eliminaria o peso computacional da EC2 e aumentaria a resiliência das filas de mensagens com o uso de *Dead-Letter Queues* (DLQ)[cite: 320].
* [cite_start]**AWS Secrets Manager:** Integração nativa da aplicação com o AWS Secrets Manager [cite: 399, 501] [cite_start]para obtenção da password da base de dados em *runtime*, permitindo rotação automática e eliminando o ficheiro `.env`[cite: 504].

### FASE 2: Resiliência e Escalabilidade (Multi-AZ)
* [cite_start]**Application Load Balancer (ALB):** Colocação de um ALB nas sub-redes públicas para distribuir tráfego[cite: 485].
* [cite_start]**Auto Scaling Group (ASG):** Migração das EC2 para um ASG distribuído por múltiplas *Availability Zones* (ex: `us-east-1a` e `us-east-1b`)[cite: 482, 487].
* [cite_start]**RDS Multi-AZ:** Ativação da funcionalidade *Multi-AZ* no banco de dados PostgreSQL para falha automática (*failover*) em caso de desastre[cite: 483].

### FASE 3: Migração para Orquestração Cloud-Native
* [cite_start]**AWS ECS (Elastic Container Service) com Fargate:** Eliminação da necessidade de gerir Sistemas Operativos convidados (EC2) e provisionamento via Ansible[cite: 543, 544]. [cite_start]A transição para Fargate permitiria orquestrar os contentores como serviços isolados [cite: 545][cite_start], cada um com os seus próprios recursos de CPU/RAM, limites de escalonamento dinâmico e integração nativa de logs[cite: 544].

### FASE 4: Observabilidade e Monitorização
* [cite_start]**Centralização de Logs:** Reencaminhamento da saída padrão (*stdout/stderr*) dos contentores Docker para o Amazon CloudWatch Logs[cite: 466, 467].
* [cite_start]**Alarmística:** Configuração de alarmes de faturação e monitorização de uso de CPU/Memória na instância EC2 via CloudWatch e SNS[cite: 471, 472].