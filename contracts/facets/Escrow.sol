// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, EscrowData} from "../lib/Structs.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UD60x18, ud, intoUint256} from "@prb/math/src/UD60x18.sol";

error NotInitialized();
error AlreadyInitialized();
error Unauthorized();
error NotEnoughFunds(uint256 actual, uint256 expected);

/// ------------------ Error Codes --------------------
/// first 4 bytes of keccak256(bytes("error message"))
/// ---------------------------------------------------
/// ES1001 - Debt amount is too low (0xbd070be3)
/// ES1515 - APR must be multiple of 3 (0x30f45722)
/// ES5001 - Escrow must be settled (0x124771cb)
/// ES5011 - Escrow is already settled (0xc1efc194)
/// ES4004 - Withdrawal failed (0xee910bd2)
/// ---------------------------------------------------
error Exception(uint256 errorCode);

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
    escrowData.isSettled = 0;
  }

  function initialize(
    uint256 principal,
    uint256 apr,
    address plantiff,
    address lawer,
    address multisig,
    IERC20 token
  ) external {
    EscrowData memory m_escrowData = escrowData;
    if (m_escrowData.startTime != 0 && m_escrowData.initialized == 1) {
      revert AlreadyInitialized();
    }

    m_escrowData.principal = principal;
    m_escrowData.jurisFundFeePercentage = _enforcePrecision(apr);
    m_escrowData.plantiff = plantiff;
    m_escrowData.plantiffLawer = lawer;
    m_escrowData.jurisFund = msg.sender; // the diamond proxy
    m_escrowData.settlementToken = token;
    m_escrowData.jurisFundSafe = multisig;
    escrowData.startTime = uint128(block.timestamp);
    m_escrowData.initialized = 1;

    escrowData = m_escrowData;
  }

  /// checks if settlement is ready to be disbursed
  function ready() external view returns (bool) {
    return escrowData.isSettled == 0 && getBalance() >= escrowData.principal * 10 + MARKUP;
  }

  /// returns JUSDC balance of the escrow
  function getBalance() public view returns (uint256) {
    return escrowData.settlementToken.balanceOf(self);
  }

  /// enforces one time deposit checks
  /// however manual deposits can be made via normal transfer
  function deposit(uint256 amount) external payable initialized {
    _deposit(amount);
  }

  /// initiates settlement, can be called by automation contract or directly by the
  /// Juris Admin Team via Safe Multisig Tx
  function disburse() external initialized jurisFundOrSafe {
    _disburse(0, getBalance());
  }

  /// initiates settlement with precalculated debt, can be called by only the Juris Admin
  /// Team via Safe Multisig Tx
  function disburseWithOffChainAPR(uint256 precalculatedDebt) external initialized jurisFundSafe {
    if (precalculatedDebt < escrowData.principal + MARKUP) revert Exception(0xbd070be3);
    _disburse(precalculatedDebt, getBalance());
  }

  function getEscrowData() external view returns (EscrowData memory) {
    return escrowData;
  }

  /// incase someone transfers ether or token to escrow proxy after escrow has been settled
  function withdraw(IERC20 token) external initialized jurisFundSafe {
    if (escrowData.isSettled == 0) revert Exception(0x124771cb);

    address safe = escrowData.jurisFundSafe;

    assembly {
      let success
      if gt(selfbalance(), 0) {
        success := call(gas(), safe, selfbalance(), 0, 0, 0, 0)
      }
      if iszero(success) {
        revert(add(0x20, "0xee910bd2"), 24)
      }
    }

    uint256 amount = token.balanceOf(self);
    if (amount > 0) token.safeTransfer(safe, amount);
  }

  function _deposit(uint256 amount) internal {
    uint256 minDeposit = escrowData.principal * 10 + MARKUP;
    IERC20 settlementToken = escrowData.settlementToken;

    if (amount < minDeposit) revert NotEnoughFunds(amount, minDeposit);

    settlementToken.safeTransferFrom(msg.sender, self, amount);
  }

  function _disburse(uint256 precalculatedDebt, uint256 settlement) internal {
    EscrowData memory m_escrowData = escrowData;

    _requiresCanBeSettled(settlement, m_escrowData.principal, m_escrowData.isSettled);

    uint256 debt = precalculatedDebt > 1
      ? precalculatedDebt
      : _calculateDebt(
        m_escrowData.principal,
        m_escrowData.jurisFundFeePercentage,
        m_escrowData.startTime
      );

    uint256 lawerCut = settlement.mulDiv(30, 100);
    uint256 rem = settlement - lawerCut - debt;
    uint256 platformFee = debt.mulDiv(3, 100);

    m_escrowData.isSettled = 1;

    IERC20 settlementToken = m_escrowData.settlementToken;

    /// --------------- order of settlement -----------------
    /// plantiff's lawer -> pool -> safe -> plantiff
    /// -----------------------------------------------------

    settlementToken.safeTransfer(m_escrowData.plantiffLawer, lawerCut);
    settlementToken.safeTransfer(m_escrowData.jurisFund, debt - platformFee);
    settlementToken.safeTransfer(m_escrowData.jurisFundSafe, platformFee + MARKUP);
    settlementToken.safeTransfer(m_escrowData.plantiff, rem - MARKUP);

    emit EscrowSettled(settlement, debt, block.timestamp);
  }

  // calculates the refund to jurisFund
  function _calculateDebt(
    uint256 principal,
    uint128 rate,
    uint128 time
  ) internal view returns (uint256) {
    UD60x18 factor = ud(1e6);
    UD60x18 P = ud(principal);
    UD60x18 r = ud(_getPrescision(rate));
    UD60x18 t = ud(_getExponent(time));

    UD60x18 R = r.div(factor);
    UD60x18 T = t.div(factor);

    UD60x18 exp = R.pow(T);

    UD60x18 total = P.mul(exp);

    return intoUint256(total);
  }

  function _getExponent(uint128 startTime) internal view returns (uint256) {
    uint256 loanDuration = block.timestamp - startTime;
    uint256 exponent = COMPOUNDING_FREQUENCY.mulDiv(loanDuration, 365 days);
    return exponent;
  }

  function _getPrescision(uint256 n) internal pure returns (uint256) {
    uint256 denominator = COMPOUNDING_FREQUENCY;
    return ((n * 1e4 * 1e6) / denominator) + denominator.mulDiv(1e6, denominator);
  }

  function _enforcePrecision(uint256 n) internal pure returns (uint112) {
    if (n % 3 != 0) {
      revert Exception(0x30f45722);
    }
    return uint112(n);
  }

  function _requiresCanBeSettled(
    uint256 balance,
    uint256 principal,
    uint256 settled
  ) internal pure {
    if (settled == 1) revert Exception(0xc1efc194);
    uint256 minExpectedSettlementDeposit = principal * 10 + MARKUP;
    if (balance < minExpectedSettlementDeposit)
      revert NotEnoughFunds(balance, minExpectedSettlementDeposit);
  }

  modifier initialized() {
    if (escrowData.initialized == 0) {
      revert NotInitialized();
    }
    _;
  }

  modifier jurisFundOrSafe() {
    if (msg.sender != escrowData.jurisFund && msg.sender != escrowData.jurisFundSafe) {
      revert Unauthorized();
    }
    _;
  }

  modifier jurisFundSafe() {
    if (msg.sender != escrowData.jurisFundSafe) {
      revert Unauthorized();
    }
    _;
  }

  event EtherRecieved(uint256 amount);
  event EscrowInitialized(uint256 principal, address plantiff, address lawer, address token);
  event EscrowSettled(uint256 settlement, uint256 jurisFundFee, uint256 timestamp);

  receive() external payable {
    emit EtherRecieved(msg.value);
  }
}
