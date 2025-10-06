// ABOUTME: Manages the public suffix list data structure and matching logic
// ABOUTME: Handles loading, parsing, and querying the public suffix list

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub opaque type Suffix {
  Suffix(suffix: String, is_public: Bool, length: Int)
}

/// The suffix list data structure
pub opaque type SuffixList {
  SuffixList(
    normal: Dict(String, Suffix),
    wildcards: List(String),
    exceptions: Dict(String, Suffix),
  )
}

const dot = "."

const bang = "!"

const splat = "*"

const comment = "//"

const private_marker = "===BEGIN PRIVATE DOMAINS==="

/// Load the public suffix list from the data file
pub fn load(include_private: Bool) -> SuffixList {
  let assert Ok(content) = simplifile.read(from: "priv/public_suffix_list.dat")

  parse(content, include_private)
}

/// Parse the public suffix list content into a SuffixList
pub fn parse(content: String, include_private: Bool) -> SuffixList {
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
            case trimmed == "" || string.starts_with(trimmed, comment) {
              True -> acc
              False -> #(add_rule(sl, trimmed, is_public), is_public)
            }
          }
        }
      },
    )

  suffix_list
}

/// Add a single rule to the suffix list
fn add_rule(sl: SuffixList, rule: String, is_public: Bool) -> SuffixList {
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
      case string.starts_with(rule, splat <> dot) {
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

/// Find the matching public suffix for a hostname
pub fn find_suffix(host: String, suffix_list: SuffixList) -> Result(String, Nil) {
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
    let suffix = suffix_labels |> list.reverse() |> string.join(dot)

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
      let parent = string.join(list.reverse(rest), dot)
      case list.any(wildcards, fn(w) { w == parent }) {
        True -> {
          let matched = string.join(normal_order, dot)
          Ok(matched)
        }
        False -> Error(Nil)
      }
    }
  }
}
