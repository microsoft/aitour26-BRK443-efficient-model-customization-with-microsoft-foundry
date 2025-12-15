# CHANGELOG

## Dec 15, 2025

**Post-Ignite Repository Refresh (Oct 29 - Dec 15)**

Major repository restructuring and content updates following Microsoft Ignite 2025:

### Rebranding & Terminology Updates (Dec 9)
- **Renamed Azure AI Foundry → Microsoft Foundry** across all documentation, notebooks, and code
- Updated references in README.MD, docs/index.md, infra scripts, session delivery resources
- Updated all 6 core notebooks with new branding

### New Tool-Calling Fine-Tuning Demo (Dec 11-15)
- **Added `03-tool-calling-fine-tuning.ipynb`**: Comprehensive cookbook for improving retail AI agent tool-calling accuracy
  - Covers MCP (Model Context Protocol) server integration
  - Demonstrates synthetic data generation, SFT training, and Python-based evaluation
  - Includes custom graders for tool accuracy, parameter correctness, and policy adherence
  - Simplified documentation (60-80% reduction in verbose markdown) on Dec 15 for improved readability
- **New supporting files**:
  - Retail MCP server tools and test utilities (`src/tools/retail_agent.py`, `test_retail_agent.py`, etc.)
  - Training data: `sft_train.jsonl`, `sft_test.jsonl`, synthetic conversation examples
  - Policy documents, OpenAPI specs, and evaluation datasets (`data/policy.md`, `openapi_with_policy.json`)
  - Tool-calling grader utilities (`eval_create_util.py`, `data/tool_call_grader.py`)
  - Architecture diagrams and UI screenshots (`img/architecture.png`, `img/datagen_ui.png`, etc.)

### Repository Restructuring (Dec 8-9)
- **Removed RAFT demo content** (`src/demo-raft/` directory deleted)
- **Flattened directory structure**: Moved files from `src/demo-core/` to `src/` root
- **Reorganized notebooks**:
  - Renumbered: `32-custom-grader.ipynb` → `01-custom-grader.ipynb`
  - Renumbered: `33-distill-finetuning.ipynb` deleted, content reorganized
  - Created `02-basic_fine-tuning.ipynb` with focused SFT examples
  - Added `00-introduction.ipynb` for workshop orientation
  - Moved advanced topics to `src/additional demos/` folder
- **Updated training data files**: Renamed and reorganized baseline/distillation datasets with new hash identifiers

### Infrastructure & Setup Improvements (Dec 9-13)
- **Enhanced environment configuration**:
  - Updated `.env.sample` with new variables for MCP server and agent configuration
  - Improved `infra/1-get-env.sh` script for better variable extraction and validation
  - Simplified setup process with clearer instructions in `src/00-setup.md`
- **Model deployment updates**:
  - Updated `infra/customization/add-models.json` for gpt-4.1 model family
  - Enhanced validation scripts (`00-validate-setup.ipynb`, `00-verify-models.ipynb`)
- **Dependencies**: Updated `requirements.txt` with new packages for MCP integration and evaluation tools

### Documentation & Delivery Resources (Nov-Dec)
- **Community links updated** (Nov 4): Refreshed Discord and GitHub Forum links in README.MD
- **Security updates** (Oct 30): Updated requests package to version 2.32.4
- **Session delivery enhancements**: Updated speaker notes and storyboards with Microsoft Foundry terminology

### Key Files Modified/Added Since Oct 29
- 6 core notebooks updated with branding and new content
- 4 new notebooks added (00-introduction, 01-custom-grader, 03-tool-calling, restructured 02-basic)
- 30+ new data files for tool-calling demos
- 8+ new utility scripts in `src/tools/`
- Infrastructure scripts modernized for current Azure AI capabilities
- All documentation and delivery resources refreshed

This refresh positions the repository for the BRK443 session with current Microsoft Foundry branding, expanded tool-calling fine-tuning content, and a cleaner, more maintainable structure.

---

## Oct 29, 2025

Refactoring repository with updates for Nov 6 delivery. The breakout has two main "categories" for demos:

- Core Fine-Tuning = SFT & Distillation
- Hybrid Fine-Tuning + RAG = RAFT

This commit refactors the repo to remove unused content and create self-contained demo subfolders for easy maintenance:

**CORE FINE-TUNING** (`src/demo-core`)
- `data/` has all data required for these demos
- `0-custom-grader.ipynb` - eval-driven development
- `1-getting-started.ipynb` - context engineering
- `2-demo-sft.ipynb` - covers SFT
- `3-demo-distillation.ipynb` - covers distillation

**HYBRID FINE-TUNING** (`src/demo-raft`)
- `scripts/` was originally in root of repo
- `data/articles` was originally in root of repo
- everything else remains unchanged from previous

INFRA FOR **CORE DEMOS**

- The repository uses a custom branch of the [_ForBeginners AZD Template_](https://github.com/microsoft/ForBeginners/tree/aitour26-demos) that is based on the Get-Started-With-AI-Agents template for Microsoft Foundry.
    - This will set up a Azure resource group with an Microsoft Foundry resource and project that has {An AI Agent, A Chat Model, An Embedding Model, A Web App, An AI Search resource, Tracing & Monitoring activated}
    - Use the `infra/2-add-models.sh` script to deploy additional models after the initial provisioning step. 
- Pick the default base model for fine-tuning (default is gpt-4.1, but you may want gpt-4o)
- Pick a region that has support for [Fine-tuning](https://learn.microsoft.com/azure/ai-foundry/foundry-models/concepts/models-sold-directly-by-azure?pivots=azure-openai&tabs=global-standard-aoai%2Cstandard-chat-completions%2Cglobal-standard#fine-tuning-models) and [Azure AI Search](https://learn.microsoft.com/azure/search/search-region-support#americas).
    - Default is Sweden Central (base is gpt-4.1)
    - Backup is East US 2 (switch base to gpt-4o)
- **SETUP**:
    - `cd infra/`
    - `./1-setup.sh`
    - `./2-add-models.sh`
- **TEARDOWN**:
    - `cd infra/`
    - `./3-teardown.sh`

---
