###############################
## Passive FortiGate-VM SETTINGS    ##
###############################
// create oci instance for passive
resource "oci_core_instance" "passivevm" {
  depends_on = [oci_core_subnet.trust_subnet_ad2]

  availability_domain = lookup(data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain2 - 1], "name")
  compartment_id      = var.compartment_ocid
  display_name        = "fgt-passivevm"
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_cpu
    memory_in_gbs = var.instance_memory
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.mgmt_subnet_ad2.id
    display_name     = "fgt-passivevm-vnic"
    assign_public_ip = true
    hostname_label   = "fgt-passivevm-vnic"
    private_ip       = var.mgmt_private_ip_passive
  }

  launch_options {
    //network_type = "PARAVIRTUALIZED"
    network_type = "VFIO"
  }

  source_details {
    source_type = "image"
    source_id   = local.mp_listing_resource_id // marketplace listing
    boot_volume_size_in_gbs = "50"
  }

  // Required for bootstrap
  // Commnet out the following if you use the feature.
  metadata = {
    user_data = base64encode(templatefile("${var.bootstrap-passive}", {
      license_file        = "${file("${var.license2}")}"
      port1_ip            = var.mgmt_private_ip_passive
      port1_mask          = var.mgmt_private_mask
      port2_ip            = var.public_private_ip_passive
      port2_mask          = var.public_private_mask
      port3_ip            = var.trust_private_ip_passive
      port3_mask          = var.trust_private_mask
      passive_peerip      = var.mgmt_private_ip_active
      mgmt_gateway_ip     = oci_core_subnet.mgmt_subnet_ad2.virtual_router_ip
      public_gateway_ip   = oci_core_subnet.public_subnet_ad2.virtual_router_ip
      vcn_cidr            = var.vcn_cidr
      internal_gateway_ip = oci_core_subnet.trust_subnet_ad2.virtual_router_ip
      tenantid            = var.tenancy_ocid
      userid              = var.user_ocid
      compartid           = var.compartment_ocid
      cert                = var.cert
      region              = var.region
      })
    )
  }

  timeouts {
    create = "60m"
  }
}

//  public nic attachment
resource "oci_core_vnic_attachment" "vnic_attach_public_passive" {
  depends_on   = [oci_core_instance.passivevm]
  instance_id  = oci_core_instance.passivevm.id
  display_name = "fgt-passivevm-vnic_public"

  create_vnic_details {
    subnet_id              = oci_core_subnet.public_subnet_ad2.id
    display_name           = "fgt-passivevm-vnic_public"
    assign_public_ip       = false
    skip_source_dest_check = true
    private_ip             = var.public_private_ip_passive
  }
}

// trust nic attachment
resource "oci_core_vnic_attachment" "vnic_attach_trust_passive" {
  depends_on   = [oci_core_vnic_attachment.vnic_attach_public_passive]
  instance_id  = oci_core_instance.passivevm.id
  display_name = "fgt-passivevm-vnic_trust"

  create_vnic_details {
    subnet_id              = oci_core_subnet.trust_subnet_ad2.id
    display_name           = "fgt-passivevm-vnic_trust"
    assign_public_ip       = false
    skip_source_dest_check = true
    private_ip             = var.trust_private_ip_passive
  }
}

