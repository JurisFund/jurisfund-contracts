// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

struct StakeData {
  uint256 unlockTime; // unlock time
  uint256 amount; // amount of USDC
  uint256 liquidity; // mintedToken amount when stake
  address owner; // address of owner
  bool finished; // this value is true after user unstake
}

struct EscrowData {
  uint128 startTime; // time escrow was created
  uint112 jurisFundFeePercentage; // compounded interest for loan duration %
  uint8 initialized; // 0 or 1
  uint8 isSettled; // 0 or 1
  uint256 principal; // initial loan amount USD
  IERC20 settlementToken; // JUSDC loan token
  address plantiff; // address of plantiff for injury case
  address plantiffLawer; // address of plantiff lawyer
  address jurisFund; // address of Juris Diamond
  address jurisFundSafe; // address of juris safe multisig
}
