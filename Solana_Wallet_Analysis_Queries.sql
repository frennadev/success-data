-- =================================================================================
-- SUPPLEMENTARY QUERIES FOR WALLET ANALYSIS
-- =================================================================================

-- QUERY A: Wallet Performance Summary Dashboard
-- =================================================================================

WITH wallet_summary AS (
  SELECT 
    trader_wallet,
    launchpad_name,
    COUNT(DISTINCT token_mint_address) as tokens_traded,
    COUNT(*) as total_trades,
    SUM(total_sol_invested) as total_invested,
    SUM(total_pnl_sol) as total_profit_sol,
    AVG(return_percentage) as avg_return_pct,
    MAX(return_percentage) as best_return_pct,
    MIN(return_percentage) as worst_return_pct,
    
    -- Success rate
    COUNT(CASE WHEN return_percentage > 0 THEN 1 END) * 100.0 / COUNT(*) as win_rate_pct,
    COUNT(CASE WHEN return_percentage >= 1000 THEN 1 END) as moonshot_count,
    
    -- Timing analysis  
    AVG(DATE_DIFF('hour', first_trade_time, last_trade_time)) as avg_hold_time_hours,
    AVG(DATE_DIFF('hour', launch_time, first_trade_time)) as avg_entry_timing_hours
    
  FROM (
    -- Reference to previous main query results
    SELECT * FROM high_performer_wallets WHERE return_percentage >= 100
  ) successful_trades
  GROUP BY trader_wallet, launchpad_name
)

SELECT 
  *,
  RANK() OVER (ORDER BY total_profit_sol DESC) as profit_rank,
  RANK() OVER (ORDER BY moonshot_count DESC) as moonshot_rank,
  RANK() OVER (ORDER BY win_rate_pct DESC) as consistency_rank
FROM wallet_summary
WHERE moonshot_count >= 1
ORDER BY total_profit_sol DESC;

-- =================================================================================
-- QUERY B: Launchpad Performance Comparison
-- =================================================================================

WITH launchpad_stats AS (
  SELECT 
    launchpad_name,
    COUNT(DISTINCT token_mint_address) as total_tokens_launched,
    COUNT(DISTINCT trader_wallet) as unique_traders,
    COUNT(*) as total_trades,
    
    -- Success metrics
    COUNT(CASE WHEN return_percentage >= 1000 THEN 1 END) as moonshot_trades,
    COUNT(CASE WHEN return_percentage >= 1000 THEN 1 END) * 100.0 / COUNT(*) as moonshot_rate_pct,
    
    -- Financial metrics
    SUM(total_sol_invested) as total_volume_invested,
    SUM(total_pnl_sol) as total_profits_generated,
    AVG(return_percentage) as avg_return_pct,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY return_percentage) as median_return_pct,
    
    -- Top performers
    MAX(return_percentage) as highest_return_pct,
    MAX(total_pnl_sol) as biggest_profit_sol
    
  FROM high_performer_wallets
  GROUP BY launchpad_name
)

SELECT 
  *,
  RANK() OVER (ORDER BY moonshot_rate_pct DESC) as moonshot_rate_rank,
  RANK() OVER (ORDER BY avg_return_pct DESC) as avg_return_rank,
  RANK() OVER (ORDER BY total_profits_generated DESC) as total_profit_rank
FROM launchpad_stats
ORDER BY moonshot_rate_pct DESC;

-- =================================================================================
-- QUERY C: Token Success Analysis
-- =================================================================================

WITH token_performance AS (
  SELECT 
    launchpad_name,
    token_mint_address,
    launch_time,
    COUNT(DISTINCT trader_wallet) as unique_traders,
    COUNT(*) as total_trades,
    
    -- Trading metrics
    SUM(total_sol_invested) as total_investment_volume,
    SUM(total_pnl_sol) as total_profits,
    AVG(return_percentage) as avg_trader_return,
    MAX(return_percentage) as best_trader_return,
    
    -- Success distribution
    COUNT(CASE WHEN return_percentage >= 1000 THEN 1 END) as traders_with_1000plus,
    COUNT(CASE WHEN return_percentage >= 5000 THEN 1 END) as traders_with_5000plus,
    COUNT(CASE WHEN return_percentage >= 10000 THEN 1 END) as traders_with_10000plus,
    
    -- Timing insights
    MIN(hours_after_launch) as fastest_entry_hours,
    AVG(hours_after_launch) as avg_entry_timing_hours,
    AVG(trade_duration_hours) as avg_hold_duration_hours
    
  FROM high_performer_wallets
  WHERE return_percentage >= 100
  GROUP BY launchpad_name, token_mint_address, launch_time
)

SELECT 
  *,
  traders_with_1000plus * 100.0 / unique_traders as pct_traders_1000plus,
  traders_with_5000plus * 100.0 / unique_traders as pct_traders_5000plus,
  traders_with_10000plus * 100.0 / unique_traders as pct_traders_10000plus,
  
  -- Token success tier
  CASE 
    WHEN traders_with_10000plus >= 5 THEN 'Ultra Success'
    WHEN traders_with_5000plus >= 10 THEN 'High Success'
    WHEN traders_with_1000plus >= 20 THEN 'Good Success'
    WHEN traders_with_1000plus >= 5 THEN 'Moderate Success'
    ELSE 'Low Success'
  END as token_success_tier
  
FROM token_performance
WHERE unique_traders >= 5  -- Filter tokens with meaningful trading activity
ORDER BY traders_with_1000plus DESC, total_profits DESC;

-- =================================================================================
-- QUERY D: Time-Based Success Patterns
-- =================================================================================

SELECT 
  launchpad_name,
  DATE_TRUNC('week', launch_time) as launch_week,
  COUNT(DISTINCT token_mint_address) as tokens_launched,
  COUNT(DISTINCT trader_wallet) as unique_successful_traders,
  
  -- Success metrics by week
  COUNT(CASE WHEN return_percentage >= 1000 THEN 1 END) as moonshot_trades,
  SUM(total_pnl_sol) as weekly_profits,
  AVG(return_percentage) as avg_weekly_return,
  
  -- Entry timing patterns
  AVG(hours_after_launch) as avg_entry_delay_hours,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_after_launch) as median_entry_delay_hours,
  
  -- Hold time patterns
  AVG(trade_duration_hours) as avg_hold_time_hours,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY trade_duration_hours) as median_hold_time_hours

FROM high_performer_wallets
WHERE return_percentage >= 1000
  AND launch_time >= CURRENT_DATE - INTERVAL '60' DAY
GROUP BY launchpad_name, DATE_TRUNC('week', launch_time)
ORDER BY launch_week DESC, launchpad_name;

-- =================================================================================
-- QUERY E: Whale vs Small Trader Analysis
-- =================================================================================

WITH trader_categories AS (
  SELECT 
    *,
    CASE 
      WHEN total_sol_invested >= 100 THEN 'Whale (100+ SOL)'
      WHEN total_sol_invested >= 10 THEN 'Big Fish (10-100 SOL)'
      WHEN total_sol_invested >= 1 THEN 'Regular (1-10 SOL)'
      ELSE 'Small Fish (<1 SOL)'
    END as trader_category
  FROM high_performer_wallets
  WHERE return_percentage >= 1000
)

SELECT 
  launchpad_name,
  trader_category,
  COUNT(*) as trade_count,
  COUNT(DISTINCT trader_wallet) as unique_traders,
  
  -- Investment and returns
  AVG(total_sol_invested) as avg_investment,
  AVG(total_pnl_sol) as avg_profit,
  AVG(return_percentage) as avg_return_pct,
  
  -- Success distribution
  COUNT(CASE WHEN return_percentage >= 5000 THEN 1 END) as ultra_success_count,
  COUNT(CASE WHEN return_percentage >= 5000 THEN 1 END) * 100.0 / COUNT(*) as ultra_success_rate,
  
  -- Behavioral patterns
  AVG(hours_after_launch) as avg_entry_timing,
  AVG(trade_duration_hours) as avg_hold_time,
  AVG(total_trades) as avg_trades_per_token

FROM trader_categories
GROUP BY launchpad_name, trader_category
ORDER BY launchpad_name, 
  CASE trader_category 
    WHEN 'Whale (100+ SOL)' THEN 1
    WHEN 'Big Fish (10-100 SOL)' THEN 2  
    WHEN 'Regular (1-10 SOL)' THEN 3
    WHEN 'Small Fish (<1 SOL)' THEN 4
  END;