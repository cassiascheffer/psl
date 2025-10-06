import gleeunit
import gleeunit/should
import psl

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn simple_com_domain_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("https://gleam.com", list)
  parts.transit_routing_domain |> should.equal("")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("com")
  parts.subdomain_parts |> should.equal([])
}

pub fn simple_com_domain_with_subdomain_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("https://www.gleam.com", list)
  parts.transit_routing_domain |> should.equal("www")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("com")
  parts.subdomain_parts |> should.equal(["www"])
}

pub fn multiple_subdomains_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) =
    psl.parse_with_list("https://glow.glam.gleam.com", list)
  parts.transit_routing_domain |> should.equal("glow.glam")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("com")
  parts.subdomain_parts |> should.equal(["glow", "glam"])
}

pub fn multi_part_suffix() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("https://gleam.airline.aero", list)
  parts.transit_routing_domain |> should.equal("")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("airline.aero")
  parts.subdomain_parts |> should.equal([])
}

pub fn multi_part_suffix_with_subdomain_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) =
    psl.parse_with_list("https://www.gleam.airline.aero", list)
  parts.transit_routing_domain |> should.equal("www")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("airline.aero")
  parts.subdomain_parts |> should.equal(["www"])
}

pub fn multi_part_suffix_with_multiple_subdomains_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) =
    psl.parse_with_list("https://glow.glam.gleam.airline.aero", list)
  parts.transit_routing_domain |> should.equal("glow.glam")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("airline.aero")
  parts.subdomain_parts |> should.equal(["glow", "glam"])
}

pub fn http_scheme_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("http://www.gleam.run", list)
  parts.transit_routing_domain |> should.equal("www")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("run")
  parts.subdomain_parts |> should.equal(["www"])
}

pub fn uri_with_path_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) =
    psl.parse_with_list("https://packages.gleam.run/?search=glam", list)
  parts.transit_routing_domain |> should.equal("packages")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("run")
  parts.subdomain_parts |> should.equal(["packages"])
}

pub fn uri_with_port_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("https://gleam.run:8080", list)
  parts.transit_routing_domain |> should.equal("")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("run")
  parts.subdomain_parts |> should.equal([])
}

// Error cases
pub fn invalid_uri_test() {
  let list = psl.load_suffix_list(True)
  psl.parse_with_list("not a uri", list)
  |> should.be_error()
}

pub fn no_host_test() {
  let list = psl.load_suffix_list(True)
  psl.parse_with_list("https://", list)
  |> should.be_error()
}

pub fn just_tld_test() {
  let list = psl.load_suffix_list(True)
  psl.parse_with_list("https://com", list)
  |> should.be_error()
}

// Wildcard tests
pub fn wildcard_suffix_test() {
  // *.ck means any label under .ck is a public suffix
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("https://gleam.wow.ck", list)
  parts.transit_routing_domain |> should.equal("")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("wow.ck")
  parts.subdomain_parts |> should.equal([])
}

pub fn wildcard_suffix_with_subdomain_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("https://www.gleam.wow.ck", list)
  parts.transit_routing_domain |> should.equal("www")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("wow.ck")
  parts.subdomain_parts |> should.equal(["www"])
}

// Exception tests (exceptions override wildcards)
pub fn exception_overrides_wildcard_test() {
  // !www.ck is an exception to *.ck, so www.ck is NOT a public suffix
  // This means the public suffix is just "ck", allowing www.ck to be registered
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("https://www.ck", list)
  parts.transit_routing_domain |> should.equal("")
  parts.second_level_domain |> should.equal("www")
  parts.top_level_domain |> should.equal("ck")
  parts.subdomain_parts |> should.equal([])
}

pub fn exception_with_subdomain_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("https://subdomain.www.ck", list)
  parts.transit_routing_domain |> should.equal("subdomain")
  parts.second_level_domain |> should.equal("www")
  parts.top_level_domain |> should.equal("ck")
  parts.subdomain_parts |> should.equal(["subdomain"])
}

pub fn exception_city_kawasaki_test() {
  // !city.kawasaki.jp is an exception to *.kawasaki.jp
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) =
    psl.parse_with_list("https://gleamcity.kawasaki.jp", list)
  parts.transit_routing_domain |> should.equal("")
  parts.second_level_domain |> should.equal("gleamcity")
  parts.top_level_domain |> should.equal("kawasaki.jp")
  parts.subdomain_parts |> should.equal([])
}

// UTF-8/Punycode handling test
// Test that parser handles punycode (xn--) domains correctly
// xn--mgbx4cd0ab ("Malaysia", Malay) : MY
//مليسيا
pub fn punycode_domain_handling_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) =
    psl.parse_with_list("https://example.xn--mgbx4cd0ab", list)
  parts.transit_routing_domain |> should.equal("")
  parts.second_level_domain |> should.equal("example")
  parts.top_level_domain |> should.equal("مليسيا")
  parts.subdomain_parts |> should.equal([])
}

pub fn private_domain_blogspot_public_only_test() {
  let list = psl.load_suffix_list(False)
  let assert Ok(parts) = psl.parse_with_list("https://gleam.blogspot.com", list)
  parts.transit_routing_domain |> should.equal("gleam")
  parts.second_level_domain |> should.equal("blogspot")
  parts.top_level_domain |> should.equal("com")
  parts.subdomain_parts |> should.equal(["gleam"])
}

pub fn private_domain_blogspot_with_private_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) = psl.parse_with_list("https://gleam.blogspot.com", list)
  parts.transit_routing_domain |> should.equal("")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("blogspot.com")
  parts.subdomain_parts |> should.equal([])
}

pub fn private_domain_blogspot_with_subdomain_public_only_test() {
  let list = psl.load_suffix_list(False)
  let assert Ok(parts) =
    psl.parse_with_list("https://www.gleam.blogspot.com", list)
  parts.transit_routing_domain |> should.equal("www.gleam")
  parts.second_level_domain |> should.equal("blogspot")
  parts.top_level_domain |> should.equal("com")
  parts.subdomain_parts |> should.equal(["www", "gleam"])
}

pub fn private_domain_blogspot_with_subdomain_with_private_test() {
  let list = psl.load_suffix_list(True)
  let assert Ok(parts) =
    psl.parse_with_list("https://www.gleam.blogspot.com", list)
  parts.transit_routing_domain |> should.equal("www")
  parts.second_level_domain |> should.equal("gleam")
  parts.top_level_domain |> should.equal("blogspot.com")
  parts.subdomain_parts |> should.equal(["www"])
}
