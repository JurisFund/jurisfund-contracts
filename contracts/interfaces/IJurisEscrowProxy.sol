// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IJurisEscrow} from "./IJurisEscrow.sol";

interface IJurisEscrowProxy is IJurisEscrow {
  /// @dev returns the address of the implementation contract
  function escrowAddress() external view returns (address);
}
