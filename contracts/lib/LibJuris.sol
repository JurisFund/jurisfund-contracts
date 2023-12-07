// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StakeData} from "./Structs.sol";

library LibJuris {
  struct PoolStorage {
    address _token; //token address
    uint256 _totalStakedAmount; // total staked amount
    uint256 _fullPeriod; // full stack period
    uint256 _minStakeAmount; // minimal stack amount
    uint256 _liquidity;
    mapping(bytes32 => StakeData) _stakes; // staking data
  }
  struct EscrowStorage {
    uint256 _upkeepInterval;
    uint256 _lastUpkeep;
    address _escrowImplementation;
    address[] _escrowProxies;
    mapping(address => bool) _escrowSettled;
    mapping(address => bool) _isEscrow;
  }
  struct TellerStorage {
    uint128 _withdrawalDelay;
    uint128 _lastWithdrawal;
    uint256 _maxSingleWithdrawal;
    address _safe;
  }

  // keccak256(abi.encode(uint256(keccak256("juris.storage.pool")) - 1)) & ~bytes32(uint256(0xff));
  bytes32 private constant PoolStorageLocation =
    0x8356a23936d9181410b4eb87f7ea6c98d92f0b339d590a092fe7e438640c3900;

  // keccak256(abi.encode(uint256(keccak256("juris.storage.escrow")) - 1)) & ~bytes32(uint256(0xff));
  bytes32 private constant EscrowStorageLocation =
    0x8afd255bdb7f34c49f6072e0b5539cfc59131ad505e98fc66299c2b24a8b2600;

  // keccak256(abi.encode(uint256(keccak256("juris.storage.teller")) - 1)) & ~bytes32(uint256(0xff));
  bytes32 private constant TellerStorageLocation =
    0xbeae2ffc7d1538c26dc42cdb5facc76d68baeac93fbd741beeab0c34b93c9300;

  function _getPoolStorage() internal pure returns (PoolStorage storage $) {
    assembly {
      $.slot := PoolStorageLocation
    }
  }

  function _getEscrowStorage() internal pure returns (EscrowStorage storage $) {
    assembly {
      $.slot := EscrowStorageLocation
    }
  }

  function _getTellerStorage() internal pure returns (TellerStorage storage $) {
    assembly {
      $.slot := TellerStorageLocation
    }
  }
}
