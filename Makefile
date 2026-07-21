TEST_IMAGE ?= otserv-test:local

.PHONY: test-static test-dev test-vps verify test-placeholder

test-static:
	docker build --file docker/test.Dockerfile --tag $(TEST_IMAGE) .
	docker run --rm --volume "$(CURDIR):/workspace:ro" $(TEST_IMAGE)

test-dev:
	sh tests/docker-build.sh
	sh scripts/smoke-development.sh

test-vps:
	@$(MAKE) --no-print-directory --silent test-placeholder SUITE=vps

verify:
	@$(MAKE) --no-print-directory --silent test-placeholder SUITE=verification

test-placeholder:
	@echo "ERROR: $(SUITE) test suite is not implemented" >&2
	@exit 2
