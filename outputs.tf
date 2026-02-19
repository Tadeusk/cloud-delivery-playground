output "vpc_id" {
    value = aws_vpc.main.id
    description = "ID of your main vpc in your project"
}

output "public_subnet_id" {
    value = aws_subnet.public.id
    description = "ID of the public subnet in your project"
}