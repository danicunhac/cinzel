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
