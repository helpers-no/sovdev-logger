# Additions while we are refactoring

tools that we should add while refactoring


## Okta tool ✅ COMPLETED

✅ Created install-tool-okta.sh
- Installs okta-cli Python package (v18.1.2)
- Installs Okta Explorer VS Code extension
- Comprehensive documentation with IaC references (Terraform, Pulumi)
- Script version: 0.0.3
- Category: CLOUD_TOOLS


## Power platform tool ✅ COMPLETED

✅ Created install-tool-powerplatform.sh
- Installs Microsoft Power Platform CLI (pac) via PACKAGES_DOTNET
- Installs Power Platform Tools VS Code extension
- Prerequisites: .NET SDK, x64 (AMD64) architecture only
- ARM64 detection with clear error message
- Comprehensive documentation about Linux devcontainer capabilities
- Script version: 0.0.3
- Category: CLOUD_TOOLS

Implementation notes:
- Created new PACKAGES_DOTNET infrastructure (lib/core-install-dotnet.sh)
- Power Platform CLI only supports x64 on Linux (not ARM64)
- 80-90% of Power Platform development works in Linux devcontainer
- Windows-only tools (PRT, CMT, pac data) clearly documented

## Azure Tools

see chat https://claude.ai/share/e1b9f3ae-1902-4146-9abd-ec7d06dcaad3

## Documentation & Diagramming Tools

Potential `install-tool-documentation.sh` script for visual documentation and diagramming.

**Visual Diagram Tools:**
- **Draw.io Integration** (hediet.vscode-drawio)
  - Create/edit architecture diagrams, flowcharts, network diagrams
  - Saves as .drawio.svg or .drawio.png (version controllable)
  - Alternative to Visio/Lucidchart
  - https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio

**Extended Mermaid Tools** (beyond base bierner.markdown-mermaid):
- **Mermaid Chart** (MermaidChart.vscode-mermaid-chart)
  - Official Mermaid editor with live preview
  - https://marketplace.visualstudio.com/items?itemName=MermaidChart.vscode-mermaid-chart
- **Mermaid Preview** (vstirbu.vscode-mermaid-preview)
  - Standalone preview pane for .mmd files
  - https://marketplace.visualstudio.com/items?itemName=vstirbu.vscode-mermaid-preview

**Alternative Text-Based Diagrams:**
- **PlantUML** (jebbs.plantuml)
  - Text-based UML diagrams (sequence, class, component, etc.)
  - More powerful than Mermaid for complex UML
  - https://marketplace.visualstudio.com/items?itemName=jebbs.plantuml
  - **Note:** Requires Java runtime and Graphviz (system packages)


**Technical Documentation:**
- **AsciiDoc** (asciidoctor.asciidoctor-vscode)
  - Alternative to Markdown for complex technical docs
  - Better for books, technical manuals, multi-file docs
  - https://marketplace.visualstudio.com/items?itemName=asciidoctor.asciidoctor-vscode

**Recommendation for MVP:**
Keep it simple with just Draw.io - most universal and works standalone.
Other tools can be added if needed, or users install manually.


## API developer tool

**API Documentation:**
- **OpenAPI (Swagger) Editor** (42Crunch.vscode-openapi)
  - Edit and preview OpenAPI/Swagger specs
  - https://marketplace.visualstudio.com/items?itemName=42Crunch.vscode-openapi
- **REST Book** (tanhakabir.rest-book)
  - Interactive API documentation notebooks
  - https://marketplace.visualstudio.com/items?itemName=tanhakabir.rest-book
