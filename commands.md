# 1. Provisionar infraestrutura
cd iac/terraform
terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform output -json

# 2. Configurar servidores
cd ../ansible
ansible-playbook -i inventory/hosts.ini playbooks/prepare-servers.yml

# 3. Instalar k3s
ansible-playbook -i inventory/hosts.ini playbooks/install-k3s.yml

# 4. Instalar e expor ArgoCD
ansible-playbook -i inventory/hosts.ini playbooks/install-argocd.yml