// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibJurisEscrow {
  struct EscrowStorage {
    uint256 _upkeepInterval;
    uint256 _lastUpkeep;
    address[] _escrowProxies;
    mapping(address => bool) _escrowSettled;
  }

  // keccak256(abi.encode(uint256(keccak256("juris.storage.escrow")) - 1)) & ~bytes32(uint256(0xff));
  bytes32 private constant StorageLocation =
    0x8afd255bdb7f34c49f6072e0b5539cfc59131ad505e98fc66299c2b24a8b2600;

  function _getEscrowStorage() internal pure returns (EscrowStorage storage $) {
    assembly {
      $.slot := StorageLocation
    }
  }
}
