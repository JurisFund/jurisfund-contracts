// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error InvalidImplementationAddress();

/// adapted from https://github.com/safe-global/safe-contracts/blob/main/contracts/proxies/SafeProxy.sol
contract JusrisEscrowProxy {
  address internal _IMPLEMENTATION_SLOT;

  constructor(address _implementation) {
    if (_implementation == address(0)) {
      revert InvalidImplementationAddress();
    }
    _IMPLEMENTATION_SLOT = _implementation;
  }

  /// @dev Fallback function forwards all transactions and returns all received return data.
  fallback() external payable {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      let _implementation := and(sload(0), 0xffffffffffffffffffffffffffffffffffffffff)
      if eq(calldataload(0), 0x0d5defa400000000000000000000000000000000000000000000000000000000) {
        mstore(0, _implementation)
        return(0, 0x20)
      }
      calldatacopy(0, 0, calldatasize())
      let success := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      if eq(success, 0) {
        revert(0, returndatasize())
      }
      return(0, returndatasize())
    }
  }
}
