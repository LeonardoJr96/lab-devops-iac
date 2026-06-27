# Infraestrutura como Codigo com Terraform, Ansible, k3s e ArgoCD

Este repositorio e um projeto didatico de IaC para provisionar servidores EC2 na AWS com Terraform, configurar os servidores com Ansible, instalar um cluster Kubernetes leve com k3s e expor o ArgoCD para GitOps.

## Objetivo

O fluxo do projeto e:

1. Criar 3 instancias EC2 na AWS:
   - `control-plane`
   - `worker-1`
   - `worker-2`
2. Obter os IPs publicos e privados das instancias pelo Terraform.
3. Usar esses IPs no inventario do Ansible.
4. Preparar os servidores.
5. Instalar o k3s.
6. Instalar e expor o ArgoCD.

## Estrutura

```text
.
+-- ansible/
|   +-- group_vars/
|   |   +-- all.yml
|   +-- inventory/
|   |   +-- hosts.ini
|   +-- playbooks/
|       +-- prepare-servers.yml
|       +-- install-k3s.yml
|       +-- install-argocd.yml
+-- terraform/
|   +-- main.tf
|   +-- variables.tf
|   +-- outputs.tf
|   +-- terraform.tfvars.example
|   +-- terraform.tfvars
+-- commands.md
+-- .gitignore
+-- README.md
```

## Pre-requisitos

Voce precisa ter instalado:

- Terraform
- Ansible
- AWS CLI configurado com credenciais validas
- Uma chave SSH cadastrada na AWS
- Uma chave privada `.pem` correspondente no seu computador

Tambem e necessario preencher o arquivo `terraform/terraform.tfvars` com os valores reais do seu ambiente.

Exemplo:

```hcl
aws_region       = "us-east-1"
project_name     = "fundamentos-devops"
ami_id           = "ami-xxxxxxxxxxxxxxxxx"
instance_type    = "t3.micro"
key_name         = "minha-chave-aws"
allowed_ssh_cidr = "203.0.113.10/32"
```

Importante: o arquivo `terraform.tfvars` nao deve ser versionado, pois pode conter dados sensiveis ou especificos do seu ambiente.

## 1. Provisionar a infraestrutura

Entre na pasta do Terraform:

```bash
cd terraform
```

Inicialize o Terraform:

```bash
terraform init
```

Veja o plano de criacao:

```bash
terraform plan -out tfplan
```

Aplique o plano:

```bash
terraform apply tfplan
```

Depois veja os IPs gerados:

```bash
terraform output
```

Ou em JSON:

```bash
terraform output -json
```

## 2. Atualizar o inventario do Ansible

O Terraform gera os IPs das instancias nos outputs:

- `public_ips`
- `private_ips`
- `instance_ids`

Esses valores precisam estar no arquivo:

```text
ansible/inventory/hosts.ini
```

Exemplo:

```ini
[control_plane]
control-plane ansible_host=IP_PUBLICO_CONTROL_PLANE private_ip=IP_PRIVADO_CONTROL_PLANE

[workers]
worker-1 ansible_host=IP_PUBLICO_WORKER_1 private_ip=IP_PRIVADO_WORKER_1
worker-2 ansible_host=IP_PUBLICO_WORKER_2 private_ip=IP_PRIVADO_WORKER_2

[k8s_nodes:children]
control_plane
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/minha-chave-aws.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

Neste estado do projeto, o inventario ainda e preenchido manualmente. Uma melhoria natural e fazer o Terraform gerar esse arquivo automaticamente usando `local_file` e `templatefile`.

## 3. Configurar variaveis do Ansible

Edite:

```text
ansible/group_vars/all.yml
```

Exemplo:

```yml
common_packages:
  - curl
  - vim
  - htop
  - net-tools
  - ca-certificates
  - apt-transport-https

admin_user: devops
admin_pubkey: "sua-chave-publica-ssh"
```

Troque `admin_pubkey` pela sua chave publica real.

## 4. Testar conexao com os servidores

Entre na pasta do Ansible:

```bash
cd ../ansible
```

Teste a conexao:

```bash
ansible all -i inventory/hosts.ini -m ping
```

Se tudo estiver correto, cada host deve responder com `pong`.

## 5. Preparar os servidores

Execute:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/prepare-servers.yml
```

Esse playbook atualiza pacotes, instala ferramentas basicas, cria um usuario administrativo e ajusta configuracoes de SSH.

## 6. Instalar o k3s

Execute:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/install-k3s.yml
```

Esse playbook instala o k3s no `control-plane`, obtem o token do cluster e adiciona os workers ao cluster usando o IP privado do control plane.

## 7. Instalar o ArgoCD

Execute:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/install-argocd.yml
```

Esse playbook cria o namespace `argocd`, instala os manifests oficiais e altera o servico `argocd-server` para `NodePort`.

Ao final, o Ansible mostra uma URL parecida com:

```text
https://IP_PUBLICO_CONTROL_PLANE:PORTA_NODEPORT
```

Para acessar pelo navegador, o Security Group da AWS precisa permitir entrada na porta NodePort usada pelo ArgoCD.

## Pontos de atencao

- O inventario do Ansible precisa refletir os IPs reais gerados pelo Terraform.
- O Security Group atual libera SSH e comunicacao interna entre os nos, mas pode precisar liberar a porta NodePort do ArgoCD.
- Nao versionar `terraform.tfvars`, `tfstate`, planos do Terraform ou chaves privadas.
- As instancias EC2 geram custo enquanto estiverem ligadas.

## Destruir a infraestrutura

Quando terminar os testes:

```bash
cd terraform
terraform destroy
```

Revise os recursos que serao removidos e confirme a destruicao.
