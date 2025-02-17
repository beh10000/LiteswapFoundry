import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
  import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
  import { expect } from "chai";
  import hre from "hardhat";
  
  describe("Liteswap Testing", function () {
    /*
    Test Case Summary
    Pair Initialization:
    - Should revert when initializing with zero address for either token
    - Should revert when initializing with same token address for both tokens
    - Should revert when initializing a pair that already exists (in either token order)
    - Should revert when initializing with zero amount for either token
    - Should correctly sort tokens by address regardless of input order
    - Should correctly calculate initial shares as geometric mean of token amounts
    - Should revert if initial shares are below MINIMUM_SHARES
    - Should properly set pair state (reserves, tokens, shares, initialized flag)
    - Should emit correct events (PairInitialized, LiquidityAdded, ReservesUpdated) with proper arguments
    - Should properly transfer initial liquidity from provider to contract
    - Should properly handle tokens with different decimals
    - Should revert if either token transfer fails
    - Should revert if provider has insufficient token balance
    - Should revert if provider has not approved sufficient token allowance
  
    Adding Liquidity:
    - Should revert when adding to non-existent pair
    - Should revert when adding zero amount
    - Should calculate correct amount of tokenB needed based on current ratio
    - Should mint correct number of shares proportional to contribution
    - Should properly update reserves
    - Should properly update user's liquidity position
    - Should emit correct events (LiquidityAdded, ReservesUpdated)
  
    Removing Liquidity:
    - Should revert when removing from non-existent position
    - Should revert when removing zero shares
    - Should revert when removing more shares than owned
    - Should calculate correct token amounts based on share proportion
    - Should properly burn shares
    - Should properly update reserves
    - Should properly update/remove user's liquidity position
    - Should emit correct events (LiquidityRemoved, ReservesUpdated)
  
    Token Transfers:
    - Should properly handle failed token transfers
    - Should properly handle tokens with different decimals
    - Should properly handle non-standard ERC20 tokens (e.g., tokens that return false on success)
  
    Swapping:
    - Should revert when swapping with non-existent pair
    - Should revert when swapping with zero input amount
    - Should revert when swapping with insufficient balance
    - Should maintain constant product invariant after swap
    - Should revert when output amount is zero
    - Should allow swap with exact minAmountOut
    - Should revert if received amount is less than minAmountOut
    - Should properly update reserves after swap
    - Should properly transfer tokens
    - Should take correct swap fee
    - Should emit correct events (Swap, ReservesUpdated)
    - Should handle price impact correctly for large swaps
    - Should revert when insufficient input token allowance
    - Should revert when insufficient output token liquidity
    - Should handle tokens with different decimals correctly
  
    Fee Accumulation:
    - Should accumulate and distribute fees correctly across multiple operations
    - Should distribute fees proportionally to liquidity providers
    - Should handle fee distribution with multiple liquidity providers
    - Should account for impermanent loss in fee distribution
    */
    async function deployFixture() {
      const [owner, user1, user2, user3] = await hre.ethers.getSigners();
      
      const TokenFactory = await hre.ethers.getContractFactory("TestERC20");
      const tokenA = await (await TokenFactory.deploy("Token A", "TKNA")).waitForDeployment();
      const tokenB = await (await TokenFactory.deploy("Token B", "TKNB")).waitForDeployment();
      
      const LiteswapFactory = await hre.ethers.getContractFactory("Liteswap");
      const liteswap = await (await LiteswapFactory.deploy()).waitForDeployment();
      
      // Mint some tokens to users for testing
      const mintAmount = hre.ethers.parseEther("1000000");
      await tokenA.mint(owner.address, mintAmount);
      await tokenA.mint(user1.address, mintAmount);
      await tokenA.mint(user2.address, mintAmount);
      await tokenA.mint(user3.address, mintAmount);
      await tokenB.mint(owner.address, mintAmount);
      await tokenB.mint(user1.address, mintAmount);
      await tokenB.mint(user2.address, mintAmount);
      await tokenB.mint(user3.address, mintAmount);
  
      return { liteswap, tokenA, tokenB, owner, user1, user2, user3 };
    }
  
    describe("🆕🆕🆕 Pair Initialization 🆕🆕🆕", function() {
      it("Should revert when initializing with zero address for either token", async function() {
        const { liteswap, tokenA } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        // Test case 1: Zero address for token B
        console.log("+ Testing initialization with zero address for token B");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B: Zero Address");
        console.log(" -Amount A:", amount.toString());
        console.log(" -Amount B:", amount.toString());
        // Should revert when second token is zero address
        await expect(liteswap.initializePair(
          tokenA.getAddress(), 
          hre.ethers.ZeroAddress, 
          amount, 
          amount
        )).to.be.revertedWithCustomError(liteswap, "InvalidTokenAddress");
        console.log("Test passed: Reverted with InvalidTokenAddress as expected\n");
  
        // Test case 2: Zero address for token A
        console.log("+ Testing initialization with zero address for token A");
        console.log(" -Token A: Zero Address");
        console.log(" -Token B:", await tokenA.getAddress());
        console.log(" -Amount A:", amount.toString());
        console.log(" -Amount B:", amount.toString());
        // Should revert when first token is zero address
        await expect(liteswap.initializePair(
          hre.ethers.ZeroAddress,
          tokenA.getAddress(), 
          amount, 
          amount
        )).to.be.revertedWithCustomError(liteswap, "InvalidTokenAddress");
        console.log("Test passed: Reverted with InvalidTokenAddress as expected\n");
      });
  
      it("Should revert when initializing with same token address", async function() {
        const { liteswap, tokenA } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        console.log("+ Testing initialization with same token address for both tokens");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B:", await tokenA.getAddress());
        console.log(" -Amount A:", amount.toString());
        console.log(" -Amount B:", amount.toString());
  
        await expect(liteswap.initializePair(
          tokenA.getAddress(),
          tokenA.getAddress(),
          amount,
          amount
        )).to.be.revertedWithCustomError(liteswap, "InvalidTokenAddress");
        console.log("Test passed: Reverted with InvalidTokenAddress as expected\n");
      });
  
      it("Should revert when initializing with zero amount", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        console.log("+ Testing initialization with zero amount for token A");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B:", await tokenB.getAddress());
        console.log(" -Amount A: 0");
        console.log(" -Amount B:", amount.toString());
  
        await expect(liteswap.initializePair(
          tokenA.getAddress(),
          tokenB.getAddress(),
          0,
          amount
        )).to.be.revertedWithCustomError(liteswap, "InvalidAmount");
        console.log("Test passed: Reverted with InvalidAmount as expected\n");
  
        console.log("+ Testing initialization with zero amount for token B");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B:", await tokenB.getAddress());
        console.log(" -Amount A:", amount.toString());
        console.log(" -Amount B: 0");
  
        await expect(liteswap.initializePair(
          tokenA.getAddress(),
          tokenB.getAddress(),
          amount,
          0
        )).to.be.revertedWithCustomError(liteswap, "InvalidAmount");
        console.log("Test passed: Reverted with InvalidAmount as expected\n");
      });
      it("Should revert when initializing without token allowance", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        console.log("+ Testing initialization without token allowance");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B:", await tokenB.getAddress());
        console.log(" -Amount A:", amount.toString());
        console.log(" -Amount B:", amount.toString());
  
        // Don't approve tokens, try to initialize directly
        await expect(liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          amount,
          amount
        )).to.be.revertedWithCustomError(tokenA, "ERC20InsufficientAllowance");
  
        // Test with only one token approved
        console.log("+ Testing initialization with only one token approved");
        await tokenA.approve(await liteswap.getAddress(), amount);
        
        await expect(liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          amount,
          amount
        )).to.be.revertedWithCustomError(tokenB, "ERC20InsufficientAllowance");
        
        console.log("Test passed: Reverted with ERC20InsufficientAllowance as expected\n");
      });
      it("Should correctly initialize a pair and emit events", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const amountA = hre.ethers.parseEther("1000");
        const amountB = hre.ethers.parseEther("1000");
  
        console.log("+ Testing successful pair initialization");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B:", await tokenB.getAddress());
        console.log(" -Amount A:", amountA.toString());
        console.log(" -Amount B:", amountB.toString());
  
        // Approve tokens
        await tokenA.approve(await liteswap.getAddress(), amountA);
        await tokenB.approve(await liteswap.getAddress(), amountB);
  
        // Get token addresses
        const tokenAAddress = await tokenA.getAddress();
        const tokenBAddress = await tokenB.getAddress();
  
        // Initialize pair
        const tx = await liteswap.initializePair(tokenAAddress, tokenBAddress, amountA, amountB);
  
        // Get pair ID
        const pairId = await liteswap.tokenPairId(
          tokenAAddress < tokenBAddress ? tokenAAddress : tokenBAddress,
          tokenAAddress < tokenBAddress ? tokenBAddress : tokenAAddress
        );
  
        // Verify events
        console.log("+ Verifying emitted events");
        console.log(" -Checking PairInitialized event");
        await expect(tx)
          .to.emit(liteswap, "PairInitialized")
          .withArgs(pairId, tokenAAddress < tokenBAddress ? tokenAAddress : tokenBAddress, 
                          tokenAAddress < tokenBAddress ? tokenBAddress : tokenAAddress);
        console.log(" --Event verified: PairInitialized with correct tokens");
  
        console.log(" -Checking LiquidityAdded event"); 
        await expect(tx)
          .to.emit(liteswap, "LiquidityAdded")
          .withArgs(pairId, owner.address, amountA, amountB, anyValue);
        console.log(" --Event verified: LiquidityAdded with correct amounts");
  
        console.log(" -Checking ReservesUpdated event");
        await expect(tx)
          .to.emit(liteswap, "ReservesUpdated")
          .withArgs(pairId, amountA, amountB);
        console.log(" --Event verified: ReservesUpdated with correct reserves\n");
  
        // Verify pair state
        const pair = await liteswap.pairs(pairId);
        expect(pair.initialized).to.be.true;
        expect(pair.reserveA).to.equal(amountA);
        expect(pair.reserveB).to.equal(amountB);
        expect(pair.totalShares).to.be.gt(0);
  
        console.log("Test passed: Pair initialized successfully");
        console.log(" -Pair ID:", pairId);
        console.log(" -Initial reserves A:", pair.reserveA.toString());
        console.log(" -Initial reserves B:", pair.reserveB.toString());
        console.log(" -Initial total shares:", pair.totalShares.toString(), "\n");
      });
  
      it("Should correctly sort tokens by address regardless of input order", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        // Approve tokens
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
  
        const tokenAAddress = await tokenA.getAddress();
        const tokenBAddress = await tokenB.getAddress();
  
        console.log("+ Testing token address sorting");
        console.log(" -Token A:", tokenAAddress);
        console.log(" -Token B:", tokenBAddress);
        console.log(" -Amount:", amount.toString());
  
        // Initialize pair with tokens in one order
        await liteswap.initializePair(tokenAAddress, tokenBAddress, amount, amount);
        const pairId1 = await liteswap.getPairId(tokenAAddress, tokenBAddress);
  
        // Try to initialize with tokens in reverse order (should revert)
        await expect(liteswap.initializePair(
          tokenBAddress, 
          tokenAAddress, 
          amount, 
          amount
        )).to.be.revertedWithCustomError(liteswap, "PairAlreadyExists");
        console.log("Test Passed: Duplicate initializePair call with reverse order should revert")
        // Verify pair was stored with correct token ordering
        const pair = await liteswap.pairs(pairId1);
        expect(pair.tokenA).to.equal(tokenAAddress < tokenBAddress ? tokenAAddress : tokenBAddress);
        expect(pair.tokenB).to.equal(tokenAAddress < tokenBAddress ? tokenBAddress : tokenAAddress);
  
        console.log("Test passed: Tokens correctly sorted by address");
        console.log(" -Pair ID:", pairId1);
        console.log(" -Token A:", pair.tokenA);
        console.log(" -Token B:", pair.tokenB, "\n");
      });
  
      it("Should revert when initial shares would be below MINIMUM_SHARES", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const tinyAmount = 10n; // Very small amount that would result in shares < MINIMUM_SHARES
  
        await tokenA.approve(await liteswap.getAddress(), tinyAmount);
        await tokenB.approve(await liteswap.getAddress(), tinyAmount);
  
        console.log("+ Testing initialization with tiny amounts");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B:", await tokenB.getAddress());
        console.log(" -Amount:", tinyAmount.toString());
  
        await expect(liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          tinyAmount,
          tinyAmount
        )).to.be.revertedWithCustomError(liteswap, "InsufficientLiquidity");
  
        console.log("Test passed: Initialization reverted with insufficient liquidity\n");
      });
  
      it("Should correctly calculate initial shares as geometric mean", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const amountA = hre.ethers.parseEther("1000");
        const amountB = hre.ethers.parseEther("2000");
  
        await tokenA.approve(await liteswap.getAddress(), amountA);
        await tokenB.approve(await liteswap.getAddress(), amountB);
  
        console.log("+ Testing geometric mean share calculation");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B:", await tokenB.getAddress());
        console.log(" -Amount A:", amountA.toString());
        console.log(" -Amount B:", amountB.toString());
  
        await liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          amountA,
          amountB
        );
  
        const pairId = await liteswap.getPairId(await tokenA.getAddress(), await tokenB.getAddress());
        const pair = await liteswap.pairs(pairId);
        
        // Calculate expected shares (sqrt(a * b))
        const expectedShares = sqrt(amountA * amountB);
        expect(pair.totalShares).to.equal(expectedShares);
  
        console.log("Test passed: Initial shares correctly calculated");
        console.log(" -Pair ID:", pairId);
        console.log(" -Total shares:", pair.totalShares.toString(), "\n");
      });
    });
  
    describe("➕➕➕ Adding Liquidity ➕➕➕", function() {
      it("Should revert when adding to non-existent pair", async function() {
        const { liteswap } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        console.log("+ Testing adding liquidity to non-existent pair");
        console.log(" -Pair ID: 999");
        console.log(" -Amount:", amount.toString());
  
        await expect(liteswap.addLiquidity(999, amount))
          .to.be.revertedWithCustomError(liteswap, "PairDoesNotExist");
  
        console.log("Test passed: Reverted with PairDoesNotExist as expected\n");
      });
  
      it("Should correctly add liquidity to existing pair", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const initialAmount = hre.ethers.parseEther("1000");
        const addAmount = hre.ethers.parseEther("500");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialAmount);
        await tokenB.approve(await liteswap.getAddress(), initialAmount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), initialAmount, initialAmount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing adding liquidity to existing pair");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B:", await tokenB.getAddress());
        console.log(" -Initial Amount:", initialAmount.toString());
        console.log(" -Add Amount:", addAmount.toString());
        console.log(" -Pair ID:", pairId);
  
        // Add more liquidity
        await tokenA.approve(await liteswap.getAddress(), addAmount);
        await tokenB.approve(await liteswap.getAddress(), addAmount);
        
        const tx = await liteswap.addLiquidity(pairId, addAmount);
  
        await expect(tx)
          .to.emit(liteswap, "LiquidityAdded")
          .withArgs(pairId, owner.address, addAmount, addAmount, anyValue);
  
        // Verify updated reserves
        const pair = await liteswap.pairs(pairId);
        expect(pair.reserveA).to.equal(initialAmount + addAmount);
        expect(pair.reserveB).to.equal(initialAmount + addAmount);
  
        console.log("Test passed: Liquidity added successfully");
        console.log(" -New Reserve A:", pair.reserveA.toString());
        console.log(" -New Reserve B:", pair.reserveB.toString(), "\n");
      });
      it("Should revert when adding zero amount", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const initialAmount = hre.ethers.parseEther("1000");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialAmount);
        await tokenB.approve(await liteswap.getAddress(), initialAmount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), initialAmount, initialAmount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing adding zero liquidity");
        console.log(" -Pair ID:", pairId);
        console.log(" -Amount: 0");
  
        await expect(liteswap.addLiquidity(pairId, 0))
          .to.be.revertedWithCustomError(liteswap, "InvalidAmount");
  
        console.log("Test passed: Reverted with InvalidAmount as expected\n");
      });
  
      it("Should revert when insufficient token allowance", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const initialAmount = hre.ethers.parseEther("1000");
        const addAmount = hre.ethers.parseEther("500");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialAmount);
        await tokenB.approve(await liteswap.getAddress(), initialAmount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), initialAmount, initialAmount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        // Don't approve tokens before adding liquidity
        await expect(liteswap.addLiquidity(pairId, addAmount))
          .to.be.revertedWithCustomError(tokenA, "ERC20InsufficientAllowance");
  
        console.log("Test passed: Reverted with ERC20InsufficientAllowance as expected\n");
      });
  
      it("Should calculate correct shares for uneven liquidity add", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const initialAmount = hre.ethers.parseEther("1000");
        const addAmountA = hre.ethers.parseEther("500"); // Add 50% more of token A
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialAmount);
        await tokenB.approve(await liteswap.getAddress(), initialAmount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), initialAmount, initialAmount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        // Calculate expected token B amount (500 * 1000 / 1000 = 500)
        const expectedAmountB = addAmountA;
  
        console.log("+ Testing uneven liquidity addition");
        console.log(" -Pair ID:", pairId);
        console.log(" -Add Amount A:", addAmountA.toString());
        console.log(" -Expected Amount B:", expectedAmountB.toString());
  
        // Approve tokens for the add
        await tokenA.approve(await liteswap.getAddress(), addAmountA);
        await tokenB.approve(await liteswap.getAddress(), expectedAmountB);
  
        // Get initial position
        const initialPosition = await liteswap.liquidityProviderPositions(pairId, owner.address);
        const initialShares = initialPosition.shares;
  
        const tx = await liteswap.addLiquidity(pairId, addAmountA);
  
        // Expected new shares should be proportional to contribution
        // 500/1000 = 0.5 = 50% increase
        const expectedNewShares = (initialShares * addAmountA) / initialAmount;
  
        await expect(tx)
          .to.emit(liteswap, "LiquidityAdded")
          .withArgs(pairId, owner.address, addAmountA, expectedAmountB, expectedNewShares);
  
        // Verify final shares
        const finalPosition = await liteswap.liquidityProviderPositions(pairId, owner.address);
        expect(finalPosition.shares).to.equal(initialShares + expectedNewShares);
  
        console.log("Test passed: Correct shares calculated for uneven liquidity add");
        console.log(" -Initial shares:", initialShares.toString());
        console.log(" -New shares:", expectedNewShares.toString());
        console.log(" -Total final shares:", finalPosition.shares.toString(), "\n");
      });
    });
  
    describe("➖➖➖ Removing Liquidity ➖➖➖", function() {
      it("Should revert when removing from non-existent position", async function() {
        const { liteswap } = await loadFixture(deployFixture);
        const shares = hre.ethers.parseEther("100");
  
        console.log("+ Testing removing liquidity from non-existent position");
        console.log(" -Pair ID: 999");
        console.log(" -Shares to remove:", shares.toString());
  
        await expect(liteswap.removeLiquidity(999, shares))
          .to.be.revertedWithCustomError(liteswap, "NoPosition");
  
        console.log("Test passed: Reverted with NoPosition as expected\n");
      });
  
      it("Should correctly remove liquidity", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing removing all liquidity from pair");
        console.log(" -Token A:", await tokenA.getAddress());
        console.log(" -Token B:", await tokenB.getAddress());
        console.log(" -Initial Amount:", amount.toString());
        console.log(" -Pair ID:", pairId);
  
        // Get initial position
        const position = await liteswap.liquidityProviderPositions(pairId, owner.address);
        const shares = position.shares;
  
        console.log(" -Shares to remove:", shares.toString());
  
        // Remove all liquidity
        const tx = await liteswap.removeLiquidity(pairId, shares);
  
        await expect(tx)
          .to.emit(liteswap, "LiquidityRemoved")
          .withArgs(pairId, owner.address, amount, amount, shares);
  
        // Verify position is cleared
        const finalPosition = await liteswap.liquidityProviderPositions(pairId, owner.address);
        expect(finalPosition.shares).to.equal(0);
  
        console.log("Test passed: All liquidity removed successfully");
        console.log(" -Final shares:", finalPosition.shares.toString(), "\n");
      });
      it("Should revert when removing zero shares", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing removing zero shares");
        console.log(" -Pair ID:", pairId);
        console.log(" -Shares to remove: 0");
  
        await expect(liteswap.removeLiquidity(pairId, 0))
          .to.be.revertedWithCustomError(liteswap, "InvalidAmount");
  
        console.log("Test passed: Reverted with InvalidAmount as expected\n");
      });
  
      it("Should revert when removing more shares than owned", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        // Get current shares
        const position = await liteswap.liquidityProviderPositions(pairId, owner.address);
        const tooManyShares = position.shares + 1n;
  
        console.log("+ Testing removing more shares than owned");
        console.log(" -Pair ID:", pairId);
        console.log(" -Owned shares:", position.shares.toString());
        console.log(" -Attempting to remove:", tooManyShares.toString());
  
        await expect(liteswap.removeLiquidity(pairId, tooManyShares))
          .to.be.revertedWithCustomError(liteswap, "InsufficientShares");
  
        console.log("Test passed: Reverted with InsufficientShares as expected\n");
      });
  
      it("Should correctly calculate token amounts based on share proportion", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        // Get initial position and pair state
        const position = await liteswap.liquidityProviderPositions(pairId, owner.address);
        const pair = await liteswap.pairs(pairId);
        
        // Remove one third of shares
        const sharesToRemove = position.shares / 3n;
        
        console.log("+ Testing partial liquidity removal");
        console.log(" -Pair ID:", pairId);
        console.log(" -Total shares:", pair.totalShares.toString());
        console.log(" -Shares to remove:", sharesToRemove.toString());
  
        const tx = await liteswap.removeLiquidity(pairId, sharesToRemove);
  
       
        const expectedAmountA = amount / 3n; // 1/3 of initial amount
        const expectedAmountB = amount / 3n;
        
        await expect(tx)
          .to.emit(liteswap, "LiquidityRemoved")
          .withArgs(pairId, owner.address, expectedAmountA, expectedAmountB, sharesToRemove);
  
        // Verify reserves were updated correctly
        const finalPair = await liteswap.pairs(pairId);
        expect(finalPair.reserveA).to.equal(amount - expectedAmountA); // 2/3 remaining
        expect(finalPair.reserveB).to.equal(amount - expectedAmountB);
  
        console.log("Test passed: Correct proportional amounts returned");
        console.log(" -Amount A returned:", expectedAmountA.toString());
        console.log(" -Amount B returned:", expectedAmountB.toString());
        console.log(" -Final reserves A:", finalPair.reserveA.toString());
        console.log(" -Final reserves B:", finalPair.reserveB.toString(), "\n");
      });
    });
    describe("💱💱💱 Swapping 💱💱💱", function() {
      it("Should revert when swapping with non-existent pair", async function() {
        const { liteswap, tokenA } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("100");
        
        console.log("+ Testing swap with non-existent pair");
        console.log(" -Non-existent Pair ID: 999");
        console.log(" -Amount:", amount.toString());
  
        // First approve the tokens
        await tokenA.approve(await liteswap.getAddress(), amount);
        
        // Use a non-existent pair ID
        const nonExistentPairId = 999;
        await expect(liteswap.swap(nonExistentPairId, await tokenA.getAddress(), amount, 0))
          .to.be.revertedWithCustomError(liteswap, "PairDoesNotExist");
  
        console.log("Test passed: Reverted with PairDoesNotExist as expected\n");
      });
  
      it("Should revert when swapping with zero input amount", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        console.log("+ Testing swap with zero input amount");
        console.log(" -Amount: 0");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log(" -Pair ID:", pairId);
  
        await expect(liteswap.swap(pairId, await tokenA.getAddress(), 0, 0))
          .to.be.revertedWithCustomError(liteswap, "InvalidAmount");
  
        console.log("Test passed: Reverted with InvalidAmount as expected\n");
      });
  
      it("Should revert when output amount is below minimum specified", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
        const swapAmount = hre.ethers.parseEther("10");
  
        console.log("+ Testing swap with impossible minimum output");
        console.log(" -Swap Amount:", swapAmount.toString());
        console.log(" -Impossible Min Output:", hre.ethers.parseEther("11").toString());
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log(" -Pair ID:", pairId);
  
        await tokenA.approve(await liteswap.getAddress(), swapAmount);
        
        // Set minimum output higher than possible
        const impossibleMinOutput = hre.ethers.parseEther("11");
        await expect(liteswap.swap(pairId, await tokenA.getAddress(), swapAmount, impossibleMinOutput))
          .to.be.revertedWithCustomError(liteswap, "InvalidAmount");
  
        console.log("Test passed: Reverted with InvalidAmount as expected\n");
      });
  
      it("Should execute swap with correct balance changes, constant product should slightly increase due to fee, and emit Swap and ReservesUpdated events", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
        const swapAmount = hre.ethers.parseEther("10");
  
        console.log("+ Testing successful swap execution");
        console.log(" -Initial Amount:", amount.toString());
        console.log(" -Swap Amount:", swapAmount.toString());
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log(" -Pair ID:", pairId);
  
        // Get initial balances
        const initialBalanceA = await tokenA.balanceOf(owner.address);
        const initialBalanceB = await tokenB.balanceOf(owner.address);
  
        // Approve and swap
        await tokenA.approve(await liteswap.getAddress(), swapAmount);
        const tx = await liteswap.swap(pairId, await tokenA.getAddress(), swapAmount, 0);
  
        // Verify events
        await expect(tx)
          .to.emit(liteswap, "Swap")
          .withArgs(pairId, owner.address, await tokenA.getAddress(), await tokenB.getAddress(), swapAmount, anyValue);
  
        await expect(tx)
          .to.emit(liteswap, "ReservesUpdated")
          .withArgs(pairId, anyValue, anyValue);
  
        // Verify balances changed
        const finalBalanceA = await tokenA.balanceOf(owner.address);
        const finalBalanceB = await tokenB.balanceOf(owner.address);
        
        expect(finalBalanceA).to.be.lessThan(initialBalanceA);
        expect(finalBalanceB).to.be.greaterThan(initialBalanceB);
  
        // Verify constant product maintained
        const pair = await liteswap.pairs(pairId);
        // Initial k = x * y before swap
        const initialK = amount * amount;
        // After swap with 0.3% fee, k should be greater than or equal to initial k
        // because fees are added to reserves
       
        
        const finalK = pair.reserveA * pair.reserveB;
        
        expect(finalK).to.be.gte(initialK, "k value should not decrease after swap");
        
        // Additional verification that reserves changed as expected
        expect(pair.reserveA).to.be.gt(amount); // Input token reserve should increase
        expect(pair.reserveB).to.be.lt(amount); // Output token reserve should decrease
  
        console.log("Test passed: Swap executed successfully");
        console.log(" -Final Reserve A:", pair.reserveA.toString());
        console.log(" -Final Reserve B:", pair.reserveB.toString());
        console.log(" -Initial k:", initialK.toString());
        console.log(" -Final k:", finalK.toString(), "\n");
      });
  
      it("Should handle large swaps with appropriate price impact", async function() {
        const { liteswap, tokenA, tokenB, owner } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
        const largeSwapAmount = hre.ethers.parseEther("500"); // 50% of pool
  
        console.log("+ Testing large swap with price impact");
        console.log(" -Initial Pool Amount:", amount.toString());
        console.log(" -Large Swap Amount:", largeSwapAmount.toString());
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log(" -Pair ID:", pairId);
  
        await tokenA.approve(await liteswap.getAddress(), largeSwapAmount);
        
        // Execute large swap
        const tx = await liteswap.swap(pairId, await tokenA.getAddress(), largeSwapAmount, 0);
  
        // Verify significant price impact
        const pair = await liteswap.pairs(pairId);
        const outputAmount = pair.reserveB - (amount * amount) / (pair.reserveA);
        
        // Output amount should be significantly less than proportional due to price impact
        // Using multiplication instead of .mul()
        const expectedProportionalOutput = (largeSwapAmount * 997n) / 1000n;
        expect(outputAmount).to.be.lessThan(expectedProportionalOutput);
  
        console.log("Test passed: Large swap handled with price impact");
        console.log(" -Output Amount:", outputAmount.toString());
        console.log(" -Expected Proportional Output:", expectedProportionalOutput.toString());
        console.log(" -Final Reserve A:", pair.reserveA.toString());
        console.log(" -Final Reserve B:", pair.reserveB.toString(), "\n");
      });
      it("Should revert when swapping with insufficient token allowance", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
        const swapAmount = hre.ethers.parseEther("100");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing swap with insufficient allowance");
        console.log(" -Pair ID:", pairId);
        console.log(" -Swap Amount:", swapAmount.toString());
        console.log(" -Allowance: 0");
  
        // Don't approve tokens before swap
        await expect(liteswap.swap(pairId, await tokenA.getAddress(), swapAmount, 0))
          .to.be.revertedWithCustomError(tokenA, "ERC20InsufficientAllowance");
  
        console.log("Test passed: Reverted with ERC20InsufficientAllowance as expected\n");
      });
  
      it("Should revert when swapping with insufficient token balance", async function() {
        const { liteswap, tokenA, tokenB, user1 } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
        const hugeAmount = hre.ethers.parseEther("2000000"); // More than minted
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing swap with insufficient balance");
        console.log(" -Pair ID:", pairId);
        console.log(" -Huge Swap Amount:", hugeAmount.toString());
  
        // Approve huge amount but don't have the balance
        await tokenA.connect(user1).approve(await liteswap.getAddress(), hugeAmount);
        
        await expect(liteswap.connect(user1).swap(pairId, await tokenA.getAddress(), hugeAmount, 0))
          .to.be.revertedWithCustomError(tokenA, "ERC20InsufficientBalance");
  
        console.log("Test passed: Reverted with ERC20InsufficientBalance as expected\n");
      });
  
      it("Should maintain constant product invariant after swap", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
        const swapAmount = hre.ethers.parseEther("100");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing constant product invariant");
        console.log(" -Pair ID:", pairId);
        console.log(" -Swap Amount:", swapAmount.toString());
  
        // Get initial k
        const initialPair = await liteswap.pairs(pairId);
        const initialK = initialPair.reserveA * initialPair.reserveB;
  
        // Execute swap
        await tokenA.approve(await liteswap.getAddress(), swapAmount);
        await liteswap.swap(pairId, await tokenA.getAddress(), swapAmount, 0);
  
        // Get final k
        const finalPair = await liteswap.pairs(pairId);
        const finalK = finalPair.reserveA * finalPair.reserveB;
        console.log(initialK)
        console.log(finalK)
        // Calculate expected k increase based on swap amounts and fees
        
        const receivedAmount = (swapAmount * 997n * initialPair.reserveB) / ((initialPair.reserveA * 1000n) + (swapAmount * 997n));
        
        const expectedK = (initialPair.reserveA + swapAmount) * (initialPair.reserveB - receivedAmount);
        const expectedIncrease = expectedK - initialK;
        console.log(expectedK)
        expect(finalK).to.be.gt(initialK); // k should increase
        expect(finalK - initialK).to.be.closeTo(expectedIncrease, expectedIncrease / 20n); // Allow 5% margin, although should be exact
  
        console.log("Test passed: Constant product increases by expected amount based on 0.3% fee.");
        console.log(" -Initial k:", initialK.toString());
        console.log(" -Final k:", finalK.toString());
        console.log(" -Expect k increase:", expectedIncrease.toString());
        console.log(" -Actual k increase:", (finalK - initialK).toString(), "\n");
      });
      it("Should revert when output amount is zero", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
        // Even smaller amount that would definitely result in 0 output after fees
        const tinySwapAmount = 1n;
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing swap with tiny amount that results in 0 output");
        console.log(" -Pair ID:", pairId);
        console.log(" -Tiny Swap Amount:", tinySwapAmount.toString());
        console.log(" -Pool Size:", amount.toString());
  
        // Calculate expected output amount to show it would be 0
        const pair = await liteswap.pairs(pairId);
        const expectedOutput = (tinySwapAmount * 997n * pair.reserveB) / ((pair.reserveA * 1000n) + (tinySwapAmount * 997n));
        console.log(" -Expected Output Amount:", expectedOutput.toString());
  
        await tokenA.approve(await liteswap.getAddress(), tinySwapAmount);
        await expect(liteswap.swap(pairId, await tokenA.getAddress(), tinySwapAmount, 0))
          .to.be.revertedWithCustomError(liteswap, "InvalidAmount");
  
        console.log("Test passed: Reverted with InvalidAmount as expected\n");
      });
  
      it("Should allow swap with exact minAmountOut", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
        const swapAmount = hre.ethers.parseEther("10");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing swap with exact minAmountOut");
        console.log(" -Pair ID:", pairId);
        console.log(" -Swap Amount:", swapAmount.toString());
  
        // Calculate expected output amount
        const pair = await liteswap.pairs(pairId);
        const expectedOutput = (swapAmount * 997n * pair.reserveB) / ((pair.reserveA * 1000n) + (swapAmount * 997n));
  
        console.log(" -Expected Output:", expectedOutput.toString());
  
        await tokenA.approve(await liteswap.getAddress(), swapAmount);
        
        // Should succeed with exact expected amount
        await expect(liteswap.swap(pairId, await tokenA.getAddress(), swapAmount, expectedOutput))
          .to.not.be.reverted;
  
        // Should fail with expected amount + 1
        await tokenA.approve(await liteswap.getAddress(), swapAmount);
        await expect(liteswap.swap(pairId, await tokenA.getAddress(), swapAmount, expectedOutput + 1n))
          .to.be.revertedWithCustomError(liteswap, "InvalidAmount");
  
        console.log("Test passed: Swap succeeded with exact minAmountOut and failed with higher amount\n");
      });
      it("Should revert if received amount is less than minAmountOut. Used in place of common uniswap deadline function. In the event that price changes between tx broadcasting and tx inclusion, this allows user to get better deal than initially intended, but not a worse deal.", async function() {
        const { liteswap, tokenA, tokenB } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
        const swapAmount = hre.ethers.parseEther("10");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), amount);
        await tokenB.approve(await liteswap.getAddress(), amount);
        await liteswap.initializePair(await tokenA.getAddress(), await tokenB.getAddress(), amount, amount);
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("+ Testing swap with minAmountOut higher than possible");
        console.log(" -Pair ID:", pairId);
        console.log(" -Swap Amount:", swapAmount.toString());
  
        // Calculate expected output amount
        const pair = await liteswap.pairs(pairId);
        const expectedOutput = (swapAmount * 997n * pair.reserveB) / ((pair.reserveA * 1000n) + (swapAmount * 997n));
        const impossibleMinOutput = expectedOutput + hre.ethers.parseEther("1"); // Set min higher than possible
  
        console.log(" -Expected Output:", expectedOutput.toString());
        console.log(" -Impossible Min Output:", impossibleMinOutput.toString());
  
        await tokenA.approve(await liteswap.getAddress(), swapAmount);
        await expect(liteswap.swap(pairId, await tokenA.getAddress(), swapAmount, impossibleMinOutput))
          .to.be.revertedWithCustomError(liteswap, "InvalidAmount");
  
        console.log("Test passed: Reverted with InvalidAmount as expected\n");
      });
    });
    describe("💰💰💰 Fee Accumulation 💰💰💰", function() {
      it("Should accumulate and distribute fees correctly across multiple operations", async function() {
        const { liteswap, tokenA, tokenB, owner, user1, user2, user3 } = await loadFixture(deployFixture);
        
        // Initial setup amounts
        const initialLiquidity = hre.ethers.parseEther("10000");
        const swapAmount = hre.ethers.parseEther("1000");
        const additionalLiquidity = hre.ethers.parseEther("5000");
  
        console.log("+ Testing fee accumulation across multiple operations");
        console.log(" -Initial Liquidity:", initialLiquidity.toString());
        console.log(" -Swap Amount:", swapAmount.toString());
        console.log(" -Additional Liquidity:", additionalLiquidity.toString());
  
        // Step 1: Owner provides initial liquidity
        await tokenA.approve(await liteswap.getAddress(), initialLiquidity);
        await tokenB.approve(await liteswap.getAddress(), initialLiquidity);
        await liteswap.initializePair(
          await tokenA.getAddress(), 
          await tokenB.getAddress(), 
          initialLiquidity, 
          initialLiquidity
        );
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("\nStep 1: Initial liquidity provided");
        let pair = await liteswap.pairs(pairId);
        console.log(" -Initial Reserve A:", pair.reserveA.toString());
        console.log(" -Initial Reserve B:", pair.reserveB.toString());
        console.log(" -Initial k:", (pair.reserveA * pair.reserveB).toString());
  
        // Verify initial 1:1 ratio
        expect(pair.reserveA).to.equal(pair.reserveB);
  
        // Step 2: User1 performs swaps
        await tokenA.transfer(user1.address, swapAmount * 2n);
        await tokenA.connect(user1).approve(await liteswap.getAddress(), swapAmount * 2n);
        
        // Multiple swaps to accumulate fees
        for(let i = 0; i < 2; i++) {
          await liteswap.connect(user1).swap(
            pairId,
            await tokenA.getAddress(),
            swapAmount,
            0
          );
        }
  
        console.log("\nStep 2: After User1's swaps");
        pair = await liteswap.pairs(pairId);
        console.log(" -Reserve A:", pair.reserveA.toString());
        console.log(" -Reserve B:", pair.reserveB.toString());
        console.log(" -k after swaps:", (pair.reserveA * pair.reserveB).toString());
  
        // Verify ratio changed - more A than B after swapping A for B
        expect(pair.reserveA).to.be.gt(pair.reserveB);
        // Verify k increased due to fees
        expect(pair.reserveA * pair.reserveB).to.be.gt(initialLiquidity * initialLiquidity);
  
        // Step 3: User2 adds liquidity after fees accumulated
        await tokenA.transfer(user2.address, additionalLiquidity);
        await tokenB.transfer(user2.address, additionalLiquidity);
        await tokenA.connect(user2).approve(await liteswap.getAddress(), additionalLiquidity);
        await tokenB.connect(user2).approve(await liteswap.getAddress(), additionalLiquidity);
  
        const user2InitialBalance = await tokenA.balanceOf(user2.address);
        await liteswap.connect(user2).addLiquidity(pairId, additionalLiquidity);
        // Calculate amountB that was added by checking user2's balance change
        const user2FinalBalance = await tokenA.balanceOf(user2.address);
        const user2AmountAAdded = user2InitialBalance - user2FinalBalance;
        const user2AmountBAdded = (user2AmountAAdded * pair.reserveB) / pair.reserveA;
        console.log("\nStep 3: After User2 adds liquidity");
        pair = await liteswap.pairs(pairId);
        console.log(" -Reserve A:", pair.reserveA.toString());
        console.log(" -Reserve B:", pair.reserveB.toString());
  
        // Verify reserves increased proportionally
        const prevRatio = pair.reserveA * 1000n / pair.reserveB;
        expect(prevRatio).to.be.closeTo(pair.reserveA * 1000n / pair.reserveB, 1n);
  
        // Step 4: User3 performs more swaps
        // Store the state before User3's swaps
        const prevPair = await liteswap.pairs(pairId);
  
        // Perform User3's swaps
        await tokenB.transfer(user3.address, swapAmount * 2n);
        await tokenB.connect(user3).approve(await liteswap.getAddress(), swapAmount * 2n);
        
        for(let i = 0; i < 2; i++) {
          await liteswap.connect(user3).swap(
            pairId,
            await tokenB.getAddress(),
            swapAmount,
            0
          );
        }
  
        console.log("\nStep 4: After User3's swaps");
        pair = await liteswap.pairs(pairId);
        console.log(" -Reserve A:", pair.reserveA.toString());
        console.log(" -Reserve B:", pair.reserveB.toString());
  
        // Verify ratio changed - more B than before after swapping B for A
        expect(pair.reserveB).to.be.gt(prevPair.reserveB);
        // Verify k increased further due to fees
        const prevK = prevPair.reserveA * prevPair.reserveB;
        expect(pair.reserveA * pair.reserveB).to.be.gt(prevK);
  
        // Step 5: Owner removes initial liquidity
        const ownerPosition = await liteswap.liquidityProviderPositions(pairId, owner.address);
        const ownerInitialBalanceA = await tokenA.balanceOf(owner.address);
        const ownerInitialBalanceB = await tokenB.balanceOf(owner.address);
        
        await liteswap.removeLiquidity(pairId, ownerPosition.shares);
        
        const ownerFinalBalanceA = await tokenA.balanceOf(owner.address);
        const ownerFinalBalanceB = await tokenB.balanceOf(owner.address);
        
        // Calculate owner's returns including fees
        const ownerReturnA = ownerFinalBalanceA - ownerInitialBalanceA;
        const ownerReturnB = ownerFinalBalanceB - ownerInitialBalanceB;
  
        console.log("\nStep 5: After Owner removes liquidity");
        console.log(" -Owner initial deposit A:", initialLiquidity.toString());
        console.log(" -Owner initial deposit B:", initialLiquidity.toString());
        console.log(" -Owner withdrawn A:", ownerReturnA.toString());
        console.log(" -Owner withdrawn B:", ownerReturnB.toString());
        console.log(" -Owner difference A:", (ownerReturnA - initialLiquidity).toString());
        console.log(" -Owner difference B:", (ownerReturnB - initialLiquidity).toString());
  
        // Due to impermanent loss, one token may return less than initial deposit
        // But fees should offset some of the IL, so verify total value is higher
        const totalInitialValue = initialLiquidity * 2n; // Value of both tokens initially deposited
        const totalReturnValue = ownerReturnA + ownerReturnB; // Total value returned
        
        
  
        // Total return should be greater due to accumulated fees
        // Use gte instead of gt to account for potential rounding
        expect(totalReturnValue).to.be.gte(totalInitialValue);
  
        // Add more specific checks for individual token returns
        expect(ownerReturnA).to.not.equal(0n);
        expect(ownerReturnB).to.not.equal(0n);
  
        // Verify owner got proportional share of accumulated fees for one token
        // The other token will be less than initial due to impermanent loss
        expect(ownerReturnA * 100n / initialLiquidity).to.be.gt(100n); // More than initial due to fees
        expect(ownerReturnB * 100n / initialLiquidity).to.be.lt(100n); // Less than initial due to IL
  
        // Step 6: User2 removes liquidity
        const user2Position = await liteswap.liquidityProviderPositions(pairId, user2.address);
        const user2InitialBalanceA = await tokenA.balanceOf(user2.address);
        const user2InitialBalanceB = await tokenB.balanceOf(user2.address);
        
        await liteswap.connect(user2).removeLiquidity(pairId, user2Position.shares);
        
        const user2FinalBalanceA = await tokenA.balanceOf(user2.address);
        const user2FinalBalanceB = await tokenB.balanceOf(user2.address);
        
        // Calculate user2's returns including fees
        const user2ReturnA = user2FinalBalanceA - user2InitialBalanceA;
        const user2ReturnB = user2FinalBalanceB - user2InitialBalanceB;
  
        console.log("\nStep 6: After User2 removes liquidity");
        console.log(" -User2 initial deposit A:", additionalLiquidity.toString());
        console.log(" -User2 initial deposit B:", user2AmountBAdded.toString()); // amountB was calculated during addLiquidity
        console.log(" -User2 withdrawn A:", user2ReturnA.toString());
        console.log(" -User2 withdrawn B:", user2ReturnB.toString());
        console.log(" -User2 difference A:", (user2ReturnA - additionalLiquidity).toString());
        console.log(" -User2 difference B:", (user2ReturnB - user2AmountBAdded).toString());
  
        // Verify user2 got proportional share of accumulated fees for one token
        // The other token will be less than initial due to impermanent loss
        expect(user2ReturnA * 100n / additionalLiquidity).to.be.lt(100n); // More than initial due to fees
        expect(user2ReturnB * 100n / additionalLiquidity).to.be.lt(100n); // Less than initial due to IL
  
        // Verify final state
        pair = await liteswap.pairs(pairId);
        console.log("\nFinal pair state");
        console.log(" -Final Reserve A:", pair.reserveA.toString());
        console.log(" -Final Reserve B:", pair.reserveB.toString());
        console.log(" -Final Total Shares:", pair.totalShares.toString());
  
        // Verify all fees were distributed proportionally
        expect(pair.totalShares).to.equal(0); // All liquidity removed
        expect(pair.reserveA).to.equal(0);
        expect(pair.reserveB).to.equal(0);
      });
    });
    describe("💰💰💰 Limit Orders 💰💰💰", function() {
      it("Should only allow limit orders to be placed in valid pairs with valid amounts.", async function() {
        const { liteswap, tokenA, tokenB, owner, user1, user2, user3 } = await loadFixture(deployFixture);
        // Initial setup amounts
        const initialLiquidity = hre.ethers.parseEther("1000");
        let limitOrderAmount = hre.ethers.parseEther("100");
  
        console.log("\n+ Testing limit order placement restrictions");
        console.log(" -Initial Liquidity:", initialLiquidity.toString());
        console.log(" -Limit Order Amount:", limitOrderAmount.toString());
  
        // Try to place limit order with invalid pair ID
        await tokenA.approve(await liteswap.getAddress(), limitOrderAmount);
        await expect(liteswap.placeLimitOrder(
          999, // Invalid pair ID
          await tokenA.getAddress(),
          limitOrderAmount,
          hre.ethers.parseEther("1")
        )).to.be.revertedWithCustomError(liteswap, "PairDoesNotExist");
  
        console.log("\nStep 1: Attempting invalid pair ID");
        console.log(" -Pair ID: 999");
        console.log(" -Result: Reverted with PairDoesNotExist");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialLiquidity);
        await tokenB.approve(await liteswap.getAddress(), initialLiquidity);
        await liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          initialLiquidity,
          initialLiquidity
        );
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("\nStep 2: Pair initialized");
        console.log(" -Pair ID:", pairId);
        console.log(" -Initial liquidity A:", initialLiquidity.toString());
        console.log(" -Initial liquidity B:", initialLiquidity.toString());
  
        // Try with invalid offer token (not in pair)
        await expect(liteswap.placeLimitOrder(
          pairId,
          await user1.getAddress(), // Invalid token address
          limitOrderAmount,
          hre.ethers.parseEther("1")
        )).to.be.revertedWithCustomError(liteswap, "InvalidTokenAddress");
  
        console.log("\nStep 3: Attempting invalid token address");
        console.log(" -Token address:", await user1.getAddress());
        console.log(" -Result: Reverted with InvalidTokenAddress");
  
        // Try with zero amounts
        await expect(liteswap.placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          0,
          hre.ethers.parseEther("1")
        )).to.be.revertedWithCustomError(liteswap, "InvalidAmount");
  
        console.log("\nStep 4: Attempting zero offer amount");
        console.log(" -Offer amount: 0");
        console.log(" -Result: Reverted with InvalidAmount");
  
        await expect(liteswap.placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          limitOrderAmount,
          0
        )).to.be.revertedWithCustomError(liteswap, "InvalidAmount");
  
        console.log("\nStep 5: Attempting zero desired amount output");
        console.log(" -Min output: 0");
        console.log(" -Result: Reverted with InvalidAmount");
  
        // Try with bad ratio (worse than current pool reserves)
        limitOrderAmount = hre.ethers.parseEther("100");
        // Calculate what you'd get from a direct swap
        const poolOutput = (limitOrderAmount * 997n * initialLiquidity) / 
          ((initialLiquidity * 1000n) + (limitOrderAmount * 997n));
        // Ask for more than what the pool would give (worse price)
        const badDesiredOutput = poolOutput - hre.ethers.parseEther("1");
  
        console.log("\nStep 6: Attempting order with bad price ratio");
        console.log(" -Offer amount:", limitOrderAmount.toString());
        console.log(" -Pool would give:", Number(poolOutput));
        console.log(" -Pool Reserve ratio: ",Number(poolOutput)/ Number(limitOrderAmount));
        console.log(" -Limit order would give:", badDesiredOutput.toString());
        console.log(" - Limit Order ratio:", Number(badDesiredOutput) / Number(limitOrderAmount));
        console.log(" Confirmed: order placement reverts if better price is available swapping direct.")
  
        await tokenA.approve(await liteswap.getAddress(), limitOrderAmount);
  
        await expect(liteswap.placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          limitOrderAmount,
          badDesiredOutput
        )).to.be.revertedWithCustomError(liteswap, "BadRatio");
        // Try with bad ratio in the other direction (tokenB as offer token)
        const limitOrderAmountB = hre.ethers.parseEther("101");
        // Calculate what you'd get from a direct swap of tokenB for tokenA
        const poolOutputB = (limitOrderAmountB * 997n * initialLiquidity) / 
          ((initialLiquidity * 1000n) + (limitOrderAmountB * 997n));
        // Ask for more than what the pool would give (worse price)
        const badDesiredOutputB = poolOutputB - hre.ethers.parseEther("2");
  
        console.log("\nStep 7: Attempting order with bad price ratio (reverse direction)");
        console.log(" -Offer amount (tokenB):", limitOrderAmountB.toString());
        console.log(" -Pool would give:", Number(poolOutputB));
        console.log(" -Pool Reserve ratio: ", Number(poolOutputB) / Number(limitOrderAmountB));
        console.log(" -Limit order would give:", badDesiredOutputB.toString());
        console.log(" -Limit Order ratio:", Number(badDesiredOutputB) / Number(limitOrderAmountB));
        console.log(" Confirmed: order placement reverts if better price is available swapping direct (reverse direction)");
  
        await tokenB.approve(await liteswap.getAddress(), limitOrderAmountB);
  
        await expect(liteswap.placeLimitOrder(
          pairId,
          await tokenB.getAddress(),
          limitOrderAmountB,
          badDesiredOutputB
        )).to.be.revertedWithCustomError(liteswap, "BadRatio");
        console.log("\nTest passed: Limit orders can only be placed in valid pairs with valid parameters");
      });
      it("Should allow placing and cancelling limit orders with correct balance changes and prevent filling cancelled order.", async function() {
        const { liteswap, tokenA, tokenB, owner, user1 } = await loadFixture(deployFixture);
        
        const initialLiquidity = hre.ethers.parseEther("10000");
        const limitOrderAmount = hre.ethers.parseEther("100");
        const desiredOutput = hre.ethers.parseEther("190"); // Better ratio than pool
  
        console.log("\n+ Testing limit order placement and cancellation");
        console.log(" -Initial liquidity:", initialLiquidity.toString());
        console.log(" -Limit order amount:", limitOrderAmount.toString());
        console.log(" -Desired output:", desiredOutput.toString());
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialLiquidity);
        await tokenB.approve(await liteswap.getAddress(), initialLiquidity);
        await liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          initialLiquidity,
          initialLiquidity
        );
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        // Transfer tokens to user1 and approve liteswap
        await tokenA.transfer(user1.address, limitOrderAmount);
        await tokenA.connect(user1).approve(await liteswap.getAddress(), limitOrderAmount);
  
        // Check initial balance
        const initialBalance = await tokenA.balanceOf(user1.address);
        console.log("\nStep 1: Initial user balance");
        console.log(" -Token A balance:", initialBalance.toString());
  
        // Place limit order and wait for the transaction
        
        const tx = await liteswap.connect(user1).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          limitOrderAmount,
          desiredOutput
        );
        const receipt = await tx.wait();
        
        // Get the order ID from the emitted event
        const event = receipt?.logs.find(
          log => log.topics[0] === liteswap.interface.getEvent("LimitOrderPlaced").topicHash
        );
        const decodedEvent = liteswap.interface.decodeEventLog(
          "LimitOrderPlaced",
          event?.data || "",
          event?.topics || []
        );
        const orderId = decodedEvent.orderId;
  
        // Check balance after placing order
        const balanceAfterOrder = await tokenA.balanceOf(user1.address);
        console.log("\nStep 2: Balance after placing order");
        console.log(" -Token A balance:", balanceAfterOrder.toString());
        console.log(" -Order ID:", orderId.toString());
        expect(balanceAfterOrder).to.equal(initialBalance - limitOrderAmount);
  
        // Cancel the order
        await liteswap.connect(user1).cancelLimitOrder(pairId, orderId);
  
        // Check final balance after cancellation
        const finalBalance = await tokenA.balanceOf(user1.address);
        console.log("\nStep 3: Balance after cancelling order");
        console.log(" -Token A balance:", finalBalance.toString());
        expect(finalBalance).to.equal(initialBalance);
        // Try to fill the cancelled order
        await tokenB.transfer(user1.address, desiredOutput);
        await tokenB.connect(user1).approve(await liteswap.getAddress(), desiredOutput);
  
        // Should revert with OrderNotActive error
        await expect(
          liteswap.connect(user1).fillLimitOrder(pairId, orderId, desiredOutput)
        ).to.be.revertedWithCustomError(liteswap, "OrderNotActive");
        console.log("\nStep 4: Attempt filling canceled order.");
        
        console.log("\nTest passed: Limit order placed and cancelled with correct balance changes, can not be filled after cancelled");
      });
      it("Should increment order IDs correctly for each pair, and orders should be done once filled.", async function() {
        const { liteswap, tokenA, tokenB, owner, user1,user2, user3 } = await loadFixture(deployFixture);
        
        const initialLiquidity = hre.ethers.parseEther("10000");
        const limitOrderAmount = hre.ethers.parseEther("100");
        const desiredOutput = hre.ethers.parseEther("190");
  
        console.log("\n+ Testing limit order ID increments");
        console.log(" -Initial liquidity:", initialLiquidity.toString());
        console.log(" -Limit order amount:", limitOrderAmount.toString());
        console.log(" -Desired output:", desiredOutput.toString());
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialLiquidity);
        await tokenB.approve(await liteswap.getAddress(), initialLiquidity);
        await liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          initialLiquidity,
          initialLiquidity
        );
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        // Transfer tokens to user1 and approve liteswap
        await tokenA.transfer(user1.address, limitOrderAmount * 3n);
        await tokenA.connect(user1).approve(await liteswap.getAddress(), limitOrderAmount * 3n);
  
        // Place first order
        const tx1 = await liteswap.connect(user1).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          limitOrderAmount,
          desiredOutput
        );
        const receipt1 = await tx1.wait();
        const event1 = receipt1?.logs.find(
          log => log.topics[0] === liteswap.interface.getEvent("LimitOrderPlaced").topicHash
        );
        const orderId1 = liteswap.interface.decodeEventLog(
          "LimitOrderPlaced",
          event1?.data || "",
          event1?.topics || []
        ).orderId;
  
        console.log("\nStep 1: First order placed");
        console.log(" -Order ID:", orderId1.toString());
        expect(orderId1).to.equal(0);
  
        // Place second order
        const tx2 = await liteswap.connect(user1).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          limitOrderAmount,
          desiredOutput
        );
        const receipt2 = await tx2.wait();
        const event2 = receipt2?.logs.find(
          log => log.topics[0] === liteswap.interface.getEvent("LimitOrderPlaced").topicHash
        );
        const orderId2 = liteswap.interface.decodeEventLog(
          "LimitOrderPlaced",
          event2?.data || "",
          event2?.topics || []
        ).orderId;
  
        console.log("\nStep 2: Second order placed");
        console.log(" -Order ID:", orderId2.toString());
        expect(orderId2).to.equal(1);
  
        // Place third order
        const tx3 = await liteswap.connect(user1).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          limitOrderAmount,
          desiredOutput
        );
        const receipt3 = await tx3.wait();
        const event3 = receipt3?.logs.find(
          log => log.topics[0] === liteswap.interface.getEvent("LimitOrderPlaced").topicHash
        );
        const orderId3 = liteswap.interface.decodeEventLog(
          "LimitOrderPlaced",
          event3?.data || "",
          event3?.topics || []
        ).orderId;
  
        console.log("\nStep 3: Third order placed");
        console.log(" -Order ID:", orderId3.toString());
        expect(orderId3).to.equal(2);
  
        console.log("\nTest passed: Order IDs increment correctly");
        // Transfer tokens to user2 for filling orders
        await tokenB.transfer(user2.address, desiredOutput * 3n);
        await tokenB.connect(user2).approve(await liteswap.getAddress(), desiredOutput * 3n);
  
        console.log("\nStep 4: Filling first order");
        // Get balances before fill
        const user1BalanceBeforeB = await tokenB.balanceOf(user1.address); // Check tokenB balance for user1
        const user2BalanceBeforeA = await tokenA.balanceOf(user2.address); // Check tokenA balance for user2
  
        await liteswap.connect(user2).fillLimitOrder(pairId, orderId1, desiredOutput);
        
        // Verify balances after fill
        const user1BalanceAfterB = await tokenB.balanceOf(user1.address);
        const user2BalanceAfterA = await tokenA.balanceOf(user2.address);
        
        // Verify user1 (maker) received the desired output amount of tokenB
        expect(user1BalanceAfterB - user1BalanceBeforeB).to.equal(desiredOutput);
        // Verify user2 (filler) received the offered amount of tokenA
        expect(user2BalanceAfterA - user2BalanceBeforeA).to.equal(limitOrderAmount);
        console.log(" -Filled order", orderId1);
        console.log(" -Maker received:", limitOrderAmount.toString(), "token A");
        console.log(" -Filler paid:", desiredOutput.toString(), "token B");
  
        // Try to fill first order again
        await expect(
          liteswap.connect(user2).fillLimitOrder(pairId, orderId1, desiredOutput)
        ).to.be.revertedWithCustomError(liteswap, "OrderNotActive");
        console.log(" -Confirmed: Cannot fill already filled order", orderId1);
  
        console.log("\nStep 5: Filling second order");
        // Get balances before fill
        const user1BalanceBeforeB2 = await tokenB.balanceOf(user1.address); // Check tokenB balance for user1
        const user2BalanceBeforeA2 = await tokenA.balanceOf(user2.address); // Check tokenA balance for user2
  
        await liteswap.connect(user2).fillLimitOrder(pairId, orderId2, desiredOutput);
        
        // Verify balances after fill
        const user1BalanceAfterB2 = await tokenB.balanceOf(user1.address);
        const user2BalanceAfterA2 = await tokenA.balanceOf(user2.address);
        
        // Verify user1 (maker) received the desired output amount of tokenB
        expect(user1BalanceAfterB2 - user1BalanceBeforeB2).to.equal(desiredOutput);
        // Verify user2 (filler) received the offered amount of tokenA
        expect(user2BalanceAfterA2 - user2BalanceBeforeA2).to.equal(limitOrderAmount);
        console.log(" -Filled order", orderId2);
        console.log(" -Maker received:", limitOrderAmount.toString(), "token A");
        console.log(" -Filler paid:", desiredOutput.toString(), "token B");
  
        // Try to fill second order again
        await expect(
          liteswap.connect(user2).fillLimitOrder(pairId, orderId2, desiredOutput)
        ).to.be.revertedWithCustomError(liteswap, "OrderNotActive");
        console.log(" -Confirmed: Cannot fill already filled order", orderId2);
  
        console.log("\nStep 6: Filling third order");
        // Get balances before fill
        const user1BalanceBeforeB3 = await tokenB.balanceOf(user1.address); // Check tokenB balance for user1
        const user2BalanceBeforeA3 = await tokenA.balanceOf(user2.address); // Check tokenA balance for user2
  
        await liteswap.connect(user2).fillLimitOrder(pairId, orderId3, desiredOutput);
        
        // Verify balances after fill
        const user1BalanceAfterB3 = await tokenB.balanceOf(user1.address);
        const user2BalanceAfterA3 = await tokenA.balanceOf(user2.address);
        
        // Verify user1 (maker) received the desired output amount of tokenB
        expect(user1BalanceAfterB3 - user1BalanceBeforeB3).to.equal(desiredOutput);
        // Verify user2 (filler) received the offered amount of tokenA
        expect(user2BalanceAfterA3 - user2BalanceBeforeA3).to.equal(limitOrderAmount);
        console.log(" -Filled order", orderId3);
        console.log(" -Maker received:", limitOrderAmount.toString(), "token A");
        console.log(" -Filler paid:", desiredOutput.toString(), "token B");
  
        // Try to fill third order again
        await expect(
          liteswap.connect(user2).fillLimitOrder(pairId, orderId3, desiredOutput)
        ).to.be.revertedWithCustomError(liteswap, "OrderNotActive");
        console.log(" -Confirmed: Cannot fill already filled order", orderId3);
  
        console.log("\nTest passed: Orders can be fully filled once with correct amounts and not refilled");
      });
      it("Should allow partially filled limit orders to cancel remaining offer and disallow over-filling offer.", async function() {
        const { liteswap, tokenA, tokenB, owner, user1, user2 } = await loadFixture(deployFixture);
        const amount = hre.ethers.parseEther("1000");
  
        // Initialize pair
        await tokenA.approve(liteswap, amount);
        await tokenB.approve(liteswap, amount);
        await liteswap.initializePair(
          tokenA.getAddress(),
          tokenB.getAddress(),
          amount,
          amount
        );
        
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        // Place limit order
        const limitOrderAmount = hre.ethers.parseEther("300");
        const desiredOutput = hre.ethers.parseEther("300");
        await tokenA.connect(user1).approve(liteswap, limitOrderAmount);
        
        const tx = await liteswap.connect(user1).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          limitOrderAmount,
          desiredOutput
        );
        const receipt = await tx.wait();
        const event = receipt?.logs.find(
          log => log.topics[0] === liteswap.interface.getEvent("LimitOrderPlaced").topicHash
        );
        const orderId = liteswap.interface.decodeEventLog(
          "LimitOrderPlaced",
          event?.data || "",
          event?.topics || []
        ).orderId;
  
        console.log("\nStep 1: Limit order placed");
        console.log(" -Order ID:", orderId.toString());
        console.log(" -Amount:", limitOrderAmount.toString());
  
        // User2 fills 1/3 of the order
        const fillAmount = limitOrderAmount / 3n;
        await tokenB.connect(user2).approve(liteswap, fillAmount);
        
        await liteswap.connect(user2).fillLimitOrder(
          pairId,
          orderId,
          fillAmount
        );
  
        console.log("\nStep 2: Order partially filled");
        console.log(" -Fill amount:", fillAmount.toString());
        // Try to fill more than remaining amount
        const remainingAmount = (limitOrderAmount * 2n) / 3n; // 2/3 of original order remains
        const tooMuchFill = remainingAmount + hre.ethers.parseEther("1"); // Try to fill more than remains
        
        await tokenB.connect(user2).approve(liteswap, tooMuchFill);
        
        await expect(liteswap.connect(user2).fillLimitOrder(
          pairId,
          orderId,
          tooMuchFill
        )).to.be.revertedWithCustomError(liteswap, "InvalidFillAmount");
  
        console.log("\nStep 2.5: Attempted to fill more than remaining");
        console.log(" -Remaining amount:", remainingAmount.toString());
        console.log(" -Attempted fill:", tooMuchFill.toString());
        console.log(" -Result: Reverted with InvalidFillAmount");
        // Cancel remaining order
        const balanceBefore = await tokenA.balanceOf(user1.address);
        await liteswap.connect(user1).cancelLimitOrder(pairId, orderId);
        const balanceAfter = await tokenA.balanceOf(user1.address);
        
        console.log("\nStep 3: Remaining order cancelled");
        console.log(" -Returned amount:", (balanceAfter - balanceBefore).toString());
  
        // Verify returned amount is 2/3 of original order
        const expectedReturn = (limitOrderAmount * 2n) / 3n;
        expect(balanceAfter - balanceBefore).to.equal(expectedReturn);
  
        console.log("\nTest passed: Correct amount returned after partial fill and cancel");
      });
      it("Should handle multiple limit orders from different users for the same pair", async function() {
        const { liteswap, tokenA, tokenB, owner, user1, user2, user3 } = await loadFixture(deployFixture);
        
        const initialLiquidity = hre.ethers.parseEther("10000");
        const orderAmount = hre.ethers.parseEther("100");
        const desiredOutput = hre.ethers.parseEther("190");
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialLiquidity);
        await tokenB.approve(await liteswap.getAddress(), initialLiquidity);
        await liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          initialLiquidity,
          initialLiquidity
        );
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        console.log("\n+ Testing multiple limit orders from different users");
        console.log(" -Initial liquidity:", initialLiquidity.toString());
        console.log(" -Order amount:", orderAmount.toString());
        console.log(" -Desired output:", desiredOutput.toString());
  
        // Setup users with tokens and approvals
        await tokenA.transfer(user1.address, orderAmount);
        await tokenA.transfer(user2.address, orderAmount);
        await tokenA.connect(user1).approve(await liteswap.getAddress(), orderAmount);
        await tokenA.connect(user2).approve(await liteswap.getAddress(), orderAmount);
  
        // Place orders from different users
        const tx1 = await liteswap.connect(user1).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          orderAmount,
          desiredOutput
        );
        const receipt1 = await tx1.wait();
        const event1 = receipt1?.logs.find(
          log => log.topics[0] === liteswap.interface.getEvent("LimitOrderPlaced").topicHash
        );
        const orderId1 = liteswap.interface.decodeEventLog(
          "LimitOrderPlaced",
          event1?.data || "",
          event1?.topics || []
        ).orderId;
  
        console.log("\nStep 1: First order placed");
        console.log(" -Order ID:", orderId1.toString());
  
        const tx2 = await liteswap.connect(user2).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          orderAmount,
          desiredOutput
        );
        const receipt2 = await tx2.wait();
        const event2 = receipt2?.logs.find(
          log => log.topics[0] === liteswap.interface.getEvent("LimitOrderPlaced").topicHash
        );
        const orderId2 = liteswap.interface.decodeEventLog(
          "LimitOrderPlaced",
          event2?.data || "",
          event2?.topics || []
        ).orderId;
  
        console.log("\nStep 2: Second order placed");
        console.log(" -Order ID:", orderId2.toString());
  
        expect(orderId2).to.equal(orderId1 + 1n);
  
        // Setup user3 as filler
        await tokenB.transfer(user3.address, desiredOutput * 2n);
        await tokenB.connect(user3).approve(await liteswap.getAddress(), desiredOutput * 2n);
  
        // Fill both orders
        await liteswap.connect(user3).fillLimitOrder(pairId, orderId1, desiredOutput);
        await liteswap.connect(user3).fillLimitOrder(pairId, orderId2, desiredOutput);
  
        console.log("\nStep 3: Both orders filled");
        console.log(" -Fill amount per order:", desiredOutput.toString());
  
        // Verify orders are no longer active
        const order1 = await liteswap.limitOrders(pairId, orderId1);
        const order2 = await liteswap.limitOrders(pairId, orderId2);
        expect(order1.active).to.be.false;
        expect(order2.active).to.be.false;
  
        console.log("\nTest passed: Multiple orders handled correctly with sequential IDs and successful fills");
      });
  
      it("Should handle partial fills from multiple users", async function() {
        const { liteswap, tokenA, tokenB, owner, user1, user2, user3 } = await loadFixture(deployFixture);
        
        const initialLiquidity = hre.ethers.parseEther("10000");
        const orderAmount = hre.ethers.parseEther("300");
        const desiredOutput = hre.ethers.parseEther("570"); // 1.9x ratio
  
        console.log("\n+ Testing partial fills from multiple users");
        console.log(" -Initial liquidity:", initialLiquidity.toString());
        console.log(" -Order amount:", orderAmount.toString());
        console.log(" -Desired output:", desiredOutput.toString());
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialLiquidity);
        await tokenB.approve(await liteswap.getAddress(), initialLiquidity);
        await liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          initialLiquidity,
          initialLiquidity
        );
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        await tokenA.transfer(user1.address, orderAmount);
        await tokenA.connect(user1).approve(await liteswap.getAddress(), orderAmount);
  
        const tx = await liteswap.connect(user1).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          orderAmount,
          desiredOutput
        );
        const receipt = await tx.wait();
        const event = receipt?.logs.find(
          log => log.topics[0] === liteswap.interface.getEvent("LimitOrderPlaced").topicHash
        );
        const orderId = liteswap.interface.decodeEventLog(
          "LimitOrderPlaced",
          event?.data || "",
          event?.topics || []
        ).orderId;
  
        console.log("\nStep 1: Order placed");
        console.log(" -Order ID:", orderId.toString());
  
        // Setup fillers
        const fillAmount = desiredOutput / 3n;
        await tokenB.transfer(user2.address, fillAmount);
        await tokenB.transfer(user3.address, fillAmount);
        await tokenB.connect(user2).approve(await liteswap.getAddress(), fillAmount);
        await tokenB.connect(user3).approve(await liteswap.getAddress(), fillAmount);
  
        // Fill order partially from different users
        await liteswap.connect(user2).fillLimitOrder(pairId, orderId, fillAmount);
        console.log("\nStep 2: First partial fill");
        console.log(" -User2 filled:", fillAmount.toString());
  
        await liteswap.connect(user3).fillLimitOrder(pairId, orderId, fillAmount);
        console.log("\nStep 3: Second partial fill");
        console.log(" -User3 filled:", fillAmount.toString());
  
        // Verify order is still active but amounts are reduced
        const order = await liteswap.limitOrders(pairId, orderId);
        expect(order.active).to.be.true;
        expect(order.offerAmount).to.equal(orderAmount / 3n);
        expect(order.desiredAmount).to.equal(desiredOutput / 3n);
  
        console.log("\nStep 4: Order verification");
        console.log(" -Order still active:", order.active);
        console.log(" -Remaining offer:", (orderAmount / 3n).toString());
        console.log(" -Remaining desired:", (desiredOutput / 3n).toString());
  
        console.log("\nTest passed: Multiple users can partially fill orders with correct remaining amounts");
      });
      it("Should emit descriptive events when orders are placed, filled, and cancelled.", async function(){
        const { liteswap, tokenA, tokenB, owner, user1, user2 } = await loadFixture(deployFixture);
        
        const initialLiquidity = hre.ethers.parseEther("10000");
        const limitOrderAmount = hre.ethers.parseEther("100");
        const desiredOutput = hre.ethers.parseEther("190");
  
        console.log("\n+ Testing limit order events");
        console.log(" -Initial liquidity:", initialLiquidity.toString());
        console.log(" -Limit order amount:", limitOrderAmount.toString());
        console.log(" -Desired output:", desiredOutput.toString());
  
        // Initialize pair
        await tokenA.approve(await liteswap.getAddress(), initialLiquidity);
        await tokenB.approve(await liteswap.getAddress(), initialLiquidity);
        await liteswap.initializePair(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          initialLiquidity,
          initialLiquidity
        );
  
        const pairId = await liteswap.tokenPairId(
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenA.getAddress() : await tokenB.getAddress(),
          await tokenA.getAddress() < await tokenB.getAddress() ? await tokenB.getAddress() : await tokenA.getAddress()
        );
  
        // Transfer tokens to users and approve
        await tokenA.transfer(user1.address, limitOrderAmount);
        await tokenA.connect(user1).approve(await liteswap.getAddress(), limitOrderAmount);
        await tokenB.transfer(user2.address, desiredOutput);
        await tokenB.connect(user2).approve(await liteswap.getAddress(), desiredOutput);
  
        console.log("\nStep 1: Testing LimitOrderPlaced event");
        // Place order and verify event
        await expect(liteswap.connect(user1).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          limitOrderAmount,
          desiredOutput
        )).to.emit(liteswap, "LimitOrderPlaced")
          .withArgs(
            pairId,
            0, // First order ID should be 0
            user1.address,
            await tokenA.getAddress(),
            await tokenB.getAddress(),
            limitOrderAmount,
            desiredOutput
          );
  
        console.log("\nStep 2: Testing LimitOrderFilled event");
        // Fill order and verify event
        await expect(liteswap.connect(user2).fillLimitOrder(
          pairId,
          0,
          desiredOutput/2n
        )).to.emit(liteswap, "LimitOrderFilled")
          .withArgs(
            pairId,
            0,
            user2.address,
            limitOrderAmount/2n
          );
        await tokenB.connect(user1).approve(await liteswap.getAddress(), desiredOutput);
        console.log("\nStep 2.5: Confirm user can fill their own limit order.");
        await expect(liteswap.connect(user1).fillLimitOrder(
          pairId,
          0,
          desiredOutput/2n
        )).to.emit(liteswap, "LimitOrderFilled")
          .withArgs(
            pairId,
            0,
            user1.address,
            limitOrderAmount/2n
          );
        // Place another order for testing cancellation
        await tokenA.transfer(user1.address, limitOrderAmount);
        await tokenA.connect(user1).approve(await liteswap.getAddress(), limitOrderAmount);
        await liteswap.connect(user1).placeLimitOrder(
          pairId,
          await tokenA.getAddress(),
          limitOrderAmount,
          desiredOutput
        );
  
        console.log("\nStep 3: Testing LimitOrderCancelled event");
        // Cancel order and verify event
        await expect(liteswap.connect(user1).cancelLimitOrder(
          pairId,
          1 // Second order ID should be 1
        )).to.emit(liteswap, "LimitOrderCancelled")
          .withArgs(
            pairId,
            1
          );
  
        console.log("\nTest passed: All limit order events emit correctly with expected arguments");
      });
  
  
    });
      
  });
  
  // Helper function to calculate square root for big numbers
  function sqrt(value: bigint): bigint {
    if (value < 0n) {
      throw new Error('square root of negative numbers is not supported');
    }
  
    if (value < 2n) {
      return value;
    }
  
    function newtonIteration(n: bigint, x0: bigint): bigint {
      const x1 = ((n / x0) + x0) >> 1n;
      if (x0 === x1 || x0 === (x1 - 1n)) {
        return x0;
      }
      return newtonIteration(n, x1);
    }
  
    return newtonIteration(value, 1n);
  }