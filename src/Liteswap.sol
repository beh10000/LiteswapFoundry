// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Liteswap is ReentrancyGuard {
    using SafeERC20 for IERC20;
    struct Pair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalShares;  // Total shares issued for this pair
        bool initialized;
    }
    struct LiquidityPosition {
        uint256 shares;       // User's share of the pool
        bool hasPosition;     // Whether the position exists
    }
    struct LimitOrder {
        address maker;
        address offerToken;
        address desiredToken;
        uint256 offerAmount;
        uint256 desiredAmount;
        bool active;
    }

    
    mapping(uint256 pairId => Pair) public pairs;
    mapping(address tokenA => mapping(address tokenB => uint256)) public tokenPairId;
    mapping(uint256 pairId=> mapping(address liquidityProvider => LiquidityPosition)) public liquidityProviderPositions;
    mapping(uint256 pairId => mapping(uint256 orderId => LimitOrder)) public limitOrders;
    mapping(uint256 pairId => uint256) private _orderIdCounter;
    uint256 public _pairIdCount; // Counter for generating unique pair IDs
    uint256 private constant MINIMUM_SHARES = 1000; // prevent division by zero on first liquidity deposit
    
    event PairInitialized(
        uint256 indexed pairId, 
        address indexed tokenA, 
        address indexed tokenB
    );
    event LiquidityAdded(
        uint256 indexed pairId,
        address indexed liquidityProvider,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );
    event LiquidityRemoved(
        uint256 indexed pairId,
        address indexed liquidityProvider,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );
    event ReservesUpdated(
        uint256 indexed pairId, 
        uint256 reserveA, 
        uint256 reserveB
    );
    event Swap(
        uint256 indexed pairId,
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event LimitOrderPlaced(
        uint256 indexed pairId,
        uint256 indexed orderId,
        address indexed maker,
        address offerToken,
        address desiredToken,
        uint256 offerAmount,
        uint256 desiredAmount
    );

    event LimitOrderFilled(
        uint256 indexed pairId,
        uint256 indexed orderId,
        address indexed filler,
        uint256 amountFilled
    );

    event LimitOrderCancelled(
        uint256 indexed pairId,
        uint256 indexed orderId
    );

    
    // Custom errors
    error PairAlreadyExists();
    error PairDoesNotExist();
    error InvalidTokenAddress();
    error InsufficientLiquidity();
    error InvalidAmount();
    error TransferFailed();
    error NoPosition();
    error InvalidProportions();
    error InsufficientShares();
    error OrderDoesNotExist();
    error OrderNotActive();
    error NotOrderMaker();
    error InvalidFillAmount();
    error BadRatio();

    constructor() {
        _pairIdCount = 1;
       
    }
    
    /**
     * @notice Creates a new trading pair between two tokens if it doesn't already exist.
     * The order of tokenA and tokenB doesn't matter - (tokenA,tokenB) and (tokenB,tokenA) 
     * are considered the same pair. Both token addresses must be valid and different from
     * each other. Emits a PairInitialized event upon successful creation.
     * @dev Initializes a new token pair and returns the pair ID
     * @param tokenA The address of the first token in the pair
     * @param tokenB The address of the second token in the pair
     * @param amountA The amount of tokenA to add
     * @param amountB The amount of tokenB to add
     * @return pairId The unique identifier for the newly created pair
     */
    function initializePair(address tokenA, address tokenB, uint256 amountA, uint256 amountB) 
        external 
        returns (uint256 pairId) {
            if (tokenA == address(0) || tokenB == address(0)) revert InvalidTokenAddress();
            if (tokenA == tokenB) revert InvalidTokenAddress();
            if (amountA == 0 || amountB == 0) revert InvalidAmount();
            
            // Sort tokens by address to ensure consistent ordering
            (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
            (uint256 amount0, uint256 amount1) = tokenA < tokenB ? (amountA, amountB) : (amountB, amountA);
                
            if (tokenPairId[token0][token1] != 0) revert PairAlreadyExists();
            
            pairId = _pairIdCount++;
            tokenPairId[token0][token1] = pairId;

            // Get initial balances
            uint256 balance0Before = IERC20(token0).balanceOf(address(this));
            uint256 balance1Before = IERC20(token1).balanceOf(address(this));

            // Transfer tokens
            if (!_transferTokens(token0, msg.sender, address(this), amount0)) revert TransferFailed();
            if (!_transferTokens(token1, msg.sender, address(this), amount1)) revert TransferFailed();

            // Calculate actual amounts received after potential transfer fees
            uint256 amount0Received = IERC20(token0).balanceOf(address(this)) - balance0Before;
            uint256 amount1Received = IERC20(token1).balanceOf(address(this)) - balance1Before;

            if (amount0Received == 0 || amount1Received == 0) revert InvalidAmount();

            // Calculate initial shares as geometric mean using actual received amounts
            uint256 initialShares = _sqrt(amount0Received * amount1Received);
            if (initialShares < MINIMUM_SHARES) revert InsufficientLiquidity();
            _mintShares(pairId, msg.sender, initialShares);

            pairs[pairId] = Pair({
                tokenA: token0,
                tokenB: token1,
                reserveA: amount0Received,
                reserveB: amount1Received,
                totalShares: initialShares,
                initialized: true
            });

            emit PairInitialized(pairId, token0, token1);
            emit LiquidityAdded(pairId, msg.sender, amount0Received, amount1Received, initialShares);
            emit ReservesUpdated(pairId, amount0Received, amount1Received);
            return pairId;
    }

    /**
     * @notice Adds liquidity to an existing trading pair by providing one token amount. The required amount
     * of the second token is calculated based on the current exchange rate to maintain price stability. 
     * Before calling, the liquidity provider must set approval on both Token A and Token B.
     * Liquidity provider should manage token allowances for Token B to set limit if price changes between tx broadcasting and block inclusion.
     * @dev Adds liquidity to a pair. Calculates and transfers the proportional amount of tokenB
     * @param pairId The pair ID to add liquidity to
     * @param amountA The amount of tokenA to add (must be token0 in the pair)
     * @return amountB The amount of tokenB that was transferred
     * @return shares The number of shares minted for the liquidity provider
     */
    function addLiquidity(uint256 pairId, uint256 amountA) 
        external nonReentrant 
        returns (uint256 amountB, uint256 shares) {
            Pair storage pair = pairs[pairId];
            if (!pair.initialized) revert PairDoesNotExist();
            if (amountA == 0) revert InvalidAmount();
            
            // Calculate required tokenB amount based on current ratio
            amountB = (amountA * pair.reserveB) / pair.reserveA;
            if (amountB == 0) revert InvalidAmount();

            // Get balances before transfer
            uint256 balanceABefore = IERC20(pair.tokenA).balanceOf(address(this));
            uint256 balanceBBefore = IERC20(pair.tokenB).balanceOf(address(this));

            if (!_transferTokens(pair.tokenA, msg.sender, address(this), amountA)) revert TransferFailed();
            if (!_transferTokens(pair.tokenB, msg.sender, address(this), amountB)) revert TransferFailed();

            // Calculate actual amounts received after potential transfer fees
            uint256 amountAReceived = IERC20(pair.tokenA).balanceOf(address(this)) - balanceABefore;
            uint256 amountBReceived = IERC20(pair.tokenB).balanceOf(address(this)) - balanceBBefore;

            if (amountAReceived == 0 || amountBReceived == 0) revert InvalidAmount();
            
            // Calculate shares based on proportion using actual received amounts
            shares = (amountAReceived * pair.totalShares) / pair.reserveA;
            if (shares == 0) revert InsufficientLiquidity();

            _mintShares(pairId, msg.sender, shares);
            _updateReserves(pairId, pair.reserveA + amountAReceived, pair.reserveB + amountBReceived);

            emit LiquidityAdded(pairId, msg.sender, amountAReceived, amountBReceived, shares);
            return (amountBReceived, shares);
    }

    /**
     * @notice Removes liquidity from a trading pair by burning shares and receiving back both tokens proportionally
     * @dev Removes liquidity from a pair
     * @param sharesToBurn The number of shares to burn
     * @return amountA Amount of tokenA returned
     * @return amountB Amount of tokenB returned
     */
    function removeLiquidity(uint256 pairId, uint256 sharesToBurn) 
        external nonReentrant 
        returns (uint256 amountA, uint256 amountB) {
            if (sharesToBurn == 0) revert InvalidAmount();
            
            LiquidityPosition storage position = liquidityProviderPositions[pairId][msg.sender];
            if (!position.hasPosition) revert NoPosition();
            if (position.shares < sharesToBurn) revert InsufficientShares();

            Pair storage pair = pairs[pairId];
            
            // Calculate tokens to return based on share proportion
            amountA = (pair.reserveA * sharesToBurn) / pair.totalShares;
            amountB = (pair.reserveB * sharesToBurn) / pair.totalShares;
            if (amountA == 0 || amountB == 0) revert InvalidAmount();

            
            _burnShares(pairId, msg.sender, sharesToBurn);
            _updateReserves(pairId, pair.reserveA - amountA, pair.reserveB - amountB);

            IERC20(pair.tokenA).safeTransfer(msg.sender, amountA);
            IERC20(pair.tokenB).safeTransfer(msg.sender, amountB);

            emit LiquidityRemoved(pairId, msg.sender, amountA, amountB, sharesToBurn);
            return (amountA, amountB);
    }
    /**
     * @notice Swaps an exact amount of input tokens for output tokens
     * @dev Performs a token swap with a minimum output amount requirement and applies 0.3% fee
     * @param pairId The pair ID to swap tokens for
     * @param tokenIn The address of the input token
     * @param amountIn The amount of input tokens to swap
     * @param minAmountOut The minimum amount of output tokens that must be received
     * @return amountOut The actual amount of output tokens received
     */
    function swap(uint256 pairId, address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external nonReentrant
        returns (uint256 amountOut){
            if (amountIn == 0) revert InvalidAmount();
            Pair storage pair = pairs[pairId];
            if (!pair.initialized) revert PairDoesNotExist();
            if (tokenIn != pair.tokenA && tokenIn != pair.tokenB) revert InvalidTokenAddress();
            
            // Determine which token is being swapped in/out
            bool isTokenA = tokenIn == pair.tokenA;
            uint256 reserveIn = isTokenA ? pair.reserveA : pair.reserveB;
            uint256 reserveOut = isTokenA ? pair.reserveB : pair.reserveA;
            
            // Get balance before transfer
            uint256 balanceBefore = IERC20(tokenIn).balanceOf(address(this));
            
            // Transfer input tokens from user to contract
            if (!_transferTokens(tokenIn, msg.sender, address(this), amountIn)) revert TransferFailed();
            
            // Calculate actual amount received after potential transfer fees
            uint256 actualAmountIn = IERC20(tokenIn).balanceOf(address(this)) - balanceBefore;
            if (actualAmountIn == 0) revert InvalidAmount();
            
            // Calculate output amount using constant product formula (x * y = k)
            // Apply 0.3% fee by using 997 instead of 1000
            // dy = (y * dx * 997) / (x * 1000 + dx * 997)
            amountOut = (reserveOut * ((actualAmountIn * 997) / 1000)) / (reserveIn + ((actualAmountIn * 997) / 1000));
            
            if (amountOut == 0) revert InvalidAmount();
            if (amountOut < minAmountOut) revert InvalidAmount();
            if (amountOut >= reserveOut) revert InsufficientLiquidity();
            
            // Transfer output tokens to user
            address tokenOut = isTokenA ? pair.tokenB : pair.tokenA;
            IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
            
            // Update reserves using actual amount received
            uint256 newReserveA = isTokenA ? pair.reserveA + actualAmountIn : pair.reserveA - amountOut;
            uint256 newReserveB = isTokenA ? pair.reserveB - amountOut : pair.reserveB + actualAmountIn;
                
            _updateReserves(pairId, newReserveA, newReserveB);
            
            emit Swap(pairId, msg.sender, tokenIn, tokenOut, actualAmountIn, amountOut);
            
            return amountOut;
    }
    
    

    /**
     * @notice Places a limit order to swap tokens at a specific rate
     * @dev This function allows users to place limit orders for token swaps at a specified rate.
     * The order will only be valid if the desired rate is worse than what could be achieved with
     * a direct swap through the AMM (to prevent arbitrage). The function:
     * 1. Validates the pair exists and tokens are valid
     * 2. Transfers offered tokens from user to contract, handling any transfer fees
     * 3. Checks that the limit price is valid compared to AMM price
     * 4. Creates and stores the limit order with a unique ID
     * 5. Emits LimitOrderPlaced event
     * The order can later be filled by other users calling fillLimitOrder() or cancelled by
     * the maker calling cancelLimitOrder()
     * 
     * @param pairId The pair ID to place the order for
     * @param offerToken The token address being offered
     * @param offerAmount The amount of tokens being offered
     * @param desiredAmount The amount of tokens desired in return
     * @return orderId The ID of the placed limit order
     */
    function placeLimitOrder(uint256 pairId, address offerToken, uint256 offerAmount, uint256 desiredAmount) 
        external nonReentrant 
        returns (uint256 orderId) {
            Pair storage pair = pairs[pairId];
            if (!pair.initialized) revert PairDoesNotExist();
            if (offerToken != pair.tokenA && offerToken != pair.tokenB) revert InvalidTokenAddress();
            if (offerAmount == 0 || desiredAmount == 0) revert InvalidAmount();

            // Get the desired token (the other token in the pair)
            address desiredToken = offerToken == pair.tokenA ? pair.tokenB : pair.tokenA;

            // Get initial balance before transfer
            uint256 initialBalance = IERC20(offerToken).balanceOf(address(this));

            // Transfer offered tokens to contract
            if (!_transferTokens(offerToken, msg.sender, address(this), offerAmount)) revert TransferFailed();

            // Calculate actual received amount after transfer
            uint256 actualOfferAmount = IERC20(offerToken).balanceOf(address(this)) - initialBalance;
            if (actualOfferAmount == 0) revert InvalidAmount();
            // Check if limit order would get more tokens than a normal swap
            bool isOfferTokenA = offerToken == pair.tokenA;
            uint256 reserveIn = isOfferTokenA ? pair.reserveA : pair.reserveB;
            uint256 reserveOut = isOfferTokenA ? pair.reserveB : pair.reserveA;

            // Calculate what a normal swap would give using the AMM formula
            uint256 swapOutput = (reserveOut * ((actualOfferAmount * 997) / 1000)) / 
                                (reserveIn + ((actualOfferAmount * 997) / 1000));

            // If limit order asks for more than a swap would give, it's a bad ratio
            if ((desiredAmount * 1e18) / actualOfferAmount < (swapOutput * 1e18) / actualOfferAmount) {
                revert BadRatio();
            }

            // Create order
            orderId = _orderIdCounter[pairId]++;
            LimitOrder storage order = limitOrders[pairId][orderId];
            order.maker = msg.sender;
            order.offerToken = offerToken;
            order.desiredToken = desiredToken;
            order.offerAmount = actualOfferAmount;
            order.desiredAmount = desiredAmount;
            order.active = true;

            emit LimitOrderPlaced(
                pairId,
                orderId,
                msg.sender,
                offerToken,
                desiredToken,
                actualOfferAmount,
                desiredAmount
            );

            return orderId;
    }

    /**
     * @notice Fills an existing limit order by providing the desired token amount
     * @dev This function handles the filling of limit orders with the following steps:
     * 1. Transfers the desired token amount from the filler to the contract
     * 2. Calculates the proportional offer amount based on the actual received amount
     * 3. Transfers the desired tokens to the order maker
     * 4. Transfers the offered tokens to the filler
     * 5. Updates or deactivates the order based on remaining amounts
     * 
     * Handles fee-on-transfer tokens by using actual received amounts.
     * Reverts if:
     * - Order is not active
     * - Transfer fails
     * - Fill amount is invalid (0 or greater than remaining desired amount)
     * - Calculated offer amount would be 0
     * 
     * @param pairId The pair ID of the order
     * @param orderId The ID of the order to fill
     * @param amountDesiredToFill The amount of desired tokens to fill the order with
     * @return filled The amount of offer tokens that was filled and sent to filler
     */
    function fillLimitOrder(uint256 pairId, uint256 orderId, uint256 amountDesiredToFill) 
        external nonReentrant 
        returns (uint256 filled) {
            LimitOrder storage order = limitOrders[pairId][orderId];
            if (!order.active) revert OrderNotActive();
            // First get initial balance of desired token
            uint256 initialBalance = IERC20(order.desiredToken).balanceOf(address(this));
            
            // Transfer desired tokens from filler to contract
            if (!_transferTokens(order.desiredToken, msg.sender, address(this), amountDesiredToFill)) revert TransferFailed();
            
            // Calculate actual received amount (handles fee-on-transfer tokens)
            uint256 actualReceived = IERC20(order.desiredToken).balanceOf(address(this)) - initialBalance;
            if (actualReceived == 0) revert InvalidFillAmount();
            if (actualReceived == 0 || actualReceived > order.desiredAmount) revert InvalidFillAmount();

            // Calculate proportional offer amount based on actual received amount
            uint256 offerAmount = (actualReceived * order.offerAmount) / order.desiredAmount;
            if (offerAmount == 0) revert InvalidFillAmount();
            
            // Transfer actual received amount to maker
            IERC20(order.desiredToken).safeTransfer(order.maker, actualReceived);
            
            // Transfer offered tokens to filler
            IERC20(order.offerToken).safeTransfer(msg.sender, offerAmount);

            order.offerAmount -= offerAmount;
            order.desiredAmount -= actualReceived;
            if (order.desiredAmount == 0) {
                order.active = false;
            }

            emit LimitOrderFilled(pairId, orderId, msg.sender, offerAmount);

            return offerAmount;
    }

    /**
     * @notice Cancels an existing limit order
     * @dev This function allows the maker of a limit order to cancel it and retrieve their remaining offered tokens.
     * The order must be active and can only be cancelled by the original maker. After cancellation:
     * - The remaining offer tokens are returned to the maker
     * - The order is marked as inactive
     * - Offer and desired amounts are set to 0
     * - A LimitOrderCancelled event is emitted
     * The function is protected against reentrancy attacks.
     * 
     * @param pairId The pair ID of the order
     * @param orderId The ID of the order to cancel
     */
    function cancelLimitOrder(uint256 pairId, uint256 orderId) 
        external nonReentrant {
            LimitOrder storage order = limitOrders[pairId][orderId];
            if (!order.active) revert OrderNotActive();
            if (order.maker != msg.sender) revert NotOrderMaker();
            IERC20(order.offerToken).safeTransfer(msg.sender, order.offerAmount);
            order.active = false;
            order.offerAmount = 0;
            order.desiredAmount = 0;

            emit LimitOrderCancelled(pairId, orderId);
    }
    /**
     * @dev Safe transfer function that works with any ERC20 token
     * Core utility function used by multiple main functions
     */
    function _transferTokens(address token, address from, address to, uint256 amount) 
        private 
        returns (bool) {
            IERC20(token).safeTransferFrom(from, to, amount);
            return true;  // safeTransferFrom will revert on failure
    }

    /**
     * @dev Updates the reserves for a pair
     * Core state update function used by multiple main functions
     */
    function _updateReserves(uint256 pairId, uint256 reserveA, uint256 reserveB) 
        private {
            pairs[pairId].reserveA = reserveA;
            pairs[pairId].reserveB = reserveB;
            emit ReservesUpdated(pairId, reserveA, reserveB);
    }

    /**
     * @dev Mints shares to an address
     * Share management function
     */
    function _mintShares(uint256 pairId, address to, uint256 amount) 
        private {
            LiquidityPosition storage position = liquidityProviderPositions[pairId][to];
            position.shares += amount;
            position.hasPosition = true;
            pairs[pairId].totalShares += amount;
    }

    /**
     * @dev Burns shares from an address
     * Share management function
     */
    function _burnShares(uint256 pairId, address from, uint256 amount) 
        private {
            LiquidityPosition storage position = liquidityProviderPositions[pairId][from];
            position.shares -= amount;
            if (position.shares == 0) {
                position.hasPosition = false;
            }
            pairs[pairId].totalShares -= amount;
    }

    /**
     * @dev Square root function
     * Math utility function
     */
    function _sqrt(uint256 y) 
        private pure 
        returns (uint256 z) {
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

    // View Functions

    /**
     * @notice Gets the unique pair ID for a token pair
     * @dev Orders the token addresses and retrieves the pair ID from mapping
     * @param tokenA The address of the first token
     * @param tokenB The address of the second token
     * @return The unique identifier for the token pair, or 0 if pair doesn't exist
     */
    function getPairId(address tokenA, address tokenB) 
        public view 
        returns (uint256) {
            (address token0, address token1) = tokenA < tokenB 
                ? (tokenA, tokenB) 
                : (tokenB, tokenA);
            return tokenPairId[token0][token1];
    }

    /**
     * @notice Returns the current reserves and total shares for a liquidity pair
     * @dev Retrieves the stored reserves and total shares from the Pair struct
     * @param pairId The unique identifier of the liquidity pair
     * @return reserveA The current reserve of tokenA in the pair
     * @return reserveB The current reserve of tokenB in the pair
     * @return totalShares The total number of shares issued for this pair
     */
    function getPairInfo(uint256 pairId) 
        external view 
        returns (uint256 reserveA, uint256 reserveB, uint256 totalShares) {
            Pair storage pair = pairs[pairId];
            return (pair.reserveA, pair.reserveB, pair.totalShares);
    }

    /**
     * @notice Calculates a user's share of a liquidity pool in basis points
     * @dev Computes the percentage of the pool owned by the user, scaled by 10000
     * @param pairId The unique identifier of the liquidity pair
     * @param user The address of the liquidity provider
     * @return The user's share in basis points (1 = 0.01%, 10000 = 100%)
     */
    function getUserShareBps(uint256 pairId, address user) 
        public view 
        returns (uint256) {
            Pair storage pair = pairs[pairId];
            LiquidityPosition storage position = liquidityProviderPositions[pairId][user];
            if (pair.totalShares == 0) return 0;
            return (position.shares * 10000) / pair.totalShares;
    }
}