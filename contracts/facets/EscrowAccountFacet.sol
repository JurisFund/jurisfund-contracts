// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {LibJuris, EscrowAccount} from "../lib/LibJuris.sol";

contract EscrowAccountFacet is ReentrancyGuardUpgradeable {
  function createAccount(address _lawyer, uint128 _amount, bytes32 _signature) external {
    LibJuris.EscrowStorage storage es = LibJuris._getEscrowStorage();
  }

  function checkCreateSignature(
    address _borrower,
    address _lawyer,
    uint128 _amount,
    bytes32 _signature
  ) private pure returns (bool) {
    LibJuris.EscrowStorage storage es = LibJuris._getEscrowStorage();

    bytes32 message = keccak256(abi.encodePacked(_borrower, _lawyer, _amount));
  }
}
