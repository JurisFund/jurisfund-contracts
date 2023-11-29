// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, EscrowData} from "../lib/Structs.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UD60x18, ud, intoUint256} from "@prb/math/src/UD60x18.sol";

error NotInitialized();
error AlreadyInitialized();
error Unauthorized(address caller);
error UnableToSettle(string reason);
error NotEnoughFunds(uint256 balance, uint256 required);
error Exception(string errorMessage);

contract JusrisEscrow {
  // required for proxy storage
  address internal immutable self = address(this);

  using SafeERC20 for IERC20;
  using Math for uint256;

  uint256 internal constant COMPOUNDING_FREQUENCY = 12e6;
  uint256 internal constant MARKUP = 5e6;

  EscrowData internal escrowData;

  // no params in constructor for proxy
  constructor() {
    escrowData.isSettled = false;
  }

  function initialize(
    uint256 principal,
    uint256 apr,
    address plantiff,
    address lawer,
    address pool,
    address multisig,
    IERC20 token
  ) external {
    EscrowData memory m_escrowData = escrowData;
    if (m_escrowData.startTime != 0 && m_escrowData.initialized) {
      revert AlreadyInitialized();
    }

    m_escrowData.principal = principal;
    m_escrowData.jurisFundFeePercentage = _enforcePrecision(apr);
    m_escrowData.plantiff = plantiff;
    m_escrowData.plantiffLawer = lawer;
    m_escrowData.jurisFundPool = pool;
    m_escrowData.settlementToken = token;
    m_escrowData.jurisFundSafe = multisig;
    escrowData.startTime = uint128(block.timestamp);
    m_escrowData.initialized = true;

    escrowData = m_escrowData;
  }

  function getBalance() public view returns (uint256) {
    return escrowData.settlementToken.balanceOf(self);
  }

  function deposit(uint256 amount) external Initialized {
    _deposit(amount);
  }

  function disburse() external Initialized {
    _disburse(0, getBalance());
  }

  function depositAndDisburse(uint256 amount) external Initialized {
    _deposit(amount);
    _disburse(0, amount);
  }

  function depositAndLock(uint256 amount) external Initialized {
    _deposit(amount);
    escrowData.locked = true;
  }

  function unlockAndDisburse() external Initialized JurisFundSafeOrPool {
    escrowData.locked = false;
    _disburse(0, getBalance());
  }

  function unlockAndDisburseWithOffChainAPR(
    uint256 precalculatedDebt
  ) external Initialized JurisFundSafeOrPool {
    if (!escrowData.locked) revert Exception("Escrow not locked");
    escrowData.locked = false;
    _disburse(precalculatedDebt, getBalance());
  }

  function updateEscrowData(
    address settlementToken,
    uint256 jurisFundFeePercentage
  ) external Initialized JurisFundSafeOrPool {
    if (settlementToken != address(0)) {
      uint8 decimals = IERC20Metadata(settlementToken).decimals();
      require(decimals == 6, "Invalid token");
      escrowData.settlementToken = IERC20(settlementToken);
    }

    if (jurisFundFeePercentage > 0) {
      escrowData.jurisFundFeePercentage = _enforcePrecision(jurisFundFeePercentage);
    }
  }

  function getEscrowData() external view returns (EscrowData memory) {
    return escrowData;
  }

  function _deposit(uint256 amount) internal {
    uint256 minDeposit = escrowData.principal * 10;
    IERC20 settlementToken = escrowData.settlementToken;

    if (amount < minDeposit) revert NotEnoughFunds(amount, minDeposit);

    bool success = settlementToken.transferFrom(msg.sender, self, amount);
    if (!success) revert NotEnoughFunds(amount, settlementToken.balanceOf(msg.sender));
  }

  function _disburse(uint256 precalculatedDebt, uint256 settlement) internal {
    _requiresEscrowUnlockedAndNotSettled();

    uint256 balance = getBalance();
    if (balance < settlement) revert NotEnoughFunds(balance, settlement);

    uint256 debt = precalculatedDebt > escrowData.principal + MARKUP
      ? precalculatedDebt
      : _calculateDebt();

    uint256 lawerCut = settlement.mulDiv(30, 100);
    uint256 rem = settlement - lawerCut - debt;
    uint256 platformFee = debt.mulDiv(3, 100);

    escrowData.isSettled = true;

    IERC20 settlementToken = escrowData.settlementToken;

    settlementToken.safeTransfer(escrowData.plantiffLawer, lawerCut);
    settlementToken.safeTransfer(escrowData.jurisFundPool, debt - platformFee);
    settlementToken.safeTransfer(escrowData.jurisFundSafe, platformFee);
    settlementToken.safeTransfer(escrowData.plantiff, rem);

    emit EscrowSettled(settlement, debt, block.timestamp);
  }

  // calculates the refund to jurisFund
  function _calculateDebt() internal view returns (uint256) {
    uint256 principal = escrowData.principal; // p max 100k usd enforced from pool
    uint256 rate = _getPrescision(uint256(escrowData.jurisFundFeePercentage)); // r 1022500 for 27% constant
    uint256 time = _getExponent(); // t timestamp * 1e6
    return _calculateDebt(principal, rate, time);
  }

  function _calculateDebt(
    uint256 principal,
    uint256 rate,
    uint256 time
  ) internal pure returns (uint256) {
    UD60x18 factor = ud(1e6);
    UD60x18 P = ud(principal);
    UD60x18 r = ud(rate);
    UD60x18 t = ud(time);

    UD60x18 R = r.div(factor);
    UD60x18 T = t.div(factor);

    UD60x18 exp = R.pow(T);

    UD60x18 total = P.mul(exp);

    return intoUint256(total);
  }

  function _getExponent() internal view returns (uint256) {
    uint256 loanDuration = block.timestamp - uint256(escrowData.startTime);
    uint256 exponent = COMPOUNDING_FREQUENCY.mulDiv(loanDuration, 365 days);
    return exponent;
  }

  function _getPrescision(uint256 n) internal pure returns (uint256) {
    uint256 denominator = COMPOUNDING_FREQUENCY;
    return ((n * 1e4 * 1e6) / denominator) + denominator.mulDiv(1e6, denominator);
  }

  function _enforcePrecision(uint256 n) internal pure returns (uint128) {
    if (n % 3 != 0) {
      revert Exception("APR must be multiple of 3");
    }
    return uint128(n);
  }

  function _requiresEscrowUnlockedAndNotSettled() internal view {
    if (escrowData.locked) revert UnableToSettle("Escrow locked");
    if (escrowData.isSettled) revert UnableToSettle("Escrow settled");
  }

  receive() external payable {
    emit EtherRecieved(msg.value);
  }

  event EtherRecieved(uint256 amount);
  event EscrowInitialized(uint256 principal, address plantiff, address lawer, address token);
  event EscrowSettled(uint256 settlement, uint256 jurisFundFee, uint256 timestamp);

  modifier Initialized() {
    if (!escrowData.initialized) {
      revert NotInitialized();
    }
    _;
  }

  modifier JurisFundSafeOrPool() {
    if (msg.sender != escrowData.jurisFundPool || msg.sender != address(escrowData.jurisFundSafe)) {
      revert Unauthorized(msg.sender);
    }
    _;
  }
}
