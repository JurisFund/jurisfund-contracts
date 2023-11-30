// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, EscrowData} from "../lib/Structs.sol";

interface IJurisEscrowProxy {
  /// @dev this does not return the contract address of the escrow proxy
  /// it returns the address of the implementation contract.
  function escrowAddress() external view returns (address);

  function ready() external view returns (bool);

  function getBalance() external view returns (uint256);

  function deposit(uint256 amount) external payable;

  function disburse() external;

  function disburseWithOffChainAPR(uint256 precalculatedDebt) external;

  function getEscrowData() external view returns (EscrowData memory);

  function withdraw(IERC20 token) external;
}
