// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UsingDiamondOwner, LibDiamond} from "hardhat-deploy/solc_0.8/diamond/UsingDiamondOwner.sol";
import {IERC165} from "hardhat-deploy/solc_0.8/diamond/interfaces/IERC165.sol";
import {IDiamondCut} from "hardhat-deploy/solc_0.8/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "hardhat-deploy/solc_0.8/diamond/interfaces/IDiamondLoupe.sol";
import {IERC173} from "hardhat-deploy/solc_0.8/diamond/interfaces/IERC173.sol";
import {PoolStorage, JurisPoolStorage} from "../pool/JurisPoolStorage.sol";

contract InitFacet is UsingDiamondOwner, ERC20Upgradeable, Initializable {
  function p() internal pure returns (PoolStorage storage) {
    return JurisPoolStorage._getPoolStorage();
  }

  function ds() internal pure returns (LibDiamond.DiamondStorage storage) {
    return LibDiamond.diamondStorage();
  }

  function init(address _token) external onlyOwner initializer {
    __ERC20_init("Juris Pool Liquidity", "JPL");

    p()._token = _token;

    ds().supportedInterfaces[type(IERC165).interfaceId] = true;
    ds().supportedInterfaces[type(IDiamondCut).interfaceId] = true;
    ds().supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
    ds().supportedInterfaces[type(IERC173).interfaceId] = true;
  }
}
