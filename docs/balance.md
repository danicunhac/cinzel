# Balanço do andar 1

Data: 2026-11-14. Objetivo: quem joga bem com o kit inicial (espada de ferro, sem armadura), rolando nos avisos vermelhos e curando parado, vence o andar 1 com o chefe na maioria das vezes, e quem não rola morre.

## Como medir

O robô de QA (`game/tools/qa_autopilot.gd`) agora joga como uma pessoa razoável:

- rola nos avisos vermelhos: mordida do slime, linha da investida do besouro, tiro da sentinela, mordida do chefe e anel do chefe (sai do anel durante o aviso; se não dá, rola para dentro quando o anel chega);
- reage a cada aviso só depois de um tempo de reação de 0,15 a 0,35 s e deixa passar uma parte deles (`--skill=0.8`: reage a 80%);
- com pouca vida (menos de 35%) se afasta e fica parado para curar; se a sala não deixa, volta a lutar depois de 6 s;
- entre salas pega os materiais do chão e cura até encher.

```
godot --headless --fixed-fps 60 --path game -s res://tools/run_node.gd -- --node=res://tools/qa_autopilot.gd --mode=win [--kit=starter|forged] [--no-dodge] [--skill=0.8]
```

Cada execução imprime uma linha `RESULT` com o resultado, o relógio na entrada do chefe, o nível, a causa da morte, o dano levado por fonte e os materiais. Os tempos são do relógio do jogo, não do relógio de parede (headless roda bem mais rápido que o tempo real).

## Antes do ajuste

Com os números antigos o andar 1 era curto e fácil demais:

| Robô | Vitórias | Chefe aos | Fim do andar |
|---|---|---|---|
| Kit inicial, `--skill=0.8` | 5/5 | 55 a 84 s (nível 0 a 1) | 66 a 106 s |
| Kit inicial, sem rolar | 3/5 (1 morte, 1 travou) | 55 a 83 s | 77 a 103 s |

O chefe caía em 9 a 13 s. Sem rolar dava para vencer, então rolar e curar não importavam.

## O que mudou

| Número | Antes | Depois | Por quê |
|---|---|---|---|
| Slime (`crawler.tscn`) vida / dano | 30 / 10 | 45 / 13 | Morria num só combo. Agora são 4 a 5 golpes e a mordida dói o bastante para quem não rola. |
| Sentinela (`shooter.tscn`) vida / dano | 20 / 8 | 30 / 11 | Mesma proporção; o tiro passa a valer uma rolagem. |
| Besouro (`charger.tscn`) vida / dano | 40 / 15 | 60 / 19 | Mesma proporção; a investida tem aviso longo (0,6 s), então pode doer. |
| Chefe grande `HP_MULT` (`boss_big.gd`) | 8 | 12 | O chefe do andar 1 caía em 10 s. Agora a luta dura 23 a 26 s para o robô (vida 540 no nível 0, 594 no nível 1). |
| Chefe grande `SHOCK_INTERVAL` | 5,0 s | 4,5 s | Um anel a mais por luta mais longa; o aviso continua de 0,8 s. |
| Cura parado `heal_per_sec` (`player_stats.gd`) | 8/s | 6/s | Curar custa mais tempo de relógio, que é o pilar do jogo. Encher 100 de vida leva 1,5 + 16,7 s. |
| Mercado `BUY_MARKUP` (`market.gd`) | 2,0 | 1,6 | A primeira peça rara cabe no bolso depois de umas 2 descidas (ver abaixo). Continua acima do bônus de 1,5 do item procurado, então comprar e revender nunca dá lucro. |

Ficaram como estavam, depois de medir:

- Inclinação do relógio: +10% de vida e +8% de dano por minuto, +1 inimigo do nível 5. Não estava quebrada; nada muda no GDD.
- Espada de ferro: 10 de dano. Com os inimigos mais fortes, ela ainda mata um slime em 4 a 5 golpes no nível 1.
- Rolagem: 0,3 s de invencibilidade. Dá para passar pelo anel e pelas investidas sem folga extra.
- Mordida e investida do chefe: avisos de 0,45 s e 0,7 s, sem mudança.
- Chance de material por inimigo: 50%. Toda vitória terminou com material para pelo menos 1 receita da forja (o couro quase sempre) e 87 a 116 de ouro, que paga uma receita de 30 a 40.

## Depois do ajuste

Kit inicial, `--skill=0.8`, 10 execuções seguidas:

| | Resultado |
|---|---|
| Vitórias | 9/10. A outra parou na sala do chefe sem morrer (robô travado, não repetiu em mais 35 execuções). |
| Chefe aos | 85 a 112 s, média 96 s (nível 1 em todas) |
| Chefe morto aos | 110 a 138 s |
| Fim do andar (com cura e portal) | 122 a 151 s |
| Dano levado por andar | 150 a 250, mais da sentinela e do slime |

Mais 35 execuções iguais: 34 vitórias, 1 morte (anel do chefe).

Outros robôs:

| Robô | Vitórias | Mortes |
|---|---|---|
| Kit inicial, sem rolar (`--no-dodge`) | 0/5 | 5 pelo slime, nas salas 0, 1, 2, 3 e 4 |
| Kit inicial, `--skill=0.6` | 5/5 | |
| Kit inicial, `--skill=0.4` | 2/5 | 2 pela mordida do chefe, 1 pelo slime |
| Kit forjado (espada do cavaleiro, cota de malha, elmo de ferro) | 3/3 | chefe aos 89 a 102 s |

Leitura: rolar decide a descida. Quem não rola morre no andar 1; quem rola bem vence quase sempre; quem rola mal perde para o chefe.

## Tempo e relógio

O robô chega ao chefe com cerca de 1 min 36 s de relógio e fecha o andar em pouco mais de 2 min. Ele não explora, não hesita e mira perfeito. Uma pessoa competente deve levar 2 a 3 vezes isso, ou seja, chega ao chefe no nível 3 a 4 e fecha o andar em 5 a 7 min, mais 1 a 1,5 min do tutorial na primeira descida. Isso não foi medido com gente.

Se a demo mostrar que o andar ficou curto, a alavanca mais barata é a vida dos inimigos (`base_hp` nas cenas) e o `HP_MULT` do chefe; o dano decide quem morre e deve mudar menos.

## Mercado

Raras só aparecem na loja depois de abrir o andar 2 (vencer o primeiro chefe). Preço de compra (antes → depois):

| Item raro | Antes | Depois |
|---|---|---|
| Relíquia rara mais barata (Lâmina Pesada, Ampulheta Rachada) | 90 | 72 |
| Elmo de Chifres, Mochila Média | 150 | 120 |
| Cota de Malha | 166 | 133 |
| Espada do Cavaleiro | 180 | 144 |

Uma descida vitoriosa rende 87 a 116 de ouro no chão, mais a venda de materiais e do item do baú. Com isso a relíquia rara cabe depois da primeira descida e a primeira peça rara de equipamento depois da segunda. A venda não mudou (preço do item × fator de oferta e procura).

# Balanço dos andares 2 e 3

Data: 2026-11-14 (Task 13). Objetivo: com o equipamento que um jogador plausivelmente tem ao chegar (o kit inicial mais o que caiu e uma peça forjada entre os andares), o robô com `--skill=0.8` vence cada andar em pelo menos 3 de 5 descidas, com o relógio subindo de nível a cada andar.

## Como medir

O robô ganhou duas opções:

- `--floors=3`: joga do andar 1 ao 3 sem parar. Depois de cada chefe (menos o último) pega o equipamento do chão, faz a parada na cidade de quem volta (forja a primeira receita que consegue pagar, veste a arma, armadura e elmo mais caros que carrega), cura parado e entra no portal "Andar N+1". O relógio fica igual ao de passar pela cidade, onde ele para.
- `--start=2 --kit=f2` / `--start=3 --kit=f3`: começa direto no andar, com o relógio em 150 s / 330 s (o que o robô mostra ao chegar lá) e um kit plausível: armadura de couro e elmo de ferro no andar 2; espada do cavaleiro, couro e elmo de ferro no andar 3.

Ele também anda em volta das grelhas de brasa, sai de cima de uma que acende, rola na investida do chefe final, larga o item novo quando a mochila cheia abre a troca e não pisa nos portais por acidente.

```
godot --headless --fixed-fps 60 --path game -s res://tools/run_node.gd -- --node=res://tools/qa_autopilot.gd --mode=win --floors=3 --skill=0.8
godot --headless --fixed-fps 60 --path game -s res://tools/run_node.gd -- --node=res://tools/qa_autopilot.gd --mode=win --start=2 --kit=f2 --floors=2 --skill=0.8
```

A linha `FLOORS` diz, por andar, se venceu (relógio na entrada e na morte do chefe) ou em que sala morreu, o que forjou e o equipamento final.

## Antes do ajuste

Os inimigos não tinham multiplicador por andar: andar 2 e 3 usavam a vida e o dano das cenas, só com o relógio por cima. Com isso:

| Robô | Andar 2 | Andar 3 |
|---|---|---|
| `--start` com o kit do andar | 1/8 | 0/8 (mortes nas salas 0 a 2) |
| `--floors=3` | 4 de 9 que chegaram | 1 de 1 |

Quem mata é a sentinela: 200 a 430 de dano por andar 2. O andar 2 tem mais sentinelas (todas as salas têm pelo menos uma, quase todas três), e no andar 3 o relógio já está no nível 5 (+50% de vida, +40% de dano e um inimigo a mais por sala).

## O que mudou

Multiplicador por andar em `game/logic/difficulty.gd` (`FLOOR_HP_MULT`, `FLOOR_DMG_MULT`), aplicado a todo inimigo e chefe por cima do relógio. As cenas dos inimigos não mudaram.

| Andar | Vida antes → depois | Dano antes → depois |
|---|---|---|
| 1 | 1,0 → 1,0 | 1,0 → 1,0 |
| 2 | 1,0 → 0,85 | 1,0 → 0,7 |
| 3 | 1,0 → 0,85 | 1,0 → 0,7 |

O multiplicador abaixo de 1 compensa o relógio, não o substitui: o robô chega ao andar 2 no nível 1 a 2 e ao chefe dele no nível 3 a 5; chega ao andar 3 no nível 3 a 6 e ao chefe final no nível 6 a 9. Na prática uma sentinela do andar 2 no nível 4 tira 11 × 1,32 × 0,7 ≈ 10 por tiro (no andar 1, nível 1: 12), e há mais delas. Valores intermediários testados: 0,85/0,8 (andar 2) e 0,75/0,7 (andar 3) deixaram o andar 2 em 3/8 e o chefe final caindo em 12 s; 0,95/0,8 no andar 3 deixou o andar 3 em 0/8 com o kit de início.

Grelha de brasa: 10 de dano por queima, com o mesmo multiplicador do andar 3 e do relógio. Gelo: só deixa o andar 20% mais lento, sem dano.

## Depois do ajuste

`--floors=3`, `--skill=0.8`, 32 descidas:

| Andar | Vitórias | Chefe aos | Nível no chefe |
|---|---|---|---|
| 1 | 31/32 | 63 a 121 s | 1 a 2 |
| 2 | 24 de 29 que chegaram (83%) | 212 a 356 s | 3 a 5 |
| 3 | 15 de 24 que chegaram (63%) | 366 a 539 s | 6 a 9 |

Com o kit de início do andar: andar 2 8/12, andar 3 9/10. O andar 3 com a espada do cavaleiro é bem mais fácil que o andar 3 de quem chega com a espada de ferro (63%), então a forja entre os andares pesa.

Mortes: no andar 2, a sentinela nas salas e a investida do chefe; no andar 3, os slimes invocados pelo chefe final e as sentinelas. As grelhas tiram 8 a 26 por andar 3, nunca decidiram uma descida.

O chefe final cai em 11 a 25 s (o do andar 1 leva 23 a 26 s). Se parecer rápido demais com gente, a alavanca é a vida dele em `boss_final.tscn`, não o multiplicador do andar.

## Materiais e forja

Conferido nas descidas: os inimigos do andar 2 deixam carapaça, chifre e olho de sentinela, os do andar 3 pó de brasa, obsidiana e tecido espectral (`LootTable.ENEMY_MATERIALS`); o robô forjou couro, elmo de chifres, espada do cavaleiro e cota de malha entre os andares. As receitas abrem com os chefes como antes (`test_floors.gd`). Nada de receitas ou materiais mudou aqui.
