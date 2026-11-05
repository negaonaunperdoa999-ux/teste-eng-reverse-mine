# Arquitetura — Inicialização (26.1.2)

**Versão:** 26.1.2 · **Confiança:** alta [FATO] · **Descoberta:** `research/discoveries/E1-initialization.md`

## Resumo
O jogo inicia por um entrypoint por lado (`client.main.Main` / `server.Main`), ambos chamando `SharedConstants.tryDetectVersion()` → `net.minecraft.server.Bootstrap.bootStrap()` (que POPULA e CONGELA os registries). O cliente adiciona `ClientBootstrap.bootstrap()` (render/GUI) e depois constrói `Minecraft` (janela GLFW/Blaze3D, reload listeners) e entra no loop `run()`.

## Componentes e papéis

| Componente | Papel | Lado |
|---|---|---|
| `SharedConstants` | metadados de versão; flags de debug (`MC_DEBUG_*`); `tryDetectVersion()` | ambos |
| `net.minecraft.server.Bootstrap` | popula conteúdos (FireBlock, Composter, EntitySelectorOptions, DispenseItemBehavior, CauldronInteractions, registries via loaders), congela registries, valida atributos default, captura timings (`bootstrapDuration`) | ambos |
| `net.minecraft.client.ClientBootstrap` | bootstrap lado-cliente: modelos de item, special renderers, tints, SpriteSources, dialogs | cliente |
| `BuiltInRegistries` | holder estático dos registries; loaders lazy; `createContents/freeze/validate` | ambos |
| `Minecraft` | instância cliente: Blaze3D/GLFW, ResourceManager + reload listeners, `run()` | cliente |
| `MinecraftServer`/`DedicatedServer` | instância servidor: níveis, players, conexões, tick | servidor |

## Ordem (cliente)
ver `initialization.md` → seção "Fluxo completo" em `research/discoveries/E1-initialization.md` (Mermaid incluso).

## Relações entre sistemas
- **Boot/registries** → tudo que usa registries (blocos, itens, entidades, receitas) só pode inicializar DEPOIS de `Bootstrap.bootStrap()`. O guard `Bootstrap.checkBootstrapCalled()` torna isso explícito.
- **DataFixers.optimize** ocorre em paralelo/assíncrono antes do join — otimizador de conversão de dados (schemas NBT).
- **Reload listeners** ordenados no construtor de `Minecraft` definem a ordem de carregamento de resource packs e são pré-requisito do pipeline de renderização/áudio/fontes.

## Limites conhecidos
- Construtor de `Minecraft` não foi lido linha a linha (121 KB); ordem dos reload listeners está documentada, a cadeia Blaze3D interna não.
- Servidor: entrypoint confirmado; corpo completo de `server/Main.java` não lido nesta missão.
- `bootstrapDuration` só mede `Bootstrap.bootStrap()`.

## Referências internas
- `knowledge/registries/block-registration.md` (registro/freeze)
- `knowledge/architecture/game-loop.md` (pós-init: loop principal)
