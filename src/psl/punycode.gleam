// ABOUTME: Punycode decoding for internationalized domain names
// ABOUTME: Converts xn-- prefixed labels to UTF-8 using Erlang's idna library

import gleam/string

// External call to Erlang's idna library - returns a charlist
@external(erlang, "idna", "to_unicode")
fn idna_to_unicode(domain: String) -> String

// Decode a domain that may contain punycode labels
pub fn decode_domain(domain: String) -> String {
  // Check if domain contains any punycode (xn--)
  case string.contains(domain, "xn--") {
    False -> domain
    True -> idna_to_unicode(domain)
  }
}
