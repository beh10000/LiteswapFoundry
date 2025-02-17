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
    
    uint256 public constant INITIAL_MINT = 1_000_000 ether;

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
