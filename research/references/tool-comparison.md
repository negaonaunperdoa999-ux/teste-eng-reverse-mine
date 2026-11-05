# Comparação de ferramentas (pesquisa 2026-11-04)

Legenda: ✅ bom · ⚠️ parcial · ❌ não atende

| Ferramenta | Decompila MC | Árvore navegável | Classe/método/deps | Bytecode | Comparar versões | Uso no OpenCode | MCP/Skills/API | Licença do próprio código |
|---|---|---|---|---|---|---|---|---|
| **MinecraftSourcesGenerator** | ✅ Vineflower integrado | ✅ `sources/<v>/` | ✅ (via saída .java) | ⚠️ (via javap à parte) | ✅ `diffVersions` (bytecode) | ⚠️ CLI via shell | ❌ | MIT? (repo público Bram1903; ver LICENSE) |
| **mcsrc.dev** (FabricMC/mcsrc) | ✅ (no navegador) | ✅ viewer web | ✅ herança, find-refs, go-to-decl | ✅ bytecode view | ✅ diff interface | ❌ (site) | ❌ | MIT |
| **Vineflower** | ✅ isolado | ⚠️ saída por classe | ✅ | ✅ `javap` complementar | ❌ | ⚠️ CLI | ❌ | Apache-2.0 |
| **Fabric (Loom genSources)** | ✅ | ✅ (IDE) | ⚠️ | ⚠️ | ❌ | ❌ | ❌ | Apache-2.0 |
| **Ghidra** | ❌ (nativo/binários) | ❌ | ❌ | ❌ JVM não é foco | ❌ | ✅ (MCP de terceiros existem) | ⚠️ ecosystem | Apache-2.0 |
| **Universal Modder** | ❌ (orquestra agente) | ❌ | ❌ | ❌ | ❌ | ✅ plugin/skills | ✅ skills+um CLI | MIT |
| **CFR / Procyon** | ✅ | ⚠️ | ✅ | ✅ | ❌ | ⚠️ CLI | ❌ | MIT / BSD |
| **Bytecode Viewer** | ✅ | GUI | ✅ | ✅ | ❌ | ❌ GUI | ❌ | GPL-3.0 |

## Decisões derivadas
1. **Pipeline principal**: MinecraftSourcesGenerator (decompile local, uma versão, 26.1.2) + Vineflower embutido.
2. **Análise estrutural**: ripgrep + `javap` + leitura direta; sem Ghidra (não se aplica a bytecode Java; pesado demais para 8 GB).
3. **Validação cruzada online**: mcsrc.dev (comparação de versões, herança) e minecraft.wiki (mecânicas; marcar `[DOC]`).
4. **Universal Modder**: usar apenas como referência de skills (`reverse-engineering`, `game-recon`) — não como base; sem fal MCP / APIs pagas.
5. **Comparação de versões**: `diffVersions` do gerador (bytecode-level), se o usuário quiser 26.1.2↔26.3 no futuro.
