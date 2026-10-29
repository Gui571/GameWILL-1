# William — O juramento de Aurora

**Prévia complementar jogável de navegador. Não é um build Unity/WebGL.** O projeto principal está em [../unity](../unity/README.md). Esta prévia permite experimentar o combate enquanto a validação no editor Unity permanece pendente.

## Jogar agora

[Baixe o HTML completo](https://github.com/Gui571/GameWILL-1/raw/refs/heads/main/downloads/William-Aurora-Demo.html), salve no computador e abra com Chrome, Edge ou Firefox. Não exige instalação, servidor, conta ou conexão após o download. O [ZIP](https://github.com/Gui571/GameWILL-1/raw/refs/heads/main/downloads/William-Aurora-Demo.zip) inclui o mesmo HTML, instruções e licenças. Caso o GitHub mostre o código, use o botão **Download raw file**.

No celular, o comportamento ao abrir arquivos HTML baixados varia conforme o navegador e sistema. O layout e o toque foram verificados em emulação Chromium; não foi feito teste em aparelho físico. A página também pode ser servida por qualquer hospedagem estática, sem backend.

## A pequena jornada

Prólogo em português, mapa de três encontros, equipe de três integrantes, inimigos com alvos anunciados, seleção de alvo, cura inteligente, melhorias entre encontros e chefe com segunda fase. A trilha é salva localmente entre encontros. Recarregar durante uma luta permite recomeçá-la; não salva o instante exato do combate.

- **Q — Chama:** dano; sobre Geada, consome o congelamento e causa choque térmico.
- **E — Geada:** congela e interrompe um golpe anunciado, devolvendo energia quando bem aplicada.
- **R — Égide:** dano e escudo de oito segundos para a equipe.
- **Espaço — Corte:** ataque manual que recupera energia. **T:** alterna Auto.
- Clique/toque no inimigo para mudar o alvo. Todos os comandos também têm botões.
- **Esc:** pausa/retoma. Ajuda inclui opção de movimento reduzido; áudio pode ser silenciado.

A arte atual é original, gerada com assistência de IA para este projeto: William, Lyra em forma humana, Bruma como raposa branca, sentinela, guardião e criatura do bosque. O cenário também foi refeito. As poses têm movimentos procedurais, sem animações novas desenhadas quadro a quadro. Os atlas antigos de Procedural Pixel Creatures permanecem apenas como fallback no projeto Unity. Mana Seed não foi comprado ou incorporado. Licenças também estão embutidas no HTML, em **Sobre esta demo**, no encerramento.

## Código e validação

`combat.js` traduz explicitamente o núcleo `unity/Assets/William/Core/Battle.cs` e usa precisão Float32. A comparação automatizada cobre a ordem dos eventos e 218 estados de cinco cenários. O arquivo de referência guarda o hash do C# para detectar alterações não sincronizadas. A apresentação e a plataforma de execução são distintas das de Unity.

```bash
# Na raiz do repositório
python3 demo/build.py
node --test demo/tests/combat.test.mjs
dotnet run --project unity/Tests/William.Core.Tests.csproj -c Release
```

Para regenerar a referência após uma alteração intencional no núcleo:

```bash
dotnet build demo/tests/fixture/Fixture.csproj -c Release
dotnet demo/tests/fixture/bin/Release/net8.0/Fixture.dll unity/Assets/William/Core/Battle.cs > demo/tests/combat-parity.json
node --test demo/tests/combat.test.mjs
```

Os testes do núcleo verificam 168 condições, incluindo as nove combinações de melhorias. Os 11 testes de navegador/modelo incluem a comparação com C#. O teste de interface exercita a jornada inteira, cliques, teclas, pausa, retomada, derrota, ajuda e toque em retrato/paisagem.

```bash
cd demo
npm ci
npx playwright install chromium
npm run test:ui
```

O teste de interface sobe um servidor local temporário; as capturas ficam em `build/demo/`. Não há dependências de rede durante a partida. O HTML pode ser recompilado com Python padrão; não há bibliotecas de interface externas.
