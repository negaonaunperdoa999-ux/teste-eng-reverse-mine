# AGENTS.md — Regras para agentes de IA neste repositório

## Antes de qualquer coisa
1. Leia `diario.md` (histórico e decisões) e `dicas.md`.
2. Leia `knowledge/INDEX.md` para não duplicar investigação.
3. Verifique `reports/` pelo estado da missão atual.

## Regras invioláveis
- **NUNCA** commite/push: código decompilado, JARs, assets, mappings, `sources/`, `work/`, `eula.txt`, `.minecraft/`. Este repo é PÚBLICO.
- **NUNCA** invente comportamento do jogo. Marque tudo: `[FATO]` (lido no código), `[DOC]` (fonte externa), `[HIPÓTESE]`, `[NÃO DESCOBERTO]`.
- **NUNCA** modifique instalação legítima do Minecraft, mundos de jogador ou saves sem autorização explícita.
- **NUNCA** contorne DRM/auth/verificações. Pesquisa técnica apenas.
- Sempre que terminar uma etapa verificável: rode a verificação (script/teste/check) e registre no `diario.md`.
- Preserve os arquivos originais. Scripts em `scripts/` são idempotentes quando possível.

## Convenções
- Idioma: português (termos técnicos em inglês quando natural).
- Cada descoberta em `knowledge/` tem: sistema, descrição, classes, métodos, dependências, funcionamento, referências, versão, confiança, pendências.
- Diagramas em Mermaid dentro dos .md de `knowledge/`.
- Atualize `knowledge/INDEX.md` ao criar/renomear documentos.
- Decidiu algo técnico relevante? Registre em `diario.md` E em `research/references/decisions.md`.

## Fluxo de trabalho incremental
1. Reconhecer → 2. Localizar classes → 3. Ler → 4. Mapear dependências → 5. Registrar → 6. Validar (experimento) → 7. Promover para `knowledge/` → 8. Atualizar índices → 9. Commit + push (o usuário pediu push permanente a cada etapa concluída).

## Riscos conhecidos
- OneDrive sincroniza esta pasta: evite gerar GBs de arquivo aqui; decompile em local ignorado ou peça pasta local ao usuário.
- 8 GB RAM: decompilação é lenta; nunca rode `generateAll`; use `-Pjobs=1`.
- PowerShell: sempre `"-Pmc=..."` entre aspas.
