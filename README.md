# Private regional high availability for scalable workloads

This is a companion repository to the blog post: [On-Premises Private Access to Workloads Across Zones Using a DNS GLB and VPC NLB
](https://www.ibm.com/cloud/blog/on-premises-private-access-to-workloads-across-zones-using-a-dns-glb-and-vpc-nlb).

![image](https://user-images.githubusercontent.com/6932057/176736173-ddad609c-85be-448e-a10a-d4bfbecedec4.png)


## Deploy...

### Terraform

See Schematics below to use [IBM Cloud Schematics](https://cloud.ibm.com/schematics/overview).

Create resources:
```
cp template.local.env local.env
edit local.env
source local.env
terraform init
terraform apply
```

Destroy resources:
```
terraform destroy
```

There is Terraform output for **onprem** and **cloud**.

## On-premises


The default Ubuntu DNS resolver can be hard to follow.  Follow the instructions below to disable the default and use [coredns](https://coredns.io/)

```
$ terraform output onprem
{
  "floating_ip" = "52.118.191.148"
  "glb" = "backend.widgets.cogs"
  "ssh" = "ssh root@52.118.191.148"
}
```

### coredns

```
ssh root@...
...
# download coredns
version=1.9.3
file=coredns_${version}_linux_amd64.tgz
wget https://github.com/coredns/coredns/releases/download/v${version}/$file
tar zxvf $file

# turn off the default dns resolution
systemctl disable systemd-resolved
systemctl stop systemd-resolved

# chattr -i stops the resolv.conf file from being updated, configure resolution to be from localhost port 53
rm /etc/resolv.conf
cat > /etc/resolv.conf <<EOF
nameserver 127.0.0.1
EOF
chattr +i /etc/resolv.conf
cat /etc/resolv.conf
ls -l /etc/resolv.conf

# coredns will resolve on localhost port 53.  DNS_SERVER_IPS are the custom resolver locations and was initialized
# by the terraform ibm_is_instance resource user_data
cat > Corefile <<EOF
.:53 {
    log
    forward .  $(cat DNS_SERVER_IPS)
    prometheus localhost:9253
}
EOF
cat Corefile
./coredns
```


Create a second ssh session to the on-premises Ubuntu instance that is running coredns, copy / paste the suggested output from the Terraform output.  A session will look like this:
```
ssh root@...
...
glb=backend.widgets.cogs
dig $glb
dig $glb; # try a few times
curl $glb/instance


while sleep 1; do curl --connect-timeout 2 $glb/instance; done
```
## start / stop instances with IBM Cloud CLI
If you have the IBM Cloud CLI you can stop / start the instances from a third terminal.  Or you can skip this section and use the IBM Cloud Console.
```
$ terraform output cloud
{
  "0" = {
    "dns_location" = "10.0.0.149"
    "instances" = {
      "0" = {
        "floating_ip" = "52.118.144.234"
        "id" = "0717_7c69b1c0-8e7c-485a-990c-2e90e201ee93
...
$ ibmcloud is instance-stop -f 0717_7c69b1c0-8e7c-485a-990c-2e90e201ee93
Creating action stop for instance 0717_7c69b1c0-8e7c-485a-990c-2e90e201ee93 under account ...

Type      stop
Created   2022-06-30T13:25:25-07:00
```

## start / stop instances with IBM Cloud Console
In a browser visit the [VPC Instances](https://cloud.ibm.com/vpc-ext/compute/vs) and notice there are instances with names based on zones.  The instances can be **Stopped** using the menu on the far right. Click on the menu then click **Stop** on a few and observe the curl in the while loop.  When you stop all of the instances in a zone notice the failure pattern.

Example, stopping us-south-1-0:

```
root@dnsglb-onprem:~# while sleep 1; do curl --connect-timeout 2 $glb/instance; done
...
dnsglb-us-south-1-0
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
dnsglb-us-south-2-0
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
...
dnsglb-us-south-2-0
dnsglb-us-south-2-0
dnsglb-us-south-2-0
...
```

Start up the instances to see them start up again:

```
$ ibmcloud is instance-start 0717_7c69b1c0-8e7c-485a-990c-2e90e201ee93
Creating action start for instance 0717_7c69b1c0-8e7c-485a-990c-2e90e201ee93 under account ...

Type      start
Created   2022-06-30T13:29:08-07:00
```

## Troubleshooting
The coredns ssh session should be generating two log messages each time a curl is executed in the second ssh session.  Like ths:
```
[INFO] 127.0.0.1:57408 - 35537 "A IN backend.widgets.cogs. udp 38 false 512" NOERROR qr,aa,rd,ra 74 0.000922732s
[INFO] 127.0.0.1:57408 - 56028 "AAAA IN backend.widgets.cogs. udp 38 false 512" NOERROR qr,aa,rd,ra 149 0.000998671s
```

```
$ terraform output cloud 
{
  "0" = {
    "dns_location" = "10.0.0.149"
    "instances" = {
      "0" = {
        "floating_ip" = "52.118.144.234"
        "ipv4_address" = "10.0.0.4"
        "ssh" = "ssh root@52.118.144.234"
      }
    }
    "lb_curl" = "curl 92cf5ee3-us-south.lb.appdomain.cloud/instance"
    "lb_hostname" = "92cf5ee3-us-south.lb.appdomain.cloud"
    "lb_private_ips" = [
      "10.0.0.132",
    ]
    "lb_public_ips" = []
  }
  "1" = {
    "dns_location" = "10.0.1.149"
    "instances" = {
      "0" = {
        "floating_ip" = "52.118.205.187"
        "ipv4_address" = "10.0.1.4"
        "ssh" = "ssh root@52.118.205.187"
      }
    }
    "lb_curl" = "curl af41ca5c-us-south.lb.appdomain.cloud/instance"
    "lb_hostname" = "af41ca5c-us-south.lb.appdomain.cloud"
    "lb_private_ips" = [
      "10.0.1.132",
    ]
    "lb_public_ips" = []
  }
}
```

There is one key ("0" and "1") per zone.  Notice the lb_ information.  From onprem try the lb_curl and the lb_private_ips

```
root@dnsglb1-onprem:~# curl 92cf5ee3-us-south.lb.appdomain.cloud/instance
dnsglb1-us-south-1-0
root@dnsglb1-onprem:~# curl af41ca5c-us-south.lb.appdomain.cloud/instance
dnsglb1-us-south-2-0
root@dnsglb1-onprem:~# curl 10.0.0.132/instance
dnsglb1-us-south-1-0
root@dnsglb1-onprem:~# curl 10.0.1.132/instance
dnsglb1-us-south-2-0
```

Try to ssh to the instances and to curl localhost:

```
root@dnsglb1-us-south-1-0:~# curl localhost/instance
dnsglb1-us-south-1-0
```

It will not be possible to curl the local IP address of the instances. This is a side effect of connecting them to the NLB:
```
root@dnsglb1-us-south-1-0:~# curl 10.0.1.4
^C
```

But it will be possible to curl the other intances:
```
root@dnsglb1-us-south-1-0:~# curl 10.0.1.132/instance
dnsglb1-us-south-2-0
```


## Schematics

Schematics is an IBM Cloud service that builds resources and maintains state. You can use this instead of Terraform on your laptop.

Create resources using schematics:
- Log in to the IBM Cloud.
- Click Schematics Workspaces.
- Click Create workspace to create a new workspace.
- Enter this respository, https://github.com/IBM-Cloud/vpc-dnsglb-nlb,for the GitHub repository.
- Select Terraform version terraform_v1.1.
- Click Next.
- Optionally change the Workspace details and click Next.
- Click Create.

In the new workspace Settings panel initialize the variables by clicking the menu selection on the left. You must provide values for the variables that do not have defaults.

- Click Apply plan to create the resources. Wait for completion.

Destroy resources using schematics:

Navigate to the the Schematics Workspace and open your workspace:
- Click Actions > Destroy resources.
- Wait for resources to be destroyed.
- Click Actions > Delete workspace.
##
