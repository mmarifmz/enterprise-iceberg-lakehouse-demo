.PHONY: check download core verify-core deploy demo destroy

check:
	python scripts/check_repo.py

download:
	python scripts/download_adventureworks.py --output data/adventureworks

core:
	powershell -ExecutionPolicy Bypass -File scripts/deploy-core-local.ps1

verify-core:
	powershell -ExecutionPolicy Bypass -File scripts/verify-core-local.ps1

deploy:
	powershell -ExecutionPolicy Bypass -File scripts/deploy-local.ps1

demo:
	powershell -ExecutionPolicy Bypass -File scripts/run-demo.ps1

destroy:
	powershell -ExecutionPolicy Bypass -File scripts/destroy-local.ps1
