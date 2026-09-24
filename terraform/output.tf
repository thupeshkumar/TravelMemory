output "web_public_ip" {
  description = "Public IP of MERN web server"
  value       = aws_instance.mern_web.public_ip
}

output "db_public_ip" {
  description = "Public IP of MongoDB server"
  value       = aws_instance.mongo_db.public_ip
}

output "subnet_used" {
  description = "Subnet ID used for both instances"
  value       = aws_instance.mern_web.subnet_id
}

output "security_groups" {
  description = "Security groups created"
  value = {
    web_sg = aws_security_group.web_sg_TK.id
    db_sg  = aws_security_group.db_sg_TK.id
  }
}