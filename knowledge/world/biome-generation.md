# Mundo — Geração de biomas (26.1.2)

**Confiança:** [FATO] · Evidência: `research/discoveries/E5-world-generation.md` §4, §8

## Visão geral
```mermaid
flowchart TD
  A["NoiseRouter final"] --> B["Climate.Sampler (7 dimensões)"]
  B --> C["sample(qx,qy,qz) → TargetPoint quantizado (×1e4)"]
  C --> D["MultiNoiseBiomeSource.getNoiseBiome"]
  D --> E["Climate.ParameterList.findValue"]
  E --> F["Climate.RTree (7D,6 filhos/nó) nearest L∞"]
  F --> G["Holder<Biome> → PalettedContainer (4³ quart grid)"]
```

## As 7 dimensões climáticas (quarts)
`temperature`, `vegetation` (humidity), `continents`, `erosion`, `depth`, `weirdness` (peaks_and_valleys no debug), + `offset` (usado só na ordenação R-tree/fitness).
`Climate.quantizeCoord(coord) = long(coord × 10000)`; spec ranges tipo ±2.
`PARAMETER_COUNT = 7` (verificado em `Climate.java`).

## Estrutura do registry
`MultiNoiseBiomeSource` (CODEC mapEither direct/preset `minecraft:overworld` etc.) ou `Holder<MultiNoiseBiomeSourceParameterList>`.
Overworld na prática: datapack `data/minecraft/worldgen/multi_noise_biome_source_parameter_list/overworld.json` — usa preset builder (`OverworldBiomeBuilder`) se presente — **não verificado na 26.1.2 (ver W5)**.

## Consulta e normalização
1. `fillBiomesFromNoise`: itera seções; por seção grava container 4×4×4 (quarts).
2. Cada quart chama `biomeResolver.getNoiseBiome(qx, qy, qz, sampler)`.
3. `sampler.sample`: `temperature/vegetation/continents/erosion/depth/ridges` (do NoiseRouter "flattener" deduplicado) + `spawnTarget`; quantiza.
4. `findValue`: R-tree nearest — `fitness(parameters) = Σ L∞ distancia(k)` por dimensão (parametros como intervalos [min,max] — `Parameter.fitness(target)`).
5. Resultado: `Holder<Biome>` com o `biomeResolver` (abaixo-zero retrogen envolve este resolver se necessário — `BelowZeroRetrogen.getBiomeResolver`).

## Relações
- **Surface**: `SurfaceRules` avalia biome para escolher blocos de superfície (`buildSurface`).
- **Estruturas**: predicado de biome (`structure.biomes()`) no STRUCTURE_STARTS; também por `StructurePlacement` (bioma-agnostic pos check + `isStructureChunk`).
- **Features/carvers**: `BiomeGenerationSettings` por biome (carvers ±8, features por step).
- **Climate/soil** no render: `Climate.Sampler` também alimenta F3 debug screen e `density_hq`.

- **Relação 5**: spawnTarget — lista de ParameterPoints construída por `OverworldBiomeBuilder.spawnTarget()` (não lida por inteiro; ver deep dark abaixo).

## OverworldBiomeBuilder (confirmado ativo) [FATO]
`net/minecraft/world/level/biome/OverworldBiomeBuilder.java` (52,8 KB): thresholds `temperatures[5]`, `humidities[5]`, `erosions[7]` e continent/weirdness segments (ex.: `mushroomFieldsContinentalness [-1.2,-1.05]`, `deepOceanContinentalness [-1.05,-0.455]`, `oceanContinentalness [-0.455,-0.19]`, `coastContinentalness [-0.19,-0.11]`, `NEAR_INLAND_START −0.11`, `MID_INLAND_START 0.03`, `FAR_INLAND_START 0.3`), `PEAK_START 0.56666666`, `HIGH_START 0.4`, `VALLEY_SIZE 0.05`, plus `isDeepDarkRegion(erosion, depth, context)` (thresholds `EROSION_DEEP_DARK_DRYNESS_THRESHOLD −0.225`, `DEPTH_DEEP_DARK_DRYNESS_THRESHOLD 0.9`) — usado por `Aquifer` para proibir floodedness no deep dark; citado também pela F3 debug. O preset do datapack consome `spawnTarget()`/thresholds para montar o `MultiNoiseBiomeSourceParameterList` (`NoiseData.bootstrap` — não lido por inteiro).

## Relação com Climate.Sampler e MultiNoiseBiomeSource [FATO]
- `Climate.RTree.search` — maior distância = melhor; `lastResult` ThreadLocal (cache de 1 resultado por thread — acelera chamadas sequenciais do fill).
- Distrito Nether: `NoiseRouterData.nether()` usa `temperature/vegetation` de `TEMPERATURE_NETHER`/`VEGETATION_NETHER` (com `LegacyRandomSource` + `createLegacyNetherBiome` quando `useLegacyRandomSource()`), demais dimensões zeradas — o preset do biome source do Nether não foi aberto nesta sessão (marcar como não verificado, não como confirmado).
- Biomes granularity = quart; não existem "biome borders" de 1 bloco (apenas multi-noise interpolado por quart).
