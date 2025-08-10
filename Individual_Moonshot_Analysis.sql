-- =================================================================================
-- INDIVIDUAL MOONSHOT TRADES ANALYSIS
-- Tracks wallets that make 1000%+ on INDIVIDUAL tokens (not cumulative)
-- =================================================================================

-- QUERY 1: Individual Moonshot Trades (1000%+ per single token)
-- =================================================================================

WITH launchpad_tokens AS (
  SELECT 
    token_mint_address,
    block_time as launch_time,
    creator_wallet,
    CASE 
      WHEN account = '6EF8rrecthR5Dkzon8Nwu78hRvfCKubJ14M5uBEwF6P' THEN 'pump.fun'
      WHEN account = '3xxDCjN8s6MgNHwdRD6Cgg3kHunJVu2SXBpkDbF9rJ9' THEN 'letsbonk'  
      WHEN account = '7YttLkHDoNj9wyDur5pM1ejNaAvT9X4eqaYcHQqtj2G5' THEN 'bags'
      ELSE 'other'
    END as launchpad_name
  FROM solana.account_activity 
  WHERE 
    (account = '6EF8rrecthR5Dkzon8Nwu78hRvfCKubJ14M5uBEwF6P' 
    OR account = '3xxDCjN8s6MgNHwdRD6Cgg3kHunJVu2SXBpkDbF9rJ9'
    OR account = '7YttLkHDoNj9wyDur5pM1ejNaAvT9X4eqaYcHQqtj2G5')
    AND instruction_name = 'create_token'
    AND block_time >= CURRENT_DATE - INTERVAL '90' DAY
),

-- Calculate PnL for each wallet per individual token
individual_token_performance AS (
  SELECT 
    lt.launchpad_name,
    lt.token_mint_address,
    lt.launch_time,
    tr.trader_wallet,
    
    -- Investment metrics for THIS specific token only
    SUM(CASE WHEN tr.instruction_name = 'buy' THEN tr.sol_amount ELSE 0 END) as sol_invested,
    SUM(CASE WHEN tr.instruction_name = 'buy' THEN tr.token_amount ELSE 0 END) as tokens_bought,
    
    -- Returns from THIS specific token only  
    SUM(CASE WHEN tr.instruction_name = 'sell' THEN tr.sol_amount ELSE 0 END) as sol_received,
    SUM(CASE WHEN tr.instruction_name = 'sell' THEN tr.token_amount ELSE 0 END) as tokens_sold,
    
    -- Current position in THIS token
    SUM(CASE WHEN tr.instruction_name = 'buy' THEN tr.token_amount 
             WHEN tr.instruction_name = 'sell' THEN -tr.token_amount 
             ELSE 0 END) as current_balance,
             
    -- Trading activity for THIS token
    MIN(tr.block_time) as first_trade,
    MAX(tr.block_time) as last_trade,
    COUNT(*) as trade_count,
    
    -- Latest price for unrealized gains
    (SELECT price_per_token 
     FROM solana.dex.trades t2 
     WHERE t2.token_mint_address = lt.token_mint_address 
     ORDER BY t2.block_time DESC 
     LIMIT 1) as current_price
     
  FROM launchpad_tokens lt
  JOIN solana.dex.trades tr ON lt.token_mint_address = tr.token_mint_address
  WHERE tr.block_time >= lt.launch_time
    AND tr.token_amount > 0
    AND tr.sol_amount > 0
  GROUP BY lt.launchpad_name, lt.token_mint_address, lt.launch_time, tr.trader_wallet
  HAVING SUM(CASE WHEN tr.instruction_name = 'buy' THEN tr.sol_amount ELSE 0 END) >= 0.05 -- Min 0.05 SOL investment
),

-- Calculate returns for each individual token position
moonshot_calculations AS (
  SELECT 
    *,
    -- Realized profit/loss
    (sol_received - sol_invested) as realized_pnl,
    
    -- Unrealized value of remaining tokens
    (current_balance * COALESCE(current_price, 0)) as unrealized_value,
    
    -- Total PnL for this specific token
    (sol_received - sol_invested + (current_balance * COALESCE(current_price, 0))) as total_pnl,
    
    -- Return percentage for THIS TOKEN ONLY
    CASE 
      WHEN sol_invested > 0 THEN 
        ((sol_received - sol_invested + (current_balance * COALESCE(current_price, 0))) / sol_invested) * 100
      ELSE 0 
    END as token_return_pct,
    
    -- Time metrics
    DATE_DIFF('hour', first_trade, last_trade) as hold_duration_hours,
    DATE_DIFF('hour', launch_time, first_trade) as entry_delay_hours
    
  FROM individual_token_performance
)

-- =================================================================================
-- FINAL RESULT: Individual Token Moonshots (1000%+ per token)
-- =================================================================================

SELECT 
  launchpad_name,
  trader_wallet,
  token_mint_address,
  
  -- Investment details for this specific token
  ROUND(sol_invested, 4) as sol_invested,
  ROUND(sol_received, 4) as sol_received, 
  ROUND(current_balance, 2) as tokens_remaining,
  ROUND(total_pnl, 4) as profit_sol,
  ROUND(token_return_pct, 2) as return_percentage,
  
  -- Trading activity
  trade_count,
  ROUND(hold_duration_hours, 2) as hold_hours,
  ROUND(entry_delay_hours, 2) as hours_after_launch,
  
  -- Timestamps
  launch_time,
  first_trade,
  last_trade,
  
  -- Success classification
  CASE 
    WHEN token_return_pct >= 10000 THEN '100x+ (10000%+)'
    WHEN token_return_pct >= 5000 THEN '50-99x (5000-9999%)'
    WHEN token_return_pct >= 2000 THEN '20-49x (2000-4999%)'
    WHEN token_return_pct >= 1000 THEN '10-19x (1000-1999%)'
    ELSE 'Under 10x'
  END as moonshot_category,
  
  -- Profit multiple (easier to understand)
  ROUND(token_return_pct / 100, 1) as profit_multiple,
  
  -- Quick analysis
  CASE 
    WHEN entry_delay_hours <= 1 THEN 'Lightning Fast (<1h)'
    WHEN entry_delay_hours <= 6 THEN 'Very Early (1-6h)'  
    WHEN entry_delay_hours <= 24 THEN 'Early (6-24h)'
    WHEN entry_delay_hours <= 168 THEN 'Within Week (1-7d)'
    ELSE 'Late Entry (>7d)'
  END as entry_timing,
  
  CASE 
    WHEN hold_duration_hours <= 1 THEN 'Scalp (<1h)'
    WHEN hold_duration_hours <= 24 THEN 'Day Trade (1-24h)'
    WHEN hold_duration_hours <= 168 THEN 'Swing (1-7d)'  
    WHEN hold_duration_hours <= 720 THEN 'Position (1-4w)'
    ELSE 'Long Hold (>4w)'
  END as hold_strategy

FROM moonshot_calculations
WHERE token_return_pct >= 1000  -- Only 1000%+ returns on individual tokens
ORDER BY token_return_pct DESC, profit_sol DESC
LIMIT 500;

-- =================================================================================
-- QUERY 2: Moonshot Wallet Summary (Wallets with multiple 1000%+ tokens)
-- =================================================================================

WITH moonshot_trades AS (
  -- Use results from above query
  SELECT * FROM moonshot_calculations WHERE token_return_pct >= 1000
),

wallet_moonshot_summary AS (
  SELECT 
    trader_wallet,
    launchpad_name,
    
    -- Count of moonshot tokens per wallet
    COUNT(*) as moonshot_count,
    COUNT(CASE WHEN token_return_pct >= 10000 THEN 1 END) as ultra_moonshots_100x,
    COUNT(CASE WHEN token_return_pct >= 5000 THEN 1 END) as super_moonshots_50x,
    
    -- Financial performance across moonshots
    SUM(sol_invested) as total_moonshot_investment,
    SUM(total_pnl) as total_moonshot_profit,
    AVG(token_return_pct) as avg_moonshot_return,
    MAX(token_return_pct) as best_moonshot_return,
    
    -- Timing patterns
    AVG(entry_delay_hours) as avg_entry_timing,
    AVG(hold_duration_hours) as avg_hold_time,
    
    -- Recent activity
    MAX(last_trade) as latest_moonshot_trade,
    MIN(first_trade) as first_moonshot_trade
    
  FROM moonshot_trades
  GROUP BY trader_wallet, launchpad_name
)

SELECT 
  *,
  -- Wallet classification
  CASE 
    WHEN moonshot_count >= 10 THEN 'Serial Moonshotter (10+)'
    WHEN moonshot_count >= 5 THEN 'Frequent Moonshotter (5-9)'
    WHEN moonshot_count >= 3 THEN 'Regular Moonshotter (3-4)'
    WHEN moonshot_count >= 2 THEN 'Occasional Moonshotter (2)'
    ELSE 'One-Hit Wonder (1)'
  END as wallet_type,
  
  -- Success rate indicator
  ROUND(total_moonshot_profit / total_moonshot_investment, 2) as overall_roi_multiple,
  
  -- Rank by different metrics
  RANK() OVER (ORDER BY total_moonshot_profit DESC) as profit_rank,
  RANK() OVER (ORDER BY moonshot_count DESC) as frequency_rank,
  RANK() OVER (ORDER BY best_moonshot_return DESC) as peak_performance_rank

FROM wallet_moonshot_summary
WHERE moonshot_count >= 1
ORDER BY total_moonshot_profit DESC;

-- =================================================================================
-- QUERY 3: Token Analysis - Which tokens created the most moonshots
-- =================================================================================

SELECT 
  launchpad_name,
  token_mint_address,
  launch_time,
  
  -- Moonshot metrics
  COUNT(*) as total_moonshot_traders,
  COUNT(CASE WHEN token_return_pct >= 10000 THEN 1 END) as traders_100x_plus,
  COUNT(CASE WHEN token_return_pct >= 5000 THEN 1 END) as traders_50x_plus,
  
  -- Financial impact
  SUM(sol_invested) as total_investment_volume,
  SUM(total_pnl) as total_profits_created,
  AVG(token_return_pct) as avg_trader_return,
  MAX(token_return_pct) as highest_individual_return,
  
  -- Entry patterns
  AVG(entry_delay_hours) as avg_entry_delay,
  MIN(entry_delay_hours) as fastest_entry,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY entry_delay_hours) as median_entry_delay,
  
  -- Success distribution  
  COUNT(*) * 100.0 / (
    SELECT COUNT(DISTINCT trader_wallet) 
    FROM solana.dex.trades tr2 
    WHERE tr2.token_mint_address = mc.token_mint_address
  ) as moonshot_trader_percentage

FROM moonshot_calculations mc
WHERE token_return_pct >= 1000
GROUP BY launchpad_name, token_mint_address, launch_time
HAVING COUNT(*) >= 3  -- At least 3 moonshot traders
ORDER BY total_moonshot_traders DESC, total_profits_created DESC;