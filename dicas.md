# dicas.md — Dicas e convenções do laboratório

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
