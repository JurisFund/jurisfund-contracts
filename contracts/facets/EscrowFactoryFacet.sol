// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {JurisEscrowProxy} from "./EscrowProxy.sol";
import {IJurisEscrowProxy} from "../interfaces/IJurisEscrowProxy.sol";
import {LibJurisEscrow} from "../lib/LibJurisEscrow.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// adapted from:
/// - openzeppelin Creat2 lib
/// - safe-protocol proxy Factory
contract JurisEscrowFactoryFacet is AutomationCompatibleInterface, ReentrancyGuardUpgradeable {
  event EscrowCreated(JurisEscrowProxy indexed proxy, address implementation);

  function isSettled(IJurisEscrowProxy proxy) external view returns (bool) {
    return LibJurisEscrow._getEscrowStorage()._escrowSettled[address(proxy)];
  }

  function checkUpkeep(
    bytes calldata /* checkData */
  ) external view override returns (bool upkeepNeeded, bytes memory performData) {
    LibJurisEscrow.EscrowStorage storage es = LibJurisEscrow._getEscrowStorage();
    upkeepNeeded = (block.timestamp - es._lastUpkeep) > es._upkeepInterval;
    performData = new bytes(0);
  }

  function performUpkeep(bytes calldata /* performData */) external override nonReentrant {
    LibJurisEscrow.EscrowStorage storage es = LibJurisEscrow._getEscrowStorage();
    if ((block.timestamp - es._lastUpkeep) > es._upkeepInterval) {
      es._lastUpkeep = block.timestamp;
    }
    address[] memory proxies = es._escrowProxies;
    for (uint i = 0; i < proxies.length; i++) {
      if (!es._escrowSettled[proxies[i]]) {
        _trySettle(proxies[i]) == 1 ? es._escrowSettled[proxies[i]] = true : false;
      }
    }
  }

  function escrowCreationCode() public pure returns (bytes memory) {
    return type(JurisEscrowProxy).creationCode;
  }

  function preCalculateEscrowAddress(bytes32 salt) public view returns (address addr) {
    bytes32 bytecodeHash = keccak256(
      abi.encodePacked(
        type(JurisEscrowProxy).creationCode,
        uint256(uint160(LibJurisEscrow._getEscrowStorage()._escrowImplementation))
      )
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
    bytes memory initializer,
    bytes32 salt
  ) external nonReentrant returns (JurisEscrowProxy proxy) {
    LibJurisEscrow.EscrowStorage storage es = LibJurisEscrow._getEscrowStorage();
    address implementation = es._escrowImplementation;
    bytes memory deploymentData = abi.encodePacked(
      type(JurisEscrowProxy).creationCode,
      uint256(uint160(implementation))
    );
    /* solhint-disable no-inline-assembly */
    /// @solidity memory-safe-assembly
    assembly {
      let size := extcodesize(implementation)
      if lt(size, 2) {
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

    es._escrowSettled[address(proxy)] = false;
    es._isEscrow[address(proxy)] = true;
    es._escrowProxies.push(address(proxy));

    emit EscrowCreated(proxy, implementation);
  }

  function _trySettle(address proxy) internal returns (uint256) {
    if (IJurisEscrowProxy(proxy).ready()) {
      try IJurisEscrowProxy(proxy).disburse() {
        return 1;
      } catch {
        return 0;
      }
    }
    return 0;
  }
}
