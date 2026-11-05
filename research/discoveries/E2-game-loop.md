# E2 — Ciclo principal do jogo (26.1.2)

- **Data:** 2026-11-04/05 · **Versão:** 26.1.2 (unobfuscada) · **Confiança:** alta [FATO]
- **Fontes:** `sources/26.1.2/net/minecraft/client/Minecraft.java`, `.../client/DeltaTracker.java`, `.../server/MinecraftServer.java`, `.../server/level/ServerLevel.java`, `.../world/TickRateManager.java`

## Dois loops independentes, unidos por rede
Cliente (Render thread) e servidor (Server thread) rodam `while (this.running)` separados. Em singleplayer, o cliente roda um `IntegratedServer` **no mesmo processo** (thread própria). Em multiplayer, servidor é outro processo/máquina.

## Cliente — `Minecraft.run()` [FATO, Minecraft.java ~892]
```
this.gameThread = Thread.currentThread()  // "Render thread" (já no Main)
if (processadores > 4) setPriority(10)
TracyClient.createDiscontinuousFrame("Client Tick")
while (this.running) {
  scope = Profiler.use(...)
  this.metricsRecorder.startTick(); tickFrame.start()
  this.window.resetIsResized()
  RenderSystem.pollEvents()              // eventos GLFW
  this.runTick(!oomRecovery)
  tickFrame.end(); this.metricsRecorder.endTick()
  // OutOfMemoryError → emergencySave() + OutOfMemoryScreen + System.gc()
}
```
Sem OOM recovery repetido: segundo OOM na mesma sessão → crash report.

### `runTick(advanceGameTime)` [FATO, ~1232]
1. `window.shouldClose()` → `stop()`
2. `pendingReload` pendente + sem overlay Loading → `reloadResourcePacks()`
3. `ticksToDo = advanceGameTime ? this.deltaTracker.advanceGameTime(Util.getMillis()) : 0`
4. Se advanceGameTime:
   - `packetProcessor.processQueuedPackets()` (rede, na thread do cliente)
   - `runAllTasks()` (tarefas agendadas)
   - `textureManager.tick()` se `isLevelRunningNormally()`
   - `for (i < min(10, ticksToDo)) this.tick()` — **máx. 10 ticks/frame; ticks atrasados são descartados**
   - drena `perTickGizmos` se nível rodando normalmente
5. Render (sempre, mesmo pausado):
   - `soundManager.updateSource(câmera)`, `toastManager.update()`, `mouseHandler.handleAccumulatedMovement()`
   - `renderFrame(advanceGameTime)`
6. Pós: cálculo de `pause` (singleplayer + pause screen + não publicado), `deltaTracker.updatePauseState/updateFrozenState`

### `renderFrame(advanceGameTime)` [FATO, ~1285]
`deltaTracker.advanceRealTime(now)` → opcional GPU TimerQuery → `pauseIfInactive()` → `window.updateFullscreenIfChanged()` → **se gameLoadFinished && level != null: `level.update()`** (interpola estado do ClientLevel entre ticks? — confirmar) → `gameRenderer.update(deltaTracker, …)` → `pick(partialTicks)` (picking bloco/entidade para mira) → `gameRenderer.extract(...)` (extrai game-state) → `RenderSystem.executePendingTasks()` → **`gameRenderer.render(...)`** → `mainRenderTarget.blitToScreen()` → `RenderSystem.flipFrame()` → `FramerateLimiter.limitDisplayFPS(framerateLimit)` (pulando se ≥ 260) → `frames++`

### `tick()` do cliente [FATO, ~1775] — 20 TPS
`clientTickCount++`; `tickRateManager().tick()` se nível não pausado; `textInputManager/chatListener/gui.tick`; `pick(1.0F)`; `gameMode.tick()`; telas/overlays (`screen.tick()`, crash → ReportedException); keybinds; `gameRenderer.tick()`; `level.tickEntities()`; `level.tickBlockEntities()`; `musicManager/soundManager.tick`; tutoriais; **`this.level.tick(() -> true)`** (ClientLevel — mundo do cliente: entidades, AI proxies?, chunks); `level.animateTick` (partículas do ambiente ao redor do jogador); `particleEngine.tick()`; `connection.send(ServerboundClientTickEndPacket)` (sync com servidor); `keyboardHandler.tick()`.

### Fixo-timestep: `DeltaTracker.Timer` [FATO, DeltaTracker.java]
- `msPerTick = 1000/ticksPerSecond` (20 → 50 ms)
- `advanceGameTime(now)`: `deltaTicks = (now-last)/targetMspt`, acumulador `deltaTickResidual`, retorna nº de ticks inteiros
- `getGameTimeDeltaPartialTick`: resto do acumulador (interpolação de render); se frozen → 1.0; se paused → residual salvo
- `getRealtimeDeltaTicks()`: clamp a 0.5 se > 7 (frame demora demais → UI não "teleporta")
- `updatePauseState`: congela/restaura residual

## Servidor — `MinecraftServer.runServer()` [FATO, MinecraftServer.java ~722]
```
initServer() → nextTickTimeNanos = now → status/icon
while (this.running) {
  if (sprinting && checkShouldSprintThisTick()) { thisTickNanos = 0; }       // tick-sprint (tickrate máxima do /tick rate)
  else { thisTickNanos = nanosecondsPerTick; checa OVERLOADED_THRESHOLD → warn "Can't keep up!" (ajusta nextTickTimeNanos) }
  nextTickTimeNanos += thisTickNanos
  Profiler.use(createProfiler()) {
    processPacketsAndTick(sprinting)   // packetProcessor + tickServer
    waitUntilNextTick()                // dorme até o próximo tick
  }
}
```
- `tickServer(haveTime)`: auto-pause se `pauseWhenEmptySeconds()` (sem players e vazio); `tickCount++`; `tickRateManager.tick()`; **`tickChildren(haveTime)`**; refresh de server status a cada N ns; autosave a cada `ticksUntilAutosave`; agregação de tick times (100 ticks) p/ MSPT suavizado.
- `tickChildren`: players.connection.suspendFlushing → functions.tick → clockManager.tick (se runsNormally) → timeSync a cada 20 ticks → **para cada ServerLevel: `level.tick(haveTime)`** → `tickConnection()` (flush de rede) → `playerList.tick()` → `debugSubscribers.tick()` → `GameTestTicker` (se runsNormally) → `tickables` → chunkSender por jogador.

### `ServerLevel.tick` (estrutura de seções, linha 340+) [FATO]
world border → weather → tickPending (`blockTicks`/`fluidTicks` via `TickingBlockEntity`/scheduled ticks) → raid → chunkSource (`tick(haveTime)` — carregador de chunks) → blockEvents → entities (`checkDespawn`, entity `tick()`, dragonFight) → blockEntities → entityManagement → debugSynchronizers → iceandsnow → `tickBlocks` (random block ticks / spread etc.) → `randomTick` → thunder.

## Papel comum — `world/TickRateManager` [FATO]
`tickrate=20`, `nanosecondsPerTick=50ms`; `setTickRate` aceita redução (comando `/tick rate`); `runsNormally()` controla se o mundo "anda"; `frozenTicksToRun` permite avançar N ticks com mundo congelado (`/tick step`); `isEntityFrozen` usa isso (entidades não-players param; players continuam).
Na prática: singleplayer e o 20 TPS são convenções do `TickRateManager`, não números mágicos no código.

## Relação cliente × servidor
- Cliente prediz/interpola; servidor é autoridade. Síntese parcial confirmada: cliente envia `ServerboundClientTickEndPacket`; mundo cliente roda `level.tick(() -> true)` (sem haveTime — nunca pausa simulação local), enquanto servidor usa `haveTime` e pode pausar (`runsNormally`).
- Fila de pacotes (`packetProcessor.processQueuedPackets()`) é drenada **no tick** nos dois lados, não no meio da renderização.
- Singleplayer: o `IntegratedServer` tem thread própria (`"Server thread"`); o cliente se comunica com ele via conexão loopback (internamente Packet flow), mas os dois `while (running)` continuam independentes.

## Diferenças-chave cliente × servidor
| Aspecto | Cliente | Servidor |
|---|---|---|
| Thread | "Render thread" (priority 10 se >4 cores) | "Server thread" |
| Tick | `runTick` → até 10× `tick()` por frame | 1 tick por iteração de `while` |
| Pace | `DeltaTracker.Timer` (acumula, descarta atraso >10) | `nanosecondsPerTick` fixo; dorme até o próximo tick; sprint à força se pedida |
| Atraso | engole até 10 ticks; ideal 20 TPS de fato | "Can't keep up!" + salta ticks perdidos |
| Mundo | `ClientLevel.tick(() -> true)` | `ServerLevel.tick(haveTime)` |
| Pacotes | `packetProcessor` no runTick | `packetProcessor` no processPacketsAndTick |
| Pausa real | singleplayer + pause screen | vazio (auto-pause), `/tick freeze` |

## Incertezas / pendências
- `level.update()` (cliente, em renderFrame): não lido; suspeita — atualização de caches por frame (ex.: `SectionOcclusionGraph`/frustum) — confirmar.
- `level.tick(() -> true)` vs `haveTime` no ClientLevel: verificar assinatura (recebe BooleanSupplier constante true — mundo cliente sempre "tem tempo").
- `gameRenderer.extract/update/render` trifásicos (render-state extraction): não aprofundados — deixar para E-rederização.
- `ServerLevel.tick` — cada seção merece sub-investigação (weather, scheduled ticks, randomTick) em experimento próprio.
- `ClientPacketListener` / batching de flush (`suspendFlushing`) — relação com rede, deixar p/ networking.

## Arquivos lidos nesta investigação
`client/Minecraft.java` (linhas ~266, 892-910, 1232-1360, 1775-1910), `client/DeltaTracker.java`, `server/MinecraftServer.java` (linhas ~194, 722-780, 950-1050, 1090-1150), `server/level/ServerLevel.java` (linhas 340-560), `world/TickRateManager.java`.
