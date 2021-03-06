output "onprem" {
  value = {
    floating_ip = ibm_is_floating_ip.onprem.address
    ssh         = "ssh root@${ibm_is_floating_ip.onprem.address}"
    glb         = ibm_dns_glb.widgets.name
  }
}
output "cloud" {
  value = { for zone_index, zone in module.zone : zone_index => {
    lb_hostname    = zone.lb.hostname
    lb_curl        = "curl ${zone.lb.hostname}/instance"
    lb_private_ips = [for private_ip in zone.lb.private_ips : private_ip]
    lb_public_ips  = [for public_ip in zone.lb.public_ips : public_ip]
    dns_location   = ibm_dns_custom_resolver.cloud.locations[zone_index].dns_server_ip
    instances = { for instance_index, instance in zone.instances : instance_index => {
      ipv4_address = instance.primary_network_interface[0].primary_ipv4_address
      floating_ip  = zone.floating_ips[instance_index].address
      ssh          = "ssh root@${zone.floating_ips[instance_index].address}"
      id           = instance.id
    } }
  } }
}