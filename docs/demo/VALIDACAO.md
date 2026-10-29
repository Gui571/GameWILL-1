# Validação da demo — 29 de outubro de 2026

As imagens desta pasta são capturas reais da prévia HTML, não renders Unity.

- **C#/.NET 8:** 168 verificações aprovadas. Cobrem seleção e troca de alvo, energia, recargas, interrupção, combo elemental, escudo e expiração, cura, inimigos ameaçando aliados, segunda fase do chefe, derrota, determinismo e as nove combinações de melhorias.
- **Modelo web:** 11 testes aprovados. Cinco cenários com 218 estados e eventos comparados aos resultados C#, com tolerância numérica de 0,00005. Hash do código C# impede usar uma referência desatualizada silenciosamente.
- **Chromium desktop 1440×900:** título, prólogo completo por teclado, mapa, alvo por clique, ataque manual/automático, três vitórias por ações de interface, poderes, melhorias, recarga da página e retomada de checkpoint, encerramento, pausa, ajuda, derrota e nova tentativa. Nenhum erro JavaScript.
- **Toque emulado:** retrato 390×844 e paisagem 844×390; iniciar, navegar, desligar Auto, executar corte manual e controles visíveis. Sem teste em aparelho físico.
- **Égide:** botão acionado com energia obtida por cortes reais; escudo conferido na equipe. Créditos incorporados ao HTML verificados.
- **Pacote:** HTML autossuficiente, ZIP com CRC válido e SHA-256. Arte/fontes incorporadas, áudio sintetizado, nenhuma requisição de recurso externo necessária durante a partida.
- **Unity:** quatro arquivos C# analisados pelo parser Roslyn sem erros de sintaxe. A análise de sintaxe não valida referências da API Unity. Não houve importação, execução visual ou build no editor, ausente neste ambiente junto com licença configurada.

Os combates ativos dos testes de regras duram aproximadamente 9–29 segundos cada; navegação, leitura e decisões estendem a introdução. O teste de derrota define vida zero para exercitar a interface; os testes de regras também verificam derrota causada pelo combate. As capturas de combate usam atributos normais da partida.
