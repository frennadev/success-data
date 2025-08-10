-- =================================================================================
-- SERIAL MOONSHOTTER ANALYSIS
-- Identifies wallets with multiple 1000%+ token hits
-- =================================================================================

-- First run the main moonshot query to get individual results, then use this for summary

WITH moonshot_data AS (
  -- This would reference results from the main Simplified_Moonshot_Tracker query
  -- For now, we'll use a simplified version to demonstrate the concept
  
  SELECT 
    trader_wallet,
    token_mint_address,
    return_percentage,
    total_invested_usd,
    total_pnl_usd,
    first_trade_time,
    last_trade_time
  FROM (
    -- Insert the main moonshot calculation logic here
    -- Or create this as a separate query after running the main one
    SELECT 
      '11111111111111111111111111111111' as trader_wallet,  -- Example data
      'TokenABC' as token_mint_address,
      2500.0 as return_percentage,
      100.0 as total_invested_usd,
      2500.0 as total_pnl_usd,
      CURRENT_TIMESTAMP as first_trade_time,
      CURRENT_TIMESTAMP as last_trade_time
    WHERE 1=0 -- This is just example structure
  ) dummy_data
),

wallet_summary AS (
  SELECT 
    trader_wallet,
    COUNT(*) as moonshot_count,
    SUM(total_invested_usd) as total_invested,
    SUM(total_pnl_usd) as total_profit,
    AVG(return_percentage) as avg_return,
    MAX(return_percentage) as best_return,
    MIN(first_trade_time) as first_moonshot,
    MAX(last_trade_time) as latest_moonshot
  FROM moonshot_data
  WHERE return_percentage >= 1000
  GROUP BY trader_wallet
)

SELECT 
  trader_wallet,
  moonshot_count,
  ROUND(total_invested, 2) as total_invested_usd,
  ROUND(total_profit, 2) as total_profit_usd,
  ROUND(avg_return, 2) as avg_return_pct,
  ROUND(best_return, 2) as best_return_pct,
  CASE 
    WHEN moonshot_count >= 10 THEN 'Serial Moonshotter (10+)'
    WHEN moonshot_count >= 5 THEN 'Frequent Moonshotter (5-9)'
    WHEN moonshot_count >= 3 THEN 'Regular Moonshotter (3-4)'
    WHEN moonshot_count >= 2 THEN 'Occasional Moonshotter (2)'
    ELSE 'One-Hit Wonder (1)'
  END as trader_type,
  first_moonshot,
  latest_moonshot
FROM wallet_summary
WHERE moonshot_count >= 2  -- Focus on repeat performers
ORDER BY total_profit DESC