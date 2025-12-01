# Additions while we are refactoring

tools that we should add while refactoring


## Okta tool

Tool for managing Okta - can contain:
https://marketplace.visualstudio.com/items?itemName=OktaDcp.okta-explorer
https://pypi.org/project/okta-cli/

there are IaC stuff
https://registry.terraform.io/providers/okta/okta/latest/docs
https://www.pulumi.com/registry/packages/okta/
(nothing for bicep, and old outdated ansible)


## Power platform tool

see chat https://claude.ai/share/f5368700-3761-4568-8cda-64127508a172

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

**API Documentation:**
- **OpenAPI (Swagger) Editor** (42Crunch.vscode-openapi)
  - Edit and preview OpenAPI/Swagger specs
  - https://marketplace.visualstudio.com/items?itemName=42Crunch.vscode-openapi
- **REST Book** (tanhakabir.rest-book)
  - Interactive API documentation notebooks
  - https://marketplace.visualstudio.com/items?itemName=tanhakabir.rest-book

**Technical Documentation:**
- **AsciiDoc** (asciidoctor.asciidoctor-vscode)
  - Alternative to Markdown for complex technical docs
  - Better for books, technical manuals, multi-file docs
  - https://marketplace.visualstudio.com/items?itemName=asciidoctor.asciidoctor-vscode

**Recommendation for MVP:**
Keep it simple with just Draw.io - most universal and works standalone.
Other tools can be added if needed, or users install manually.