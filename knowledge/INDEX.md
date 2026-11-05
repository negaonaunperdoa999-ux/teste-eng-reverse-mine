# Índice da base de conhecimento

> Consulte ANTES de investigar. Ao criar/renomear documento, atualize este índice e o `diario.md`.

## Arquitetura geral
- `architecture/overview.md` — mapa geral com Mermaid ✅ (E1+E2)
- `architecture/initialization.md` — boot cliente/servidor, registries ✅ (E1)
- `architecture/game-loop.md` — loop principal cliente/servidor, pacing, pausa, rede, render ✅ (E2)

## Por sistema
- `initialization/startup-flow.md` — resumo + ponteiros (ver architecture/initialization.md)
- `registries/block-registration.md` — registro de bloco/freeze ✅ (E3 auxiliar)
- `world/chunk-loading.md` — pipeline ponta-a-ponta ✅ (E4)
- `world/chunk-status.md` — 12 estágios, pirâmides GENERATION/LOADING ✅ (E4)
- `world/chunk-tickets.md` — tipos, níveis, propagação BFS, view distance ✅ (E4)
- `world/chunk-storage.md` — .mca, IOWorker, NBT, unload ✅ (E4)
- `world/chunk-networking.md` — protocolo de batch, envio adaptativo, cliente ✅ (E4)
- `world/lighting-engine.md` — block/sky light, swap visible/updating ✅ (E4b)
- `world/lighting-threading.md` — contrato async, tryScheduleUpdate, runUpdate ✅ (E4b)
- `world/chunk-save-unload-integrity.md` — copyOf, saveSyncFuture, races, riscos R1–R5 ✅ (E4b)
- `world/world-generation.md` — pipeline de geração procedural ✅ (E5)
- `world/noise-system.md` — DensityFunction, BlendedNoise, NoiseChunk ✅ (E5)
- `world/biome-generation.md` — MultiNoiseBiomeSource, R-tree 7D ✅ (E5)
- `world/chunk-generation-stages.md` — ponte E4×E5, chamadas por estágio ✅ (E5)
- `world/structures-and-features.md` — estruturas, carvers, decoração ✅ (E5)
- `world/worldgen-internals.md` — Aquifer, OreVeinifier, EndIslands, TerrainProvider, WorldGenRegion, FeatureSorter ✅ (E5b)
- `world/` — biomas, geração/worldgen detalhe (NÃO INICIADO)
- `blocks/` — blocos, states, propriedades (PARCIAL: ver registries/block-registration.md)
- `items/` — itens, componentes, receitas, tags (NÃO INICIADO)
- `entities/` — entidades, IA, navegação (NÃO INICIADO)
- `physics/` — colisões, gravidade, tick (NÃO INICIADO)
- `rendering/` — pipeline de render (PARCIAL: só pontos do loop)
- `audio/` — motor de som (NÃO INICIADO)
- `networking/` — protocolo, pacotes, flush/suspend (PARCIAL: citas no game-loop)
- `persistence/` — saves, NBT (NÃO INICIADO)

## Pesquisa
- `../research/discoveries/E1-initialization.md` — init completa [FATO]
- `../research/discoveries/E2-game-loop.md` — loop principal [FATO]
- `../research/discoveries/E4-chunk-loading.md` — pipeline de chunks + H1-H8 (todas resolvidas em E4b) [FATO]
- `../research/discoveries/E4b-light-engine.md` — iluminação threading/engine + H1-H8 resolução [FATO]
- `../research/discoveries/E5-world-generation.md` — geração procedural (W1-W8 TODAS resolvidas em E5b §11) [FATO]
- `../research/discoveries/` — futuras descobertas
- `../research/hypotheses/` — hipóteses não verificadas
- `../research/comparisons/` — comparações entre versões
- `../research/references/` — tool-comparison, decisions, external-docs

## Experimentos
- `../experiments/README.md` — E1 init ✅ · E2 game loop ✅ · E3 block registration ✅ (aux) · E4 chunks ✅ · **E4b iluminação + hipóteses ✅** · E5 receitas/worldgen · E6 texturas
