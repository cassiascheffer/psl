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
import gleam/option.{None}
import psl

pub fn main() {
  // Load the public suffix list (include private domains)
  let list = psl.load_suffix_list(True, None)

  // Parse a simple domain
  let assert Ok(parts) = psl.parse("https://gleam.run", list)
  // parts.transit_routing_domain -> ""
  // parts.second_level_domain -> "gleam"
  // parts.top_level_domain -> "run"
  // parts.subdomain_parts -> []

  // Parse a domain with a subdomain
  let assert Ok(parts) = psl.parse("https://packages.gleam.run", list)
  // parts.transit_routing_domain -> "packages"
  // parts.second_level_domain -> "gleam"
  // parts.top_level_domain -> "run"
  // parts.subdomain_parts -> ["packages"]

  let assert Ok(parts) = psl.parse("https://fun.packages.gleam.run", list)
  // parts.transit_routing_domain -> "fun.packages"
  // parts.second_level_domain -> "gleam"
  // parts.top_level_domain -> "run"
  // parts.subdomain_parts -> ["fun", "packages"]

  // Parse UTF-8
  let assert Ok(parts) = psl.parse("https://gleam.مليسيا", list)
  // parts.transit_routing_domain -> ""
  // parts.second_level_domain -> "gleam"
  // parts.top_level_domain -> "مليسيا"  (decoded from punycode)
  // parts.subdomain_parts -> []

  // Parse punycode domains
  // Punycode domains (xn--) are decoded to UTF-8
  let assert Ok(parts) = psl.parse("https://gleam.xn--mgbx4cd0ab", list)
  // parts.transit_routing_domain -> ""
  // parts.second_level_domain -> "gleam"
  // parts.top_level_domain -> "مليسيا"  (decoded from punycode)
  // parts.subdomain_parts -> []
}
```

### Using Your Own List

You can provide your own public suffix list file instead of using the bundled
one:

```gleam
import gleam/option.{Some}
import psl

pub fn main() {
  // Load a custom suffix list
  let list = psl.load_suffix_list(True, Some("path/to/list.dat"))

  let assert Ok(parts) = psl.parse("https://gleam.run", list)
}
```

### Adding Custom Rules

You can add your own rules for private DNS domains that are not on the Public
Suffix List:

```gleam
import gleam/option.{None}
import psl

pub fn main() {
  // Load the standard list
  let list = psl.load_suffix_list(True, None)

  // Add a custom rule for your private domain
  // Normal domains: mysuffix"
  // Wildcards: "*mysuffix"
  // Exceptions: "!www.mysuffix"
  let list = psl.add_rule(list, "mysuffix", False)


  let assert Ok(parts) = psl.parse("https://neat.gleam.mysuffix", list)
  // parts.second_level_domain -> "gleam"
  // parts.top_level_domain -> "mysuffix"
}
```

## Credits

- Inspired by [publicsuffix-ruby](https://github.com/weppos/publicsuffix-ruby) by Simone Carletti
- Uses the [Public Suffix List](https://publicsuffix.org/) maintained by Mozilla

## Licence

Apache-2.0
