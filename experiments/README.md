# Experimentos de validação

Experimentos isolados e pequenos. Nenhum experimento modifica saves/mundos.
Resultados são resumidos em `reports/` e promovidos para `knowledge/` quando confirmados.

## E1 — Caminho de inicialização do jogo ✅ CONCLUÍDO
- Resultado: `research/discoveries/E1-initialization.md` + `knowledge/architecture/initialization.md`
- Cliente: `client.main.Main#main` → `SharedConstants.tryDetectVersion()` → `server.Bootstrap.bootStrap()` → `ClientBootstrap.bootstrap()` → `new Minecraft` → `run()`.
- Registries populados via loaders lazy + freeze antes do loop.

## E2 — Ciclo principal do jogo ✅ CONCLUÍDO
- Resultado: `research/discoveries/E2-game-loop.md` + `knowledge/architecture/game-loop.md`
- Cliente: `Minecraft.run` → `runTick` (fixo-timestep `DeltaTracker.Timer`, máx. 10 ticks/frame) → `renderFrame` (render sempre, simulação sob demanda).
- Servidor: `MinecraftServer.runServer` → pacing `nanosecondsPerTick`, `tickServer` → `tickChildren` → `ServerLevel.tick(haveTime)` por nível.

## E3 — Registro de um bloco ✅ CONCLUÍDO (auxiliar)
- Resultado: `knowledge/registries/block-registration.md`

## E5b — Fechamento worldgen ✅ CONCLUÍDO
- Resultado: W1–W8 todas resolvidas (ver `research/discoveries/E5-world-generation.md` §11) + `knowledge/world/worldgen-internals.md`.
- Pendências remanescentes V1–V7 (NoiseData.bootstrap, Noises registry, StructurePlacement, BiomeManager helpers, BelowZeroRetrogen, Blender, SurfaceRules eval).
- PRÓXIMO: E6 persistência/NBT OU Entidades (recomendado: Entidades — maior sistema desconhecido).

## E5 — Worldgen ✅ CONCLUÍDO
- Resultado: `research/discoveries/E5-world-generation.md` + `knowledge/world/{world-generation, noise-system, biome-generation, chunk-generation-stages, structures-and-features}.md`.
- Questões abertas W1–W8 (NoiseRouterData final chain, Aquifer, OreVeinifier, SurfaceSystem datagen, OverworldBiomeBuilder, EndIslandDensityFunction, FeatureSorter, WorldGenRegion semantics).
- PRÓXIMO: E6 persistência/NBT OU E-networking geral OU E-entities; ou W1-W8 (E5b) para fechar worldgen.

## E4b — Light engine + H1–H8 ✅ CONCLUÍDO
- Resultado: `research/discoveries/E4b-light-engine.md` + `knowledge/world/lighting-engine.md`, `lighting-threading.md`, `chunk-save-unload-integrity.md`.
- H1–H8 todas resolvidas (detalhe no discovery E4 §10).
- PRÓXIMO: E5 worldgen detalhado (estruturas/biomas/ruído) ou E6 persistência/NBT; depois Entidades.

## E4 — Carregamento de um chunk ✅ CONCLUÍDO
- Resultado: `research/discoveries/E4-chunk-loading.md` + `knowledge/world/chunk-loading.md`, `chunk-status.md`, `chunk-tickets.md`, `chunk-storage.md`, `chunk-networking.md`.
- Pipeline completo: ServerLevel.tick → ServerChunkCache.tick → DistanceManager/stack de tickets → ChunkMap → GenerationChunkHolder → ChunkGenerationTask → ChunkStatusTasks → FULL (mainThreadExecutor).
- Pendências H1–H8 no discovery; próximos sub-experimentos: E4b (light engine + H1–H8), E5 worldgen/estruturas, E-networking-geral.

## E5 — Pipeline de uma receita
- Objetivo: como `RecipeManager` carrega `RecipeHolder` de data packs e casa com inventários.
- Pontos de partida: `net/minecraft/world/item/crafting/RecipeManager.java`, `net/minecraft/world/item/crafting/RecipeMap.java`, tags de receita.

## E6 — Textura até a renderização
- Objetivo: `Identifier` → `TextureManager` (ReloadListener) → `TextureAtlas`/`AtlasManager` → `Sprite` → render de bloco.
- Pontos de partida: `net/minecraft/client/renderer/texture/TextureManager.java`, `.../texture/atlas/TextureAtlas.java`, `SpriteLoader`.
