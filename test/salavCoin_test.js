const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SalvaCoin", function () {
  let salvaCoin, admin, addr1, addr2, addr3, lockedAmount;
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployDDTcontractFixture() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;

    lockedAmount = ONE_GWEI;
    const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

    // Contracts are deployed using the first signer/account by default
    [admin, addr1, addr2, addr3] = await ethers.getSigners();

    const SalvaCoin = await ethers.getContractFactory("SalvaCoin");
    salvaCoin = await SalvaCoin.deploy("Salva Coin", "STCX");
    console.log(`SalvaCoin deployed to ${salvaCoin.address}`);

    return { unlockTime, lockedAmount, admin, addr1, addr2, addr3, salvaCoin };
  }

  describe("Deployment", function () {
    it("Should set the right name and symbol", async function () {
      const { salvaCoin } = await loadFixture(deployDDTcontractFixture);

      expect(await salvaCoin.name()).to.equal("Salva Coin");
      expect(await salvaCoin.symbol()).to.equal("STCX");
    });

    it("Should set the right admin", async function () {
      const { salvaCoin, admin } = await loadFixture(deployDDTcontractFixture);

      expect(await salvaCoin.admin()).to.equal(admin.address);
    });

    it("Should set this contract to fundsToken address", async function () {
      const { salvaCoin } = await loadFixture(
        deployDDTcontractFixture
      );

      expect(await salvaCoin.getFundsToken()).to.equal(salvaCoin.address);

    });

    // it("Should fail if the unlockTime is not in the future", async function () {
    //   // We don't use the fixture here because we want a different deployment
    //   const latestTime = await time.latest();
    //   const Lock = await ethers.getContractFactory("Lock");
    //   await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //     "Unlock time should be in the future"
    //   );
    // });
  });



  describe("Dividend withdrawal", function () {
    describe("minthing  tokens", function () {
      it("Should prevent random user to mint tokens", async function () {

        await expect(salvaCoin.connect(addr1).mint(addr1.address, 100)).to.be.revertedWith(
          'Ownable: caller is not the owner'
        );
      });

      it("Should allow admin(owner) to mint 1 GWEI to addr1, addr2 and addr3", async function () {



        await expect(salvaCoin.mint(addr1.address, lockedAmount))
          .to.emit(salvaCoin, "Transfer")
          .withArgs(ethers.constants.AddressZero, addr1.address, lockedAmount);

        await expect(salvaCoin.mint(addr2.address, lockedAmount))
          .to.emit(salvaCoin, "Transfer")
          .withArgs(ethers.constants.AddressZero, addr2.address, lockedAmount);

        await expect(salvaCoin.mint(addr3.address, lockedAmount))
          .to.emit(salvaCoin, "Transfer")
          .withArgs(ethers.constants.AddressZero, addr3.address, lockedAmount);

        // Confirming the balance

        console.log("confirming the balances...");

        expect(await salvaCoin.balanceOf(addr1.address)).to.be.equal(lockedAmount);
        expect(await salvaCoin.balanceOf(addr2.address)).to.be.equal(lockedAmount);
        expect(await salvaCoin.balanceOf(addr3.address)).to.be.equal(lockedAmount);

      });
    });

    describe("Withdrawals of Dividend", function () {
      it("Should revert while withdrawing dividens because contract is not funded", async function () {

        await expect(salvaCoin.connect(addr1).withdrawFunds())
          .to.be.revertedWith('SalvaContract: 0 funds to distribute.');
      });

      it("should fund the contract treasury", async () => {

        console.log("funding the tresury contract...")

        expect(await salvaCoin.mint(salvaCoin.address, lockedAmount))
          .to.emit(salvaCoin, "Transfer")
          .withArgs(ethers.constants.AddressZero, salvaCoin.address, lockedAmount);

        expect(await salvaCoin.balanceOf(salvaCoin.address)).to.be.equal(lockedAmount);
      })



      it("Should NOW allow addr1 to withdraw one third of one gwei as dividend", async function () {



        await expect(salvaCoin.connect(addr1).withdrawFunds())
          .to.emit(salvaCoin, "FundsWithdrawn")
          .withArgs(addr1.address, 333333333);

        const finalBal = 333333333 + lockedAmount;

        expect(await salvaCoin.balanceOf(addr1.address)).to.be.equal(finalBal);


      })

      // it("Should revert admin with zero divided because it does not hold any salva coin", async function () {

      //   const { ddt } = await loadFixture(
      //     deployDDTcontractFixture
      //   );
      //   await expect(ddt.withdrawFunds())
      //     .to.be.revertedWith('Zero caller dividend.');
      // })

    });

    // describe("Transfers", function () {
    //   it("Should transfer the funds to the owner", async function () {
    //     const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
    //       deployDDTcontractFixture
    //     );

    //     await time.increaseTo(unlockTime);

    //     await expect(lock.withdraw()).to.changeEtherBalances(
    //       [owner, lock],
    //       [lockedAmount, -lockedAmount]
    //     );
    //   });
    // });
  });


  describe.only('Trying to fund treasury while total supply 0', function () {
    it("Should revert funding treasury contract while total supply is zero", async () => {
      const { salvaCoin } = await loadFixture(deployDDTcontractFixture);

      await expect(salvaCoin.mint(salvaCoin.address, lockedAmount))
        .to.emit(salvaCoin, "Transfer")
        .withArgs(ethers.constants.AddressZero, salvaCoin.address, lockedAmount);

      expect(await salvaCoin.balanceOf(salvaCoin.address)).to.be.equal(lockedAmount);

      const fundToken = await salvaCoin.getFundsToken();

      console.log(`${await salvaCoin.balanceOf(fundToken)}`)

    })
  })


});
