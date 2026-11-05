# E4b — Sistema de iluminação (Light Engine) — 26.1.2

- **Versão:** 26.1.2 · **Data:** 2026-11-05 · **Confiança:** alta [FATO] salvo hipóteses marcadas
- **Fontes:** `sources/26.1.2/net/minecraft/{server/level,world/level/lighting,world/level/chunk/storage}/`

## 1. Arquitetura geral (camadas)

```
block ops (setBlock etc.)
   │  ChunkMap / PlayerChunkSender? não — quem chama? ver §2
   ▼
ThreadedLevelLightEngine (server/level)  ── estende LevelLightEngine ── LightEventListener
   │  addTask(x, z, [level], TaskType.PRE/POST_UPDATE, runnable)
   ▼  (via lightTaskDispatcher → ChunkTaskPriorityQueue por ticket level)
   ├─ tasks acumulam em lightTasks (batch de 1000) ou consecutiveExecutor.tryScheduleUpdate
   ▼
LevelLightEngine (world/level/lighting)
   ├─ BlockLightEngine (LightEngine<BlockLightSectionStorage.BlockDataLayerStorageMap, BlockLightSectionStorage>)
   └─ SkyLightEngine  (LightEngine<SkyLightSectionStorage.SkyDataLayerStorageMap, SkyLightSectionStorage>)
        ▼
      LightEngine<M,S> (abstrato): blockNodesToCheck(Set<long> 512), decreaseQueue, increaseQueue (LongArrayFIFOQueue)
        ▼
      LayerLightSectionStorage<M> (abstrato): updatingSectionData (visível p/ escrita) + visibleSectionData (swap),
         queuedSections (sincronizado), sectionStates (byte: bit5 HAS_DATA | bits0-4 neighborCount ≤26),
         sectionsAffectedByLightUpdates → chunkSource.onLightUpdate(...) (→ ServerChunkCache.onLightUpdate → broadcast)
        ▼
      DataLayerStorageMap<M>: Long2ObjectOpenHashMap<DataLayer> + cache L2 de 2 seções (lastSectionKeys/lastSections)
```

## 2. Quem dispara atualizações de luz
- `ServerChunkCache.onLightUpdate(layer, pos)` (implementa `LightChunkGetter`? não — é chamado por `LayerLightSectionStorage.swapSectionMap` via `chunkSource.onLightUpdate`) — manda `chunkHolder.sectionLightChanged(layer, y)` via mainThreadProcessor (marca bit skyChanged/blockChanged + `chunk.markUnsaved()`). [FATO — ServerChunkCache]
- `ChunkHolder.sectionLightChanged` (só a light correta, exige `INITIALIZE_LIGHT` presente) — registra mudança p/ sincronização.
- `ThreadedLevelLightEngine.checkBlock/updateSectionStatus/propagateLightSources/setLightEnabled/queueSectionData/retainData` — todos wrappeados em `addTask` (despacho via lightTaskDispatcher; nível de ticket da posição).
- `ChunkMap.scheduleUnload` → `lightEngine.updateChunkStatus(chunk.getPos())` (PRE_UPDATE: `retainData(pos,false)` + `setLightEnabled(pos,false)` + `queueSectionData(BLOCK/SKY, null data)` + `updateSectionStatus(..., true=empty)`) — remove dados de luz do chunk ao descarregar.
- `ChunkMap.waitForLightBeforeSending(center, radius)` → `chunkHolder.addSendDependency(lightEngine.waitForPendingTasks(x, z))` — caso EnderDragon (único caller [FATO — EnderDragonFight]).

## 3. Contrato de execução assíncrona [FATO — ThreadedLevelLightEngine.java]
- `addTask` → `taskDispatcher.submit(() -> { lightTasks.add(Pair.of(type, runnable)); if (lightTasks.size() >= 1000) runUpdate(); }, pos.pack(), chunkMap.getChunkQueueLevel(pos) veya level)`
  ⇒ tarefas de light entram na **mesma fila prioritária** do worldgen (ChunkTaskPriorityQueue por ticket level — nível de chunk; menor = mais prioritário). Execução dos runnables → apenas acumulam na lista local `lightTasks` (ObjectArrayList) — NÃO executam o trabalho pesado na thread da fila.
- `tryScheduleUpdate()` — chamado pelo `ServerChunkCache.MainThreadExecutor.pollTask()`: se `!lightTasks.isEmpty() || super.hasLightWork()` e `scheduled.compareAndSet(false, true)` → agenda `consecutiveExecutor.schedule(() -> { runUpdate(); scheduled.set(false); })` no `light` ConsecutiveExecutor ("light" thread do ConsecutiveExecutor).
- `runUpdate()` (thread light): processa as primeiras `min(size,1000)` tarefas PRE_UPDATE, depois `super.runLightUpdates()` (= BlockLightEngine + SkyLightEngine: drena `blockNodesToCheck` → `checkNode`; `propagateDecreases`; `propagateIncreases` — **fixpoint interno, sem cap**), depois as POST_UPDATE na mesma leva.
- `DEFAULT_BATCH_SIZE=1000`, constante `taskPerBatch` (também 1000) declarada e não usada fora (ver hipótese H1 — mesmo padrão; não era esta).
- `runLightUpdates()` lançado da thread errada → `UnsupportedOperationException` (“Ran automatically on a different thread!”).
- `initializeLight(chunk, lighted)` → PRE task: seções não-air → `updateSectionStatus(.., false)`; POST task: `setLightEnabled(pos, lighted)` + `retainData(pos, false)` → **CompletableFuture<ChunkAccess>**.
- `lightChunk(chunk, lighted)` → `setLightCorrect(false)`; PRE: `if (!lighted) propagateLightSources(pos)`; POST: `setLightCorrect(true)`.
- `waitForPendingTasks(x, z)` → future vazio como POST task — barreira: quando completa, todas as tarefas light anteriores da posição já rodaram.
- `ChunkStatusTasks.initializeLight` exige `isLightCorrect` prévia (`isLighted()`) senão refaz; `ChunkStatusTasks.light` leva `lightChunk`.

## 4. Como a propagação funciona [FATO]
### Block light
- `BlockLightEngine.checkNode`: se seção tem dados (`storingLightForSection`): `emission=state.getLightEmission()` (0 se a seção não estiver "light on"); se emission < oldLevel → set 0 + `enqueueDecrease(PULL_LIGHT_IN_ENTRY...)`; emissions > 0 → `enqueueIncrease(increaseLightFromEmission(emission, isEmptyShape))`.
- `propagateIncrease`: vizinhos 6 direções; `newToLevel = fromLevel − opacity(toState, min 1)`; respeita oclusão (`Shapes.mergedFaceOccludes` com fromState/toState ceves) — se `newToLevel > toLevel` ⇒ set + enqueue (exceto nível ≤ 1).
- `propagateDecrease`: vizinho ≤ oldFrom−1 → set 0, re-enqueue emissão própria; senão → `increaseOnlyOneDirection` (fonte alternativa pode re-iluminar).
- `QueueEntry`: bits low 4 = nível (0–15), bits 4–10 = direções (6 bits), bit 9 = FLAG_FROM_EMPTY_SHAPE, bit 10 = FLAG_INCREASE_FROM_EMISSION. `PULL_LIGHT_IN_ENTRY = decreaseAllDirections(1)` — o truque “re-pull” para recalcular fonte sob mudança.
### Sky light
- `SkyLightEngine`: `ChunkSkyLightSources` (fontes por coluna, menor Y fonte) + `checkNode` (compara y vs lowestSourceY; `REMOVE_SKY_SOURCE_ENTRY = decreaseSkipOneDirection(15, UP)` quando fonte), `removeSourcesBelow/addSourcesAbove` (desce/sube pelo mapa de luz apagando/acendendo colunas), `propagateFromEmptySections` (propaga através de seções vazias sem dados na borda com otimização horizontal), mesmo `propagateIncrease/Decrease` do bloco.
- `SkyLightSectionStorage`: mantém `topSections` (top por coluna) + `currentLowestY`; `getLightValue(blockNode)` quando `sectionY < topSection` e seção ausente → percorre cima até achar camada (assume 15) — fallback de colunas sem dados.
### Propagação cross-section
`LayerLightSectionStorage` usa `sectionStates` (byte: bit5 HAS_DATA, bits0–4 neighborCount ≤26) para só escrever/armazenar seções com dados reais; seções vazias/não iniciadas não criam DataLayer (isso é a otimização "light section elision").

## 5. Swap / visibilidade [FATO]
- Toda escrita em seção: `changedSections.add` + `copyDataLayer` on write (copy-on-write) dentro de `updatingSectionData`.
- `swapSectionMap()` (fim de `runLightUpdates`): se `changedSections` não vazio → `visibleSectionData = updatingSectionData.copy()` (disableCache); depois `sectionsAffectedByLightUpdates` → `forEach` → `chunkSource.onLightUpdate(layer, SectionPos)` → `ServerChunkCache.onLightUpdate` → main thread executor → `chunkHolder.sectionLightChanged` → broadcast.
- `visibleSectionData` é o que `getDataLayerData(sectionNode, false)` lê (e o que o cliente/save veem).

## 6. O que acontece no save/unload (ver também `chunk-save-unload-integrity.md`)
- `SerializableChunkData.copyOf` lê **visibleSectionData** (`getLayerListener(layer).getDataLayerData`), copia com `.copy()` cada DataLayer + `chunkSections[i].copy()` (cópia profunda) no main thread → encode async em `backgroundExecutor` — snapshot consistente, nunca referencia mutable do engine. [FATO]
- Chunk salvo `isLightCorrect` conforme flag no momento do snapshot; se `false`, no reload `LIGHT`/`INITIALIZE_LIGHT` refazem tudo (gate `isLighted()`).
- Unload: `scheduleUnload` (à espera do `saveSyncFuture`) → `save` → `level.unload` → `lightEngine.updateChunkStatus` + `tryScheduleUpdate`; o `saveSyncFuture` só fecha quando as refs de geração caem a zero + full/accessible futures completam — luz em voo **não** segura o save, mas `isLightCorrect=false` força recálculo no reload.

## 7. Consistência entre chunks vizinhos [FATO]
- Propagação de luz é 6-dir gulosa até ponto fixo dentro de `runLightUpdates()` (drena decreaseQueue e increaseQueue por completo).
- Seções novas: `initializeSection` → cria DataLayer vazia + `markSectionAndNeighborsAsAffected` ±1 → atualizações tocam os 26 vizinhos de seção afetados.
- `sectionsAffectedByLightUpdates` é global ao engine (não por chunk) — updated após swap, enviado via onLightUpdate → `Entier` dirty tracking.

## 8. Limites desta análise (estática)
- `ChunkSkyLightSources` não foi linha-a-linha (algoritmo de coluna ‘lowest source Y’ — indireto via `getLowestSourceY`).
- `DynamicGraphMinFixedPoint` e `LeveledPriorityQueue` (light) não dissecados (existem como helpers; a fila real usada pelo pacote é `LongArrayFIFOQueue` — não é prioridade; fila de PRIORIDADE existe em `ChunkTaskPriorityQueue` para o despacho de tarefas).
- Erros dentro de PRE_UPDATE propagam como exceção na thread light → future `initializeLight`/`lightChunk` nunca completa → chunk trava no estágio — comportamento teórico; não reproduzido em runtime. [RISCO]
- Budget de trabalho por batch (1000) pode adiar luz em mundos com milhões de mudanças simultâneas [RISCO teórico].
