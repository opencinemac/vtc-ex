# Installs command line tools for development
.PHONY: install-dev
install-dev:
	mix deps.get

.PHONY: test
test:
	-mix test --cover --warnings-as-errors

.PHONY: lint
lint:
	-mix format --check-formatted
	-mix dialyzer
	-mix credo --strict
	-find . -type f | grep -e "\.ex$$" -e "\.exs$$" | grep -v zdevelop/ | grep -v _build | grep -v deps | xargs misspell -error

.PHONY: format
format:
	-mix format

.PHONY: doc
doc:
	mix docs
	sleep 1
	open doc/index.html

# Installs command line tools for development
.PHONY: install-tools
install-tools:
	# Catches misspelling
	-go install github.com/client9/misspell/cmd/misspell@latest