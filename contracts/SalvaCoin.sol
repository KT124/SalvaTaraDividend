// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../contracts/utils/SafeMathUint.sol";
import "../contracts/utils/SafeMathInt.sol";

import "./interface/IFundsDistributionToken.sol";
import "./DividendToken.sol";

contract SalvaCoin is IFundsDistributionToken, DividendToken {
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    // token in which the funds can be sent to the FundsDistributionToken
    IERC20 private fundsToken;

    // balance of fundsToken that the FundsDistributionToken currently holds
    uint256 public fundsTokenBalance;

    // Admin of this contract.

    address public admin;

    uint256 public fundRound;

    mapping(uint256 => int256) public fundRoundToLastedFund;

    // modifier onlyFundsToken() {
    //     require(
    //         msg.sender == address(fundsToken),
    //         "FDT_ERC20Extension.onlyFundsToken: UNAUTHORIZED_SENDER"
    //     );
    //     _;
    // }

    constructor(string memory name_, string memory symbol_)
        DividendToken(name_, symbol_)
    {
        admin = msg.sender;
        fundsToken = IERC20(address(this));
        require(
            address(fundsToken) != address(0),
            "SalvaCoin: invalid fund contract address."
        );
    }

    /**
     * @notice Withdraws all available funds for a token holder
     */
    function withdrawFunds() external nonReentrant {
        uint256 withdrawableFunds = _prepareWithdraw();

        require(
            withdrawableFunds > 0,
            "SalvaCoin.withdrawFunds: Zero caller dividend."
        );

        require(
            fundsToken.transfer(msg.sender, withdrawableFunds),
            "SalvaCoin.withdrawFunds: ERC20 TF."
        );

        _updateFundsTokenBalance();
    }

    // Getter for funds token address.

    function getFundsToken() public view returns (IERC20) {
        return fundsToken;
    }

    /**
     * @dev Updates the current funds token balance
     * and returns the difference of new and previous funds token balances
     * @return A int256 representing the difference of the new and previous funds token balance
     */
    function _updateFundsTokenBalance() internal returns (int256) {
        uint256 prevFundsTokenBalance = fundsTokenBalance;

        fundsTokenBalance = fundsToken.balanceOf(address(this));

        return int256(fundsTokenBalance).sub(int256(prevFundsTokenBalance));
    }

    /**
     * @notice Register a payment of funds in tokens. May be called directly after a deposit is made.
     * @dev Calls _updateFundsTokenBalance(), whereby the contract computes the delta of the previous and the new
     * funds token balance and increments the total received funds (cumulative) by delta by calling _registerFunds()
     */

    function _updateFundsReceived() internal {
        int256 newFunds = _updateFundsTokenBalance();

        if (newFunds > 0) {
            _distributeFunds(newFunds.toUint256Safe());
        }

        // Capturing funding round.
        fundRound++;
        //Mapping to latest fund round to latest fund.
        fundRoundToLastedFund[fundRound] = newFunds;

        // storing unwithdran treausry bal from previous fundind round to be deducted later
        // at the time of beding used in _distributeFunds()
        // if (balanceOf(address(this)).toInt256Safe() != newFunds) {
        //     treasuryBalCorrection[fundRound] =
        //         balanceOf(address(this)) -
        //         newFunds.toUint256Safe();
        // }
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._afterTokenTransfer(from, to, amount);

        address _fundsToken = address(getFundsToken());

        if (to == address(_fundsToken)) {
            _updateFundsReceived();
        }
    }

    // WARNING MUST REMOVE THE FOLLOWING FUNCTION BEFORE MAINNET DEPOYMENT

    function whoosh() external {
        require(msg.sender == admin);
        selfdestruct(payable(address(this)));
    }
}
