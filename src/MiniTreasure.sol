// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MiniTreasure (MT)
 * @notice ERC-20 token with capped supply and burnable functionality.
 */
contract MiniTreasure is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens

    constructor(
        uint256 initialSupply,
        address initialOwner
    ) ERC20("MiniTreasure", "MT") Ownable(initialOwner) {
        require(initialSupply <= MAX_SUPPLY, "Initial supply exceeds max");
        _mint(initialOwner, initialSupply);
    }

    /// @notice Mint new tokens (owner only, capped at MAX_SUPPLY)
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
}