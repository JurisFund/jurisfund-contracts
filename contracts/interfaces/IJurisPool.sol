// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IJurisPool {
  function updatePool(uint256 _principal, uint256 _netRepayment) external;
}
