// ABOUTME: Handles extraction of domain components from hostnames
// ABOUTME: Separates hostnames into TLD, SLD, TRD, and subdomain parts

import gleam/list
import gleam/string

/// Represents the parsed components of a domain
/// Definitions
/// top_level_domain or TLD is the last part of a domain name before the paths.
/// For example, in https://packages.gleam.run, "run" is the TLD.
///
/// second_level_domain or SLD is the part of a domain name before the TLD,
/// separated by a ".". For example, in https://packages.gleam.run, "gleam" is
/// the SLD.
///
/// transit_routing_domain or TRD is the first part of a domain name and may
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

/// Error type for domain extraction
pub type ExtractionError {
  InvalidDomain
}

/// Extract domain parts from hostname and suffix
pub fn extract_parts(
  host: String,
  suffix: String,
) -> Result(DomainParts, ExtractionError) {
  let host_labels = string.split(host, ".")
  let suffix_labels = string.split(suffix, ".")

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
