// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, EscrowData} from "../lib/Structs.sol";

interface IJusrisEscrowProxy {
  function escrowAddress() external view returns (address);

  function initialize(
    uint256 principal,
    uint256 apr,
    address plantiff,
    address lawer,
    address pool,
    address multisig,
    IERC20 token
  ) external;

  function getBalance() external view returns (uint256);

  function deposit(uint256 amount) external;

  function disburse() external;

  function depositAndDisburse(uint256 amount) external;

  function depositAndLock(uint256 amount) external;

  function unlockAndDisburse() external;

  function unlockAndDisburseWithOffChainAPR(uint256 precalculatedDebt) external;

  function updateEscrowData(address settlementToken, uint256 jurisFundFeePercentage) external;

  function getEscrowData() external view returns (EscrowData memory);
}
