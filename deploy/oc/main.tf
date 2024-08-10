provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

resource "oci_core_vcn" "talos_vcn" {
  cidr_block     = "10.0.0.0/16"
  display_name   = "talos-vcn"
  compartment_id = var.compartment_ocid
}

resource "oci_core_subnet" "talos_subnet" {
  availability_domain = var.availability_domain
  cidr_block          = "10.0.0.0/24"
  display_name         = "talos-subnet"
  compartment_id       = var.compartment_ocid
  vcn_id               = oci_core_vcn.talos_vcn.id
}

resource "oci_core_internet_gateway" "talos_ig" {
  compartment_id = var.compartment_ocid
  display_name   = "talos-ig"
  is_enabled     = true
  vcn_id         = oci_core_vcn.talos_vcn.id
}

resource "oci_core_route_table" "talos_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.talos_vcn.id
  display_name   = "talos-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.talos_ig.id
  }
}

resource "oci_core_security_list" "talos_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.talos_vcn.id
  display_name   = "talos-security-list"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "all"
  }
}

resource "oci_load_balancer_load_balancer" "talos_lb" {
  compartment_id = var.compartment_ocid
  display_name   = "talos-lb"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.talos_subnet.id]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }
}

resource "oci_load_balancer_backend_set" "talos_backend_set" {
  load_balancer_id = oci_load_balancer_load_balancer.talos_lb.id
  name             = "talos-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "TCP"
    port     = 50000
  }
}

resource "oci_load_balancer_listener" "talos_listener" {
  load_balancer_id         = oci_load_balancer_load_balancer.talos_lb.id
  name                     = "talos-listener"
  default_backend_set_name = oci_load_balancer_backend_set.talos_backend_set.name
  port                     = 50000
  protocol                  = "TCP"
}

resource "oci_core_instance" "talos_instance" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.A1.Flex"
  display_name        = "talos-instance"

  shape_config {
    memory_in_gbs = 4
    ocpus         = 1
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.talos_subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    image_id    = var.image_id
  }

  metadata = {
    user_data = base64encode(file("controlplane.yaml"))
  }

  launch_options {
    network_type = "PARAVIRTUALIZED"
  }
}

resource "oci_load_balancer_backend" "talos_backend" {
  load_balancer_id = oci_load_balancer_load_balancer.talos_lb.id
  backendset_name  = oci_load_balancer_backend_set.talos_backend_set.name
  ip_address       = oci_core_instance.talos_instance.private_ip
  port             = 50000
}
