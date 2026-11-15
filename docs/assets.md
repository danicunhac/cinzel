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
- `build_weapons.py`: camada de arma de cada tipo e as poses de ataque próprias (Task E3).
- `build_outfits.py`: copia a roupa inicial para `outfits/starter/` e guarda a repintura por grupo de cor que as outras roupas usam.
- `build_outfit_shapes.py`: as outras roupas visuais (camadas `hair` e `outfit`), cada uma com a sua silhueta: repintura da roupa inicial mais formas tiradas das máscaras de cada quadro (saia, casaco, tabardo, avental, ombreiras, mangas largas, capa num ombro, cabelo espetado).
- `build_items.py`: ícones 16x16 de armas, armaduras, capuzes, mochilas, materiais e roupas, e as molduras de raridade (Task E3). `preview_items.py` monta a folha de conferência.
- `split_layers.py`: tira a mochila e os cabos de machado e lança das camadas `body`, `hair` e `outfit` do escalador (e das tiras de ataque), guarda as camadas originais em `art-src/split/orig/` e os pixels tirados em `art-src/split/` (`pack*.png`, `haft_*.png`). Roda depois de `build_weapons.py`.
- `build_weapon_items.py`: camada de arma de cada item (`climber/weapons/<id>.png`), da folha do tipo com as cores e a forma do ícone.
- `build_offhand.py`: a espada na mão secundária (`climber/offhand/<id>.png`, só espadas) e as armas guardadas na cidade (`climber/weapons/<id>_sheathed.png`, todas; `climber/offhand/<id>_sheathed.png`, espadas), das folhas de `build_weapon_items.py` e das cores do ícone. Roda depois dele.
- `build_gear.py`: camadas de armadura e elmo (`climber/gear/`), tiradas quadro a quadro das camadas do escalador, nas cores do ícone de cada item, com as formas do ícone (saias, ombreiras, espinhos, capuz fundo, aba do elmo).
- `build_backpacks.py`: camada da mochila de cada item (`climber/gear/backpack_*.png`): a mochila tirada por `split_layers.py`, repintada, mais o tamanho de cada item, quadro a quadro.
- `preview_gear.py`: prévias 4x e GIFs do escalador com cada arma e cada roupa, empilhando as camadas como o jogo.
- `preview_equip.py`: folha ícone x sprite (ícone, parado de frente, parado de lado e um quadro de ataque) de cada item equipável.
- `build_logo.py`: logo CINZEL (240, 120 e 80 px de largura, brilho de brasa do logo grande), emblema quadrado (16, 32, 64, 256), `icon.ico` do Windows e imagem do boot splash.
- `build_title.py`: camadas da tela de título desenhadas por script (parapeito, faixa de névoa, luz quente).
- `check_art.py`: confere tamanho, transparência, no máximo 32 cores, quadros sem uso vazios, pixels soltos nas camadas do escalador e a linha do chão (escalador e NPCs 30, inimigos 22, chefe 44).
- `build_decor.py`: tira de decoração das salas (12 quadros de 32x32: barril, caixote, ossos, crânios, pote quebrado, velas, correntes, entulho, musgo, estandarte, suporte de armas, teia), posta nas salas por `game/world/decor_layout.gd` quando `game/tools/build_rooms.gd` roda.
- `build_rooms_art.py` (precisa também de `numpy`): salas pintadas. `blockout` desenha cada layout de `game/tools/build_rooms.gd` em cores chapadas (480x270; chão rachado e musgo ficam como chão liso, senão a pintura vira blocos; o layout sai em `art-src/gen/rooms/layouts.json` quando o `build_rooms.gd` roda), `score` e `overlay` conferem o alinhamento de uma pintura com a colisão, `final` reduz a pintura escolhida para 480x270 (média por área), gradua por andar (`GRADE`: nitidez, luminância média alvo, contraste, saturação), no máximo 48 cores, sem pontilhado,, desloca até 8 px quando o chão inteiro deslizou e grava `art-src/gen/rooms/align/` (sobreposição e `scores.json`), `doors` monta as portas.

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
| `game/assets/rooms/<sala>.png` (24 fundos 480x270: `t1_move_attack`, `t2_dodge`, `t3_heal`, `f1_anel`, `f1_antessala`, `f1_arena`, `f1_colunas`, `f1_cruz`, `f1_galeria`, `boss_f1`, `f2_salao`, `f2_corredor`, `f2_cripta`, `f2_fosso`, `f2_mirante`, `f2_nave`, `boss_f2`, `f3_camaras`, `f3_claustro`, `f3_forja`, `f3_obsidiana`, `f3_ponte`, `f3_serpente`, `boss_f3`) | Gerado por IA (gpt-image-2.5 sunburst edit) a partir do layout + ajuste por script | `art-src/gen/rooms/<sala>.png` por `build_rooms_art.py final`. Repintadas no estilo da cidade: edição do blockout `<sala>@4x.png` com a captura da cidade no jogo ampliada 4x (`town-ref-4x`) e `art-src/gen/town-ground.png` como referências. As placas de gelo (`i`) são pintadas e ganham um brilho por código (`world/ice_patch.gd`); as grelhas de brasa (`v`) são desenhadas por código (`world/ember_vent.gd`). Retoques à mão na pintura de origem: em `f1_galeria` faltava um caixote na fileira de baixo (copiado do vizinho); em `f1_anel` a face do bloco central foi estendida uma linha para cobrir a colisão. O `CanvasModulate` das salas (`AMBIENT` em `build_rooms.gd`) fica perto do `TINT` da cidade | 2026-11-14 |
| `game/assets/rooms/doors.png` | Gerado por IA (gpt-image-2.5 sunburst edit) + ajuste por script | `art-src/gen/rooms/doors-sheet.png` por `build_rooms_art.py doors`, 3x2 quadros de 24x32: fechada, trancada, aberta; frente e lado; até 32 cores; o cadeado da trancada é redesenhado em pixel (7x8) por cima, porque o pintado some na redução | 2026-11-14 |
| `game/assets/rooms/stairs_down.png` | Gerado por IA (gpt-image-2.5 sunburst edit) + ajuste por script | `art-src/gen/r2/stairs-down-1.png` por `build_stairs.py`: chave magenta, redução por área para 34 px de largura (altura pela proporção), até 32 cores; escada para baixo da primeira sala de cada andar | 2026-11-14 |
| `game/assets/items/<id>.png` (8 ícones 16x16) | Gerado por IA (nano-banana-2 edit) + ajuste por script | `cinzel-item-icons-sheet` por `build_ui.py` | 2026-11-14 |
| `game/assets/characters/npc_shopkeeper.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Lojista de `cinzel-npcs-sheet` por `build_ui.py`, 2 quadros de 32x32 (pés na linha 30, contorno escuro); 2º quadro do idle = tronco 1 px abaixo | 2026-11-14 |
| `game/assets/characters/npc_blacksmith.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Ferreiro de `cinzel-npcs-sheet` por `build_ui.py`, mesmo formato | 2026-11-14 |
| `game/assets/characters/villagers/<look>.png` (`oldwoman`, `child`, `guard`, `farmer`, `archer`, `merchant`) | Gerado por IA (gpt-image-2.5 flare edit) + ajuste por script | `art-src/gen/villager-<look>.png` por `build_villagers.py`: 4x6 células de 32x32 (idle 2 quadros e andar 4 quadros, de frente, de costas e de lado olhando à direita), pés na linha 30, corpo na coluna 16, 32 cores, uma escala para todos | 2026-11-14 |
| `game/assets/ui/panel.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moldura de `cinzel-ui-kit-sheet` por `build_ui.py` (9-slice, margem 4) | 2026-11-14 |
| `game/assets/ui/slot.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Espaço de item de `cinzel-ui-kit-sheet` (9-slice, margem 3) | 2026-11-14 |
| `game/assets/ui/heart.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Coração de `cinzel-ui-kit-sheet` | 2026-11-14 |
| `game/assets/ui/coin.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | Moeda de `cinzel-ui-kit-sheet`, recolorida para dourado (saiu salmão) | 2026-11-14 |
| `game/assets/ui/title_bg.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | `cinzel-title-bg` reduzido para 480x270, 32 cores | 2026-11-14 |
| `game/assets/ui/logo/logo_large.png`, `logo_medium.png`, `logo_small.png`, `boot_splash.png` | Gerado por IA (nano-banana-2 edit) + ajuste por script | `art-src/gen/logo/wordmark-1-2.png` por `build_logo.py`: chave magenta, redução por área para 240/120/80 px de largura, contorno de 1 px, até 32 cores; o splash é o logo grande x3 | 2026-11-14 |
| `game/assets/ui/logo/logo_large_glow.png` | Autoral (script) | Halo de brasa em 3 faixas, 4 px em volta do logo grande, por `build_logo.py` (soma aditiva no Godot) | 2026-11-14 |
| `game/assets/ui/logo/emblem_16.png`, `emblem_32.png`, `emblem_64.png`, `emblem_256.png`, `icon.ico` | Gerado por IA (nano-banana-2 edit) + ajuste por script | `art-src/gen/logo/emblem-1-1.png` por `build_logo.py`; o 256 é o 64 x4; o `.ico` junta 16 a 256 para o export do Windows | 2026-11-14 |
| `game/assets/ui/title/parapet.png`, `fog.png`, `glow.png` | Autoral (script) | `build_title.py`: parapeito escuro com borda quente, faixa de névoa que repete a cada 512 px, luz radial em faixas | 2026-11-14 |
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
| `game/assets/town/decals.png` (192x16) | Gerado por IA + ajuste por script | `art-src/gen/town-base-decals.png` por `build_town.py`: 12 células de 16 px (tufos de grama, musgo, pedras soltas), contorno trocado por tom de chão; `town.gd` espalha nas bases | 2026-11-14 |
| `game/assets/town/shop.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`) + ajuste por script | `art-src/gen/town-shop.png` por `build_town.py`: recorte, 104 px de largura, até 29 cores, contorno de 1 px e sombra suave embutida | 2026-11-14 |
| `game/assets/town/forge.png` | Idem | `art-src/gen/town-forge.png`, mesma receita; a cena espelha o sprite | 2026-11-14 |
| `game/assets/town/house_a.png` | Idem | `art-src/gen/town-houses.png`, 80 px de altura | 2026-11-14 |
| `game/assets/town/house_b.png`, `house_c.png` | Gerado por IA (gpt-image-2.5 flare edit) + ajuste por script | `art-src/gen/town-houses-b.png` (casa de pedra e casa enxaimel) | 2026-11-14 |
| `game/assets/town/crystal.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`) + ajuste por script | `art-src/gen/town-crystal.png`, 60 px de altura | 2026-11-14 |
| `game/assets/town/tree_a.png`, `tree_b.png`, `tree_c.png`, `lamp.png`, `well.png`, `planter.png`, `flowerbed.png`, `fence.png`, `fence_post.png`, `barrel.png`, `crates.png`, `sack.png` | Idem | `art-src/gen/town-props.png`, um recorte por objeto (caixas em `build_town.py`); o halo rosa do lampião vira luz âmbar | 2026-11-14 |
| `game/assets/town/tower_gate.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`) + ajuste por script | `art-src/gen/town-tower-gate.png` por `build_town.py`, 88 px de altura; a cena põe a chave de ordenação na porta para o jogador aparecer na escada | 2026-11-14 |
| `game/assets/town/crystal_glow.png` | Feito por script | Brilho azul radial em 4 faixas, desenhado em `build_town.py` | 2026-11-14 |
| `game/assets/fonts/Silkscreen-Regular.ttf` | Terceiros: fonte Silkscreen, licença SIL OFL 1.1 | Fonte Silkscreen (Jason Kottke), SIL OFL 1.1, de google/fonts; licença em `Silkscreen-OFL.txt` | 2026-11-14 |

| `game/assets/characters/climber/weapons/sword.png` | Gerado por IA + ajuste por script | Cópia de `climber/weapon.png` por `build_weapons.py` | 2026-11-14 |
| `game/assets/characters/climber/weapons/longsword.png`, `bow.png`, `axe.png`, `spear.png`, `dagger.png` | Gerado por IA (gpt-image-2.5 flare edit) + desenho por script | Linhas de parado, andar, rolamento e morte: a arma é desenhada por `build_weapons.py` na mão, no lugar e na direção da espada de cada quadro. Linhas de ataque: tiras `art-src/gen/r2/climber32-attack-<tipo>-*` (abaixo) | 2026-11-14 |
| `game/assets/characters/climber/weapons/<id>.png` (as 12 armas do catálogo) | Feito por script sobre `weapons/<tipo>.png` | `build_weapon_items.py`: cores tiradas do ícone do item (k-means por parte: lâmina ou cabeça, cabo, guarda, corda, borla). Linhas de parado, andar, rolamento e morte redesenhadas com o código de `build_weapons.py` nas cores do item, mais a forma: machado de duas lâminas (`axe_war`), asas e borla vermelha sob a ponta (`spear_dragoon`); as espadas com lâmina de 7 px e guarda na cor do ícone (dourada em `sword_knight`, aço escuro em `sword_iron`). Linhas de ataque: as do tipo recoloridas por casamento de histograma, mais os cabos de machado e lança que `split_layers.py` tirou das tiras, nas cores do cabo; `axe_war` com a cabeça espelhada no cabo, `spear_dragoon` com as asas | 2026-11-15 |
| `game/assets/characters/climber/attacks/<tipo>_{body,hair,outfit}.png` (`longsword`, `bow`, `axe`, `spear`, `dagger`) | Gerado por IA (gpt-image-2.5 flare edit) + ajuste por script | Poses de ataque próprias: espada longa (varrida larga com as duas mãos), arco (puxar a corda e soltar), machado (golpe de cima até o chão), lança (estocada) e adaga (duas estocadas rápidas), 8x3 de 32x32, cores levadas para a paleta das camadas do escalador | 2026-11-14 |
| `game/assets/characters/climber/outfits/starter/*` | Gerado por IA + ajuste por script | Cópias de `climber/hair.png`, `climber/outfit.png` e de `climber/attacks/<tipo>_{hair,outfit}.png` | 2026-11-14 |
| `game/assets/characters/climber/outfits/casaco_longo/*` | Gerado por IA + ajuste por script | Roupa inicial repintada e com silhueta própria por `build_outfit_shapes.py`: capuz e casaco cinza-escuro quase preto até os pés, fechado com costura, gola alta cinza | 2026-11-15 |
| `game/assets/characters/climber/outfits/cavaleiro_leve/*` | Gerado por IA + ajuste por script | Roupa inicial repintada e com silhueta própria por `build_outfit_shapes.py`: coifa de malha de aço, peitoral branco-prateado com ombreiras, tabardo carmim até os joelhos | 2026-11-15 |
| `game/assets/characters/climber/outfits/tunica_ferreiro/*` | Gerado por IA + ajuste por script | Roupa inicial repintada e com silhueta própria por `build_outfit_shapes.py`: bandana vermelho-ferrugem, túnica de linho até o meio da coxa, avental de couro até os joelhos | 2026-11-15 |
| `game/assets/characters/climber/outfits/manto_mago/*` | Gerado por IA + ajuste por script | Roupa inicial repintada e com silhueta própria por `build_outfit_shapes.py`: capuz e manto violeta até o chão com mangas largas, gola e barra verde-água claro | 2026-11-15 |
| `game/assets/characters/climber/outfits/sobretudo_noite/*` | Feito por script sobre a arte gerada | `build_outfit_shapes.py`: capuz negro, sobretudo de couro negro-azulado abaixo dos joelhos, aberto na frente, cauda partida que balança, friso prateado, camisa cinza-escura | 2026-11-15 |
| `game/assets/characters/climber/outfits/traje_sombra/*` | Feito por script sobre a arte gerada | `build_outfit_shapes.py`: cabelo curto espetado, jaqueta negra justa de gola alta, capa curta num ombro com fio vermelho-escuro, calça grafite | 2026-11-15 |
| `game/assets/characters/climber/gear/armor_<id>.png` (`armor_cloth`, `armor_leather`, `armor_chain`, `armor_scale`, `armor_plate`, `armor_shadow`) e `gear/attacks/<tipo>_armor_<id>.png` | Feito por script sobre as camadas do escalador | `build_gear.py`: os pixels do tronco de `climber/outfit.png` (jaqueta, luvas, cachecol e cinto, nunca a calça nem a mochila) de cada quadro, repintados nas cores do ícone (k-means no ícone mais o realce dele, por posto de brilho, com os tons claros da jaqueta indo para o realce): pano acolchoado bege-claro com costuras, couro marrom-avermelhado com correia e fivela, malha prateada pontilhada, escamas oliva-escuro, placas de aço claro com ombreiras de 1 px para fora, pano de sombra roxo-amarronzado | 2026-11-15 |
| `game/assets/characters/climber/gear/helm_<id>.png` (`helm_hood`, `helm_iron`, `helm_horned`, `helm_circlet`) e `gear/attacks/<tipo>_helm_<id>.png` | Feito por script sobre as camadas do escalador | `build_gear.py`: os pixels visíveis do capuz e do cabelo de `climber/hair.png` de cada quadro, repintados nas cores do ícone: capuz de couro marrom-alaranjado, elmo de bronze com aba clara e protetor de nariz, o mesmo elmo com dois chifres amarelados, e o diadema (só uma faixa dourada com pedra azul sobre o capuz) | 2026-11-15 |
| `game/assets/characters/climber/gear/backpack_<id>.png` (`backpack_small`, `backpack_medium`, `backpack_large`) e `gear/attacks/<tipo>_backpack_<id>.png` | Feito por script sobre as camadas do escalador | `build_backpacks.py`: em todo quadro, a mochila da roupa inicial (tirada por `split_layers.py`) repintada nas cores do ícone; em parado, andar e ataque, de costas e de lado, a mochila do item por cima: pequena (bolsa compacta marrom), média (mais alta, cobertor cinza-ardósia em cima), grande (alta, saco de dormir grosso). De frente: alças (fina e escura na pequena, fina e clara na média, larga na grande) e as pontas do cobertor ou do saco de dormir que sobram dos lados da cabeça | 2026-11-15 |
| `game/assets/characters/climber/hair.png`, `outfit.png`, `attacks/<tipo>_{body,hair,outfit}.png` | Gerado por IA + ajuste por script | Sem a mochila e sem os cabos de machado e lança: `split_layers.py` os tira (originais em `art-src/split/orig/`) | 2026-11-15 |
| `game/assets/items/sword_midnight.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`, papel `gameplayProps`) + ajuste por script | `art-src/gen/r2/icon-sword-midnight-2.png` por `build_items.py`: chave magenta, esticada x2 na largura da lâmina antes da redução (senão a lâmina vira 1 px), clareada x1,4, nítida como as outras armas | 2026-11-15 |
| `game/assets/characters/climber/weapons/sword_midnight.png` | Feito por script | `build_weapon_items.py` sobre `weapons/sword.png`: lâmina preta com o fio e a ponta prateados (forma `midnight`), guarda e cabo do ícone | 2026-11-15 |
| `game/assets/characters/climber/offhand/<id>.png` (`sword_iron`, `sword_knight`, `sword_midnight`) | Feito por script | `build_offhand.py`: a folha `weapons/<id>.png` espelhada no centro do corpo (frente e costas; o andar usa o quadro de meio ciclo depois, o braço oposto), 2 px para trás e 1 px para cima de lado (o jogo desenha atrás do corpo); nas linhas de ataque, a pose parada do quadro 0 acompanhando o corpo | 2026-11-15 |
| `game/assets/characters/climber/weapons/<id>_sheathed.png` (as 13 armas), `offhand/<id>_sheathed.png` (espadas) | Feito por script | `build_offhand.py`: só linhas de parado, andar e rolamento. Espada e adaga na cintura do lado da mão (a segunda espada na outra cintura), cabo para cima, bainha de couro escuro com contorno, guarda, cabo e ponteira nas cores do ícone. Espada longa, machado, lança e arco nas costas, na diagonal, desenhados com o código de `build_weapons.py` nas cores do item | 2026-11-15 |
| `game/assets/items/<id>.png` (armas, armaduras, capuzes, mochilas, materiais; 35 ícones 16x16) | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`) + ajuste por script | Folhas `art-src/gen/icons-*.png` por `build_items.py` (lista de ids abaixo) | 2026-11-14 |
| `game/assets/items/mat_iron_ore.png`, `mat_old_leather.png`, `mat_ash_wood.png`, `mat_chitin.png`, `mat_silver_ore.png`, `mat_coal.png` | Gerado por IA (gpt-image-2.5 flare, preset `cinzel-pixel`, papel `gameplayProps`) + ajuste por script | `art-src/gen/icons-materials2-sheet.png` por `build_items.py`; substituem gosma, núcleo, lasca, olho, carapaça e pó de brasa | 2026-11-14 |
| `game/assets/items/outfit_<id>.png` (7 ícones 16x16) | Feito por script sobre a arte gerada | Busto (cabeça e ombros) do quadro parado de frente de cada roupa, 1:1, por `build_items.py` | 2026-11-14 |
| `game/assets/items/frames/common.png`, `rare.png`, `epic.png` (18x18) | Autoral (script) | Anel de 2 px desenhado por `build_items.py`: branco, azul e roxo | 2026-11-14 |

Quando o Daniel redesenhar um arquivo à mão, troque a autoria dessa linha para "Autoral (Daniel)".

## Gerações no gerador de IA

O nome no gerador de IA leva um hash de conteúdo. O arquivo no repositório é o original PNG baixado.

| Arquivo no repo | Asset no gerador de IA | Modelo | Prompt (resumo) | Data |
|---|---|---|---|---|
| `art-src/keyart/keyart-tower-1-f637e9b7acec.png` | `cinzel-keyart-tower-1-6b2e37361861` | gpt-image-2.5 sunburst | Sala da torre, pixel art vista de cima (escolhida pelo Daniel) | 2026-11-14 |
| `art-src/keyart/keyart-town-1-bd276bf242c4.png` | `cinzel-keyart-town-1-3796c73abe79` | gpt-image-2.5 sunburst | Rua da cidade, pixel art vista de cima (escolhida pelo Daniel) | 2026-11-14 |
| `art-src/gen/rooms/<sala>.png` | `cinzel-room2-<sala>-<n>-<hash>` (lista em `art-src/gen/rooms/sources.json`, projeto `asset-gen`) | `openai/gpt-image-2.5/sunburst/edit`, imagens = blockout da sala + `town-ref-4x-70568fd908e7` (captura da cidade no jogo, 4x) + `town-ground-2671cc35bd75` | "Repaint the FIRST image ... in EXACTLY the art style, brightness, saturation and pixel density of the SECOND and THIRD images", com legenda das cores do blockout e a posição de cada porta por sala: andar 1 lajes de arenito pequenas como o calçamento da cidade, musgo e grama, vigas, estandartes vermelho e azul; andar 2 pedra cinza-azulada com geada, gelo nas placas `i`, estandartes azuis, braseiros; andar 3 basalto em tons médios, pedras pequenas, rachaduras em brasa, ferro e latão, estandartes vermelhos; tutoriais com placa de madeira lisa no muro grosso; chefes com um anel de lajes no meio; chão livre, sem objetos. 2 imagens por pedido, escolhida pela sobreposição; `f1_arena`, `t1_move_attack`, `t2_dodge`, `t3_heal` e `f1_colunas` precisaram de uma segunda rodada | 2026-11-14 |
| `art-src/gen/rooms/doors-sheet.png` | `cinzel-room-doors-sheet-town-1-473f13e2fc25` | `openai/gpt-image-2.5/sunburst/edit`, imagens = folha antiga (`cinzel-room-doors-sheet-2-52c5ba8fb7e8`) + `town-props` | Mesmas seis portas na mesma grade sobre magenta, no estilo dos objetos da cidade: madeira mel, arco de pedra clara, ferro, contorno de 1 px | 2026-11-14 |
| `art-src/gen/r2/stairs-down-1.png` | `cinzel-stairs-down-town-2-c31c136edb65` | `openai/gpt-image-2.5/sunburst/edit`, imagens = escada antiga (`cinzel-stairs-down-1-5fd6a2d89887`) + `town-props` | Mesma escada descendo no chão, arenito claro, degraus iluminados que escurecem só no fundo, contorno de 1 px, sobre magenta | 2026-11-14 |
| `art-src/gen/r2/stairs-down-2.png` | `cinzel-stairs-down-2-eb4a2d8435b9` | `style/gpt-image-2.5/flare`, preset `cinzel-pixel`, papel `gameplayProps` | Alternativa antiga da escada, não usada | 2026-11-14 |
| `art-src/gen/decor-sheet.png` | `cinzel-decor-sheet-town-1-594386541de5` | `openai/gpt-image-2.5/sunburst/edit`, imagens = folha antiga + `town-props` | Mesmos 12 objetos na mesma grade 4x3 sobre magenta, no estilo dos objetos da cidade | 2026-11-14 |
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
| `art-src/gen/town-tower-gate.png` | `cinzel-town-tower-gate-2-0440c046ac1c` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayProps` | Base da torre: pedra escura, ameias, portão em arco com portas abertas e luz âmbar, escada de pedra, tochas, estandartes azuis, hera | 2026-11-14 |
| `art-src/gen/town-props.png` | `cinzel-town-props-316a781f76ff` | idem, 2K | Folha de objetos em 3 linhas: três árvores (carvalho, árvore clara, outono), lampião, poço, floreira, canteiro redondo, cerca, poste, barril, caixotes, saco | 2026-11-14 |
| `art-src/gen/town-ground-guide.png` | `town-ground-guide-9e3f26c9fe7f` (upload) | `town_ground_guide.py` | Mapa de cores do chão: cinza = calçamento, anel claro = anel de pedra do cristal, marrom = terra, verde = grama | 2026-11-14 |
| `art-src/gen/town-ground.png` | `cinzel-town-ground-e1d822381cad` | `openai/gpt-image-2.5/flare/edit`, referências = guia + arte-chave da cidade | "Repaint it as the GROUND ONLY of a top-down pixel art town square, keeping every region where it is": calçamento, anel de lajes, caminho de terra, grama com flores, meio-fio de pedra, sem prédios | 2026-11-14 |
| `art-src/gen/town-base-decals.png` | `cinzel-town-base-decals-925384bda50c` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayProps` | Grade 4x3 de decalques de chão: tufos de grama entre pedras, musgo com seixos, pedras de fundação soltas, sobre magenta | 2026-11-14 |
| `art-src/gen/villager-oldwoman.png` | `cinzel-villager-oldwoman-58cefbfd2a8f` | `openai/gpt-image-2.5/flare/edit`, referências = turnaround do herói + `climber32-walk-side-1` + arte-chave da cidade, papel `characters` | Senhora idosa: coque grisalho, xale vermelho, vestido marrom, cesto; grade 3x4 de andar (frente, costas, lado direito) sobre magenta | 2026-11-14 |
| `art-src/gen/villager-child.png` | `cinzel-villager-child-82fcabf6b5b1` | `openai/gpt-image-2.5/flare/edit`, referências = turnaround do herói + `climber32-walk-side-1` + arte-chave da cidade, papel `characters` | Criança ruiva de túnica azul com espada de madeira; grade 3x4 de andar (frente, costas, lado direito) sobre magenta | 2026-11-14 |
| `art-src/gen/villager-guard.png` | `cinzel-villager-guard-a4a0059da309` | `openai/gpt-image-2.5/flare/edit`, referências = turnaround do herói + `climber32-walk-side-1` + arte-chave da cidade, papel `characters` | Guarda: elmo de aço, cota de malha, tabardo azul, lança; grade 3x4 de andar (frente, costas, lado direito) sobre magenta | 2026-11-14 |
| `art-src/gen/villager-farmer.png` | `cinzel-villager-farmer-98b6df32113c` | `openai/gpt-image-2.5/flare/edit`, referências = turnaround do herói + `climber32-walk-side-1` + arte-chave da cidade, papel `characters` | Fazendeiro: chapéu de palha, camisa verde, macacão, enxada; grade 3x4 de andar (frente, costas, lado direito) sobre magenta | 2026-11-14 |
| `art-src/gen/villager-archer.png` | `cinzel-villager-archer-e8cf458d63cc` | `openai/gpt-image-2.5/flare/edit`, referências = turnaround do herói + `climber32-walk-side-1` + arte-chave da cidade, papel `characters` | Aventureira: trança ruiva, colete verde, aljava, arco; grade 3x4 de andar (frente, costas, lado direito) sobre magenta | 2026-11-14 |
| `art-src/gen/villager-merchant.png` | `cinzel-villager-merchant-11d3f00d46d1` | `openai/gpt-image-2.5/flare/edit`, referências = turnaround do herói + `climber32-walk-side-1` + arte-chave da cidade, papel `characters` | Mercador de capuz roxo, barba grisalha, mochila com panelas, cajado com lanterna; grade 3x4 de andar (frente, costas, lado direito) sobre magenta | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-item-icons-sheet-6a10443e5bc9` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `gameplayProps`, 2K | Grade 4x2 dos 8 itens sobre magenta, cada um com brilho amarelo (veio um mini escalador perdido no meio, apagado no script) | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-npcs-sheet-73ad112ab455` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `characters`, 2K | Lojista (avental verde, boné, bolsa de moedas) e ferreiro (careca, barba, avental de couro, martelo), 2 quadros de idle cada, sobre magenta | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-ui-kit-sheet-7be22ce3bc8a` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `uiElements`, 2K | Moldura de painel bronze, espaço de item, coração, moeda, relógio, sobre magenta | 2026-11-14 |
| (sem arquivo bruto no repo) | `cinzel-title-bg-69c9e042aad3` | `fal-ai/nano-banana-2/edit`, preset `cinzel-pixel`, papel `backgrounds`, 1K, 16:9 | Torre de pedra com brasas sobre a cidade de telhados vermelhos ao anoitecer, céu livre para o título | 2026-11-14 |
| `art-src/gen/hud-frames-sheet.png` | `cinzel-hud-frames-sheet-218b52ab9951` | `fal-ai/nano-banana-2/edit` (via `generate_styled_image`), preset `cinzel-pixel`, papel `uiElements`, 2K, 16:9 | Kit de HUD sobre magenta: barra de vida de ferro com cantos de bronze, barra do chefe com pontas de chifre e placa no meio, espaço de item, placa, botão, janela. Só as duas barras saíram limpas: o resto veio misturado com a arte de referência da cidade | 2026-11-14 |
| `art-src/gen/hud-frames-sheet-b.png` | `cinzel-hud-frames-sheet-b-0c785c1847fa` | idem, 2K, 1:1 | Espaço de item de ferro rebitado com cantos de bronze, placa de ferro com friso de bronze, botão marrom com borda de bronze chanfrada, janela de bronze e ferro com cantos ornamentados, sobre magenta | 2026-11-14 |
| `art-src/gen/hud-icons-sheet.png` | `cinzel-hud-icons-sheet-da5da5001b42` | idem, 1K, 4:1 | Coração vermelho, moeda dourada com torre em relevo, ampulheta de bronze com areia âmbar, anel de luz âmbar, sobre magenta | 2026-11-14 |
| `art-src/gen/logo/wordmark-1-2.png` | `cinzel-logo-wordmark-1-2-79dcd9b2768e` | `fal-ai/nano-banana-2/edit` (via `generate_styled_image`), preset `cinzel-pixel`, papel `uiElements`, 2K, 4:1, 2 variações (a 1 tinha uma ponta solta sobre o C) | "CINZEL" em blocos de pedra entalhada com bordas de ferro, rebites de bronze e brilho de brasa embaixo; o I é uma torre com janela acesa; sobre magenta | 2026-11-14 |
| `art-src/gen/logo/emblem-1-1.png` | `cinzel-logo-emblem-1-1-10cd82af1058` | idem, 1K, 1:1, 2 variações | Emblema: C de pedra com rebites, torre com janela acesa e espada atravessada, brasas; sobre magenta | 2026-11-14 |

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


### Equipamento (Task E3)

Tiras de ataque por arma: `openai/gpt-image-2.5/flare/edit`, 2K, 16:9, papel `characters`, 2 variações por pedido (a outra foi descartada). Referências: o turnaround aprovado `cinzel-climber-turnaround-1-a9700b2c85f6` e a folha atual do escalador ampliada 4x sobre magenta (`hero-sheet-magenta-90b185ad225b`, upload). Prompt base: "Using this exact character (...) from the first image, drawn in the same pixel-art style and proportions as the sprite sheet in the second image, draw a pixel-art animation strip on a flat solid magenta #FF00FF background: ONE horizontal row of exactly 6 frames (...)", mais a pose quadro a quadro. Arma e flecha pedidas em cinza-aço para o script separar a camada de arma pela cor.

Ícones: `style/gpt-image-2.5/flare` (via `generate_styled_image`), preset `cinzel-pixel`, papel `gameplayProps`, 2K, sobre magenta. Originais em `art-src/gen/icons-*.png`.

| Arquivo no repo | Asset no gerador de IA | Modelo | Prompt (resumo) | Data |
|---|---|---|---|---|
| `art-src/gen/r2/climber32-attack-longsword-side-1.png` | `cinzel-climber32-attack-longsword-side-1-c2073a63e0d6` | flare edit + turnaround + folha | De lado: espada longa de duas mãos atrás do ombro, passo, varrida com arco creme grande, arco no máximo, acompanhamento, volta | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-longsword-down-1.png` | `cinzel-climber32-attack-longsword-down-1-aa8558da5065` | idem | De frente: espada no alto, desce pelo lado, varrida larga diante das pernas, crescente largo, acompanhamento, volta | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-longsword-up-2.png` | `cinzel-climber32-attack-longsword-up-2-374ad8e020b3` | idem | De costas: espada baixa, sobe pela direita, varrida por cima com arco acima do capuz, acompanhamento, volta | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-bow-side-1.png` | `cinzel-climber32-attack-bow-side-1-88ee522ed65e` | idem | De lado: arco de aço na mão esquerda; pega a flecha, encaixa, puxa até o rosto, segura, solta, baixa o arco. A flecha que sai voando no quadro 5 é apagada no script (o jogo cria a sua) | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-bow-down-2.png` | `cinzel-climber32-attack-bow-down-2-68295bd8c5d6` | idem | De frente: mesma sequência, flecha apontada para a câmera, clarão creme ao soltar | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-bow-up-2.png` | `cinzel-climber32-attack-bow-up-2-29cf1f86ee35` | idem | De costas: arco erguido acima do capuz, mesma sequência | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-axe-side-1.png` | `cinzel-climber32-attack-axe-side-1-92c7c1525483` | flare edit + turnaround + folha | De lado: machado de aço; ergue, machado alto atrás da cabeça, desce com arco creme vertical, bate no chão com faíscas, puxa de volta, volta à guarda | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-axe-down-1.png` | `cinzel-climber32-attack-axe-down-1-ee85ad4675ff` | idem | De frente: machado acima do capuz com as duas mãos, desce reto, bate no chão diante dos pés | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-axe-up-1.png` | `cinzel-climber32-attack-axe-up-1-f8ade21c8018` | idem | De costas: mesmo golpe, arco creme acima do capuz | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-spear-side-2.png` | `cinzel-climber32-attack-spear-side-2-dde6226f21c5` | idem | De lado: lança de aço na horizontal; recua, avança em estocada com rastro creme, extensão total, recolhe, guarda | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-spear-down-1.png` | `cinzel-climber32-attack-spear-down-1-104dc7c75fa6` | idem | De frente: lança em pé ao lado, ergue, estoca para baixo diante dos pés, recolhe | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-spear-up-2.png` | `cinzel-climber32-attack-spear-up-2-6fda54dab7f6` | idem | De costas: estoca para cima acima do capuz | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-dagger-side-1.png` | `cinzel-climber32-attack-dagger-side-1-84c5b86e8c9e` | idem | De lado, agachado: adaga curta; estocada no peito, recolhe, estocada na cintura, recolhe, guarda | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-dagger-down-1.png` | `cinzel-climber32-attack-dagger-down-1-57ba7ba52388` | idem | De frente: duas estocadas rápidas para baixo | 2026-11-14 |
| `art-src/gen/r2/climber32-attack-dagger-up-1.png` | `cinzel-climber32-attack-dagger-up-1-ca35aa47b5fb` | idem | De costas: duas estocadas rápidas ao lado dos ombros | 2026-11-14 |
| `art-src/gen/r2/icon-sword-midnight-2.png` | `cinzel-icon-sword-midnight-2-07bccae7de54` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayProps`, 1K, 2 variações (a 2 escolhida, lâmina mais limpa) | Espada curta de uma mão na diagonal, lâmina de aço negro com fio prateado fino dos dois lados, guarda de ferro negro com aro prateado, cabo de couro carvão, pomo redondo prateado, sobre magenta | 2026-11-15 |
| `art-src/gen/icons-weapons-sheet.png` | `cinzel-icons-weapons-sheet-741fdddc11c5` | `style/gpt-image-2.5/flare`, `cinzel-pixel`, `gameplayProps` | Grade 4x3 de armas na diagonal: espada de ferro, espada de cavaleiro, espada longa de aço, espada longa em brasa, machado de lenhador, machado de guerra duplo, lança de caçador, lança de dragoon, adaga, adaga curva de presa, arco curto, arco élfico | 2026-11-14 |
| `art-src/gen/icons-armor-sheet.png` | `cinzel-icons-armor-sheet-132525266767` | idem | Grade 3x2 de armaduras: túnica de pano, gibão de couro, cota de malha, escamas, placas, couro negro com roxo | 2026-11-14 |
| `art-src/gen/icons-helms-packs-sheet.png` | `cinzel-icons-helms-packs-sheet-edd4b815f870` | idem | Grade 3x2: capuz de pano, elmo de ferro com nasal, elmo com chifres, diadema com gema azul, mochila pequena, mochila média com cobertor | 2026-11-14 |
| `art-src/gen/icons-backpack-large.png` | `cinzel-icons-gear-sheet-a1199a2b8917` | idem | Pedido de 13 equipamentos numa grade 4x4; veio só a mochila grande (armação, saco de dormir, lanterna, panela), usada para `backpack_large` | 2026-11-14 |
| `art-src/gen/icons-materials-sheet.png` | `cinzel-icons-materials-sheet-f1dc43bd78b9` | idem | Grade 5x2 de materiais: gel de slime, núcleo de slime, lasca de pedra, olho de sentinela, carapaça, chifre de besouro, obsidiana, pó de brasa, pano espectral, cristal da torre. Só chifre, obsidiana, pano espectral e cristal seguem em uso | 2026-11-14 |
| `art-src/gen/icons-materials2-sheet.png` | `cinzel-icons-materials2-sheet-7756b25dd8f3` | idem | Grade 3x2 de materiais: minério de ferro, couro velho enrolado com fivela, madeira de freixo amarrada, quitina de besouro, minério de prata, carvão em brasa | 2026-11-14 |

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

## Equipamento: armas, roupas e ícones (Task E3)

### Camadas por arma

`game/assets/characters/climber/weapons/<tipo>.png`, com `<tipo>` em `sword`, `longsword`, `axe`, `spear`, `dagger`, `bow`. Mesma grade 8x13 de 32x32 do escalador, só os pixels da arma (e o arco claro do golpe nas linhas de ataque). Substitui `climber/weapon.png` na camada `weapon`; `sword.png` é uma cópia dela.

Tipos com pose de ataque própria trazem também `game/assets/characters/climber/attacks/<tipo>_body.png`, `<tipo>_hair.png` e `<tipo>_outfit.png`: 256x96, 8 colunas x 3 linhas, na ordem `attack_down`, `attack_up`, `attack_side` (6 quadros cada). Com essa arma equipada, o código troca as linhas 6, 7 e 8 das camadas `body`, `hair` e `outfit` por essas 3 linhas; a camada `weapon` já vem certa em `weapons/<tipo>.png`. Fora do ataque nada muda.

| Tipo | `weapons/<tipo>.png` | Pose de ataque própria (`attacks/<tipo>_*.png`) |
|---|---|---|
| `sword` | sim | não (usa as linhas do escalador) |
| `longsword` | sim | sim: varrida larga com as duas mãos |
| `bow` | sim | sim: puxa a corda e solta |
| `axe` | sim | sim: golpe de cima até o chão |
| `spear` | sim | sim: estocada |
| `dagger` | sim | sim: duas estocadas rápidas |

Cada item de arma tem a própria folha `weapons/<id>.png` (mesma grade, mesmos quadros da folha do tipo, nas cores e na forma do ícone). O jogo usa `weapons/<id>.png`, senão `weapons/<tipo>.png`, senão `climber/weapon.png` (`LayeredSprite.weapon_sheet_path`). As poses de ataque continuam por tipo.

Camada `offhand` (Lâminas Gêmeas): `offhand/<id>.png` da espada na mão secundária, por cima de tudo de frente e de costas, atrás do corpo de lado. Num golpe da mão secundária as camadas `weapon` e `offhand` trocam de folha (a camada `weapon` usa `weapons/<id da secundária>.png`, a `offhand` usa `offhand/<id da principal>.png`) e, de frente e de costas, o sprite inteiro espelha, para o golpe sair do outro lado.

Armas guardadas (`LayeredSprite.set_sheathed`, ligado na cidade pelo `Player.armed = false` e no guarda-roupa): parado, andar e rolamento usam `weapons/<id>_sheathed.png` e `offhand/<id>_sheathed.png`. Arma de costas (espada longa, machado, lança, arco) vai atrás do corpo na vista de frente.

### Roupas visuais

`game/assets/characters/climber/outfits/<id>/hair.png` e `outfit.png` (8x13 cheio), com `<id>` em `starter`, `casaco_longo`, `cavaleiro_leve`, `tunica_ferreiro`, `manto_mago`, `sobretudo_noite` e `traje_sombra`. Para cada tipo com pose de ataque própria há também `outfits/<id>/attacks/<tipo>_hair.png` e `<tipo>_outfit.png` (8x3, mesmas linhas). Com a roupa `<id>` e a arma `<tipo>`, as camadas ficam:

- `body`: `climber/body.png`, com as linhas de ataque de `attacks/<tipo>_body.png` se existir;
- `hair` e `outfit`: `outfits/<id>/<camada>.png`, com as linhas de ataque de `outfits/<id>/attacks/<tipo>_<camada>.png` se existir;
- `weapon`: `weapons/<id da arma>.png` (senão `weapons/<tipo>.png`).

A roupa não muda o corpo nem a arma, então qualquer roupa combina com qualquer arma em todo quadro.

Cada roupa tem a sua silhueta (`build_outfit_shapes.py`). Todo quadro começa da roupa inicial repintada e ganha formas tiradas das máscaras daquele quadro (calça, botas, tronco, mãos), então tudo continua alinhado com o corpo, as armas, as armaduras e as mochilas:

- `casaco_longo`: casaco até os pés, fechado com uma costura na frente e fenda atrás;
- `cavaleiro_leve`: tabardo carmim reto até os joelhos (frente e costas), com barra rosada, e ombreiras prateadas 1 px para fora dos ombros;
- `tunica_ferreiro`: túnica bege até o meio da coxa e avental de couro até os joelhos (de frente e de lado);
- `manto_mago`: manto até o chão, alargando para baixo, barra verde-água, mangas largas sobre os pulsos;
- `sobretudo_noite`: sobretudo de couro negro azulado até 2 linhas acima da sola, aberto na frente (a abertura alarga até a barra e mostra as pernas, com friso prateado nas bordas e na barra), fenda nas costas; de lado a cauda abre para trás conforme a passada. A barra atrasa 1 px em relação às pernas do quadro anterior, então balança no passo; no rolamento saem caudas atrás da bola e na morte a aba se espalha no chão;
- `traje_sombra`: jaqueta negra justa, gola alta de frente, capa curta no ombro (esquerdo na tela de frente, direito de costas, atrás de lado) até o quadril, com um fio vermelho-escuro na barra, balançando no passo; calça grafite; o capuz vira cabelo curto espetado (tufos dos lados, franja recortada).

O preto usa rampas cinza-azuladas com contorno de 1 px e realce claro na borda esquerda, então lê no chão escuro dos andares. Armaduras ficam por cima do tronco; saias, caudas e capas continuam visíveis.

### Armaduras, elmos e mochilas

`game/assets/characters/climber/gear/<id>.png` (8x13 cheio), um por item `armor_*`, `helm_*` e `backpack_*` do catálogo. Para cada tipo com pose de ataque própria há também `gear/attacks/<tipo>_<id>.png` (8x3, mesmas linhas). O jogo desenha `body`, `hair`, `outfit`, `armor`, `backpack`, `helm`, `weapon`; `armor` e `helm` só aparecem com "Mostrar armadura" ligado no guarda-roupa, a mochila aparece sempre.

As cores vêm do ícone do item: k-means nos pixels opacos do ícone (sem o contorno), em rampa do escuro ao claro (`artlib.kmeans`). Nas armaduras a rampa termina no realce do ícone (a média do décimo mais claro; nas de metal puxado para o branco por `shine`, o brilho que um ícone de 16 px não tem espaço para mostrar), e os tons da jaqueta vão para ela por posto de brilho espalhado para cima (`lift`), então os tons claros caem no realce e a armadura lê como o ícone: pano bege-claro, malha e placa prateadas. Elmos e cinto usam casamento de histograma (`artlib.quantile_index`).

Só a camada `backpack` desenha mochila. `split_layers.py` tira a mochila da roupa inicial de todo quadro (de lado, a parte de trás do tronco; de costas, o meio das costas e a aba em `hair.png`; no rolamento e na morte, uma caixa por quadro em `PACK_BOXES`; de frente, nada) e as roupas e armaduras saem dessas camadas, então ficam com um buraco ali. `build_backpacks.py` preenche esse buraco em todo quadro com os mesmos pixels repintados nas cores do item e, de costas e de lado nas linhas em pé, desenha por cima a mochila do tamanho do item; de frente desenha as alças e o que sobra para fora do corpo, de toda armadura e de todo elmo.

Os cabos do machado e da lança nas poses de ataque também saem das tiras (`split_layers.py`: a maior reta fina de pixels cor de madeira saindo da cabeça da arma) e vão para a camada da arma de cada item.

`build_gear.py` tira cada quadro das camadas da roupa inicial no mesmo quadro (as outras roupas são repinturas dela, com os mesmos pixels), então armadura e elmo encaixam em qualquer roupa e arma:

- armadura: os pixels do tronco de `outfit.png` (o cinto acima da calça entra, a calça e as abas de roupa não), repintados na rampa da armadura com um desenho próprio. O contorno escuro continua o da roupa por baixo. As formas do ícone ganham contorno novo: saia abaixo do cinto (`skirt`: pano 3 linhas, couro 2, malha 3, escamas 4, faldas de placa 2, sombra 3 com barra recortada), ombreiras das placas, abas de couro nos ombros, espinhos na sombra;
- elmo: os pixels do capuz e do cabelo visíveis em `hair.png` (onde `outfit.png` não cobre), repintados, então o cabelo não aparece por baixo. Chifres (2 px na base) e a faixa do diadema são desenhados por cima. O capuz de viagem fica 1 px maior que o capuz (no alto e dos lados), o gorro de ferro tem a aba 1 px para fora. O diadema deixa o capuz e o cabelo à vista. As mochilas já tinham o tamanho do ícone (pequena, média com cobertor, grande com rolo) e não mudaram.

### Ícones e molduras de raridade

Ícones de 16x16 em `game/assets/items/<id>.png`, fundo transparente. As molduras de raridade são arquivos separados, não embutidos no ícone: `game/assets/items/frames/common.png` (branca), `rare.png` (azul) e `epic.png` (roxa), 18x18, centro transparente. Desenhe a moldura e o ícone por cima com 1 px de recuo (ícone em (1, 1) da moldura).

Ids (o catálogo da Task E1 usa os mesmos):

- Armas: `sword_iron`, `sword_knight`, `longsword_steel`, `longsword_ember`, `axe_woodcutter`, `axe_war`, `spear_hunter`, `spear_dragoon`, `dagger_rogue`, `dagger_twin_fang`, `bow_short`, `bow_elven`
- Armaduras: `armor_cloth`, `armor_leather`, `armor_chain`, `armor_scale`, `armor_plate`, `armor_shadow`
- Capuzes e elmos: `helm_hood`, `helm_iron`, `helm_horned`, `helm_circlet`
- Mochilas: `backpack_small`, `backpack_medium`, `backpack_large`
- Materiais: `mat_iron_ore`, `mat_old_leather`, `mat_ash_wood`, `mat_chitin`, `mat_beetle_horn`, `mat_silver_ore`, `mat_coal`, `mat_obsidian`, `mat_specter_cloth`, `mat_tower_crystal`
- Roupas: `outfit_starter`, `outfit_casaco_longo`, `outfit_cavaleiro_leve`, `outfit_tunica_ferreiro`, `outfit_manto_mago`, `outfit_sobretudo_noite`, `outfit_traje_sombra`
- Relíquias (já existiam): `heavy_blade`, `light_boots`, `stone_heart`, `fang`, `wind_cape`, `cracked_hourglass`, `spark`, `glass_shield`

Para refazer tudo: `build_weapons.py`, depois `split_layers.py` (com `--refresh` se `build_climber.py` ou `build_weapons.py` refizeram as camadas), depois `build_weapon_items.py`, depois `build_offhand.py`, depois `build_outfits.py`, depois `build_outfit_shapes.py`, depois `build_gear.py`, depois `build_backpacks.py`, depois `build_items.py` (os ícones das roupas saem das folhas das roupas), todos com `--force` só quando for para sobrescrever.
| `game/assets/rooms/decor.png` | Gerado por IA (gpt-image-2.5 sunburst edit) + ajuste por script | `art-src/gen/decor-sheet.png` (`cinzel-decor-sheet-town-1`, 4x3 objetos no magenta, repintados no estilo de `town-props.png`) por `build_decor.py`: chave magenta, redução por área, até 64 cores, alfa binário | 2026-11-14 |
| `game/assets/audio/sfx/<id>.ogg` (28 efeitos: `swing_light`, `swing_heavy`, `bow_shot`, `hit`, `crit`, `player_hurt`, `enemy_die`, `boss_roar`, `coin`, `item_pickup`, `ui_open`, `ui_close`, `ui_move`, `ui_confirm`, `step`, `roll`, `door_open`, `door_locked`, `chest_open`, `heal_loop`, `buy`, `sell`, `forge`, `teleport`, `stairs`, `special_charge`, `special_release`, `shockwave`) | Gerado por IA (ElevenLabs/MiniMax) | `generate_sfx` (ElevenLabs Sound Effects V2, projeto `asset-gen`, nomes `cinzel-sfx-<id>`), convertidos com ffmpeg: silêncio cortado nas pontas (-50 dB), pico normalizado em -3 dB, Ogg Vorbis. `heal_loop` em laço | 2026-11-14 |
| `game/assets/audio/music/town.ogg`, `tower.ogg`, `boss.ogg` | Gerado por IA (ElevenLabs/MiniMax) | `generate_music` (MiniMax Music 2.6, instrumental, projeto `asset-gen`, nomes `cinzel-music-<id>`): cidade (alaúde, aconchegante), torre (cordas graves e percussão, tensa), chefe (intensa). Cortadas em 88 s com fade de 2 s no fim, loudness ~-15 LUFS (loudnorm), Ogg Vorbis em laço | 2026-11-14 |
