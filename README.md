# Liteswap
Simple Dex
# Liteswap
![Liteswap](/assets/Liteswap.png)

A simple decentralized exchange protocol that pairs automated market making with limit orders for enhanced trader experience and liquidity provider risk management.

## Features

- Create trading pairs between any two ERC20 tokens
- Add/remove liquidity while collecting fees
- Swap tokens
- Fee-free limit order placement, filling, and cancellation


## Verified Contract Deployment to Sepolia

- https://sepolia.etherscan.io/address/0xd3183D0568FB5Ce114aB2D275933CeE355905fa2

- simple dapp https://rich-rigid-manufacturer.anvil.app (was using free plan to ensure it could be reproduced by a non-anvil user, which doesnt allow changing the url.)


## Architecture

The core contract `Liteswap.sol` implements:

- Pair creation and management
- Share-based liquidity provision accounting
- Constant product AMM formula (x * y = k)
- Simple offer based limit order system

The supplementary contract `TestERC20.sol` is used for generating test tokens on sepolia to interact with the contract.
````mermaid
graph TD
    subgraph Liteswap [Liteswap Contract Instance]
        subgraph Storage [Contract Storage]
            direction LR
            subgraph Mappings [State Mappings]
                PM[pairs]
                TPM[tokenPairId]
                LPM[liquidityProviderPositions]
                LOM[limitOrders]
            end
            
            subgraph Counters [State Counters]
                PC[_pairIdCount]
                OC[_orderIdCounter]
            end
        end

        subgraph Functions [Contract Functions]
            direction TB
            subgraph AMM [AMM Operations]
                IP[initializePair]
                AL[addLiquidity]
                RL[removeLiquidity]
                SW[swap]
            end

            subgraph LO [Limit Orders]
                PLO[placeLimitOrder]
                FLO[fillLimitOrder]
                CLO[cancelLimitOrder]
            end

            subgraph Internal [Internal Functions]
                TT[_transferTokens]
                UR[_updateReserves]
                MS[_mintShares]
                BS[_burnShares]
                SQ[_sqrt]
            end

            subgraph Views [View Functions]
                GPI[getPairId]
                GPIF[getPairInfo]
                GSB[getUserShareBps]
            end
        end

        Functions --> Storage
        Storage --> Functions
    end

    EXT[External Token Contracts] -.-> Liteswap
    USR[Users] -.-> Liteswap

    style Liteswap fill:#e6e6e6,stroke:#000000,stroke-width:3px,color:#000000
    style Storage fill:#cce5ff,stroke:#000000,stroke-width:1px,color:#000000
    style Functions fill:#d4edda,stroke:#000000,stroke-width:1px,color:#000000
    style AMM fill:#c3e6cb,stroke:#000000,stroke-width:1px,color:#000000
    style LO fill:#d4d7f5,stroke:#000000,stroke-width:1px,color:#000000
    style Internal fill:#ffe5cc,stroke:#000000,stroke-width:1px,color:#000000
    style Views fill:#f8d7da,stroke:#000000,stroke-width:1px,color:#000000
    style Mappings fill:#b8e2fc,stroke:#000000,stroke-width:1px,color:#000000
    style Counters fill:#e9d2f4,stroke:#000000,stroke-width:1px,color:#000000
    style EXT fill:#ffe5cc,stroke:#000000,stroke-width:1px,stroke-dasharray: 5 5,color:#000000
    style USR fill:#ffe5cc,stroke:#000000,stroke-width:1px,stroke-dasharray: 5 5,color:#000000
````
## User Journey
````mermaid
flowchart TD
    EOA([End User Wallet]) -->|Can interact| ENTRY[All Contract Functions]
    EXT([External Contract]) -->|Can integrate| ENTRY
    
    ENTRY --> START
    
    START([Start]) --> A{Trading Pair Exists?}
    
    A -->|No| B{Validate Pair Creation}
    B -->|Invalid| R([REVERT:
    - PairAlreadyExists
    - InvalidTokenAddress
    - InvalidAmount
    - InsufficientLiquidity
    - TransferFailed])
    B -->|Valid| C[Supply Initial Liquidity]
    C --> D[Pair Created]
    D --> E
    
    A -->|Yes| E{Choose Action}
    
    %% AMM Actions
    E -->|Swap| F[Swap Tokens]
    F --> G[Approve Token Transfer]
    G --> H[Execute Swap]
    H --> E
    
    E -->|Add Liquidity| I[Add More Liquidity]
    I --> J[Approve Both Tokens]
    J --> K[Provide Liquidity]
    K --> L[Receive LP Shares]
    L --> E
    
    E -->|Remove Liquidity| M[Remove Liquidity]
    M --> N[Burn LP Shares]
    N --> O[Receive Both Tokens]
    O --> E
    
    %% Limit Order Actions
    E -->|Place Limit Order| P[Create Limit Order]
    P --> Q[Approve Offer Token]
    Q --> S[Place Order]
    S --> E
    
    E -->|Fill Limit Order| T[Fill Order]
    T --> U[Approve Desired Token]
    U --> V[Execute Fill]
    V --> E
    
    E -->|Cancel Limit Order| W[Cancel Own Order]
    W --> X[Receive Back Tokens]
    X --> E
    
    E --> END([End])

    style START fill:#d4edda,stroke:#000000,stroke-width:2px,color:#000000
    style END fill:#f8d7da,stroke:#000000,stroke-width:2px,color:#000000
    style R fill:#ff9999,stroke:#000000,stroke-width:2px,color:#000000
    style A fill:#cce5ff,stroke:#000000,stroke-width:2px,color:#000000
    style B fill:#cce5ff,stroke:#000000,stroke-width:2px,color:#000000
    style E fill:#cce5ff,stroke:#000000,stroke-width:2px,color:#000000
    style D fill:#d4d7f5,stroke:#000000,stroke-width:2px,color:#000000
    style EOA fill:#b8e2fc,stroke:#000000,stroke-width:2px,color:#000000
    style EXT fill:#e9d2f4,stroke:#000000,stroke-width:2px,color:#000000
    style ENTRY fill:#e6e6e6,stroke:#000000,stroke-width:2px,color:#000000,stroke-dasharray: 5 5
    
    classDef action fill:#e6e6e6,stroke:#000000,stroke-width:2px,color:#000000
    class C,F,G,H,I,J,K,L,M,N,O,P,Q,S,T,U,V,W,X action
````

## Stack
- Solidity smart contract 
- Foundry (forge, anvil)
- Solidity tests with fuzzing
- Front end written in python and javascript using Anvil

# Liteswap Deployment Guide

This guide explains how to deploy the Liteswap contract to both local development network and Sepolia testnet using Foundry.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed


1. Open a terminal and run:
```bash
curl -L https://foundry.paradigm.xyz | bash
```

2. Restart your terminal, then run:
```bash
foundryup
```

3. Verify the installation:
```bash
forge --version
```

- Git
- Terminal access
- For Sepolia: 
  - An Alchemy or Infura API key
  - Some Sepolia ETH (from a faucet)

## Setup

1. Clone the repository and install dependencies:
```bash
git clone https://github.com/beh10000/LiteswapFoundry.git
cd LiteswapFoundry
forge install
```

## Local Deployment

### 1. Start Local Node

Start an Anvil node in a terminal window:
```bash
anvil
```

Keep this terminal window open. Anvil will display several test accounts with their private keys.

### 2. Configure Environment

In a new terminal window, set up your deployment private key:

```bash
# Copy one of the private keys from Anvil output
export PRIVATE_KEY=<paste_private_key_here>
```

### 3. Deploy Contract Locally

From your project's root directory, run:
```bash
forge script script/DeployLiteswap.s.sol:DeployLiteswap --rpc-url http://localhost:8545 --broadcast
```

## Sepolia Testnet Deployment

### 1. Set Up Environment Variables

Create a `.env` file in your project root:
```bash
# Your wallet's private key (without 0x prefix)
export PRIVATE_KEY=your_private_key_here
# Your Alchemy or Infura API URL
export SEPOLIA_RPC_URL=your_rpc_url_here
# Optional: Your Etherscan API Key for verification
export ETHERSCAN_API_KEY=your_etherscan_key_here
```

Load the environment variables:
```bash
source .env
```

### 2. Get Sepolia ETH

Get some Sepolia ETH from a faucet:
- [Alchemy Sepolia Faucet](https://sepoliafaucet.com/)
- [Infura Sepolia Faucet](https://www.infura.io/faucet/sepolia)


### 3. Deploy to Sepolia

Run the deployment script with Sepolia configuration:
```bash
forge script script/DeployLiteswap.s.sol:DeployLiteswap \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

### 4. Verify Contract (Optional)

If the automatic verification didn't work, verify manually:
```bash
forge verify-contract \
    <deployed-address> \
    src/Liteswap.sol:Liteswap \
    --chain-id 11155111 \
    --compiler-version v0.8.28 \
    --etherscan-api-key $ETHERSCAN_API_KEY
```



## Network Configurations

### Local Anvil
- RPC URL: `http://localhost:8545`
- Chain ID: `31337`
- Network Name: `Anvil`

### Sepolia Testnet
- RPC URL: Your Alchemy/Infura Sepolia URL
- Chain ID: `11155111`
- Network Name: `Sepolia`
- Block Explorer: `https://sepolia.etherscan.io`

## Troubleshooting

If you encounter issues:

1. For local deployment:
   - Ensure Anvil is running in a separate terminal
   - Verify your `PRIVATE_KEY` is set correctly
   - Make sure you're in the project root directory

2. For Sepolia deployment:
   - Check that your wallet has sufficient Sepolia ETH
   - Verify your RPC URL is correct
   - Ensure your private key is set properly
   - Check that all environment variables are loaded

3. General issues:
   - Check that all dependencies are installed with `forge install`
   - Try increasing gas limit with `--gas-limit 3000000`
   - Use `-vvvv` flag for verbose output

## Security Notes

- Never commit your `.env` file or expose private keys
- Never use the test private keys from Anvil on mainnet
- The provided setup is for development and testing purposes
- Ensure proper security measures before deploying to mainnet
- Always test thoroughly on testnet before mainnet deployment

## Usage

After deployment, clone the dapp.
https://anvil.works/build#clone:VWNRQRSGPY77UYZQ=VT33BJ3AXXGVJTNXHSCYSM4A

This will take you to Anvil, a python web framework and browser IDE. 

Once you open the IDE, find the "contracts" datatable. Copy the Liteswap address and Factory address from the above deployment script logs and paste them into the contracts datatable in the corresponding address fields. The dapp reads the address and abi from this datatable to connect to the contract, so make sure the datatable access settings are set to "Client Read Only, Server No access". 

If you are on the localhost network, go to main.js file and find and update these variables.
```javascript
const gchainrpc="http://127.0.0.1:8545/" 
export const networks = [customNetwork]
```


If you are on Sepolia Network, go to main.js file and set the networks value to:
```javascript 
export const networks = [sepolia]
```
Now click "Run" and you can interact with the app. 
## Test Coverage
```bash
╭-----------------------------+------------------+------------------+----------------+----------------╮
| File                        | % Lines          | % Statements     | % Branches     | % Funcs        |
+=====================================================================================================+
| script/DeployLiteswap.s.sol | 0.00% (0/8)      | 0.00% (0/10)     | 100.00% (0/0)  | 0.00% (0/1)    |
|-----------------------------+------------------+------------------+----------------+----------------|
| script/Liteswap.s.sol       | 0.00% (0/5)      | 0.00% (0/3)      | 100.00% (0/0)  | 0.00% (0/2)    |
|-----------------------------+------------------+------------------+----------------+----------------|
| src/Liteswap.sol            | 91.38% (159/174) | 85.60% (220/257) | 48.89% (22/45) | 81.25% (13/16) |
|-----------------------------+------------------+------------------+----------------+----------------|
| test/Liteswap.t.sol         | 69.57% (16/23)   | 65.22% (15/23)   | 100.00% (0/0)  | 50.00% (1/2)   |
|-----------------------------+------------------+------------------+----------------+----------------|
| test/TestERC20.sol          | 9.09% (2/22)     | 5.00% (1/20)     | 0.00% (0/2)    | 20.00% (1/5)   |
|-----------------------------+------------------+------------------+----------------+----------------|
| Total                       | 76.29% (177/232) | 75.40% (236/313) | 46.81% (22/47) | 57.69% (15/26) |
╰-----------------------------+------------------+------------------+----------------+----------------╯
```
The branch coverage for liteswap.sol could be increased with more invariant testing.
## Contract Reference

### Public/External Functions

| Function | Inputs | Outputs | Description | State Changing |
|----------|---------|---------|-------------|----------------|
| initializePair | address tokenA, address tokenB, uint256 amountA, uint256 amountB | uint256 pairId | Creates a new trading pair between two tokens with initial liquidity. Tokens must be valid and different. Order of tokens doesn't matter. Emits PairInitialized, LiquidityAdded and ReservesUpdated events. | Yes |
| addLiquidity | uint256 pairId, uint256 amountA | (uint256 amountB, uint256 shares) | Adds liquidity to existing pair by providing one token amount. Required amount of second token is calculated based on current exchange rate. Emits LiquidityAdded event. | Yes |
| removeLiquidity | uint256 pairId, uint256 sharesToBurn | (uint256 amountA, uint256 amountB) | Burns shares to remove liquidity proportionally. Returns both token amounts. Emits LiquidityRemoved event. | Yes |
| swap | uint256 pairId, address tokenIn, uint256 amountIn, uint256 minAmountOut | uint256 amountOut | Swaps exact input tokens for output tokens with 0.3% fee. Requires minimum output amount. Handles fee-on-transfer tokens. Emits Swap and ReservesUpdated events. | Yes |
| placeLimitOrder | uint256 pairId, address offerToken, uint256 offerAmount, uint256 desiredAmount | uint256 orderId | Places limit order to swap tokens at specific rate. Rate must be worse than AMM price. Handles fee-on-transfer tokens. Emits LimitOrderPlaced event. | Yes |
| cancelLimitOrder | uint256 pairId, uint256 orderId | void | Cancels active limit order and returns remaining offered tokens to maker. Only callable by order maker. Emits LimitOrderCancelled event. | Yes |
| fillLimitOrder | uint256 pairId, uint256 orderId, uint256 amountDesiredToFill | uint256 filled | Fills active limit order with specified amount. Returns amount of offer tokens sent to filler. Handles fee-on-transfer tokens. Emits LimitOrderFilled event. | Yes |
| getPairId | address tokenA, address tokenB | uint256 | Gets unique ID for token pair. Order of tokens doesn't matter - returns same ID for (A,B) and (B,A). | No |
| getPairInfo | uint256 pairId | (uint256 reserveA, uint256 reserveB, uint256 totalShares) | Gets current reserves and total shares for a liquidity pair. | No |
| getUserShareBps | uint256 pairId, address user | uint256 | Calculates user's share of liquidity pool in basis points (1 = 0.01%, 10000 = 100%). | No |

### Public State Variables 

| Variable | Type | Description |
|----------|------|-------------|
| pairs | mapping(uint256 => Pair) | Stores pair data including tokens, reserves, total shares and initialization status |
| tokenPairId | mapping(address => mapping(address => uint256)) | Maps sorted token addresses to their unique pair ID |
| liquidityProviderPositions | mapping(uint256 => mapping(address => LiquidityPosition)) | Tracks LP positions including shares and position status |
| limitOrders | mapping(uint256 => mapping(uint256 => LimitOrder)) | Stores limit order data including tokens, amounts, maker and status |
| _pairIdCount | uint256 | Counter for generating unique pair IDs starting from 1 |

### Events

| Event | Parameters | Description |
|-------|------------|-------------|
| PairInitialized | uint256 indexed pairId, address token0, address token1 | Emitted when new trading pair is created |
| LiquidityAdded | uint256 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 shares | Emitted when liquidity is added to a pair |
| LiquidityRemoved | uint256 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 shares | Emitted when liquidity is removed from a pair |
| Swap | uint256 indexed pairId, address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut | Emitted when tokens are swapped |
| ReservesUpdated | uint256 indexed pairId, uint256 reserveA, uint256 reserveB | Emitted when pair reserves are updated |
| LimitOrderPlaced | uint256 indexed pairId, uint256 indexed orderId, address indexed maker, address offerToken, address desiredToken, uint256 offerAmount, uint256 desiredAmount | Emitted when limit order is created |
| LimitOrderCancelled | uint256 indexed pairId, uint256 indexed orderId | Emitted when limit order is cancelled |
| LimitOrderFilled | uint256 indexed pairId, uint256 indexed orderId, address indexed filler, uint256 fillAmount | Emitted when limit order is filled |

## Assumptions and comments
At this point in time, the market is moving beyond solely relying on simple symmetrical constant product market makers and moving towards concentrated liquidity pools. In the interest of time for this project, implementing a version of Uniswap V3 concentrated positions utilizing tick math would have been a stretch. Since it is critical for liquidity providers to be able to hedge impermanent loss and direct ranges in which they want to primarily be buying or selling, the solution was to introduce the simple limit order system alongside the standard constant product liquidity pool. While working through this, it became clear that this can be beneficial for liquidity providers in a situation where they want to be a seller at some price range, but they dont want to also be a buyer at that range. If they were in a V3 pool they would have to monitor the position and pull it once the price marched through it in one direction before returning in the other direction. If they utilized this implementation of the limit order they could set ranges they expect price to hit, exit at the high range, re-enter at the low range and not bear impermanent loss in between.

