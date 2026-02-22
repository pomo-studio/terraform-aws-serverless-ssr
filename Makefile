.PHONY: test test-integration fmt validate

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
