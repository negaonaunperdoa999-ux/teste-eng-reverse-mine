# Índice da base de conhecimento

> Consulte ANTES de investigar. Ao criar/renomear documento, atualize este índice e o `diario.md`.

## Arquitetura geral
- `architecture/overview.md` — mapa geral com Mermaid ✅ (E1+E2)
- `architecture/initialization.md` — boot cliente/servidor, registries ✅ (E1)
- `architecture/game-loop.md` — loop principal cliente/servidor, pacing, pausa, rede, render ✅ (E2)

## Por sistema
- `initialization/startup-flow.md` — resumo + ponteiros (ver architecture/initialization.md)
- `registries/block-registration.md` — registro de bloco/freeze ✅ (E3 auxiliar)
- `world/` — chunks, regiões, geração, biomas (NÃO INICIADO)
- `blocks/` — blocos, states, propriedades (PARCIAL: ver registries/block-registration.md)
- `items/` — itens, componentes, receitas, tags (NÃO INICIADO)
- `entities/` — entidades, IA, navegação (NÃO INICIADO)
- `physics/` — colisões, gravidade, tick (NÃO INICIADO)
- `rendering/` — pipeline de render (PARCIAL: só pontos do loop)
- `audio/` — motor de som (NÃO INICIADO)
- `networking/` — protocolo, pacotes, flush/suspend (PARCIAL: citas no game-loop)
- `persistence/` — saves, NBT (NÃO INICIADO)

## Pesquisa
- `../research/discoveries/E1-initialization.md` — init completa [FATO]
- `../research/discoveries/E2-game-loop.md` — loop principal [FATO]
- `../research/discoveries/` — futuras descobertas
- `../research/hypotheses/` — hipóteses não verificadas
- `../research/comparisons/` — comparações entre versões
- `../research/references/` — tool-comparison, decisions, external-docs

## Experimentos
- `../experiments/README.md` — E1 init ✅ · E2 game loop ✅ · E3 block registration ✅ (aux) · E4 chunks · E5 receitas · E6 texturas
