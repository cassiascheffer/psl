# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- ## [Unreleased] -->

## [2.0.0] - 2024-10-10

### Added
- New `add_rule()` public function to add custom suffix rules to a loaded list, supporting normal domains, wildcards, and exceptions.
- Addded `path` option to `load_suffix_list()` to allow for custom files. See BREAKING changes below.
- UTF-8 and punycode examples in README demonstrating internationalised domain name support

### Changed
- **BREAKING**: `parse()` function signature changed from `parse(uri_string: String, include_private: Bool)` to `parse(uri_string: String, list: SuffixList)`. Users must now load the suffix list first and pass it to parse.
- **BREAKING**: `load_suffix_list()` accepts an optional `path` parameter to load a custom public suffix list. The signature changed - added required second parameter `path: Option(String)`.
- **BREAKING**: Module structure refactored - consolidated three internal modules (`psl/domain.gleam`, `psl/punycode.gleam`, `psl/suffix_list.gleam`) into the main `psl.gleam` module. Imports from those submodules will no longer work.

## [1.0.0] - 2025-10-8

- Initial release.

