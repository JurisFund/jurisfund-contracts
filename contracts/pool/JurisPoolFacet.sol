// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable, IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {JurisPoolStorage, PoolStorage, StakeData} from "./JurisPoolStorage.sol";

contract JurisPoolFacet is ERC20Upgradeable, ReentrancyGuardUpgradeable {
  event NewStake(
    bytes32 indexed key,
    address indexed owner,
    uint256 amount,
    uint256 unlockTime,
    uint256 mintAmount
  );
  event NewUnstake(
    bytes32 indexed key,
    address indexed owner,
    uint256 amount,
    uint256 rewardAmount
  );
  /// @dev constants
  uint256 public constant FULL_PERIOD = 2 * 365 * 24 * 3600; // 2 years
  uint256 public constant HALF_PERIOD = 365 * 24 * 3600; // 1 years
  uint256 public constant MIN_STAKE_AMOUNT = 10_000_000; // $10

  function stake(bool _useHalfStake, uint256 _amount) external nonReentrant {
    require(_amount > MIN_STAKE_AMOUNT, "JurisPool: stake amount is too small");
    PoolStorage storage ps = JurisPoolStorage._getPoolStorage();

    uint256 unlockTime = block.timestamp + (_useHalfStake ? HALF_PERIOD : FULL_PERIOD);

    uint256 mintAmount = _amount;
    if (ps._totalStakedAmount > 0) {
      mintAmount = (totalSupply() * _amount) / ps._totalStakedAmount;
    }
    bytes32 key = keccak256(abi.encodePacked(msg.sender, _amount, unlockTime));
    ps._stakes[key] = StakeData(unlockTime, _amount, mintAmount, msg.sender, false);
    ps._totalStakedAmount += _amount;

    _mint(msg.sender, mintAmount);
    IERC20(ps._token).transferFrom(msg.sender, address(this), _amount);

    emit NewStake(key, msg.sender, _amount, unlockTime, mintAmount);
  }

  function unStake(bytes32 _key) external nonReentrant {
    PoolStorage storage ps = JurisPoolStorage._getPoolStorage();
    StakeData storage data = ps._stakes[_key];
    require(!data.finished, "JurisPool: already unStaked!");
    require(data.owner == msg.sender, "JurisPool: you are not owner of this stake");

    data.finished = true;
    uint256 rewardAmount = (data.tokenAmount * ps._totalStakedAmount) / totalSupply();
    ps._totalStakedAmount -= rewardAmount;

    _burn(msg.sender, data.tokenAmount);
    IERC20(ps._token).transfer(msg.sender, rewardAmount);

    emit NewUnstake(_key, msg.sender, data.amount, rewardAmount);
  }
}
