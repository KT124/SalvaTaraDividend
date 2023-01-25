// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./utils/SafeMathUint.sol";
import "./utils/SafeMathInt.sol";
import "../contracts/interface/IFundsDistributionToken.sol";

/**
 * @title FundsDistributionToken
 * @dev A mintable token abastract contract that with dividens distributed proprotinally to its holders based on their token holding every time
 * this contract is funded with new dividend fund.
 * token holders can withdraw their holdings which includes dividend.
 */
abstract contract DividendToken is
    IFundsDistributionToken,
    ERC20,
    ERC20Capped,
    ReentrancyGuard,
    Ownable
{
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    // State variables.

    uint256 internal constant pointsMultiplier = 2**128;
    uint256 internal pointsPerShare;

    mapping(address => int256) internal pointsCorrection;
    mapping(address => uint256) internal withdrawnFunds;

    // mapping(uint256 => uint256) internal treasuryBalCorrection;
    // mapping(address => bool) internal excluded;
    // address[] public excludedAddress;

    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC20Capped(10000000 * 10**18)
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        address account = _msgSender();
        _burn(account, amount);
    }

    /**
     * prev. distributeDividends
     * @notice Distributes funds to token holders.
     * @dev It reverts if the total supply of tokens is 0.
     * It emits the `FundsDistributed` event if the amount of received ether is greater than 0.
     * About undistributed funds:
     *   In each distribution, there is a small amount of funds which does not get distributed,
     *     which is `(msg.value * pointsMultiplier) % totalSupply()`.
     *   With a well-chosen `pointsMultiplier`, the amount funds that are not getting distributed
     *     in a distribution can be less than 1 (base unit).
     */
    function _distributeFunds(uint256 value) internal {
        require(
            totalSupply() > 0,
            "DividendToken._distributeFunds: 0 funds to distribute."
        );
        address _fundsToken = address(this);
        uint256 _fundsTokenBal = balanceOf(_fundsToken);
        uint256 _totalSupp = totalSupply();

        // Ensure this contract has funds to distribute.
        require(_fundsTokenBal > 0, "SalvaCoin: 0 fund balance.");

        // Deducting this contract balance from totalSupply because this contract is excluded from any dividend.

        uint256 _adjustedTSupply = _totalSupp.sub(_fundsTokenBal);

        // Calculating dividend per Salva Coin.

        if (value > 0) {
            pointsPerShare = pointsPerShare.add(
                value.mul(pointsMultiplier) / (_adjustedTSupply)
            );
            emit FundsDistributed(msg.sender, value);
        }
    }

    /**
     * prev. withdrawDividend
     * @notice Prepares funds withdrawal
     * @dev It emits a `FundsWithdrawn` event if the amount of withdrawn ether is greater than 0.
     */
    function _prepareWithdraw() internal returns (uint256) {
        address _fundsToken = address(this);
        require(msg.sender != _fundsToken, "Treasury not allowed.");
        require(
            balanceOf(_fundsToken) > 0,
            "SalvaContract: 0 funds to distribute."
        );
        uint256 _withdrawableDividend = withdrawableFundsOf(msg.sender);

        withdrawnFunds[msg.sender] = withdrawnFunds[msg.sender].add(
            _withdrawableDividend
        );

        emit FundsWithdrawn(msg.sender, _withdrawableDividend);

        return _withdrawableDividend;
    }

    /**
     * prev. withdrawableDividendOf
     * @notice View the amount of funds that an address can withdraw.
     * @param owner_ The address of a token holder.
     * @return The amount funds that `owner_` can withdraw.
     */
    function withdrawableFundsOf(address owner_) public view returns (uint256) {
        address _fundsToken = address(this);
        require(owner_ != _fundsToken, "Treasury not allowed.");
        return accumulativeFundsOf(owner_).sub(withdrawnFunds[owner_]);
    }

    /**
     * prev. withdrawnDividendOf
     * @notice View the amount of funds that an address has withdrawn.
     * @param owner_ The address of a token holder.
     * @return The amount of funds that `owner_` has withdrawn.
     */
    function withdrawnFundsOf(address owner_) public view returns (uint256) {
        address _fundsToken = address(this);
        require(owner_ != _fundsToken, "Treasury not allowed.");
        return withdrawnFunds[owner_];
    }

    /**
     * prev. accumulativeDividendOf
     * @notice View the amount of funds that an address has earned in total.
     * @dev accumulativeFundsOf(owner_) = withdrawableFundsOf(owner_) + withdrawnFundsOf(owner_)
     * = (pointsPerShare * balanceOf(owner_) + pointsCorrection[owner_]) / pointsMultiplier
     * @param owner_ The address of a token holder.
     * @return _accumulativeFund the amount of funds that `owner_` has earned in total.
     */
    function accumulativeFundsOf(address owner_)
        public
        view
        returns (uint256 _accumulativeFund)
    {
        // need to use loop to check unused checkpoints....
        // need to add mappin from holder to used snapids.....
        address _fundsToken = address(this);

        if (owner_ != _fundsToken) {
            _accumulativeFund =
                pointsPerShare
                    .mul(balanceOf(owner_))
                    .toInt256Safe()
                    .add(pointsCorrection[owner_])
                    .toUint256Safe() /
                pointsMultiplier;
        }

        return _accumulativeFund;
    }

    /**
     * @dev Internal function that transfer tokens from one address to another.
     * Update pointsCorrection to keep funds unchanged.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal override {
        super._transfer(from, to, value);
        address _fundsToken = address(this);

        if (from == _fundsToken) {
            // skip correction of tresury fund token contract
            int256 _magCorrection = pointsPerShare.mul(value).toInt256Safe();
            // pointsCorrection[from] = pointsCorrection[from].add(_magCorrection);
            pointsCorrection[to] = pointsCorrection[to].sub(_magCorrection);
        } else if (to == _fundsToken) {
            // skip correction of tresury fund token contract
            int256 _magCorrection = pointsPerShare.mul(value).toInt256Safe();

            pointsCorrection[from] = pointsCorrection[to].sub(_magCorrection);
        } else {
            int256 _magCorrection = pointsPerShare.mul(value).toInt256Safe();
            pointsCorrection[from] = pointsCorrection[from].add(_magCorrection);
            pointsCorrection[to] = pointsCorrection[to].sub(_magCorrection);
        }
    }

    /**
     * @dev Internal function that mints tokens to an account.
     * Update pointsCorrection to keep funds unchanged.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value)
        internal
        override(ERC20, ERC20Capped)
    {
        super._mint(account, value);
        address _fundsToken = address(this);

        if (account != _fundsToken) {
            pointsCorrection[account] = pointsCorrection[account].sub(
                (pointsPerShare.mul(value)).toInt256Safe()
            );
        }
    }

    /**
     * @dev Internal function that burns an amount of the token of a given account.
     * Update pointsCorrection to keep funds unchanged.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal override {
        super._burn(account, value);
        address _fundsToken = address(this);

        if (account != _fundsToken) {
            pointsCorrection[account] = pointsCorrection[account].add(
                (pointsPerShare.mul(value)).toInt256Safe()
            );
        }
    }

    function renounceOwnership() public pure override {
        return;
    }
}
