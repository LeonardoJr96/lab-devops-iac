output "public_ips" {
  description = "IPs publicos das instancias"
  value = {
    for name, instance in aws_instance.nodes :
    name => instance.public_ip
  }
}

output "private_ips" {
  description = "IPs privados das instancias"
  value = {
    for name, instance in aws_instance.nodes :
    name => instance.private_ip
  }
}

output "instance_ids" {
  description = "IDs das instancias"
  value = {
    for name, instance in aws_instance.nodes :
    name => instance.id
  }
}