// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct StakeData {
  uint256 unlockTime; // unlock time
  uint256 amount; // amount of USDC
  uint256 tokenAmount; // mintedToken amount when stake
  address owner; // address of owner
  bool finished; // this value is true after user unstake
}
