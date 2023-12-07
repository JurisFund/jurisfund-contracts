// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {LibJuris, StakeData} from "../lib/LibJuris.sol";
import {UsingDiamondOwner} from "hardhat-deploy/solc_0.8/diamond/UsingDiamondOwner.sol";
import {IJurisPool} from "../interfaces/IJurisPool.sol";

contract JurisPoolFacet is IJurisPool, ReentrancyGuardUpgradeable, UsingDiamondOwner {
  function stake(bool _useHalfStake, uint256 _amount) external nonReentrant {
    LibJuris.PoolStorage storage ps = LibJuris._getPoolStorage();
    if (_amount < ps._minStakeAmount) {
      revert InvalidStakeAmount();
    }

    uint256 unlockTime = block.timestamp + (_useHalfStake ? ps._fullPeriod / 2 : ps._fullPeriod);

    uint256 liquidity = _amount;
    if (ps._totalStakedAmount > 0) {
      liquidity = (ps._liquidity * _amount) / ps._totalStakedAmount;
    }
    bytes32 key = keccak256(abi.encodePacked(msg.sender, _amount, unlockTime));
    ps._stakes[key] = StakeData(unlockTime, _amount, liquidity, msg.sender, false);
    ps._totalStakedAmount += _amount;
    ps._liquidity += liquidity;

    IERC20(ps._token).transferFrom(msg.sender, address(this), _amount);

    emit Staked(key, msg.sender, _amount, unlockTime, liquidity);
    emit RateUpdated(ps._liquidity, ps._totalStakedAmount);
  }

  function unStake(bytes32 _key) external nonReentrant {
    LibJuris.PoolStorage storage ps = LibJuris._getPoolStorage();
    StakeData storage data = ps._stakes[_key];
    if (data.finished) {
      revert AlreadyWithdrawn();
    }
    if (data.owner != msg.sender) {
      revert Forbidden(data.owner);
    }
    if (block.timestamp < data.unlockTime) {
      revert Locked(data.unlockTime);
    }

    data.finished = true;
    uint256 rewardAmount = (data.liquidity * ps._totalStakedAmount) / ps._liquidity;
    ps._totalStakedAmount -= rewardAmount;
    ps._liquidity -= data.liquidity;

    IERC20(ps._token).transfer(msg.sender, rewardAmount);

    emit RateUpdated(ps._liquidity, ps._totalStakedAmount);
    emit Withdrawal(_key, msg.sender, data.amount, rewardAmount);
  }

  function updatePool(uint256 _principal, uint256 _netRepayment) external {
    require(_netRepayment >= _principal, "JurisPool: invalid repayment amount");
    LibJuris.PoolStorage storage ps = LibJuris._getPoolStorage();
    LibJuris.EscrowStorage storage es = LibJuris._getEscrowStorage();

    if (!es._isEscrow[msg.sender]) {
      revert UnAuthorized();
    }

    // IERC20(ps._token).transferFrom(msg.sender, address(this), _netRepayment);
    ps._totalStakedAmount += _netRepayment - _principal;

    emit RateUpdated(ps._liquidity, ps._totalStakedAmount);
  }

  function updateConfig(uint256 _fullPeriod, uint256 _minStakeAmount) external onlyOwner {
    LibJuris.PoolStorage storage ps = LibJuris._getPoolStorage();
    ps._fullPeriod = _fullPeriod;
    ps._minStakeAmount = _minStakeAmount;
  }

  function getStake(bytes32 key) external view returns (StakeData memory stakeData) {
    stakeData = LibJuris._getPoolStorage()._stakes[key];
  }

  function getPoolState() external view returns (uint256 stakedAmount, uint256 liquidity) {
    stakedAmount = LibJuris._getPoolStorage()._totalStakedAmount;
    liquidity = LibJuris._getPoolStorage()._liquidity;
  }

  function getPoolConfig()
    external
    view
    returns (address token, uint256 fullPeriod, uint256 minStakeAmount)
  {
    token = LibJuris._getPoolStorage()._token;
    fullPeriod = LibJuris._getPoolStorage()._fullPeriod;
    minStakeAmount = LibJuris._getPoolStorage()._minStakeAmount;
  }
}
