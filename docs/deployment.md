# Guia de Deployment (Deployment Workflow)

Este documento detalha o processo de entrega da aplicação, desde a compilação do código-fonte até à execução na infraestrutura cloud da AWS. [cite_start]O projeto suporta duas vias de *deployment*: um pipeline totalmente automatizado via integração contínua (CI/CD) e um processo manual passo-a-passo para efeitos de debug e demonstração[cite: 654, 655, 733].

## 1. Deployment Automatizado (Recomendado via GitHub Actions)

O fluxo principal de entrega contínua está configurado no ficheiro `.github/workflows/deploy.yml`. Este pipeline garante que não há intervenção manual na consola da AWS para colocar o sistema em produção.

**Fluxo de Execução:**
1. O *trigger* é ativado automaticamente através de um *push* ou *merge* para a *branch* `main`.
2. O GitHub Actions assume as credenciais de forma segura através de permissões OIDC (OpenID Connect).
3. **Infraestrutura:** Executa `terraform init` e `terraform apply -auto-approve` para atualizar ou provisionar a rede (VPC), os *Security Groups*, a instância EC2 e a base de dados RDS PostgreSQL.
4. **Injeção de Variáveis:** O pipeline extrai dinamicamente o IP público da EC2 e o *endpoint* do RDS gerados pela AWS.
5. **Configuração e Execução (Deploy):** O Ansible estabelece ligação via SSH, instala e configura as dependências (Docker), injeta as variáveis de ambiente e segredos, e invoca o orquestrador para compilar as imagens e iniciar os contentores (`docker-compose up --build -d`).

## 2. Deployment Manual (Passo-a-Passo)

[cite_start]Caso seja necessário provisionar o ambiente localmente (ex: para a demonstração ou validação da idempotência), os passos seguintes devem ser executados sequencialmente, cumprindo o fluxo de criação da infraestrutura, compilação de imagens e *deploy*[cite: 733].

### Passo 2.1: Provisionamento da Infraestrutura (Terraform)
Na máquina local, certifique-se de que configurou as credenciais AWS e navegue para a diretoria do Terraform para criar os recursos:
```bash
cd terraform/
terraform init
terraform apply
```
*Atenção: Anote o `ec2_public_ip` e o `rds_endpoint` apresentados no output do terminal no final do processo.*

### Passo 2.2: Preparação e Sincronização de Código (Build)
Compile os pacotes Java dos microsserviços:
```bash
# Na raiz do projeto
mvn clean package -DskipTests
```
Transfira o código-fonte e os binários para o servidor EC2 recém-criado, utilizando sincronização diferencial (`rsync`) para otimização de largura de banda:
```bash
rsync -av -e "ssh -i terraform/projeto-final-key.pem" \
--exclude='.git' --exclude='.terraform' --exclude='*.pem' \
./ ubuntu@<EC2_PUBLIC_IP>:/home/ubuntu/app/
```

### Passo 2.3: Configuração e Execução (Ansible & Docker)
Atualize o ficheiro de inventário do Ansible (`ansible/inventory.ini`) com o novo IP público da instância. Em seguida, execute o *playbook* de provisionamento:
```bash
cd ansible/
ansible-playbook -i inventory.ini playbook.yml
```
*O Ansible irá garantir a instalação do ecossistema Docker e arrancar o API Gateway, os microsserviços aplicacionais e a stack do Kafka. Aguarde 1-2 minutos para estabilização da memória (JVMs e Zookeeper).*

## 3. Desmantelamento da Infraestrutura (Tear Down)

[cite_start]Para otimização de custos e por cumprimento das boas práticas de laboratório, todos os recursos AWS devem ser destruídos quando a aplicação não se encontra em uso[cite: 976, 1156].

**Opção A (Manual):**
Na máquina local, execute a remoção do estado do Terraform:
```bash
cd terraform/
terraform destroy
```

**Opção B (Automatizada):**
No repositório do GitHub, navegue até ao separador **Actions**, selecione o workflow **Destroy Infrastructure** e clique em **Run workflow** para iniciar um desmantelamento remoto limpo.