# Assets

Origem de cada arquivo de arte do jogo. Alimenta a ficha do jogo.

Toda geração usou o gerador de IA (ambiente QA, projeto `asset-gen`) com o preset de estilo `cinzel-pixel`. Os originais baixados ficam em `art-src/gen/` e `art-src/keyart/`. Os scripts em `art-src/` (rodar com `python3 -I` de um Python que tenha o Pillow, por exemplo um venv) transformam esses originais nas folhas do jogo:

- `build_climber.py`: escalador em camadas.
- `build_enemies.py`: inimigos.
- `build_tiles.py`: tilesets.
- `check_art.py`: confere tamanho, transparência e no máximo 32 cores.

`make_placeholders.py` continua gerando os placeholders antigos, mas não sobrescreve arquivo existente sem `--force`.

## Arquivos do jogo

| Arquivo | Origem | Data |
|---|---|---|
| `game/assets/characters/climber/body.png` | Derivado das folhas geradas do escalador (abaixo) por `build_climber.py`: pele, mãos e botas | 2026-11-14 |
| `game/assets/characters/climber/hair.png` | Idem: capuz e cabelo | 2026-11-14 |
| `game/assets/characters/climber/outfit.png` | Idem: jaqueta, cachecol, calça e mochila | 2026-11-14 |
| `game/assets/characters/climber/weapon.png` | Idem: espada e arco do golpe | 2026-11-14 |
| `art-src/climber-reference.png` | Composição das 4 camadas, referência para redesenhar à mão | 2026-11-14 |
| `game/assets/enemies/crawler.png` | `cinzel-enemy-crawler` por `build_enemies.py` (animação por deformação da pose gerada) | 2026-11-14 |
| `game/assets/enemies/shooter.png` | Conjurador de `cinzel-enemies-sheet` por `build_enemies.py` | 2026-11-14 |
| `game/assets/enemies/charger.png` | `cinzel-enemy-charger-v2` por `build_enemies.py` | 2026-11-14 |
| `game/assets/tiles/floor1.png` | `cinzel-tiles-floor1-sheet` e `cinzel-tiles-props-sheet` por `build_tiles.py` | 2026-11-14 |
| `game/assets/tiles/floor2.png` | `floor1.png` com a pedra em azul frio (`build_tiles.py`) | 2026-11-14 |
| `game/assets/tiles/floor3.png` | `floor1.png` com a pedra em vermelho escuro de brasa (`build_tiles.py`) | 2026-11-14 |
| `game/assets/tiles/town.png` | `cinzel-tiles-town-sheet` por `build_tiles.py` | 2026-11-14 |

## Gerações no gerador de IA

| Nome do asset | Modelo | Prompt (resumo) | Data |
|---|---|---|---|
| `cinzel-keyart-tower-1-6b2e37361861` | gpt-image-2.5 sunburst | Sala da torre, pixel art vista de cima (escolhida pelo Daniel) | 2026-11-14 |
| `cinzel-keyart-town-1-3796c73abe79` | gpt-image-2.5 sunburst | Rua da cidade, pixel art vista de cima (escolhida pelo Daniel) | 2026-11-14 |
| `cinzel-climber-turnaround-1-a9700b2c85f6` | template `styled-sprite-sheet`, papel `characters` | Escalador em pose neutra: frente, costas, lado (aprovado pelo Daniel) | 2026-11-14 |
| `cinzel-climber-walk-sheet-20a83c957340` | `openai/gpt-image-2.5/flare/edit`, referência = turnaround | "Using this exact character (...) draw a pixel-art animation sprite sheet on a flat magenta #FF00FF background (...) row 1 walk cycle facing the viewer, row 2 from behind, row 3 facing right" | 2026-11-14 |
| `cinzel-climber-attack-sheet-ed17687bcaf3` | `openai/gpt-image-2.5/flare/edit`, referência = turnaround | Mesmo pedido, ataque com espada em 3 linhas x 3 quadros: preparo, golpe com arco, acompanhamento | 2026-11-14 |
| `cinzel-climber-roll-death-sheet-a999fe192f26` | `openai/gpt-image-2.5/flare/edit`, referência = turnaround | Rolamento para frente, para trás e para o lado (4 quadros) e morte de frente (4 quadros) | 2026-11-14 |
| `cinzel-enemies-sheet-e3b89b5f3c48` | `style/gpt-image-2.5/flare`, preset `cinzel-pixel`, papel `characters` | Três inimigos; o preset devolveu só o conjurador encapuzado com cajado de orbe vermelho (usado como atirador) | 2026-11-14 |
| `cinzel-enemy-crawler-4688abb49eb4` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `characters` | Gosma vermelho-escura em cúpula, dois olhos vermelhos brilhando, brilho claro no topo | 2026-11-14 |
| `cinzel-enemy-charger-fc1d186596d2` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `characters` | Besouro-javali de placas cinza-marrom (descartado: virava ruído em 16 px) | 2026-11-14 |
| `cinzel-enemy-charger-v2-958fd2b4b941` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `characters` | Besouro-javali com casco liso azul-aço, faixa vermelha, chifres de osso, olhos vermelhos, silhueta simples | 2026-11-14 |
| `cinzel-tiles-floor1-sheet-a22089b881f0` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayTiles` | Folha 4x4 de tiles da torre: lajes (lisa, clara, rachada, com musgo), parede, topo de parede, pilar, caixote, portas (trancada, aberta, fechada), baús, parede com tocha | 2026-11-14 |
| `cinzel-tiles-props-sheet-6f9f6685ebad` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayProps` | Pilar, caixote, baú fechado, baú aberto com ouro, tocha de parede, sobre magenta | 2026-11-14 |
| `cinzel-tiles-town-sheet-07b9e1466613` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayTiles` | Folha 4x4 da cidade: calçamento, grama, madeira, terra, telhado, muro, toldo listrado, casa enxaimel, porta, janela, estandarte, topo de muro, água | 2026-11-14 |

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
