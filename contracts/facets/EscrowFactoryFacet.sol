// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {JusrisEscrowProxy} from "./EscrowProxy.sol";

/// adapted from:
/// - openzeppelin Creat2 lib
/// - safe-protocol proxy Factory
contract EscrowManagerFacet {
  event EscrowCreated(JusrisEscrowProxy indexed proxy, address implementation);

  function escrowCreationCode() public pure returns (bytes memory) {
    return type(JusrisEscrowProxy).creationCode;
  }

  function preCalculateEscrowAddress(
    address implementation,
    bytes32 salt
  ) public view returns (address addr) {
    bytes32 bytecodeHash = keccak256(
      abi.encodePacked(type(JusrisEscrowProxy).creationCode, uint256(uint160(implementation)))
    );

    assembly {
      let ptr := mload(0x40)
      mstore(add(ptr, 0x40), bytecodeHash)
      mstore(add(ptr, 0x20), salt)
      mstore(ptr, address())
      let start := add(ptr, 0x0b)
      mstore8(start, 0xff)
      addr := keccak256(start, 85)
    }
  }

  function deployEscrow(
    address implementation,
    bytes memory initializer,
    bytes32 salt
  ) external returns (JusrisEscrowProxy proxy) {
    bytes memory deploymentData = abi.encodePacked(
      type(JusrisEscrowProxy).creationCode,
      uint256(uint160(implementation))
    );
    /* solhint-disable no-inline-assembly */
    /// @solidity memory-safe-assembly
    assembly {
      let size := extcodesize(implementation)
      if not(gt(size, 0)) {
        revert(0, 0)
      }
      proxy := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
      if eq(proxy, 0) {
        revert(0, 0)
      }
      if eq(call(gas(), proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0), 0) {
        revert(0, 0)
      }
    }

    emit EscrowCreated(proxy, implementation);
  }
}
