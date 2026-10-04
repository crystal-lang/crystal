# AGENTS.md

Context file for AI agents working on crystal.

**Dual Format**: This file combines Category A (Operations Manual) and Category B (Context Guide) for comprehensive agent guidance.

## Project Overview

crystal is a Javascript project using Makefile.

**Key Info:**
- **Primary Language:** Javascript
- **Build System:** Makefile
- **Test Framework:** Jest
- **Total Files:** 2724
- **Test Files:** 49
- **AI Readiness Score:** 77/100 (AI-Native)

---

## 🚨 AI Policy & Operations

Extracted from CONTRIBUTING.md - operational constraints and procedures.

### AI Policy

- Documenting the standard library
- Adding missing bits of the standard library, and/or improving its performance
- The [standard library documentation](https://crystal-lang.org/api/) is on the code itself, in this repository.
- the docs execute `make docs`. Please follow the guidelines described in our
- [language documentation](https://crystal-lang.org/reference/conventions/documenting_code.html), like the use of the third person.

### Key Requirements

- [`community:to-research`](https://github.com/crystal-lang/crystal/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen%20label%3Acommunity%3Ato-research): Help needed on **researching and investigating** the issue at hand; could be from going through an RFC to figure out how something _should_ be working, to go through details on a C-library we'd like to bind.
- Furthermore, these are the most important general topics in need right now, so if you are interested open an issue to start working on it:
- Pull-request only labels, used to signal that a pull request `needs-review` by a core team member, or that is still `wip` (work in progress).
- An issue is `accepted` when it describes a feature or bugfix that a core team member has agreed to have added to the language, so as soon as a design is discussed (if needed), it's safe to start working on a pull request.
- Bug reports are marked as `needs-more-info`, where the author is requested to provide the info required; note that the issue may be closed after some time if it is not supplied.

### Development Procedures

- Once in the cloned directory, and once you [installed Crystal](https://crystal-lang.org/install/),
- you can execute `bin/crystal` instead of `crystal`. This is a wrapper that will use the cloned repository
- your installation.
- You can run `crystal tool format` to automate this.
- the first thing you will need to do is to [install the compiler](https://crystal-lang.org/install/).



## 🏗️ Architecture & Context Guide

This section provides architectural context and agent-understanding for the codebase.

### Prerequisites

- **Javascript:** 16+ (or applicable language version)
- **Package Manager:** npm or yarn
- **Test Runner:** Jest



### Project Structure

```
crystal/
├── Makefile
├── Makefile
├── Makefile
├── src/                  # Source code
├── tests/                # Test suite (49 files)
└── README.md             # Project documentation
```

### Architecture Overview

#### Key Components
- **Main Entry:** Standard layout
- **Test Suite:** 49 test files
- **Build Configuration:** Makefile, Makefile, Makefile

#### Design Principles

1. **Modularity** - Code organized by functionality with clear separation of concerns
2. **Testability** - Comprehensive test coverage across critical paths
3. **Clarity** - Explicit naming and structure for AI agent understanding
4. **Consistency** - Uniform patterns and conventions throughout codebase
5. **Maintainability** - Well-documented code with clear intent

### Directory Map

| Directory | Purpose |
|-----------|----------|
| `lib/` | Library code |
| `scripts/` | Build and utility scripts |
| `spec/` | Test specifications |
| `src/` | Source code |


### Development Workflow

#### Initial Setup

```bash
git clone https://github.com/YOUR_ORG/crystal.git
cd crystal
npm install
# or
yarn install
```

#### Development Commands

**Running Tests:**
```bash
npm test                  # Run all tests
npm run test -- --watch   # Watch mode
npm run lint              # Lint code
```

#### Code Quality
```bash
npm run format            # Format code (prettier)
npm run lint -- --fix     # Auto-fix lint issues
```

### Code Style & Conventions

- **Naming:** Use Javascript conventions (snake_case for functions, PascalCase for classes)
- **Type Hints:** Yes (strongly encouraged)
- **Error Handling:** Yes - handle errors at boundaries; let exceptions propagate when another layer owns recovery
- **Logging:** Yes
- **Testing:** Yes - write tests alongside code changes

### Testing Strategy

**Framework:** Jest
**Test Files:** 49 found

Before committing:
1. Run the full test suite: `npm test` or `yarn test`
2. Run linter: `npm run lint` or `yarn lint`
3. Format code: `npm run format` or `yarn format`
4. Type check (if TypeScript): `npm run type-check`

### Writing Documentation

When updating docs:
1. Always include explanatory text before code snippets
2. Describe *why* and *what* before showing *how*
3. Keep sections focused on a single concept
4. Use clear, concrete examples

## Known Gotchas & Warnings

- The most basic category is the kind of the issue: `bug`, `feature` and `question` speak for themselves, while `refactor` is left for changes that do not actually introduce a new a feature, and are not fixing something that is broken, but rather clean up the code (or documentation!).
- Status labels attempt to capture the lifecycle of an issue:
- Note: at this point you might get long compile error that include "library not found for: ...". This means

### Contributing Guidelines

This project has a detailed contribution guide at **`CONTRIBUTING.md`**.

**Key Requirements:**
- **Performance Work**: Requires benchmarks and performance metrics in PR description

**Before submitting:**
1. Read `CONTRIBUTING.md` in full
2. Check recent merged PRs for patterns
3. Follow the specific requirements above

### Common Patterns

When contributing to this project:
1. Read existing code in the area you're modifying
2. Follow the established patterns and style
3. Write tests for new functionality
4. Use clear, descriptive variable and function names
5. Add docstrings for public APIs
6. Update tests when changing behavior

### What We Value

✅ Well-tested code with clear intent
✅ Consistent code style and naming conventions
✅ Code that is easy for AI agents to understand
✅ Clear, descriptive commit messages
✅ Modular, reusable components
✅ Comprehensive documentation

### What We Avoid

❌ Large functions doing multiple things
❌ Commented-out dead code
❌ Inconsistent naming or patterns
❌ Unclear error messages
❌ Unexplained magic numbers or strings
❌ Skipped tests or test TODOs

### AI Readiness Dimensions (Scoring)

This project is evaluated across 8 dimensions:

1. **Architecture** (10/100) - Code organization and modularity
2. **Testing** (15/100) - Test coverage and quality
3. **Dependencies** (12/100) - Dependency management
4. **Conventions** (8/100) - Consistent patterns
5. **Entry Points** (4/100) - Clear main/start locations
6. **Security** (10/100) - Input validation and error handling
7. **Build** (10/100) - Clear build/setup instructions
8. **Documentation** (8/100) - Code and project documentation

### Next Steps

Before making changes:
1. Read relevant source files to understand the existing code
2. Look at existing tests for similar functionality
3. Follow the patterns you see in the codebase
4. Write tests for your changes
5. Run `pytest` to verify nothing breaks
6. Run code quality checks: `ruff check . && mypy .`
7. Format your code: `ruff format .`

---

*Generated by Braxis - keeping AI agents in sync with your code*

