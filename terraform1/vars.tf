variable "token" {
  description = "Yandex Cloud security OAuth token"
  default     = "<OAuth>" 
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID where resources will be created"
  default     = "<folder id>"
}

variable "cloud_id" {
  description = "Yandex Cloud ID where resources will be created"
  default     = "<cloud id>"
}

variable "zone" {
  description = "Yandex Cloud zone where resources will be created"
  default     = "ru-central1-a"
}

variable "public_key_path" {
  description = "Path to ssh public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Path to ssh private key"
  default     = "~/.ssh/id_rsa"
}

variable "password" {
  type = string
  default  = "<password>"
}

variable "user" {
  type = string
  default = "user"
}


 