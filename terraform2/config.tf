terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token = var.token
  cloud_id = var.cloud_id
  folder_id = var.folder_id
  zone = var.zone
}

resource "yandex_vpc_network" "network1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet1" {
  name           = "subnet1"
  zone           = var.zone
  network_id     = yandex_vpc_network.network1.id
  v4_cidr_blocks = ["10.240.1.0/24"]
}

data "yandex_compute_image" "ubuntu-20-04" {
  family = "ubuntu-2004-lts"
}



resource "yandex_iam_service_account" "sa" {
  folder_id = var.folder_id
  name      = "tf-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

resource "yandex_storage_bucket" "boxfuserepo" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = var.bucket_name
}


resource "yandex_compute_instance" "vm-1" {
  name = "build"
 
  resources {
    cores = 2
    memory = 2
  }
  boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu-20-04.id
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat = true
  }

  metadata = {
      user-data = "${file("/home/user/terraform2/meta-1.txt")}"
  }


provisioner "remote-exec" {
    inline = [
	  "echo '${var.user}:${var.password}' | sudo chpasswd",
      "sudo apt update",
	  "sudo apt install git maven openjdk-8-jdk awscli -y ",
      "git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello.git /home/user/boxfuse",
      "mvn package -f /home/user/boxfuse",
	  "aws --profile default configure set aws_access_key_id ${yandex_iam_service_account_static_access_key.sa-static-key.access_key}",
      "aws --profile default configure set aws_secret_access_key ${yandex_iam_service_account_static_access_key.sa-static-key.secret_key}",
      "aws configure set region ${var.region}",
      "aws --endpoint-url=https://storage.yandexcloud.net/ s3 cp  /home/user/boxfuse/target/hello-1.0.war s3://${var.bucket_name}/"
    ]
	connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file(var.private_key_path)
      host = "${yandex_compute_instance.vm-1.network_interface.0.nat_ip_address}"
    }
  }
}
	
resource "yandex_compute_instance" "vm-2" {
   name = "prod"

   resources {
     cores  = 2
     memory = 2
   }	
   boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu-20-04.id
      type = "network-ssd"
      size = 100
    }
  }	
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat = true
  }

  metadata = {
    user-data = "${file("/home/user/terraform2/meta-2.txt")}"
  }
  
  provisioner "remote-exec" {
       inline = [
        "sudo apt update",
        "sudo apt install tomcat9 awscli -y ",
        "aws --profile default configure set aws_access_key_id ${yandex_iam_service_account_static_access_key.sa-static-key.access_key}",
        "aws --profile default configure set aws_secret_access_key ${yandex_iam_service_account_static_access_key.sa-static-key.secret_key}",
        "aws configure set region ${var.region}",
        "aws --endpoint-url=https://storage.yandexcloud.net/ s3 cp s3://${local.bucket_name}/hello-1.0.war /var/lib/tomcat9/webapps/",
        "mv /var/lib/tomcat9/webapps/hello-1.0.war /var/lib/tomcat9/webapps/hello.war",
        "sudo systemctl restart tomcat9"
      ]
      connection {
        type     = "ssh"
		user     = "ubuntu"
        private_key = file(var.private_key_path)
        host = "${yandex_compute_instance.vm-2.network_interface.0.nat_ip_address}"
      }
    }
   depends_on = [
      yandex_compute_instance.vm-1
    ]
 }
 


output "vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

output "vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.nat_ip_address
}
