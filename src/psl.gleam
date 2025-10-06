// ABOUTME: Domain parsing library using the public suffix list
// ABOUTME: Parses URIs into domain components (subdomains, domain, suffix)

import gleam/option.{None, Some}
import gleam/result
import gleam/uri
import psl/domain
import psl/punycode
import psl/suffix_list

/// Re-export DomainParts for public API
///
/// See domain.gleam for documentation.
pub type DomainParts =
  domain.DomainParts

/// Re-export SuffixList for public API
///
/// See suffix_list.gleam for documentation.
pub type SuffixList =
  suffix_list.SuffixList

/// Errors that can occur during parsing
pub type ParseError {
  InvalidUri
  NoHost
  InvalidDomain
  UnknownSuffix
}

/// Load the public suffix list from the embedded data file and choose to
/// include private domains or not.
///
/// Use this to pre-load the suffix list when parsing multiple URIs.
pub fn load_suffix_list(include_private: Bool) -> SuffixList {
  suffix_list.load(include_private)
}

/// Parse a URI and extract domain parts
///
/// Note: This function loads the suffix list on every call. For better
///       performance when parsing multiple URIs, use `parse_with_list()` with
///       a cached suffix list.
pub fn parse(
  uri_string: String,
  include_private: Bool,
) -> Result(DomainParts, ParseError) {
  let list = load_suffix_list(include_private)
  parse_with_list(uri_string, list)
}

/// Parse a URI and extract domain parts using a pre-loaded suffix list
///
/// For better performance when parsing multiple URIs, load the suffix list
/// once using `load_suffix_list()` and reuse it:
///
/// ```gleam
/// let list = load_suffix_list()
/// let result1 = parse_with_list("https://example.com", list)
/// let result2 = parse_with_list("https://test.co.uk", list)
/// ```
pub fn parse_with_list(
  uri_string: String,
  list: suffix_list.SuffixList,
) -> Result(DomainParts, ParseError) {
  use parsed_uri <- result.try(
    uri.parse(uri_string)
    |> result.replace_error(InvalidUri),
  )

  use host <- result.try(case parsed_uri.host {
    Some(h) -> Ok(h)
    None -> Error(NoHost)
  })

  // Decode punycode to UTF-8 for suffix lookup
  let decoded_host = punycode.decode_domain(host)

  use suffix <- result.try(
    suffix_list.find_suffix(decoded_host, list)
    |> result.replace_error(UnknownSuffix),
  )

  domain.extract_parts(decoded_host, suffix)
  |> result.map_error(fn(_) { InvalidDomain })
}
