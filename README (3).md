# Liturgia

Aplicativo web (PWA) com as leituras do dia, devocional para rezar a dois e ranking de participantes. Instalável no celular, abre offline.

## Recursos

- Login ou cadastro com apelido e senha (sem e-mail) ao abrir o app
- Leituras do dia: 1ª leitura, salmo, 2ª leitura, Evangelho e leituras extras, com a cor litúrgica
- A aba Liturgia usa a cor litúrgica do dia (verde, branco, vermelho, roxo ou rosa); se a fonte não informar, a cor vem do calendário litúrgico calculado no próprio app
- Os próximos dias são salvos no aparelho para abrir mesmo com internet fraca
- Navegação entre os dias e ajuste do tamanho da letra
- Devocional: reflexões sobre a liturgia do dia, visíveis para os outros usuários
- Ranking de participantes por dias com reflexão publicada
- Ajustes: tema claro, escuro ou automático, cor do app (terracota por padrão, azul, rosa ou verde), tamanho da letra e efeitos sonoros com volume

- **Casal:** em Ajustes › Casal, um usuário gera um código de convite e o outro digita o código. Depois de conectados, as reflexões marcadas "só o casal" aparecem para os dois (e só para os dois)

## Arquivos

`index.html` (o app inteiro, com ícones e manifesto embutidos), `sw.js` (cache offline, opcional), `supabase.sql` (banco) e `LICENSE`.

## Configuração

No início do script de `index.html` fica o bloco `CONFIG`:

1. **`liturgiaUrl`** (e `liturgiaUrlAlt`, tentada se a primeira falhar): endereço da API de liturgia. `{d}`, `{m}` e `{y}` são trocados pelo dia, mês e ano. Use uma fonte cujo conteúdo você tenha permissão para exibir.
2. **`supabase`**: crie um projeto no [Supabase](https://supabase.com), desative "Confirm email" em Authentication > Providers > Email, execute o arquivo `supabase.sql` (inclui as tabelas e funções do casal; pode rodar de novo ao atualizar) no SQL Editor e preencha `url` e `anonKey`. Com o Supabase configurado, o app pede login ou cadastro assim que é aberto. Sem ele, o app abre direto e as reflexões ficam apenas no aparelho.

O login usa apelido e senha, sem e-mail, então não existe recuperação de senha. Moderação de comentários e contas é feita pelo painel do Supabase.

## Instalação

Publique os arquivos no repositório `Liturgia` do GitHub e ative o GitHub Pages (Settings › Pages › Deploy from a branch › `main` / root). O app fica em **https://lucasravelli.github.io/Liturgia/**. Abra esse endereço no celular.

- **Android (Chrome):** menu ⋮ → "Instalar app" ou "Adicionar à tela inicial"
- **iPhone (Safari):** Compartilhar → "Adicionar à Tela de Início"

## Licença

Distribuído sob a licença MIT. Veja [LICENSE](LICENSE).

Desenvolvido por [Lucas Ravelli](https://github.com/lucasravelli).
