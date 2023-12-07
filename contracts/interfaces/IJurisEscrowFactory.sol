// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {JurisEscrowProxy} from "../facets/EscrowProxy.sol";
import {IJurisEscrowProxy} from "./IJurisEscrowProxy.sol";

interface IJurisEscrowFactory {
  event EscrowCreated(JurisEscrowProxy indexed proxy, address implementation);

  function isSettled(IJurisEscrowProxy proxy) external view returns (bool);

  function preCalculateEscrowAddress(bytes32 salt) external view returns (address addr);

  function deployEscrow(
    bytes memory initializer,
    bytes32 salt
  ) external returns (JurisEscrowProxy proxy);
}
