#Include "TOTVS.CH"

/*/{Protheus.doc} AfterLogin
Ponto de Entrada executado apos o login do usuario e abertura das tabelas SXs
(e a cada abertura de modulo no SIGAMDI).
Verifica na tabela SCR quantos Pedidos de Compra estao pendentes de aprovacao
para o usuario logado e exibe um alerta informativo.

@type       function
@author     Diego Santana
@since      16/10/2026
@version    12.1.2510
@param      ParamIXB, array, [1] = ID do Usuario (Caractere), [2] = Nome do Usuario (Caractere)
@return     logical, .T. para prosseguir normalmente
@see        https://centraldeatendimento.totvs.com/hc/pt-br/articles/360028988131
/*/
User Function AfterLogin()
    Local aArea      := FWGetArea()
    Local cIdUsr     := ""
    Local cNomeUsr   := ""
    Local nQtdFilial := 0
    Local nQtdTotal  := 0
    Local cMensagem  := ""

    // Evita execucao em processamento sem interface (Jobs, RPC, REST, Schedule)
    If IsBlind()
        Return .T.
    EndIf

    // Recupera o codigo e nome do usuario via ParamIXB ou funcoes padrao do Framework
    If Type("ParamIXB") == "A" .And. Len(ParamIXB) >= 2
        cIdUsr   := AllTrim(ParamIXB[1])
        cNomeUsr := AllTrim(ParamIXB[2])
    Else
        cIdUsr   := RetCodUsr()
        cNomeUsr := UsrRetName(cIdUsr)
    EndIf

    // Opcional: Descomente a linha abaixo caso deseje exibir apenas ao entrar no modulo de Compras (SIGACOM)
    // If cModulo != "COM" ; Return .T. ; EndIf

    // Consulta quantidade de pedidos pendentes para o aprovador (Filial Atual e Todas as Filiais)
    fQtdPedPend(cIdUsr, @nQtdFilial, @nQtdTotal)

    // Exibe mensagem apenas se o usuario possuir pedidos aguardando sua aprovacao (CR_STATUS = '02')
    If nQtdTotal > 0
        cMensagem := "Olá, <b>" + cNomeUsr + "</b>!<br><br>"
        cMensagem += "Você possui <b>" + cValToChar(nQtdFilial) + "</b> pedido(s) de compra aguardando sua aprovação na filial atual (<b>" + cFilAnt + "</b>)."

        If nQtdTotal > nQtdFilial
            cMensagem += "<br>Total considerando todas as filiais do grupo: <b>" + cValToChar(nQtdTotal) + "</b> pedido(s) pendente(s)."
        EndIf

        cMensagem += "<br><br>Acesse a rotina <b>Liberação de Documentos (MATA094)</b> para analisá-los."

        FWAlertInfo(cMensagem, "Aprovações Pendentes")
    EndIf

    FWRestArea(aArea)
Return .T.

/*/{Protheus.doc} fQtdPedPend
Consulta na tabela SCR (Documentos com Alcada) a quantidade distinta de Pedidos de Compra
com status '02' (Pendente / Aguardando aprovacao do nivel atual) para o usuario.
Contempla alcada por Pedido de Compra ('PC') e por Item de Pedido ('IP').

@type       function
@param      cIdUsr, character, Codigo do usuario aprovador (6 posicoes)
@param      nQtdFilial, numeric, Quantidade pendente na filial atual (passado por referencia)
@param      nQtdTotal, numeric, Quantidade pendente em todas as filiais (passado por referencia)
@return     nil, nulo
/*/
Static Function fQtdPedPend(cIdUsr, nQtdFilial, nQtdTotal)
    Local cQuery     := ""
    Local cAliasQry  := ""
    Local cFilSCR    := FWxFilial("SCR")
    Local cUsrPad    := PadR(cIdUsr, TamSX3("CR_USER")[1])

    nQtdFilial := 0
    nQtdTotal  := 0

    // Conta documentos distintos (CR_FILIAL + CR_NUM) para nao duplicar contagem quando a alcada for por item ('IP')
    cQuery := " SELECT "
    cQuery += "     CR_FILIAL, "
    cQuery += "     COUNT(DISTINCT CR_NUM) AS QTD_PED "
    cQuery += " FROM " + RetSqlName("SCR") + " SCR "
    cQuery += " WHERE SCR.CR_USER = '" + cUsrPad + "' "
    cQuery += "   AND SCR.CR_STATUS = '02' "
    cQuery += "   AND SCR.CR_TIPO IN ('PC', 'IP') "
    cQuery += "   AND SCR.D_E_L_E_T_ = ' ' "
    cQuery += " GROUP BY CR_FILIAL "

    cQuery    := ChangeQuery(cQuery)
    cAliasQry := MpSysOpenQuery(cQuery)

    While (cAliasQry)->(!EoF())
        nQtdTotal += (cAliasQry)->QTD_PED
        If AllTrim((cAliasQry)->CR_FILIAL) == AllTrim(cFilSCR)
            nQtdFilial += (cAliasQry)->QTD_PED
        EndIf
        (cAliasQry)->(DbSkip())
    EndDo

    (cAliasQry)->(DbCloseArea())
Return Nil
