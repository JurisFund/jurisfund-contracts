// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, IJurisTeller} from "../interfaces/IJurisTeller.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibJuris} from "../lib/LibJuris.sol";
import {UsingDiamondOwner} from "hardhat-deploy/solc_0.8/diamond/UsingDiamondOwner.sol";

contract JurisTellerFacet is IJurisTeller {
  using SafeERC20 for IERC20;

  function dispense(IERC20 token, address plaintiff, uint256 amount) external {
    LibJuris.TellerStorage memory ts = LibJuris._getTellerStorage();

    if (msg.sender != ts._safe) {
      revert UnAuthorized();
    }

    if (amount > ts._maxSingleWithdrawal) {
      revert MaxSingleWithdrawalExceeded();
    }

    if (block.timestamp < ts._withdrawalDelay + ts._lastWithdrawal) {
      revert WithdrawalDelayNotReached();
    }

    LibJuris._getTellerStorage()._lastWithdrawal = uint128(block.timestamp);

    token.safeTransfer(plaintiff, amount);
    emit Dispensed(plaintiff, amount);
  }

  function updateTellerConfig(uint256 delay, uint256 maxSingleWithdrawal) external {
    LibJuris.TellerStorage storage ts = LibJuris._getTellerStorage();
    if (msg.sender != ts._safe) {
      revert UnAuthorized();
    }
    // if a withdrawal has been made disables updating the delay
    if (block.timestamp < ts._withdrawalDelay + ts._lastWithdrawal) {
      revert WithdrawalDelayNotReached();
    }
    ts._withdrawalDelay = uint128(delay);
    ts._maxSingleWithdrawal = maxSingleWithdrawal;

    emit TellerConfigUpdated(delay, maxSingleWithdrawal);
  }
}
