# Liteswap
Simple Dex

# Liteswap Deployment Guide

This guide explains how to deploy the Liteswap contract to both local development network and Sepolia testnet using Foundry.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Git
- Terminal access
- For Sepolia: 
  - An Alchemy or Infura API key
  - Some Sepolia ETH (from a faucet)

## Setup

1. Clone the repository and install dependencies:
```bash
git clone <your-repo-url>
cd <repo-name>
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
# Copy one of the private keys from Anvil output (without the 0x prefix)
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
- [PoW Faucet](https://sepolia-faucet.pk910.de/)

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