# Assets

Origem de cada arquivo de arte do jogo. Alimenta a ficha do jogo.

Toda geração usou o gerador de IA (ambiente QA, projeto `asset-gen`) com o preset de estilo `cinzel-pixel` (papéis `backgrounds`, `characters`, `gameplayTiles`, `gameplayProps`, `uiElements`; referências: as duas artes-chave escolhidas). Os originais baixados ficam em `art-src/gen/` e `art-src/keyart/`.

Os scripts em `art-src/` transformam esses originais nas folhas do jogo. Rode com `python3 -I` de um Python que tenha o Pillow, por exemplo um venv: `python3 -m venv /tmp/cinzel-venv && /tmp/cinzel-venv/bin/pip install pillow`, depois `/tmp/cinzel-venv/bin/python -I art-src/<script>.py .`.

- `build_climber.py` (com `strips.py`): escalador em camadas, quadros de 32x32.
- `build_enemies.py`: inimigos (24x24) e chefe final (48x48).
- `build_boss.py`: só o chefe final, mesma receita.
- `fetch_gen.py`: baixa os originais PNG do gerador de IA para `art-src/gen/r2/`.
- `preview.py`: prévias ampliadas 4x e um GIF por animação (escalador, inimigos, chefe).
- `build_tiles.py`: tilesets.
- `build_town.py`: cidade (chão pintado de 480x270 e os sprites grandes com sombra). `town_ground_guide.py` desenha o mapa de cores que guiou a geração do chão.
- `build_ui.py`: ícones dos itens, NPCs da cidade, molduras e ícones da UI, fundo do título. `preview_ui.py` monta uma folha ampliada para revisar.
- `build_hud.py`: kit do HUD e dos painéis (molduras 9-slice, botões com estados, coração e moeda animados, ampulheta, anel, barras).
- `check_art.py`: confere tamanho, transparência, no máximo 32 cores, quadros sem uso vazios, pixels soltos nas camadas do escalador e a linha do chão (escalador e NPCs 30, inimigos 22, chefe 44).

Nenhum desses scripts sobrescreve um arquivo que já existe, porque ele pode ter sido redesenhado à mão. Para gerar de novo por cima, passe `--force`. `make_placeholders.py` segue a mesma regra.

## Arquivos do jogo

| Arquivo | Autoria | Origem | Data |
|---|---|---|---|
| `game/assets/characters/climber/body.png` | Gerado por IA (gpt-image-2.5 flare edit) + ajuste por script | Tiras `art-src/gen/r2/climber32-*` (abaixo) por `build_climber.py`, grade 8x13 de 32x32: pele e botas (as luvas de couro ficam em `outfit`) | 2026-11-14 |
| `game/assets/characters/climber/hair.png` | Idem | Idem: capuz e cabelo | 2026-11-14 |
| `game/assets/characters/climber/outfit.png` | Idem | Idem: jaqueta, luvas, cachecol, calça e mochila | 2026-11-14 |
| `game/assets/characters/climber/weapon.png` | Idem | Idem: espada e arco do golpe | 2026-11-14 |
| `art-src/climber-reference.png` | Idem | Composição das 4 camadas, guia para redesenhar à mão | 2026-11-14 |
| `game/assets/enemies/crawler.png` | Gerado por IA (gpt-image-2.5 flare edit) + ajuste por script | `art-src/gen/r2/enemy24-crawler-anim-1.png` por `build_enemies.py`, grade 6x4 de 24x24 (parado, andar, ataque, morte; 6 quadros cada) | 2026-11-14 |
| `game/assets/enemies/shooter.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`) + ajuste por script | Sentinela de pedra flutuante com um olho vermelho, `art-src/gen/r2/enemy24-shooter-sheet-1.png` por `build_enemies.py` (substitui o conjurador encapuzado, que lembrava o herói) | 2026-11-14 |
| `game/assets/enemies/charger.png` | Gerado por IA (gpt-image-2.5 flare edit) + ajuste por script | `art-src/gen/r2/enemy24-charger-anim-1.png` por `build_enemies.py`, de lado olhando para a direita | 2026-11-14 |
| `game/assets/enemies/boss_final.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`) + ajuste por script | `art-src/gen/r2/boss48-final-sheet-2.png` por `build_boss.py`, grade 6x4 de 48x48; verdes do capuz esfriados para cinza-violeta. Os chefes dos andares 1 e 2 reaproveitam `crawler.png` e `charger.png` em escala x2 | 2026-11-14 |
| `game/assets/tiles/floor1.png` | Idem | `art-src/gen/tiles-floor1-sheet.png` e `art-src/gen/tiles-props-sheet.png` por `build_tiles.py` | 2026-11-14 |
| `game/assets/tiles/floor2.png` | Idem | `floor1` com a pedra em azul frio | 2026-11-14 |
| `game/assets/tiles/floor3.png` | Idem | `floor1` com a pedra em vermelho escuro de brasa | 2026-11-14 |
| `game/assets/items/<id>.png` (8 ícones 16x16) | Gerado por IA (nano-banana-2 edit) + ajuste por script | `cinzel-item-icons-sheet` por `build_ui.py` | 2026-11-14 |
| `game/assets/characters/npc_shopkeeper.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Lojista de `cinzel-npcs-sheet` por `build_ui.py`, 2 quadros de 32x32 (pés na linha 30, contorno escuro); 2º quadro do idle = tronco 1 px abaixo | 2026-11-14 |
| `game/assets/characters/npc_blacksmith.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Ferreiro de `cinzel-npcs-sheet` por `build_ui.py`, mesmo formato | 2026-11-14 |
| `game/assets/ui/panel.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moldura de `cinzel-ui-kit-sheet` por `build_ui.py` (9-slice, margem 4) | 2026-11-14 |
| `game/assets/ui/slot.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Espaço de item de `cinzel-ui-kit-sheet` (9-slice, margem 3) | 2026-11-14 |
| `game/assets/ui/heart.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Coração de `cinzel-ui-kit-sheet` | 2026-11-14 |
| `game/assets/ui/coin.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moeda de `cinzel-ui-kit-sheet`, recolorida para dourado (saiu salmão) | 2026-11-14 |
| `game/assets/ui/title_bg.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | `cinzel-title-bg` reduzido para 480x270, 32 cores | 2026-11-14 |
| `game/assets/ui/hud/hp_frame.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moldura da barra de vida de `cinzel-hud-frames-sheet` por `build_hud.py`: metade esquerda reduzida e espelhada, 48x12, 9-slice 9/3/9/3 (o meio é uma coluna repetida, estica sem dobrar pixel) | 2026-11-14 |
| `game/assets/ui/hud/boss_frame.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moldura com chifres da barra do chefe de `cinzel-hud-frames-sheet`, mesma receita, 64x16, 9-slice 14/5/14/3 (a placa de nome é `plaque.png`) | 2026-11-14 |
| `game/assets/ui/hud/slot.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Espaço de item de `cinzel-hud-frames-sheet-b`, 22x22, simetrizado | 2026-11-14 |
| `game/assets/ui/hud/plaque.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Placa de ferro de `cinzel-hud-frames-sheet-b`, 9-slice margem 4: bloco do relógio, nome do chefe, títulos dos painéis | 2026-11-14 |
| `game/assets/ui/hud/button.png, button_hot.png, button_down.png, button_off.png, button_focus.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Botão de `cinzel-hud-frames-sheet-b`, 9-slice margem 6; estados ativo (bronze clareado + brilho âmbar de 1 px), pressionado, desligado e o anel de foco (só o brilho, por cima de qualquer estado) feitos por script; meios uniformes no 9-slice | 2026-11-14 |
| `game/assets/ui/hud/panel.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moldura de janela de `cinzel-hud-frames-sheet-b`, 72x70, 9-slice margem 18 com meios uniformes, miolo escurecido para o texto ler | 2026-11-14 |
| `game/assets/ui/hud/heart.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Coração de `cinzel-hud-icons-sheet`, 4 quadros de 13x12 (repouso, cresce, pico, volta) por redução em tamanhos diferentes | 2026-11-14 |
| `game/assets/ui/hud/coin.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moeda de `cinzel-hud-icons-sheet`, 6 quadros de 9x9 (giro por achatamento; o verso é a face espelhada e mais escura; aro de 2 px) | 2026-11-14 |
| `game/assets/ui/hud/hourglass.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Ampulheta de `cinzel-hud-icons-sheet`, 6x9 | 2026-11-14 |
| `game/assets/ui/hud/ring.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Anel de luz de `cinzel-hud-icons-sheet`, 24x24, 8 cores | 2026-11-14 |
| `game/assets/ui/hud/fill_hp.png`, `fill_boss.png`, `fill_exit.png`, `fill_tip.png` | Autoral (script) | Rampas de 4 tons das barras e o pulso de luz da ponta, desenhados por `build_hud.py` | 2026-11-14 |
| `game/assets/town/ground.png` (480x270) | Gerado por IA (gpt-image-2.5 flare edit) + ajuste por script | `art-src/gen/town-ground.png` (pintado sobre `town-ground-guide.png` com a arte-chave da cidade como referência) por `build_town.py`: reduzido para 480x270, 32 cores | 2026-11-14 |
| `game/assets/town/shop.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`) + ajuste por script | `art-src/gen/town-shop.png` por `build_town.py`: recorte, 104 px de largura, até 29 cores, contorno de 1 px e sombra suave embutida | 2026-11-14 |
| `game/assets/town/forge.png` | Idem | `art-src/gen/town-forge.png`, mesma receita; a cena espelha o sprite | 2026-11-14 |
| `game/assets/town/house_a.png` | Idem | `art-src/gen/town-houses.png`, 80 px de altura | 2026-11-14 |
| `game/assets/town/house_b.png`, `house_c.png` | Gerado por IA (gpt-image-2.5 flare edit) + ajuste por script | `art-src/gen/town-houses-b.png` (casa de pedra e casa enxaimel) | 2026-11-14 |
| `game/assets/town/crystal.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`) + ajuste por script | `art-src/gen/town-crystal.png`, 60 px de altura | 2026-11-14 |
| `game/assets/town/tree_a.png`, `tree_b.png`, `tree_c.png`, `lamp.png`, `well.png`, `planter.png`, `flowerbed.png`, `fence.png`, `fence_post.png`, `barrel.png`, `crates.png`, `sack.png` | Idem | `art-src/gen/town-props.png`, um recorte por objeto (caixas em `build_town.py`); o halo rosa do lampião vira luz âmbar | 2026-11-14 |
| `game/assets/town/crystal_glow.png` | Feito por script | Brilho azul radial em 4 faixas, desenhado em `build_town.py` | 2026-11-14 |
| `game/assets/fonts/Silkscreen-Regular.ttf` | Terceiros: fonte Silkscreen, licença SIL OFL 1.1 | Fonte Silkscreen (Jason Kottke), SIL OFL 1.1, de google/fonts; licença em `Silkscreen-OFL.txt` | 2026-11-14 |

Quando o Daniel redesenhar um arquivo à mão, troque a autoria dessa linha para "Autoral (Daniel)".

## Gerações no gerador de IA

O nome no gerador de IA leva um hash de conteúdo. O arquivo no repositório é o original PNG baixado.

| Arquivo no repo | Asset no gerador de IA | Modelo | Prompt (resumo) | Data |
|---|---|---|---|---|
| `art-src/keyart/keyart-tower-1-f637e9b7acec.png` | `cinzel-keyart-tower-1-6b2e37361861` | gpt-image-2.5 sunburst | Sala da torre, pixel art vista de cima (escolhida pelo Daniel) | 2026-11-14 |
| `art-src/keyart/keyart-town-1-bd276bf242c4.png` | `cinzel-keyart-town-1-3796c73abe79` | gpt-image-2.5 sunburst | Rua da cidade, pixel art vista de cima (escolhida pelo Daniel) | 2026-11-14 |
| `art-src/keyart/climber-turnaround-1.png` | `cinzel-climber-turnaround-1-a9700b2c85f6` | template `styled-sprite-sheet`, papel `characters` | Escalador em pose neutra: frente, costas, lado (aprovado pelo Daniel) | 2026-11-14 |
| `art-src/gen/climber-walk-sheet.png` | `cinzel-climber-walk-sheet-20a83c957340` | `openai/gpt-image-2.5/flare/edit`, referência = turnaround | "Using this exact character (...) draw a pixel-art animation sprite sheet on a flat magenta #FF00FF background (...) row 1 walk cycle facing the viewer, row 2 from behind, row 3 facing right". Não é mais usado: a 24 px as pernas quase não mexiam | 2026-11-14 |
| `art-src/gen/climber-attack-sheet.png` | `cinzel-climber-attack-sheet-ed17687bcaf3` | idem | Mesmo pedido, ataque com espada em 3 linhas x 3 quadros: preparo, golpe com arco, acompanhamento. Não é mais usado desde as tiras de 32 px | 2026-11-14 |
| `art-src/gen/climber-roll-death-sheet.png` | `cinzel-climber-roll-death-sheet-a999fe192f26` | idem | Rolamento para frente, para trás e para o lado (4 quadros) e morte de frente (4 quadros). Não é mais usado desde as tiras de 32 px | 2026-11-14 |
| `art-src/gen/enemies-sheet.png` | `cinzel-enemies-sheet-e3b89b5f3c48` | `style/gpt-image-2.5/flare`, preset `cinzel-pixel`, papel `characters` | Três inimigos; o preset devolveu só o conjurador encapuzado com cajado de orbe vermelho (foi o atirador até o R2; trocado porque lembrava o herói) | 2026-11-14 |
| `art-src/gen/enemy-crawler.png` | `cinzel-enemy-crawler-4688abb49eb4` | idem | Gosma vermelho-escura em cúpula, dois olhos vermelhos brilhando, brilho claro no topo | 2026-11-14 |
| `art-src/gen/enemy-charger.png` | `cinzel-enemy-charger-fc1d186596d2` | idem | Besouro-javali de placas cinza-marrom. Descartado: virava ruído em 16 px | 2026-11-14 |
| `art-src/gen/enemy-charger-v2.png` | `cinzel-enemy-charger-v2-958fd2b4b941` | idem | Besouro-javali com casco liso azul-aço, faixa vermelha, chifres de osso, olhos vermelhos, silhueta simples | 2026-11-14 |
| `art-src/gen/tiles-floor1-sheet.png` | `cinzel-tiles-floor1-sheet-a22089b881f0` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayTiles` | Folha 4x4 de tiles da torre: lajes (lisa, clara, rachada, com musgo), parede, topo de parede, pilar, caixote, portas (trancada, aberta, fechada), baús, parede com tocha | 2026-11-14 |
| `art-src/gen/tiles-props-sheet.png` | `cinzel-tiles-props-sheet-6f9f6685ebad` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayProps` | Pilar, caixote, baú fechado, baú aberto com ouro, tocha de parede, sobre magenta | 2026-11-14 |
| `art-src/gen/tiles-town-sheet.png` | `cinzel-tiles-town-sheet-07b9e1466613` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayTiles` | Folha 4x4 da cidade: calçamento, grama, madeira, terra, telhado, muro, toldo listrado, casa enxaimel, porta, janela, estandarte, topo de muro, água. Não é mais usado: desde a Task P3 a cidade usa `game/assets/town/` e `town.png` saiu | 2026-11-14 |
| `art-src/gen/boss-final.png` | `cinzel-boss-final-15618594aab4` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `characters` | Chefe final: cavaleiro-espectro encapuzado de armadura negra rachada, olhos e fenda no peito em brasa vermelha, lâmina incandescente, sobre magenta. Não é mais usado: o chefe de 48 px vem de `boss48-final-sheet-2` | 2026-11-14 |
| `art-src/gen/town-shop.png` | `cinzel-town-shop-2d8e249685e5` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayProps` | Loja do herói vista de cima 3/4: enxaimel, toldo listrado vermelho e creme, balcão com prateleiras de poções, duas mesas de exposição com pano verde, placa de poção, barril, caixote, lanterna, sobre magenta | 2026-11-14 |
| `art-src/gen/town-forge.png` | `cinzel-town-forge-ef8d59b688fe` | idem | Forja: pedra e madeira escura, chaminé alta de pedra, frente aberta com fornalha acesa, bigorna no toco, suporte de espadas e machados, barril de têmpera, placa de bigorna, lanterna, sobre magenta | 2026-11-14 |
| `art-src/gen/town-houses.png` | `cinzel-town-houses-1182b3bf7188` | idem | Pedido de três casas; veio uma (enxaimel estreita com hera, floreira e estandarte azul) | 2026-11-14 |
| `art-src/gen/town-houses-b.png` | `cinzel-town-houses-b-0c23dc8e0a89` | `openai/gpt-image-2.5/flare/edit`, referência = `town-houses` | Mesmo estilo e escala: casa de pedra com telhado vermelho e estandarte; casa enxaimel com telhado marrom, janela redonda, banco e vaso | 2026-11-14 |
| `art-src/gen/town-crystal.png` | `cinzel-town-crystal-ad465add88c7` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayProps` | Cristal azul de teleporte sobre pedestal redondo de pedra com dois pilares e estandartes | 2026-11-14 |
| `art-src/gen/town-props.png` | `cinzel-town-props-316a781f76ff` | idem, 2K | Folha de objetos em 3 linhas: três árvores (carvalho, árvore clara, outono), lampião, poço, floreira, canteiro redondo, cerca, poste, barril, caixotes, saco | 2026-11-14 |
| `art-src/gen/town-ground-guide.png` | `town-ground-guide-9e3f26c9fe7f` (upload) | `town_ground_guide.py` | Mapa de cores do chão: cinza = calçamento, anel claro = anel de pedra do cristal, marrom = terra, verde = grama | 2026-11-14 |
| `art-src/gen/town-ground.png` | `cinzel-town-ground-e1d822381cad` | `openai/gpt-image-2.5/flare/edit`, referências = guia + arte-chave da cidade | "Repaint it as the GROUND ONLY of a top-down pixel art town square, keeping every region where it is": calçamento, anel de lajes, caminho de terra, grama com flores, meio-fio de pedra, sem prédios | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-item-icons-sheet-6a10443e5bc9` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `gameplayProps`, 2K | Grade 4x2 dos 8 itens sobre magenta, cada um com brilho amarelo (veio um mini escalador perdido no meio, apagado no script) | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-npcs-sheet-73ad112ab455` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `characters`, 2K | Lojista (avental verde, boné, bolsa de moedas) e ferreiro (careca, barba, avental de couro, martelo), 2 quadros de idle cada, sobre magenta | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-ui-kit-sheet-7be22ce3bc8a` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `uiElements`, 2K | Moldura de painel bronze, espaço de item, coração, moeda, relógio, sobre magenta | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-title-bg-69c9e042aad3` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `backgrounds`, 1K, 16:9 | Torre de pedra com brasas sobre a cidade de telhados vermelhos ao anoitecer, céu livre para o título | 2026-11-14 |
| `art-src/gen/hud-frames-sheet.png` | `cinzel-hud-frames-sheet-218b52ab9951` | `fal-ai/nano-banana-2/edit` (via `generate_styled_image`), preset `cinzel-pixel`, papel `uiElements`, 2K, 16:9 | Kit de HUD sobre magenta: barra de vida de ferro com cantos de bronze, barra do chefe com pontas de chifre e placa no meio, espaço de item, placa, botão, janela. Só as duas barras saíram limpas: o resto veio misturado com a arte de referência da cidade | 2026-11-14 |
| `art-src/gen/hud-frames-sheet-b.png` | `cinzel-hud-frames-sheet-b-0c785c1847fa` | idem, 2K, 1:1 | Espaço de item de ferro rebitado com cantos de bronze, placa de ferro com friso de bronze, botão marrom com borda de bronze chanfrada, janela de bronze e ferro com cantos ornamentados, sobre magenta | 2026-11-14 |
| `art-src/gen/hud-icons-sheet.png` | `cinzel-hud-icons-sheet-da5da5001b42` | idem, 1K, 4:1 | Coração vermelho, moeda dourada com torre em relevo, ampulheta de bronze com areia âmbar, anel de luz âmbar, sobre magenta | 2026-11-14 |

### Arte em alta (R2): escalador 32 px, inimigos 24 px, chefe 48 px

Escalador: `openai/gpt-image-2.5/flare/edit` com a referência aprovada `cinzel-climber-turnaround-1-a9700b2c85f6`, papel `characters`, 2 variações por pedido, uma escolhida. Prompt base: "Using this exact character (green-olive hood, brown leather jacket, olive scarf, khaki trousers, brown boots, backpack, short steel sword in right hand), draw a pixel-art animation strip on a flat solid magenta #FF00FF background: ONE horizontal row of exactly N frames, evenly spaced, same size and same scale, all feet on the same ground line (...) Crisp pixel art with 1px dark outline, no anti-aliasing, no shadows, no text, no ground, frames do not overlap", mais a descrição pose a pose abaixo. Os arquivos no repo são os originais PNG baixados por `fetch_gen.py`.

| Arquivo no repo (`art-src/gen/r2/`) | Asset no gerador de IA | Modelo | Prompt (resumo) | Data |
|---|---|---|---|---|
| `climber32-idle-down-up-1.png` | `cinzel-climber32-idle-down-up-1-15ba46aba99a` | flare edit + turnaround | 8 poses: respiração parada de frente (4) e de costas (4) | 2026-11-14 |
| `climber32-idle-side-1.png` | `cinzel-climber32-idle-side-1-bafa402658eb` | idem | 4 poses: respiração parada de lado, olhando para a direita | 2026-11-14 |
| `climber32-walk-down-2.png` | `cinzel-climber32-walk-down-2-4d3b58e62a89` | idem | Andar de frente em 8 quadros: contato, descida, passagem, subida, espelhado | 2026-11-14 |
| `climber32-walk-up-1.png` | `cinzel-climber32-walk-up-1-5503be6e0e6e` | idem | Andar de costas em 8 quadros | 2026-11-14 |
| `climber32-walk-side-1.png` | `cinzel-climber32-walk-side-1-964ec4291b44` | idem | Andar de lado em 8 quadros, braços contra as pernas | 2026-11-14 |
| `climber32-attack-down-1.png` | `cinzel-climber32-attack-down-1-77aad2d75c77` | idem | Golpe para baixo em 6: preparo, espada no alto, golpe com arco creme, arco cheio, acompanhamento, volta | 2026-11-14 |
| `climber32-attack-up-2.png` | `cinzel-climber32-attack-up-2-ef2dc65224d4` | idem | Golpe por cima, de costas, em 6, arco acima do capuz | 2026-11-14 |
| `climber32-attack-side-1.png` | `cinzel-climber32-attack-side-1-fe2c668618b2` | idem | Golpe horizontal de lado em 6, avanço com arco à frente | 2026-11-14 |
| `climber32-roll-down-1.png` | `cinzel-climber32-roll-down-1-f0092ad29aa5` | idem | Rolamento para a câmera em 6: agacha, mergulha, bola, bola girando, aterrissa, levanta | 2026-11-14 |
| `climber32-roll-up-1.png` | `cinzel-climber32-roll-up-1-c1335812c52f` | idem | Rolamento de costas em 6 | 2026-11-14 |
| `climber32-roll-side-1.png` | `cinzel-climber32-roll-side-1-ef46be8295c5` | idem | Rolamento de lado em 6 | 2026-11-14 |
| `climber32-death-1.png` | `cinzel-climber32-death-1-4cbeb0c33d7a` | idem | Morte de frente em 6: recuo, cambaleia, joelhos, cai de mãos, deitado, parado | 2026-11-14 |
| `enemy24-crawler-anim-1.png` | `cinzel-enemy24-crawler-anim-1-93f85dfb78fc` | flare edit, referência = `cinzel-enemy-crawler-4688abb49eb4` | Grade 6x4 da gosma: balanço, pulos com achatamento, bote com boca aberta, derrete em poça | 2026-11-14 |
| `enemy24-shooter-sheet-1.png` | `cinzel-enemy24-shooter-sheet-1-c1a019f6cee7` | `style/gpt-image-2.5/flare`, preset `cinzel-pixel`, papel `characters`, 2K | Grade 6x4 da sentinela de pedra flutuante: casca de ardósia azul-cinza, um olho vermelho, três lascas orbitando; flutua, avança inclinada, olho carrega e dispara, racha e desmorona. Veio um mini escalador no canto, apagado no script | 2026-11-14 |
| `enemy24-charger-anim-1.png` | `cinzel-enemy24-charger-anim-1-792e520875ff` | flare edit, referência = `cinzel-enemy-charger-v2-958fd2b4b941` | Grade 6x4 do besouro-javali de lado: respira, trote com pernas alternando, empina e investe, tomba de costas | 2026-11-14 |
| `boss48-final-sheet-2.png` | `cinzel-boss48-final-sheet-2-778794c65944` | `style/gpt-image-2.5/flare`, preset `cinzel-pixel`, papel `characters`, 2K | Grade 6x4 do cavaleiro-espectro: armadura negra rachada, capa cinza-violeta, olhos em brasa pequenos, pouco vermelho; respira, desliza, golpe pesado com arco, vira cinza e sobra a capa | 2026-11-14 |

Pedidos do inimigo comum com o preset `cinzel-pixel` e papel `characters` (`cinzel-enemy24-crawler-sheet-*`, `cinzel-enemy24-charger-sheet-*`) vieram como cópias do escalador, porque o papel puxa a referência do herói. Por isso a gosma e o besouro saíram de `edit_image` sobre a arte antiga deles.


## Layout dos tilesets

Os tilesets da torre têm 8 colunas x 2 linhas de tiles 16x16. As coordenadas são (coluna, linha) no atlas.

`floor1.png`, `floor2.png` e `floor3.png` usam o layout de `world/room_tiles.gd`:

| (c, l) | Nome | (c, l) | Nome |
|---|---|---|---|
| (0, 0) | `floor_a` | (0, 1) | `door_locked` |
| (1, 0) | `floor_b` | (1, 1) | `door_open` |
| (2, 0) | `floor_crack` | (2, 1) | `door_shut` |
| (3, 0) | `floor_moss` | (3, 1) | `chest_closed` (fundo transparente) |
| (4, 0) | `wall_face` | (4, 1) | `chest_open` (fundo transparente) |
| (5, 0) | `wall_top` | (5, 1) | `wall_torch` |
| (6, 0) | `pillar` | (6, 1) | vazio |
| (7, 0) | `crate` | (7, 1) | vazio |

## Peças da cidade (`game/assets/town/`)

Desde a Task P3 a cidade não é um mapa de tiles. `ground.png` é o chão inteiro da tela (480x270, opaco). Os outros arquivos são sprites soltos, ordenados por Y na cena (`world/town.gd`, lista `PIECES`).

Em todo sprite, a linha de base (onde a parede ou o tronco toca o chão) fica 4 px acima da borda de baixo; esses 4 px guardam a sombra embutida. A cena põe a origem do sprite em (largura / 2, altura - 4). A sombra é uma elipse de duas faixas de alfa, por isso esses arquivos têm alfa parcial (os outros sprites do jogo não têm).

| Arquivo | Tamanho | Uso |
|---|---|---|
| `shop.png` | 106x116 | loja do herói (toldo, balcão, mesas) |
| `forge.png` | 106x104 | forja com chaminé, espelhada na cena |
| `house_a.png`, `house_b.png`, `house_c.png` | 59x86, 76x73, 64x82 | casas |
| `crystal.png`, `crystal_glow.png` | 52x66, 48x48 | cristal de teleporte e o brilho aditivo que pulsa |
| `tree_a.png`, `tree_b.png`, `tree_c.png` | 56x63, 42x53, 48x58 | árvores (sem colisão) |
| `lamp.png` | 18x44 | lampião (a luz é um `PointLight2D`) |
| `well.png`, `planter.png`, `flowerbed.png` | 36x46, 32x32, 32x31 | poço, floreira, canteiro |
| `fence.png`, `fence_post.png` | 42x24, 13x28 | cerca e poste (sem sombra) |
| `barrel.png`, `crates.png`, `sack.png` | 16x26, 20x30, 16x24 | barril, caixotes, saco |
