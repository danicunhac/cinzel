# Guia para redesenhar o escalador

O escalador atual foi gerado por IA, uma tira por animação e direção, e reduzido para 32 px por script. Este guia explica como redesenhá-lo à mão no Pixelorama sem mexer no código: basta exportar arquivos com os mesmos nomes, tamanhos e posições.

## Tamanho e grade

- Cada quadro tem 32x32 pixels.
- Cada folha tem 8 colunas x 13 linhas de quadros: 256x416 pixels.
- Fundo transparente. Quadro que não é usado fica vazio.
- A sola das botas fica na linha 30 do quadro (contando do 0, de cima para baixo); nada passa da linha 30. Os pés ficam centrados na coluna 16.
- Parado, o personagem tem uns 25 px de altura, do topo do capuz à sola. Sobra espaço em cima e dos lados para a espada e o arco do golpe.
- O lado esquerdo não existe na folha: o jogo espelha o lado direito. Desenhe o lado sempre olhando para a direita.

## Linhas e quadros

| Linha | Animação | Quadros usados |
|---|---|---|
| 0 | `idle_down` (parado, de frente, respirando) | 4 |
| 1 | `idle_up` (parado, de costas) | 4 |
| 2 | `idle_side` (parado, de lado) | 4 |
| 3 | `walk_down` (andando, de frente) | 8 |
| 4 | `walk_up` | 8 |
| 5 | `walk_side` | 8 |
| 6 | `attack_down` (preparo, espada no alto, golpe, arco cheio, acompanhamento, volta) | 6 |
| 7 | `attack_up` | 6 |
| 8 | `attack_side` | 6 |
| 9 | `roll_down` (agacha, mergulha, bola, bola girando, aterrissa, levanta) | 6 |
| 10 | `roll_up` | 6 |
| 11 | `roll_side` | 6 |
| 12 | `death` (morte, só de frente) | 6 |

## Uma camada por arquivo

O personagem é montado no jogo com 4 folhas empilhadas, nesta ordem (a de baixo primeiro):

1. `body.png`: pele e botas.
2. `hair.png`: capuz e cabelo.
3. `outfit.png`: jaqueta, luvas de couro, cachecol, calça e mochila.
4. `weapon.png`: espada e o arco claro do golpe.

As 4 folhas têm o mesmo tamanho e a mesma grade. Um pixel pertence a uma camada só, e nenhuma camada tem pixel solto (sem vizinho na mesma camada). Separar assim permite trocar a cor da roupa ou a arma depois sem redesenhar o resto.

## Paleta

30 cores no total, com contorno `#181014` em todas as camadas.

- Pele: `#FABF6B` (luz), `#E8A859`, `#AB7B40` (sombra do capuz).
- Capuz e cachecol (verde-oliva): `#707144` (luz), `#63663B`, `#575D38`, `#4D5837`, `#4A5335`, `#424F32`, `#3B462D`, `#2F3724` (sombra).
- Couro (jaqueta, luvas, mochila, botas): `#9A5121` (luz), `#894B20`, `#7A3E1C`, `#6C391A`, `#61371A`, `#5E2E16`, `#4B3118`, `#472513` (sombra).
- Calça cáqui e fivelas: `#C9A556`, `#CF914A`, `#A3813A`, `#8E672E`, `#704B23`.
- Espada e arco do golpe: `#FDFAD6`, `#FDF3D5`, `#F8E9D6` (brilho e arco), `#D0C8BB`, `#9D9A90`.

Regras do jogo para cor: amarelo marca item ou cura e vermelho marca perigo. No escalador, evite amarelo saturado ou dourado e vermelho vivo. Os cáquis e marrons da paleta acima podem ficar.

## Como as animações funcionam

- Parado: 4 quadros de respiração. Os pés não mexem; ombros e cabeça descem 1 px no meio.
- Andar: 8 quadros. 1 contato (um pé à frente), 2 descida (joelhos dobram, corpo mais baixo), 3 passagem (perna de trás passa pela da frente, corpo mais alto), 4 subida, e de 5 a 8 o mesmo com a outra perna. Os braços balançam ao contrário das pernas. Pernas e braços mudam de pose em todo quadro.
- Ataque: 6 quadros. O arco do golpe fica dentro do quadro de 32x32 (no golpe de lado, o corpo recua 3 a 4 px nos quadros 3 e 4 para o arco caber). A ponta da espada no alto pode encostar na borda de cima.
- Rolamento: 6 quadros, termina de pé na mesma posição do quadro parado.
- Morte: 6 quadros, os 2 últimos iguais (deitado de bruços, espada no chão).

## Passo a passo no Pixelorama

Os nomes de menu abaixo são os da versão em português. Se estiverem diferentes na sua versão, procure a opção com a mesma função.

1. Abra o Pixelorama e crie uma imagem nova de 256x416 pixels, com fundo transparente.
2. Ligue a grade (fica no menu de visualização, algo como Ver > Grade) e ajuste o tamanho dela para 32x32 pixels. Cada quadrado é um quadro.
3. Importe `art-src/climber-reference.png` como uma camada nova (no menu Arquivo, a opção de importar imagem tem um modo "como camada"). Chame essa camada de `guia`, baixe a opacidade dela para uns 40% e trave a camada.
4. Crie 4 camadas acima da guia, com os nomes `body`, `hair`, `outfit` e `weapon`, nesta ordem de baixo para cima.
5. Crie uma paleta nova no painel de paletas e adicione as cores acima pelo código hex.
6. Redesenhe camada por camada, por cima da guia:
   - Comece pela linha 0 (parado, de frente). Quando ela estiver boa, copie para as outras linhas e ajuste.
   - Mantenha a sola na linha 30 e os pés centrados na coluna 16 em todos os quadros, senão o personagem "pula" quando a animação troca.
   - Para conferir uma animação, use a prévia de animação do Pixelorama, ou exporte e rode o jogo.
7. Esconda a camada `guia`.
8. Exporte uma folha por camada. Deixe visível só uma camada por vez e exporte como PNG (no menu Arquivo, a opção de exportar; se ela pedir, escolha exportar a imagem inteira, sem cortar nem dividir em quadros). Use o nome da camada e salve em `game/assets/characters/climber/`, sobrescrevendo `body.png`, `hair.png`, `outfit.png` e `weapon.png`.
9. Confira os arquivos. Os scripts precisam de um Python com o Pillow. Crie um venv uma vez com `python3 -m venv /tmp/cinzel-venv && /tmp/cinzel-venv/bin/pip install pillow` e rode `/tmp/cinzel-venv/bin/python -I art-src/check_art.py .`. Ele avisa se o tamanho estiver errado, se houver mais de 32 cores, pixel semitransparente, pixel solto, quadro sem uso preenchido ou algo abaixo da linha 30.
10. Para ver as animações sem abrir o jogo, rode `/tmp/cinzel-venv/bin/python -I art-src/preview.py . /tmp/cinzel-previews` (ele lê `art-src/climber-reference.png`; refaça essa composição empilhando as 4 camadas, ou olhe direto no Godot).
11. Abra o Godot (ele reimporta sozinho) e rode a sala de teste para ver o resultado.

Atenção: `build_climber.py` gera de novo a versão feita por IA. Ele não sobrescreve as folhas que já existem, a menos que você passe `--force`. Com `--force` ele apaga os seus desenhos de `body.png`, `hair.png`, `outfit.png` e `weapon.png`. Faça uma cópia antes, ou use o git para recuperar.
