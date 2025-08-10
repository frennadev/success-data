-- =================================================================================
-- SIMPLIFIED SOLANA MOONSHOT TRACKER (Dune Compatible)
-- Tracks wallets with 1000%+ returns on individual tokens
-- =================================================================================

-- Start with DEX trades and work backwards to identify moonshots
WITH recent_tokens AS (
  -- Get tokens that have been actively traded recently
  SELECT DISTINCT
    token_address as token_mint_address,
    MIN(block_time) as first_seen,
    MAX(block_time) as last_seen
  FROM dex.trades
  WHERE blockchain = 'solana'
    AND block_time >= CURRENT_DATE - INTERVAL '90' DAY
    AND token_address IS NOT NULL
  GROUP BY token_address
  HAVING COUNT(*) >= 10 -- Filter for tokens with meaningful trading volume
),

-- Calculate wallet performance per token
wallet_token_performance AS (
  SELECT 
    rt.token_mint_address,
    rt.first_seen as launch_time,
    tr.trader as trader_wallet,
    
    -- Calculate total invested (buys) in USD
    SUM(CASE 
      WHEN tr.token_amount > 0 THEN tr.usd_amount 
      ELSE 0 
    END) as total_invested_usd,
    
    -- Calculate total received (sells) in USD  
    SUM(CASE 
      WHEN tr.token_amount < 0 THEN ABS(tr.usd_amount)
      ELSE 0 
    END) as total_received_usd,
    
    -- Calculate remaining token balance
    SUM(tr.token_amount) as current_token_balance,
    
    -- Trade metrics
    MIN(tr.block_time) as first_trade_time,
    MAX(tr.block_time) as last_trade_time,
    COUNT(*) as total_trades,
    
    -- Get latest price for unrealized value
    (SELECT token_price 
     FROM dex.trades t2 
     WHERE t2.token_address = rt.token_mint_address 
       AND t2.blockchain = 'solana'
     ORDER BY t2.block_time DESC 
     LIMIT 1) as latest_price
     
  FROM recent_tokens rt
  JOIN dex.trades tr ON rt.token_mint_address = tr.token_address
  WHERE tr.blockchain = 'solana'
    AND tr.block_time >= rt.first_seen
    AND tr.token_amount != 0
    AND tr.usd_amount > 0
  GROUP BY rt.token_mint_address, rt.first_seen, tr.trader
  HAVING SUM(CASE WHEN tr.token_amount > 0 THEN tr.usd_amount ELSE 0 END) >= 50 -- Min $50 investment
),

-- Calculate returns and identify moonshots
moonshot_calculations AS (
  SELECT 
    *,
    -- Calculate unrealized value of remaining tokens
    (current_token_balance * COALESCE(latest_price, 0)) as unrealized_value_usd,
    
    -- Total PnL = realized + unrealized
    (total_received_usd - total_invested_usd + (current_token_balance * COALESCE(latest_price, 0))) as total_pnl_usd,
    
    -- Return percentage calculation
    CASE 
      WHEN total_invested_usd > 0 THEN 
        ((total_received_usd - total_invested_usd + (current_token_balance * COALESCE(latest_price, 0))) / total_invested_usd) * 100
      ELSE 0 
    END as return_percentage,
    
    -- Time analysis
    DATE_DIFF('hour', launch_time, first_trade_time) as hours_after_launch,
    DATE_DIFF('hour', first_trade_time, last_trade_time) as hold_duration_hours
    
  FROM wallet_token_performance
)

-- =================================================================================
-- FINAL RESULTS: Individual Token Moonshots (1000%+ Returns)
-- =================================================================================

SELECT 
  trader_wallet,
  token_mint_address,
  
  -- Investment metrics
  ROUND(total_invested_usd, 2) as invested_usd,
  ROUND(total_received_usd, 2) as received_usd,
  ROUND(total_pnl_usd, 2) as profit_usd,
  ROUND(return_percentage, 2) as return_pct,
  
  -- Position details
  ROUND(current_token_balance, 0) as tokens_remaining,
  ROUND(unrealized_value_usd, 2) as unrealized_value_usd,
  total_trades,
  
  -- Timing analysis
  ROUND(hours_after_launch, 2) as hours_after_launch,
  ROUND(hold_duration_hours, 2) as hold_hours,
  
  -- Timestamps
  launch_time,
  first_trade_time,
  last_trade_time,
  
  -- Success classification
  CASE 
    WHEN return_percentage >= 10000 THEN '100x+ (10000%+)'
    WHEN return_percentage >= 5000 THEN '50-99x (5000-9999%)'
    WHEN return_percentage >= 2000 THEN '20-49x (2000-4999%)'
    WHEN return_percentage >= 1000 THEN '10-19x (1000-1999%)'
    ELSE 'Under 10x'
  END as moonshot_tier,
  
  -- Profit multiple for easy reading
  ROUND(return_percentage / 100, 1) as profit_multiple,
  
  -- Entry timing classification
  CASE 
    WHEN hours_after_launch <= 1 THEN 'Lightning Fast (<1h)'
    WHEN hours_after_launch <= 6 THEN 'Very Early (1-6h)'  
    WHEN hours_after_launch <= 24 THEN 'Early (6-24h)'
    WHEN hours_after_launch <= 168 THEN 'Within Week (1-7d)'
    ELSE 'Late Entry (>7d)'
  END as entry_timing,
  
  -- Hold strategy classification
  CASE 
    WHEN hold_duration_hours <= 1 THEN 'Scalp (<1h)'
    WHEN hold_duration_hours <= 24 THEN 'Day Trade (1-24h)'
    WHEN hold_duration_hours <= 168 THEN 'Swing (1-7d)'  
    WHEN hold_duration_hours <= 720 THEN 'Position (1-4w)'
    ELSE 'Long Hold (>4w)'
  END as hold_strategy,
  
  -- Quick links
  CONCAT('https://solscan.io/account/', trader_wallet) as wallet_link,
  CONCAT('https://solscan.io/token/', token_mint_address) as token_link

FROM moonshot_calculations
WHERE return_percentage >= 1000  -- Only show 1000%+ returns (10x+)
  AND total_invested_usd >= 50    -- Minimum meaningful investment
ORDER BY return_percentage DESC, profit_usd DESC
LIMIT 1000