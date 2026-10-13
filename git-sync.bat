@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title PDL PRO - Gerenciador Git Custom & Upstream

:: Garante que o script roda a partir da pasta raiz do projeto
cd /d "%~dp0"

:CHECK_GIT
where git >nul 2>&1
if %ERRORLEVEL% neq 0 (
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
echo            PDL PRO - SINCRONIZADOR GIT (CUSTOM ^& UPSTREAM)
echo ===============================================================================
echo  Branch Ativa: [!CURRENT_BRANCH!]
echo  Remoto Pessoal  (origin)   : !HAS_ORIGIN! (1 = Configurado, 0 = Ausente)
echo  Remoto Oficial  (upstream) : !HAS_UPSTREAM! (1 = Configurado, 0 = Ausente)
echo ===============================================================================
echo.
echo  [1] SALVAR E ENVIAR TUDO (Commit + Push para seu repositorio 'origin')
echo  [2] PUXAR ATUALIZACOES OFICIAIS (Fetch + Merge de 'upstream/!CURRENT_BRANCH!')
echo  [3] SINCRONIZACAO COMPLETA (Commit Local -^> Puxar Upstream -^> Enviar Origin)
echo  [4] VER STATUS DETALHADO (Arquivos alterados, branches e diferencas)
echo  [5] GUARDAR / RECUPERAR ALTERACOES (Git Stash / Stash Pop)
echo  [6] RESOLVER / CANCELAR CONFLITO DE MERGE (Abortar ou listar conflitos)
echo  [7] DIAGNOSTICO E CONFIGURACAO DE REMOTOS (Ver/Corrigir links origin e upstream)
echo  [8] VER HISTORICO RECENTE DE COMMITS
echo.
echo  [0] SAIR
echo ===============================================================================
set OPTION=
set /p OPTION="Escolha uma opcao [0-8]: "

if "%OPTION%"=="1" goto OP_COMMIT_PUSH
if "%OPTION%"=="2" goto OP_PULL_UPSTREAM
if "%OPTION%"=="3" goto OP_FULL_SYNC
if "%OPTION%"=="4" goto OP_STATUS
if "%OPTION%"=="5" goto OP_STASH
if "%OPTION%"=="6" goto OP_RESOLVE_MERGE
if "%OPTION%"=="7" goto OP_DIAGNOSTIC
if "%OPTION%"=="8" goto OP_LOG
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
if %ERRORLEVEL% neq 0 goto END_OP

echo  Verificando alteracoes pendentes...
git status --short
echo.

set /p COMMIT_MSG="Digite a mensagem do commit (Pressione ENTER para usar a padrao): "
if "!COMMIT_MSG!"=="" set COMMIT_MSG=feat: atualizacoes customizadas em !date! !time:~0,5!

echo.
echo [1/3] Adicionando todos os arquivos (git add .)...
git add .
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Falha ao adicionar arquivos. Verifique permissoes de arquivo.
    goto END_OP
)

echo [2/3] Criando commit...
git commit -m "!COMMIT_MSG!"
set COMMIT_RET=%ERRORLEVEL%
if !COMMIT_RET! neq 0 (
    echo.
    echo [INFO] Nenhuma nova alteracao encontrada para commitar.
) else (
    echo [OK] Commit criado com sucesso: "!COMMIT_MSG!"
)

echo.
echo [3/3] Enviando para origin/!CURRENT_BRANCH! (git push origin !CURRENT_BRANCH!)...
git push origin !CURRENT_BRANCH!
if %ERRORLEVEL% neq 0 (
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
if %ERRORLEVEL% neq 0 goto END_OP

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
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERRO] Nao foi possivel conectar ao upstream. Verifique sua conexao ou o link do repositorio.
    goto END_OP
)

echo.
echo [3/3] Mesclando atualizacoes (git merge upstream/!CURRENT_BRANCH!)...
git merge upstream/!CURRENT_BRANCH!
if %ERRORLEVEL% neq 0 (
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
if %ERRORLEVEL% neq 0 goto END_OP
call :VALIDATE_UPSTREAM
if %ERRORLEVEL% neq 0 goto END_OP

echo [PASSO 1/3] Salvando alteracoes locais...
git add .
git commit -m "chore: sincronizacao automatica - preservando customizacoes locais" >nul 2>&1

echo.
echo [PASSO 2/3] Baixando novidades do oficial (upstream)...
git fetch upstream
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Falha ao fazer fetch do upstream.
    goto END_OP
)

git merge upstream/!CURRENT_BRANCH!
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERRO] Ocorreu um conflito ao mesclar com upstream.
    echo O processo foi pausado para voce resolver os conflitos.
    echo Veja a opcao [6] do menu para detalhes.
    goto END_OP
)

echo.
echo [PASSO 3/3] Enviando tudo para o seu origin (origin/!CURRENT_BRANCH!)...
git push origin !CURRENT_BRANCH!
if %ERRORLEVEL% neq 0 (
    git push -u origin !CURRENT_BRANCH!
)

if %ERRORLEVEL% equ 0 (
    echo.
    echo ============================================================================
    echo  [SUCESSO COMPLETO!]
    echo  Seu repositorio privado agora possui tanto as suas customizacoes
    echo  quanto as ultimas atualizacoes do PDL PRO oficial!
    echo ============================================================================
) else (
    echo.
    echo [ERRO] Falha ao enviar para o origin. Verifique a conexao e autenticacao.
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
if %ERRORLEVEL% neq 0 (
    echo Nao foi possivel ler o status.
)
echo.
echo [DIFERENCA DE COMMITS COM ORIGIN]:
git log --oneline origin/!CURRENT_BRANCH!..HEAD 2>nul
if %ERRORLEVEL% equ 0 (
    echo (Commits listados acima existem localmente mas ainda nao foram enviados ao origin)
) else (
    echo (origin/!CURRENT_BRANCH! ainda nao possui tracking ativo)
)
echo.
echo [DIFERENCA DE COMMITS COM UPSTREAM]:
git log --oneline HEAD..upstream/!CURRENT_BRANCH! 2>nul
if %ERRORLEVEL% equ 0 (
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
    if %ERRORLEVEL% neq 0 (
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
    if %ERRORLEVEL% equ 0 (
        echo [OK] Merge cancelado com sucesso. O projeto voltou ao estado original.
    ) else (
        echo [INFO] Nao ha nenhum merge ativo para cancelar.
    )
) else if "%MERGE_OPT%"=="2" (
    git add .
    git commit -m "merge: resolucao de conflitos com upstream/!CURRENT_BRANCH!"
    if %ERRORLEVEL% equ 0 (
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
:: FUNCOES AUXILIARES
:: ===============================================================================
:VALIDATE_ORIGIN
git remote | findstr /X "origin" >nul
if %ERRORLEVEL% neq 0 (
    echo [ERRO] O remoto 'origin' nao esta configurado!
    echo Execute a opcao [7] do menu para registrar o link do seu repositorio.
    exit /b 1
)
exit /b 0

:VALIDATE_UPSTREAM
git remote | findstr /X "upstream" >nul
if %ERRORLEVEL% neq 0 (
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
echo Encerrando PDL PRO Git Manager...
exit /b 0
