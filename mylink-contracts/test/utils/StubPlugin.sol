pragma solidity ^0.8.9;

import "../../src/plugins/BasePlugin.sol";

contract StubPlugin is BasePlugin {
    uint256 public capacity = type(uint256).max;
    uint256 private _balance;

    constructor(address _vault, address _LINK) BasePlugin(_vault, _LINK) {}

    function _deposit(uint256 _amount) internal override {
        _balance += _amount;
    }

    function _withdraw(uint256 _amount) internal override {
        _balance -= _amount;
    }

    function balance() public view override returns (uint256) {
        return _balance;
    }

    function setCapacity(uint256 _amount) public {
        capacity = _amount;
    }

    function availableForDeposit() public view override returns (uint256) {
        return capacity - _balance;
    }

    function availableForWithdrawal() public view override returns (uint256) {
        return balance();
    }

    function setBalance(uint256 _newBalance) public {
        _balance = _newBalance;
    }
}
