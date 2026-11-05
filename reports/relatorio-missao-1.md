# Relatório — Missão 1 (reconhecimento, pesquisa, setup, primeira decompilação)

> STATUS: EM ANDAMENTO — última atualização 2026-11-04

## O que foi instalado
- Git 2.56.0.4 (winget)
- Microsoft OpenJDK 25.0.5 LTS (winget)
- GitHub CLI 2.103.3 (winget)
- Clones locais em `tools/` (git-ignored): MinecraftSourcesGenerator, universal-modder

## O que foi reutilizado
- MinecraftSourcesGenerator (decompile 26.1.2 local)
- Vineflower (embutido no gerador)
- mcsrc.dev, minecraft.wiki, steelmc.dev (referências online)
- Universal Modder (apenas como referência; NÃO instalado no OpenCode, sem fal MCP)

## Versão selecionada
**26.1.2** — primeira geração unobfuscada do Java Edition (nomes reais no jar), linha 26.1 mais documentada, requer Java 25. Ver `research/references/decisions.md` (D1).

## Arquivos analisados
- (pendente decompilação — preencher após `.mcsg-done`)

## Sistemas identificados
- (pendente)

## O que já foi documentado
- Ambiente, decisões D1–D6, comparação de ferramentas, diario.md, dicas.md, AGENTS.md, estrutura knowledge/.

## O que falta
- Decompilação 26.1.2 (em andamento)
- Análise inicial da arquitetura (entrypoints, bootstrap, registries)
- Experimentos E1–E4
- Publicação no GitHub (pendente login do usuário)

## Próximos passos
1. Concluir decompile e registrar estatísticas no diario.md
2. Mapear entrypoints e bootstrap (experimento E1)
3. Traçar registro de 1 bloco (E2), carregamento de chunk (E3), atualização de entidade (E4)
4. Preencher knowledge/ por sistema
5. Login gh + push do repositório público `teste eng reverse mine`
