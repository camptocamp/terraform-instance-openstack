test:
	make clean
	summon terraform apply -auto-approve
	summon terraform plan -detailed-exitcode
	make clean

clean:
	summon terraform destroy -force
