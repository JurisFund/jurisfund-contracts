// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, EscrowData} from "../lib/Structs.sol";

interface IJurisEscrow {
  event EtherReceived(uint256 amount);

  event EscrowInitialized(
    uint256 principal,
    address indexed plaintiff,
    address lawer,
    address token
  );

  event EscrowSettled(uint256 settlement, uint256 jurisFundFee, uint256 timestamp);

  error NotInitialized();
  error AlreadyInitialized();
  error UnAuthorized();
  error NotEnoughFunds(uint256 actual, uint256 expected);

  /// ------------------ Error Codes --------------------
  /// first 4 bytes of keccak256(bytes("error message"))
  /// ---------------------------------------------------
  /// ES1001 - Debt amount is too low (0xbd070be3)
  /// ES1515 - Minimum duration not reached (0xdb17e5b1)
  /// ES5001 - Escrow must be settled (0x124771cb)
  /// ES5011 - Escrow is already settled (0xc1efc194)
  /// ES4004 - Withdrawal failed (0xee910bd2)
  /// ---------------------------------------------------
  error Exception(uint256 errorCode);

  function ready() external view returns (bool);

  function getBalance() external view returns (uint256);

  function deposit(uint256 amount) external payable;

  function disburse() external;

  function disburseWithOffChainAPR(uint256 precalculatedDebt) external;

  function getEscrowData() external view returns (EscrowData memory);

  function withdraw(IERC20 token) external;
}
