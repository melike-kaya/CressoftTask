terraform {
  required_version = ">= 1.9.0"
  backend "s3" {} # sadece bu modülde local backend kullan
}

