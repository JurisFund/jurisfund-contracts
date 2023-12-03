import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { deployments } from "hardhat";
import chai from "chai";
import { Ship, advanceTimeAndBlock } from "../utils";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { JUSDC, JUSDC__factory, JusrisEscrow, JusrisEscrow__factory } from "../types";
import { ZeroAddress, ethers } from "ethers";

const { expect } = chai;

let ship: Ship;
let escrowProxy: JusrisEscrow;
let usdc: JUSDC;

let deployer: SignerWithAddress; // also the diamond
let safe: SignerWithAddress;
let plantiff: SignerWithAddress;
let lawer: SignerWithAddress;
let depositor: SignerWithAddress; // settlement depositor

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["init"]);

  return {
    ship,
    accounts,
    users,
  };
});

describe("JurisEscrow implementation", function () {
  let key: string;
  let timestamp: bigint;

  const markup: bigint = 5_000_000n;
  const principal: bigint = 10_000n * 1_000_000n;
  const settlement: bigint = principal * 10n + markup;
  const debt: bigint = 11_407_373_271n;
  const settlement30: bigint = (30n * settlement) / 100n;
  const debt3: bigint = (debt * 3n) / 100n;

  const initEscrow = async (apr = 27) => {
    await escrowProxy
      .connect(deployer)
      .initialize(principal, apr, plantiff.address, lawer.address, safe.address, usdc);
  };

  before(async () => {
    const scaffold = await setup();

    deployer = scaffold.accounts.deployer;
    safe = scaffold.accounts.safe;
    plantiff = scaffold.accounts.alice;
    lawer = scaffold.accounts.bob;
    depositor = scaffold.accounts.signer;

    usdc = await ship.connect(JUSDC__factory);
    escrowProxy = await ship.connect(JusrisEscrow__factory);

    await usdc.connect(depositor).mint(settlement * 12n);
    await usdc.connect(depositor).approve(escrowProxy.target, settlement * 12n);
  });

  it("reverts if APR is not a multiple of 3", async () => {
    await expect(await initEscrow(28)).to.be.revertedWithCustomError(escrowProxy, "Exception");
  });

  describe("after initialization", () => {
    before(async () => {
      await initEscrow();
    });

    it("cannot be re-initialized", async () => {
      await expect(await initEscrow()).to.be.revertedWithCustomError(escrowProxy, "AlreadyInitialized");
    });

    it("emited an EscrowInitialized event after initialization", async () => {
      await advanceTimeAndBlock(60);
      const events = await escrowProxy.queryFilter(escrowProxy.filters.EscrowInitialized());
      expect(events.length).to.equal(1);
    });

    it("rejects deposits below p * 10 limit", async () => {
      await expect(escrowProxy.connect(depositor).deposit(markup)).to.be.revertedWithCustomError(
        escrowProxy,
        "NotEnoughFunds",
      );
    });

    it("accepts deposits above p * 10 limit", async () => {
      await escrowProxy.connect(depositor).deposit(settlement);
      await expect(escrowProxy.getBalance()).to.be.equal(settlement);
    });

    it("accepts deposits by normal transfer", async () => {
      await usdc.connect(depositor).transfer(escrowProxy, markup);
      await expect(escrowProxy.getBalance()).to.be.equal(markup);
    });

    it("emits an EtherRecieved event on Ether transfer", async () => {
      await expect(depositor.sendTransaction({ to: escrowProxy, value: ethers.parseEther("1") })).to.emit(
        escrowProxy,
        "EtherRecieved",
      );
    });

    it("can get current token balance", async () => {
      expect(await escrowProxy.getBalance()).to.be.equal(0);
    });

    it("can retrieve escrow data", async () => {
      const data = await escrowProxy.getEscrowData();
      expect(data).to.be.deep.equal({
        initialized: 1,
        isSettled: 0,
        principal: principal,
        settlementToken: usdc,
        plantiff: plantiff.address,
        plantiffLawer: lawer.address,
        jurisFund: deployer.address,
        jurisFundSafe: safe.address,
      });
    });

    it("returns ready status", async () => {
      expect(await escrowProxy.ready()).to.be.false;
      await escrowProxy.connect(depositor).deposit(settlement);
      expect(await escrowProxy.ready()).to.be.true;
    });

    it("can be disbursed", async () => {
      await usdc.connect(depositor).transfer(escrowProxy, settlement);
      expect(await usdc.balanceOf(escrowProxy)).to.be.equal(settlement);
      await escrowProxy.connect(deployer).disburse();
      expect(await usdc.balanceOf(escrowProxy)).to.be.equal(0);
      expect(await usdc.balanceOf(lawer.address)).to.be.equal(settlement30);
      expect(await usdc.balanceOf(deployer.address)).to.be.equal(debt - debt3);
      expect(await usdc.balanceOf(safe.address)).to.be.equal(debt3 + markup);
      expect(await usdc.balanceOf(plantiff.address)).to.be.equal(settlement - debt - markup - settlement30);
    });

    it("can be disbursed with externally calculated debt", async () => {
      await usdc.connect(depositor).transfer(escrowProxy, settlement);
      expect(await usdc.balanceOf(escrowProxy)).to.be.equal(settlement);
      await escrowProxy.connect(deployer).disburseWithOffChainAPR(debt);
      expect(await usdc.balanceOf(escrowProxy)).to.be.equal(0);
      expect(await usdc.balanceOf(lawer.address)).to.be.equal(settlement30);
      expect(await usdc.balanceOf(deployer.address)).to.be.equal(debt - debt3);
      expect(await usdc.balanceOf(safe.address)).to.be.equal(debt3 + markup);
      expect(await usdc.balanceOf(plantiff.address)).to.be.equal(settlement - debt - markup - settlement30);
    });

    it("cannont be disbursed with externally calculated debt < Principal + Markup", async () => {
      await expect(
        escrowProxy.connect(deployer).disburseWithOffChainAPR(markup),
      ).to.be.revertedWithCustomError(escrowProxy, "Exception");
    });

    it("reverts on disburse if min amount not met", async () => {
      await expect(escrowProxy.connect(deployer).disburseWithOffChainAPR(debt)).to.be.revertedWithCustomError(
        escrowProxy,
        "NotEnoughFunds",
      );
    });

    it("cannot disburse if not diamond or safe", async () => {
      await expect(escrowProxy.connect(lawer).disburse()).to.be.revertedWithCustomError(
        escrowProxy,
        "Unauthorized",
      );
    });

    it("emits an EscrowSettled event after disbursement", async () => {
      await usdc.connect(depositor).transfer(escrowProxy, settlement);
      await expect(escrowProxy.connect(deployer).disburse()).to.emit(escrowProxy, "EscrowSettled");
    });

    it("allows safe to withdraw locked funds after settlement", async () => {
      await usdc.connect(depositor).transfer(escrowProxy, settlement);
      await escrowProxy.connect(safe).disburse();
      await usdc.connect(depositor).transfer(escrowProxy, markup);
      expect(await usdc.balanceOf(escrowProxy)).to.be.equal(markup);
      await escrowProxy.connect(safe).withdraw(usdc);
      expect(await usdc.balanceOf(escrowProxy)).to.be.equal(0);
    });

    it("reverts if safe withdraws funds before settlement", async () => {
      await usdc.connect(depositor).transfer(escrowProxy, 5_000_000n);
      await expect(escrowProxy.connect(safe).withdraw(usdc)).to.be.revertedWithCustomError(
        escrowProxy,
        "Exception",
      );
    });

    it("allows only safe to withdraw funds", async () => {
      await usdc.connect(depositor).transfer(escrowProxy, settlement);
      await escrowProxy.connect(safe).disburse();
      await escrowProxy.connect(safe).withdraw(usdc);
      await expect(escrowProxy.connect(lawer).withdraw(usdc)).to.be.revertedWithCustomError(
        escrowProxy,
        "Unauthorized",
      );
    });
  });
});
