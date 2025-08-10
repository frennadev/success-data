-- Solana Meme Token Trader Performance Dashboard
-- Tracks wallets with 1000%+ returns on tokens from specific launchpads

-- =================================================================================
-- QUERY 1: Token Launches from Specific Launchpads
-- =================================================================================

WITH launchpad_tokens AS (
  SELECT 
    token_mint_address,
    block_time as launch_time,
    creator_wallet,
    initial_supply,
    launchpad_type,
    CASE 
      WHEN account = '6EF8rrecthR5Dkzon8Nwu78hRvfCKubJ14M5uBEwF6P' THEN 'pump.fun'
      WHEN account = '3xxDCjN8s6MgNHwdRD6Cgg3kHunJVu2SXBpkDbF9rJ9' THEN 'letsbonk'  
      WHEN account = '7YttLkHDoNj9wyDur5pM1ejNaAvT9X4eqaYcHQqtj2G5' THEN 'bags'
      ELSE 'other'
    END as launchpad_name
  FROM solana.account_activity 
  WHERE 
    -- Pump.fun program ID
    (account = '6EF8rrecthR5Dkzon8Nwu78hRvfCKubJ14M5uBEwF6P' 
    -- LetsBonk program ID  
    OR account = '3xxDCjN8s6MgNHwdRD6Cgg3kHunJVu2SXBpkDbF9rJ9'
    -- Bags program ID
    OR account = '7YttLkHDoNj9wyDur5pM1ejNaAvT9X4eqaYcHQqtj2G5')
    AND instruction_name = 'create_token'
    AND block_time >= CURRENT_DATE - INTERVAL '90' DAY
),

-- =================================================================================
-- QUERY 2: Token Price Data and Trading Activity
-- =================================================================================

token_trades AS (
  SELECT 
    t.token_mint_address,
    tr.trader_wallet,
    tr.block_time,
    tr.instruction_name,
    tr.token_amount,
    tr.sol_amount,
    tr.price_per_token,
    tr.tx_id,
    ROW_NUMBER() OVER (PARTITION BY tr.trader_wallet, t.token_mint_address ORDER BY tr.block_time) as trade_sequence
  FROM launchpad_tokens t
  JOIN solana.dex.trades tr ON t.token_mint_address = tr.token_mint_address
  WHERE 
    tr.block_time >= t.launch_time
    AND tr.block_time <= CURRENT_TIMESTAMP
    AND tr.token_amount > 0
    AND tr.sol_amount > 0
),

-- =================================================================================  
-- QUERY 3: Calculate Wallet PnL per Token
-- =================================================================================

wallet_token_pnl AS (
  SELECT 
    lt.launchpad_name,
    lt.token_mint_address,
    tt.trader_wallet,
    lt.launch_time,
    
    -- Buy metrics
    SUM(CASE WHEN tt.instruction_name = 'buy' THEN tt.sol_amount ELSE 0 END) as total_sol_invested,
    SUM(CASE WHEN tt.instruction_name = 'buy' THEN tt.token_amount ELSE 0 END) as total_tokens_bought,
    
    -- Sell metrics  
    SUM(CASE WHEN tt.instruction_name = 'sell' THEN tt.sol_amount ELSE 0 END) as total_sol_received,
    SUM(CASE WHEN tt.instruction_name = 'sell' THEN tt.token_amount ELSE 0 END) as total_tokens_sold,
    
    -- Current position
    SUM(CASE WHEN tt.instruction_name = 'buy' THEN tt.token_amount 
             WHEN tt.instruction_name = 'sell' THEN -tt.token_amount 
             ELSE 0 END) as current_token_balance,
             
    -- Trade timing
    MIN(tt.block_time) as first_trade_time,
    MAX(tt.block_time) as last_trade_time,
    COUNT(*) as total_trades,
    
    -- Latest price for unrealized PnL calculation
    (SELECT price_per_token 
     FROM token_trades t2 
     WHERE t2.token_mint_address = tt.token_mint_address 
     ORDER BY t2.block_time DESC 
     LIMIT 1) as latest_price
     
  FROM launchpad_tokens lt
  JOIN token_trades tt ON lt.token_mint_address = tt.token_mint_address
  GROUP BY lt.launchpad_name, lt.token_mint_address, tt.trader_wallet, lt.launch_time
  HAVING SUM(CASE WHEN tt.instruction_name = 'buy' THEN tt.sol_amount ELSE 0 END) > 0
),

-- =================================================================================
-- QUERY 4: Calculate Returns and Filter High Performers
-- =================================================================================

high_performer_wallets AS (
  SELECT 
    *,
    -- Realized PnL
    (total_sol_received - total_sol_invested) as realized_pnl_sol,
    
    -- Unrealized PnL (for remaining tokens)
    (current_token_balance * COALESCE(latest_price, 0)) as unrealized_value_sol,
    
    -- Total PnL
    (total_sol_received - total_sol_invested + (current_token_balance * COALESCE(latest_price, 0))) as total_pnl_sol,
    
    -- Return percentage
    CASE 
      WHEN total_sol_invested > 0 THEN 
        ((total_sol_received - total_sol_invested + (current_token_balance * COALESCE(latest_price, 0))) / total_sol_invested) * 100
      ELSE 0 
    END as return_percentage,
    
    -- Trade duration
    EXTRACT(EPOCH FROM (last_trade_time - first_trade_time)) / 3600 as trade_duration_hours
    
  FROM wallet_token_pnl
  WHERE total_sol_invested >= 0.1  -- Minimum investment threshold
)

-- =================================================================================
-- MAIN QUERY: Individual Token Moonshots (1000%+ Returns Per Token)
-- =================================================================================

SELECT 
  launchpad_name,
  trader_wallet,
  token_mint_address,
  total_sol_invested,
  total_sol_received,
  current_token_balance,
  total_pnl_sol,
  ROUND(return_percentage, 2) as return_pct,
  total_trades,
  ROUND(trade_duration_hours, 2) as duration_hours,
  first_trade_time,
  last_trade_time,
  launch_time,
  
  -- Individual token success metrics
  CASE 
    WHEN return_percentage >= 10000 THEN '10000%+ (100x)'
    WHEN return_percentage >= 5000 THEN '5000-9999% (50-99x)'
    WHEN return_percentage >= 2000 THEN '2000-4999% (20-49x)'
    WHEN return_percentage >= 1000 THEN '1000-1999% (10-19x)'
    ELSE '<1000%'
  END as moonshot_tier,
  
  -- Time to profit analysis
  EXTRACT(EPOCH FROM (first_trade_time - launch_time)) / 3600 as hours_after_launch,
  
  -- Individual trade context
  CONCAT('https://solscan.io/account/', trader_wallet) as wallet_link,
  CONCAT('https://solscan.io/token/', token_mint_address) as token_link
  
FROM high_performer_wallets
WHERE return_percentage >= 1000  -- Each row = 1000%+ return on ONE specific token
  AND total_sol_invested >= 0.05  -- Minimum meaningful investment
ORDER BY return_percentage DESC, total_pnl_sol DESC
LIMIT 1000;