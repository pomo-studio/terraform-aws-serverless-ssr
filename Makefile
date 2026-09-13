.PHONY: test test-integration test-upgrade-gate fmt validate

## Credential-free tests of plan policy and TFC plan-only orchestration
test-upgrade-gate:
	python3 -m unittest discover -s tests -p 'test_upgrade*.py' -v

## Run all unit tests
test:
	terraform test

## Run integration tests against a deployed CloudFront distribution
test-integration:
	./tests/integration.sh

## Check Terraform formatting
fmt:
	terraform fmt -check -recursive

## Validate all examples
validate:
	cd examples/basic && terraform init -backend=false -upgrade && terraform validate
	cd examples/complete && terraform init -backend=false -upgrade && terraform validate
