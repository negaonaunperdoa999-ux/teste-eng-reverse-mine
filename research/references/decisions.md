# Decisões técnicas (registradas também no diario.md)

## D1 — Versão principal: 26.1.2 (linha 26.1)
**Data**: 2026-11-04 · **Status**: proposta técnica (usuário não confirmou explicitamente)
- Unobfuscada (nomes reais no jar) desde 26.1; requer Java 25.
- Linha 26.1 é a mais documentada da era unobfuscada (wiki, steelmc.dev, mcsrc.dev).
- Alternativas rejeitadas: 1.21.1/1.21.11 (ofuscadas → dependem de Mojmap/Parchment), 26.3 (mais nova, menos material), 26.1.0 (bugs corrigidos no 26.1.2).
- Comparação futura possível: diffVersions 26.1.2→26.3 (requer 2ª decompilação, só se aprovado).

## D2 — MinecraftSourcesGenerator como ferramenta de geração local
- Decompile 1 versão por vez; `-Pjobs=1 -PmaxHeap=4g -PvfThreads=4`; fontes em `sources/` (git-ignored).
- Respeita EULA via `-Peula=true` (aceite local, não versionado).

## D3 — Sem Ghidra por ora
- Bytecode Java → Vineflower + javap são suficientes. Ghidra é para binários nativos; custo/benefício ruim em 8 GB RAM sem GPU.

## D4 — Repositório GitHub PÚBLICO (decisão do usuário)
- Consequências: .gitignore estrito; `git ls-files` auditado antes de cada push; nunca subir `.java` decompilado, JARs, assets, mappings, eula.txt.
- Nome: `teste eng reverse mine`.

## D5 — Distribuição de código decompilado é proibida
- Apenas conhecimento destilado é publicado. Citações mínimas de trechos curtos para fins de estudo/crítica são mantidas raras e necessárias.

## D6 — Pastas sincronizadas pelo OneDrive
- Este workspace é OneDrive. Árvores decompiladas/grandes não devem ser geradas aqui se o usuário puder oferecer pasta local (ex.: `C:\mc-sources\26.1.2`). Pendente decisão do usuário.
