# Assets

Origem de cada arquivo de arte do jogo. Alimenta a ficha do jogo.

Toda geração usou o gerador de IA (ambiente QA, projeto `asset-gen`) com o preset de estilo `cinzel-pixel` (papéis `backgrounds`, `characters`, `gameplayTiles`, `gameplayProps`, `uiElements`; referências: as duas artes-chave escolhidas). Os originais baixados ficam em `art-src/gen/` e `art-src/keyart/`.

Os scripts em `art-src/` transformam esses originais nas folhas do jogo. Rode com `python3 -I` de um Python que tenha o Pillow, por exemplo um venv: `python3 -m venv /tmp/cinzel-venv && /tmp/cinzel-venv/bin/pip install pillow`, depois `/tmp/cinzel-venv/bin/python -I art-src/<script>.py .`.

- `build_climber.py` (com `walk_cycle.py`): escalador em camadas.
- `build_enemies.py`: inimigos.
- `build_boss.py`: chefe final (quadros de 32x32, mesma receita dos inimigos).
- `build_tiles.py`: tilesets.
- `build_ui.py`: ícones dos itens, NPCs da cidade, molduras e ícones da UI, fundo do título. `preview_ui.py` monta uma folha ampliada para revisar.
- `build_hud.py`: kit do HUD e dos painéis (molduras 9-slice, botões com estados, coração e moeda animados, ampulheta, anel, barras).
- `check_art.py`: confere tamanho, transparência e no máximo 32 cores.

Nenhum desses scripts sobrescreve um arquivo que já existe, porque ele pode ter sido redesenhado à mão. Para gerar de novo por cima, passe `--force`. `make_placeholders.py` segue a mesma regra.

## Arquivos do jogo

| Arquivo | Autoria | Origem | Data |
|---|---|---|---|
| `game/assets/characters/climber/body.png` | Gerado por IA (gpt-image-2.5 flare edit) + ajuste por script | Folhas do escalador (abaixo) por `build_climber.py`: pele, mãos e botas. Andar feito à mão por script (`walk_cycle.py`) a partir do quadro parado | 2026-11-14 |
| `game/assets/characters/climber/hair.png` | Idem | Idem: capuz e cabelo | 2026-11-14 |
| `game/assets/characters/climber/outfit.png` | Idem | Idem: jaqueta, cachecol, calça e mochila | 2026-11-14 |
| `game/assets/characters/climber/weapon.png` | Idem | Idem: espada e arco do golpe | 2026-11-14 |
| `art-src/climber-reference.png` | Idem | Composição das 4 camadas, guia para redesenhar à mão | 2026-11-14 |
| `game/assets/enemies/crawler.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`) + ajuste por script | `art-src/gen/enemy-crawler.png` por `build_enemies.py` (animação por deformação da pose gerada) | 2026-11-14 |
| `game/assets/enemies/shooter.png` | Idem | Conjurador de `art-src/gen/enemies-sheet.png` por `build_enemies.py` | 2026-11-14 |
| `game/assets/enemies/charger.png` | Idem | `art-src/gen/enemy-charger-v2.png` por `build_enemies.py` | 2026-11-14 |
| `game/assets/enemies/boss_final.png` | Gerado por IA (gpt-image-2.5 flare) + ajuste por script | `cinzel-boss-final` por `build_boss.py` (folha 4x4 de 32x32: parado, andar, ataque, morte). Os chefes dos andares 1 e 2 reaproveitam `crawler.png` e `charger.png` em escala x2 | 2026-11-14 |
| `game/assets/tiles/floor1.png` | Idem | `art-src/gen/tiles-floor1-sheet.png` e `art-src/gen/tiles-props-sheet.png` por `build_tiles.py` | 2026-11-14 |
| `game/assets/tiles/floor2.png` | Idem | `floor1` com a pedra em azul frio | 2026-11-14 |
| `game/assets/tiles/floor3.png` | Idem | `floor1` com a pedra em vermelho escuro de brasa | 2026-11-14 |
| `game/assets/tiles/town.png` | Idem | `art-src/gen/tiles-town-sheet.png` por `build_tiles.py` | 2026-11-14 |
| `game/assets/items/<id>.png` (8 ícones 16x16) | Gerado por IA (nano-banana-2 edit) + ajuste por script | `cinzel-item-icons-sheet` por `build_ui.py` | 2026-11-14 |
| `game/assets/characters/npc_shopkeeper.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Lojista de `cinzel-npcs-sheet` por `build_ui.py`; 2º quadro do idle = tronco 1 px abaixo | 2026-11-14 |
| `game/assets/characters/npc_blacksmith.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Ferreiro de `cinzel-npcs-sheet` por `build_ui.py`, mesmo idle | 2026-11-14 |
| `game/assets/ui/panel.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moldura de `cinzel-ui-kit-sheet` por `build_ui.py` (9-slice, margem 4) | 2026-11-14 |
| `game/assets/ui/slot.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Espaço de item de `cinzel-ui-kit-sheet` (9-slice, margem 3) | 2026-11-14 |
| `game/assets/ui/heart.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Coração de `cinzel-ui-kit-sheet` | 2026-11-14 |
| `game/assets/ui/coin.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moeda de `cinzel-ui-kit-sheet`, recolorida para dourado (saiu salmão) | 2026-11-14 |
| `game/assets/ui/title_bg.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | `cinzel-title-bg` reduzido para 320x180, 32 cores | 2026-11-14 |
| `game/assets/ui/hud/hp_frame.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moldura da barra de vida de `cinzel-hud-frames-sheet` por `build_hud.py`: metade esquerda reduzida e espelhada, 48x12, 9-slice 5/3/5/3 | 2026-11-14 |
| `game/assets/ui/hud/boss_frame.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moldura com chifres da barra do chefe de `cinzel-hud-frames-sheet`, mesma receita, 64x16, 9-slice 14/5/14/3 (a placa de nome é `plaque.png`) | 2026-11-14 |
| `game/assets/ui/hud/slot.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Espaço de item de `cinzel-hud-frames-sheet-b`, 22x22, simetrizado | 2026-11-14 |
| `game/assets/ui/hud/plaque.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Placa de ferro de `cinzel-hud-frames-sheet-b`, 9-slice margem 4: bloco do relógio, nome do chefe, títulos dos painéis | 2026-11-14 |
| `game/assets/ui/hud/button.png, button_hot.png, button_down.png, button_off.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Botão de `cinzel-hud-frames-sheet-b`, 9-slice margem 6; estados ativo (bronze clareado + brilho âmbar de 1 px), pressionado e desligado feitos por script | 2026-11-14 |
| `game/assets/ui/hud/panel.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moldura de janela de `cinzel-hud-frames-sheet-b`, 72x70, 9-slice margem 18, miolo escurecido para o texto ler | 2026-11-14 |
| `game/assets/ui/hud/heart.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Coração de `cinzel-hud-icons-sheet`, 4 quadros de 13x12 (repouso, cresce, pico, volta) por redução em tamanhos diferentes | 2026-11-14 |
| `game/assets/ui/hud/coin.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moeda de `cinzel-hud-icons-sheet`, 6 quadros de 9x9 (giro por achatamento; o verso é a face espelhada e mais escura; aro de 2 px) | 2026-11-14 |
| `game/assets/ui/hud/hourglass.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Ampulheta de `cinzel-hud-icons-sheet`, 6x9 | 2026-11-14 |
| `game/assets/ui/hud/ring.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Anel de luz de `cinzel-hud-icons-sheet`, 24x24, 8 cores | 2026-11-14 |
| `game/assets/ui/hud/fill_hp.png`, `fill_boss.png`, `fill_exit.png`, `fill_tip.png` | Autoral (script) | Rampas de 4 tons das barras e o pulso de luz da ponta, desenhados por `build_hud.py` | 2026-11-14 |
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
| `art-src/gen/climber-attack-sheet.png` | `cinzel-climber-attack-sheet-ed17687bcaf3` | idem | Mesmo pedido, ataque com espada em 3 linhas x 3 quadros: preparo, golpe com arco, acompanhamento | 2026-11-14 |
| `art-src/gen/climber-roll-death-sheet.png` | `cinzel-climber-roll-death-sheet-a999fe192f26` | idem | Rolamento para frente, para trás e para o lado (4 quadros) e morte de frente (4 quadros) | 2026-11-14 |
| `art-src/gen/enemies-sheet.png` | `cinzel-enemies-sheet-e3b89b5f3c48` | `style/gpt-image-2.5/flare`, preset `cinzel-pixel`, papel `characters` | Três inimigos; o preset devolveu só o conjurador encapuzado com cajado de orbe vermelho (usado como atirador) | 2026-11-14 |
| `art-src/gen/enemy-crawler.png` | `cinzel-enemy-crawler-4688abb49eb4` | idem | Gosma vermelho-escura em cúpula, dois olhos vermelhos brilhando, brilho claro no topo | 2026-11-14 |
| `art-src/gen/enemy-charger.png` | `cinzel-enemy-charger-fc1d186596d2` | idem | Besouro-javali de placas cinza-marrom. Descartado: virava ruído em 16 px | 2026-11-14 |
| `art-src/gen/enemy-charger-v2.png` | `cinzel-enemy-charger-v2-958fd2b4b941` | idem | Besouro-javali com casco liso azul-aço, faixa vermelha, chifres de osso, olhos vermelhos, silhueta simples | 2026-11-14 |
| `art-src/gen/tiles-floor1-sheet.png` | `cinzel-tiles-floor1-sheet-a22089b881f0` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayTiles` | Folha 4x4 de tiles da torre: lajes (lisa, clara, rachada, com musgo), parede, topo de parede, pilar, caixote, portas (trancada, aberta, fechada), baús, parede com tocha | 2026-11-14 |
| `art-src/gen/tiles-props-sheet.png` | `cinzel-tiles-props-sheet-6f9f6685ebad` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayProps` | Pilar, caixote, baú fechado, baú aberto com ouro, tocha de parede, sobre magenta | 2026-11-14 |
| `art-src/gen/tiles-town-sheet.png` | `cinzel-tiles-town-sheet-07b9e1466613` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayTiles` | Folha 4x4 da cidade: calçamento, grama, madeira, terra, telhado, muro, toldo listrado, casa enxaimel, porta, janela, estandarte, topo de muro, água | 2026-11-14 |
| `art-src/gen/boss-final.png` | `cinzel-boss-final-15618594aab4` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `characters` | Chefe final: cavaleiro-espectro encapuzado de armadura negra rachada, olhos e fenda no peito em brasa vermelha, lâmina incandescente, sobre magenta | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-item-icons-sheet-6a10443e5bc9` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `gameplayProps`, 2K | Grade 4x2 dos 8 itens sobre magenta, cada um com brilho amarelo (veio um mini escalador perdido no meio, apagado no script) | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-npcs-sheet-73ad112ab455` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `characters`, 2K | Lojista (avental verde, boné, bolsa de moedas) e ferreiro (careca, barba, avental de couro, martelo), 2 quadros de idle cada, sobre magenta | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-ui-kit-sheet-7be22ce3bc8a` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `uiElements`, 2K | Moldura de painel bronze, espaço de item, coração, moeda, relógio, sobre magenta | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-title-bg-69c9e042aad3` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `backgrounds`, 1K, 16:9 | Torre de pedra com brasas sobre a cidade de telhados vermelhos ao anoitecer, céu livre para o título | 2026-11-14 |


## Layout dos tilesets

Todos os tilesets têm 8 colunas x 2 linhas de tiles 16x16. As coordenadas são (coluna, linha) no atlas.

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

`town.png` (para a Task 12):

| (c, l) | Nome | Uso |
|---|---|---|
| (0, 0) | `cobble_a` | calçamento da praça |
| (1, 0) | `cobble_b` | calçamento, variação |
| (2, 0) | `grass` | grama |
| (3, 0) | `grass_flowers` | grama com flores |
| (4, 0) | `wood_planks` | piso de madeira (loja, ferreiro) |
| (5, 0) | `dirt` | caminho de terra |
| (6, 0) | `roof` | telhado de telha vermelha |
| (7, 0) | `wall_face` | face do muro de pedra clara |
| (0, 1) | `awning` | toldo listrado vermelho e creme |
| (1, 1) | `awning_edge` | borda recortada do toldo (metade de baixo transparente) |
| (2, 1) | `house_wall` | parede enxaimel |
| (3, 1) | `house_door` | porta de casa |
| (4, 1) | `house_window` | janela com veneziana |
| (5, 1) | `banner` | estandarte azul (fundo transparente) |
| (6, 1) | `wall_top` | topo do muro, visto de cima |
| (7, 1) | `water` | água rasa |
| `art-src/gen/hud-frames-sheet.png` | `cinzel-hud-frames-sheet-218b52ab9951` | `fal-ai/nano-banana-2/edit` (via `generate_styled_image`), preset `cinzel-pixel`, papel `uiElements`, 2K, 16:9 | Kit de HUD sobre magenta: barra de vida de ferro com cantos de bronze, barra do chefe com pontas de chifre e placa no meio, espaço de item, placa, botão, janela. Só as duas barras saíram limpas: o resto veio misturado com a arte de referência da cidade | 2026-11-14 |
| `art-src/gen/hud-frames-sheet-b.png` | `cinzel-hud-frames-sheet-b-0c785c1847fa` | idem, 2K, 1:1 | Espaço de item de ferro rebitado com cantos de bronze, placa de ferro com friso de bronze, botão marrom com borda de bronze chanfrada, janela de bronze e ferro com cantos ornamentados, sobre magenta | 2026-11-14 |
| `art-src/gen/hud-icons-sheet.png` | `cinzel-hud-icons-sheet-da5da5001b42` | idem, 1K, 4:1 | Coração vermelho, moeda dourada com torre em relevo, ampulheta de bronze com areia âmbar, anel de luz âmbar, sobre magenta | 2026-11-14 |
