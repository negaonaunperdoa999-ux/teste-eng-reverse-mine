# Relatório — Missão 1 (reconhecimento, setup, decompilação, E1+E2)

> ATUALIZADO 2026-11-05 · Status: **CONCLUÍDO (local) — repositório NÃO publicado por instrução do usuário**

## O que foi instalado
- Git 2.56.0.4 · Microsoft OpenJDK 25.0.5 LTS · GitHub CLI 2.103.3 (winget, com autorização do usuário)
- Nenhum outro software; Ghidra, ripgrep e IDE extra NÃO instalados

## O que foi reutilizado
- **MinecraftSourcesGenerator** (clone em `tools/`, git-ignored) — decompile local 26.1.2
- **Vineflower 1.12.0** (embutido no gerador)
- **mcsrc.dev / minecraft.wiki / steelmc.dev** — referências online ([DOC])
- **Universal Modder** — clonado apenas como referência; NÃO integrado ao OpenCode; fal MCP/APIs pagas não utilizadas

## Versão selecionada
**26.1.2** — unobfuscada, mais documentada da linha 26.1. Ver `research/references/decisions.md` (D1).

## Auditoria da decompilação (26.1.2)
- 6882 classes .java · 6883 arquivos · 31.3 MB · 539 diretórios · ~4.7 KB/arquivo · 0 vazios · 0 resíduos de ofuscação
- `.mcsg-done`: tier=VANILLA, revision=3, decompiler vineflower-1.12.0
- 17/17 classes-chave verificadas presentes e legíveis; nomes reais de métodos/locais
- Distribuição: world 2559, client 1813, util 713, server 418, network 411 classes

## Sistemas investigados
- **Inicialização** (E1) — `knowledge/architecture/initialization.md` + `research/discoveries/E1-initialization.md`
- **Ciclo principal / game loop** (E2) — `knowledge/architecture/game-loop.md` + `research/discoveries/E2-game-loop.md`
- **Registro de bloco + freeze de registries** (E3 auxiliar) — `knowledge/registries/block-registration.md`

## Arquivos de documentação criados nesta missão
knowledge/: architecture/overview.md, architecture/initialization.md, architecture/game-loop.md, initialization/startup-flow.md, registries/block-registration.md, INDEX.md (atualizado) · research/discoveries/E1-initialization.md, E2-game-loop.md · experiments/README.md (atualizado) · diario.md, dicas.md (atualizados) · scripts/pre-push-check.ps1 (corrigido PATH)

## Problemas encontrados
- `gh` ainda não autenticado → repositório público NÃO criado; nenhum push executado (por instrução do usuário)
- OneDrive sincroniza a pasta do projeto (decompilação fica em `tools/.../sources/` e `work/`, git-ignored; ocupa ~32 MB de fontes — cache `work/` pode crescer mais)
- PowerShell não tem ripgrep; buscas usam `Select-String` (script padrão em dicas.md)
- PATH da sessão não incluía Git recém-instalado → scripts corrigidos para localizar `C:\Program Files\Git\cmd`

## Verificação de segurança (repo público)
- `git ls-files`: 19 arquivos próprios, **0** `.java`/`.jar`/`sources/`/`work/`/`eula.txt` — `scripts/pre-push-check.ps1` → OK
- Commit local `e220194` criado com identidade local neutra (`Minecraft RE Lab <mc-re-lab@localhost>`) — SEM push
- Código decompilado, JARs, mappings e assets NÃO estão e NUNCA estarão no repositório

## Próximo experimento recomendado
**E4 — Carregamento de um chunk** (pontos de partida em `experiments/README.md` e `diario.md`): `ServerLevel.tick` → `chunkSource.tick` → `ServerChunkCache` → `ChunkSerializer`/`SerializableChunkData` → formato de região `.mca` (cross-check [DOC] wiki).

## Pendências de publicação
- Aguardar instrução do usuário para `gh auth login` + criação do repo público `teste eng reverse mine` + primeiro push (com `pre-push-check.ps1` OK)
