import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import chai from "chai";
import { Contract, ZeroAddress } from "ethers";
import { deployments } from "hardhat";
import {
  IJurisEscrowProxy__factory,
  JUSDC,
  JUSDC__factory,
  JurisEscrowFactoryFacet,
  JurisEscrowFactoryFacet__factory,
  JurisEscrow,
  JurisEscrowProxy__factory,
  JurisEscrow__factory,
} from "../types";
import { Ship, advanceTimeAndBlock } from "../utils";

const { expect } = chai;

let ship: Ship;
let escrowFactory: JurisEscrowFactoryFacet;
let escrowImpl: JurisEscrow;
let usdc: JUSDC;

let deployer: SignerWithAddress;
let safe: SignerWithAddress;
let plaintiff: SignerWithAddress;
let lawyer: SignerWithAddress;

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

describe("JurisEscrow factory test", function () {
  let key: string;
  let timestamp: bigint;

  const markup: bigint = 5_000_000n;
  const principal: bigint = 10_000n * 1_000_000n;
  const settlement: bigint = principal * 10n + markup;
  // const debt: bigint = 11_407_373_271n;
  // const settlement30: bigint = (30n * settlement) / 100n;
  // const debt3: bigint = (debt * 3n) / 100n;
  const apr: bigint = 27n;

  function getCalldata() {
    return escrowImpl.interface.encodeFunctionData("initialize", [
      principal,
      apr,
      plaintiff.address,
      lawyer.address,
      safe.address,
      usdc.target,
    ]);
  }

  before(async () => {
    const scaffold = await setup();

    deployer = scaffold.accounts.deployer;
    safe = scaffold.accounts.safe;
    plaintiff = scaffold.accounts.alice;
    lawyer = scaffold.accounts.bob;

    escrowImpl = await ship.connect(JurisEscrow__factory);
    usdc = await ship.connect(JUSDC__factory);
    const diamond = await ship.connect("JurisFund");
    escrowFactory = JurisEscrowFactoryFacet__factory.connect(
      (diamond as Contract).target as string,
      deployer,
    );
    await usdc.connect(deployer).mint(settlement * 12n);
  });
  it("deploys escrow with initializer", async () => {
    const tx = await escrowFactory.deployEscrow(
      getCalldata(),
      "0xef50095700000000000000000000000000000000000000000000000000000000",
    );

    const receipt = await tx.wait();
    const event = receipt?.logs
      .map((log) => escrowFactory.interface.parseLog(log.toJSON()))
      .find((item) => item?.name === "EscrowCreated");

    const proxyAddress = event?.args[0];

    expect(await ship.deployed(proxyAddress)).to.be.true;

    expect(proxyAddress).to.not.equal(ZeroAddress);

    const escrow = IJurisEscrowProxy__factory.connect(proxyAddress, deployer);

    expect(await escrow.escrowAddress()).to.equal(escrowImpl.target);
  });

  it("marks escrow unsettled after deployment", async () => {
    const proxy = await escrowFactory.preCalculateEscrowAddress(
      "0xef50095700000000000000000000000000000000000000000000000000000000",
    );
    expect(proxy).to.not.equal(ZeroAddress);
    expect(await ship.deployed(proxy)).to.be.true;
    expect(await escrowFactory.isSettled(proxy)).to.be.false;
  });

  it("pre-calculates escrow address", async () => {
    const addr = await escrowFactory.preCalculateEscrowAddress(
      "0xef50095743000000000000000000000000000000000000000000000000000000",
    );

    expect(addr).to.not.equal(ZeroAddress);

    expect(await ship.deployed(addr)).to.be.false;

    const addr2 = await escrowFactory.preCalculateEscrowAddress(
      "0xef50095700000000000000000000000000000000000000000000000000000000",
    );

    expect(addr2).to.not.equal(ZeroAddress);

    expect(await ship.deployed(addr2)).to.be.true;
  });

  it("checks upkeep", async () => {
    const upkeep = await escrowFactory.checkUpkeep("0x");

    expect(upkeep[0]).to.equal(false);

    await advanceTimeAndBlock(4 * 60 * 60);

    const upkeep2 = await escrowFactory.checkUpkeep("0x");

    expect(upkeep2[0]).to.equal(true);
  });

  it("updates upkeepInterval after interval", async () => {
    const upkeep = await escrowFactory.checkUpkeep("0x");
    expect(upkeep[0]).to.equal(true);

    await escrowFactory.performUpkeep("0x");

    const upkeep2 = await escrowFactory.checkUpkeep("0x");
    expect(upkeep2[0]).to.equal(false);

    await advanceTimeAndBlock(4 * 60 * 60);

    const upkeep3 = await escrowFactory.checkUpkeep("0x");
    expect(upkeep3[0]).to.equal(true);
  });

  it("performs upkeep", async () => {
    const proxy = await escrowFactory.preCalculateEscrowAddress(
      "0xef50095700000000000000000000000000000000000000000000000000000000",
    );
    expect(proxy).to.not.equal(ZeroAddress);
    expect(await ship.deployed(proxy)).to.be.true;

    const escrow = IJurisEscrowProxy__factory.connect(proxy, deployer);

    await usdc.connect(deployer).approve(escrow.target, settlement);
    await escrow.deposit(settlement);

    expect(await escrow.ready()).to.be.true;
    advanceTimeAndBlock(3600 * 24 * 180);

    await escrowFactory.performUpkeep("0x");

    expect(await escrow.ready()).to.be.false;
  });

  it("emits EscrowCreated event on escrow creation", async () => {
    await expect(
      escrowFactory.deployEscrow(
        getCalldata(),
        "0xef80095700000000000000000000000000000000000000000000000000000000",
      ),
    ).to.emit(escrowFactory, "EscrowCreated");
  });

  it("marks escrow settled after upkeep", async () => {
    const proxy = await escrowFactory.preCalculateEscrowAddress(
      "0xef50095700000000000000000000000000000000000000000000000000000000",
    );
    expect(proxy).to.not.equal(ZeroAddress);
    expect(await ship.deployed(proxy)).to.be.true;
    expect(await escrowFactory.isSettled(proxy)).to.be.true;
  });
});
