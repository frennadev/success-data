# Solana Meme Token Trader Performance Dashboard

## 🎯 Dashboard Overview

This Dune dashboard tracks wallets that achieve 1000%+ returns on **individual tokens** (not cumulative) launched on specific Solana launchpads (pump.fun, letsbonk, and bags). Each row represents a single moonshot trade on one specific token.

## 📊 Dashboard Components

### **Main Visualizations**

1. **Top Performing Wallets Table** 
   - Wallets with 1000%+ returns
   - Investment amounts, profits, and return percentages
   - Trade timing and duration analysis

2. **Launchpad Comparison Chart**
   - Success rates by launchpad
   - Average returns and moonshot frequencies
   - Trading volume comparison

3. **Token Success Heatmap**
   - Individual token performance
   - Number of successful traders per token
   - Success tier classification

4. **Time-Based Success Trends**
   - Weekly performance patterns
   - Entry timing optimization
   - Hold duration analysis

5. **Trader Category Analysis**
   - Whale vs small trader performance
   - Investment size impact on returns
   - Behavioral pattern differences

## 🔧 Setup Instructions

### **Step 1: Create New Dune Dashboard**
1. Go to [dune.com](https://dune.com)
2. Click "New Query" 
3. Select "Solana" as the blockchain
4. Create queries using the provided SQL files

### **Step 2: Upload Main Query**
```sql
-- Copy and paste content from: Solana_Meme_Trader_Dashboard_Queries.sql
-- This creates the foundation query for tracking high-performing wallets
```

### **Step 3: Create Supplementary Queries**
```sql  
-- Copy content from: Solana_Wallet_Analysis_Queries.sql
-- Create separate queries for each analysis type (A through E)
```

### **Step 4: Configure Visualizations**

#### **Query 1: Main Dashboard (High Performers)**
- **Visualization Type:** Table
- **Columns to Display:**
  - `trader_wallet` (clickable link)
  - `launchpad_name` 
  - `return_pct`
  - `total_pnl_sol`
  - `total_sol_invested`
  - `total_trades`
  - `return_tier`
- **Filters:** 
  - Launchpad dropdown (pump.fun, letsbonk, bags)
  - Minimum return percentage slider
  - Date range picker

#### **Query A: Wallet Summary**
- **Visualization Type:** Table + Bar Chart
- **Sort:** By total profit SOL (descending)
- **Highlight:** Top 10 wallets

#### **Query B: Launchpad Comparison** 
- **Visualization Type:** Bar Chart
- **X-axis:** Launchpad name
- **Y-axis:** Moonshot rate percentage
- **Secondary Y-axis:** Total profits generated

#### **Query C: Token Analysis**
- **Visualization Type:** Scatter Plot
- **X-axis:** Unique traders
- **Y-axis:** Average trader return
- **Size:** Total profits
- **Color:** Token success tier

#### **Query D: Time Trends**
- **Visualization Type:** Line Chart
- **X-axis:** Launch week
- **Y-axis:** Weekly profits
- **Multiple lines:** One per launchpad

#### **Query E: Trader Categories**
- **Visualization Type:** Stacked Bar Chart
- **X-axis:** Trader category
- **Y-axis:** Trade count
- **Stack:** Success rate tiers

## 🎨 Dashboard Layout

```
┌─────────────────────────────────────────────────────────────┐
│                     HEADER & FILTERS                        │
│  [Launchpad Filter] [Date Range] [Min Return %] [Refresh]   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TOP PERFORMING WALLETS (1000%+ RETURNS)                   │
│  [Large Table showing wallet performance data]             │
│                                                             │
├───────────────────────┬─────────────────────────────────────┤
│                       │                                     │
│  LAUNCHPAD COMPARISON │   TOKEN SUCCESS ANALYSIS           │
│  [Bar Chart]          │   [Scatter Plot]                   │
│                       │                                     │
├───────────────────────┼─────────────────────────────────────┤
│                       │                                     │
│  WEEKLY TRENDS        │   TRADER CATEGORIES                 │
│  [Line Chart]         │   [Stacked Bar Chart]               │
│                       │                                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  DETAILED WALLET METRICS                                    │
│  [Comprehensive Table with all wallet data]                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## ⚙️ Configuration Parameters

### **Query Parameters**
```sql
-- Adjustable parameters in the queries:

-- Minimum return threshold
WHERE return_percentage >= {{min_return_pct}}  -- Default: 1000

-- Date range 
AND block_time >= '{{start_date}}'::timestamp
AND block_time <= '{{end_date}}'::timestamp

-- Minimum investment threshold
AND total_sol_invested >= {{min_investment}}  -- Default: 0.1

-- Launchpad filter
AND launchpad_name IN ({{selected_launchpads}})
```

### **Dashboard Filters**
1. **Launchpad Selection** (Multi-select dropdown)
   - pump.fun
   - letsbonk  
   - bags
   - All

2. **Return Threshold** (Slider)
   - Range: 100% to 50,000%
   - Default: 1000%

3. **Date Range** (Date picker)
   - Default: Last 90 days
   - Max: Last 365 days

4. **Investment Size** (Dropdown)
   - All sizes
   - Whales (100+ SOL)
   - Big Fish (10-100 SOL)
   - Regular (1-10 SOL)
   - Small Fish (<1 SOL)

## 📈 Key Metrics Tracked

### **Wallet Performance**
- Total SOL invested
- Total SOL profit
- Return percentage
- Number of moonshot trades (1000%+)
- Win rate percentage
- Average hold time
- Entry timing after launch

### **Token Success**
- Number of successful traders
- Average trader return
- Moonshot trader count
- Success tier classification
- Total trading volume
- Launch to first trade time

### **Launchpad Comparison**
- Moonshot rate percentage
- Average returns
- Total profits generated
- Unique trader count
- Token launch frequency

## 🔍 Advanced Features

### **Drill-Down Capabilities**
- Click wallet address → Individual wallet analysis
- Click token → Token-specific performance
- Click launchpad → Launchpad deep dive

### **Alert System** (Future Enhancement)
- New wallets achieving 1000%+ returns
- Unusual trading patterns
- New high-performing tokens

### **Export Options**
- CSV export of wallet lists
- API endpoints for real-time data
- Webhook integration for alerts

## 🚀 Usage Tips

1. **Start with the main table** to identify top performers
2. **Use launchpad comparison** to see which platforms are most successful
3. **Check time trends** to identify optimal trading periods  
4. **Analyze trader categories** to understand investment size impact
5. **Monitor token success patterns** for future opportunities

## 📋 Data Update Schedule

- **Real-time:** Every 10 minutes
- **Historical data:** Backfilled to 90 days
- **Query timeout:** 30 seconds max
- **Data refresh:** Automatic on dashboard load

---

**Dashboard URL:** `https://dune.com/your-username/solana-meme-moonshot-traders`  
**Created:** January 2025  
**Last Updated:** Auto-refreshing