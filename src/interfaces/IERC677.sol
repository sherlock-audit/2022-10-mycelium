pragma solidity ^0.8.9;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC677 is IERC20, IERC20Metadata {
    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);
}

interface IERC677Receiver {
    function onTokenTransfer(
        address sender,
        uint256 amount,
        bytes calldata data
    ) external returns (bool success);
}
