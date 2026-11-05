# diário — Minecraft Reverse Engineering Lab

> Diário de anotações do laboratório. Todo agente de IA que trabalhar aqui DEVE ler este arquivo primeiro e DEVE registrar descobertas aqui.
> Idioma principal: português. Classe de confiança e fontes sempre explícitas.
> NÃO registrar código decompilado aqui — apenas conhecimento destilado e referências.

---

## 2026-11-04 — Dia 1: Reconhecimento do ambiente e pesquisa de ferramentas

### Ambiente físico (verificado)
- SO: Windows 11 Home Single Language 10.0.26200
- RAM: 7.84 GB (8 GB) — SEM GPU dedicada
- CPU: 1 física / 8 lógicas
- Disco livre: ~62 GB (C:)
- Python 3.12.10 instalado (`python` no PATH)
- VS Code 1.144.1, Zed instalado (na pasta LOCALAPPDATA\Programs\Zed)
- Java: NÃO instalado | Git: NÃO instalado | Node: NÃO instalado | winget: disponível
- Minecraft NÃO está instalado (`%APPDATA%\.minecraft` não existe)
- GitHub CLI (`gh`): não instalado
- Repositório de trabalho: `C:\Users\p4tol\OneDrive\Desktop\Projetos zed\Eng reverse` (estava vazio)

### Pesquisa de ferramentas (fontes consultadas em 2026-11-04)

**MinecraftSourcesGenerator** (https://github.com/Bram1903/MinecraftSourcesGenerator)
- Gera árvore de fontes decompiladas navegável para releases 1.7.2 → mais recente.
- Usa Vineflower por baixo, tiny-remapper/mapping-io, Parchment para params/javadocs em Mojmap.
- 26.1+: o jar já vem com nomes reais (sem mapeamentos).
- Requer JDK 17+ para o Gradle (ele baixa toolchain Java 25 sozinho). `-PmaxHeap=8g -Pjobs=1` basta para 1 versão numa máquina de 8 GB.
- ~290 s de CPU por versão moderna. `sources/`, `work/`, `diffs/` são git-ignored (nunca commitar — redistribuição proibida).
- Comando-chave (na pasta do clone): `.\gradlew generateVersion "-Pmc=26.1.2" -Peula=true`
- Também: `diffVersions` para comparar versões a nível de bytecode.

**mcsrc.dev** (https://mcsrc.dev/ — projeto FabricMC/mcsrc, https://github.com/FabricMC/mcsrc)
- Visualizador web de fontes decompiladas; decompila no navegador com Vineflower; nada é redistribuído.
- Recursos: comparação de versões, visualização de herança, find references, go to declaration, bytecode view, diff interface.
- Cobre 1.14.4+ (Mojmap) e 26.1+ (unobfuscado), além de versões antigas.
- Útil para consultas rápidas e validação cruzada, NÃO substitui a árvore local.

**Vineflower** (https://github.com/Vineflower/vineflower)
- Decompilador Java/JVM moderno (fork do Fernflower). Apache-2.0.
- Standalone: `java -jar vineflower.jar input output`. Requer Java 17+ (1.11+).
- NÃO deofusca: em versões ≤1.21.x produz nomes obfuscados se o jar não foi remapeado antes.

**Fabric / FabricMC** (https://github.com/FabricMC)
- Para ESTE projeto, Fabric não é necessário como loader; o que importa é o ecossistema de mapeamentos (tiny-remapper, mapping-io, Mojmap/Parchment) e o mcsrc.
- Licença dos mappings Mojang: decompilar para uso pessoal é permitido; NÃO redistribuir código decompilado.

**Ghidra** (https://github.com/NationalSecurityAgency/ghidra)
- Ferramenta de engenharia reversa de BINÁRIOS NATIVOS (NSA). NÃO é adequada ao bytecode Java.
- Decisão: NÃO instalar por ora (pesada para 8 GB RAM; nenhuma necessidade — Minecraft é 100% bytecode Java).

**Universal Modder** (https://github.com/rehan-remade/universal-modder)
- Plugin de IA (Claude/Codex/Cursor/OpenCode/Gemini) para MODDING de jogos, 9.4k stars, MIT.
- Contém: skills Agent-Skills-format, `um` CLI (Python), MCP fal (assets pagos), knowledge base de "field notes".
- Suporta OpenCode: clonar e rodar `opencode` dentro (opencode.json) OU `opencode plugin add 'github:rehan-remade/universal-modder#main::path:plugins/opencode'`.
- Tem uma skill `reverse-engineering` (Vineflower/Ghidra/ILSpy) e playbook de Minecraft — úteis como REFERÊNCIA.
- NÃO é um decompilador nem um analisador de arquitetura; é orquestrador de agente para criar mods.
- Decisão pendente de autorização do usuário (ver seção Pendências).

### Versões do Minecraft investigadas
- **26.1** ("Tiny Takeover", 24/mar/2026): primeira release unobfuscada da história do Java Edition; requer Java 25; protocolo 775; dataPack 101.1.
- **26.1.1 / 26.1.2**: hotfixes (abr/2026). 26.1.2 é a mais estável da linha 26.1.
- **26.2** ("Chaos Cubed", jun/2026), **26.3** ("Wilderness Bound", set/2026): releases posteriores; 26.4 ("Fourth Drop 2026") anunciada para Q4 2026.
- **1.21.1 / 1.21.11**: últimos da linha 1.x; OBFUSCADOS — exigem Mojmap (+Parchment) para nomes legíveis.
- Regra do MinecraftSourcesGenerator: 26.1+ = nomes reais Mojang (JAR não ofuscado); 1.14.4–1.21.x = Mojmap; ≤1.14.3 = Ornithe Feather.

### Decisão técnica: versão principal = **26.1.2**
Justificativa:
1. unobfuscada → nomes reais de classes, métodos, campos e variáveis locais (máxima legibilidade sem mapeamentos).
2. linha 26.1 é a MAIS documentada da era unobfuscada (wiki do Minecraft, steelmc.dev, mcsrc.dev, artigos de março/2026).
3. MinecraftSourcesGenerator e mcsrc.dev dão suporte completo.
4. Hotfix 26.1.2 corrige bugs críticos da 26.1 mantendo compatibilidade total.
5. 1.21.11/1.21.1 ficam como alvos de comparação histórica (diffVersions) apenas se o usuário quiser.
6. 26.3 fica como comparação futura (diffVersions 26.1.2→26.3), não como base.

### Pendências / aguardando usuário
- Autorização para instalar via winget: Git, Microsoft OpenJDK 25, GitHub CLI (gh).
- Confirmação da escolha 26.1.2 (usuário não respondeu à pergunta de versão).
- Integração do Universal Modder (usuário não respondeu; default proposto: clonar só como referência em tools/, sem fal MCP nem APIs pagas).
- Repositório GitHub "teste eng reverse mine": PÚBLICO (definido pelo usuário). gh login pendente.
- .minecraft NÃO instalado: análise comportamental ("rodar o jogo e observar") exige que o usuário possua/instale o jogo legitimamente; não faremos isso sem autorização. A decompilação local para estudo é permitida pela EULA da Mojang.

### Dicas para futuros agentes
- **NUNCA** commitar: `sources/`, `work/`, `diffs/`, `*.jar`, `eula.txt`, `.minecraft/`, assets, JARs originais. O .gitignore do projeto cobre isso — não contornar.
- **NUNCA** redistribuir código decompilado (GitHub público!). O repo contém APENAS: docs, knowledge/, scripts, experiments (código próprio), reports, diário.
- Decompile SEMPRE local com `-Peula=true` (EULA local por máquina, git-ignored).
- Sempre distinguir no texto: FATO (lido no código decompilado) / DOC EXTERNA (wiki, mcsrc.dev) / HIPÓTESE / NÃO DESCOBERTO.
- 8 GB RAM: usar `-PmaxHeap=4g -Pjobs=1 -PvfThreads=4` (ajustar). Não rodar generateAll.
- Java necessário: 25 (26.x exige). Se o usuário autorizar winget: `winget install Microsoft.OpenJDK.25`.
- No PowerShell, SEMPRE colocar entre aspas argumentos com versão: `"-Pmc=26.1.2"` (o ponto quebra o parser).
- OneDrive sincroniza esta pasta — arquivos grandes (sources/, work/) devem ficar FORA do repo ou em pasta ignorada com cuidado; melhor decompilar em `work/` dentro do projeto (git-ignored) mas ciente de que o OneDrive vai tentar sincronizar. Se possível, usar `C:\Users\p4tol\AppData\Local\Temp\opencode` ou pedir ao usuário uma pasta local não sincronizada.

---

## 2026-11-04 — Dia 1 (cont.): Decompilação 26.1.2 concluída + E1/E2

### Decompilação (MinecraftSourcesGenerator)
- Comando: `gradlew generateVersion "-Pmc=26.1.2" -Peula=true -Pjobs=1 -PmaxHeap=4g -PvfThreads=4`
- Resultado: **6882 classes / 6883 arquivos / 31.3 MB, 0 falhas, ~3.5 min wall** (decompile 148 s, prepare 42 s).
- Mapeamentos: `VANILLA` (unobfuscada — sem Mojmap/Parchment).
- Fontes: `tools/MinecraftSourcesGenerator/sources/26.1.2/` (git-ignored, OneDrive sincroniza — atenção).
- `.mcsg-done` gerado; cache em `work/decompile-cache/`.

### Instalações realizadas (autorizadas)
- Git 2.56.0.4 · Microsoft OpenJDK 25.0.5 LTS · GitHub CLI 2.103.3 (winget).
- TODO instalação pendente de confirmação: ripgrep (não instalado sem autorização — uso `Select-String` no PowerShell).

### E1 — Caminho de inicialização (CONFIRMADO no código)
- Cliente: `net.minecraft.client.main.Main#main` → `SharedConstants.tryDetectVersion()` → `DataFixers.optimize(...)` (async) → `net.minecraft.server.Bootstrap.bootStrap()` → `ClientBootstrap.bootstrap()` → `Bootstrap.validate()`.
- Servidor dedicado: `net.minecraft.server.Main#main` — MESMA sequência base (`tryDetectVersion` → parser jopt-simple, `--nogui`, `--initSettings`). [FATO parcial — confirmar bootStrap no corpo]
- `Bootstrap.bootStrap()` ordem: checagem de registries → `FireBlock`/`ComposterBlock` → sanidade `EntityType.PLAYER` → `EntitySelectorOptions`/`DispenseItemBehavior`/`CauldronInteractions` → `BuiltInRegistries.bootStrap()` (createContents → freeze → validate) → `CreativeModeTabs.validate()` → wrap stdout/stderr.
- `ClientBootstrap.bootstrap()`: apenas renderização/GUI (`ItemModels`, `SpecialModelRenderers`, `SpriteSources`, dialogs…). Nada de registries.
- Documento: `knowledge/initialization/startup-flow.md`

### E2 — Registro de um bloco (CONFIRMADO no código)
- `BuiltInRegistries` cria `DefaultedMappedRegistry<Block>` (default `"air"`, intrusive holders) com loader lazy `registry -> Blocks.AIR`.
- `bootStrap()` → `createContents()` força clinit de `Blocks`; `Blocks.register(...)` → `Registry.register(BuiltInRegistries.BLOCK, "minecraft:stone", STONE)`.
- Ao final do clinit de `Blocks`: `Block.BLOCK_STATE_REGISTRY` preenchido + `state.initCache()`.
- Depois: `freeze()` (raiz + filhos) → registries imutáveis.
- Documento: `knowledge/registries/block-registration.md`

### Infra verificada
- `Server Main` em `net/minecraft/server/Main.java` existe (estrutura análoga ao cliente).
- Pacotes top-level em `sources/26.1.2/net/minecraft`: advancements, client, commands, core, data, gametest, gizmos, locale, nbt, network, realms, recipebook, references, resources, server, sounds, stats, tags, util, world.

### Pendências imediatas
- **gh não autenticado** → criar repo público `teste eng reverse mine` exige `gh auth login` do usuário (ou token).
- Identidade git: padrão proposto = conta do gh (noreply).
- Push permanente solicitado pelo usuário: só após login + `scripts/pre-push-check.ps1` OK.

---

## 2026-11-04/05 — Sessão 2: Auditoria decompilação + E1/E2 completos

### Auditoria da decompilação 26.1.2 (aprovada)
- 6882 .java / 6883 arquivos / 31.3 MB / 539 dirs / 10682 classes contadas (inclui inner) / avg 4.7 KB por arquivo / ZERO arquivos vazios / ZERO resíduos `class_\d` (ofuscação) / nomes 100% reais.
- Classes-chave verificadas e legíveis: Minecraft, MinecraftServer, ServerLevel, LevelChunk, Entity, Player, ItemStack, BlockBehaviour, CompoundTag, SoundManager, Connection, BuiltInRegistries, LevelRenderer, GameRenderer, 17/17 presentes.
- Distribuição: world 2559, client 1813, util 713, server 418, network 411, data 165, commands 120, core 106.
- `.mcsg-done`: version=26.1.2 revision=3 tier=VANILLA decompiler=vineflower-1.12.0.
- Único não-.java: `.mcsg-done` (marcador).

### E1 — Inicialização (COMPLETO)
Ver `research/discoveries/E1-initialization.md` e `knowledge/architecture/initialization.md`.
- Cliente: client.main.Main → tryDetectVersion → DataFixers.optimize(async) → server.Bootstrap.bootStrap() → ClientBootstrap.bootstrap() → validate() → GameConfig → new Minecraft → run().
- Registries: loaders LAZY (`LOADERS.put(key, () -> loader.run(registry))`) disparam `<clinit>` das classes de conteúdo; `createContents()` roda cada loader 1×; `freeze()` torna tudo imutável.
- Server main existe em `net/minecraft/server/Main.java` (início lido; corpo completo pendente).

### E2 — Ciclo principal do jogo (COMPLETO)
Ver `research/discoveries/E2-game-loop.md` e `knowledge/architecture/game-loop.md`.
- Cliente: `Minecraft.run()` ("Render thread") → `runTick(advanceGameTime)` → `snapShot de DeltaTracker.Timer` (acumula ~50ms; retorna nº de ticks inteiros; máx 10/frame; partial tick p/ interpolação de render) → `renderFrame` (level.update → gameRenderer.update/extract/render → blitToScreen → flipFrame → frameLimiter<260) → `tick()` 20 TPS (gui → gameMode → screens → gameRenderer.tick → level.tickEntities/tickBlockEntities/`level.tick(() -> true)` → particles → `ServerboundClientTickEndPacket`).
- Servidor: `MinecraftServer.runServer` ("Server thread") → pacing `nanosecondsPerTick` (50ms; sprint /tick rate faz 0ns) → "Can't keep up!" ao atrasar >20 ticks → `processPacketsAndTick` → `tickServer` (auto-pause vazio; tickCount++; status; autosave) → `tickChildren` (functions → clocks → timeSync@20 → **ServerLevel.tick por nível** → tickConnection → playerList.tick → GameTestTicker → tickables → chunkSender) → `waitUntilNextTick`.
- `ServerLevel.tick` seções (340+): world border → weather → tickPending(block/fluid) → raid → chunkSource → blockEvents → entities(+dragonFight, checkDespawn) → blockEntities → entityManagement → debugSynchronizers → iceandsnow → tickBlocks → randomTick → thunder.
- TickRateManager (world/TickRateManager.java): tickrate=20, runsNormally, frozenTicksToRun (/tick step), /tick freeze|rate; isEntityFrozen excetua players.
- Singleplayer: IntegratedServer em thread própria ("Server thread"), cliente renderiza independente; ambos while(running).

### Decisões/estado
- Experimentos renumerados: E3 (auxiliar) = registro de bloco ✅ · novo E3/E4+ = ver experiments/README.md (E4 = chunks, recomendado próximo).
- Repo GitHub: NÃO publicar ainda (ordem do usuário 2026-11-04). gh ainda NÃO autenticado. NUNCA push nesta etapa.
- Commits locais: permitidos se conteúdo seguro (pre-push-check.ps1).

## 2026-11-05 — Sessão 3: E4 completo (chunks)

Investigação estática profunda do sistema de chunks. Documentos criados:
- `research/discoveries/E4-chunk-loading.md` (evidência completa + H1–H8 + refs)
- `knowledge/world/chunk-loading.md` (pipeline) · `chunk-status.md` · `chunk-tickets.md` · `chunk-storage.md` · `chunk-networking.md`
- Atualizados: INDEX.md, overview.md, dicas.md

Achados principais (todos [FATO] salvo nota):
1. Pipeline: ServerLevel.tick → ServerChunkCache.tick → purgeStaleTickets → runDistanceManagerUpdates (BFS min-fixed-point nos 3 trackers) → ChunkHolder/updatingChunkMap → ChunkGenerationTask (pirâmide EMPTY→FULL, camadas ±acumuladas) → ChunkTaskPriorityQueue (46 filas, menor nível = prioridade) → ConsecutiveExecutor worldgen/light → applyStep → tarefas (structure starts/refs r=8, biomes, noise w/ BelowZeroRetrogen, surface, carvers, features w/ blockStateWriteRadius=1, light) → FULL no mainThreadExecutor (ProtoChunk→LevelChunk).
2. Níveis: MAX_LEVEL=44, RADIUS_AROUND_FULL_CHUNK=11 (verificado computando acumulados do GENERATION_PYRAMID); FULL=33, BLOCK_TICKING=32, ENTITY_TICKING=31; byStatus: S_STARTS/EMPTY→44, BIOMES→36, NOISE..CARVERS→35, FEATURES/INIT_LIGHT→34, LIGHT/SPAWN/FULL→33; generationStatus(level)=getStatusAroundFullChunk(level−33).
3. Tickets são SavedData (`chunk_tickets`) — só persist() sobrevive restart; PLAYER_LOADING=31 (radius=viewDist via PlayerTicketTracker, dispatcher 4 permits), PLAYER_SIMULATION=max(0,31−simDist) (default 10 → 21). UNKNOWN (timeout 1 tick) provisório para qualquer getChunk.
4. `.mca` por região 32×32, setores 4 KB, cache 256, IOWorker com PriorityConsecutiveExecutor(FOREGROUND/BACKGROUND/SHUTDOWN) coalescendo pendingWrites; save eager ≤20/tick, ≤128 writes, throttle 10 s por chunk.
5. Descarga: toDrop → pendingUnloads → scheduleUnload (aguarda saveSyncFuture) → save+unload+light update.
6. Envio adaptativo client-driven: ClientboundChunkBatchStart/Finished + ClientboundLevelChunkWithLightPacket; ServerboundChunkBatchReceivedPacket; desired 9.0 inicial, clamp 0.01..64; 1→10 maxUnacknowledged após ACK; sendSync gate; 2 MB cap no payload.
7. Sintaxe real: sem "ChunkSerializer" separado — SerializableChunkData direto; sem ChunkTicket.java — Ticket dentro de Ticket.java.
8. H1–H8 registrados como pendentes (constantes mortas em ChunkMap: CHUNK_SAVED_PER_TICK=200/CHUNK_SAVED_EAGERLY_PER_TICK=20/EAGER_CHUNK_SAVE_COOLDOWN_IN_MILLIS=10000 sem usos no arquivo; nextChunkSaveTime usa +10000L inline; MAX_ACTIVE_CHUNK_WRITES=128 USADO).

Notas para agentes futuros:
- Em 26.1.2 NÃO existe ChunkSerializer/ChunkTicket como classes separadas — não perder tempo procurando; use SerializableChunkData e Ticket.
- `Select-String` > ripgrep (não instalado).
- Já sabemos o pipeline de ticks (E2): todo chunk passa por ServerLevel.tick → chunkSource.tick — ancore sempre ali.
- Para ServerLevel.tick: seções em ~340-560 (world border → weather → tickPending → ... → randomTick).

## Modelo de entrada para descobertas

```
## AAAA-MM-DD — <título>
- Sistema:
- Versão analisada:
- Classes envolvidas:
- Métodos relevantes:
- Dependências:
- Funcionamento observado (FATO):
- Fontes externas (DOC):
- Hipóteses:
- Confiança: alta | média | baixa
- Questões pendentes:
```
