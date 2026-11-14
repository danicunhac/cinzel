# Cinzel: roteiro da apresentação

Apresentação técnica em 21/11. Formato: 6 a 10 min, alvo de 8 min. Obrigatório: mostrar o jogo rodando ou o projeto aberto no Godot.

Nota para confirmar: o formato pede pelo menos 2 apresentadores. Daniel apresenta sozinho com OK do professor. Confirmar por escrito antes do dia 21 e guardar a resposta.

O roteiro está escrito para uma pessoa falando. Frases curtas. O texto em itálico é a fala. O resto é indicação de tela.

## Tempos

| Seção | Tempo | Acumulado |
|---|---|---|
| 1. O que é o jogo | 0:20 | 0:20 |
| 2. A ideia: tempo é custo | 0:40 | 1:00 |
| 3. Demo ao vivo | 3:00 | 4:00 |
| 4. Decisões de design | 1:00 | 5:00 |
| 5. Implementação técnica | 1:00 | 6:00 |
| 6. Pipeline de arte | 0:50 | 6:50 |
| 7. Design de níveis | 0:30 | 7:20 |
| 8. Áudio | 0:15 | 7:35 |
| 9. Processo | 0:15 | 7:50 |
| 10. Próximos passos e fechamento | 0:20 | 8:10 |

Se a demo estourar, corte a seção 8 para uma frase e a 9 para uma frase.

## Antes de começar

- Jogo aberto na tela de título, em tela cheia, volume ajustado. Godot aberto em outra janela com `game/project.godot` carregado, como plano B.
- Slides com os 8 prints da lista no fim, prontos em outra janela.
- Rodar uma vez antes e deixar a cidade no estado inicial (jogo novo).
- Controles na ponta da língua: WASD move, J ataca (segurar J faz o especial), Espaço rola, E interage, Q segurado sai, Tab mochila.

## 1. O que é o jogo (0:20)

*Cinzel é um roguelike de ação 2D, visto de cima. Você sobe uma torre, volta à cidade para vender o saque e se equipar, e sobe de novo. Feito em Godot 4.7.*

## 2. A ideia: tempo é custo (0:40)

*A frase do jogo é: o que custa caro é o tempo, não a vida.*

*Dentro da torre existe um relógio. A cada minuto, os inimigos ficam mais fortes: 10% mais vida e 8% mais dano. Na cidade e nos menus o relógio pausa.*

*Curar também custa tempo. Só cura quem fica parado, 1,5 segundo, e depois recupera 6 de vida por segundo. Ficar mais rende mais saque, mas cada minuto deixa a torre mais dura.*

*E morrer perde tudo: mochila, equipamento, ouro e andares liberados. O que protege você é sair a tempo.*

## 3. Demo ao vivo (3:00)

Rota exata. Falar pouco, deixar o jogo mostrar.

1. **Título (0:10).** Mostrar logo e tela. Apertar para começar.
   *Essa é a tela de título. Começo um jogo novo.*
2. **Cidade (0:20).** Andar pela rua. Apontar moradores, fumaça da forja, luz das lanternas.
   *A cidade é uma tela só. Os moradores andam e falam em balões curtos. O relógio está parado aqui.*
3. **Loja, forja, guarda-roupa (0:40).**
   - Loja: abrir com E. Mostrar preços e a seta de tendência. *O preço muda com oferta e procura. A loja paga mais pelo que está em falta, e menos pelo que eu vendi demais.*
   - Forja: abrir com E. Mostrar uma receita. *O ferreiro forja armas e armaduras com material e ouro.*
   - Guarda-roupa: trocar de roupa. *As roupas são só visuais, estilo SAO. Não mudam número nenhum.*
4. **Andar 1, tutorial (0:25).** Entrar pelo cristal de teleporte. Primeiras salas.
   *O tutorial não tem texto longo. Cada sala ensina uma coisa: mover e atacar, rolar, curar parado.*
5. **Combate com 2 armas e especial (0:50).**
   - Atacar com a espada de ferro, combo de 3 golpes.
   - Rolar num aviso vermelho. *Todo ataque inimigo avisa em vermelho antes. Rolar dá 0,3 s de invencibilidade.*
   - Trocar de arma pela mochila (Tab). Atacar com a segunda arma.
   - Segurar J por meio segundo e soltar o especial. *Segurar o ataque carrega um golpe especial, cada arma tem o seu.*
6. **Saque (0:15).** Abrir um baú com E, pegar o item do chão. Mostrar o aviso de loot.
   *Inimigos derrubam material. Baús derrubam equipamento. Tudo vai para a mochila.*
7. **Sair com Q (0:10).** Segurar Q por 2 s, voltar à cidade.
   *Segurar Q tira você da torre com tudo o que carrega. Cancela se eu levar dano.*
8. **Vender (0:10).** Na loja, vender o saque. Mostrar o ouro subindo.
9. **Chefe (0:10 ao vivo, resto em print se faltar tempo).** Mostrar a entrada do chefe do andar 1: slime gigante com anel de choque. Só mostrar o aviso do anel e a barra de vida.
   *O chefe do andar 1 é um slime gigante com onda de choque.*

Se o chefe não couber nos 3 minutos, mostrar `task10-boss.png` e `task11-shockwave-warning.png` e seguir.

## 4. Decisões de design (1:00)

*O loop é: cidade, torre, saque, cidade. Vencer o chefe libera o próximo andar no teleporte.*

*Algumas decisões que eu tomei e por quê:*

- *Relógio só dentro da torre. A dificuldade vira o jogador decidir quando sair.*
- *Cura só parado. Curar custa relógio, então curar é uma escolha e não um botão.*
- *Morte perde tudo. Sem baú de casa. Isso dá peso para o botão de sair.*
- *Volta a pé. As salas ficam ligadas nos dois sentidos, com escada para descer. Q é o atalho.*
- *Mercado com oferta e procura. Comprar e revender nunca dá lucro, porque a compra custa 1,6 vez o preço base.*
- *Roupas só visuais, estilo SAO. A aparência vem da roupa, os números vêm do equipamento.*

*Eu medi o balanço com um robô que joga: rola nos avisos, cura parado. Com o kit inicial ele vence o andar 1 em cerca de 9 de 10 tentativas. Sem rolar, perde sempre. Ou seja, rolar decide a descida.*

## 5. Implementação técnica (1:00)

Mostrar o Godot aberto, painel de arquivos.

*Godot 4.7, GDScript tipado.*

*A lógica do jogo é pura, sem nós. Fica em `game/logic/`: inventário, mercado, forja, relógio, regra de cura, tabela de saque. Isso permite testar sem abrir o jogo. Hoje são 261 testes e todos passam. Rodam em modo headless por linha de comando.*

*Três autoloads: `Game` guarda o estado da run. `Fx` cuida de hit-stop, tremor de tela, números de dano e partículas. `Sfx` toca música e efeitos.*

*As salas são geradas a partir de layouts em ASCII, 30 por 16 tiles. Um script lê o layout, valida que o chão é alcançável e gera a cena. Por cima do layout entra uma sala pintada. A colisão vem do layout, não da pintura.*

*O herói é um sprite em camadas: corpo, cabelo, roupa e arma. Trocar roupa ou arma troca a camada. Por isso cada peça precisa da sua folha, de 32 px.*

## 6. Pipeline de arte (0:50)

*Comecei escolhendo duas artes-chave: uma sala da torre e uma rua da cidade. Fixei um preset de estilo, `cinzel-pixel`, com paleta limitada.*

*Toda arte gerada usa esse preset, via gerador de IA. Depois, scripts em Python limpam: reduzem para a grade, limitam a 32 cores, alinham os pés na mesma linha. Um script de checagem reprova folha fora do padrão.*

*As salas seguem um processo: desenho o layout em blocos, a IA pinta por cima com a arte-chave como referência, e um script confere se a pintura bate com a colisão.*

*O personagem é a exceção. O escalador foi gerado como referência e eu estou redesenhando à mão, no Pixelorama, seguindo o guia que escrevi. A versão que vai na build é a desenhada por mim.*

Nota: antes do dia 21, mostrar o sprite autoral rodando no jogo (idle e andar, pelo marco de 20/11). Se não estiver pronto, mostrar o guia, a referência e o rascunho, e dizer o estado exato. Não dizer que está pronto se não estiver.

## 7. Design de níveis (0:30)

*O tutorial não usa texto longo. Três salas, uma mecânica por sala.*

*Todo ataque inimigo tem um aviso vermelho antes: mordida do slime, linha da investida do besouro, tiro da sentinela, anel do chefe. O jogador aprende a ler o vermelho.*

*Cada andar sorteia de 4 a 5 salas de um conjunto de modelos, mais o chefe no fim. Cada sala tem um baú e uma porta que só abre quando os inimigos morrem.*

## 8. Áudio (0:15)

*28 efeitos e 3 músicas: cidade, torre e chefe. Tudo gerado por IA e tratado com ffmpeg: corte de silêncio, volume normalizado, laço. O jogo funciona sem som, mas o som dá peso ao golpe.*

## 9. Processo (0:15)

*Trabalhei com um quadro de tarefas no GitHub Projects. Cada tarefa passou por revisão antes de entrar no ramo principal. O link está na ficha.*

Confirmar que o quadro existe e está público antes do dia 21. Colocar o link na ficha.

## 10. Próximos passos e fechamento (0:20)

*Para a entrega, faltam os andares 2 e 3 completos, todas as armas, o ferreiro com todas as receitas, o personagem redesenhado em todas as animações e a build para Windows.*

*Depois da entrega: preço livre com clientes, estilo Moonlighter.*

*Obrigado. Posso mostrar mais alguma coisa no Godot.*

## Plano B se a demo falhar

1. Abrir o Godot com `game/project.godot`. Se o jogo não rodar, mostrar a árvore de arquivos e rodar os testes no terminal:
   `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s res://tests/run_tests.gd`
   Resultado esperado: `PASS 261 / FAIL 0`.
2. Passar para os slides com os prints e seguir a mesma ordem da demo.
3. Frase de transição: *O jogo não abriu agora. Vou mostrar as capturas da mesma rota.*

### 8 prints para os slides

Pasta: `.superpowers/sdd/2026-11-14-cinzel/shots/`

| # | Arquivo | Mostra |
|---|---|---|
| 1 | `task12-title.png` | Tela de título |
| 2 | `task12-town.png` | Cidade |
| 3 | `task12-shop.png` | Loja com oferta e procura |
| 4 | `taskE3-outfit-casaco_longo.png` | Roupa visual e camadas do herói |
| 5 | `task12-hud-dungeon.png` | HUD dentro da torre |
| 6 | `taskE2-sword-special.png` | Golpe especial da espada |
| 7 | `task11-shockwave-warning.png` | Aviso vermelho do anel do chefe |
| 8 | `task11-final-phase2.png` | Chefe final, fase 2 |

Reserva: `task12-smith.png` (forja), `task10-t1.png` (tutorial), `task10-boss.png` (chefe do andar 1).

## Atalho para o chefe na demonstração

Se o tempo apertar, abra a sala do chefe direto (sem passar pelas salas):

```
/Applications/Godot.app/Contents/MacOS/Godot --path game res://world/dungeon.tscn -- --room=res://world/rooms/boss_f1.tscn
```

Rode da pasta do projeto (`cinzel/`). No Windows, use o `.exe` da build com os mesmos argumentos depois de `--`.
