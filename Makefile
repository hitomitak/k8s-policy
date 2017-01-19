.PHONY: all policy-controller docker-image clean

SRCDIR=.
CONTAINER_NAME=hitomitak/kube-policy-controller-ppc64le

default: all
all: policy-controller

# Build the calico/kube-policy-controller Docker container.
docker-image: image.created

# Run the unit tests.
ut: update-version
	docker run --rm -v `pwd`:/code \
	calico/test \
	nosetests tests/unit -c nose.cfg

# Makes tests on Circle CI.
test-circle: update-version
	# Can't use --rm on circle
	# Circle also requires extra options for reporting.
	docker run \
	-v `pwd`:/code \
	-v $(CIRCLE_TEST_REPORTS):/circle_output \
	-e COVERALLS_REPO_TOKEN=$(COVERALLS_REPO_TOKEN) \
	calico/test sh -c \
	'nosetests tests/unit -c nose.cfg \
	--with-xunit --xunit-file=/circle_output/output.xml; RC=$$?;\
	[[ ! -z "$$COVERALLS_REPO_TOKEN" ]] && coveralls || true; exit $$RC'

image.created: update-version
	# Build the docker image for the policy controller.
	docker build -t $(CONTAINER_NAME) . 
	touch image.created

# Update the version file.
update-version:
	echo "VERSION='`git describe --tags --dirty`'" > version.py

release: clean
ifndef VERSION
	$(error VERSION is undefined - run using make release VERSION=vX.Y.Z)
endif
	git tag $(VERSION)
	$(MAKE) image.created
	docker tag $(CONTAINER_NAME) $(CONTAINER_NAME):$(VERSION)
	docker tag $(CONTAINER_NAME) quay.io/$(CONTAINER_NAME):$(VERSION)

# Ensure reported version is correct.
	if ! docker run calico/kube-policy-controller:$(VERSION) version | grep '^$(VERSION)$$'; then echo "Reported version:" `docker run calico/kube-policy-controller:$(VERSION) version` "\nExpected version: $(VERSION)"; false; else echo "Version check passed\n"; fi

	@echo "Now push the tag and images."
	@echo "git push $(VERSION)"
	@echo "docker push calico/kube-policy-controller:$(VERSION)"
	@echo "docker push quay.io/calico/kube-policy-controller:$(VERSION)"

clean:
	find . -name '*.pyc' -exec rm -f {} +
	rm -rf dist image.created
	-docker rmi $(CONTAINER_NAME)

ci: clean docker-image
# Assumes that a few environment variables exist - BRANCH_NAME PULL_REQUEST_NUMBER
	set -e; \
	if [ -z $$PULL_REQUEST_NUMBER ]; then \
		docker tag $(CONTAINER_NAME) $(CONTAINER_NAME):$$BRANCH_NAME && docker push $(CONTAINER_NAME):$$BRANCH_NAME; \
		docker tag $(CONTAINER_NAME) quay.io/$(CONTAINER_NAME):$$BRANCH_NAME && docker push quay.io/$(CONTAINER_NAME):$$BRANCH_NAME; \
		if [ "$$BRANCH_NAME" = "master" ]; then \
			export VERSION=`git describe --tags --dirty`; \
			docker tag $(CONTAINER_NAME) $(CONTAINER_NAME):$$VERSION && docker push $(CONTAINER_NAME):$$VERSION; \
			docker tag $(CONTAINER_NAME) quay.io/$(CONTAINER_NAME):$$VERSION && docker push quay.io/$(CONTAINER_NAME):$$VERSION; \
		fi; \
	fi
