// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct StakeData {
  uint256 unlockTime; // unlock time
  uint256 amount; // amount of USDC
  uint256 tokenAmount; // mintedToken amount when stake
  address owner; // address of owner
  bool finished; // this value is true after user unstake
}

struct PoolStorage {
  address _token; //token address
  uint256 _totalStakedAmount; // total staked amount
  mapping(bytes32 => StakeData) _stakes; // staking data
}

library JurisPoolStorage {
  // keccak256(abi.encode(uint256(keccak256("juris.storage.pool")) - 1)) & ~bytes32(uint256(0xff));
  bytes32 private constant StorageLocation =
    0x8356a23936d9181410b4eb87f7ea6c98d92f0b339d590a092fe7e438640c3900;

  function _getPoolStorage() internal pure returns (PoolStorage storage $) {
    assembly {
      $.slot := StorageLocation
    }
  }
}
