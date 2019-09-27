test:
	make clean
	summon terraform apply -target openstack_networking_network_v2.standard_rancher_host -auto-approve
	summon terraform apply -auto-approve
	summon terraform plan -detailed-exitcode
	make clean

clean:
	summon terraform apply -target openstack_networking_network_v2.standard_rancher_host -auto-approve
	summon terraform destroy -target module.instance -force
	summon terraform destroy -force
