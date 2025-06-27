# CLAUDE.md

This file provides **MANDATORY** guidance to Claude Code (claude.ai/code) when working with code in this repository.

**⚠️ CRITICAL: YOU MUST ADHERE TO ALL PRINCIPLES BELOW ⚠️**
These are not suggestions - they are strict requirements that MUST be followed in every code change. In particular:

1. Test-Driven Development
2. SOLID, KISS and DRY
3. Single responsibility principle
4. Always declare variables at top of a routine

**⚠️ COMMUNICATION REQUIREMENTS ⚠️**
- Keep responses minimal and direct
- No flattery, congratulations, or celebration language
- Be brutally honest about issues and mistakes
- Answer questions with facts only
- Skip explanations unless specifically requested

## Project Overview

**fortplotlib** is a modern Fortran plotting library providing scientific visualization with PNG, PDF, and ASCII backends.

## API Usage

```fortran
use fortplot
type(figure_t) :: fig

call fig%initialize(width, height)
call fig%add_plot(x, y, label="data")
call fig%add_contour(x_grid, y_grid, z_grid)
call fig%savefig('output.png')  ! Auto-detects backend from extension
```

## Development Commands

**⚠️ CRITICAL: ALWAYS USE MAKE FOR ALL DEVELOPMENT TASKS ⚠️**

All development work must use the Makefile. Never run `fpm` commands directly.

**⚠️ SPELLING: It is "fpm" (Fortran Package Manager) - NEVER "fmp" ⚠️**

### Primary Development Commands

- `make example` - Build and run all examples (default development workflow)
- `make debug` - Build and run apps in app/ directory for debugging
- `make test` - Run all unit tests in test/ directory
- `make build` - Compile the project
- `make clean` - Clean build artifacts and generated plots

### Command Line Arguments Support

All make targets support passing additional fpm arguments. Use `ARGS` to pass extra parameters:

```bash
# Run specific example
make example ARGS="basic_plots"

# Run specific test
make test ARGS="--target test_specific_feature"

# Run specific app for debugging
make debug ARGS="--target debug_feature"

# Build with verbose output
make build ARGS="--verbose"
```

## File Organization

**Library Sources**: Place library sources in `src/` directory
**Debugging**: Place debugging sources in `app/` directory and execute with `make debug`
**Unit Tests**: Place unit tests in `test/` directory
**Examples**: Place examples in `example/` directory

## Third party References and Inspiration

**Matplotlib Source Code**: Located in `thirdparty/matplotlib/` for layout, styling, and API reference
- **Core Reference**: `thirdparty/matplotlib/lib/matplotlib/` contains the main matplotlib implementation
- Use for understanding margin calculations, text positioning, plot layout algorithms
- Reference for color schemes, tick generation, and professional plot styling
- Study layout managers and backend implementations for consistency

**Pyplot-Fortran Wrapper**: Located in `thirdparty/pyplot-fortran/src/pyplot_module.F90`
- **API Inspiration**: Study the Fortran wrapper patterns and interface design
- Reference for clean Fortran API design and Python integration patterns
- Learn from error handling and parameter passing approaches
- Use as inspiration for functional API design (not implementation)

### FPM Automatic Discovery

FPM automatically discovers all sources and resolves module dependencies when run via make:

- **Sources**: All `.f90` files in `src/`, `example/`, `test/`, and `app/` are automatically found
- **Dependencies**: Module dependencies are automatically resolved - no manual specification needed
- **Executables**: Each program in `example/`, `test/`, or `app/` becomes a buildable target

### Finding Available Targets

To discover available executable targets:

```bash
# List example programs
find example/ -name "*.f90" -not -name "CMakeLists.txt"

# List test programs
ls test/

# List debug/app programs
ls app/

# Find available modules in src/
grep -r "^module " src/
```

Example usage with discovered targets:
```bash
# Run specific example
make example ARGS="basic_plots"

# Run specific test
make test ARGS="--target test_figure_basics"

# Run specific debug app
make debug ARGS="--target debug_symlog_data"
```

```fortran
! app/debug_feature.f90 - For debugging/development
program debug_feature
    use fortplot
    ! Your debugging code here
end program
```

## Coding Standards

### SOLID Principles (Adapted for Fortran) - MANDATORY

**⚠️ CRITICAL: ALL SOLID PRINCIPLES MUST BE FOLLOWED ⚠️**

**S - Single Responsibility**: Each routine has one clear purpose, max 30 lines - **ENFORCED**
**O - Open/Closed**: Extend through inheritance/composition, not modification - **REQUIRED**
**L - Liskov Substitution**: Derived types must work wherever base types do - **MANDATORY**
**I - Interface Segregation**: Keep interfaces focused and minimal - **ENFORCED**
**D - Dependency Inversion**: Depend on abstractions (abstract types), not concrete implementations - **REQUIRED**

### DRY and KISS Principles - MANDATORY

**⚠️ CRITICAL: DRY AND KISS ARE STRICTLY ENFORCED ⚠️**

**DRY - Don't Repeat Yourself**: Extract common functionality into shared modules - **REQUIRED**
- Create common modules for shared logic (e.g., `fortplot_margins` for margin calculations)
- Use procedure pointers for backend-agnostic operations
- Centralize constants and magic numbers in one place

**KISS - Keep It Simple, Stupid**: Favor simplicity over cleverness - **MANDATORY**
- Write clear, readable code over "clever" optimizations
- Use straightforward algorithms unless performance demands complexity
- Prefer explicit over implicit behavior
- Choose clear variable names over short abbreviations

### Test-Driven Development (MANDATORY)

**⚠️ CRITICAL: TDD IS MANDATORY FOR ALL FEATURES AND REFACTORING ⚠️**
**⚠️ WRITE TESTS FIRST - NO EXCEPTIONS ⚠️**
**⚠️ DO NOT WRITE ANY CODE WITHOUT A FAILING TEST FIRST ⚠️**

**MANDATORY TDD WORKFLOW - NEVER DEVIATE:**

1. **WRITE FAILING TEST FIRST** in `test/test_*.f90` - **ALWAYS START HERE**
2. **RUN `make test`** to confirm the test fails (RED)
3. **Write minimal code** to make test pass (GREEN)
4. **Refactor** while keeping tests green (REFACTOR)
5. **Repeat RED-GREEN-REFACTOR** for next feature

**FORBIDDEN:**
- Writing implementation code before tests
- Changing code without a test covering the change
- Assuming existing code works without tests
- Skipping tests "just this once"

**TDD is not optional** - it is the foundation of all development in this codebase.
**TESTS FIRST, ALWAYS. NO CODE WITHOUT TESTS.**

```fortran
! test/test_new_feature.f90
program test_new_feature
    call test_should_calculate_bounds()
contains
    subroutine test_should_calculate_bounds()
        ! Arrange, Act, Assert pattern
    end subroutine
end program
```

**⚠️ CRITICAL: ALWAYS REFERENCE THIRD PARTY SOURCES WHEN IMPLEMENTING FEATURES ⚠️**

When implementing new features or improving existing ones:
1. **Check matplotlib implementation** in `thirdparty/matplotlib/src/lib/matplotlib/` first
2. **Study layout and styling patterns** to ensure consistency with professional plotting standards
3. **Reference pyplot-fortran** in `thirdparty/pyplot-fortran/src/pyplot_module.F90` for clean API design patterns
4. **Test against matplotlib output** using `make ref` to generate reference plots for comparison

### Code Organization (MANDATORY RULES)

**⚠️ CRITICAL: THESE RULES ARE NON-NEGOTIABLE ⚠️**

**Routine Size**: Max 30 lines, single responsibility - **NO EXCEPTIONS**
**Naming**: Use descriptive verbs (`calculate_bounds` not `calc`) - **REQUIRED**
**Placement**: Helper routines after caller, shared utilities at module end - **ENFORCED**
**Comments**: Only for complex algorithms, let code self-document - **MANDATORY**

### State Management - CRITICALLY IMPORTANT

**⚠️ MUTABLE GLOBAL STATE IS THE SOURCE OF ALL EVIL AND MUST BE AVOIDED AT ALL COST ⚠️**

**MANDATORY PRINCIPLES:**
- **NO GLOBAL MUTABLE STATE** - All state must be explicitly passed as parameters
- **IMMUTABLE BY DEFAULT** - Prefer immutable data structures and pure functions
- **EXPLICIT STATE MANAGEMENT** - Always save/restore state when temporarily modifying context
- **STATELESS OPERATIONS** - Functions should not rely on hidden global state
- **CLEAR OWNERSHIP** - Each piece of state must have a clear owner and scope

### Constants and Magic Numbers - STRICTLY ENFORCED

**⚠️ MAGIC NUMBER CONSTANTS ARE FORBIDDEN ⚠️**

**MANDATORY PRINCIPLES:**
- **NO MAGIC NUMBERS** - If a number has meaning, it MUST be a named constant
- **DESCRIPTIVE NAMES** - Constant names must clearly indicate their purpose
- **CENTRALIZED CONSTANTS** - Group related constants in parameter declarations
- **DOCUMENTED PURPOSE** - Each constant should have a clear comment explaining its meaning

### Backend Specialization and Polymorphism - STRICTLY ENFORCED

**⚠️ CRITICAL: NO SCATTERED DISPATCH LOGIC ALLOWED ⚠️**

**MANDATORY PRINCIPLES:**
- **NO SELECT TYPE IN BUSINESS LOGIC** - Backend-specific behavior must be handled in the backend implementations
- **SPECIALIZATION AT INITIALIZATION** - Configure backend-specific behavior when the backend is created
- **POLYMORPHIC INTERFACES** - Use abstract interfaces to hide backend differences from calling code
- **ENCAPSULATED SCALING** - Each backend handles its own coordinate/value scaling internally

### Misc - STRICTLY ENFORCED

**⚠️ CRITICAL: THESE RULES HAVE NO EXCEPTIONS ⚠️**

- Always explicitly import with `use only`. No wildcard imports allowed. - **MANDATORY**
- Use `implicit none` in all modules and programs - **REQUIRED**
- **ALL variable declarations MUST come before any executable code in routines** - **MANDATORY**
  - Variables, parameters, and type declarations first
  - Then executable statements and assignments
  - Fortran requires this strict ordering
- **cd COMMAND IS FORBIDDEN** - Never use `cd` in bash commands. Use absolute paths instead. - **MANDATORY**

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.


      IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context or otherwise consider it in your response unless it is highly relevant to your task. Most of the time, it is not relevant.
