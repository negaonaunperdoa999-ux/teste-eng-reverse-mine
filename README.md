# Minecraft Reverse Engineering Lab

Laboratório de engenharia reversa do **Minecraft: Java Edition** assistido por IA.
Objetivo: compreender, relacionar, documentar e validar como o jogo funciona internamente — NÃO é um projeto de modding.

> ⚠️ **Aviso legal**: este repositório contém apenas conhecimento próprio (documentação, scripts, experimentos, análises).
> NUNCA são distribuídos: código decompilado, JARs originais, assets proprietários ou mapeamentos.
> A decompilação é feita localmente, para estudo pessoal, nos termos da EULA da Mojang.
> Não contornamos DRM, autenticação ou verificações de propriedade.

## Versão de análise

- **26.1.2** (linha 26.1, "Tiny Takeover", hotfix de abr/2026) — primeira geração de releases **unobfuscadas** do Java Edition (nomes reais no jar, sem mapeamentos).
- Requer Java 25. Ver `diario.md` e `knowledge/` para o raciocínio completo.

## Estrutura

```
├── diario.md          # diário de campo — LER PRIMEIRO, ATUALIZAR SEMPRE
├── dicas.md           # dicas e convenções para agentes de IA
├── AGENTS.md          # regras para agentes de IA neste repositório
├── README.md
├── knowledge/         # base de conhecimento permanente (por sistema)
├── research/          # descobertas, hipóteses, comparações, referências
├── tools/             # ferramentas de terceiros (clones de referência) — git-ignored onde aplicável
├── scripts/           # scripts próprios (análise, indexação, geração de diagramas)
├── experiments/       # experimentos isolados de validação
└── reports/           # relatórios de missão
```

Nota: as árvores decompiladas (`sources/`) e caches (`work/`) NÃO vivem neste repositório público.

## Como usar

1. Leia `diario.md` e `dicas.md`.
2. Consulte `knowledge/INDEX.md` para achar o conhecimento existente.
3. Ao investigar, abra os arquivos decompilados localmente (ver `reports/` para instruções de setup).
4. Registre tudo no formato de entrada do `diario.md`; promova descobertas maduras para `knowledge/<sistema>/`.

## Status

Ver `reports/relatorio-missao-1.md` para o estado atual.
