import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { deployments } from "hardhat";
import chai from "chai";
import { Ship, advanceTimeAndBlock } from "../utils";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { JUSDC, JUSDC__factory, JusrisEscrow, JusrisEscrow__factory } from "../types";
import { ethers } from "hardhat";

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
  const apr: bigint = 27n;

  const initEscrow = async () => {
    await escrowProxy
      .connect(deployer)
      .initialize(principal, apr, plantiff.address, lawer.address, safe.address, usdc);
  };

  beforeEach(async () => {
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

    await initEscrow();
  });

  it("cannot be re-initialized", async () => {
    await expect(initEscrow()).to.be.revertedWithCustomError(escrowProxy, "AlreadyInitialized");
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
    expect(await escrowProxy.getBalance()).to.be.equal(settlement);
  });

  it("accepts deposits by normal transfer", async () => {
    await usdc.connect(depositor).transfer(escrowProxy, markup);
    expect(await escrowProxy.getBalance()).to.be.equal(markup);
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
    expect(data).to.be.deep.equal([
      data[0], // timestamp
      apr,
      1n,
      0n,
      principal,
      usdc.target,
      plantiff.address,
      lawer.address,
      deployer.address,
      safe.address,
    ]);
  });

  it("returns ready status", async () => {
    expect(await escrowProxy.ready()).to.be.false;
    await escrowProxy.connect(depositor).deposit(settlement);
    expect(await escrowProxy.ready()).to.be.true;
  });

  it("can be disbursed", async () => {
    await usdc.connect(depositor).transfer(escrowProxy, settlement);
    expect(await usdc.balanceOf(escrowProxy.target)).to.be.equal(settlement);
    await advanceTimeAndBlock(3600 * 24 * 180); // 180 days
    await escrowProxy.connect(deployer).disburse();
    expect(await usdc.balanceOf(escrowProxy.target)).to.be.equal(0);
    expect(await usdc.balanceOf(lawer.address)).to.be.equal(settlement30);
    expect(await usdc.balanceOf(deployer.address)).to.be.equal(11065151827n);
    expect(await usdc.balanceOf(safe.address)).to.be.equal(347221190);
    expect(await usdc.balanceOf(plantiff.address)).to.be.equal(58591126983);
  });

  it("cannot disburse if duration is not greater than 24hours", async () => {
    await usdc.connect(depositor).transfer(escrowProxy, settlement);
    expect(await usdc.balanceOf(escrowProxy.target)).to.be.equal(settlement);
    await expect(escrowProxy.connect(deployer).disburse()).to.be.revertedWithCustomError(
      escrowProxy,
      "Exception",
    );
  });

  it("can be disbursed with externally calculated debt", async () => {
    await usdc.connect(depositor).transfer(escrowProxy, settlement);
    expect(await usdc.balanceOf(escrowProxy.target)).to.be.equal(settlement);
    await escrowProxy.connect(safe).disburseWithOffChainAPR(debt);
    expect(await usdc.balanceOf(escrowProxy.target)).to.be.equal(0);
    expect(await usdc.balanceOf(lawer.address)).to.be.equal(settlement30);
    expect(await usdc.balanceOf(deployer.address)).to.be.equal(debt - debt3);
    expect(await usdc.balanceOf(safe.address)).to.be.equal(debt3 + markup);
    expect(await usdc.balanceOf(plantiff.address)).to.be.equal(settlement - debt - markup - settlement30);
  });

  it("cannot disburse with externally calculated debt if not safe", async () => {
    await expect(escrowProxy.connect(deployer).disburseWithOffChainAPR(debt)).to.be.revertedWithCustomError(
      escrowProxy,
      "UnAuthorized",
    );
  });

  it("cannont be disbursed with externally calculated debt < Principal + Markup", async () => {
    await expect(escrowProxy.connect(safe).disburseWithOffChainAPR(markup)).to.be.revertedWithCustomError(
      escrowProxy,
      "Exception",
    );
  });

  it("reverts on disburse if min settlement amount not met", async () => {
    await expect(escrowProxy.connect(safe).disburseWithOffChainAPR(debt)).to.be.revertedWithCustomError(
      escrowProxy,
      "NotEnoughFunds",
    );
  });

  it("reverts if already settled", async () => {
    await usdc.connect(depositor).transfer(escrowProxy, settlement);
    await escrowProxy.connect(safe).disburseWithOffChainAPR(debt);
    await expect(escrowProxy.connect(deployer).disburse()).to.be.revertedWithCustomError(
      escrowProxy,
      "Exception",
    );
  });

  it("cannot disburse if not diamond or safe", async () => {
    await expect(escrowProxy.connect(lawer).disburse()).to.be.revertedWithCustomError(
      escrowProxy,
      "UnAuthorized",
    );
  });

  it("emits an EscrowSettled event after disbursement", async () => {
    await usdc.connect(depositor).transfer(escrowProxy, settlement);
    await expect(escrowProxy.connect(safe).disburseWithOffChainAPR(debt)).to.emit(
      escrowProxy,
      "EscrowSettled",
    );
  });

  it("allows safe to withdraw locked funds after settlement", async () => {
    await usdc.connect(depositor).transfer(escrowProxy, settlement);
    await escrowProxy.connect(safe).disburseWithOffChainAPR(debt);
    await usdc.connect(depositor).transfer(escrowProxy, markup);
    expect(await usdc.balanceOf(escrowProxy.target)).to.be.equal(markup);
    await escrowProxy.connect(safe).withdraw(usdc);
    expect(await usdc.balanceOf(escrowProxy.target)).to.be.equal(0);
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
    await escrowProxy.connect(safe).disburseWithOffChainAPR(debt);
    await expect(escrowProxy.connect(deployer).withdraw(usdc)).to.be.revertedWithCustomError(
      escrowProxy,
      "UnAuthorized",
    );
  });
});
