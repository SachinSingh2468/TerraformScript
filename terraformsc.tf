provider "aws" {
  region = "up-east-1"
}


#Creating a VPC
resource "aws_vpc" "newvpc"{
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "myVPC"
    }
}
#Creating a Public Subnet
resource "aws_subnet" "publicsubnet"{
    vpc_id = aws_vpc.newvpc.id
    availability_zone = "us-east-1a"
    cidr_block = "10.0.0.0/24"
    map_public_ip_on_launch = true
}

# Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.newvpc.id
}

# Create Route Table 
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.newvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}
# Associate route table with subnet
resource "aws_route_table_association" "my_route_table_association" {
  subnet_id      = aws_subnet.publicsubnet.id
  route_table_id = aws_route_table.my_route_table.id
}

#Creating Security Group
resource "aws_security_group" "terraform-sg" {
  name        = "SG_using_terraform"
  vpc_id      = aws_vpc.newvpc.id

  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "terraform-sg"
  }
}
#Creating an EC2 instance
resource "aws_instance" "ec2-terraform" {
  ami           = "ami-0aa2b7722dc1b5612"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.publicsubnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.terraform-sg.id]

    user_data = <<-EOF
        #!/bin/bash
        apt-get update
        apt-get install -y docker.io

        #Create a Dockerfile
        cat > Dockerfile << EOL
        FROM php:7.4-apache
        WORKDIR /var/www/html
        COPY . /var/www/html/
        RUN docker-php-ext-install mysqli
        EXPOSE 80
        ENTRYPOINT ["apache2-foreground"]
        EOL

        #Login to DockerHub
        docker login --username=<dockerhub_username> --password=<dockerhub_password>

        #build & run the image....
        docker build -t my-wordpress-app .
        docker run -d -p 80:80 --env WORDPRESS_DB_HOST=${aws_db_instance.db_instance.address} --env WORDPRESS_DB_USER=${aws_db_instance.db_instance.username} --env WORDPRESS_DB_PASSWORD=${aws_db_instance.db_instance.password} --env WORDPRESS_DB_NAME=${aws_db_instance.db_instance.name} my-wordpress-app
        EOF

        #Push Docker image to Docker Hub
        docker push <dockerhub_username>/my-wordpress-app

  tags = {
    Name = "ec2-terraform"
  }
}


#Creating a Private Subnet
resource "aws_subnet" "privatesubnet"{
    vpc_id = aws_vpc.newvpc.id
    availability_zone = "us-east-1a"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = false
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.privatesubnet.id]
}

resource "aws_db_instance" "db_instance" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "wordpressdb"
  username             = "dbadmin"
  password             = "passwddb"
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name

   vpc_security_group_ids = [aws_security_group.db_security_group.id]
}

resource "aws_security_group" "db_security_group" {
  name        = "db-security-group"
  description = "Allow inbound connections to the RDS instance"

  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}
