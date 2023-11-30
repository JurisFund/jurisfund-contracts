// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StakeData, EscrowAccount} from "./Structs.sol";

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
    address _signer; // signer of escrow
    mapping(bytes32 => EscrowAccount) _escrows; // escrow account data
  }

  // keccak256(abi.encode(uint256(keccak256("juris.storage.pool")) - 1)) & ~bytes32(uint256(0xff));
  bytes32 private constant PoolStorageLocation =
    0x8356a23936d9181410b4eb87f7ea6c98d92f0b339d590a092fe7e438640c3900;

  // keccak256(abi.encode(uint256(keccak256("juris.storage.pool")) - 1)) & ~bytes32(uint256(0xff));
  bytes32 private constant EscrowStorageLocation =
    0x8f1ea076d449c7290f6ee76c738ebf60764f11117112437b78d7eb9fa6333000;

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
}
