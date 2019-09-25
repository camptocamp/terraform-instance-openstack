test:
	summon terraform destroy -force
	summon terraform apply -auto-approve
	summon terraform plan -detailed-exitcode
	summon terraform destroy -force

clean:
	summon terraform destroy -force
