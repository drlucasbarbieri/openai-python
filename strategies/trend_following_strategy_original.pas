{ ============================================================================
  Estratégia Original (antes da otimização) - mantido para referência
  ============================================================================ }

begin

  {Compra quando:
   - Fechamento acima de todas as médias (21, 50, 200, 300)
   - "MACD positivo" (proxy: MediaExp(14) > MediaExp(105))
   - Estocástico entre 25 e 75
   - RSI entre 30 e 70
   - ADX > 20 (tendência definida)
   - Horário permitido}

  if (Close > MediaExp(21, Close)) and
     (MediaExp(21, Close) > MediaExp(50, Close)) and
     (MediaExp(50, Close) > MediaExp(200, Close)) and
     (MediaExp(200, Close) > MediaExp(300, Close)) and
     (MediaExp(14, Close) > MediaExp(105, Close)) and
     (SlowStochastic(14, 3, 1) > 25) and
     (SlowStochastic(14, 3, 1) < 75) and
     (RSI(14, 0) > 30) and
     (RSI(14, 0) < 70) and
     (ADX(14, 14) > 20) and
     (Time >= 945) and
     (Time <= 1715) then
  begin
    if (IsSold) then
      ReversePosition
    else if (not HasPosition) then
      BuyAtMarket(2);
  end;

  {Venda quando:
   - Fechamento abaixo de todas as médias
   - "MACD negativo" (proxy: MediaExp(14) < MediaExp(105))
   - Condições opostas à compra}

  if (Close < MediaExp(21, Close)) and
     (MediaExp(21, Close) < MediaExp(50, Close)) and
     (MediaExp(50, Close) < MediaExp(200, Close)) and
     (MediaExp(200, Close) < MediaExp(300, Close)) and
     (MediaExp(14, Close) < MediaExp(105, Close)) and
     (SlowStochastic(14, 3, 1) > 25) and
     (SlowStochastic(14, 3, 1) < 75) and
     (RSI(14, 0) > 30) and
     (RSI(14, 0) < 70) and
     (ADX(14, 14) > 20) and
     (Time >= 945) and
     (Time <= 1715) then
  begin
    if (IsBought) then
      ReversePosition
    else if (not HasPosition) then
      SellShortAtMarket(2);
  end;

  {Saída por lateralidade - ADX < 20}
  if (ADX(14, 14) < 20) then
  begin
    if (IsBought) then
      SellToCoverAtMarket
    else if (IsSold) then
      BuyToCoverAtMarket;
  end;

  {Saída no fim do pregão}
  if (Time > 1700) then
  begin
    if (IsBought) then
      SellToCoverAtMarket
    else if (IsSold) then
      BuyToCoverAtMarket;
  end;

end;
