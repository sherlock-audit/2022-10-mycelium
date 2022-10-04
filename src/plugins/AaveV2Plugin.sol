// SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity ^0.8.9;

import "./BasePlugin.sol";
import "../vendors/aave/ILendingPool.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title A plugin that deposits LINK into Aave v2 and earns interest
 *
 * This plugin is intended to be used with the Vault contract
 */

contract AaveV2Plugin is BasePlugin {
    /// @notice The Aave V2 LendingPool contract
    ILendingPool public lendingPool;

    /// @notice The Aave V2 aLINK token
    IERC20 public aLINK;

    /**
     * @notice Construct a new AaveV2Plugin
     *
     * @param _vault The address of the vault contract
     * @param _LINK The address of the LINK token
     * @param _lendingPool The address of the Aave V2 LendingPool contract
     */
    constructor(
        address _vault,
        address _LINK,
        address _lendingPool
    ) BasePlugin(_vault, _LINK) {
        lendingPool = ILendingPool(_lendingPool);
        IERC20(_LINK).approve(_lendingPool, type(uint256).max);
        aLINK = IERC20(lendingPool.getReserveData(_LINK).aTokenAddress);
    }

    /**
     * @notice Deposit LINK into the LendingPool
     *
     * @param _amount The amount of LINK to deposit
     */
    function _deposit(uint256 _amount) internal override {
        lendingPool.deposit(LINK, _amount, address(this), 0);
    }

    /**
     * @notice Withdraw LINK from the LendingPool
     *
     * @param _amount The amount of LINK to withdraw
     */
    function _withdraw(uint256 _amount) internal override {
        lendingPool.withdraw(LINK, _amount, address(this));
    }

    /**
     * @notice Get the balance of the plugin
     * @dev This function returns the balance of the aLINK token
     *
     * @return The balance of the plugin
     */
    function balance() public view override returns (uint256) {
        return aLINK.balanceOf(address(this));
    }

    /**
     * @notice Get the available capacity for deposits
     * @dev Returns max uint256 - balance
     *
     * @return The available capacity for deposits
     */
    function availableForDeposit() public view override returns (uint256) {
        return type(uint256).max - balance();
    }

    /**
     * @notice Get the available balance for withdrawals
     * @dev Returns balance
     *
     * @return The available balance for withdrawals
     */
    function availableForWithdrawal() public view override returns (uint256) {
        return balance();
    }
}
