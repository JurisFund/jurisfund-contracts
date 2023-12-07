// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IJurisTeller {
  event Dispensed(address indexed plaintiff, uint256 indexed amount);
  event TellerConfigUpdated(uint256 delay, uint256 maxSingleWithdrawal);

  error UnAuthorized();
  error MaxSingleWithdrawalExceeded();
  error WithdrawalDelayNotReached();

  function dispense(IERC20 token, address plaintiff, uint256 amount) external;

  function updateTellerConfig(uint256 delay, uint256 maxSingleWithdrawal) external;
}
