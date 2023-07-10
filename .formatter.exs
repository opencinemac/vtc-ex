# Used by "mix format"
[
  plugins: [Styler, ExamplesStyler],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "lib/ecto/postgres/**/*.{ex,exs}",
    "README.md",
    "zdocs/quickstart.cheatmd"
  ]
]
