# Mundo — Sistema de ruído (Noise system, 26.1.2)

**Confiança:** [FATO] · Evidência: `research/discoveries/E5-world-generation.md`

## Visão geral
3 tipos de ruído + marcadores de otimização, tudo dentro de `DensityFunction`:

```mermaid
flowchart TD
  A[NoiseRouter15 funções] --> B{Marker?}
  B -- Interpolated --> C[NoiseInterpolator: caches slice0/1 + trilhinear]
  B -- FlatCache --> D[FlatCache: 2D por coluna]
  B -- Cache2D --> E[Cache2D: 2D lazy]
  B -- CacheOnce --> F[CacheOnce]
  B -- CacheAllInCell --> G[CacheAllInCell: array + fillArray]
  C --> H[BlendedNoise: minLimit/maxLimit/main Perlin]
  D --> H
```

## BlendedNoise — a fórmula real do terreno [FATO]
- 3 PerlinNoise: `minLimit` octaves −15..0, `maxLimit` −15..0, `main` −7..0.
- `xzMultiplier = 684.412 * xzScale`, `yMultiplier = 684.412 * yScale`.
- `mainX = x*xzMultiplier/xzFactor`; `mainY = y*yMultiplier/yFactor`; `mainZ = z*xzMultiplier/xzFactor`; smear `yMultiplier*smearScaleMultiplier` (e `/yFactor` para main).
- 8 iterações na parte main e 16 na parte min/max, com `pow /= 2` em cada uma; `factor = (mainNoiseValue / 10.0 + 1.0) / 2.0` (valores `isMax/isMin` tratam os limites);
- blendMin/blendMax ponderados por `factor`; `maxValue = minLimitNoise.maxBrokenValue(yMultiplier)`.

(Obs.: a parte final de `compute()` — combinação blendMin/blendMax/main — não foi lida até o fim nesta sessão; a estrutura interna e os coeficientes foram verificados.)

## PerlinNoise / ImprovedNoise
`PerlinNoise.create(random, firstOctave, amplitudes)` — cascata de octaves com amplitudes (`DoubleList`), `PerlinNoise.wrap()` aplicada antes de cada amostra (módulo 16? — a wrapper evita acumulação de floats; não inspecionada linha a linha).
`NormalNoise.getValue(x,y,z)`: amostra `first.getValue(x,y,z) + second.getValue(x·1.0181268882175227, …)` × `valueFactor = 0.166666.../expectedDeviation(maxOctave−minOctave)`, `expectedDeviation(span) = 0.1×(1+1/(span+1))` — nos parâmetros (-3..6? depende do registro).

## NoiseChunk — cache/interpolador de célula [FATO — lida linha a linha]
- `cellWidth`, `cellHeight` (`NoiseSettings.getCellWidth = QuartPos.toBlock(sizeH)`; overworld = 4 e 8).
- `firstCellX/Z`; `noiseSizeXZ = QuartPos.fromBlock(cellCountXZ × cellWidth)`.
- `initializeForFirstCellX()` → `fillSlice(slice0, 0)`; `advanceCellX` → `swapSlices` + `fillSlice(next, x+1)`.
- `selectCellYZ(y,z)`: `fillingCell=true` → preenche `CacheAllInCell` arrays (`fillArray`) → corners 8 em `NoiseInterpolator.slice*`.
- `updateForY/X/Z(pos, factor)`: `lerp(factor, noise000, noise010)` (Y), `lerp(factorX, valueXZ00, valueXZ10)` (X), `lerp(factorZ, valueZ0, valueZ1)` (Z) → `value` = densidade final.
- `getInterpolatedState()` requer `interpolating==true` — interpolator fora do loop lança `IllegalStateException("Trying to sample interpolator outside the interpolation loop")` (comportamento detectável, não silencioso).
- `getInterpolatedDensity()` = `fullNoiseDensity.compute(this)` — usada por `getInterpolatedNoiseValue` (debug) e por `DensityFunction.SinglePointContext` (debug screen).

## NoiseRouter — as 15 funções [FATO]
barrieiras (`barrier`), `fluid_level_floodedness`, `fluid_level_spread`, `lava`, `temperature`, `vegetation`, `continents`, `erosion`, `depth`, `ridges`, `preliminary_surface_level`, `final_density`, `vein_toggle`, `vein_ridged`, `vein_gap`.

`mapAll` + `NoiseWiringHelper` no RandomState instancia cada `NoiseHolder` com a `NormalNoise` real registrada em `Registries.NOISE` (ou legado Nether), e rewia `BlendedNoise` com `terrainRandom`.

## Cascata de registro (onde os valores são definidos)
- `DensityFunctions` — codecs Dispatch (`"minecraft:interpolated"`, `"minecraft:cache_2d"`, `"minecraft:shift_a"`, etc.) — diretório do mod/loader do datapack.
- `Noises` — registro `Registries.NOISE` dos NormalNoise vanilla (`minecraft:classic_terrain_noise` etc.).
- `NoiseRouterData` — cadeia final vanilla dos DensityFunction (`overworldRouter`, `netherRouter`, `endRouter`, etc.) — **não lida ainda** (W1).
- Datapack `data/<ns>/worldgen/noise_settings/*.json` — sobrescreve/pre define.

## Fórmulas-chave (declaradas pelo código)
- `xzMultiplier = 684.412 × xzScale`, `yMultiplier = 684.412 × yScale`.
- `valueFactor(NormalNoise) = 1/6 / expectedDeviation(span)`; `expectedDeviation = 0.1 × (1 + 1/(span+1))`.
- `factor(blend) = (noise/10 + 1) / 2`.
- `QuartPos.toBlock(n) = n << 4`, `QuartPos.fromBlock(x) = x >> 4`.

## Limitações
- Cadeia vanilla exata (`final_density` squeezed etc.) não lida — não inventar os coeficientes de "continents→depth→ridges" aqui; qualquer documento futuro que cite a forma exata DEVE marcar fonte = data pack JSON (não este arquivo).
- `PerlinNoise.wrap` operação não dissecada.
