pragma solidity ^0.8.9;

import "openzeppelin/token/ERC20/ERC20.sol";
import "../../src/interfaces/IERC677.sol";

contract Token is ERC20, IERC677 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        _burn(_from, _amount);
    }

    function transferAndCall(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external override returns (bool success) {
        _transfer(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, _value, _data);

        bool result = IERC677Receiver(_to).onTokenTransfer(msg.sender, _value, _data);

        if (!result) {
            revert("Transfer failed");
        }

        return true;
    }
}
