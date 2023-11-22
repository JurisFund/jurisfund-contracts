// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {LibJurisPool, StakeData} from "../lib/LibJurisPool.sol";

contract JurisPoolFacet is ReentrancyGuardUpgradeable {
  event Staked(
    bytes32 indexed key,
    address indexed owner,
    uint256 amount,
    uint256 unlockTime,
    uint256 liquidity
  );
  event Withdrawal(
    bytes32 indexed key,
    address indexed owner,
    uint256 amount,
    uint256 rewardAmount
  );

  error InvalidStakeAmount();
  error Forbidden(address owner);
  error AlreadyWithdrawn();
  error Locked(uint256 unlockTime);

  function stake(bool _useHalfStake, uint256 _amount) external nonReentrant {
    LibJurisPool.PoolStorage storage ps = LibJurisPool._getPoolStorage();
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
  }

  function unStake(bytes32 _key) external nonReentrant {
    LibJurisPool.PoolStorage storage ps = LibJurisPool._getPoolStorage();
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

    emit Withdrawal(_key, msg.sender, data.amount, rewardAmount);
  }

  function getStake(bytes32 key) external view returns (StakeData memory stakeData) {
    stakeData = LibJurisPool._getPoolStorage()._stakes[key];
  }

  function getPoolState() external view returns (uint256 stakedAmount, uint256 liquidity) {
    stakedAmount = LibJurisPool._getPoolStorage()._totalStakedAmount;
    liquidity = LibJurisPool._getPoolStorage()._liquidity;
  }

  function getPoolConfig()
    external
    view
    returns (address token, uint256 fullPeriod, uint256 minStakeAmount)
  {
    token = LibJurisPool._getPoolStorage()._token;
    fullPeriod = LibJurisPool._getPoolStorage()._fullPeriod;
    minStakeAmount = LibJurisPool._getPoolStorage()._minStakeAmount;
  }
}
