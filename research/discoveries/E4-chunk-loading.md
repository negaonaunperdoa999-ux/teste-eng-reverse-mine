# E4 — Carregamento, geração, gerenciamento e descarregamento de chunks

- **Versão:** 26.1.2 · **Data:** 2026-11-05 · **Confiança:** alta [FATO] salvo hipóteses marcadas
- **Fontes (locais, não versionadas):** `tools/MinecraftSourcesGenerator/sources/26.1.2/`
- **Método:** leitura direta + busca de referências. Todos os caminhos/nomes ↓ verificados no código.

## 1. Pipeline completo (visão de 30 segundos)

```
ServerLevel.tick(haveTime)
  → ServerChunkCache.tick(haveTime, tickChunks) [chunkSource.tick @ ~linha 386]
    → TicketStorage.purgeStaleTickets(chunkMap)   (se runsNormally)
    → runDistanceManagerUpdates()                  // DistanceManager + promoteChunkMap + runGenerationTasks
    → tickChunks(profiler, timeDiff)               // spawn mobs por chunk; tickChunkingChunks
    → chunkMap.tick(haveTime)                      // poi + processUnloads + saveChunksEagerly
```
Fila de geração: `ServerChunkCache.getChunkFutureMainThread` → ticket provisório `UNKNOWN` (1 tick) → `ChunkHolder.scheduleChunkGenerationTask(target, map)` → `ChunkGenerationTask` (pirâmide) → `ChunkTaskDispatcher` (worldgen/light) → `applyStep` → `ChunkStatusTasks.*` → `completeFuture`. Salvamento: `ChunkMap.save(chunk)` → `SerializableChunkData.copyOf` → `backgroundExecutor` encode → `SimpleRegionStorage.write` → `IOWorker` → `RegionFileStorage` (`r.x.z.mca`).

## 2. Carregamento de chunks — localização [FATO]

| Classe | Arquivo | Papel |
|---|---|---|
| `ServerLevel` | server/level/ServerLevel.java:340 | Chama `chunkSource.tick` na seção "chunkSource" do tick |
| `ServerChunkCache` | server/level/ServerChunkCache.java | Fachada (ChunkSource 26.1 unobf.); agenda geração, ticks, spawns, broadcast |
| `ChunkMap` | server/level/ChunkMap.java | Coração: storage, loaders, geração, save, tracking, unload, envio |
| `ChunkHolder` / `GenerationChunkHolder` | server/level/ChunkHolder.java, GenerationChunkHolder.java | Estado + futures por ChunkStatus (FULL/BLOCK_TICKING/ENTITY_TICKING) |
| `ChunkStatus / ChunkPyramid / ChunkStep / ChunkStatusTask(s) / ChunkDependencies` | world/level/chunk/status/ | Estágios e dependências |
| `ChunkGenerationTask` | server/level/ChunkGenerationTask.java | Algoritmo de escalonamento por pirâmide |
| `ChunkTaskDispatcher` / `ChunkTaskPriorityQueue` | server/level/ | Fila prioritária por ticket level |
| `DistanceManager` (ChunkMap.DistanceManager) | server/level/DistanceManager.java + ChunkMap | Tickets → nível |
| `LoadingChunkTracker` / `SimulationChunkTracker` / `PlayerTicketTracker` / `FixedPlayerDistanceChunkTracker` | server/level/ | BFS de níveis (DynamicGraphMinFixedPoint) |
| `TicketStorage` / `Ticket` / `TicketType` | world/level/TicketStorage.java + server/level/Ticket*.java | Tickets (SavedData `chunk_tickets`) |
| `ChunkLevel` / `FullChunkStatus` | server/level/ | Conversões nível↔status |
| `SimpleRegionStorage` / `IOWorker` / `RegionFileStorage` / `RegionFile` | world/level/chunk/storage/ | Persistência (.mca, 32x32 chunks) |
| `SerializableChunkData` | world/level/chunk/storage/SerializableChunkData.java | (De)serialização do chunk NBT |
| `PlayerChunkSender` | server/network/PlayerChunkSender.java | Envio adaptativo de chunks |
| `ChunkTrackingView` | server/level/ChunkTrackingView.java | View circular de tracking por jogador |

## 3. Carregamento de um chunk (do pedido ao mundo)

1. Quem pede: `ServerChunkCache.getChunk(...)` (main thread; fora dela faz `supplyAsync(...).join()` na `mainThreadProcessor`), o próprio tick (`getChunkFutureMainThread`) ou outro futuro (ex.: `prepareTickingChunk`).
2. `getChunkFutureMainThread`: cria ticket `new Ticket(TicketType.UNKNOWN, ChunkLevel.byStatus(targetStatus))` — ticket provisório com timeout 1 tick (UNKNOWN flags=18=PERSIST+LOADING+CAN_EXPIRE → expira; purgeStaleTickets o remove).
   - `addTicket` → `ticketStorage.addTicket` → notifica `loadingChunkUpdatedListener` (LoadingChunkTracker.update).
   - `runDistanceManagerUpdates()` → `DistanceManager.runAllUpdates(chunkMap)`: `naturalSpawnChunkCounter`, `simulationChunkTracker`, `playerTicketManager` (todos `runAllUpdates()`), `loadingChunkTracker.runDistanceUpdates(MAX)` — propagação min-fixed-point: custo = nível do vizinho − 1 (chunk mais próximo „vence“), source = ticket level.
   - `setLevel` → `updateChunkScheduling` → cria/reutiliza `ChunkHolder` (writing `updatingChunkMap`), se level ≤ MAX_LEVEL(44) e holder null → new ChunkHolder(...).
3. `chunkHolder.scheduleChunkGenerationTask(targetStatus, chunkMap)` → `GenerationChunkHolder`:
   - `getOrCreateFuture(status)` — array `futures[12]` (uma CompletableFuture por ChunkStatus).
   - Se já done → retorna; senão `rescheduleChunkTask(scheduler, status)` → `ChunkMap.scheduleGenerationTask(status, pos)` → `ChunkGenerationTask.create` → `pendingGenerationTasks.add`.
   - `runDistanceManagerUpdates` também chama `chunkMap.runGenerationTasks()` → `runGenerationTask` para cada task → `worldgenTaskDispatcher.submit(..., pos, chunk::getQueueLevel)`.
4. `ChunkGenerationTask.runUntilWait()` (roda no executor worldgen via dispatcher):
   - Começa em `ChunkStatus.EMPTY` e sobe `EMPTY → STRUCTURE_STARTS → … → FULL` (via `ChunkStatus.getStatusList()`), uma "camada" por vez.
   - Para cada camada: `radius = GENERATION_PYRAMID.getStepTo(targetStatus).getAccumulatedRadiusOf(status)` (ou LOADING_PYRAMID se `canLoadWithoutGeneration()`); itera o quadrado de ±radius; para cada holder: `applyStep(pyramid.getStepTo(status), this, cache)` — escolhe geração vs carga pela `persistedStatus` do chunk vizinho (`status.isAfter(persistedStatus)`); se o persistido cobre, `LOADING_PYRAMID` (quase todo `passThrough` + `loadStructureStarts` + `full`).
   - Espera a camada completar (futures), marca `scheduledLayer`, sobe. `markedForCancellation` se qualquer falha → release.
   - `releaseClaim()` ao fim: `removeTask` + `releaseGeneration` para todos os holders do cache estático (±radius).
5. `ChunkMap.applyStep`:
   - `step.targetStatus() == EMPTY` → `scheduleChunkLoad(pos)` (disco).
   - Senão: holder central deve ter `getChunkIfPresentUnchecked(parent)` não-nulo → `step.apply(worldGenContext, cache, centerChunk)` → `ChunkStep.apply` → a task (ChunkStatusTasks.*) via `task.doWork(...)` — se `persistedStatus < targetStatus` executa e `setPersistedStatus` + JvmProfiler; senão executa igual (regeneração idempotente).
6. LOAD: `scheduleChunkLoad` → `readChunk(pos)` (IO async via `IOWorker.loadAsync` → RegionFileStorage → `r.x.z.mca` por `ChunkPos.getRegionX/Z`, cache LRU de 256 regiões; `NbtIo.read`) → fase `Util.backgroundExecutor().forName("parseChunk")` com `SerializableChunkData.parse(...)` → `poiManager.prefetch` → `thenApplyAsync(..., mainThreadExecutor)`: `parsedData.read(level, poiManager, storageInfo, pos)` → `ProtoChunk`/`LevelChunk` (persistedStatus do NBT "Status") → `markPosition(pos, chunkType)`.
7. FULL (`ChunkStatusTasks.full`): roda na **main thread executor** (`context.mainThreadExecutor`): `ProtoChunk` → `LevelChunk` (via `ImposterProtoChunk` se veio de upgrade); entities do protochunk → `level.addWorldGenChunkEntities`; `setFullStatus`, `runPostLoad`, `setLoaded(true)`, registra block entities e tick container, `unsavedListener` (mark dirty) → future EMPTY…FULL completa.
8. `prepareTickingChunk`: `getChunkRangeFuture(chunk, 1, distance -> ChunkStatus.FULL)` (3x3 FULL) → `postProcessGeneration`, `level.startTickingChunk`, e depois `onChunkReadyToSend` (ou agenda via `sendSyncFuture` quando pronto): marca chunks pendentes para players que rastreiam o chunk → `PlayerChunkSender`.
9. Tick do mundo: `ServerLevel.tick` → `ServerChunkCache.tick(...)` → `tickChunks()` → `forEachBlockTickingChunk` → `level.tickChunk` / mob spawning nas "spawningChunks".

## 4. Sistema de tickets [FATO]

- **Design:** `TicketStorage` (SavedData `chunk_tickets`, codec `tickets: [{chunk_pos, type, level, ticks_left}]`, DataFixTypes.SAVED_DATA_FORCED_CHUNKS) — **apenas tickets persist()=1 sobrevivem save/load** (`packTickets`). `addTicket`: mesma type+level → `resetTicksLeft` (renova timeout); senão insere; **level mais baixo vence** (`getTicketLevelAt`, min sobre doesLoad/doesSimulate). Listeners: `simulationChunkUpdatedListener` (SimulationChunkTracker), `loadingChunkUpdatedListener` (LoadingChunkTracker).
- **`Ticket`**: `{type, ticketLevel, ticksLeft}`; `ticksLeft` só decrementa se `hasTimeout()`; `purgeStaleTickets` (chamado no início de cada `ServerChunkCache.tick`) → `decreaseTicksLeft` e remove se `< 0` (após `canTicketExpire` respeitar `canExpireIfUnloaded` / `isReadyForSaving`).
- **FLAGS (TicketType.flags):** PERSIST=1, LOADING=2, SIMULATION=4, KEEP_DIMENSION_ACTIVE=8, CAN_EXPIRE_IF_UNLOADED=16.
- **Catálogo real (TicketType, todos registrados em BuiltInRegistries.TICKET_TYPE):**

| type | timeout(ticks) | flags | persist | load | sim | dimensão? | expire-if-unloaded |
|---|---|---|---|---|---|---|---|
| `player_spawn` | 20 | 2 | – | ✓ | – | – | – |
| `spawn_search` | 1 | 2 | – | ✓ | – | – | – |
| `dragon` | 0 | 6 | – | ✓ | ✓ | – | – |
| `player_loading` | 0 | 2 | – | ✓ | – | – | – |
| `player_simulation` | 0 | 12 | – | ✓ | ✓ | ✓ | – |
| `forced` | 0 | 15 | ✓ | ✓ | ✓ | ✓ | – |
| `portal` | 300 | 15 | ✓ | ✓ | ✓ | ✓ | – |
| `ender_pearl` | 40 | 14 | – | ✓ | ✓ | ✓ | ✓ |
| `unknown` | 1 | 18 | ✓ | ✓ | – | – | ✓ |

- **Níveis (ChunkLevel):** `isLoaded(level) := level <= MAX_LEVEL(44)`; `fullStatus`: ≤31 `ENTITY_TICKING`, 32 `BLOCK_TICKING`, 33 `FULL`, senão `INACCESSIBLE`. `byStatus(status) = 33 + FULL_STEP.accumulatedDependencies.getRadiusOf(status)` (computado: EMPTY/STRUCTURE_STARTS→44, STRUCTURE_REFERENCES/BIOMES→36, NOISE/SURFACE/CARVERS→35, FEATURES/INITIALIZE_LIGHT→34, LIGHT/SPAWN/FULL→33). `generationStatus(level) = getStatusAroundFullChunk(level-33)`: 44→STRUCTURE_STARTS, 36→BIOMES, 35→CARVERS, 34→INITIALIZE_LIGHT, 33→FULL. `RADIUS_AROUND_FULL_CHUNK = 11`, `MAX_LEVEL = 44`.
- **Propagação (ChunkTracker → DynamicGraphMinFixedPoint):** nível(nó) = min_{vizinhos(3x3) ∪ source} (nível_vizinho + 1); source = `ticketStorage.getTicketLevelAt(to, simulation)` (LoadingChunkTracker: tickets doesLoad; SimulationChunkTracker: doesSimulate, default 33). So a **menor** distância vence — tickets espalham "custo crescente" pelo mundo.
- **PlayerTicketTracker** (maxDistance=32, `viewDistance` = serverViewDistance ou requestedViewDistance clampado 2..32): cria/remove `Ticket(PLAYER_LOADING, 31)` **em todas as posições dentro do view distance** via `ThrottlingChunkTaskDispatcher` (4 permits, ordenado por nível); `PLAYER_SIMULATION` com `level=max(0,31−simulationDistance)` (default 10 → 21) em `addPlayer/removePlayer` (SectionPos). `naturalSpawnChunkCounter`: FixedPlayerDistanceChunkTracker(8) para spawn.
- **Forçados:** `updateChunkForced` → `Ticket(FORCED, FORCED_TICKET_LEVEL=31)` persistente → `getForceLoadedChunks` = chunks com FORCED (usado p/ `chunk_tickets` e biome/source… confirmar consumidores no TODO-E4b).
- **Definitivamente:** `addTicketWithRadius(type,pos,radius)` = `Ticket(type, 33−radius)` — note nível mais baixo (mais forte) para raio maior.
- **Churn de tickets de jogador:** `DistanceManager.removePlayer` remove `PLAYER_SIMULATION`; `ticketsToRelease` (PLAYER_LOADING release quando holder null) → dispatcher.release. `updatePlayerTickets(viewDistance)` → `playerTicketManager.updateViewDistance` → transitionSaw/Sees → add/remove PLAYER_LOADING (via dispatcher; release com `clearQueue=false/true` credit).
- **Salvamento de tickets:** SavedData integrado ao `SavedDataStorage` do dimension (`savedDataStorage` em ServerChunkCache) → persistido em `<dimension>/data/chunk_tickets.dat` (formato NamespacedSavedData `minecraft:chunk_tickets`, DataFixTypes.SAVED_DATA_FORCED_CHUNKS). [FATO — ver TicketStorage.TYPE]
- **Fecha em shutdown:** `deactivateTicketsOnClosing()` (todos exceto UNKNOWN) e `activateAllDeactivatedTickets()` no start (referência: ServerChunkCache.deactivateTicketsOnClosing → quem chama: MinecraftServer stop; quem chama activate: verificar no E4b).

## 5. ChunkStatus — estágios [FATO]

Ordem (índice = posição no `CHUNK_STATUSES`, `getStatusList()` reverso de FULL):
`EMPTY(0) → STRUCTURE_STARTS(1) → STRUCTURE_REFERENCES(2) → BIOMES(3) → NOISE(4) → SURFACE(5) → CARVERS(6) → FEATURES(7) → INITIALIZE_LIGHT(8) → LIGHT(9) → SPAWN(10) → FULL(11)`
- `CHUNK_STATUS` é registry built-in (`BuiltInRegistries.CHUNK_STATUS`), codec `ChunkStatus.CODEC = byNameCodec()`.
- `heightmapsAfter`: WORLDGEN_HEIGHTMAPS (OCEAN_FLOOR_WG+WORLD_SURFACE_WG) até CARVERS (índice ≤6); FINAL_HEIGHTMAPS (OCEAN_FLOOR+WORLD_SURFACE+MOTION_BLOCKING+MOTION_BLOCKING_NO_LEAVES) de CARVERS em diante. `FINAL_HEIGHTMAPS` usados a partir de CARVERS (Constant FINAL for steps CARVERS..FULL).
- `ChunkType`: PROTOCHUNK até SPAWN; LEVELCHUNK só em FULL.
- **Tarefas (GENERATION_PYRAMID):**

| Step | Task | Dependências (direct → raio) | blockStateWriteRadius |
|---|---|---|---|
| EMPTY | passThrough | — | — |
| STRUCTURE_STARTS | generateStructureStarts (`createStructures` se `generateStructures()`) | parent(EMPTY) | — |
| STRUCTURE_REFERENCES | generateStructureReferences (`createReferences`) | STRUCTURE_STARTS r=8 | — |
| BIOMES | generateBiomes (`createBiomes` async NoiseBased) | STRUCTURE_STARTS r=8 | — |
| NOISE | generateNoise (`fillFromNoise` + BelowZeroRetrogen fix) | STRUCTURE_STARTS r=8, BIOMES r=1 | 0 |
| SURFACE | generateSurface (`buildSurface`) | STRUCTURE_STARTS r=8, BIOMES r=1 | 0 |
| CARVERS | generateCarvers (`applyCarvers` + Blender mask) | STRUCTURE_STARTS r=8 | 0 |
| FEATURES | generateFeatures (`primeHeightmaps` + `applyBiomeDecoration`) | STRUCTURE_STARTS r=8, CARVERS r=1 | **1** |
| INITIALIZE_LIGHT | initializeLight (`initializeLightSources` + lightEngine.initializeLight; `isLightCorrect` gate) | — | — |
| LIGHT | light (`lightEngine.lightChunk`) | INITIALIZE_LIGHT r=1 | — |
| SPAWN | generateSpawn (`spawnOriginalMobs` se !isUpgrading) | BIOMES r=1 | — |
| FULL | full (main thread; ProtoChunk→LevelChunk; entities postLoad; registerBlockEntities; setFullStatus+loaded) | — | — |

- **LOADING_PYRAMID** (chunks presentes em disco): `loadStructureStarts` (chama `level.onStructureStartsAvailable`), `initializeLight`, `light`, `full`; o resto `passThrough`. `canLoadWithoutGeneration()` escolhe LOADING vs GENERATION **por camada** — se `persistedStatus` cobre o target, todas as camadas vizinhas só carregam.
- Dependências de máx estrutura = `MAX_STRUCTURE_DISTANCE = 8` (chunks vizinhos até 8 de raio precisam de STRUCTURE_STARTS antes das referências/biomas — por isso r=8).
- `ChunkStep.apply`: só executa a task se `persistedStatus < targetStatus`; senão idempotente (executa igual, mas `setPersistedStatus` pula). Depois completa o future por índice (`AtomicReferenceArray futures[12]` com `compareAndExchange`).
- **Falha de futuro:** `maxFailure` → `ChunkResult.error` ("Not done yet"/"Unloaded chunk"); `failAndClearPendingFuturesBetween` quando ticket cai — futures pendentes viram `UNLOADED_CHUNK`.

## 6. Threads e processamento assíncrono [FATO]

- Executors: `Util.backgroundExecutor()` → pool fixo `Main` de `maxAllowedExecutorThreads()=clamp(cores−1,1,max.bg.threads=255)` (8 cores → 7 threads). `Util.ioPool()` → cached `IO-Worker-N` (não-daemon) para IO de disco (`IOWorker`). `Util.backgroundExecutor().forName("parseChunk")` — fila dedicada para parse (ConsecutiveExecutor TracingExecutor).
- `ChunkMap`: `worldgen` = `ConsecutiveExecutor(executor=background,"worldgen")`, `light` = `ConsecutiveExecutor(executor,"light")`; `worldgenTaskDispatcher` e `lightTaskDispatcher` = `ChunkTaskDispatcher(ConsecutiveExecutor, executor)`. Internamente: `PriorityConsecutiveExecutor(4, ...)` + `ChunkTaskPriorityQueue` (`PRIORITY_LEVEL_COUNT=MAX_LEVEL+2=46` filas por ticket level; pop sempre da fila de menor nível (mais restrito = mais prioritário), LRU dentro do nível via `Long2ObjectLinkedOpenHashMap`).
- `ThreadedLevelLightEngine` recebe `light` ConsecutiveExecutor + `lightTaskDispatcher` — MESMA política: tasks de light passam pela fila prioritária.
- `ChunkGenerationTask` roda **na thread worldgen** (`worldgenTaskDispatcher.submit` com `chunk::getQueueLevel`); `ChunkStatusTasks.full` vai para a `mainThreadExecutor` (ServerChunkCache.MainThreadExecutor, “Chunk source main thread executor”). Light engine tem suas próprias threads (ver E4b).
- Sincronização: `StaticCache2D<GenerationChunkHolder>` (cache 2D imutável por task), `AtomicReferenceArray futures` com CAS, `startedWork` (compareAndExchange para bump de status sequencial), `generationRefCount` (StaticCache2D acquire/release), `pendingFullStateConfirmation` (cancel(false) para despromover). `GenerationChunkHolder.replaceProtoChunk` CAS trocando futures do pre-FULL para o ImposterProtoChunk.
- Backpressure: `ThrottlingChunkTaskDispatcher(executor, 4)` — 4 tickets por vez (PLAYER_LOADING add/release) e `maxUnacknowledgedBatches=10` no send de chunks; `CHUNK_SAVED_PER_TICK/CHUNK_SAVED_EAGERLY_PER_TICK/MAX_ACTIVE_CHUNK_WRITES` — **ATENÇÃO:** `CHUNK_SAVED_PER_TICK=200`, `CHUNK_SAVED_EAGERLY_PER_TICK=20`, `EAGER_CHUNK_SAVE_COOLDOWN_IN_MILLIS=10000` declaradas em ChunkMap mas **sem referências no restante do arquivo** → `MAX_ACTIVE_CHUNK_WRITES=128` É usado (em `saveChunksEagerly`) e `nextChunkSaveTime` usa `+10000L` inline. (Constantes parcialmente mortas — ver hipótese H1.)
- `saveChunkIfNeeded`: throttle por chunk de **10 s** (`nextChunkSaveTime.put(pos, now + 10000L)`).
- Overloads do server: `hasWork()` = light ou savingPending ou updatingChunkMap não-vazio ou dispatchers com trabalho ou tickets — usado por `MinecraftServer.haveTime`? (não confirmado; ver E4b)

## 7. Armazenamento [FATO]

- Layout: `<worldFolder>/<dimension>/region/r.<x>.<z>.mca` (`RegionFileStorage`): `r.x.z.mca`, 32×32 chunks por região, setor de 4 KB (`SECTOR_BYTES=4096`), header de 2 setores (4096+4096), `MAX_CACHE_SIZE=256` regions LRU, `.mcc` externo se > 256 setores (`EXTERNAL_STREAM_FLAG=128`). POI em `<dim>/poi/` (`PoiManager`, mesma engine).
- Leitura: `RegionFileStorage.read` → `NbtIo.read(DataInputStream)`; `scanChunk` com `StreamTagVisitor` (CollectFields p/ Blender — `blending_data`, `DataVersion` < 4295 → “old chunk”).
- `SimpleRegionStorage`: dá `CompletableFuture` read/write + `upgradeChunkTag` (DataFixer, `DataFixTypes.CHUNK`).
- `IOWorker`: única thread através de `PriorityConsecutiveExecutor(FOREGROUND,BACKGROUND,SHUTDOWN)` sobre `ioPool()`; `pendingWrites` (LinkedHashMap) coalescendo writes pendentes por posição — leitura durante write pendente devolve cópia (`PendingStore.copyData`); `synchronize(flush)` aguarda writes pendentes + opcional `storage.flush()`; `close` → SHUTDOWN priority barrier.
- Serialização (`SerializableChunkData.write`): `Status` (codec CHUNK_STATUS), `xPos/zPos`, `Heightmaps`, `isLightOn`, `sections` (palettedContainers por seção incl. `BlockLight`/`SkyLight` internos), `block_ticks`/`fluid_ticks` (`SavedTick.filterTickListForChunk`), `entities` (ValueInputList — só ProtoChunk/entities pendentes? lido via `protoChunk.getEntities()`), `blending_data`, `below_zero_retrogen`, `UpgradeData`, `block_entities`, `PostProcessing`?, tags de estruturas? (StructureStarts via `getAllStarts`? — ver E4b) — **parse**: `Status` ausente → `ChunkStatus.EMPTY` (regeneração total).
- Save: `ChunkMap.save` → só se `isUnsaved()`; se `persistedStatus` é protótipo e existe chunk FULL no disco → descarta (`isExistingChunkFull` via `chunkTypeCache` ou re-read do disco); senão `SerializableChunkData.copyOf(level, chunk)` → `CompletableFuture.supplyAsync(data::write, backgroundExecutor)` → `write(pos, encodedData::join)` → `SimpleRegionStorage.write` → `IOWorker.store` → FOREGROUND → `PendingStore` → BACKGROUND `runStore` → `storage.write` → NbtIo.write.
- Descarregamento: `processUnloads`: `toDrop` (level >44) → holder movido para `pendingUnloads` → `scheduleUnload`: aguarda `saveSyncFuture` → `getLatestChunk` → se LevelChunk: `setLoaded(false)` → `save(chunk)` → `level.unload(levelChunk)` → `lightEngine.updateChunkStatus` + `tryScheduleUpdate`. Fila de unload: `unloadQueue` processa `max(0, size-2000)` mínimos extras por tick.
- Eager save: `chunksToEagerlySave` (unsavedListener) + `saveChunksEagerly` (máx 20/tick, ≤128 writes ativos).

## 8. Sincronização com o cliente [FATO]

- Tracking: `PlayerMap` + `ChunkMap.updateChunkTracking(player)` → `ChunkTrackingView.of(chunkPos, playerViewDistance)` (viewDistance = `min(requestedViewDistance, serverViewDistance)` clampado 2..32; servidor força serverViewDistance). `updateChunkTrackingView` → `ChunkTrackingView.difference(prev, next, onEnter=markChunkPendingToSend, onLeave=dropChunk)`.
- Envio: `PlayerChunkSender` (por conexão): `pendingChunks` ordenado por `distanceSquared` ao jogador; `batchQuota` acumulador com `desiredChunksPerTick` (inicial 9.0, clamp 0.01..64; NAN→0.01); `MAX_UNACKNOWLEDGED_BATCHES=10` após ACK (inicia com `maxUnacknowledgedBatches=1`); pacotes por batch: `ClientboundChunkBatchStartPacket` → `ClientboundLevelChunkWithLightPacket(chunk, lightEngine, null, null)` × N → `ClientboundChunkBatchFinishedPacket(N)`.
- ACK do cliente: `ServerboundChunkBatchReceivedPacket(desiredChunksPerTick)` — enviado no `handleChunkBatchFinished` do cliente junto ao `chunkBatchSizeCalculator` local (client calcula desired a partir do tempo de processamento). Servidor chama `onChunkBatchReceivedByClient` → decrementa `unacknowledgedBatches`, aplica novos valores.
- Payload: `ClientboundLevelChunkPacketData`: `heightmaps` (filtro `Usage.CLIENT` → WORLD_SURFACE, MOTION_BLOCKING, MOTION_BLOCKING_NO_LEAVES), `buffer` com seções serializadas (2 MB max, `TWO_MEGABYTES`), `blockEntitiesData` (NBT por bloco); `ClientboundLightUpdatePacketData`: BitSet skyChanged/blockChanged + arrays de 4096 bytes (16 seções × 256). [FATO — Heightmap.Types Usage.CLIENT; ClientboundLevelChunkPacketData]
- Cliente: `handleLevelChunkWithLight` → `PacketUtils.ensureRunningOnSameThread` → `updateLevelChunk` → `level.getChunkSource().replaceWithPacketData(x,z,buffer,heightmaps,blockEntitiesConsumer)` → fila `level.queueLightUpdate(...)`: `applyLightData` → `getChunk` → `enableChunkLight` → `minecraft.levelRenderer.onChunkReadyToRender(pos)`. `handleForgetLevelChunk` → `level.getChunkSource().drop(pos)` + `queueLightRemoval`.
- Chunk **ainda não enviado**: `getChunkToSend` retorna null enquanto `sendSync` não-done.
- Biomes: `ClientboundChunksBiomesPacket` (sendChunkBiomesForAllPlayers?) — usado se `resendBiomesForChunks` (ver `ChunkMap.resendBiomesForChunks`).

## 9. Problemas e limitações desta investigação
- Ambiente sem Java 25 em PATH na sessão? Java 25 OK; apenas leitura estática — sem runtime de servidor dedicado rodado (E4 não executou o jogo).
- `prepareTickingChunk` vs `prepareEntityTickingChunk` — nuance de callers (entity ticking 31). **Não confundir** com spawn de entidades.
- `THROTTLE` — `CHUNK_SAVED_PER_TICK`/`CHUNK_SAVED_EAGERLY_PER_TICK`/`EAGER_CHUNK_SAVE_COOLDOWN_IN_MILLIS` sem usos no ChunkMap (H1).

## 10. Questões pendentes / hipóteses (TODO E4b)
- H1: constantes declaradas-e-não-usadas em ChunkMap (`CHUNK_SAVED_PER_TICK` etc.) — buscar uso global; se ausente, código morto (flag: 26.1.2 pode ter substituído por throttle inline 10 s).
- H2: `resendBiomesForChunks` / quando usado (Ressync de biome streaming em debug?).
- H3: quem chama `activateAllDeactivatedTickets` (suspeita: MinecraftServer.loadLevel → ServerChunkCache.restart/activate).
- H4: fluxo `ChunkTrackingView.Positioned.squareIntersects` otimização de diferença (raio<2 quando viewDistance pequena) — documentado como centrado na estrutura "Positioned".
- H5: `ThreadedLevelLightEngine.initializeLight/lightChunk` — contrato das threads de light (não dissecado; separar para E-light).
- H6: `chunksToUpdateFutures` acumula holders cujo ticketLevel mudou após `setLevel` — confirmado uso; confirmar todos os callers fora de DistanceManager (ex.: PlayerTicketTracker? não usa).
- H7: Orden de `onChunkReadyToSend` vs `ChunkStatusUpdateListener` (ChunkMap sa)?
- H8: `generationSaveSyncFuture` — não bloquear save durante geração (confirmado por leitura: `increaseGenerationRefCount` → `generationSaveSyncFuture` completado em decreaseGenerationRefCount; usada como save dependency).

## Referências (fontes consultadas)
Arquivos listados na seção 2. Lições aplicadas: 12 buscas direcionadas com Select-String; sem benchmarks; sem execução do jogo.
