# E5 — Geração procedural do mundo (26.1.2)

- **Versão:** 26.1.2 · **Data:** 2026-11-05 · **Confiança:** alta [FATO] salvo hipóteses
- **Método:** leitura direta + busca de referências. Sem execução/runtime.

## 1. Arquitetura geral

```
worldgen/default_settings (data/worldgen/NoiseData.java etc., NoiseRouterData)
        │
        ▼
RandomState (seed → RandomSource/Xoroshiro; noises cacheados em ConcurrentHashMap;
             router "wired" com instâncias reais; BlendedNoise com random do terrain)
        │
BiomeSource (MultiNoiseBiomeSource: 6D-7D climate R-tree)
        │
        ▼
NoiseChunk (células 4×4×cellH, trilhinear; markers Interpolated/FlatCache/Cache2D/CacheOnce/CacheAllInCell)
        │
        ▼
doFill (wgen_fill_noise) → BlockStatePorbloco via blockStateRule (Aquifer → OreVeins)
        │
        ▼
WorldGenRegion → Carvers (±8) → Decoration (GenerationStep.Decoration N etapas) → LIGHT → FULL
```

## 2. Estágios e executors [FATO — ChunkStatusTasks / ChunkPyramid]
| Estágio | Chamada assíncrona | Executor |
|---|---|---|
| EMPTY (load) | `scheduleChunkLoad` (decodifica NBT) | mainThread (então parseChunk) |
| STRUCTURE_STARTS | `generator.createStructures(...)` | caller thread (worldgen) |
| STRUCTURE_REFERENCES | `generator.createReferences(...)` | worldgen |
| BIOMES | `createBiomes` → `CompletableFuture.supplyAsync` | **`Util.backgroundExecutor().forName("init_biomes")`** |
| NOISE | `fillFromNoise` → `supplyAsync` | **`wgen_fill_noise`** |
| SURFACE/CARVERS/FEATURES | `buildSurface`/`applyCarvers`/`applyBiomeDecoration` | worldgen |
| INITIALIZE_LIGHT/LIGHT | `ThreadedLevelLightEngine.*` | thread "light" |
| SPAWN | `spawnOriginalMobs` | worldgen |
| FULL | `ChunkStatusTasks.full` | **main thread executor** |

## 3. "Células" e ruído [FATO]
- Overworld: `NoiseSettings OVERWORLD = (minY=-64, height=384, sizeH=1, sizeV=2)` → **cellWidth=4, cellHeight=8**. Nether (0,128,1,2), End (0,128,2,1 → 8×4).
- `NoiseChunk` cria grid `noiseSizeXZ = QuartPos.fromBlock(cellCountXZ * cellWidth)` quarts? (sizeXZ = 16/cellWidth contados em quarts → 4).
- Density functions: `BlendedNoise(xzScale=1.0? [ver NoiseRouterData], yScale, xzFactor, yFactor, smearScaleMultiplier)` — minLimit/maxLimit Perlin(-15..0), main (-7..0), `xzMultiplier = 684.412 * xzScale`, `yMultiplier = 684.412 * yScale`, 8 iterações main + 16 min/max com `pow /= 2`, `blendMin/Max` combinados por `factor = (main/10 + 1) / 2` (clamp implícito por Perlin selado).
- Marcadores (`DensityFunctions.Marker`): `Interpolated` → `NoiseInterpolator` (trilhinear via `slice0/slice1` arrays por célula, updateForX/Y/Z), `FlatCache` (2D por coluna), `Cache2D` (2D lazy), `CacheOnce`, `CacheAllInCell` (array pré-preenche + fillArray).
- **Funções de densidade compostas** (registro codecs DIRECT_CODEC): badlands_squeezed_router? Não — funções vanilla vêm de `data/worldgen/noise/*` + `NoiseRouterData` (final_density = `cacheAllInCell(add(final_noise, beardifier))`, squeezed? — em 1.18+: `finalDensity = cacheAllInCell(add(interpolated_final, beardifier).clamp(-1,1))` etc. — depende do datapack; a vanilla chain não é lida nesta investigação).

## 4. Biomas [FATO]
- `BiomeSource` interface; overworld = `MultiNoiseBiomeSource` (holder `MultiNoiseBiomeSourceParameterList` preset `minecraft:overworld`) com `Climate.ParameterList<Holder<Biome>>` — **7 dimensões**: temperature, vegetation(humidity), continents, erosion, depth, weirdness, offset.
- `Climate.Sampler.sample(qx,qy,qz)` → `TargetPoint(quantizado em 1e-4)`.
- Lookup: **R-tree 7D** (`Climate.RTree`, CHILDREN_PER_NODE=6, ThreadLocal<Leaf> lastResult) — nearest neighbor por distância L∞ de `fitness`. `findValueBruteForce` para debug.
- `fillBiomesFromNoise` preenche quarts 4×4×4 por seção (`fillBiomesFromNoise` PalettedContainer<Holder<Biome>>).
- Spawn targets (`settings.spawnTarget()` — lista de `Climate.ParameterPoint` para spawn de mundo).

## 5. Pontos de seed [FATO]
- `RandomState.random = settings.getRandomSource().newInstance(seed).forkPositional()`; `aquiferRandom = fromHashOf("aquifer")`, `oreRandom = fromHashOf("ore")`.
- `BlendedNoise` rewired com `terrainRandom` = `fromHashOf("terrain")` (ou legacy seed offset 0 se `useLegacyRandomSource()`).
- LegadoNetherBiome: `createLegacyNetherBiome` com seed+0/1.
- Estruturas: `setLargeFeatureSeed(seed, x, z)`; decoração: `setDecorationSeed(seed, minBlockX, minBlockZ)` + `setFeatureSeed(decorationSeed, index, step)` — tudo determinístico por posição.

## 8. Estruturas e features [FATO]
- `createStructures`: para cada `StructureSet` (registry) → `featurePlacement.isStructureChunk(state, x, z)` (spacing/separation/salt) → entradas pesadas aleatórias (`WorldgenRandom.setLargeFeatureSeed`) → `tryGenerateStructure` → biome predicate → `structure.generate(...)` → `setStartForStructure`.
- `createReferences`: marca referência de estrutura em chunks vizinhos até 8 (r=8, MAX_STRUCTURE_DISTANCE).
- Decoração: `ChunkGenerator.applyBiomeDecoration` — `GenerationStep.Decoration.values().length` etapas; estruturas no step via `structuresByStep` (stage do structure registrada); features por biome em `featuresPerStep` (cache) com `FeatureSorter` (X entries bucket) — seeds `setFeatureSeed`.
- Carvers: ±8 chunks ao redor (`applyCarvers` loop `dx,dz ∈ [−8..8]`), `random.setLargeFeatureSeed(seed + index, x, z)`.

## 9. Relações com E4/E4b
- `Blender` (blending 1.18→blend old chunks) — pré-disponível via `Blender.of(region)` — interage com `structure starts` etc.
- `BiomeManager.withDifferentSource(...)` usado pelos carvers para noise biome correto.
- Iluminação não faz parte da geração de terreno (mas INITIALIZE_LIGHT/LIGHT vêm depois de FEATURES no pirâmide).
- Storage/unload descritos em E4; save durante geração: refs `generationRefCount` (H8).

## 10. Limitações desta investigação
- Chaves de noise exatas da vanilla (`minecraft:overworld/...`) não lidas nesta sessão — apenas o mecanismo.
- `NoiseRouterData`/`Noises` central (registry lookups) não lida — recomendado E5b.
- `Aquifer`/`OreVeinifier` parcialmente lidos (suporte documentado, não dissecados).
- Fórmulas de noise não verificadas numericamente; `BlendedNoise` lido linha a linha exceto `compute` (parte final limitada).

## 11. Questões pendentes (E5b)
- W1: ler `NoiseRouterData.java` (cadeia vanilla de DensityFunction) + `DensityFunctions` (~2000 funções registradas como codecs?).
- W2: aquifer algorithm (`Aquifer.java` 20+ KB) — beber/secar/pirâmide de águas? verificar criação em `Aquifer.create`.
- W3: `OreVeinifier` minerais raros (copper/diamond blobs) — ler `OreVeinifier.java`.
- W4: `SurfaceSystem` regras por biome (`surfaceRule()` no datagen `SurfaceRuleData`) — verificar aplicação por coluna; `nota`: um cálculo NBT de bloco raiz por coluna, não por bloco (otimização).
- W5: `OverworldBiomeBuilder`/`OverworldBiomeBootstrap` — construir lista de ParameterPoints vanilla (se presente na 26.1.2 com datapack-ready registries?).
- W6: `WorldGenRegion` — as regras de "chunk completo" para in-gen (vs. FEATURES write radius=1).
- W7: `BiomeManager.findBiome`, `BiomeGenerationSettings` (getCarvers) — como biome decide features/carvers/estruturas.
- W8: `EndIslandDensityFunction` (`DensityFunctions.EndIslandDensityFunction`) — usado só no End via RandomState wiring.
