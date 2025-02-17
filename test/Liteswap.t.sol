// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Liteswap} from "../src/Liteswap.sol";
import {TestERC20} from "./TestERC20.sol"; 
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol"; 
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
abstract contract SetUp is Test {
    Liteswap public liteswap;
    TestERC20 public tokenA;
    TestERC20 public tokenB;
    
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address poorUser = address(0x1);
    
    uint256 public constant INITIAL_MINT = 1_000_000_000_000 ether;

    function setUp() public virtual {
        // Set up accounts
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy contracts
        liteswap = new Liteswap();
        tokenA = new TestERC20("Token A", "TKNA");
        tokenB = new TestERC20("Token B", "TKNB");

        // Mint tokens to users
        tokenA.mint(owner, INITIAL_MINT);
        tokenA.mint(user1, INITIAL_MINT);
        tokenA.mint(user2, INITIAL_MINT);
        tokenA.mint(user3, INITIAL_MINT);
        
        tokenB.mint(owner, INITIAL_MINT);
        tokenB.mint(user1, INITIAL_MINT);
        tokenB.mint(user2, INITIAL_MINT);
        tokenB.mint(user3, INITIAL_MINT);
    }
    // Helper function to initialize a pair
    function _initializePair(uint256 amountA, uint256 amountB) internal returns (uint256 pairId) {
        tokenA.approve(address(liteswap), amountA);
        tokenB.approve(address(liteswap), amountB);
        
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        
        liteswap.initializePair(address(tokenA), address(tokenB), amountA, amountB);
        pairId = liteswap.tokenPairId(token0, token1);
    }
}

contract LiteswapPairInitializationTests is Test, SetUp {
    
    // First test: Initialize with zero address
    function test_RevertWhenInitializingWithZeroAddress() public {
        uint256 amount = 1000 ether;

        // Test zero address for token B
        vm.expectRevert(abi.encodeWithSignature("InvalidTokenAddress()"));
        liteswap.initializePair(address(tokenA), address(0), amount, amount);

        // Test zero address for token A
        vm.expectRevert(abi.encodeWithSignature("InvalidTokenAddress()"));
        liteswap.initializePair(address(0), address(tokenB), amount, amount);
    }

    // Second test: Initialize with same token address
    function test_RevertWhenInitializingWithSameToken() public {
        uint256 amount = 1000 ether;

        vm.expectRevert(abi.encodeWithSignature("InvalidTokenAddress()"));
        liteswap.initializePair(address(tokenA), address(tokenA), amount, amount);
    }

    // Third test: Initialize with zero amount
    function test_RevertWhenInitializingWithZeroAmount() public {
        uint256 amount = 1000 ether;

        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        liteswap.initializePair(address(tokenA), address(tokenB), 0, amount);

        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        liteswap.initializePair(address(tokenA), address(tokenB), amount, 0);
    }

    // Fourth test: Initialize without token allowance
    function test_RevertWhenInitializingWithoutAllowance() public {
        uint256 amount = 1000 ether;

        // Test with no allowance - expect insufficient allowance error
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientAllowance.selector);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        // Test with only one token approved
        tokenA.approve(address(liteswap), amount);
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientAllowance.selector);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);
    }
    // Fifth test: Correctly initialize pair and emit events
    function test_CorrectlyInitializePairAndEmitEvents() public {
        uint256 amount = 1000 ether;

        // Approve tokens
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);

        // Get initial balances
        uint256 initialBalanceA = tokenA.balanceOf(address(this));
        uint256 initialBalanceB = tokenB.balanceOf(address(this));

        // Get token addresses in sorted order
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);

        // Get the next pair ID (current + 1)
        uint256 expectedPairId = liteswap._pairIdCount();

        // Set up event expectations with complete event data
        vm.expectEmit(true, true, true, true);
        emit Liteswap.PairInitialized(expectedPairId, token0, token1);
        
        vm.expectEmit(true, true, true, true);
        emit Liteswap.LiquidityAdded(expectedPairId, address(this), amount, amount, sqrt(amount * amount));
        
        vm.expectEmit(true, true, true, true);
        emit Liteswap.ReservesUpdated(expectedPairId, amount, amount);

        // Initialize pair
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        // Verify the actual pair ID matches our prediction
        uint256 actualPairId = liteswap.tokenPairId(token0, token1);
        assertEq(actualPairId, expectedPairId, "Pair ID prediction was incorrect");

        // Verify pair state
        (address token0_, address token1_, uint256 reserveA, uint256 reserveB, uint256 totalShares, bool initialized) = liteswap.pairs(expectedPairId);
        assertEq(reserveA, amount);
        assertEq(reserveB, amount);
        assertEq(totalShares, sqrt(amount * amount));

        // Verify token transfers
        assertEq(tokenA.balanceOf(address(this)), initialBalanceA - amount);
        assertEq(tokenB.balanceOf(address(this)), initialBalanceB - amount);
    }

    // Sixth test: Correctly sort tokens by address
    function test_CorrectlySortTokensByAddress() public {
        uint256 amount = 1000 ether;

        // Approve tokens
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);

        // Add console logs to debug token addresses
        console2.log("TokenA address:", address(tokenA));
        console2.log("TokenB address:", address(tokenB));

        // Initialize pair in reverse order
        liteswap.initializePair(address(tokenB), address(tokenA), amount, amount);

        // Get token addresses in sorted order
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);

        // Get pair ID
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Get the actual tokens from the pair to verify sorting
        (address actualToken0, address actualToken1,,,, ) = liteswap.pairs(pairId);
        
        // Add debug logs
        console2.log("Expected token0:", token0);
        console2.log("Actual token0:", actualToken0);
        console2.log("Expected token1:", token1);
        console2.log("Actual token1:", actualToken1);

        assertEq(actualToken0, token0, "Token0 not correctly sorted");
        assertEq(actualToken1, token1, "Token1 not correctly sorted");
    }

    // Seventh test: Revert when initial shares below minimum
    function test_RevertWhenInitialSharesBelowMinimum() public {
        uint256 tinyAmount = 1;

        // Approve tokens
        tokenA.approve(address(liteswap), tinyAmount);
        tokenB.approve(address(liteswap), tinyAmount);

        // Update the expected error to match the contract
        vm.expectRevert(abi.encodeWithSignature("InsufficientLiquidity()"));
        liteswap.initializePair(address(tokenA), address(tokenB), tinyAmount, tinyAmount);
    }

    // Eighth test: Correctly calculate initial shares as geometric mean
    function test_CorrectlyCalculateInitialShares() public {
        uint256 amountA = 1000 ether;
        uint256 amountB = 1000 ether;

        // Approve tokens
        tokenA.approve(address(liteswap), amountA);
        tokenB.approve(address(liteswap), amountB);

        // Initialize pair
        liteswap.initializePair(address(tokenA), address(tokenB), amountA, amountB);
        // Get token addresses in sorted order
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        // Get pair ID
        uint256 newPairId = liteswap.tokenPairId(token0, token1);

        // Get total shares
        (,,,,uint256 totalShares,) = liteswap.pairs(newPairId);

        // Verify shares equals geometric mean
        assertEq(totalShares, sqrt(amountA * amountB));
    }
    // Ninth test: Revert if provider has insufficient balance
    function test_RevertWhenInsufficientBalance() public {
        uint256 amount = 1000 ether;
        

        vm.startPrank(poorUser);

        // Approve tokens without having balance
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);

        // Should revert due to insufficient balance
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, poorUser, 0, amount));
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        vm.stopPrank();
    }

    // Tenth test: Revert if insufficient allowance
    function test_RevertWhenInsufficientAllowance() public {
        uint256 amount = 1000 ether;
        uint256 lowAllowance = amount - 1;

        // Mint tokens but set insufficient allowance
        tokenA.approve(address(liteswap), lowAllowance);
        tokenB.approve(address(liteswap), amount);

        // Should revert with insufficient allowance error
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientAllowance.selector);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        // Test other token insufficient allowance
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), lowAllowance);

        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientAllowance.selector);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);
    }

    // Fuzz test: Initialize pair with random valid amounts
    function testFuzz_InitializePairWithRandomAmounts(uint256 amountA, uint256 amountB) public {
        // Bound amounts to be reasonable and above minimum shares
        amountA = bound(amountA, 1000 ether, 1_000_000 ether);
        amountB = bound(amountB, 1000 ether, 1_000_000 ether);

        // Approve tokens
        tokenA.approve(address(liteswap), amountA);
        tokenB.approve(address(liteswap), amountB);

        // Initialize pair
        liteswap.initializePair(address(tokenA), address(tokenB), amountA, amountB);

        // Get pair ID
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Verify reserves match input amounts
        (,, uint256 reserveA, uint256 reserveB, uint256 totalShares,) = liteswap.pairs(pairId);
        assertEq(reserveA, amountA);
        assertEq(reserveB, amountB);
        assertEq(totalShares, sqrt(amountA * amountB));
    }

    // Fuzz test: Verify geometric mean calculation with random amounts
    function testFuzz_GeometricMeanCalculation(uint256 amountA, uint256 amountB) public {
        // Bound amounts to prevent overflow
        amountA = bound(amountA, 1000 ether, 1_000_000 ether);
        amountB = bound(amountB, 1000 ether, 1_000_000 ether);

        uint256 calculatedShares = sqrt(amountA * amountB);
        
        // Verify calculated shares are between amountA and amountB
        if (amountA > amountB) {
            assertGe(calculatedShares, amountB);
            assertLe(calculatedShares, amountA);
        } else {
            assertGe(calculatedShares, amountA);
            assertLe(calculatedShares, amountB);
        }
    }

    // Fuzz test: Verify pair initialization reverts with tiny amounts
    function testFuzz_RevertWithTinyAmounts(uint256 amountA, uint256 amountB) public {
        // Bound amounts to be below minimum shares threshold
        amountA = bound(amountA, 1, 999);
        amountB = bound(amountB, 1, 999);

        tokenA.approve(address(liteswap), amountA);
        tokenB.approve(address(liteswap), amountB);

        vm.expectRevert(abi.encodeWithSignature("InsufficientLiquidity()"));
        liteswap.initializePair(address(tokenA), address(tokenB), amountA, amountB);
    }

    // Helper function to calculate square root
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

contract LiteswapLiquidityAddTests is Test, SetUp {
    function test_RevertWhenAddingToNonExistentPair() public {
        uint256 amount = 1000 ether;

        vm.expectRevert(abi.encodeWithSignature("PairDoesNotExist()"));
        liteswap.addLiquidity(999, amount);
    }

    function test_CorrectlyAddLiquidityToExistingPair() public {
        uint256 initialAmount = 1000 ether;
        uint256 addAmount = 500 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Add more liquidity
        tokenA.approve(address(liteswap), addAmount);
        tokenB.approve(address(liteswap), addAmount);
        
        vm.expectEmit(true, true, true, true);
        emit Liteswap.LiquidityAdded(pairId, address(this), addAmount, addAmount, addAmount);

        liteswap.addLiquidity(pairId, addAmount);

        // Verify updated reserves
        (,, uint256 reserveA, uint256 reserveB,,) = liteswap.pairs(pairId);
        assertEq(reserveA, initialAmount + addAmount);
        assertEq(reserveB, initialAmount + addAmount);
    }

    function test_RevertWhenAddingZeroAmount() public {
        uint256 initialAmount = 1000 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        liteswap.addLiquidity(pairId, 0);
    }

    function test_RevertWhenInsufficientTokenAllowance() public {
        uint256 initialAmount = 1000 ether;
        uint256 addAmount = 500 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Don't approve tokens before adding liquidity
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientAllowance.selector);
        liteswap.addLiquidity(pairId, addAmount);
    }

    function test_CalculateCorrectSharesForUnevenLiquidityAdd() public {
        uint256 initialAmount = 1000 ether;
        uint256 addAmountA = 500 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Calculate expected token B amount
        uint256 expectedAmountB = addAmountA;

        // Approve tokens for the add
        tokenA.approve(address(liteswap), addAmountA);
        tokenB.approve(address(liteswap), expectedAmountB);

        // Get initial position
        (uint256 initialShares,) = liteswap.liquidityProviderPositions(pairId, address(this));

        // Expected new shares should be proportional to contribution
        uint256 expectedNewShares = (initialShares * addAmountA) / initialAmount;

        vm.expectEmit(true, true, true, true);
        emit Liteswap.LiquidityAdded(pairId, address(this), addAmountA, expectedAmountB, expectedNewShares);

        liteswap.addLiquidity(pairId, addAmountA);

        // Verify final shares
        (uint256 finalShares,) = liteswap.liquidityProviderPositions(pairId, address(this));
        assertEq(finalShares, initialShares + expectedNewShares);
    }

    function testFuzz_AddLiquidityWithRandomAmounts(uint256 initialAmount, uint256 addAmount) public {
        // Bound amounts to reasonable ranges
        initialAmount = bound(initialAmount, 1000 ether, 1_000_000 ether);
        addAmount = bound(addAmount, 1000 ether, 1_000_000 ether);

        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Record initial state
        (,, uint256 initialReserveA, uint256 initialReserveB,,) = liteswap.pairs(pairId);
        (uint256 initialShares,) = liteswap.liquidityProviderPositions(pairId, address(this));

        // Add liquidity
        tokenA.approve(address(liteswap), addAmount);
        tokenB.approve(address(liteswap), addAmount);
        liteswap.addLiquidity(pairId, addAmount);

        // Verify final state
        (,, uint256 finalReserveA, uint256 finalReserveB,,) = liteswap.pairs(pairId);
        (uint256 finalShares,) = liteswap.liquidityProviderPositions(pairId, address(this));

        // Verify reserves increased correctly
        assertEq(finalReserveA, initialReserveA + addAmount);
        assertEq(finalReserveB, initialReserveB + addAmount);

        // Verify shares increased proportionally
        uint256 expectedNewShares = (initialShares * addAmount) / initialAmount;
        assertEq(finalShares, initialShares + expectedNewShares);
    }

    function testFuzz_AddLiquidityMaintainsRatio(uint256 initialAmount, uint256 addAmount) public {
        // Bound amounts to reasonable ranges
        initialAmount = bound(initialAmount, 1000 ether, 1_000_000 ether);
        addAmount = bound(addAmount, 1000 ether, 1_000_000 ether);

        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Add liquidity
        tokenA.approve(address(liteswap), addAmount);
        tokenB.approve(address(liteswap), addAmount);
        liteswap.addLiquidity(pairId, addAmount);

        // Get final reserves
        (,, uint256 finalReserveA, uint256 finalReserveB,,) = liteswap.pairs(pairId);

        // Verify reserves maintain 1:1 ratio
        assertEq(finalReserveA, finalReserveB);
    }

}
contract LiteswapLiquidityRemoveTests is Test, SetUp {
    function test_RevertWhenRemovingFromNonExistentPosition() public {
        uint256 shares = 100 ether;

        vm.expectRevert(abi.encodeWithSignature("NoPosition()"));
        liteswap.removeLiquidity(999, shares);
    }

    function test_CorrectlyRemoveLiquidity() public {
        uint256 amount = 1000 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Get initial position
        (uint256 shares,) = liteswap.liquidityProviderPositions(pairId, address(this));

        vm.expectEmit(true, true, true, true);
        emit Liteswap.LiquidityRemoved(pairId, address(this), amount, amount, shares);

        liteswap.removeLiquidity(pairId, shares);

        // Verify position is cleared
        (uint256 finalShares,) = liteswap.liquidityProviderPositions(pairId, address(this));
        assertEq(finalShares, 0);
    }

    function test_RevertWhenRemovingZeroShares() public {
        uint256 amount = 1000 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        liteswap.removeLiquidity(pairId, 0);
    }

    function test_RevertWhenRemovingMoreSharesThanOwned() public {
        uint256 amount = 1000 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Get current shares
        (uint256 shares,) = liteswap.liquidityProviderPositions(pairId, address(this));
        uint256 tooManyShares = shares + 1;

        vm.expectRevert(abi.encodeWithSignature("InsufficientShares()"));
        liteswap.removeLiquidity(pairId, tooManyShares);
    }

    function test_CalculateCorrectTokenAmountsForPartialRemove() public {
        uint256 amount = 1000 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Get initial position and pair state
        (uint256 shares,) = liteswap.liquidityProviderPositions(pairId, address(this));
        (,, uint256 reserveA, uint256 reserveB,,) = liteswap.pairs(pairId);
        
        // Remove one third of shares
        uint256 sharesToRemove = shares / 3;
        
        uint256 expectedAmountA = amount / 3; // 1/3 of initial amount
        uint256 expectedAmountB = amount / 3;
        
        vm.expectEmit(true, true, true, true);
        emit Liteswap.LiquidityRemoved(pairId, address(this), expectedAmountA, expectedAmountB, sharesToRemove);

        liteswap.removeLiquidity(pairId, sharesToRemove);

        // Verify reserves were updated correctly
        (,, uint256 finalReserveA, uint256 finalReserveB,,) = liteswap.pairs(pairId);
        assertEq(finalReserveA, amount - expectedAmountA); // 2/3 remaining
        assertEq(finalReserveB, amount - expectedAmountB);
    }

    function testFuzz_RemoveLiquidityProportions(uint256 initialAmount, uint256 removePercent) public {
        // Bound initial amount to reasonable range
        initialAmount = bound(initialAmount, 1000 ether, 1_000_000 ether);
        // Bound remove percent between 1% and 99%
        removePercent = bound(removePercent, 1, 99);

        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Get initial shares
        (uint256 shares,) = liteswap.liquidityProviderPositions(pairId, address(this));
        
        // Calculate shares to remove based on percentage
        uint256 sharesToRemove = (shares * removePercent) / 100;
        
        // Remove liquidity
        liteswap.removeLiquidity(pairId, sharesToRemove);

        // Get final state
        (uint256 finalShares,) = liteswap.liquidityProviderPositions(pairId, address(this));
        (,, uint256 finalReserveA, uint256 finalReserveB,,) = liteswap.pairs(pairId);

        // Verify remaining shares
        assertEq(finalShares, shares - sharesToRemove);
        
        // Verify reserves reduced proportionally
        uint256 expectedRemainingAmount = (initialAmount * (100 - removePercent)) / 100;
        
        console2.log("Final Reserve A:           ", finalReserveA);
        console2.log("Final Reserve B:           ", finalReserveB); 
        console2.log("Expected Remaining Amount: ", expectedRemainingAmount);
        console2.log("Difference from expected:  ", finalReserveA > expectedRemainingAmount ? 
            finalReserveA - expectedRemainingAmount : 
            expectedRemainingAmount - finalReserveA
        );
        
        assertApproxEqAbs(finalReserveA, expectedRemainingAmount, 1); // Allow 1 wei difference
        assertApproxEqAbs(finalReserveB, expectedRemainingAmount, 1); // Allow 1 wei difference
    }

    function testFuzz_RemoveLiquidityMaintainsRatio(uint256 initialAmount, uint256 sharesToRemove) public {
        // Bound initial amount
        initialAmount = bound(initialAmount, 1000 ether, 1_000_000 ether);
        
        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Get initial shares
        (uint256 shares,) = liteswap.liquidityProviderPositions(pairId, address(this));
        
        // Bound shares to remove to be less than total shares
        sharesToRemove = bound(sharesToRemove, 1, shares - 1);
        
        // Remove liquidity
        liteswap.removeLiquidity(pairId, sharesToRemove);

        // Get final reserves
        (,, uint256 finalReserveA, uint256 finalReserveB,,) = liteswap.pairs(pairId);

        // Verify reserves maintain 1:1 ratio
        assertEq(finalReserveA, finalReserveB);
    }
}
contract LiteswapSwappingTests is Test, SetUp {
    function test_RevertWhenSwappingWithNonExistentPair() public {
        uint256 amount = 100 ether;

        // First approve the tokens
        tokenA.approve(address(liteswap), amount);
        
        // Use a non-existent pair ID
        uint256 nonExistentPairId = 999;
        vm.expectRevert(abi.encodeWithSignature("PairDoesNotExist()"));
        liteswap.swap(nonExistentPairId, address(tokenA), amount, 0);
    }

    function test_RevertWhenSwappingWithZeroInputAmount() public {
        uint256 amount = 1000 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        liteswap.swap(pairId, address(tokenA), 0, 0);
    }

    function test_RevertWhenOutputAmountIsBelowMinimumSpecified() public {
        uint256 amount = 1000 ether;
        uint256 swapAmount = 10 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        tokenA.approve(address(liteswap), swapAmount);
        
        // Set minimum output higher than possible
        uint256 impossibleMinOutput = 11 ether;
        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        liteswap.swap(pairId, address(tokenA), swapAmount, impossibleMinOutput);
    }

    function test_ExecuteSwapWithCorrectBalanceChanges() public {
        uint256 amount = 1000 ether;
        uint256 swapAmount = 10 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Get initial balances
        uint256 initialBalanceA = tokenA.balanceOf(address(this));
        uint256 initialBalanceB = tokenB.balanceOf(address(this));

        // Calculate expected output amount
        (,, uint256 reserveA, uint256 reserveB,,) = liteswap.pairs(pairId);
        uint256 expectedOutput = (swapAmount * 997 * reserveB) / ((reserveA * 1000) + (swapAmount * 997));

        // Approve and swap
        tokenA.approve(address(liteswap), swapAmount);
        
        vm.expectEmit(true, true, true, true);
        emit Liteswap.Swap(pairId, address(this), address(tokenA), address(tokenB), swapAmount, expectedOutput);

        liteswap.swap(pairId, address(tokenA), swapAmount, expectedOutput/2);

        // Verify balances changed
        uint256 finalBalanceA = tokenA.balanceOf(address(this));
        uint256 finalBalanceB = tokenB.balanceOf(address(this));
        
        // Add debug logs to help identify failing assertion
        console2.log("Initial balance A:", initialBalanceA);
        console2.log("Final balance A:", finalBalanceA);
        console2.log("Initial balance B:", initialBalanceB); 
        console2.log("Final balance B:", finalBalanceB);

        assertLt(finalBalanceA, initialBalanceA, "Final balance A should be less than initial");
        assertGt(finalBalanceB, initialBalanceB, "Final balance B should be greater than initial");

        // Verify constant product maintained
        (,, uint256 reserveA_, uint256 reserveB_,,) = liteswap.pairs(pairId);
        uint256 initialK = reserveA * reserveB;
        uint256 finalK = reserveA_ * reserveB_;
        
        console2.log("Initial K:", initialK);
        console2.log("Final K:", finalK);
        console2.log("Initial amount:", amount);
        console2.log("Final reserve A:", reserveA_);
        console2.log("Final reserve B:", reserveB_);
        
        assertGe(finalK, initialK, "Final K should be >= initial K");
        
        // Additional verification that reserves changed as expected
        assertGt(reserveA_, amount, "Reserve A should increase"); // Input token reserve should increase
        assertLt(reserveB_, amount, "Reserve B should decrease"); // Output token reserve should decrease
    }

    function testFuzz_SwapWithRandomAmounts(uint256 initialAmount, uint256 swapAmount) public {
        // Bound initial amount to reasonable range
        initialAmount = bound(initialAmount, 1000 ether, 1_000_000 ether);
        // Bound swap amount to be less than initial amount
        swapAmount = bound(swapAmount, 1 ether, initialAmount / 2);

        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Get initial state
        (,, uint256 reserveA, uint256 reserveB,,) = liteswap.pairs(pairId);
        uint256 initialK = reserveA * reserveB;

        // Execute swap
        tokenA.approve(address(liteswap), swapAmount);
        liteswap.swap(pairId, address(tokenA), swapAmount, 0);

        // Verify final state
        (,, uint256 finalReserveA, uint256 finalReserveB,,) = liteswap.pairs(pairId);
        uint256 finalK = finalReserveA * finalReserveB;

        // Verify k increased due to fees
        assertGt(finalK, initialK, "K should increase due to fees");
        
        // Verify reserves changed appropriately
        assertGt(finalReserveA, reserveA, "Reserve A should increase");
        assertLt(finalReserveB, reserveB, "Reserve B should decrease");
    }

    function testFuzz_SwapWithRandomMinimumOutput(uint256 initialAmount, uint256 swapAmount, uint256 minOutput) public {
        // Bound initial amount to a reasonable range (1000-1M ether)
        initialAmount = bound(initialAmount, 1000 ether, 1_000_000 ether);
        
        // Bound swap amount to be between 1 ether and 10% of initial amount
        swapAmount = bound(swapAmount, 1 ether, initialAmount / 10);

        // Initialize pair
        tokenA.approve(address(liteswap), initialAmount);
        tokenB.approve(address(liteswap), initialAmount);
        liteswap.initializePair(address(tokenA), address(tokenB), initialAmount, initialAmount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Calculate expected output
        (,, uint256 reserveA, uint256 reserveB,,) = liteswap.pairs(pairId);
        uint256 expectedOutput = (swapAmount * 997 * reserveB) / ((reserveA * 1000) + (swapAmount * 997));
        
        // Ensure minOutput is bounded between 0 and expectedOutput
        minOutput = bound(minOutput, 1, expectedOutput-1);

        // Get initial balance
        uint256 initialBalanceB = tokenB.balanceOf(address(this));

        // Execute swap
        tokenA.approve(address(liteswap), swapAmount);
        liteswap.swap(pairId, address(tokenA), swapAmount, minOutput);

        // Verify swap succeeded with minimum output requirement
        uint256 finalBalanceB = tokenB.balanceOf(address(this));
        uint256 outputAmount = finalBalanceB - initialBalanceB;
        assertGe(outputAmount, minOutput, "Output amount should meet minimum");
    }

    function test_HandleLargeSwapsWithAppropriateImpact() public {
        uint256 amount = 1000 ether;
        uint256 largeSwapAmount = 500 ether; // 50% of pool

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        tokenA.approve(address(liteswap), largeSwapAmount);
        
        liteswap.swap(pairId, address(tokenA), largeSwapAmount, 0);

        // Verify significant price impact
        (,, uint256 reserveA, uint256 reserveB,,) = liteswap.pairs(pairId);
        uint256 outputAmount = reserveB - ((amount * amount) / reserveA);
        
        // Output amount should be significantly less than proportional due to price impact
        uint256 expectedProportionalOutput = (largeSwapAmount * 997) / 1000;
        assertLt(outputAmount, expectedProportionalOutput);
    }

    function test_RevertWhenSwappingWithInsufficientTokenAllowance() public {
        uint256 amount = 1000 ether;
        uint256 swapAmount = 100 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Don't approve tokens before swap
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientAllowance.selector);
        liteswap.swap(pairId, address(tokenA), swapAmount, 0);
    }

    function test_RevertWhenSwappingWithInsufficientTokenBalance() public {
        uint256 amount = 1000 ether;
        uint256 hugeAmount = 2000000 ether; // More than minted

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        vm.startPrank(poorUser);
        tokenA.approve(address(liteswap), hugeAmount);
        
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, poorUser, 0, hugeAmount));
        liteswap.swap(pairId, address(tokenA), hugeAmount, 0);
        vm.stopPrank();
    }

    function test_MaintainConstantProductInvariantAfterSwap() public {
        uint256 amount = 1000 ether;
        uint256 swapAmount = 100 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Get initial k
        (,, uint256 initialReserveA, uint256 initialReserveB,,) = liteswap.pairs(pairId);
        uint256 initialK = initialReserveA * initialReserveB;

        // Execute swap
        tokenA.approve(address(liteswap), swapAmount);
        liteswap.swap(pairId, address(tokenA), swapAmount, 0);

        // Get final k
        (,, uint256 finalReserveA, uint256 finalReserveB,,) = liteswap.pairs(pairId);
        uint256 finalK = finalReserveA * finalReserveB;
        
        uint256 receivedAmount = (swapAmount * 997 * initialReserveB) / ((initialReserveA * 1000) + (swapAmount * 997));
        uint256 expectedK = (initialReserveA + swapAmount) * (initialReserveB - receivedAmount);
        uint256 expectedIncrease = expectedK - initialK;

        assertGt(finalK, initialK);
        assertApproxEqRel(finalK - initialK, expectedIncrease, 0.05e18); // 5% tolerance
    }

    function test_RevertWhenOutputAmountIsZero() public {
        uint256 amount = 1000 ether;
        uint256 tinySwapAmount = 1;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        tokenA.approve(address(liteswap), tinySwapAmount);
        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        liteswap.swap(pairId, address(tokenA), tinySwapAmount, 0);
    }

    function test_AllowSwapWithExactMinAmountOut() public {
        uint256 amount = 1000 ether;
        uint256 swapAmount = 10 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), amount);
        tokenB.approve(address(liteswap), amount);
        liteswap.initializePair(address(tokenA), address(tokenB), amount, amount);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Calculate expected output amount
        (,, uint256 reserveA, uint256 reserveB,,) = liteswap.pairs(pairId);
        uint256 expectedOutput = (swapAmount * 997 * reserveB) / ((reserveA * 1000) + (swapAmount * 997));

        tokenA.approve(address(liteswap), swapAmount);
        
        // Should succeed with exact expected amount
        liteswap.swap(pairId, address(tokenA), swapAmount, expectedOutput);

        // Should fail with expected amount + 1
        tokenA.approve(address(liteswap), swapAmount);
        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        liteswap.swap(pairId, address(tokenA), swapAmount, expectedOutput + 1);
    }
}

contract LiteswapFeeAccumulationTests is Test, SetUp {
    function test_AccumulateAndDistributeFeesAcrossMultipleOperations() public {
        uint256 initialLiquidity = 10_000 ether;
        uint256 swapAmount = 1_000 ether;
        uint256 additionalLiquidity = 5_000 ether;

        // Step 1: Owner provides initial liquidity
        tokenA.approve(address(liteswap), initialLiquidity);
        tokenB.approve(address(liteswap), initialLiquidity);
        liteswap.initializePair(address(tokenA), address(tokenB), initialLiquidity, initialLiquidity);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Verify initial 1:1 ratio
        (,, uint256 reserveA, uint256 reserveB,,) = liteswap.pairs(pairId);
        assertEq(reserveA, reserveB);

        // Step 2: User1 performs swaps
        tokenA.transfer(user1, swapAmount * 2);
        vm.startPrank(user1);
        tokenA.approve(address(liteswap), swapAmount * 2);
        
        // Multiple swaps to accumulate fees
        for(uint256 i = 0; i < 2; i++) {
            liteswap.swap(pairId, address(tokenA), swapAmount, 0);
        }
        vm.stopPrank();

        (,, uint256 reserveAAfterSwaps, uint256 reserveBAfterSwaps,,) = liteswap.pairs(pairId);
        // Verify ratio changed - more A than B after swapping A for B
        assertGt(reserveAAfterSwaps, reserveBAfterSwaps);
        // Verify k increased due to fees
        assertGt(reserveAAfterSwaps * reserveBAfterSwaps, initialLiquidity * initialLiquidity);

        // Step 3: User2 adds liquidity after fees accumulated
        tokenA.transfer(user2, additionalLiquidity);
        tokenB.transfer(user2, additionalLiquidity);
        
        vm.startPrank(user2);
        tokenA.approve(address(liteswap), additionalLiquidity);
        tokenB.approve(address(liteswap), additionalLiquidity);

        uint256 user2InitialBalance = tokenA.balanceOf(user2);
        liteswap.addLiquidity(pairId, additionalLiquidity);
        uint256 user2FinalBalance = tokenA.balanceOf(user2);
        uint256 user2AmountAAdded = user2InitialBalance - user2FinalBalance;
        
        (,, reserveA, reserveB,,) = liteswap.pairs(pairId);
        uint256 user2AmountBAdded = (user2AmountAAdded * reserveB) / reserveA;
        vm.stopPrank();

        // Step 4: User3 performs more swaps
        (,, uint256 prevReserveA, uint256 prevReserveB,,) = liteswap.pairs(pairId);
        uint256 prevK = prevReserveA * prevReserveB;

        tokenB.transfer(user3, swapAmount * 2);
        vm.startPrank(user3);
        tokenB.approve(address(liteswap), swapAmount * 2);
        
        for(uint256 i = 0; i < 2; i++) {
            liteswap.swap(pairId, address(tokenB), swapAmount, 0);
        }
        vm.stopPrank();

        (,, reserveA, reserveB,,) = liteswap.pairs(pairId);
        // Verify ratio changed - more B than before after swapping B for A
        assertGt(reserveB, prevReserveB);
        // Verify k increased further due to fees
        assertGt(reserveA * reserveB, prevK);

        // Step 5: Owner removes initial liquidity
        (uint256 ownerShares,) = liteswap.liquidityProviderPositions(pairId, address(this));
        uint256 ownerInitialBalanceA = tokenA.balanceOf(address(this));
        uint256 ownerInitialBalanceB = tokenB.balanceOf(address(this));
        
        liteswap.removeLiquidity(pairId, ownerShares);
        
        uint256 ownerFinalBalanceA = tokenA.balanceOf(address(this));
        uint256 ownerFinalBalanceB = tokenB.balanceOf(address(this));
        
        uint256 ownerReturnA = ownerFinalBalanceA - ownerInitialBalanceA;
        uint256 ownerReturnB = ownerFinalBalanceB - ownerInitialBalanceB;

        uint256 totalInitialValue = initialLiquidity * 2; // Value of both tokens initially deposited
        uint256 totalReturnValue = ownerReturnA + ownerReturnB; // Total value returned
        
        // Total return should be greater due to accumulated fees
        assertGe(totalReturnValue, totalInitialValue);

        // Add more specific checks for individual token returns
        assertNotEq(ownerReturnA, 0);
        assertNotEq(ownerReturnB, 0);

        // Verify owner got proportional share of accumulated fees for one token
        assertGt(ownerReturnA * 100 / initialLiquidity, 100); // More than initial due to fees
        assertLt(ownerReturnB * 100 / initialLiquidity, 100); // Less than initial due to IL

        // Step 6: User2 removes liquidity
        vm.startPrank(user2);
        (uint256 user2Shares,) = liteswap.liquidityProviderPositions(pairId, user2);
        user2InitialBalance = tokenA.balanceOf(user2);
        uint256 user2InitialBalanceB = tokenB.balanceOf(user2);
        
        liteswap.removeLiquidity(pairId, user2Shares);
        
        user2FinalBalance = tokenA.balanceOf(user2);
        uint256 user2FinalBalanceB = tokenB.balanceOf(user2);
        vm.stopPrank();
        
        uint256 user2ReturnA = user2FinalBalance - user2InitialBalance;
        uint256 user2ReturnB = user2FinalBalanceB - user2InitialBalanceB;

        // Verify user2 got proportional share of accumulated fees for one token
        assertLt(user2ReturnA * 100 / additionalLiquidity, 100); // Less than initial due to IL
        assertLt(user2ReturnB * 100 / additionalLiquidity, 100); // Less than initial due to IL
        uint256 totalShares;
        // Verify final state
        (,, reserveA, reserveB, totalShares,) = liteswap.pairs(pairId);
        
        // Verify all fees were distributed proportionally
        assertEq(totalShares, 0); // All liquidity removed
        assertEq(reserveA, 0);
        assertEq(reserveB, 0);
    }

    function testFuzz_FeeAccumulationWithRandomSwaps(
        uint256 initialLiquidity,
        uint256 swapAmount,
        uint8 numSwaps
    ) public {
        // Bound inputs to reasonable ranges
        initialLiquidity = bound(initialLiquidity, 1000 ether, 1_000_000 ether);
        swapAmount = bound(swapAmount, 1 ether, initialLiquidity / 10); // Max 10% of liquidity per swap
        numSwaps = uint8(bound(numSwaps, 1, 10)); // 1-10 swaps

        // Initialize pair
        tokenA.approve(address(liteswap), initialLiquidity);
        tokenB.approve(address(liteswap), initialLiquidity);
        liteswap.initializePair(address(tokenA), address(tokenB), initialLiquidity, initialLiquidity);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // Record initial k
        (,, uint256 initialReserveA, uint256 initialReserveB,,) = liteswap.pairs(pairId);
        uint256 initialK = initialReserveA * initialReserveB;

        // Perform random swaps
        tokenA.transfer(user1, swapAmount * numSwaps);
        vm.startPrank(user1);
        tokenA.approve(address(liteswap), swapAmount * numSwaps);
        
        for(uint256 i = 0; i < numSwaps; i++) {
            liteswap.swap(pairId, address(tokenA), swapAmount, 0);
        }
        vm.stopPrank();

        // Verify k increased from fees
        (,, uint256 finalReserveA, uint256 finalReserveB,,) = liteswap.pairs(pairId);
        uint256 finalK = finalReserveA * finalReserveB;
        
        assertGt(finalK, initialK);
        
        // Calculate and verify fee accumulation
        uint256 kGrowthPercent = (finalK * 100) / initialK;
        assertGe(kGrowthPercent, 100); // At least same as initial
        assertLe(kGrowthPercent, 100 + numSwaps); // Max 1% growth per swap
    }

    function testFuzz_FeeDistributionProportions(
        uint256 initialLiquidity,
        uint256 additionalLiquidity,
        uint256 swapAmount
    ) public {
        // Bound inputs
        initialLiquidity = bound(initialLiquidity, 1000 ether, 1_000_000 ether);
        additionalLiquidity = bound(additionalLiquidity, 100 ether, initialLiquidity);
        swapAmount = bound(swapAmount, 1 ether, initialLiquidity / 10);

        // Initialize pair with owner liquidity
        tokenA.approve(address(liteswap), initialLiquidity);
        tokenB.approve(address(liteswap), initialLiquidity);
        liteswap.initializePair(address(tokenA), address(tokenB), initialLiquidity, initialLiquidity);

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint256 pairId = liteswap.tokenPairId(token0, token1);

        // User1 adds additional liquidity
        tokenA.transfer(user1, additionalLiquidity);
        tokenB.transfer(user1, additionalLiquidity);
        
        vm.startPrank(user1);
        tokenA.approve(address(liteswap), additionalLiquidity);
        tokenB.approve(address(liteswap), additionalLiquidity);
        liteswap.addLiquidity(pairId, additionalLiquidity);
        vm.stopPrank();

        // User2 performs swap to generate fees
        tokenA.transfer(user2, swapAmount);
        vm.startPrank(user2);
        tokenA.approve(address(liteswap), swapAmount);
        liteswap.swap(pairId, address(tokenA), swapAmount, 0);
        vm.stopPrank();

        // Record balances before removing liquidity
        uint256 ownerInitialBalanceA = tokenA.balanceOf(address(this));
        uint256 user1InitialBalanceA = tokenA.balanceOf(user1);

        // Remove all liquidity
        (uint256 ownerShares,) = liteswap.liquidityProviderPositions(pairId, address(this));
        liteswap.removeLiquidity(pairId, ownerShares);

        vm.startPrank(user1);
        (uint256 user1Shares,) = liteswap.liquidityProviderPositions(pairId, user1);
        liteswap.removeLiquidity(pairId, user1Shares);
        vm.stopPrank();

        // Calculate returns
        uint256 ownerReturnA = tokenA.balanceOf(address(this)) - ownerInitialBalanceA;
        uint256 user1ReturnA = tokenA.balanceOf(user1) - user1InitialBalanceA;

        // Verify fee distribution proportions
        uint256 ownerProportion = (ownerReturnA * 1000) / initialLiquidity;
        uint256 user1Proportion = (user1ReturnA * 1000) / additionalLiquidity;
        
        // Proportions should be within 1% of each other
        uint256 proportionDiff = ownerProportion > user1Proportion ? 
            ownerProportion - user1Proportion : 
            user1Proportion - ownerProportion;
            
        assertLe(proportionDiff, 10); // Max 1% difference (10/1000)
    }
}
contract LiteswapLimitOrderTests is Test, SetUp {
    function testLimitOrderPlacementRestrictions() public {
        // Initial setup amounts
        uint256 initialLiquidity = 1000 ether;
        uint256 limitOrderAmount = 100 ether;

        // Try to place limit order with invalid pair ID
        tokenA.approve(address(liteswap), limitOrderAmount);
        vm.expectRevert(abi.encodeWithSelector(Liteswap.PairDoesNotExist.selector));
        liteswap.placeLimitOrder(
            999, // Invalid pair ID
            address(tokenA),
            limitOrderAmount,
            1 ether
        );

        // Initialize pair
        tokenA.approve(address(liteswap), initialLiquidity);
        tokenB.approve(address(liteswap), initialLiquidity);
        liteswap.initializePair(
            address(tokenA),
            address(tokenB),
            initialLiquidity,
            initialLiquidity
        );

        uint256 pairId = liteswap.tokenPairId(
            address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB),
            address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA)
        );

        // Try with invalid offer token (not in pair)
        vm.expectRevert(abi.encodeWithSelector(Liteswap.InvalidTokenAddress.selector));
        liteswap.placeLimitOrder(
            pairId,
            user1, // Invalid token address
            limitOrderAmount,
            1 ether
        );

        // Try with zero amounts
        vm.expectRevert(abi.encodeWithSelector(Liteswap.InvalidAmount.selector));
        liteswap.placeLimitOrder(
            pairId,
            address(tokenA),
            0,
            1 ether
        );

        vm.expectRevert(abi.encodeWithSelector(Liteswap.InvalidAmount.selector));
        liteswap.placeLimitOrder(
            pairId,
            address(tokenA),
            limitOrderAmount,
            0
        );

        // Try with bad ratio (worse than current pool reserves)
        limitOrderAmount = 100 ether;
        // Calculate what you'd get from a direct swap
        uint256 poolOutput = (limitOrderAmount * 997 * initialLiquidity) / 
            ((initialLiquidity * 1000) + (limitOrderAmount * 997));
        // Ask for more than what the pool would give (worse price)
        uint256 badDesiredOutput = poolOutput - 1 ether;

        tokenA.approve(address(liteswap), limitOrderAmount);

        vm.expectRevert(abi.encodeWithSelector(Liteswap.BadRatio.selector));
        liteswap.placeLimitOrder(
            pairId,
            address(tokenA),
            limitOrderAmount,
            badDesiredOutput
        );

        // Try with bad ratio in the other direction (tokenB as offer token)
        uint256 limitOrderAmountB = 101 ether;
        // Calculate what you'd get from a direct swap of tokenB for tokenA
        uint256 poolOutputB = (limitOrderAmountB * 997 * initialLiquidity) / 
            ((initialLiquidity * 1000) + (limitOrderAmountB * 997));
        // Ask for more than what the pool would give (worse price)
        uint256 badDesiredOutputB = poolOutputB - 2 ether;

        tokenB.approve(address(liteswap), limitOrderAmountB);

        vm.expectRevert(abi.encodeWithSelector(Liteswap.BadRatio.selector));
        liteswap.placeLimitOrder(
            pairId,
            address(tokenB),
            limitOrderAmountB,
            badDesiredOutputB
        );
    }

    function testPlaceAndCancelLimitOrder() public {
        uint256 initialLiquidity = 10000 ether;
        uint256 limitOrderAmount = 100 ether;
        uint256 desiredOutput = 190 ether; // Better ratio than pool

        // Initialize pair
        tokenA.approve(address(liteswap), initialLiquidity);
        tokenB.approve(address(liteswap), initialLiquidity);
        liteswap.initializePair(
            address(tokenA),
            address(tokenB),
            initialLiquidity,
            initialLiquidity
        );

        uint256 pairId = liteswap.tokenPairId(
            address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB),
            address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA)
        );

        // Transfer tokens to user1 and approve liteswap
        tokenA.transfer(user1, limitOrderAmount);
        vm.startPrank(user1);
        tokenA.approve(address(liteswap), limitOrderAmount);

        // Check initial balance
        uint256 initialBalance = tokenA.balanceOf(user1);

        // Place limit order
        uint256 orderId;
        vm.expectEmit(true, true, true, true);
        emit LimitOrderPlaced(pairId, 0, user1, address(tokenA), address(tokenB), limitOrderAmount, desiredOutput);
        liteswap.placeLimitOrder(
            pairId,
            address(tokenA),
            limitOrderAmount,
            desiredOutput
        );
        orderId = 0;

        // Check balance after placing order
        uint256 balanceAfterOrder = tokenA.balanceOf(user1);
        assertEq(balanceAfterOrder, initialBalance - limitOrderAmount);

        // Cancel the order
        liteswap.cancelLimitOrder(pairId, orderId);

        // Check final balance after cancellation
        uint256 finalBalance = tokenA.balanceOf(user1);
        assertEq(finalBalance, initialBalance);

        // Try to fill the cancelled order
        tokenB.approve(address(liteswap), desiredOutput);
        vm.expectRevert(abi.encodeWithSelector(Liteswap.OrderNotActive.selector));
        liteswap.fillLimitOrder(pairId, orderId, desiredOutput);
        vm.stopPrank();
    }

    function testLimitOrderIdIncrements() public {
        uint256 initialLiquidity = 10000 ether;
        uint256 limitOrderAmount = 100 ether;
        uint256 desiredOutput = 190 ether;

        // Initialize pair
        tokenA.approve(address(liteswap), initialLiquidity);
        tokenB.approve(address(liteswap), initialLiquidity);
        liteswap.initializePair(
            address(tokenA),
            address(tokenB),
            initialLiquidity,
            initialLiquidity
        );

        uint256 pairId = liteswap.tokenPairId(
            address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB),
            address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA)
        );

        // Transfer tokens to user1 and approve liteswap
        tokenA.transfer(user1, limitOrderAmount * 3);
        vm.startPrank(user1);
        tokenA.approve(address(liteswap), limitOrderAmount * 3);

        // Place first order
        liteswap.placeLimitOrder(
            pairId,
            address(tokenA),
            limitOrderAmount,
            desiredOutput
        );
        uint256 orderId1 = liteswap._orderIdCounter(pairId) - 1;
        assertEq(orderId1, 0); // First order ID should be 0

        // Place second order
        liteswap.placeLimitOrder(
            pairId,
            address(tokenA),
            limitOrderAmount,
            desiredOutput
        );
        uint256 orderId2 = liteswap._orderIdCounter(pairId) - 1;
        assertEq(orderId2, 1); // Second order ID should be 1

        // Place third order
        liteswap.placeLimitOrder(
            pairId,
            address(tokenA),
            limitOrderAmount,
            desiredOutput
        );
        uint256 orderId3 = liteswap._orderIdCounter(pairId) - 1;
        assertEq(orderId3, 2); // Third order ID should be 2

        vm.stopPrank();

        // Transfer tokens to user2 for filling orders
        tokenB.transfer(user2, desiredOutput * 3);
        vm.startPrank(user2);
        tokenB.approve(address(liteswap), desiredOutput * 3);

        // Get balances before fill
        uint256 user1BalanceBeforeB = tokenB.balanceOf(user1);
        uint256 user2BalanceBeforeA = tokenA.balanceOf(user2);

        liteswap.fillLimitOrder(pairId, 0, desiredOutput);

        // Verify balances after fill
        uint256 user1BalanceAfterB = tokenB.balanceOf(user1);
        uint256 user2BalanceAfterA = tokenA.balanceOf(user2);

        // Verify user1 (maker) received the desired output amount of tokenB
        assertEq(user1BalanceAfterB - user1BalanceBeforeB, desiredOutput);
        vm.stopPrank();
    }

    function testFuzz_LimitOrderPlacementAndFill(uint256 initialLiquidity, uint256 limitOrderAmount, uint256 desiredOutput) public {
        // Bound inputs to reasonable ranges
        initialLiquidity = bound(initialLiquidity, 1000 ether, 1_000_000 ether);
        limitOrderAmount = bound(limitOrderAmount, 1 ether, initialLiquidity / 2);
        
        // Initialize pair
        tokenA.approve(address(liteswap), initialLiquidity);
        tokenB.approve(address(liteswap), initialLiquidity);
        liteswap.initializePair(address(tokenA), address(tokenB), initialLiquidity, initialLiquidity);

        uint256 pairId = liteswap.tokenPairId(
            address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB),
            address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA)
        );

        // Calculate minimum viable output based on pool ratio
        uint256 minViableOutput = (limitOrderAmount * 997 * initialLiquidity) / 
            ((initialLiquidity * 1000) + (limitOrderAmount * 997));
        
        // Ensure desired output is better than pool ratio but not unreasonable
        desiredOutput = bound(desiredOutput, minViableOutput + 1, minViableOutput * 2);

        // Place limit order
        tokenA.transfer(user1, limitOrderAmount);
        vm.startPrank(user1);
        tokenA.approve(address(liteswap), limitOrderAmount);
        
        uint256 user1InitialBalance = tokenA.balanceOf(user1);
        liteswap.placeLimitOrder(pairId, address(tokenA), limitOrderAmount, desiredOutput);
        
        // Verify order placement
        assertEq(tokenA.balanceOf(user1), user1InitialBalance - limitOrderAmount);
        vm.stopPrank();

        // Fill order
        tokenB.transfer(user2, desiredOutput);
        vm.startPrank(user2);
        tokenB.approve(address(liteswap), desiredOutput);
        
        uint256 user2InitialBalanceA = tokenA.balanceOf(user2);
        uint256 user1InitialBalanceB = tokenB.balanceOf(user1);
        
        liteswap.fillLimitOrder(pairId, 0, desiredOutput);
        
        // Verify fill results
        assertEq(tokenA.balanceOf(user2) - user2InitialBalanceA, limitOrderAmount);
        assertEq(tokenB.balanceOf(user1) - user1InitialBalanceB, desiredOutput);
        vm.stopPrank();
    }

    function testFuzz_LimitOrderCanBeFilledInChunks(
        uint256 initialLiquidity,
        uint256 limitOrderAmount,
        uint256 desiredOutput,
        uint256 firstFillPct
    ) public {
        // Bound inputs to reasonable ranges
        initialLiquidity = bound(initialLiquidity, 1000 ether, 1_000_000 ether);
        limitOrderAmount = bound(limitOrderAmount, 100 ether, initialLiquidity / 2);
        
        // Initialize pair
        tokenA.approve(address(liteswap), initialLiquidity);
        tokenB.approve(address(liteswap), initialLiquidity);
        liteswap.initializePair(address(tokenA), address(tokenB), initialLiquidity, initialLiquidity);

        uint256 pairId = liteswap.tokenPairId(
            address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB),
            address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA)
        );

        // Calculate minimum viable output based on pool ratio
        uint256 minViableOutput = (limitOrderAmount * 997 * initialLiquidity) / 
            ((initialLiquidity * 1000) + (limitOrderAmount * 997));
        
        // Ensure desired output is better than pool ratio but not unreasonable
        desiredOutput = bound(desiredOutput, minViableOutput + 1, minViableOutput * 2);

        // Bound first fill percentage between 1-99%
        firstFillPct = bound(firstFillPct, 1, 99);
        
        // Place limit order
        tokenA.transfer(user1, limitOrderAmount);
        vm.startPrank(user1);
        tokenA.approve(address(liteswap), limitOrderAmount);
        liteswap.placeLimitOrder(pairId, address(tokenA), limitOrderAmount, desiredOutput);
        vm.stopPrank();

        // Calculate fill amounts
        uint256 firstFillAmount = (desiredOutput * firstFillPct) / 100;
        uint256 secondFillAmount = desiredOutput - firstFillAmount;

        // First partial fill
        tokenB.transfer(user2, firstFillAmount);
        vm.startPrank(user2);
        tokenB.approve(address(liteswap), firstFillAmount);
        uint256 firstFillReceived = liteswap.fillLimitOrder(pairId, 0, firstFillAmount);
        vm.stopPrank();

        // Second partial fill
        tokenB.transfer(user3, secondFillAmount);
        vm.startPrank(user3);
        tokenB.approve(address(liteswap), secondFillAmount);
        uint256 secondFillReceived = liteswap.fillLimitOrder(pairId, 0, secondFillAmount);
        vm.stopPrank();

        // Verify total fills equal original order amounts
        assertEq(firstFillReceived + secondFillReceived, limitOrderAmount, "Total filled should equal limit order amount");
        
        // Verify order is no longer active
        (,,,,, bool active) = liteswap.limitOrders(pairId, 0);
        assertFalse(active, "Order should be inactive after complete fill");
    }

    event LimitOrderPlaced(
        uint256 indexed pairId,
        uint256 indexed orderId,
        address indexed maker,
        address offerToken,
        address desiredToken,
        uint256 offerAmount,
        uint256 desiredAmount
    );
}