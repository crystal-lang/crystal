# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

### TODO

- GFM support

## [0.5.0] (2022-06-14)

- Support CommonMark 0.29 #[50](https://github.com/icyleaf/markd/pull/50) thanks @[HertzDevil](https://github.com/HertzDevil).
- Fix typos #[47](https://github.com/icyleaf/markd/pull/47) #[49](https://github.com/icyleaf/markd/pull/49) thanks @[kianmeng](https://github.com/kianmeng), @[jsoref](https://github.com/jsoref).

## [0.4.2] (2021-10-19)

### Added

- Enable Table of Content (TOC) #[41](https://github.com/icyleaf/markd/pull/41) thanks @[Nephos](https://github.com/Nephos).

### Fixed

- Fix byte slice negative #[43](https://github.com/icyleaf/markd/pull/43).
- Compatibility with Crystal 1.2.

## [0.4.1] (2021-09-27)

### Added

- Refactor Options and change to a class #[36](https://github.com/icyleaf/markd/pull/36) thanks @[straight-shoota](https://github.com/straight-shoota).
- Add `lang` parameter to to `HTMLRenderer#code_block_body` #[38](https://github.com/icyleaf/markd/pull/38) thanks @[straight-shoota](https://github.com/straight-shoota).

## [0.4.0] (2021-03-23)

- Compatibility with Crystal 1.0. #[34](https://github.com/icyleaf/markd/pull/34) thanks @[bcardiff](https://github.com/bcardiff).

## [0.3.0] (2021-03-02)

No changelog.

## [0.2.1] (2020-08-24)

### Added

- Add Options#base_url to allow resolving relative links. #[26](https://github.com/icyleaf/markd/pull/26), #[28](https://github.com/icyleaf/markd/pull/28) thanks @[straight-shoota](https://github.com/straight-shoota).

### Fixed

- [high severity] escape unsafe html entry inline of code block. #[32](https://github.com/icyleaf/markd/pull/32).
- Fixed some typos in README. #[29](https://github.com/icyleaf/markd/pull/29) thanks @[Calamari](https://github.com/Calamari).

## [0.2.0] (2019-10-08)

### Changed

- Optimizations speed. many thanks @[asterite](https://github.com/asterite). #[19](https://github.com/icyleaf/markd/pull/19)

### Fixed

- Compatibility with Crystal 0.31. #[22](https://github.com/icyleaf/markd/pull/22).

## [0.1.2] (2019-08-26)

- Use Crystal v0.31.0 as default compiler.

## [0.1.1] (2017-12-26)

- Minor refactoring and improving speed. thanks @[straight-shoota](https://github.com/straight-shoota).
- Use Crystal v0.24.1 as default compiler.

## 0.1.0 (2017-09-22)

- [initial implementation](https://github.com/icyleaf/markd/milestone/1?closed=1)

[Unreleased]: https://github.com/icyleaf/markd/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/icyleaf/markd/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/icyleaf/markd/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/icyleaf/markd/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/icyleaf/markd/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/icyleaf/markd/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/icyleaf/markd/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/icyleaf/markd/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/icyleaf/markd/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/icyleaf/markd/compare/v0.1.0...v0.1.1
