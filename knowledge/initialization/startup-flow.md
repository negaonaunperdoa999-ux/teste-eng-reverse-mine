# Inicialização do jogo (26.1.2)

> Documento canônico detalhado foi movido para `knowledge/architecture/initialization.md`.
> Discovery completa: `research/discoveries/E1-initialization.md`.

Resumo: `client.main.Main` / `server.Main` → `SharedConstants.tryDetectVersion()` → `net.minecraft.server.Bootstrap.bootStrap()` (registries lazy loaders → freeze) → (cliente: `ClientBootstrap`) → construção do `Minecraft`/`MinecraftServer` → loop principal (`knowledge/architecture/game-loop.md`).
