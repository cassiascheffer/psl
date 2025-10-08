import gleam/option.{None, Some}
import gleeunit
import global_value
import psl

pub type TestGlobalData {
  TestGlobalData(public_list: psl.SuffixList, private_list: psl.SuffixList)
}

pub fn global_data() -> TestGlobalData {
  global_value.create_with_unique_name("psl.list", fn() {
    TestGlobalData(
      public_list: psl.load_suffix_list(True, None),
      private_list: psl.load_suffix_list(False, None),
    )
  })
}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn simple_com_domain_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://gleam.com", list)
  assert parts.transit_routing_domain == ""
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "com"
  assert parts.subdomain_parts == []
}

pub fn simple_com_domain_with_subdomain_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://www.gleam.com", list)
  assert parts.transit_routing_domain == "www"
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "com"
  assert parts.subdomain_parts == ["www"]
}

pub fn multiple_subdomains_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://glow.glam.gleam.com", list)
  assert parts.transit_routing_domain == "glow.glam"
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "com"
  assert parts.subdomain_parts == ["glow", "glam"]
}

pub fn multi_part_suffix() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://gleam.airline.aero", list)
  assert parts.transit_routing_domain == ""
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "airline.aero"
  assert parts.subdomain_parts == []
}

pub fn multi_part_suffix_with_subdomain_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://www.gleam.airline.aero", list)
  assert parts.transit_routing_domain == "www"
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "airline.aero"
  assert parts.subdomain_parts == ["www"]
}

pub fn multi_part_suffix_with_multiple_subdomains_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://glow.glam.gleam.airline.aero", list)
  assert parts.transit_routing_domain == "glow.glam"
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "airline.aero"
  assert parts.subdomain_parts == ["glow", "glam"]
}

pub fn http_scheme_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("http://www.gleam.run", list)
  assert parts.transit_routing_domain == "www"
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "run"
  assert parts.subdomain_parts == ["www"]
}

pub fn uri_with_path_test() {
  let list = global_data().public_list
  let assert Ok(parts) =
    psl.parse("https://packages.gleam.run/?search=glam", list)
  assert parts.transit_routing_domain == "packages"
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "run"
  assert parts.subdomain_parts == ["packages"]
}

pub fn uri_with_port_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://gleam.run:8080", list)
  assert parts.transit_routing_domain == ""
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "run"
  assert parts.subdomain_parts == []
}

// Error cases
pub fn invalid_uri_test() {
  let list = global_data().public_list
  let assert Error(_) = psl.parse("not a uri", list)
}

pub fn no_host_test() {
  let list = global_data().public_list
  let assert Error(_) = psl.parse("https://", list)
}

pub fn just_tld_test() {
  let list = global_data().public_list
  let assert Error(_) = psl.parse("https://com", list)
}

// Wildcard tests
pub fn wildcard_suffix_test() {
  // *.ck means any label under .ck is a public suffix
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://gleam.wow.ck", list)
  assert parts.transit_routing_domain == ""
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "wow.ck"
  assert parts.subdomain_parts == []
}

pub fn wildcard_suffix_with_subdomain_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://www.gleam.wow.ck", list)
  assert parts.transit_routing_domain == "www"
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "wow.ck"
  assert parts.subdomain_parts == ["www"]
}

// Exception tests (exceptions override wildcards)
pub fn exception_overrides_wildcard_test() {
  // !www.ck is an exception to *.ck, so www.ck is NOT a public suffix
  // This means the public suffix is just "ck", allowing www.ck to be registered
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://www.ck", list)
  assert parts.transit_routing_domain == ""
  assert parts.second_level_domain == "www"
  assert parts.top_level_domain == "ck"
  assert parts.subdomain_parts == []
}

pub fn exception_with_subdomain_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://subdomain.www.ck", list)
  assert parts.transit_routing_domain == "subdomain"
  assert parts.second_level_domain == "www"
  assert parts.top_level_domain == "ck"
  assert parts.subdomain_parts == ["subdomain"]
}

pub fn exception_city_kawasaki_test() {
  // !city.kawasaki.jp is an exception to *.kawasaki.jp
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://gleamcity.kawasaki.jp", list)
  assert parts.transit_routing_domain == ""
  assert parts.second_level_domain == "gleamcity"
  assert parts.top_level_domain == "kawasaki.jp"
  assert parts.subdomain_parts == []
}

// UTF-8/Punycode handling test
// Test that parser handles punycode (xn--) domains correctly
// xn--mgbx4cd0ab ("Malaysia", Malay) : MY
//مليسيا
pub fn punycode_domain_handling_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://example.xn--mgbx4cd0ab", list)
  assert parts.transit_routing_domain == ""
  assert parts.second_level_domain == "example"
  assert parts.top_level_domain == "مليسيا"
  assert parts.subdomain_parts == []
}

pub fn private_domain_public_only_test() {
  let list = global_data().private_list
  let assert Ok(parts) = psl.parse("https://gleam.blogspot.com", list)
  assert parts.transit_routing_domain == "gleam"
  assert parts.second_level_domain == "blogspot"
  assert parts.top_level_domain == "com"
  assert parts.subdomain_parts == ["gleam"]
}

pub fn private_domain_with_private_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://gleam.blogspot.com", list)
  assert parts.transit_routing_domain == ""
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "blogspot.com"
  assert parts.subdomain_parts == []
}

pub fn private_domain_with_subdomain_public_only_test() {
  let list = global_data().private_list
  let assert Ok(parts) = psl.parse("https://www.gleam.blogspot.com", list)
  assert parts.transit_routing_domain == "www.gleam"
  assert parts.second_level_domain == "blogspot"
  assert parts.top_level_domain == "com"
  assert parts.subdomain_parts == ["www", "gleam"]
}

pub fn private_domain_with_subdomain_with_private_test() {
  let list = global_data().public_list
  let assert Ok(parts) = psl.parse("https://www.gleam.blogspot.com", list)
  assert parts.transit_routing_domain == "www"
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "blogspot.com"
  assert parts.subdomain_parts == ["www"]
}

pub fn custom_list_test() {
  let list = psl.load_suffix_list(True, Some("priv/test_list.dat"))
  let assert Ok(parts) = psl.parse("https://gleam.neat", list)
  assert parts.transit_routing_domain == ""
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "neat"
  assert parts.subdomain_parts == []
}

pub fn adding_a_rule_test() {
  let list = psl.load_suffix_list(True, Some("priv/test_list.dat"))
  let list = psl.add_rule(list, "gleam", True)
  let assert Ok(parts) = psl.parse("https://gleam.gleam.gleam", list)
  assert parts.transit_routing_domain == "gleam"
  assert parts.second_level_domain == "gleam"
  assert parts.top_level_domain == "gleam"
  assert parts.subdomain_parts == ["gleam"]
}
