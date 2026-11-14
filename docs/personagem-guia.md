# Guia para redesenhar o escalador

O escalador atual foi gerado por IA e reduzido por script. Este guia explica como redesenhá-lo à mão no Pixelorama sem mexer no código: basta exportar arquivos com os mesmos nomes, tamanhos e posições.

## Tamanho e grade

- Cada quadro tem 24x24 pixels.
- Cada folha tem 4 colunas x 13 linhas de quadros: 96x312 pixels.
- Fundo transparente. Quadro que não é usado fica vazio.
- Os pés ficam na linha 22 do quadro (contando do 0, de cima para baixo). O centro do capuz fica na coluna 12.
- O lado esquerdo não existe na folha: o jogo espelha o lado direito. Desenhe o lado sempre olhando para a direita.

## Linhas e quadros

| Linha | Animação | Quadros usados |
|---|---|---|
| 0 | `idle_down` (parado, de frente) | 2 |
| 1 | `idle_up` (parado, de costas) | 2 |
| 2 | `idle_side` (parado, de lado) | 2 |
| 3 | `walk_down` (andando, de frente) | 4 |
| 4 | `walk_up` | 4 |
| 5 | `walk_side` | 4 |
| 6 | `attack_down` (golpe: preparo, golpe, acompanhamento) | 3 |
| 7 | `attack_up` | 3 |
| 8 | `attack_side` | 3 |
| 9 | `roll_down` (rolamento) | 4 |
| 10 | `roll_up` | 4 |
| 11 | `roll_side` | 4 |
| 12 | `death` (morte, só de frente) | 4 |

## Uma camada por arquivo

O personagem é montado no jogo com 4 folhas empilhadas, nesta ordem (a de baixo primeiro):

1. `body.png`: pele, mãos e botas.
2. `hair.png`: capuz e cabelo.
3. `outfit.png`: jaqueta, cachecol, calça e mochila.
4. `weapon.png`: espada e o arco claro do golpe.

As 4 folhas têm o mesmo tamanho e a mesma grade. Um pixel pertence a uma camada só. Separar assim permite trocar a cor da roupa ou a arma depois sem redesenhar o resto.

## Paleta

Contorno de todas as camadas: `#181014`.

- Pele: `#CFA152` (luz), `#A2803D`, `#966429`, `#7A713B` (sombra no capuz).
- Botas e couro escuro: `#864D1F`, `#7C421E`, `#67361A`, `#523119`, `#3F2313`, `#2D1D12`, `#22130E`.
- Capuz e cachecol (verde-oliva): `#67673A` (luz), `#5A6238`, `#4A5834`, `#475433`, `#424C32`, `#343C27`, `#2A2718` (sombra).
- Jaqueta e mochila: `#975422` (luz), `#864D1F`, `#7C421E`, `#6C3F1C`, `#502A16`, `#503C1F`.
- Calça cáqui: `#A2803D`, `#7A713B`, `#5E532E`.
- Espada: `#EFE1CD` (brilho e arco do golpe), `#CBC5B4`, `#AEAC9B`, `#8D8B7F`.

Regras do jogo para cor: amarelo marca item ou cura e vermelho marca perigo. No escalador, evite amarelo saturado ou dourado e vermelho vivo. Os cáquis e marrons da paleta acima podem ficar.

## Como o andar é feito

As linhas de andar (3, 4 e 5) partem do quadro parado da mesma direção:

1. Contato: pé esquerdo à frente, braço direito (com a espada) à frente.
2. Passagem: corpo 1 px acima, pernas juntas.
3. Contato espelhado: pé direito à frente, braço esquerdo à frente.
4. Passagem de novo.

De frente e de costas, o pé da frente desce 1 px e o de trás sobe 1 px, e os braços balançam 1 px ao contrário das pernas. De lado, as pernas abrem 3 px (a de trás mais escura) e a mochila fica 1 px para trás na passagem. Ao redesenhar, mantenha essa ideia: as pernas precisam alternar de forma visível.

## Passo a passo no Pixelorama

Os nomes de menu abaixo são os da versão em português. Se estiverem diferentes na sua versão, procure a opção com a mesma função.

1. Abra o Pixelorama e crie uma imagem nova de 96x312 pixels, com fundo transparente.
2. Ligue a grade (fica no menu de visualização, algo como Ver > Grade) e ajuste o tamanho dela para 24x24 pixels. Cada quadrado é um quadro.
3. Importe `art-src/climber-reference.png` como uma camada nova (no menu Arquivo, a opção de importar imagem tem um modo "como camada"). Chame essa camada de `guia`, baixe a opacidade dela para uns 40% e trave a camada.
4. Crie 4 camadas acima da guia, com os nomes `body`, `hair`, `outfit` e `weapon`, nesta ordem de baixo para cima.
5. Crie uma paleta nova no painel de paletas e adicione as cores acima pelo código hex.
6. Redesenhe camada por camada, por cima da guia:
   - Comece pela linha 0 (parado, de frente). Quando ela estiver boa, copie para as outras linhas e ajuste.
   - Mantenha os pés na linha 22 e o capuz centrado na coluna 12 em todos os quadros, senão o personagem "pula" quando a animação troca.
   - Para conferir uma animação, use a prévia de animação do Pixelorama, ou exporte e rode o jogo.
7. Esconda a camada `guia`.
8. Exporte uma folha por camada. Deixe visível só uma camada por vez e exporte como PNG (no menu Arquivo, a opção de exportar; se ela pedir, escolha exportar a imagem inteira, sem cortar nem dividir em quadros). Use o nome da camada e salve em `game/assets/characters/climber/`, sobrescrevendo `body.png`, `hair.png`, `outfit.png` e `weapon.png`.
9. Confira os arquivos. Os scripts precisam de um Python com o Pillow. Crie um venv uma vez com `python3 -m venv /tmp/cinzel-venv && /tmp/cinzel-venv/bin/pip install pillow` e rode `/tmp/cinzel-venv/bin/python -I art-src/check_art.py .`. Ele avisa se o tamanho estiver errado, se houver mais de 32 cores ou pixel semitransparente.
10. Abra o Godot (ele reimporta sozinho) e rode a sala de teste para ver o resultado.

Atenção: `build_climber.py` gera de novo a versão feita por IA. Ele não sobrescreve as folhas que já existem, a menos que você passe `--force`. Com `--force` ele apaga os seus desenhos de `body.png`, `hair.png`, `outfit.png` e `weapon.png`. Faça uma cópia antes, ou use o git para recuperar.
