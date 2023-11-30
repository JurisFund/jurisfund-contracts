// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct StakeData {
  uint256 unlockTime; // unlock time
  uint256 amount; // amount of USDC
  uint256 liquidity; // mintedToken amount when stake
  address owner; // address of owner
  bool finished; // this value is true after user unstake
}

enum EscrowState {
  Created,
  Pending,
  Finished
}

struct EscrowAccount {
  EscrowState status;
  address borrower;
  address lawyer;
  uint128 amount;
  uint128 interest;
  uint128 borrowedAt;
  uint128 payoffAt;
}
