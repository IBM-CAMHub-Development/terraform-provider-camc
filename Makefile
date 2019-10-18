#
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2016, 2017. All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
TEST?=$$(go list ./... | grep -v '/vendor/')
VETARGS?=-all
GOFMT_FILES?=$$(find . -name '*.go' | grep -v vendor)
PLUGIN=provider-http


TERRAFORM_VERSION=v0.11.1
TERRAFORM_PROVIDER_SOFTLAYER_VERSION=	# Empty string means master version
BLUEMIX_GO_VERSION=						# Empty string means master version

default: test

tools:
	@go get github.com/kardianos/govendor
	@go get github.com/mitchellh/gox
	@go get golang.org/x/tools/cmd/cover

# bin generates the releaseable binary for your os and architecture
bin: fmtcheck vet tools 
	@sh -c "'$(CURDIR)/scripts/build.sh'"

# meant as a pre-step before publishing cross-platform binaries
bins: fmtcheck vet tools
	gox -os="linux darwin windows" -arch="amd64 arm" -ldflags="-s -w"

# test runs the unit tests
test: fmtcheck vet
	TF_ACC= go test $(TEST) $(TESTARGS) -timeout=30s -parallel=4

# testacc runs acceptance tests
# e.g make testacc TESTARGS="-run TestAccBluemixInfrastructureScaleGroup_Basic"
# Set env vars before running this - for example you can edit scripts/testAccEnv.sh
#   then do . scripts/testAccEnv.sh; make testacc
#
testacc: fmtcheck vet
	TF_ACC=1 go test $(TEST) -v $(TESTARGS) -timeout 120m

# testrace runs the race checker
testrace: fmtcheck vet
	TF_ACC= go test -race $(TEST) $(TESTARGS)

cover: tools
	go test $(TEST) -coverprofile=coverage.out
	go tool cover -html=coverage.out
	rm coverage.out

# vet runs the Go source code static analysis tool `vet` to find
# any common errors.
vet:
	@echo "go tool vet $(VETARGS) ."
	@go tool vet $(VETARGS) $$(ls -d */ | grep -v vendor) ; if [ $$? -eq 1 ]; then \
		echo ""; \
		echo "Vet found suspicious constructs. Please check the reported constructs"; \
		echo "and fix them if necessary before submitting the code for review."; \
		exit 1; \
	fi

fmt:
	gofmt -w $(GOFMT_FILES)

fmtcheck:
	@sh -c "'$(CURDIR)/scripts/gofmtcheck.sh'"

#
# Run this to recreate vendor contents
# Pre-req: Run this with a GOPATH that has no prereqs under src
#
#	mkdir -p $GOPATH/src/github.ibm.com/Orpheus
#	cd $GOPATH/src/github.ibm.com/Orpheus
#	git clone git@github.ibm.com:Orpheus/terraform-provider-bluemix.git
#
# Note:
#	to see the list of dependencies run govendor list --no-status +outside
#
deps:
	cd ${GOPATH}/src/github.ibm.com/Orpheus/terraform-provider-bluemix
	@echo "Removing current vendor contents ..."
	rm -rf vendor
	@echo "Initializing govendor ..."
	govendor init

	@echo "Getting terraform prereq at version ${TERRAFORM_VERSION} ..."
	go get github.com/hashicorp/terraform || true
	cd ${GOPATH}/src/github.com/hashicorp/terraform && git fetch origin && git checkout ${TERRAFORM_VERSION} 

	@echo "Getting terraform-provider-softlayer prereq at version ${TERRAFORM_PROVIDER_SOFTLAYER_VERSION} ..."
	go get github.com/softlayer/terraform-provider-softlayer || true
	cd ${GOPATH}/src/github.com/softlayer/terraform-provider-softlayer && git fetch origin && git checkout ${TERRAFORM_PROVIDER_SOFTLAYER_VERSION} 

	@echo "Getting bluemix-go prereq at version ${BLUEMIX_GO_VERSION} ..."
	cd ${GOPATH}/src/github.ibm.com/Orpheus/terraform-provider-bluemix
	go get github.ibm.com/Orpheus/bluemix-go || true
	cd ${GOPATH}/src/github.ibm.com/Orpheus/bluemix-go && git fetch origin && git checkout ${BLUEMIX_GO_VERSION} 

	@echo "Including terraform-provider-softlayer dependencies ..."
	for file in `ls ${GOPATH}/src/github.com/softlayer/terraform-provider-softlayer/vendor/ | grep -v vendor.json`; \
	do \
		cp -r ${GOPATH}/src/github.com/softlayer/terraform-provider-softlayer/vendor/$$file ${GOPATH}/src/github.ibm.com/Orpheus/terraform-provider-bluemix/vendor/; \
	done

	@echo "Adding dependencies other than terraform to vendor ..."
	cd ${GOPATH}/src/github.ibm.com/Orpheus/terraform-provider-bluemix
	govendor update github.com/softlayer/terraform-provider-softlayer/softlayer
	govendor update github.ibm.com/Orpheus/bluemix-go/session

	@echo "Checking for missing dependencies -- If no output then we are good"
	cd ${GOPATH}/src/github.ibm.com/Orpheus/terraform-provider-bluemix
	govendor list +missing
	

.PHONY: bin bins default test vet fmt fmtcheck tools deps
