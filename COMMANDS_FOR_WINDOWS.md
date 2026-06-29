# Lab DevOps — Terraform + Ansible no Windows (WSL)

Guia adaptado para ambiente Windows com Terraform no PowerShell e Ansible no WSL.

---

## Pré-requisitos

- AWS Learner Lab ativo
- Terraform instalado no Windows (no PATH)
- WSL instalado com Ubuntu
- Ansible instalado no WSL
- AWS CLI instalada no WSL
- Chave SSH criada/importada na AWS

---

## Etapa 0 — Credenciais do Learner Lab

No AWS Learner Lab, abra **AWS Details** e copie as credenciais.

Crie o arquivo `credentials.ps1` na raiz do projeto:

```powershell
$env:AWS_ACCESS_KEY_ID="SEU_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY="SEU_SECRET_KEY"
$env:AWS_SESSION_TOKEN="SEU_SESSION_TOKEN"
$env:AWS_DEFAULT_REGION="us-east-1"
```

Crie também o `.env` para o WSL (Ansible):

```bash
export AWS_ACCESS_KEY_ID="SEU_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="SEU_SECRET_KEY"
export AWS_SESSION_TOKEN="SEU_SESSION_TOKEN"
export AWS_DEFAULT_REGION="us-east-1"
```

> Adicione os dois ao `.gitignore` — nunca suba credenciais no Git.

**Validar no WSL:**

```bash
source .env
aws sts get-caller-identity
```

---

## Etapa 1 — Estrutura de pastas

A estrutura já existe no repositório:

```
LAB-DEVOPS-IAC/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars          ← você cria (não sobe no Git)
│   └── terraform.tfvars.example  ← modelo já existe
├── ansible/
│   ├── inventory/
│   │   └── hosts.ini
│   ├── group_vars/
│   │   └── all.yml
│   └── playbooks/
│       └── prepare-servers.yml
├── credentials.ps1               ← você cria (não sobe no Git)
├── .env                          ← você cria (não sobe no Git)
└── .gitignore
```

---

## Etapa 2 — Preencher o terraform.tfvars

Copie o exemplo e edite com seus valores:

**No PowerShell:**

```powershell
cd D:\LAB-DEVOPS-IAC\terraform
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edite o `terraform.tfvars`:

```hcl
aws_region       = "us-east-1"
project_name     = "fundamentos-devops"
ami_id           = "ami-xxxxxxxxxxxxxxxxx"
instance_type    = "t3.micro"
key_name         = "vockey"
allowed_ssh_cidr = "0.0.0.0/0"
```

Para descobrir seu IP público (WSL):

```bash
curl -s ifconfig.me
```

> `ami_id`: AMI Ubuntu da sua região. `key_name`: no Learner Lab use `vockey`.

---

## Etapa 3 — Executar o Terraform

Abra o **terminal PowerShell** no VS Code e execute:

```powershell
# Entrar na pasta do Terraform
cd D:\LAB-DEVOPS-IAC\terraform

# Carregar credenciais AWS
. ..\credentials.ps1

# Inicializar (só na primeira vez)
terraform init

# Formatar e validar
terraform fmt -recursive
terraform validate

# Ver o que será criado
terraform plan -out tfplan

# Criar a infraestrutura na AWS
terraform apply tfplan
```

**Coletar os IPs gerados:**

```powershell
terraform output
terraform output -json
```

Guarde os IPs públicos e privados — você vai precisar deles no Ansible.

---

## Etapa 4 — Configurar o inventário Ansible

Abra o arquivo `ansible/inventory/hosts.ini` e substitua os IPs pelos valores do `terraform output`:

```ini
[control_plane]
control-plane ansible_host=18.210.10.10 private_ip=10.0.1.10

[workers]
worker-1 ansible_host=54.88.20.20 private_ip=10.0.1.11
worker-2 ansible_host=3.95.30.30 private_ip=10.0.1.12

[k8s_nodes:children]
control_plane
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/vockey.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

---

## Etapa 5 — Copiar a chave SSH para o WSL

A chave `.pem` baixada do Learner Lab precisa estar no WSL:

```bash
# Criar pasta .ssh se não existir
mkdir -p ~/.ssh

# Copiar a chave do Windows para o WSL
cp /mnt/c/Users/SEU_USUARIO/Downloads/labsuser.pem ~/.ssh/vockey.pem

# Ajustar permissão (obrigatório)
chmod 400 ~/.ssh/vockey.pem
```

---

## Etapa 6 — Executar o Ansible

Abra o **terminal WSL** no VS Code e execute:

```bash
# Entrar na pasta do projeto
cd /mnt/d/LAB-DEVOPS-IAC

# Carregar credenciais
source .env

# Entrar na pasta do Ansible
cd ansible

# Validar inventário
ansible-inventory -i inventory/hosts.ini --graph

# Testar conectividade SSH nos 3 nós
ansible -i inventory/hosts.ini k8s_nodes -m ping

# Executar o playbook de configuração
ansible-playbook -i inventory/hosts.ini playbooks/prepare-servers.yml
```

---

## Etapa 7 — Verificação final

**Teste SSH manual no control plane (WSL):**

```bash
ssh -i ~/.ssh/vockey.pem ubuntu@IP_PUBLICO_DO_CONTROL_PLANE
```

**Teste ad-hoc nos três nós:**

```bash
ansible all -i inventory/hosts.ini -m command -a "hostname -I"
```

---

## Checklist de entrega

- [ ] 3 instâncias EC2 criadas (`terraform output` mostrando os IPs)
- [ ] Security Group configurado
- [ ] `aws sts get-caller-identity` retornando dados da conta
- [ ] `ansible -m ping` funcionando nos 3 hosts
- [ ] Playbook executado com sucesso
- [ ] Acesso SSH validado no control plane

---

## Limpeza do ambiente (obrigatória)

Para evitar consumo no Learner Lab, destrua a infraestrutura ao final:

**No PowerShell:**

```powershell
cd D:\LAB-DEVOPS-IAC\terraform
. ..\credentials.ps1
terraform destroy
```

---

## Referência rápida — qual terminal usar

| Comando | Terminal |
|---|---|
| `terraform init / plan / apply / destroy` | PowerShell |
| `. ..\credentials.ps1` | PowerShell |
| `ansible-playbook` | WSL |
| `ansible -m ping` | WSL |
| `aws sts get-caller-identity` | WSL |
| `source .env` | WSL |
| `chmod 400 chave.pem` | WSL |
| `ssh -i chave.pem ubuntu@IP` | WSL |
