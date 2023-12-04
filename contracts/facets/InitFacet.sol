// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UsingDiamondOwner, LibDiamond} from "hardhat-deploy/solc_0.8/diamond/UsingDiamondOwner.sol";
import {IERC165} from "hardhat-deploy/solc_0.8/diamond/interfaces/IERC165.sol";
import {IDiamondCut} from "hardhat-deploy/solc_0.8/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "hardhat-deploy/solc_0.8/diamond/interfaces/IDiamondLoupe.sol";
import {IERC173} from "hardhat-deploy/solc_0.8/diamond/interfaces/IERC173.sol";
import {LibJuris} from "../lib/LibJuris.sol";
import {LibJurisEscrow} from "../lib/LibJurisEscrow.sol";

contract InitFacet is UsingDiamondOwner, Initializable {
  function ds() internal pure returns (LibDiamond.DiamondStorage storage) {
    return LibDiamond.diamondStorage();
  }

  function ps() internal pure returns (LibJuris.PoolStorage storage) {
    return LibJuris._getPoolStorage();
  }

  function es() internal pure returns (LibJurisEscrow.EscrowStorage storage) {
    return LibJurisEscrow._getEscrowStorage();
  }

  function init(
    address _token,
    uint256 _fullPeriod,
    uint256 _minStakeAmount,
    address _escrowImplementation
  ) external onlyOwner initializer {
    es()._upkeepInterval = 2600; // an hour
    es()._escrowImplementation = _escrowImplementation;
    es()._lastUpkeep = block.timestamp;

    ps()._token = _token;
    ps()._fullPeriod = _fullPeriod;
    ps()._minStakeAmount = _minStakeAmount;

    ds().supportedInterfaces[type(IERC165).interfaceId] = true;
    ds().supportedInterfaces[type(IDiamondCut).interfaceId] = true;
    ds().supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
    ds().supportedInterfaces[type(IERC173).interfaceId] = true;
  }
}
