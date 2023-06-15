# Contributing

NOTE: This document is under developement.

## Making a PR

Please make pull requests based off the `dev` branch into the `dev` branch. The release
CI pipleine adds additional files to the `main` branch whenever a PR is merged.

## Running lints

To run all linters that will be run in CI:

```
make line
```

You'll need to install the following non-elixir programs:

- [misspell](https://github.com/client9/misspell)

## Running tests

To run all tests with coverage reports:

```
make test
```

Vtc offers optional Postgres extensions. If you do not have a Posgres instanve running
locally you can skip those tests like so:

```
mix test --exclude :postgres
```

Or:

```
mix test --exclude :ecto
```
