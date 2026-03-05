# Elastic internal jargon

Terms are grouped by category. Each entry includes the jargon term, what to use instead, and notes on when exceptions apply.

---

## Internal code names

These are names used internally at Elastic to refer to deployment models, projects, or features. External readers will not recognize them without context.

| Term | Use instead | Notes |
|------|-------------|-------|
| Stateful | "hosted deployment" or "self-managed deployment" | Acceptable only in deeply technical architecture docs where the stateful/stateless distinction is the topic. |
| Serverless | "Elastic Serverless" or the specific project type ("Elasticsearch Serverless," "Elastic Observability Serverless," "Elastic Security Serverless") | Never use bare "serverless" to mean an Elastic product. Generic "serverless" (e.g., "serverless architecture") is fine. |
| Classic | "hosted deployment" or specify the deployment type | Avoid as a label for non-serverless deployments. |
| Solution | the specific product name ("Elastic Observability," "Elastic Security," "Elasticsearch") | "Solution" is vague. Name the product. |

## Internal abbreviations

Short forms used in Slack, internal docs, and meetings. Spell out or replace for external readers.

| Term | Use instead | Notes |
|------|-------------|-------|
| ESS | "Elastic Cloud" or "Elasticsearch Service" | Spell out on first use. |
| ECE | "Elastic Cloud Enterprise" | Spell out on first use. |
| ECK | "Elastic Cloud on Kubernetes" | Spell out on first use. |
| ECH | "Elastic Cloud Hosted" | Spell out on first use. |
| EUI | "Elastic UI framework" | Spell out on first use. |

## Outdated terms

Terms replaced by newer naming. Flag and suggest the current equivalent.

| Term | Use instead | Notes |
|------|-------------|-------|
| index pattern | "data view" | Renamed in Kibana 8.0. |
| master node | "master-eligible node" | Use role-based naming. |
| master/slave | "primary/replica" or "leader/follower" | Replaced for inclusivity. |
| blacklist | "blocklist" or "deny list" | Replaced for inclusivity. |
| whitelist | "allowlist" | Replaced for inclusivity. |
| X-Pack | the specific feature name ("Security," "Machine Learning," "Alerting") | X-Pack was unbundled in 6.3. |

## Informal shorthand

Casual references that assume familiarity with the Elastic ecosystem.

| Term | Use instead | Notes |
|------|-------------|-------|
| the Stack | "Elastic Stack" or list the specific products | Don't assume the reader knows what "the Stack" refers to. |
| Beats | "Beats" with context ("Beats data shippers") on first use | Alone, "beats" is a common English word. |
| Agent | "Elastic Agent" on first use | Bare "agent" is ambiguous. |
| Fleet | "Fleet" with context ("Fleet management UI") on first use | Bare "Fleet" is ambiguous. |
| Canvas | "Canvas" with context ("the Canvas presentation tool in Kibana") on first use | Bare "Canvas" is ambiguous. |
| Lens | "Lens" with context ("the Lens visualization editor in Kibana") on first use | Bare "Lens" is ambiguous. |
| Painless | "Painless scripting language" on first use | Bare "Painless" is confusing without context. |
| Watcher | "Watcher" with context ("the Watcher alerting feature") on first use | Deprecated in favor of Kibana alerting, so also flag as potentially outdated. |
| Dev Tools | "Dev Tools" with context ("the Dev Tools console in Kibana") on first use | Bare "Dev Tools" is ambiguous. |
| Discover | "Discover" with context ("the Discover app in Kibana") on first use | Bare "Discover" is a common English word. |
| Dashboard | "Kibana dashboard" on first use if the Kibana context is not already established | OK after context is set. |

## Unexplained acronyms

Technical acronyms that must be spelled out on first use per page. Flag if they appear without expansion.

| Term | Expansion |
|------|-----------|
| ILM | Index Lifecycle Management |
| SLM | Snapshot Lifecycle Management |
| CCR | Cross-cluster replication |
| CCS | Cross-cluster search |
| APM | Application Performance Monitoring |
| SIEM | Security Information and Event Management |
| TSDB | Time series data stream (or time series database, depending on context) |
| ECS | Elastic Common Schema |
| RBAC | Role-based access control |
| KQL | Kibana Query Language |
| EQL | Event Query Language |
| ES|QL | Elasticsearch Query Language |
| DSL | Domain-specific language (or "Query DSL" specifically) |
| ML | Machine learning |
| NLP | Natural language processing |
