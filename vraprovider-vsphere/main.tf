provider vra {
  url                           = var.vra_url
  refresh_token                 = var.vra_refresh_token
  insecure                      = true
}

# Collecting Data Collector ID (used primarily for vRA Cloud)
data "vra_data_collector" "dc" {
  count                         = var.datacollector != "" ? 1 : 0
  name                          = var.datacollector
}

# Collecting vSphere Region Data:
data "vra_region_enumeration_vsphere" "this" {
  username                      = var.vc_username
  password                      = var.vc_password
  hostname                      = var.vc_hostname
  accept_self_signed_cert       = true
}

# Creating the NSX-V Cloud Account:
resource "vra_cloud_account_nsxv" "this" {
  name                          = "Terraform NSX-V Account"
  description                   = "Created by Terraform!"
  username                      = var.nsxv_username
  password                      = var.nsxv_password
  hostname                      = var.nsxv_hostname
  dc_id                         = var.datacollector != "" ? data.vra_data_collector.dc[0].id : ""
  accept_self_signed_cert       = true
}

# Creating the vSphere Cloud Account and Associating the above NSX-V to it:
resource "vra_cloud_account_vsphere" "this" {
  name                          = "Terraform vSphere Account"
  description                   = "Created by Terraform with very little effort!"
  username                      = var.vc_username
  password                      = var.vc_password
  hostname                      = var.vc_hostname
  dcid                          = var.datacollector != "" ? data.vra_data_collector.dc[0].id : "" # Required for vRA Cloud, Optional for vRA 8.0
  regions                       = data.vra_region_enumeration_vsphere.this.regions
  associated_cloud_account_ids  = [vra_cloud_account_nsxv.this.id]
  accept_self_signed_cert       = true
}

# Collecting the ID of the vSphere Datacenter to create resources:
data "vra_region" "this" {
  cloud_account_id              = vra_cloud_account_vsphere.this.id
  region                        = "Datacenter:datacenter-21"
}

# Create a vSphere Cloud Zone:
resource "vra_zone" "this" {
  name                          = "Terraform Zone"
  description                   = "Cloud Zone configured by Terraform"
  region_id                     = data.vra_region.this.id
}

# Create a vSphere flavor profile:
resource "vra_flavor_profile" "this" {
  name                          = "CentOS"
  description                   = "Flavor profile created by Terraform"
  region_id                     = data.vra_region.this.id

  flavor_mapping {
    name                        = "small"
    cpu_count                   = 1
    memory                      = 512
  }
  flavor_mapping {
    name                        = "medium"
    cpu_count                   = 2
    memory                      = 2048
  }
  flavor_mapping {
    name                        = "large"
    cpu_count                   = 4
    memory                      = 4096
  }
}

# Terraform does not support a delay or wait command so this provider launches a local command on your client.  'Timeout' in windows will error because of input redirect errors but ping works.  If using linux you would use the commmand 'sleep':
resource "null_resource" "delay" {
  depends_on                    = [vra_cloud_account_vsphere.this]
  provisioner "local-exec" {
    command = "ping 127.0.0.1 -n 60 > NULL"
  }
  triggers = {
    "my_zone" = vra_zone.this.id
  }
}

# Create a new image profile:
data "vra_image" "this" {
  depends_on                    = [null_resource.delay]
//  filter = "name eq 'PuppetAgentCentOS7-tangoE2E' and cloudAccountId eq '${data.vra_cloud_account_vsphere.this.id}'"
  filter = "name eq 'centos6-template'"
}
 
resource "vra_image_profile" "this" {
  depends_on                    = [null_resource.delay]
  name        = "CentOS"
  description = "terraform test image profile"
  region_id   = data.vra_region.this.id
 
  image_mapping {
    name       = "CentOS"
    image_id   = data.vra_image.this.id
  }
}

# Create a new Project
resource "vra_project" "this" {
  name                          = "Terraform Project"
  description                   = "Project configured by Terraform"

  administrators                = ["fritz@coke.sqa-horizon.local"]
  members                       = ["fritz@coke.sqa-horizon.local"]

  zone_assignments {
    zone_id                     = vra_zone.this.id
    priority                    = 1
    max_instances               = 0
  }
}

# Create a new Blueprint
resource "vra_blueprint" "this" {
  depends_on                    = [null_resource.delay]
  name                          = "CentOS Blueprint"
  description                   = "Created by vRA terraform provider"
  project_id                    = vra_project.this.id

  content                       = <<-EOT
formatVersion: 1
inputs: {}
resources:
  Cloud_vSphere_Machine_1:
    type: Cloud.vSphere.Machine
    properties:
      image: CentOS
      flavor: Small
  EOT
}

# Example to create a blueprint version and release it
resource "vra_blueprint_version" "this" {
  blueprint_id                  = vra_blueprint.this.id
  description                   = "Released from vRA terraform provider"
  version                       = 1
  release                       = true
  change_log                    = "First version"
}


# Request a new Blueprint:
//data "vra_project" "this" {
//  depends_on                    = [vra_project.this]
//  name                          = var.project_name
//}
//
//data "vra_blueprint" "this" {
//  depends_on                    = [vra_blueprint.this]
//  name                          = var.blueprint_name
//}
//
//resource "vra_deployment" "this" {
//  depends_on                    = [null_resource.delay]
//  name                          = var.deployment_name
//  description                   = "Deployed from vRA provider for Terraform."
//
//  blueprint_id                  = data.vra_blueprint.this.id
//  blueprint_version             = var.blueprint_version
//  project_id                    = data.vra_project.this.id
//
//  inputs                        = {
//    flavor                      = "small"
//    image                       = "CentOS Blueprint"
//    count                       = 1
//    flag                        = true
//  }
//
//  timeouts {
//    create                      = "60m"
//    delete                      = "60m"
//    update                      = "60m"
//  }
//}
//
//
//output "resources" {
//  description                   = "All the resources from a vRA deployment"
//  value                         = vra_deployment.this.resources
//}
//
//output "resource_properties_by_name" {
//  description                   = "Properties of all resources by its name from a vRA deployment"
//  value                         = {
//    for rs in vra_deployment.this.resources :
//    rs.name => jsondecode(rs.properties_json)
//  }
//}
//
//output "resources_properties" {
//  description                   = "Properties of all resources from a vRA deployment"
//  value                         = [
//    for rs in vra_deployment.this.resources :
//    jsondecode(rs.properties_json)
//  ]
//}