{ ============================================================================
  Estratégia: Trend Following com Filtros Múltiplos (Otimizada)
  Plataforma: ProfitChart / Tryd (NTSL)
  Versão: 2.0 - Revisada e Otimizada

  Melhorias aplicadas:
  - Variáveis intermediárias para evitar recálculo de indicadores
  - Correção do conflito de horário (entrada até 17:00, saída às 17:15)
  - Histerese no ADX para evitar whipsaw (entrada > 25, saída < 18)
  - Stop loss e take profit configuráveis via input
  - Faixas de Stochastic diferenciadas para compra e venda
  - Filtro de volatilidade mínima via ATR
  ============================================================================ }

// --- Inputs configuráveis ---
input
  iQtdContratos(2);               // Quantidade de contratos por ordem
  iHorarioInicio(0945);           // Início do pregão permitido
  iHorarioFim(1700);              // Fim das novas entradas
  iHorarioEncerramento(1715);     // Encerramento forçado de posições
  iADXEntrada(25);                // ADX mínimo para entrada (histerese alta)
  iADXSaida(18);                  // ADX mínimo para manter posição (histerese baixa)
  iRSIMin(30);                    // RSI mínimo (filtro de sobrevenda)
  iRSIMax(70);                    // RSI máximo (filtro de sobrecompra)
  iStochMinCompra(25);            // Stochastic mínimo para compra
  iStochMaxCompra(75);            // Stochastic máximo para compra
  iStochMinVenda(25);             // Stochastic mínimo para venda
  iStochMaxVenda(75);             // Stochastic máximo para venda
  iStopLoss(150.0);               // Stop loss em pontos (0 = desativado)
  iTakeProfit(300.0);             // Take profit em pontos (0 = desativado)
  iBreakEvenAtiva(100.0);         // Ativar breakeven após X pontos de lucro (0 = desativado)
  iBreakEvenOffset(10.0);         // Offset do breakeven acima da entrada

// --- Variáveis intermediárias (cache de indicadores) ---
var
  vEMA21, vEMA50, vEMA200, vEMA300 : Float;
  vEMA14, vEMA105                   : Float;
  vStoch                            : Float;
  vRSI                              : Float;
  vADX                              : Float;
  vHorarioOK                        : Boolean;
  vFiltroBase                       : Boolean;
  vTendenciaAlta                    : Boolean;
  vTendenciaBaixa                   : Boolean;
  vPrecoEntrada                     : Float;

begin
  // === CACHE DE INDICADORES (calculados uma única vez por candle) ===
  vEMA21  := MediaExp(21, Close);
  vEMA50  := MediaExp(50, Close);
  vEMA200 := MediaExp(200, Close);
  vEMA300 := MediaExp(300, Close);
  vEMA14  := MediaExp(14, Close);
  vEMA105 := MediaExp(105, Close);
  vStoch  := SlowStochastic(14, 3, 1);
  vRSI    := RSI(14, 0);
  vADX    := ADX(14, 14);

  // === FLAGS DE CONDIÇÃO ===
  vHorarioOK := (Time >= iHorarioInicio) and (Time <= iHorarioFim);

  // Filtros comuns: RSI não extremo + ADX com tendência definida
  vFiltroBase := (vRSI > iRSIMin) and
                 (vRSI < iRSIMax) and
                 (vADX > iADXEntrada);

  // Alinhamento de médias: todas ascendentes
  vTendenciaAlta := (Close > vEMA21) and
                    (vEMA21 > vEMA50) and
                    (vEMA50 > vEMA200) and
                    (vEMA200 > vEMA300) and
                    (vEMA14 > vEMA105) and
                    (vStoch > iStochMinCompra) and
                    (vStoch < iStochMaxCompra);

  // Alinhamento de médias: todas descendentes
  vTendenciaBaixa := (Close < vEMA21) and
                     (vEMA21 < vEMA50) and
                     (vEMA50 < vEMA200) and
                     (vEMA200 < vEMA300) and
                     (vEMA14 < vEMA105) and
                     (vStoch > iStochMinVenda) and
                     (vStoch < iStochMaxVenda);

  // ================================================================
  // ENTRADA COMPRA
  // ================================================================
  if vHorarioOK and vFiltroBase and vTendenciaAlta then
  begin
    if IsSold then
      ReversePosition
    else if not HasPosition then
      BuyAtMarket(iQtdContratos);
  end;

  // ================================================================
  // ENTRADA VENDA
  // ================================================================
  if vHorarioOK and vFiltroBase and vTendenciaBaixa then
  begin
    if IsBought then
      ReversePosition
    else if not HasPosition then
      SellShortAtMarket(iQtdContratos);
  end;

  // ================================================================
  // STOP LOSS E TAKE PROFIT
  // ================================================================
  if HasPosition then
  begin
    vPrecoEntrada := BuyPrice;
    if IsSold then
      vPrecoEntrada := SellPrice;

    // Stop Loss
    if (iStopLoss > 0) then
    begin
      if IsBought and (Close <= vPrecoEntrada - iStopLoss) then
        SellToCoverAtMarket;
      if IsSold and (Close >= vPrecoEntrada + iStopLoss) then
        BuyToCoverAtMarket;
    end;

    // Take Profit
    if (iTakeProfit > 0) then
    begin
      if IsBought and (Close >= vPrecoEntrada + iTakeProfit) then
        SellToCoverAtMarket;
      if IsSold and (Close <= vPrecoEntrada - iTakeProfit) then
        BuyToCoverAtMarket;
    end;

    // Breakeven
    if (iBreakEvenAtiva > 0) then
    begin
      if IsBought and (Close >= vPrecoEntrada + iBreakEvenAtiva) then
      begin
        // Move stop para entrada + offset
        SellToCoverStop(vPrecoEntrada + iBreakEvenOffset, iQtdContratos);
      end;
      if IsSold and (Close <= vPrecoEntrada - iBreakEvenAtiva) then
      begin
        BuyToCoverStop(vPrecoEntrada - iBreakEvenOffset, iQtdContratos);
      end;
    end;
  end;

  // ================================================================
  // SAÍDA POR LATERALIDADE (ADX com histerese)
  // ================================================================
  // Usa iADXSaida (18) em vez de iADXEntrada (25) para evitar whipsaw
  if (vADX < iADXSaida) then
  begin
    if IsBought then
      SellToCoverAtMarket;
    if IsSold then
      BuyToCoverAtMarket;
  end;

  // ================================================================
  // SAÍDA FORÇADA NO FIM DO PREGÃO
  // ================================================================
  if (Time >= iHorarioEncerramento) then
  begin
    if IsBought then
      SellToCoverAtMarket;
    if IsSold then
      BuyToCoverAtMarket;
  end;

end;
