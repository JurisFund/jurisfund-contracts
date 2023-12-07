// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StakeData} from "../lib/LibJuris.sol";

interface IJurisPool {
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
  event RateUpdated(uint256 liquidity, uint256 stakeAmount);

  error UnAuthorized();
  error InvalidStakeAmount();
  error Forbidden(address owner);
  error AlreadyWithdrawn();
  error Locked(uint256 unlockTime);

  function stake(bool _useHalfStake, uint256 _amount) external;

  function unStake(bytes32 _key) external;

  function updatePool(uint256 _principal, uint256 _netRepayment) external;

  function updateConfig(uint256 _fullPeriod, uint256 _minStakeAmount) external;

  function getStake(bytes32 key) external view returns (StakeData memory stakeData);

  function getPoolState() external view returns (uint256 stakedAmount, uint256 liquidity);

  function getPoolConfig()
    external
    view
    returns (address token, uint256 fullPeriod, uint256 minStakeAmount);
}
