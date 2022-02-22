// SPDX-License-Identifier: MIT

/**
 * Smart Token Cash Token
 * @author Liu
 */

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract SmartTokenCash is ERC20, ERC20Burnable {
  
  constructor() 
    ERC20("Smart Token Cash", "SMTC"){

    // mint 1 million 
    _mint(0xc2A79DdAF7e95C141C20aa1B10F3411540562FF7, 1000_000 * 1e18);
  }
}