// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
} 

contract TestERC20Factory {
    TestERC20 public immutable GOLD;
    TestERC20 public immutable SILVER; 
    TestERC20 public immutable BRONZE;
    TestERC20 public immutable COPPER;
    TestERC20 public immutable IRON;

    uint256 private constant FAUCET_AMOUNT = 10_000_000 * 10**18; // 10M tokens with 18 decimals

    constructor() {
        GOLD = new TestERC20("Digital Gold", "GOLD");
        SILVER = new TestERC20("Digital Silver", "SILV"); 
        BRONZE = new TestERC20("Digital Bronze", "BRNZ");
        COPPER = new TestERC20("Digital Copper", "COPR");
        IRON = new TestERC20("Digital Iron", "IRON");
    }

    function faucet() external {
        GOLD.mint(msg.sender, FAUCET_AMOUNT);
        SILVER.mint(msg.sender, FAUCET_AMOUNT);
        BRONZE.mint(msg.sender, FAUCET_AMOUNT);
        COPPER.mint(msg.sender, FAUCET_AMOUNT);
        IRON.mint(msg.sender, FAUCET_AMOUNT);
    }
}


contract TestFeeOnTransferERC20 is ERC20 {
    uint256 private constant FEE_BPS = 1000; // 10% fee in basis points

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (from != address(0) && to != address(0)) { // Skip fee on mint/burn
            uint256 feeAmount = (amount * FEE_BPS) / 10000;
            super._update(from, to, amount - feeAmount);
            _burn(from, feeAmount);
        } else {
            super._update(from, to, amount);
        }
    }
}