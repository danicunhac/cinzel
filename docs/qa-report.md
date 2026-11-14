# QA: sensação de combate, áudio e decoração (Task P1)

Data: 2026-11-14. Godot 4.7.2, macOS.

Duas rodadas por script (`game/tools/qa_autopilot.gd`) com entrada real (ações de mover, atacar, rolar, interagir), caminho por AStarGrid2D sobre o que bloqueia de verdade (paredes, colunas, caixotes, decoração sólida) e um Logger que conta todo erro do motor:

```
godot --headless --fixed-fps 60 --path game -s res://tools/run_node.gd -- --node=res://tools/qa_autopilot.gd --mode=win
godot --headless --fixed-fps 60 --path game -s res://tools/run_node.gd -- --node=res://tools/qa_autopilot.gd --mode=die
```

No modo `win` o robô começa com espada de cavaleiro, cota de malha e elmo de ferro (kit de quem já forjou na cidade). Com o kit inicial ele morre no andar 1 na maior parte das vezes: ele não esquiva bem (rola só em ataque telegrafado e no anel do chefe).

## Vencer o chefe do andar 1 (`--mode=win`)

3 execuções depois das correções: 2 completas sem nenhuma falha, 1 morte na sala 0 (`f1_anel`, quatro inimigos com investida; limite do robô, não do jogo).

| Verificação | Resultado |
|---|---|
| Masmorra carrega do teleporte da cidade | PASS |
| Cada sala: inimigos mortos, porta de saída abre, próxima sala carrega (5 ou 6 salas por andar) | PASS |
| Baú abre com E, item entra no inventário | PASS |
| Música da torre nas salas, do chefe na sala do chefe, volta à da torre quando o chefe cai | PASS |
| Andar 1 marcado como vencido, portais aparecem | PASS |
| Portal "Cidade" leva à cidade, música da cidade toca | PASS |
| Ouro ganho (93 a 117 por andar), moeda voa até o contador | PASS |
| Hit-stop acontece (time_scale mínimo 0,02) e o tempo volta a 1 no fim | PASS |
| Números de dano aparecem (51 a 61 por andar) | PASS |
| Decoração sólida nunca fecha caminho (o robô chega a todo inimigo, baú e porta) | PASS |
| Nenhum erro do motor | PASS (depois das correções abaixo) |

## Morrer (`--mode=die`)

| Verificação | Resultado |
|---|---|
| Herói morre na primeira luta (pisca vermelho, tremor, coração do HUD pulsa a cada dano) | PASS |
| Tela de fim de jogo aparece | PASS |
| Música para na morte | PASS |
| Run zera (ouro 0, tutorial de novo) | PASS |
| time_scale volta a 1 depois do hit-stop da morte | PASS |
| Nenhum erro do motor | PASS |

## Problemas achados e corrigidos nesta tarefa

1. Hit-stop preso: o fim do hit-stop comparava o relógio de parede, e com quadros rápidos (`--fixed-fps`) o tempo ficava em 0,02 para sempre e a tela de fim de jogo nunca vinha. Agora conta os hit-stops ativos (o último a acabar devolve o tempo) e a rede de segurança usa o passo sem escala.
2. Erro do motor ao matar o último inimigo de uma sala com baú: o baú (corpo e área) entrava na física durante o callback do golpe. Agora entra com `call_deferred` (`room.gd`). Erro anterior a esta tarefa.
3. Mesmo erro com os portais do chefe (`dungeon.gd`): agora entram com `call_deferred`. Erro anterior a esta tarefa.
4. Trocar de cena ao tocar o portal removia corpos dentro do callback de física (`portal.gd`): o sinal `used` agora sai adiado. Erro anterior a esta tarefa.

## Pendências (não corrigidas)

- O kit inicial contra o andar 1 é duro para quem não rola: o robô sem esquiva perde com frequência. Vale olhar o balanço com gente jogando.
- O Godot avisa "ObjectDB instances leaked" e "resources still in use" ao fechar, nos testes e nas capturas. Não quebra nada.
- As músicas saíram de 131 a 144 s do MiniMax e foram cortadas em 88 s com fade de 2 s; o laço tem uma pausa curta no ponto de volta. A loudness ficou entre -14 e -15 LUFS (alvo -16).
- Os sliders de volume da pausa usam o estilo padrão do tema (cinza), sem moldura pixel art.
