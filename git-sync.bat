@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title DIMES - Gerenciador Git Custom ^& Upstream

:: Garante que o script roda a partir da pasta raiz do projeto
cd /d "%~dp0"

:CHECK_GIT
:: Algumas janelas abertas por duplo clique não herdam o PATH atualizado do Windows.
:: Usa o executável oficial diretamente antes de verificar o PATH.
set "GIT_EXE="
set "GIT_CMD_DIR="
if exist "C:\Program Files\Git\cmd\git.exe" (
    set "GIT_EXE=C:\Program Files\Git\cmd\git.exe"
    set "GIT_CMD_DIR=C:\Program Files\Git\cmd"
)
if not defined GIT_EXE if exist "C:\Program Files (x86)\Git\cmd\git.exe" (
    set "GIT_EXE=C:\Program Files (x86)\Git\cmd\git.exe"
    set "GIT_CMD_DIR=C:\Program Files (x86)\Git\cmd"
)
if defined GIT_CMD_DIR set "PATH=!GIT_CMD_DIR!;!PATH!"

if not defined GIT_EXE (
    cls
    echo ========================================================
    echo  [ERRO CRITICO] O Git nao esta instalado ou no PATH!
    echo ========================================================
    echo  Instale o Git para Windows ou adicione-o nas variaveis de ambiente.
    echo  Download oficial: https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)
"!GIT_EXE!" --version >nul 2>&1
if errorlevel 1 (
    cls
    echo ========================================================
    echo  [ERRO CRITICO] A instalacao do Git nao pode ser executada
    echo ========================================================
    echo  Caminho encontrado: !GIT_EXE!
    echo  Reinstale o Git para Windows e tente novamente.
    echo.
    pause
    exit /b 1
)

if not exist ".git" (
    cls
    echo ========================================================
    echo  [ERRO CRITICO] Pasta .git nao encontrada!
    echo ========================================================
    echo  Este arquivo .bat deve estar na raiz do projeto pdlpro.
    echo  Diretorio atual: %cd%
    echo.
    pause
    exit /b 1
)

:: -----------------------------------------------------------------------
:: Verifica identidade git (user.name e user.email) — necessario para commits
:: -----------------------------------------------------------------------
:CHECK_IDENTITY
set GIT_USER_NAME=
set GIT_USER_EMAIL=
for /f "delims=" %%N in ('git config user.name 2^>nul') do set GIT_USER_NAME=%%N
for /f "delims=" %%E in ('git config user.email 2^>nul') do set GIT_USER_EMAIL=%%E

if "!GIT_USER_NAME!"=="" (
    cls
    echo ===============================================================================
    echo  [CONFIGURACAO INICIAL] Identidade Git nao encontrada para este usuario
    echo ===============================================================================
    echo  O Git precisa saber quem voce e para registrar os commits corretamente.
    echo  Isso so precisa ser feito uma vez nesta maquina.
    echo ===============================================================================
    echo.
    set /p GIT_USER_NAME="Seu nome completo ou apelido (ex: jacksonfelipe): "
    if "!GIT_USER_NAME!"=="" set GIT_USER_NAME=jacksonfelipe
    git config --global user.name "!GIT_USER_NAME!"
    echo [OK] Nome registrado: !GIT_USER_NAME!
    echo.
)

if "!GIT_USER_EMAIL!"=="" (
    echo  Email nao configurado. Pode usar o email do GitHub no formato:
    echo  usuario@users.noreply.github.com
    echo.
    set /p GIT_USER_EMAIL="Seu email (ENTER para usar jacksonfelipe@users.noreply.github.com): "
    if "!GIT_USER_EMAIL!"=="" set GIT_USER_EMAIL=jacksonfelipe@users.noreply.github.com
    git config --global user.email "!GIT_USER_EMAIL!"
    echo [OK] Email registrado: !GIT_USER_EMAIL!
    echo.
    timeout /t 2 >nul
)

:MENU
cls
:: Detecta branch atual
for /f "delims=" %%B in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set CURRENT_BRANCH=%%B
if "!CURRENT_BRANCH!"=="" set CURRENT_BRANCH=master

:: Detecta remotes
set HAS_ORIGIN=0
set HAS_UPSTREAM=0
for /f "tokens=1" %%R in ('git remote 2^>nul') do (
    if "%%R"=="origin" set HAS_ORIGIN=1
    if "%%R"=="upstream" set HAS_UPSTREAM=1
)

echo ===============================================================================
echo            DIMES - SINCRONIZADOR GIT (CUSTOM ^& UPSTREAM)
echo ===============================================================================
echo  Branch Ativa: [!CURRENT_BRANCH!]
echo  Remoto Pessoal  (origin)   : !HAS_ORIGIN! (1 = Configurado, 0 = Ausente)
echo  Remoto Oficial  (upstream) : !HAS_UPSTREAM! (1 = Configurado, 0 = Ausente)
echo ===============================================================================
echo.
echo  [1] SALVAR E ENVIAR TUDO (Commit + Push para seu repositorio 'origin')
echo      -^> Quando usar: No meio ou fim do dia para salvar seu progresso no seu GitHub,
echo         sem puxar atualizacoes oficiais ainda.
echo.
echo  [2] PUXAR ATUALIZACOES OFICIAIS (Fetch + Merge de 'upstream/!CURRENT_BRANCH!')
echo      -^> Quando usar: Quando quiser testar novidades do DIMES oficial localmente
echo         sem subir nada para o seu GitHub ainda.
echo.
echo  [3] SINCRONIZACAO COMPLETA (Commit Local -^> Puxar Upstream -^> Enviar Origin) [RECOMENDADO]
echo      -^> Quando usar: Seu botao do dia a dia! Salva suas melhorias, puxa o oficial
echo         e sobe tudo mesclado e atualizado para o seu GitHub.
echo.
echo  [4] VER STATUS DETALHADO (Arquivos alterados, commits pendentes e remotos)
echo.
echo  [5] GUARDAR / RECUPERAR ALTERACOES (Git Stash / Stash Pop)
echo      -^> Quando usar: Deixar o workspace limpo temporariamente sem criar commit.
echo.
echo  [6] RESOLVER / CANCELAR CONFLITO DE MERGE (Abortar ou listar conflitos)
echo      -^> Quando usar: Se um merge apontar arquivos em conflito e quiser resolver ou cancelar.
echo.
echo  [7] DIAGNOSTICO E CONFIGURACAO DE REMOTOS (Ver/Corrigir links origin e upstream)
echo  [8] VER HISTORICO RECENTE DE COMMITS
echo  [9] GUIA DETALHADO: QUANDO USAR CADA OPCAO? (Explicacoes passo a passo)
echo.
echo  [10] PUXAR DO SEU REPOSITORIO CUSTOM (origin -^> local)
echo       -^> Quando usar: Voce fez mudancas no VPS ou em outro PC e quer baixar
echo          para esta maquina sem subir nada novo.
echo.
echo  [0] SAIR
echo ===============================================================================
set OPTION=
set /p OPTION="Escolha uma opcao [0-9, 10]: "

if "%OPTION%"=="1" goto OP_COMMIT_PUSH
if "%OPTION%"=="2" goto OP_PULL_UPSTREAM
if "%OPTION%"=="3" goto OP_FULL_SYNC
if "%OPTION%"=="4" goto OP_STATUS
if "%OPTION%"=="5" goto OP_STASH
if "%OPTION%"=="6" goto OP_RESOLVE_MERGE
if "%OPTION%"=="7" goto OP_DIAGNOSTIC
if "%OPTION%"=="8" goto OP_LOG
if "%OPTION%"=="9" goto OP_HELP
if "%OPTION%"=="10" goto OP_PULL_ORIGIN
if "%OPTION%"=="0" goto EXIT_SCRIPT

echo.
echo Opcao invalida. Tente novamente.
timeout /t 2 >nul
goto MENU

:: ===============================================================================
:: OPCAO 1: COMMIT + PUSH PARA ORIGIN
:: ===============================================================================
:OP_COMMIT_PUSH
cls
echo ===============================================================================
echo  [1] SALVAR E ENVIAR ALTERACOES PARA O SEU REPOSITORIO (ORIGIN)
echo ===============================================================================
echo.

call :VALIDATE_ORIGIN
if !ERRORLEVEL! neq 0 goto END_OP

echo  Verificando alteracoes pendentes...
git status --short
echo.

set /p COMMIT_MSG="Digite a mensagem do commit (Pressione ENTER para usar a padrao): "
if "!COMMIT_MSG!"=="" set COMMIT_MSG=feat: atualizacoes customizadas em !date! !time:~0,5!

echo.
echo [1/3] Adicionando todos os arquivos (git add .)...
git add .
if !ERRORLEVEL! neq 0 (
    echo [ERRO] Falha ao adicionar arquivos. Verifique permissoes de arquivo.
    goto END_OP
)

echo [2/3] Criando commit...
git commit -m "!COMMIT_MSG!"
set COMMIT_RET=!ERRORLEVEL!
if !COMMIT_RET! neq 0 (
    echo.
    echo [INFO] Nenhuma nova alteracao encontrada para commitar.
) else (
    echo [OK] Commit criado com sucesso: "!COMMIT_MSG!"
)

echo.
echo [3/3] Enviando para origin/!CURRENT_BRANCH! (git push origin !CURRENT_BRANCH!)...
git push origin !CURRENT_BRANCH!
if !ERRORLEVEL! neq 0 (
    echo.
    echo ============================================================================
    echo  [ERRO NO PUSH] O envio foi rejeitado ou falhou!
    echo ============================================================================
    echo  Causas comuns e solucoes:
    echo  1. O repositorio remoto possui commits que voce nao tem localmente.
    echo     - Solucao: Execute a opcao [2] ou [3] para puxar e mesclar antes.
    echo  2. Falha de autenticacao com o GitHub (token ou credencial expirada).
    echo     - Solucao: Abra https://github.com/settings/tokens e configure o Git Credential Manager.
    echo  3. O branch remoto ainda nao existe com tracking configurado.
    echo     - Tentando 'git push -u origin !CURRENT_BRANCH!' automaticamente agora...
    echo.
    git push -u origin !CURRENT_BRANCH!
    if !ERRORLEVEL! equ 0 (
        echo.
        echo [OK] Push com tracking realizado com sucesso!
    )
) else (
    echo.
    echo [SUCESSO] Todas as suas alteracoes foram enviadas para o seu repositorio!
)
goto END_OP

:: ===============================================================================
:: OPCAO 2: PUXAR ATUALIZACOES DO UPSTREAM (OFICIAL)
:: ===============================================================================
:OP_PULL_UPSTREAM
cls
echo ===============================================================================
echo  [2] PUXAR E MESCLAR ATUALIZACOES DO REPOSITORIO OFICIAL (UPSTREAM)
echo ===============================================================================
echo.

call :VALIDATE_UPSTREAM
if !ERRORLEVEL! neq 0 goto END_OP

echo [1/3] Verificando se ha arquivos modificados no ambiente de trabalho...
git status --porcelain > "%temp%\git_pdl_dirty.txt"
set IS_DIRTY=0
for %%A in ("%temp%\git_pdl_dirty.txt") do if %%~zA gtr 0 set IS_DIRTY=1
del "%temp%\git_pdl_dirty.txt" >nul 2>&1

if !IS_DIRTY! equ 1 (
    echo.
    echo [AVISO] Voce possui alteracoes nao salvas no workspace que podem entrar em
    echo         conflito ao mesclar com as atualizacoes do upstream.
    echo.
    echo Deseja:
    echo   [S] Salvar tudo automaticamente num commit antes de mesclar (Recomendado)
    echo   [G] Guardar temporariamente no Git Stash
    echo   [C] Continuar mesmo assim (Pode falhar se houver colisao)
    echo   [A] Abortar
    set /p MERGE_DIRTY_CHOICE="Escolha [S/G/C/A]: "
    if /i "!MERGE_DIRTY_CHOICE!"=="S" (
        git add .
        git commit -m "chore: salvando alteracoes locais antes do merge com upstream"
    ) else if /i "!MERGE_DIRTY_CHOICE!"=="G" (
        git stash push -m "Stash automatico antes de merge com upstream"
    ) else if /i "!MERGE_DIRTY_CHOICE!"=="A" (
        echo Operacao cancelada pelo usuario.
        goto END_OP
    )
)

echo.
echo [2/3] Buscando atualizacoes do upstream (git fetch upstream)...
git fetch upstream
if !ERRORLEVEL! neq 0 (
    echo.
    echo [ERRO] Nao foi possivel conectar ao upstream. Verifique sua conexao ou o link do repositorio.
    goto END_OP
)

echo.
echo [3/3] Mesclando atualizacoes (git merge upstream/!CURRENT_BRANCH!)...
git merge --no-edit upstream/!CURRENT_BRANCH!
if !ERRORLEVEL! neq 0 (
    echo.
    echo ============================================================================
    echo  [ATENCAO: CONFLITO DE MERGE DETECTADO!]
    echo ============================================================================
    echo  Arquivos que entraram em conflito:
    git status --short | findstr /R "^UU ^AA ^UD ^DU"
    echo.
    echo  O que fazer agora:
    echo  1. Abra os arquivos listados acima no VS Code / editor de texto.
    echo  2. Procure por marcadores ^<^<^<^<^<^<^< HEAD e resolva as diferencas.
    echo  3. Apos resolver, execute 'git add .' e finalize o commit.
    echo  OU se preferir desfazer o merge e voltar ao estado anterior:
    echo     Use a Opcao [6] deste menu para dar 'git merge --abort'.
    echo ============================================================================
) else (
    echo.
    echo [SUCESSO] Atualizacoes do repositorio oficial integradas sem conflitos!
    echo Lembre-se de enviar as atualizacoes integradas para o seu origin (Opcao 1).
)
goto END_OP

:: ===============================================================================
:: OPCAO 3: SINCRONIZACAO COMPLETA (1 CLIQUE)
:: ===============================================================================
:OP_FULL_SYNC
cls
echo ===============================================================================
echo  [3] SINCRONIZACAO COMPLETA EM 1 CLIQUE
echo ===============================================================================
echo  1. Comita suas alteracoes locais atuais
echo  2. Puxa as novidades do upstream
echo  3. Envia o resultado completo para seu origin
echo ===============================================================================
echo.

call :VALIDATE_ORIGIN
if !ERRORLEVEL! neq 0 goto END_OP
call :VALIDATE_UPSTREAM
if !ERRORLEVEL! neq 0 goto END_OP

echo [PASSO 1/3] Salvando alteracoes locais...
git add .
git commit -m "chore: sincronizacao automatica - preservando customizacoes locais" >nul 2>&1

echo.
echo [PASSO 2/3] Baixando novidades do oficial (upstream)...
git fetch upstream
if !ERRORLEVEL! neq 0 (
    echo [ERRO] Falha ao fazer fetch do upstream.
    goto END_OP
)

git merge --no-edit upstream/!CURRENT_BRANCH!
if !ERRORLEVEL! neq 0 (
    echo.
    echo [ERRO] Ocorreu um conflito ao mesclar com upstream.
    echo O processo foi pausado para voce resolver os conflitos.
    echo Veja a opcao [6] do menu para detalhes.
    goto END_OP
)

echo.
echo [PASSO 3/3] Preparando registro da versao e envio...
echo.

:: --- Le a versao atual do version.json ---
set PDL_VERSION=desconhecida
for /f "tokens=2 delims=:, " %%V in ('findstr /i "\"version\"" version.json 2^>nul') do (
    set PDL_VERSION=%%~V
)

:: --- Coleta commits do upstream que chegaram ---
set UPSTREAM_LOG=
for /f "delims=" %%L in ('git log --oneline ORIG_HEAD..HEAD 2^>nul') do (
    if "!UPSTREAM_LOG!"=="" (
        set UPSTREAM_LOG=%%L
    ) else (
        set UPSTREAM_LOG=!UPSTREAM_LOG! ^| %%L
    )
)
if "!UPSTREAM_LOG!"=="" set UPSTREAM_LOG=(nenhuma novidade do upstream nesta sincronizacao)

:: --- Coleta commits customizados (antes do merge) ---
set CUSTOM_LOG=
for /f "delims=" %%L in ('git log --oneline upstream/!CURRENT_BRANCH!..ORIG_HEAD 2^>nul') do (
    if "!CUSTOM_LOG!"=="" (
        set CUSTOM_LOG=%%L
    ) else (
        set CUSTOM_LOG=!CUSTOM_LOG! ^| %%L
    )
)
if "!CUSTOM_LOG!"=="" set CUSTOM_LOG=(sem commits customizados novos)

echo ============================================================================
echo  REVISAO FINAL - SINCRONIZACAO v!PDL_VERSION!
echo  Destino: github.com/jacksonfelipe/pdlpro-custom  ^| Branch: !CURRENT_BRANCH!
echo ============================================================================
echo.
echo  [+] Versao detectada  : v!PDL_VERSION!
echo.
echo  [UPSTREAM] Novidades do DIMES oficial:
for /f "delims=" %%L in ('git log --oneline ORIG_HEAD..HEAD 2^>nul') do echo     - %%L
if "!UPSTREAM_LOG!"=="(nenhuma novidade do upstream nesta sincronizacao)" echo     (nenhuma novidade nova)
echo.
echo  [CUSTOM] Suas correcoes e customizacoes:
for /f "delims=" %%L in ('git log --oneline upstream/!CURRENT_BRANCH!..ORIG_HEAD 2^>nul') do echo     - %%L
if "!CUSTOM_LOG!"=="(sem commits customizados novos)" echo     (sem commits proprios novos)
echo.
echo ============================================================================
echo.
set EXTRA_NOTE=
set /p EXTRA_NOTE="Nota adicional para o registro (ENTER para usar a mensagem automatica): "
echo.

:: --- Monta mensagem de commit final ---
if not "!EXTRA_NOTE!"=="" (
    set FINAL_MSG=release: v!PDL_VERSION! - !EXTRA_NOTE!
) else (
    set FINAL_MSG=release: v!PDL_VERSION! - sincronizacao DIMES custom
)

git add .
git commit --allow-empty -m "!FINAL_MSG!" -m "Upstream: !UPSTREAM_LOG!" -m "Custom: !CUSTOM_LOG!" >nul 2>&1

echo  Enviando para jacksonfelipe/pdlpro-custom...
git push origin !CURRENT_BRANCH!
if !ERRORLEVEL! neq 0 (
    git push -u origin !CURRENT_BRANCH!
)

if !ERRORLEVEL! equ 0 (
    echo.
    echo ============================================================================
    echo  [SUCESSO COMPLETO!]  v!PDL_VERSION! registrado em:
    echo  github.com/jacksonfelipe/pdlpro-custom
    echo.
    echo  Commit: !FINAL_MSG!
    echo ============================================================================
) else (
    echo.
    echo [ERRO] Falha ao enviar. Verifique conexao e autenticacao do GitHub.
)
goto END_OP

:: ===============================================================================
:: OPCAO 4: STATUS DETALHADO
:: ===============================================================================
:OP_STATUS
cls
echo ===============================================================================
echo  [4] STATUS DETALHADO DO REPOSITORIO
echo ===============================================================================
echo.
echo [BRANCH ATIVA]: !CURRENT_BRANCH!
echo.
echo [REMOTOS CONFIGURADOS]:
git remote -v
echo.
echo [ESTADO DOS ARQUIVOS LOCAIS]:
git status -s
if !ERRORLEVEL! neq 0 (
    echo Nao foi possivel ler o status.
)
echo.
echo [DIFERENCA DE COMMITS COM ORIGIN]:
git log --oneline origin/!CURRENT_BRANCH!..HEAD 2>nul
if !ERRORLEVEL! equ 0 (
    echo (Commits listados acima existem localmente mas ainda nao foram enviados ao origin)
) else (
    echo (origin/!CURRENT_BRANCH! ainda nao possui tracking ativo)
)
echo.
echo [DIFERENCA DE COMMITS COM UPSTREAM]:
git log --oneline HEAD..upstream/!CURRENT_BRANCH! 2>nul
if !ERRORLEVEL! equ 0 (
    echo (Commits listados acima existem no upstream mas ainda nao foram incorporados)
)
goto END_OP

:: ===============================================================================
:: OPCAO 5: GIT STASH
:: ===============================================================================
:OP_STASH
cls
echo ===============================================================================
echo  [5] GUARDAR / RECUPERAR ALTERACOES (GIT STASH)
echo ===============================================================================
echo  O Stash serve para "guardar na gaveta" alteracoes que ainda nao estao prontas,
echo  deixando seu projeto limpo para puxar atualizacoes sem conflitos.
echo.
echo  [1] Guardar alteracoes no Stash (git stash push)
echo  [2] Restaurar ultimas alteracoes guardadas (git stash pop)
echo  [3] Listar o que esta guardado no Stash (git stash list)
echo  [4] Voltar ao menu principal
echo.
set /p STASH_OPT="Escolha [1-4]: "
if "%STASH_OPT%"=="1" (
    set /p STASH_NAME="Nome/Descricao para este stash (opcional): "
    if "!STASH_NAME!"=="" set STASH_NAME=Stash manual em !date! !time:~0,5!
    git stash push -u -m "!STASH_NAME!"
    echo Alteracoes guardadas com sucesso.
) else if "%STASH_OPT%"=="2" (
    git stash pop
    if !ERRORLEVEL! neq 0 (
        echo [AVISO] Houve conflito ao restaurar o stash. Resolva os arquivos ou descarte.
    ) else (
        echo Stash restaurado com sucesso!
    )
) else if "%STASH_OPT%"=="3" (
    echo.
    git stash list
)
goto END_OP

:: ===============================================================================
:: OPCAO 6: RESOLVER / CANCELAR MERGE
:: ===============================================================================
:OP_RESOLVE_MERGE
cls
echo ===============================================================================
echo  [6] RESOLVER OU CANCELAR MERGE EM CONFLITO
echo ===============================================================================
echo.
echo  Verificando arquivos em conflito no momento...
git status -s | findstr /R "^UU ^AA ^UD ^DU"
echo.
echo  [1] Cancelar e Desfazer o Merge (git merge --abort) - Volta tudo ao estado anterior
echo  [2] Concluir o Merge (Apos resolver e salvar todos os arquivos em conflito)
echo  [3] Voltar ao menu
echo.
set /p MERGE_OPT="Escolha [1-3]: "
if "%MERGE_OPT%"=="1" (
    git merge --abort
    if !ERRORLEVEL! equ 0 (
        echo [OK] Merge cancelado com sucesso. O projeto voltou ao estado original.
    ) else (
        echo [INFO] Nao ha nenhum merge ativo para cancelar.
    )
) else if "%MERGE_OPT%"=="2" (
    git add .
    git commit --no-edit -m "merge: resolucao de conflitos com upstream/!CURRENT_BRANCH!"
    if !ERRORLEVEL! equ 0 (
        echo [SUCESSO] Merge finalizado e comitado com sucesso!
    ) else (
        echo [ERRO] Ainda ha arquivos com conflito pendente ou o commit falhou.
    )
)
goto END_OP

:: ===============================================================================
:: OPCAO 7: DIAGNOSTICO E CONFIGURACAO DE REMOTOS
:: ===============================================================================
:OP_DIAGNOSTIC
cls
echo ===============================================================================
echo  [7] DIAGNOSTICO E REPARO DE REMOTOS
echo ===============================================================================
echo.
echo  Remotos atuais configurados:
git remote -v
echo.
echo  Deseja reconfigurar algum remoto?
echo  [1] Configurar/Corrigir 'origin' (Seu repositorio pessoal)
echo  [2] Configurar/Corrigir 'upstream' (Repositorio oficial D3NKYT0/pdlpro)
echo  [3] Testar conexao de rede com origin e upstream
echo  [4] Voltar ao menu principal
echo.
set /p DIAG_OPT="Escolha [1-4]: "

if "%DIAG_OPT%"=="1" (
    echo.
    echo Digite a URL do seu repositorio no GitHub (Ex: https://github.com/jacksonfelipe/pdlpro-custom.git)
    set /p NEW_ORIGIN="URL Origin: "
    if not "!NEW_ORIGIN!"=="" (
        git remote remove origin >nul 2>&1
        git remote add origin !NEW_ORIGIN!
        echo [OK] Remoto 'origin' atualizado para: !NEW_ORIGIN!
    )
) else if "%DIAG_OPT%"=="2" (
    echo.
    echo Digite a URL do repositorio oficial (Padrao: https://github.com/D3NKYT0/pdlpro.git)
    set /p NEW_UPSTREAM="URL Upstream [Pressione ENTER para usar a padrao]: "
    if "!NEW_UPSTREAM!"=="" set NEW_UPSTREAM=https://github.com/D3NKYT0/pdlpro.git
    git remote remove upstream >nul 2>&1
    git remote add upstream !NEW_UPSTREAM!
    echo [OK] Remoto 'upstream' atualizado para: !NEW_UPSTREAM!
) else if "%DIAG_OPT%"=="3" (
    echo.
    echo Testando conexao com 'origin'...
    git ls-remote origin >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo  [OK] Conexao com origin estabelecida com sucesso!
    ) else (
        echo  [FALHA] Nao foi possivel conectar com origin. Verifique a URL ou autenticacao.
    )

    echo Testando conexao com 'upstream'...
    git ls-remote upstream >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo  [OK] Conexao com upstream estabelecida com sucesso!
    ) else (
        echo  [FALHA] Nao foi possivel conectar com upstream. Verifique a URL.
    )
)
goto END_OP

:: ===============================================================================
:: OPCAO 8: HISTORICO RECENTE
:: ===============================================================================
:OP_LOG
cls
echo ===============================================================================
echo  [8] ULTIMOS 15 COMMITS
echo ===============================================================================
echo.
git log -n 15 --graph --pretty=format:"%%h - %%an, %%ar : %%s"
echo.
goto END_OP

:: ===============================================================================
:: OPCAO 9: GUIA PRATICO - QUANDO USAR CADA OPCAO?
:: ===============================================================================
:OP_HELP
cls
echo ===============================================================================
echo            GUIA PRATICO: QUANDO USAR CADA OPCAO NO DIA A DIA?
echo ===============================================================================
echo.
echo  [OPCAO 1] SALVAR E ENVIAR TUDO (Commit + Push para seu Origin)
echo  -----------------------------------------------------------------------------
echo  QUANDO USAR:
echo   * Voce fez melhorias, criou telas ou alterou regras e quer fazer um BACKUP
echo     seguro no seu GitHub privado.
echo   * Voce AINDA NAO quer baixar atualizacoes do DIMES oficial porque esta
echo     no meio de um teste e nao quer novidades externas interferindo agora.
echo.
echo  [OPCAO 2] PUXAR ATUALIZACOES OFICIAIS (Fetch + Merge Upstream)
echo  -----------------------------------------------------------------------------
echo  QUANDO USAR:
echo   * O DIMES oficial lancou correcoes de bugs ou melhorias novas e voce quer
echo     apenas testar essas novidades no seu computador ANTES de decidir se vai
echo     subir para o seu GitHub privado.
echo.
echo  [OPCAO 3] SINCRONIZACAO COMPLETA (O "BOTAO MAGICO" RECOMENDADO!)
echo  -----------------------------------------------------------------------------
echo  QUANDO USAR:
echo   * No inicio do dia ou ao finalizar uma funcionalidade importante.
echo   * Ela faz os 3 passos automaticamente:
echo     1. Salva tudo o que voce fez (garante que nada seu seja perdido).
echo     2. Baixa e mescla as novidades do DIMES oficial.
echo     3. Sobe o codigo integrado e 100%% atualizado para seu GitHub privado.
echo.
echo  [OPCAO 5] GIT STASH (GUARDAR NA GAVETA)
echo  -----------------------------------------------------------------------------
echo  QUANDO USAR:
echo   * Voce estava rascunhando um codigo que ainda nao funciona, mas precisa
echo     limpar o projeto rapidamente para testar outra coisa sem perder o rascunho.
echo.
echo  [OPCAO 6] RESOLVER / CANCELAR CONFLITO DE MERGE
echo  -----------------------------------------------------------------------------
echo  QUANDO USAR:
echo   * Se voce e o repositorio oficial alteraram exatamente a mesma linha de um
echo     mesmo arquivo e o Git pausou o merge pedindo decisao.
echo   * Voce pode usar esta opcao para desfazer o merge (voltar ao normal) ou
echo     concluir apos revisar os arquivos.
echo.
echo  [OPCAO 10] PUXAR DO SEU REPOSITORIO CUSTOM
echo  -----------------------------------------------------------------------------
echo  QUANDO USAR:
echo   * Voce subiu mudancas pelo VPS, outro PC ou diretamente no GitHub e quer
echo     baixar tudo para esta maquina local sem subir nada novo.
echo.
echo  =============================================================================
echo  DICA DE OURO PARA CONFLITO ZERO:
echo  =============================================================================
echo  * Crie suas customizacoes em pastas de extensao:
echo    - Backend:  backend/extensions/^<seu_nome^>/
echo    - Frontend: frontend/src/extensions/^<seu_nome^>/
echo  * Assim, o repositorio oficial NUNCA vai mexer nas suas pastas e o merge
echo    da Opcao [3] acontecera 100%% liso e sem nenhum conflito!
goto END_OP

:: ===============================================================================
:: OPCAO 10: PUXAR DO REPOSITORIO CUSTOM (ORIGIN -> LOCAL)
:: ===============================================================================
:OP_PULL_ORIGIN
cls
echo ===============================================================================
echo  [10] PUXAR ATUALIZACOES DO SEU REPOSITORIO CUSTOM (origin -^> local)
echo ===============================================================================
echo  Destino: github.com/jacksonfelipe/pdlpro-custom  ^| Branch: !CURRENT_BRANCH!
echo  Util quando: voce subiu mudancas pelo VPS ou outro PC e quer trazer para ca.
echo  GARANTIA: suas alteracoes locais serao preservadas antes de qualquer merge.
echo ===============================================================================
echo.

call :VALIDATE_ORIGIN
if !ERRORLEVEL! neq 0 goto END_OP

:: --- Verifica se ha alteracoes locais nao salvas ---
git status --porcelain > "%temp%\git_pdl_dirty2.txt"
set IS_DIRTY2=0
for %%A in ("%temp%\git_pdl_dirty2.txt") do if %%~zA gtr 0 set IS_DIRTY2=1
del "%temp%\git_pdl_dirty2.txt" >nul 2>&1

if !IS_DIRTY2! equ 1 (
    echo [AVISO] Voce possui alteracoes locais nao salvas:
    echo.
    git status -s
    echo.
    echo ============================================================================
    echo  Como voce quer PRESERVAR suas alteracoes antes de puxar do repositorio?
    echo ============================================================================
    echo.
    echo  [S] SALVAR em commit agora e mesclar depois ^(RECOMENDADO - nada se perde^)
    echo      Cria um commit com suas mudancas, pega o que veio do origin e mescla.
    echo      Resultado final: seu trabalho + o que veio do origin, tudo junto.
    echo.
    echo  [G] GUARDAR no Stash ^(temporario^) e restaurar apos o pull
    echo      Esconde suas mudancas, puxa do origin, e devolve suas mudancas depois.
    echo      Util para testar o que veio sem commitar ainda.
    echo.
    echo  [A] ABORTAR ^(nao faz nada, volta ao menu^)
    echo.
    set DIRTY_CHOICE=S
    set /p DIRTY_CHOICE="Escolha [S/G/A] (ENTER = S - Salvar e mesclar): "
    if "!DIRTY_CHOICE!"=="" set DIRTY_CHOICE=S

    if /i "!DIRTY_CHOICE!"=="S" (
        echo.
        set LOCAL_SAVE_MSG=
        set /p LOCAL_SAVE_MSG="Mensagem para salvar seu trabalho local (ENTER para usar a padrao): "
        if "!LOCAL_SAVE_MSG!"=="" set LOCAL_SAVE_MSG=chore: preservando trabalho local antes de puxar do origin
        echo.
        echo [1/4] Salvando suas alteracoes locais em commit...
        git add .
        git commit -m "!LOCAL_SAVE_MSG!"
        if !ERRORLEVEL! equ 0 (
            echo [OK] Suas alteracoes foram salvas com seguranca.
        ) else (
            echo [INFO] Nenhuma alteracao nova para commitar. Continuando...
        )
    ) else if /i "!DIRTY_CHOICE!"=="G" (
        echo.
        echo [1/4] Guardando suas alteracoes no Stash...
        git stash push -u -m "Stash automatico antes de pull do origin em !date! !time:~0,5!"
        if !ERRORLEVEL! equ 0 (
            echo [OK] Alteracoes guardadas. Serao restauradas apos o pull.
            set STASH_SAVED=1
        ) else (
            echo [ERRO] Nao foi possivel guardar no stash.
            goto END_OP
        )
    ) else if /i "!DIRTY_CHOICE!"=="A" (
        echo Operacao cancelada. Suas alteracoes nao foram tocadas.
        goto END_OP
    )
    echo.
) else (
    echo [OK] Workspace limpo. Nenhuma alteracao local pendente.
    echo.
)

echo [2/4] Buscando atualizacoes do seu repositorio custom (git fetch origin)...
git fetch origin
if !ERRORLEVEL! neq 0 (
    echo [ERRO] Nao foi possivel conectar ao origin. Verifique conexao ou autenticacao.
    goto END_OP
)

echo.
echo  Novidades que virao do origin/!CURRENT_BRANCH!:
git log --oneline HEAD..origin/!CURRENT_BRANCH! 2>nul
for /f %%C in ('git rev-list --count HEAD..origin/!CURRENT_BRANCH! 2^>nul') do set INCOMING=%%C
if "!INCOMING!"=="0" (
    echo  (Nenhum commit novo no origin. Seu local ja esta atualizado!)
    if defined STASH_SAVED if "!STASH_SAVED!"=="1" (
        echo.
        echo [3/4] Restaurando seu trabalho do Stash...
        git stash pop
        echo [OK] Seu trabalho foi restaurado com sucesso.
    )
    goto END_OP
)
echo.

echo [3/4] Aplicando atualizacoes do origin (git merge --no-edit)...
git merge --no-edit origin/!CURRENT_BRANCH!
if !ERRORLEVEL! neq 0 (
    echo.
    echo ============================================================================
    echo  [ATENCAO: CONFLITO DETECTADO!]
    echo ============================================================================
    echo  Arquivos em conflito:
    git status -s | findstr /R "^UU ^AA ^UD ^DU"
    echo.
    echo  O que fazer:
    echo  1. Abra os arquivos listados acima no seu editor.
    echo  2. Procure por marcadores ^<^<^<^<^<^<^< e resolva as diferencas.
    echo  3. Apos resolver, use a Opcao [6] deste menu para finalizar o merge.
    echo ============================================================================
    goto END_OP
)

:: --- Se usou stash, restaura agora ---
if defined STASH_SAVED if "!STASH_SAVED!"=="1" (
    echo.
    echo [4/4] Restaurando seu trabalho que estava no Stash...
    git stash pop
    if !ERRORLEVEL! neq 0 (
        echo.
        echo [AVISO] Conflito ao restaurar o Stash com o que veio do origin.
        echo  Seus arquivos do stash estao preservados. Use 'git stash list' para ver.
        echo  Resolva os conflitos manualmente e faca 'git stash drop' para limpar.
    ) else (
        echo [OK] Seu trabalho local foi restaurado e mesclado com sucesso.
    )
)

echo.
echo ============================================================================
echo  [SUCESSO!] Sua maquina local esta 100%% atualizada:
echo  - O que veio de: github.com/jacksonfelipe/pdlpro-custom
echo  - Suas alteracoes locais foram preservadas e mescladas
echo  Branch: !CURRENT_BRANCH!
echo ============================================================================
goto END_OP

:: ===============================================================================
:: FUNCOES AUXILIARES
:: ===============================================================================
:VALIDATE_ORIGIN
set _FOUND_ORIGIN=0
for /f "delims=" %%R in ('git remote 2^>nul') do (
    if /i "%%R"=="origin" set _FOUND_ORIGIN=1
)
if !_FOUND_ORIGIN! equ 0 (
    echo [ERRO] O remoto 'origin' nao esta configurado!
    echo Execute a opcao [7] do menu para registrar o link do seu repositorio.
    exit /b 1
)
exit /b 0

:VALIDATE_UPSTREAM
set _FOUND_UPSTREAM=0
for /f "delims=" %%R in ('git remote 2^>nul') do (
    if /i "%%R"=="upstream" set _FOUND_UPSTREAM=1
)
if !_FOUND_UPSTREAM! equ 0 (
    echo [ERRO] O remoto 'upstream' nao esta configurado!
    echo Configurando upstream automaticamente agora para https://github.com/D3NKYT0/pdlpro.git...
    git remote add upstream https://github.com/D3NKYT0/pdlpro.git
)
exit /b 0

:END_OP
echo.
echo ===============================================================================
pause
goto MENU

:EXIT_SCRIPT
cls
echo Encerrando DIMES Git Manager...
exit /b 0
