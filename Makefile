TEST_IMAGE ?= otserv-test:local

.PHONY: test-static test-dev test-vps verify test-placeholder

test-static:
	docker build --file docker/test.Dockerfile --tag $(TEST_IMAGE) .
	docker run --rm --volume "$(CURDIR):/workspace:ro" $(TEST_IMAGE)

test-dev:
	@$(MAKE) --no-print-directory --silent test-placeholder SUITE=development

test-vps:
	@$(MAKE) --no-print-directory --silent test-placeholder SUITE=vps

verify:
	@$(MAKE) --no-print-directory --silent test-placeholder SUITE=verification

test-placeholder:
	@echo "ERROR: $(SUITE) test suite is not implemented" >&2
	@exit 2
