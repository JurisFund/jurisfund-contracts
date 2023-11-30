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
  uint128 jurisFundFeePercentage; // compounded interest for loan duration %
  uint256 principal; // initial loan amount USD
  address plantiff; // address of plantiff for injury case
  address plantiffLawer; // address of plantiff lawyer
  address jurisFundPool; // address of Juris Diamond
  IERC20 settlementToken; // JUSDC loan token
  address jurisFundSafe; // address of juris safe multisig
  bool initialized; // escrow can only be initialized once
  bool isSettled; // escrow can only be settled once
  bool locked; // escrow can only be unlocked by plantiff and lawyer if locked
}
