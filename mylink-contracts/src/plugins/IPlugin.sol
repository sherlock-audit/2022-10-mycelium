// SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity ^0.8.9;

interface IPlugin {
    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function balance() external view returns (uint256);

    function availableForDeposit() external view returns (uint256);

    function availableForWithdrawal() external view returns (uint256);
}
