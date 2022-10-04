// SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity ^0.8.9;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./IPlugin.sol";

/**
 * @title An abstract plugin that implements the common logic for all plugins
 *
 * To create a plugin, inherit from this contract and implement the following functions:
 * - _deposit(uint256 _amount)
 * - _withdraw(uint256 _amount)
 * - balance() public view returns (uint256)
 * - availableForDeposit() public view returns (uint256)
 * - availableForWithdrawal() public view returns (uint256)
 */

abstract contract BasePlugin is IPlugin {
    /// @notice The address of the vault contract
    address public immutable vault;

    /// @notice The address of the LINK token
    address public immutable LINK;

    /**
     * @notice Construct a new BasePlugin
     *
     * @param _vault The address of the vault contract
     * @param _LINK The address of the LINK token
     */
    constructor(address _vault, address _LINK) {
        vault = _vault;
        LINK = _LINK;
    }

    /**
     * @notice Deposit LINK into the plugin
     * @dev This function is only callable by the vault contract
     * @dev This function will revert if the amount is greater than the available capacity
     * @param _amount The amount of LINK to deposit
     */
    function deposit(uint256 _amount) external override onlyVault {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= availableForDeposit(), "Amount exceeds available capacity");
        IERC20(LINK).transferFrom(vault, address(this), _amount);
        _deposit(_amount);
    }

    /**
     * @notice Withdraw LINK from the plugin
     * @dev This function is only callable by the vault contract
     * @dev This function will revert if the amount is greater than the available amount
     *
     * @param _amount The amount of LINK to withdraw
     */
    function withdraw(uint256 _amount) external override onlyVault {
        require(_amount <= availableForWithdrawal(), "Amount exceeds available balance");
        _withdraw(_amount);
        IERC20(LINK).transfer(vault, _amount);
    }

    /**
     * @notice Implements the custom deposit logic for the plugin
     * @dev This function is required to be implemented in the derived plugin contract
     * @param _amount The amount of LINK to deposit
     */
    function _deposit(uint256 _amount) internal virtual;

    /**
     * @notice Implements the custom withdraw logic for the plugin
     * @dev This function is required to be implemented in the derived plugin contract
     * @param _amount The amount of LINK to withdraw
     */
    function _withdraw(uint256 _amount) internal virtual;

    /**
     * @return The total amount of LINK controlled by the plugin
     * @dev This function is required to be implemented in the derived plugin contract
     * @dev This is used for calculating the total balance of the vault
     */
    function balance() public view virtual override returns (uint256);

    /**
     * @return The amount of LINK that can be deposited into the plugin
     * @dev This function is required to be implemented in the derived plugin contract
     */
    function availableForDeposit() public view virtual override returns (uint256);

    /**
     * @return The amount of LINK that can be withdrawn from the plugin
     * @dev This function is required to be implemented in the derived plugin contract
     */
    function availableForWithdrawal() public view virtual override returns (uint256);

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault can call this function");
        _;
    }
}
