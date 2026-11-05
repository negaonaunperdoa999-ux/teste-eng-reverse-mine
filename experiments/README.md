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

## E4 — Carregamento de um chunk (PRÓXIMO RECOMENDADO)
- Objetivo: rastrear servidor → `ChunkMap`/`ChunkSource` → deserialização → `LevelChunk`; quem chama `level.tick` → `chunkSource.tick`.
- Pontos de partida: `ServerLevel.tick` (seção chunkSource), `net/minecraft/server/level/ServerChunkCache.java`, `net/minecraft/world/level/chunk/storage/ChunkSerializer.java` (ou `SerializableChunkData`), formato `r.x.z.mca` ([DOC] wiki).
- Validação: ler `ServerChunkCache` + `ChunkMap.scheduleChunkLoad` + pipeline de tickets (`TicketType`, `ChunkStatus`).

## E5 — Pipeline de uma receita
- Objetivo: como `RecipeManager` carrega `RecipeHolder` de data packs e casa com inventários.
- Pontos de partida: `net/minecraft/world/item/crafting/RecipeManager.java`, `net/minecraft/world/item/crafting/RecipeMap.java`, tags de receita.

## E6 — Textura até a renderização
- Objetivo: `Identifier` → `TextureManager` (ReloadListener) → `TextureAtlas`/`AtlasManager` → `Sprite` → render de bloco.
- Pontos de partida: `net/minecraft/client/renderer/texture/TextureManager.java`, `.../texture/atlas/TextureAtlas.java`, `SpriteLoader`.
