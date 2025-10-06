# psl 🎃🌶️☕

[![Package Version](https://img.shields.io/hexpm/v/psl)](https://hex.pm/packages/psl)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/psl/)

A Gleam package for parsing domain names into their component parts using the
[Public Suffix List](https://publicsuffix.org/).

## Installation

Add `psl` to your Gleam project:

```sh
gleam add psl
```

## Usage

```gleam
import psl

pub fn main() {
  // Parse a simple domain
  let assert Ok(parts) = psl.parse("https://gleam.run")
  // parts.transit_routing_domain -> ""
  // parts.second_level_domain -> "gleam"
  // parts.top_level_domain -> "run"
  // parts.subdomain_parts -> []

  // Parse a domain with a subdomain
  let assert Ok(parts) = psl.parse("https://packages.gleam.run")
  // parts.transit_routing_domain -> "packages"
  // parts.second_level_domain -> "gleam"
  // parts.top_level_domain -> "run"
  // parts.subdomain_parts -> ["packages"]

  let assert Ok(parts) = psl.parse("https://fun.packages.gleam.run")
  // parts.transit_routing_domain -> "fun.packages"
  // parts.second_level_domain -> "gleam"
  // parts.top_level_domain -> "run"
  // parts.subdomain_parts -> ["fun", "packages"]
}
```

## Credits

- Inspired by [publicsuffix-ruby](https://github.com/weppos/publicsuffix-ruby) by Simone Carletti
- Uses the [Public Suffix List](https://publicsuffix.org/) maintained by Mozilla

## Licence

Apache-2.0
