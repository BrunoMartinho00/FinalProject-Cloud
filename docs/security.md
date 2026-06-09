# Segurança e Controlo de Acessos (Security & IAM)

Este documento detalha as políticas de segurança, gestão de identidade e isolamento de rede aplicadas à infraestrutura do projeto, garantindo a proteção de dados e a mitigação de vetores de ataque comuns.

## 1. Gestão de Identidade e Acessos (IAM)

A arquitetura adota rigorosamente o **Princípio de Privilégio Mínimo (Least Privilege)** em todas as interações com a AWS.

### 1.1. Autenticação via OIDC (OpenID Connect)
Foi abolido o uso de credenciais estáticas de longo prazo (Access Keys e Secret Keys) no pipeline de CI/CD, prevenindo o risco de fuga de chaves no código fonte.
* O GitHub Actions autentica-se na AWS através de um *Identity Provider* OIDC.
* O pipeline assume uma *IAM Role* temporária (`AWS_ROLE_TO_ASSUME`) cujas políticas de confiança (*Trust Policies*) estão estritamente limitadas ao repositório do projeto no GitHub.
* A *Role* possui apenas as permissões necessárias para o Terraform aprovisionar instâncias EC2, gerir a VPC e o serviço RDS, rejeitando implicitamente qualquer outra ação na conta AWS.

## 2. Isolamento de Rede (Network Security)

A superfície de ataque foi drasticamente reduzida através da segmentação da rede na VPC e da aplicação de regras de firewall restritivas (*Security Groups*).

* **Camada de Computação (Public Subnet):** A instância EC2, que atua como *host* Docker e *Reverse Proxy*, reside numa sub-rede pública. O seu *Security Group* (`web_sg`) aceita apenas tráfego HTTP (Porta 80) e tráfego administrativo SSH (Porta 22).
* **Camada de Persistência (Private Subnet):** A base de dados RDS (PostgreSQL) encontra-se isolada numa sub-rede privada, sem endereço IP público (`publicly_accessible = false`).
* **Controlo de Fluxo:** O *Security Group* da base de dados (`db_sg`) está configurado para rejeitar tráfego de qualquer bloco IP (0.0.0.0/0). O acesso à porta `5432` é permitido **exclusivamente** a pacotes com origem no ID do *Security Group* da EC2 (`web_sg`).

## 3. Gestão de Segredos e Credenciais

Nenhum dado sensível, password ou *token* foi *hardcoded* no código fonte do Terraform, Docker ou Java. A injeção de segredos ocorre apenas no momento do *deployment*.

### 3.1. Pipeline e Repositório
* As passwords da base de dados (`DB_USERNAME`, `DB_PASSWORD`) estão guardadas no cofre cifrado do GitHub (**GitHub Secrets**).
* Durante a execução do *workflow*, o GitHub Actions extrai estes segredos em memória e injeta-os como