# Project Guidelines

These requirements apply to all files and contributions in this project unless an explicit task requirement states otherwise.

## Language

- Write all project content in professional English. This includes identifiers, source code, comments, documentation, tests, diagnostics, user-facing text, filenames, and contribution descriptions.
- Use clear, precise, grammatically correct language. Avoid slang, informal shorthand, and unnecessary jargon.
- Use another language only when explicitly required by the task, such as for a requested localization or language-specific test fixture.

## Swift Coding Style

- Follow Apple's Swift API Design Guidelines and the conventions of Apple's Swift frameworks strictly.
- Use four spaces for indentation. Do not use tabs.
- Write declaration, accessor, closure, and control-flow bodies on multiple lines. Place the opening brace on the declaration or statement line, indent the body on subsequent lines, and put the closing brace on its own line, followed only by any continuation syntax. Do not compress computed properties, subscripts, functions, accessors, closures, or conditional branches into single-line blocks.
- Put each `switch` case's body on an indented line after its case label. Retain Swift's implicit returns where appropriate; multiline formatting does not require an explicit `return`.
- Use `UpperCamelCase` for types and protocols, and `lowerCamelCase` for functions, methods, properties, variables, parameters, and enumeration cases. Follow Apple's capitalization conventions for acronyms and initialisms.
- Prioritize clarity at the call site. Choose descriptive names and argument labels that read naturally, and omit words that merely repeat type information.
- Name Boolean values as assertions. Follow Apple's conventions for methods with side effects and for mutating and nonmutating method pairs.
- Use standard Swift language features and idioms. Follow Apple's established patterns for access control, error handling, optionals, and concurrency where applicable.
- Document public APIs with Swift documentation comments, using precise descriptions of their behavior, parameters, return values, and errors as applicable.
- Keep formatting and API conventions consistent throughout the package.

## Domain Terminology

- Use established terminology from the domain each component actually models.
- For settings-related concepts, use precise settings vocabulary, such as setting, preference, section, group, option, selection, and value, only where the term accurately describes the concept.
- Never transplant terminology, metaphors, naming patterns, or descriptions from an unrelated domain into identifiers, APIs, comments, documentation, or user-facing text.
- When referring to a platform or framework concept, use its established terminology and spelling.
- Use one consistent term for each concept. Avoid invented terminology, ambiguous synonyms, and vague names that obscure the component's responsibility.
- If the correct term is uncertain, inspect the relevant domain conventions and existing APIs before introducing a name.
