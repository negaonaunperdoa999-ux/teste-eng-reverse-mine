# dicas.md — Dicas e convenções do laboratório

### Chunks 26.1.2 — fatos-chave (E4)
- ChunkStatus 0..11: EMPTY→FULL. `BuiltInRegistries.CHUNK_STATUS`. MAX_STRUCTURE_DISTANCE=8.
- LOAD vs GEN é por camada via `canLoadWithoutGeneration()`; loaders tocam só `loadStructureStarts` + light + FULL (LOADING_PYRAMID).
- `MAX_LEVEL=44`, `RADIUS_AROUND_FULL_CHUNK=11`, nível 33 = FULL, 32 BLOCK_TICKING, 31 ENTITY_TICKING.
- `byStatus(FULL)=33`; UNKNOWN ticket (timeout 1) provisório para getChunk().
- TicketStorage é SavedData (`chunk_tickets`), só persist() sobrevive restart; PLAYER_SIMULATION nível=max(0,31−simDist).
- Propagação: DynamicGraphMinFixedPoint (min-fixed-point, custo+1 por anel Chebyshev).
- Envio adaptativo: PlayerChunkSender desiredChunksPerTick inicial 9.0 (0.01..64), `maxUnacknowledgedBatches=1→10` após 1º ACK.
- Semantic: vanilla NÃO envia pacote se `sendSync` pendente (getChunkToSend null).

## NoiseRouterData (vanilla, 26.1.2) — fatos registrados
- Cadeia overworld: `shiftX/shiftZ = flatCache(cache2d(shiftA/B))`, `CONTINENTS/EROSION = flatCache(shiftedNoise2d(shiftX, shiftZ, 0.25, noises))`, `RIDGES_FOLDED` = peaksAndValleys, `OFFSET = flatCache(cache2d(lerp(blendAlpha, blendOffset, spline(terrain.overworldOffset)))) + (−0.50375F)`, `DEPTH = yClampedGradient(−64,320,1.5,−1.5) + OFFSET`, `initialDensity = 4.0×quarterNegative((depth+jaggedness)×factor)`, `SLOPED_CHEESE = initialDensity + BASE_3D_NOISE_OVERWORLD`, `caves = rangeChoice(SC, 1.5625, min(SC, 5×ENTRANCES), underground(...))`, `fullNoise = min(postProcess(slideOverworld(caves)), NOODLE).squeeze()`.
- Nether: `slideNetherLike(BASE_3D_NOISE_NETHER(0.25, 0.375, 80, 60, 8))` sobre zeros. End: `islands = cache2d(endIslands(0L))`, `SLOPED_CHEESE_END = add(endIslands, BASE_3D_NOISE_END(0.25, 0.25, 80, 160, 4))`.
## Iluminação 26.1.2 — fatos-chave (E4b)
- Toda luz passa por `ThreadedLevelLightEngine.addTask` → `lightTaskDispatcher` (ChunkTaskPriorityQueue, menor ticket level = prioridade) → `light` ConsecutiveExecutor → `runUpdate`: PRE → `super.runLightUpdates()` (block+sky fixpoint, drena) → POST.
- batch = 1000 tasks (`lightTasks`); `taskPerBatch`/`DEFAULT_BATCH_SIZE` = 1000 (um deles não usado fora).
- `runLightUpdates()` em thread errada → exception explícita.
- `waitForPendingTasks(x,z)` = barreira POST por posição; consumidor: `waitForLightBeforeSending` (só EnderDragon usa hoje).
- Estratégia visible/updating + copy-on-write + batch `changedSections` → `swapSectionMap()` ao final de `runLightUpdates()`; leitores (save/render) só veem visible.
- Seção sem dados NUNCA aloca DataLayer (sectionStates byte: bit5 HAS_DATA, bits0–4 neighborCount).
- `SerializableChunkData.copyOf` copia tudo no main thread — encode async depois, seguro.
- `isLightCorrect=false` ⇒ reload refaz INITIALIZE_LIGHT+LIGHT.
- Glob search > grep (`Select-String`); lembrar de procurar callers com `-SimpleMatch` para evitar erro do scanner.

## Worldgen 26.1.2 — fatos-chave (E5)
- Overworld noise: `NoiseSettings OVERWORLD = (-64,384,1,2)` → cellWidth=4, cellHeight=8 (verify em NoiseSettings.java).
- `NoiseRouter` = 15 DensityFunctions; wiring via RandomState (NoiseWiringHelper) com `noises` registry (Registries.NOISE).
- `BlendedNoise`: minLimit/maxLimit Perlin(-15..0), main(-7..0), `xzMultiplier = 684.412 * xzScale`, `yMultiplier = 684.412 * yScale`; `valueFactor(NormalNoise) = 1/6 / expectedDeviation(span)`.
- Markers: Interpolated→NoiseInterpolator(trilhinear) | FlatCache | Cache2D | CacheOnce | CacheAllInCell; bugdetect: "Trying to sample interpolator outside the interpolation loop".
- BIOME executor: `init_biomes`; NOISE executor: `wgen_fill_noise`; FULL: main thread executor; STRUCTURE/SURFACE/...: worldgen.
- Biomas: quart grid de 4 blocos (`QuartPos.toBlock(n) = n << 4`); consulta via R-tree 7D L∞ com ThreadLocal `lastResult`.
- `fillBiomesFromNoise` preenche 4×4×4 quarts por seção (paletted container).
- Estruturas: `isStructureChunk(spacing/separation/salt)` → weighted choice (setLargeFeatureSeed) → `structure.generate(biomePredicate)` → setStartForStructure; refs r=8.
- SpawnMobs só em geração (SPAWN), nunca em load.
- FEATURES é a única etapa com write radius=1; CARVERS varre ±8 (289 chunks).
- Full pyramid write: NOISE=0, SURFACE=0, CARVERS=0, FEATURES=1.
- "BlendedNoise minLimitNoise" vs "mainNoise" — nunca confundir amplitudes: min/max = 16 octaves, main = 8.

## Aquifer/OreVeins 26.1.2 — fatos registrados
- Aquifer: grade 16×12×16; centros por `positionalRandomFactory.at()`; 12 candidatos → 4 mais próximos; `similarity = 1 − Δd²/25`; `DEEP DARK ⇒ floodedness = −1`; lava se `|lavaNoise| > 0.3` e nível ≤ −10 (células 64×40).
- OreVeinifier: `vein_toggle > 0` → COPPER (Y 0..50, filler GRANITE); senão IRON (Y −60..−8, filler TUFF); `|toggle| + edgeRoundoff ≥ 0.4`; `veinRidged < 0`; `richness = clampedMap(|toggle|, 0.4, 0.6, 0.1, 0.3)`; 2% raw blocks.
- WorldGenRegion: acesso a chunks fora do pirâmide ⇒ `ReportedException` (não silencioso).
- FeatureSorter: DFS topológico sobre grafo `FeatureData[step, index]`; ciclos ⇒ `reducedSources` no erro.

## Pacotes e classes-chave já mapeados (26.1.2)
- Entrypoints: cliente `net.minecraft.client.main.Main#main` · servidor `net.minecraft.server.Main#main`.
- Loop cliente: `Minecraft.run()` → `runTick()` → `renderFrame()` → `tick()` (20 TPS, DeltaTracker.Timer). Ver knowledge/architecture/game-loop.md.
- Loop servidor: `MinecraftServer.runServer()` → `processPacketsAndTick` → `tickServer` → `tickChildren` → `ServerLevel.tick(haveTime)`.
- Pacing servidor: `ServerTickRateManager` (nanosecondsPerTick, /tick rate|freeze|step); "Can't keep up!" pula ticks.
- Agregação MSPT: `tickTimesNanos[100]`, `aggregatedTickTimesNanos`, `smoothedTickTimeMillis` (*0.8 + current*0.2).
- Reload listeners do cliente (ordem importa): language → texture → shader → sound → splash → atlas → font → grass/foliage colors.
- Busca rápida sem ripgrep: `Select-String -Path <arquivo> -Pattern "regex" | % { "$($_.LineNumber): $($_.Line.Trim())" }`.
- Pacotes top-level: world 2559, client 1813, util 713, server 418, network 411 classes (26.1.2).

## Pesquisa no código decompilado (26.1.2, nomes reais da Mojang)
- Pacote raiz: `net.minecraft`. Lado cliente: `net.minecraft.client.*`; servidor: `net.minecraft.server.*`; comum: o resto.
- Entrypoints: cliente `net.minecraft.client.main.Main#main`; servidor dedicado `net.minecraft.server.Main#main`.
- Registries: `net.minecraft.core.registries.Registries` + `net.minecraft.core.Registry` (FrozenRegistry/MappedRegistry).
- Tudo começa por registries + bootstrap (`SharedConstants`, `Bootstrap` / `net.minecraft.server.Bootstrap`).
- IDs de resources: `net.minecraft.resources.Identifier` (antes `ResourceLocation`).
- Data components: `net.minecraft.core.component.DataComponentType`.
- NBT: `net.minecraft.nbt.*`; codec: `net.minecraft.network.codec.*`, `net.minecraft.network.protocol.*`.
- Para achar "quem chama X": use ripgrep em `sources/26.1.2/` (`rg -n "SomeClass"`) ou o mcsrc.dev (find references).

## Ferramentas
- **Vineflower**: decompilador. Já embutido no MinecraftSourcesGenerator; standalone só se precisar de jar avulso.
- **MinecraftSourcesGenerator**: `.\gradlew generateVersion "-Pmc=26.1.2" -Peula=true` dentro do clone em `tools/`.
- **javap** (vem no JDK): `javap -p -c -constants <classe>` para bytecode legível de um método específico.
- **mcsrc.dev**: referência online rápida (comparação de versões, herança). Não substitui análise local.
- **minecraft.wiki** (https://minecraft.wiki): documentação de formato/mecânica (NBT, protocolos, data packs) — versão pode divergir; marcar `[DOC]`.
- **steelmc.dev/development/decompile-minecraft**: guia de decompilação.

## Limitações honestas
- Decompilado ≠ código original. Formatação, nomes de locais (26.1+ são reais), inlining: confie na semântica, não no estilo.
- Versão real do jogo pode ter bugs; o código É a especificação — ao divergir da wiki, o código vence (marque a divergência).
- O cliente unobfuscado ainda usa invokedynamic/lambdas: decompilar com Vineflower > de ler bytecode puro no dia a dia.

## Higiene do repo público
- `.gitignore` protege `sources/`, `work/`, `*.jar`, `eula.txt`. NÃO forçar `git add -f`.
- Antes de cada push: `git status` e conferir que nenhum `.java` decompilado entrou por acidente (`git ls-files | findstr /i "net\\minecraft"`).
- Commits pequenos e descritivos; mensagem em português.

## Performance (8 GB RAM, sem GPU)
- Decompile uma versão por vez; feche VS Code/Zed durante a geração.
- `-Pjobs=1 -PvfThreads=4 -PmaxHeap=4g`.
- Armazenar árvores em SSD local fora do OneDrive se o usuário autorizar (ex.: `C:\mc-sources\`).
