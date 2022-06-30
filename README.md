# Regional load balancer accessable over direct link

This is a companion repository to the following blog post

![image](https://user-images.githubusercontent.com/6932057/176736173-ddad609c-85be-448e-a10a-d4bfbecedec4.png)


## Depoy resources

### Desktop Terraform

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

### Schematics

Schematics is an IBM Cloud service that builds resources and maintais state.

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

## On premises

The default ubuntu DNS resolver can be hard to follow.  Follow the instructions below to disable the default and use [coredns](https://coredns.io/)


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

# coredns will resolve on localhost port 53.  DNS_SERVER_IPS are the custom resolver locations
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

Create a second ssh session to the on premises ubuntu instance that is running coredns, copy/paste the suggested output from the terraform output.  A session will look like this:
```
ssh root@...
...
glb=backend.widgets.cogs
dig $glb
dig $glb; # try a few times
curl $glb/instance


while sleep 1; do curl --connect-timeout 2 $glb/instance; done

```

## Watching failures
Visit the [VPC Instances](https://cloud.ibm.com/vpc-ext/compute/vs) and notice there are instances in each zone based on variable instances.  The instances can be **Stopped** using the menu on the far right.  Click on the menu then click **Stop** on a few and observe the curl in the while loop.  When you stop all of the instances in a zone notice the failure pattern.

Example, stopping both us-south-1-0 and us-south-1-1:

```
root@dnsglb-onprem:~# while sleep 1; do curl --connect-timeout 2 $glb/instance; done
...
dnsglb-us-south-1-0
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
dnsglb-us-south-2-1
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
dnsglb-us-south-2-0
dnsglb-us-south-3-1
dnsglb-us-south-3-1
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
dnsglb-us-south-3-1
dnsglb-us-south-3-1
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
dnsglb-us-south-3-1
dnsglb-us-south-2-1
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
curl: (7) Failed to connect to backend.widgets.cogs port 80: Connection refused
dnsglb-us-south-3-1
dnsglb-us-south-3-1
dnsglb-us-south-2-0
dnsglb-us-south-2-1
dnsglb-us-south-2-0
```

Start up the instances to see them start up again.

## Troubleshooting

Notes:

The terraform output shows info sorted into zone and instance





## todo

maybe
```
cat > /etc/NetworkManager/NetworkManager.conf <<EOF
dns=none
EOF
service network-manager restart
```

ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

```
vi /etc/systemd/resolved.conf
  DNSStubListener=no
vi /etc/resolv.conf
```

 /etc/NetworkManager/dispatcher.d/hook-network-manager


## todo
- onprem /etc/systemd/resolved.conf
