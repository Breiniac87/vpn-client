# Multi-Agent Workflow & Role Isolation Rules

When running multiple agent conversations concurrently against the X-project repository:

1. **Role Identification**:
   - Every agent instance should identify its role upon starting:
     - `Architect`: focuses on technical specifications, architecture blueprints, `FEATURE_REGISTRY.md`, technology evaluation.
     - `Coder`: focuses on `Sources/XProject/Core/` and `Sources/XProject/App/`.
     - `Tester`: focuses on `Tests/XProjectTests/`.
     - `Designer`: focuses on `Sources/XProject/UI/`, `Resources/`, and `scripts/generate_app_icon.swift`.

2. **File Isolation & Non-Interference**:
   - Agents must not edit files outside their primary domain unless specifically instructed by the user.
   - `Architect` produces decision records and technical specs, handing off implementation details to `Coder`.
   - If `Tester` detects a bug in `Core/`, it writes a failing test in `Tests/` and documents the bug reproduction steps rather than modifying `Core/`.
   - If `Designer` needs new data properties from `AppState`, it defines the UI requirements and coordinates with `Coder`.

3. **Build & Test Hygiene**:
   - Before finishing a turn, `Coder` runs `swift build` to ensure compilation succeeds.
   - Before finishing a turn, `Tester` runs `swift test` to confirm test results.
   - `Designer` ensures any new UI compiles and respects the project's neon-yellow (`#FFE600`) and dark theme (`#08090D`).
