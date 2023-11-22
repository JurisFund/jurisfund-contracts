// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JUSDC is ERC20 {
  constructor() ERC20("Juris USDC", "JUSDC") {}

  function decimals() public pure override returns (uint8) {
    return 6;
  }

  function mint(uint256 _amount) external {
    _mint(msg.sender, _amount);
  }
}
