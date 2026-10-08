# AI Governance & Security Lab (local, private)

Hands-on companion for AI security and governance study (including TCM Security's Practical AI Pentest Associate, PAPA).
Everything runs against **local models** (Ollama) so no prompts, data, or findings leave the workstation.

## Framework map
| Framework | Use in the lab |
|---|---|
| NIST AI RMF 1.0 + GenAI Profile (AI 600-1) | Govern/Map/Measure/Manage worksheet per system → `templates/ai-rmf-worksheet.md` |
| ISO/IEC 42001 | AIMS control gap assessment of the lab itself |
| OWASP Top 10 for LLM Apps | Each item gets a test (garak / promptfoo) + evidence file |
| MITRE ATLAS | Tag every finding with an ATLAS technique ID |
| EU AI Act | Risk-tier classification exercise for each lab use case |

## Exercises (each produces a report in `reports/` and evidence in `evidence/`)
1. **Inventory & risk-tier** - register every model/tool in `inventory.csv`; classify (EU AI Act tier, RMF impact).
2. **Prompt-injection baseline** - `garak --probes promptinject,dan,encoding` vs. 2 local models; compare.
3. **Data-leakage test** - seed fake PII/secrets in a RAG store; measure extraction with promptfoo; add Presidio redaction; re-measure.
4. **Guardrail A/B** - llm-guard input/output scanners on vs. off; record residual risk.
5. **Policy pack** - write Acceptable-Use, Model Acquisition, and Incident-Response (AI) policies; map to 42001 clauses.
6. **Model/supply-chain** - verify hashes of pulled models, scan pickles (`picklescan`), document provenance.
7. **Monitoring** - ship Ollama/Open WebUI logs to the existing Wazuh SIEM lab; write detections for jailbreak patterns.

## Weekly cadence (suggested)
Mon read a framework section → Wed run an exercise → Fri write it up (this is the GitHub/resume evidence).
