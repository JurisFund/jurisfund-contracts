import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import chai from "chai";
import { Contract, ZeroAddress } from "ethers";
import { deployments } from "hardhat";
import { JUSDC, JUSDC__factory, JurisTellerFacet, JurisTellerFacet__factory } from "../types";
import { Ship, advanceTimeAndBlock } from "../utils";

const { expect } = chai;

let ship: Ship;
let teller: JurisTellerFacet;
let usdc: JUSDC;

let deployer: SignerWithAddress;
let safe: SignerWithAddress;
let plaintiff: SignerWithAddress;

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

describe("Juris Teller test", function () {
  const amount: bigint = 50_000n * 1_000_000n;

  before(async () => {
    const scaffold = await setup();

    deployer = scaffold.accounts.deployer;
    safe = scaffold.accounts.safe;
    plaintiff = scaffold.accounts.alice;

    usdc = await ship.connect(JUSDC__factory);
    const diamond = await ship.connect("JurisFund");
    teller = JurisTellerFacet__factory.connect((diamond as Contract).target as string, deployer);
    await usdc.connect(safe).mint(amount);
  });

  it("dispenses loan from teller", async () => {
    const tellerInitialBalance = await usdc.balanceOf(teller.target);
    expect(tellerInitialBalance).to.equal(0n);

    await usdc.connect(safe).transfer(teller.target, 5_000_000n);

    const tellerBalance = await usdc.balanceOf(teller.target);
    expect(tellerBalance).to.equal(5_000_000n);

    await teller.connect(safe).dispense(usdc, plaintiff, 5_000_000n);
    const finalTellerBalance = await usdc.balanceOf(teller.target);
    expect(finalTellerBalance).to.equal(0n);
  });

  it("emits Dispensed Event after dispensing loan", async () => {
    await advanceTimeAndBlock(60);
    const events = await teller.queryFilter(teller.filters.Dispensed());
    expect(events.length).to.equal(1);
  });

  it("reverts when not called by safe", async () => {
    await expect(teller.connect(plaintiff).dispense(usdc, plaintiff, amount)).to.be.revertedWithCustomError(
      teller,
      "UnAuthorized",
    );
    await expect(
      teller.connect(plaintiff).updateTellerConfig(2600n, 5_000_000n),
    ).to.be.revertedWithCustomError(teller, "UnAuthorized");
  });

  it("updates teller config", async () => {
    await expect(teller.connect(safe).updateTellerConfig(2600n, 5_000_000n))
      .to.emit(teller, "TellerConfigUpdated")
      .withArgs(2600n, 5_000_000n);
  });

  it("reverts if max withdrawal is exceeded", async () => {
    await expect(
      teller.connect(safe).dispense(usdc, plaintiff, 5_000_000n + 1n),
    ).to.be.revertedWithCustomError(teller, "MaxSingleWithdrawalExceeded");
  });

  it("reverts if delay is not reached", async () => {
    await expect(teller.connect(safe).dispense(usdc, plaintiff, 5_000_000n)).to.be.revertedWithCustomError(
      teller,
      "WithdrawalDelayNotReached",
    );

    await advanceTimeAndBlock(2600);

    await usdc.connect(safe).transfer(teller.target, 5_000_000n);
    await teller.connect(safe).dispense(usdc, plaintiff, 5_000_000n);

    await expect(teller.connect(safe).updateTellerConfig(2600n, 5_000_000n)).to.be.revertedWithCustomError(
      teller,
      "WithdrawalDelayNotReached",
    );

    await expect(teller.connect(safe).dispense(usdc, plaintiff, 5_000_000n)).to.be.revertedWithCustomError(
      teller,
      "WithdrawalDelayNotReached",
    );
  });
});
