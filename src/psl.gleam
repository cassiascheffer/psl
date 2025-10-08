import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import simplifile

const splat = "*"

const dot = "."

const bang = "!"

const comment_marker = "//"

const private_marker = "===BEGIN PRIVATE DOMAINS==="

/// Represents the parsed components of a domain
///
/// Definitions
///
/// **top_level_domain** or TLD is the last part of a domain name before the paths.
/// For example, in https://packages.gleam.run, "run" is the TLD.
///
/// **second_level_domain** or SLD is the part of a domain name before the TLD,
/// separated by a ".". For example, in https://packages.gleam.run, "gleam" is
/// the SLD.
///
/// **transit_routing_domain** or TRD is the first part of a domain name and may
/// have more than one part. For example, in https://packages.gleam.run,
/// "packages" is the TRD and in https://cool.packages.gleam.run
/// "cool.packages" is the TRD.
///
/// We return "subdomain_parts" that splits the TRD on ".".
pub type DomainParts {
  DomainParts(
    top_level_domain: String,
    second_level_domain: String,
    transit_routing_domain: String,
    subdomain_parts: List(String),
  )
}

/// Errors that can occur during parsing
pub type ParseError {
  InvalidUri
  NoHost
  InvalidDomain
  UnknownSuffix
}

/// The suffix list data structure
pub opaque type SuffixList {
  SuffixList(
    normal: Dict(String, Suffix),
    wildcards: List(String),
    exceptions: Dict(String, Suffix),
  )
}

// An individual suffix record.
type Suffix {
  Suffix(suffix: String, is_public: Bool, length: Int)
}

/// Load the public suffix list from the a data file and choose to
/// include private domains or not. Pass a file path to include your own list
/// or leave `path` empty to load the one included in the package.
pub fn load_suffix_list(
  include_private: Bool,
  path: Option(String),
) -> SuffixList {
  let file_path = case path {
    Some(p) -> p
    None -> "priv/public_suffix_list.dat"
  }

  let assert Ok(content) = simplifile.read(from: file_path)
  let domain_data = case include_private {
    True -> content
    False -> {
      case string.split_once(content, private_marker) {
        Ok(#(public_domains, _private_domains)) -> public_domains
        Error(_) -> content
      }
    }
  }
  let #(suffix_list, _) =
    domain_data
    |> string.split("\n")
    |> list.fold(
      #(SuffixList(dict.new(), list.new(), dict.new()), True),
      fn(acc, line) {
        let #(sl, is_public) = acc
        let trimmed = string.trim(line)

        // Check if we've entered the private domains section
        case string.contains(trimmed, private_marker) {
          True ->
            case include_private {
              // Toggle is_public to False
              True -> #(sl, False)
              // No Need to continue
              False -> acc
            }
          False -> {
            // Skip empty lines and comments
            case trimmed == "" || string.starts_with(trimmed, comment_marker) {
              True -> acc
              False -> #(add_rule(sl, trimmed, is_public), is_public)
            }
          }
        }
      },
    )

  suffix_list
}

/// Parse a URI and extract domain parts
///
/// ```gleam
/// let list = load_suffix_list(True, None)
/// let result1 = parse("https://example.com", list)
/// let result2 = parse("https://test.co.uk", list)
/// ```
pub fn parse(
  uri_string: String,
  list: SuffixList,
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
  let decoded_host = decode_domain(host)

  use suffix <- result.try(
    find_suffix(decoded_host, list)
    |> result.replace_error(UnknownSuffix),
  )

  extract_parts(decoded_host, suffix)
  |> result.map_error(fn(_) { InvalidDomain })
}

/// Add a single rule to the suffix list. This is useful if a suffix is not yet
/// in the list provided by publicsuffix.org.
///
/// Rules are formatted as follows:
///
/// * Normal domaains do not start with a special character.
/// * Exceptions start with a "!".
/// * Wildcards start with a "*".
pub fn add_rule(sl: SuffixList, rule: String, is_public: Bool) -> SuffixList {
  case string.starts_with(rule, bang) {
    True -> {
      let suffix_str = string.drop_start(rule, 1)
      let suffix = Suffix(suffix_str, is_public, string.length(suffix_str))
      SuffixList(
        ..sl,
        exceptions: dict.insert(sl.exceptions, suffix_str, suffix),
      )
    }
    False ->
      case string.starts_with(rule, splat <> ".") {
        True -> {
          let pattern = string.drop_start(rule, 2)
          let suffix = Suffix(pattern, is_public, string.length(pattern))
          SuffixList(
            normal: dict.insert(sl.normal, pattern, suffix),
            wildcards: [pattern, ..sl.wildcards],
            exceptions: sl.exceptions,
          )
        }
        False -> {
          let suffix = Suffix(rule, is_public, string.length(rule))
          SuffixList(..sl, normal: dict.insert(sl.normal, rule, suffix))
        }
      }
  }
}

/// Extract domain parts from hostname and suffix
fn extract_parts(
  host: String,
  suffix: String,
) -> Result(DomainParts, ParseError) {
  let host_labels = string.split(host, dot)
  let suffix_labels = string.split(suffix, dot)

  case list.length(host_labels) <= list.length(suffix_labels) {
    True -> Error(InvalidDomain)
    False -> {
      let remaining_count =
        list.length(host_labels) - list.length(suffix_labels)

      case remaining_count {
        0 -> Error(InvalidDomain)
        _ -> {
          let remaining = list.take(host_labels, remaining_count)

          case list.reverse(remaining) {
            [] -> Error(InvalidDomain)
            [domain, ..rest] -> {
              let subdomains = list.reverse(rest)
              Ok(DomainParts(
                top_level_domain: suffix,
                second_level_domain: domain,
                transit_routing_domain: string.join(subdomains, "."),
                subdomain_parts: subdomains,
              ))
            }
          }
        }
      }
    }
  }
}

// External call to Erlang's idna library - returns a charlist
@external(erlang, "idna", "to_unicode")
fn idna_to_unicode(domain: String) -> String

// Decode a domain that may contain punycode labels
fn decode_domain(domain: String) -> String {
  // Check if domain contains any punycode (xn--)
  case string.contains(domain, "xn--") {
    False -> domain
    True -> idna_to_unicode(domain)
  }
}

/// Find the matching public suffix for a hostname
fn find_suffix(host: String, suffix_list: SuffixList) -> Result(String, Nil) {
  let labels = string.split(host, dot)

  // Try to find the longest matching suffix
  let matches = find_all_matches(labels, suffix_list)

  case matches {
    [] -> Error(Nil)
    _ -> {
      // Return the longest match
      matches
      |> list.sort(fn(a, b) { int.compare(string.length(b), string.length(a)) })
      |> list.first()
      |> result.replace_error(Nil)
    }
  }
}

/// Find all matching suffixes for the given labels
fn find_all_matches(
  labels: List(String),
  suffix_list: SuffixList,
) -> List(String) {
  let reversed = list.reverse(labels)

  // Generate all possible suffix combinations
  list.range(1, list.length(labels))
  |> list.filter_map(fn(i) {
    let suffix_labels = list.take(reversed, i)
    let suffix = suffix_labels |> list.reverse() |> string.join(".")

    // Check for exception rules first - exceptions mean "NOT a public suffix"
    // so we skip them and don't include them in matches
    case dict.has_key(suffix_list.exceptions, suffix) {
      True -> Error(Nil)
      False -> {
        // Check for exact match
        case dict.has_key(suffix_list.normal, suffix) {
          True -> Ok(suffix)
          False -> {
            // Check for wildcard match
            case check_wildcard_match(suffix_labels, suffix_list.wildcards) {
              Ok(matched) -> Ok(matched)
              Error(_) -> Error(Nil)
            }
          }
        }
      }
    }
  })
}

/// Check if a suffix matches any wildcard pattern
fn check_wildcard_match(
  suffix_labels: List(String),
  wildcards: List(String),
) -> Result(String, Nil) {
  // suffix_labels is in reverse order (TLD first)
  // For *.ck matching "something.ck", suffix_labels = ["ck", "something"]
  // We need to extract the parent "ck" to match against the wildcard pattern
  let normal_order = list.reverse(suffix_labels)
  case normal_order {
    [] -> Error(Nil)
    [_] -> Error(Nil)
    [_, ..rest] -> {
      // rest is the parent domain labels, e.g., ["ck"] for "something.ck"
      let parent = string.join(list.reverse(rest), ".")
      case list.any(wildcards, fn(w) { w == parent }) {
        True -> {
          let matched = string.join(normal_order, ".")
          Ok(matched)
        }
        False -> Error(Nil)
      }
    }
  }
}
